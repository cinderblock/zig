//! usage: check <bundle> [--bound-to-executable <symbol>]
//! Asserts that the file is a 64-bit Mach-O bundle: filetype MH_BUNDLE, no
//! LC_ID_DYLIB (a bundle has no install name), and no LC_MAIN (no entry point).
//! Without options it was linked with `-undefined dynamic_lookup`, so the
//! MH_NOUNDEFS flag must be clear. With `--bound-to-executable` it was linked
//! with `-bundle_loader`, so every symbol was resolved at link time
//! (MH_NOUNDEFS set), and <symbol> must be imported from the main executable:
//! EXECUTABLE_ORDINAL in the symbol table, and BIND_SPECIAL_DYLIB_MAIN_EXECUTABLE
//! in every bind of it.

const std = @import("std");
const macho = std.macho;

/// EXECUTABLE_ORDINAL in <mach-o/nlist.h>
const executable_ordinal = 0xff;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(arena);
    const bound_symbol: ?[]const u8 = switch (args.len) {
        2 => null,
        4 => if (std.mem.eql(u8, args[2], "--bound-to-executable")) args[3] else return error.BadUsage,
        else => return error.BadUsage,
    };

    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, args[1], arena, .limited(64 * 1024 * 1024));
    if (bytes.len < @sizeOf(macho.mach_header_64)) return error.TooShort;

    const header = std.mem.bytesToValue(macho.mach_header_64, bytes[0..@sizeOf(macho.mach_header_64)]);
    if (header.magic != macho.MH_MAGIC_64) return error.NotMachO64;
    if (header.filetype != macho.MH_BUNDLE) {
        std.log.err("filetype is 0x{x}, expected MH_BUNDLE (0x{x})", .{ header.filetype, macho.MH_BUNDLE });
        return error.NotABundle;
    }
    const no_undefs = header.flags & macho.MH_NOUNDEFS != 0;
    if (bound_symbol == null and no_undefs) return error.UnexpectedNoUndefs;
    if (bound_symbol != null and !no_undefs) return error.ExpectedNoUndefs;

    var symtab: ?macho.symtab_command = null;
    var dyld_info: ?macho.dyld_info_command = null;
    var offset: usize = @sizeOf(macho.mach_header_64);
    for (0..header.ncmds) |_| {
        if (offset + @sizeOf(macho.load_command) > bytes.len) return error.Truncated;
        const lc = std.mem.bytesToValue(macho.load_command, bytes[offset..][0..@sizeOf(macho.load_command)]);
        if (lc.cmdsize == 0 or offset + lc.cmdsize > bytes.len) return error.Truncated;
        switch (lc.cmd) {
            .ID_DYLIB => return error.BundleHasInstallName,
            .MAIN => return error.BundleHasEntryPoint,
            .SYMTAB => symtab = std.mem.bytesToValue(macho.symtab_command, bytes[offset..][0..@sizeOf(macho.symtab_command)]),
            .DYLD_INFO, .DYLD_INFO_ONLY => dyld_info = std.mem.bytesToValue(macho.dyld_info_command, bytes[offset..][0..@sizeOf(macho.dyld_info_command)]),
            else => {},
        }
        offset += lc.cmdsize;
    }

    const name = bound_symbol orelse return;
    try checkSymtab(bytes, symtab orelse return error.NoSymtab, name);
    const info = dyld_info orelse return error.NoDyldInfo;
    var binds: usize = 0;
    binds += try checkBinds(bytes[info.bind_off..][0..info.bind_size], name);
    binds += try checkBinds(bytes[info.lazy_bind_off..][0..info.lazy_bind_size], name);
    if (binds == 0) {
        std.log.err("{s} is never bound", .{name});
        return error.NotBound;
    }
}

fn checkSymtab(bytes: []const u8, symtab: macho.symtab_command, name: []const u8) !void {
    const strtab = bytes[symtab.stroff..][0..symtab.strsize];
    for (0..symtab.nsyms) |i| {
        const sym = std.mem.bytesToValue(macho.nlist_64, bytes[symtab.symoff + i * @sizeOf(macho.nlist_64) ..][0..@sizeOf(macho.nlist_64)]);
        const sym_name = std.mem.sliceTo(strtab[sym.n_strx..], 0);
        if (!std.mem.eql(u8, sym_name, name)) continue;
        const ordinal = @as(u16, @bitCast(sym.n_desc)) >> 8;
        if (ordinal != executable_ordinal) {
            std.log.err("{s} has library ordinal {d} in the symbol table, expected EXECUTABLE_ORDINAL ({d})", .{ name, ordinal, executable_ordinal });
            return error.WrongLibraryOrdinal;
        }
        return;
    }
    std.log.err("{s} is not in the symbol table", .{name});
    return error.SymbolNotFound;
}

/// Walks a bind (or lazy bind) opcode stream and returns how many binds of `name`
/// it has, failing if any of them is not to the main executable.
fn checkBinds(stream: []const u8, name: []const u8) !usize {
    var r: std.Io.Reader = .fixed(stream);
    var ordinal: i64 = 0;
    var symbol: []const u8 = "";
    var count: usize = 0;
    while (r.takeByte()) |byte| {
        const imm = byte & macho.BIND_IMMEDIATE_MASK;
        var bind = false;
        switch (byte & macho.BIND_OPCODE_MASK) {
            macho.BIND_OPCODE_DONE, macho.BIND_OPCODE_SET_TYPE_IMM => {},
            macho.BIND_OPCODE_SET_DYLIB_ORDINAL_IMM => ordinal = imm,
            macho.BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB => ordinal = @intCast(try r.takeLeb128(u64)),
            macho.BIND_OPCODE_SET_DYLIB_SPECIAL_IMM => ordinal = if (imm == 0) 0 else @as(i8, @bitCast(macho.BIND_OPCODE_MASK | imm)),
            macho.BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM => symbol = try r.takeSentinel(0),
            macho.BIND_OPCODE_SET_ADDEND_SLEB => _ = try r.takeLeb128(i64),
            macho.BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB, macho.BIND_OPCODE_ADD_ADDR_ULEB => _ = try r.takeLeb128(u64),
            macho.BIND_OPCODE_DO_BIND, macho.BIND_OPCODE_DO_BIND_ADD_ADDR_IMM_SCALED => bind = true,
            macho.BIND_OPCODE_DO_BIND_ADD_ADDR_ULEB => {
                _ = try r.takeLeb128(u64);
                bind = true;
            },
            macho.BIND_OPCODE_DO_BIND_ULEB_TIMES_SKIPPING_ULEB => {
                _ = try r.takeLeb128(u64);
                _ = try r.takeLeb128(u64);
                bind = true;
            },
            else => return error.UnsupportedBindOpcode,
        }
        if (!bind or !std.mem.eql(u8, symbol, name)) continue;
        if (ordinal != macho.BIND_SPECIAL_DYLIB_MAIN_EXECUTABLE) {
            std.log.err("{s} is bound to dylib ordinal {d}, expected BIND_SPECIAL_DYLIB_MAIN_EXECUTABLE ({d})", .{ name, ordinal, macho.BIND_SPECIAL_DYLIB_MAIN_EXECUTABLE });
            return error.WrongBindOrdinal;
        }
        count += 1;
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => |e| return e,
    }
    return count;
}

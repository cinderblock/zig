//! usage: check <bundle>
//! Asserts that the file is a 64-bit Mach-O bundle: filetype MH_BUNDLE, no
//! LC_ID_DYLIB (a bundle has no install name), no LC_MAIN (no entry point),
//! and the MH_NOUNDEFS flag clear (it was linked with -undefined dynamic_lookup).

const std = @import("std");
const macho = std.macho;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(arena);
    if (args.len != 2) return error.BadUsage;

    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, args[1], arena, .limited(64 * 1024 * 1024));
    if (bytes.len < @sizeOf(macho.mach_header_64)) return error.TooShort;

    const header = std.mem.bytesToValue(macho.mach_header_64, bytes[0..@sizeOf(macho.mach_header_64)]);
    if (header.magic != macho.MH_MAGIC_64) return error.NotMachO64;
    if (header.filetype != macho.MH_BUNDLE) {
        std.log.err("filetype is 0x{x}, expected MH_BUNDLE (0x{x})", .{ header.filetype, macho.MH_BUNDLE });
        return error.NotABundle;
    }
    if (header.flags & macho.MH_NOUNDEFS != 0) return error.UnexpectedNoUndefs;

    var offset: usize = @sizeOf(macho.mach_header_64);
    for (0..header.ncmds) |_| {
        if (offset + @sizeOf(macho.load_command) > bytes.len) return error.Truncated;
        const lc = std.mem.bytesToValue(macho.load_command, bytes[offset..][0..@sizeOf(macho.load_command)]);
        switch (lc.cmd) {
            .ID_DYLIB => return error.BundleHasInstallName,
            .MAIN => return error.BundleHasEntryPoint,
            else => {},
        }
        if (lc.cmdsize == 0) return error.Truncated;
        offset += lc.cmdsize;
    }
}

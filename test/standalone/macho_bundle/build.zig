//! `zig cc -bundle` produces a Mach-O bundle (MH_BUNDLE), the kind of image
//! that Node.js addons and other plugins are; `-bundle_loader` binds a bundle's
//! symbols to the program that loads it, as PostgreSQL extensions need; and
//! linking an executable without `_main` under `-undefined dynamic_lookup` is a
//! clean error rather than a linker crash.

const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test it");
    b.default_step = test_step;

    const check = b.addExecutable(.{
        .name = "check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("check.zig"),
            .target = b.graph.host,
            .optimize = .debug,
        }),
    });

    for ([_][]const u8{ "aarch64-macos", "x86_64-macos" }) |triple| {
        // The driver flags, as Clang users write them.
        const cc = b.addSystemCommand(&.{ b.graph.zig_exe, "cc", "-target", triple, "-bundle", "-undefined", "dynamic_lookup", "-o" });
        cc.setName(b.fmt("zig cc -bundle -undefined dynamic_lookup ({s})", .{triple}));
        const bundle = cc.addOutputFileArg("addon.node");
        cc.addFileArg(b.path("addon.c"));

        const check_cc = b.addRunArtifact(check);
        check_cc.setName(b.fmt("check -bundle ({s})", .{triple}));
        check_cc.addFileArg(bundle);
        test_step.dependOn(&check_cc.step);

        // The same flags passed to the linker directly.
        const wl = b.addSystemCommand(&.{ b.graph.zig_exe, "cc", "-target", triple, "-Wl,-bundle", "-Wl,-undefined,dynamic_lookup", "-o" });
        wl.setName(b.fmt("zig cc -Wl,-bundle ({s})", .{triple}));
        const wl_bundle = wl.addOutputFileArg("addon.node");
        wl.addFileArg(b.path("addon.c"));

        const check_wl = b.addRunArtifact(check);
        check_wl.setName(b.fmt("check -Wl,-bundle ({s})", .{triple}));
        check_wl.addFileArg(wl_bundle);
        test_step.dependOn(&check_wl.step);

        // Without -bundle this is an executable with no _main: an error, not a crash.
        const no_main = b.addSystemCommand(&.{ b.graph.zig_exe, "cc", "-target", triple, "-Wl,-undefined,dynamic_lookup", "-o" });
        no_main.setName(b.fmt("zig cc executable without _main ({s})", .{triple}));
        _ = no_main.addOutputFileArg("no_main");
        no_main.addFileArg(b.path("addon.c"));
        no_main.expectExitCode(1);
        no_main.expectStdErrMatch("undefined symbol: _main");
        test_step.dependOn(&no_main.step);

        // -bundle_loader: a PostgreSQL-style extension, linked against the program that
        // loads it. hash_create() must come from that program, although libSystem has
        // one too, and be bound to the main executable.
        const host = b.addSystemCommand(&.{ b.graph.zig_exe, "cc", "-target", triple, "-rdynamic", "-o" });
        host.setName(b.fmt("zig cc loader ({s})", .{triple}));
        const host_exe = host.addOutputFileArg("loader");
        host.addFileArg(b.path("loader.c"));

        const pg = b.addSystemCommand(&.{ b.graph.zig_exe, "cc", "-target", triple, "-bundle", "-bundle_loader" });
        pg.setName(b.fmt("zig cc -bundle -bundle_loader ({s})", .{triple}));
        pg.addFileArg(host_exe);
        pg.addArg("-o");
        const pg_bundle = pg.addOutputFileArg("pg_addon.so");
        pg.addFileArg(b.path("pg_addon.c"));

        const check_pg = b.addRunArtifact(check);
        check_pg.setName(b.fmt("check -bundle_loader ({s})", .{triple}));
        check_pg.addFileArg(pg_bundle);
        check_pg.addArgs(&.{ "--bound-to-executable", "_hash_create" });
        test_step.dependOn(&check_pg.step);

        const pg_wl = b.addSystemCommand(&.{ b.graph.zig_exe, "cc", "-target", triple, "-Wl,-bundle" });
        pg_wl.setName(b.fmt("zig cc -Wl,-bundle_loader ({s})", .{triple}));
        pg_wl.addPrefixedFileArg("-Wl,-bundle_loader,", host_exe);
        pg_wl.addArg("-o");
        const pg_wl_bundle = pg_wl.addOutputFileArg("pg_addon.so");
        pg_wl.addFileArg(b.path("pg_addon.c"));

        const check_pg_wl = b.addRunArtifact(check);
        check_pg_wl.setName(b.fmt("check -Wl,-bundle_loader ({s})", .{triple}));
        check_pg_wl.addFileArg(pg_wl_bundle);
        check_pg_wl.addArgs(&.{ "--bound-to-executable", "_hash_create" });
        test_step.dependOn(&check_pg_wl.step);

        // -bundle_loader means nothing without -bundle (as with ld64).
        const not_bundle = b.addSystemCommand(&.{ b.graph.zig_exe, "cc", "-target", triple, "-shared", "-bundle_loader" });
        not_bundle.setName(b.fmt("zig cc -bundle_loader without -bundle ({s})", .{triple}));
        not_bundle.addFileArg(host_exe);
        not_bundle.addArg("-o");
        _ = not_bundle.addOutputFileArg("pg_addon.dylib");
        not_bundle.addFileArg(b.path("pg_addon.c"));
        not_bundle.expectExitCode(1);
        not_bundle.expectStdErrMatch("-bundle_loader can only be used with -bundle");
        test_step.dependOn(&not_bundle.step);

        // On a Mac of the same architecture, load the bundles and call into them.
        if (builtin.os.tag == .macos and std.mem.startsWith(u8, triple, @tagName(builtin.cpu.arch))) {
            const loader = b.addExecutable(.{
                .name = "loader",
                .root_module = b.createModule(.{
                    .target = b.graph.host,
                    .optimize = .debug,
                    .link_libc = true,
                }),
            });
            loader.root_module.addCSourceFile(.{ .file = b.path("loader.c"), .flags = &.{} });
            // The bundle finds host_value() in the loading executable.
            loader.rdynamic = true;

            const load = b.addRunArtifact(loader);
            load.addFileArg(bundle);
            load.expectExitCode(0);
            test_step.dependOn(&load.step);

            const load_pg = b.addRunArtifact(loader);
            load_pg.addFileArg(pg_bundle);
            load_pg.expectExitCode(0);
            test_step.dependOn(&load_pg.step);
        }
    }
}

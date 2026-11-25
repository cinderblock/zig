# Fork: `zig cc -bundle` for macOS

This fork's `master` is Zig's Codeberg `master` plus three fixes for Zig's Mach-O (macOS) linker:

1. **`zig cc -bundle` didn't make a bundle.** `-bundle` was ignored (`argument unused during compilation: '-bundle'`), so Zig linked an executable and failed with `error: undefined symbol: _main` / `note: referenced with linker flag -e`. `-Wl,-bundle` failed with `error: unsupported linker arg: -bundle`. Now both produce an `MH_BUNDLE`, the image type that Node.js addons, Python and Ruby extensions, Erlang NIFs, and other `dlopen` plugins use.
2. **`-undefined dynamic_lookup` crashed the linker on an executable with no `_main`.** Because `-bundle` was ignored, `-bundle -undefined dynamic_lookup` hit this too: exit 139, `Segmentation fault`, no message, and a garbage output file (sometimes only intermittently). Linking an executable with no `_main` now fails cleanly with `error: undefined symbol: _main`.
3. **`-bundle_loader` wasn't supported.** PostgreSQL extensions link with `-bundle -bundle_loader postgres` so functions they call from PostgreSQL bind to the executable that loads them. Without it, colliding symbols bound to a linked dylib instead: in [xataio/pgzx#105](https://github.com/xataio/pgzx/pull/105), a pgzx test extension called libSystem's `hash_create` instead of PostgreSQL's and crashed. Now `-bundle_loader <executable>` (and `-Wl,-bundle_loader,<executable>`) resolves the bundle's undefined symbols against that executable's exports before any dylib and binds them to the main executable, as Apple's `ld64` does.

Bundles and `-bundle_loader` also work from `zig build`. Set `macho_bundle` on a dynamic library:

```zig
const ext = b.addLibrary(.{ .name = "my_ext", .linkage = .dynamic, .root_module = mod });
ext.macho_bundle = true;
// PostgreSQL: bind to the server executable ($(pg_config --bindir)/postgres).
ext.setBundleLoader(.{ .cwd_relative = postgres_path });
// Or, instead of setBundleLoader, for a Node.js-style addon (-undefined dynamic_lookup):
// ext.linker_allow_shlib_undefined = true;
// Output still uses the default dylib filename (libmy_ext.dylib); rename it on install.
b.getInstallStep().dependOn(&b.addInstallArtifact(ext, .{ .dest_sub_path = "my_ext.dylib" }).step);
```

`zig build-lib -dynamic` also accepts `-bundle` and `-bundle_loader <executable>`.

Upstream reports: [ziglang/zig#14757](https://github.com/ziglang/zig/issues/14757), [#15868](https://github.com/ziglang/zig/issues/15868), [#17660](https://github.com/ziglang/zig/issues/17660), [#25451](https://github.com/ziglang/zig/issues/25451).

## Repro

```sh
printf 'extern int host_value(void);\nint addon_value(void) { return host_value() + 1; }\n' > addon.c
zig cc -target aarch64-macos -bundle -undefined dynamic_lookup -o addon.node addon.c
file addon.node   # upstream: crash or "data"; this fork: Mach-O 64-bit arm64 bundle
```

## Building

There are no prebuilt binaries yet. Clone `master` and build it like upstream Zig (see the top-level [README](../README.md)), or on x86_64 Linux run `sh fork/build-linux.sh ReleaseFast`.

## What's here

- The fix ([compare](https://github.com/cinderblock/zig/compare/upstream-master...master)): the commits on `master` above `upstream-master` (the Codeberg `master` they're based on). `master` also includes a no-op merge of the last commit from GitHub's old `ziglang/zig` mirror, where this fork started.
- `test/standalone/macho_bundle`: cross-links bundles for `aarch64-macos` and `x86_64-macos` from any host with both `zig cc` and `std.Build`; checks the Mach-O headers, `-bundle_loader` bindings, and the no-`_main` error; and `dlopen`s the bundles on macOS.
- `fork/build-linux.sh`: builds the compiler on x86_64 Linux, from a recent master Zig plus the LLVM devkit Zig's CI uses.
- `fork/repro.sh`: the repro, run against that build.
- `.github/workflows/macho-bundle.yml`: builds on Linux, runs the test, then loads the bundles on a GitHub macOS runner, with `dlopen` and as a Node.js addon.

## Not done

- The new Mach-O linker (`-fnew-linker`, `src/link/MachO2.zig`) isn't changed.

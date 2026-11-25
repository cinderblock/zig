Zig `@VERSION@`, built from this fork's [`master`](https://github.com/cinderblock/zig/commit/@COMMIT@): Zig's Codeberg `master` plus fixes for Mach-O bundles (`MH_BUNDLE`). `zig cc -bundle` emits a real Mach-O bundle, `-bundle_loader` binds symbols to the loading executable, `std.Build` has options for both, and `-undefined dynamic_lookup` no longer crashes the linker. Details: [fork/README.md](https://github.com/cinderblock/zig/blob/@COMMIT@/fork/README.md).

Downloads:

- `zig-x86_64-linux-*.tar.xz`, `zig-aarch64-linux-*.tar.xz`: Linux (statically linked)
- `zig-aarch64-macos-*.tar.xz`: macOS on Apple silicon. There is no Intel Mac host build, because Zig does not publish a prebuilt LLVM devkit for `x86_64-macos`.
- `zig-x86_64-windows-*.zip`, `zig-aarch64-windows-*.zip`: Windows

Unpack and run `zig` from the folder, as with ziglang.org's downloads. Verify downloaded archives against `SHA256SUMS` (Linux: `sha256sum -c --ignore-missing SHA256SUMS`; macOS: `grep aarch64-macos SHA256SUMS | shasum -a 256 -c`).

Each build was compiled on Linux with the LLVM devkit Zig's own CI uses, then tested on its own platform with [`test/standalone/macho_bundle`](https://github.com/cinderblock/zig/tree/@COMMIT@/test/standalone/macho_bundle).

This is not an official Zig release: the Zig project doesn't build, sign, or support it.

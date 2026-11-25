#!/bin/sh
# Builds this checkout's Zig compiler (with LLVM) on x86_64 Linux, following
# README "Building from Source Using Prebuilt Zig", with the pinned bootstrap
# Zig and LLVM devkit from fork/deps.sh. Output: build-fork/stage3/bin/zig
# (run it with ZIG_LIB_DIR=$PWD/lib).
#
# usage: fork/build-linux.sh [Debug|ReleaseSafe|ReleaseFast]
set -eu

OPTIMIZE="${1:-Debug}"
. "$(dirname "$0")/deps.sh"
fetch_boot
fetch_devkit x86_64-linux-musl

OUT="$PWD/build-fork"
mkdir -p "$OUT"
export ZIG_GLOBAL_CACHE_DIR="$OUT/global-cache"
export ZIG_LOCAL_CACHE_DIR="$OUT/local-cache"

"$ZIG_BOOT" build \
  --zig-lib=lib \
  -p "$OUT/stage3" \
  --search-prefix "$DEVKIT" \
  -Dstatic-llvm \
  -Duse-zig-libcxx \
  -Dtarget=x86_64-linux-musl \
  -Dcpu=baseline \
  -Doptimize="$OPTIMIZE" \
  -Dno-lib \
  -Dversion-string="0.18.0-dev.fork-macho-bundle"

echo "built: $OUT/stage3/bin/zig"

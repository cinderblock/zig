#!/bin/sh
# Builds this checkout's Zig compiler (with LLVM) on x86_64 Linux, following
# README "Building from Source Using Prebuilt Zig": a recent master build of
# Zig compiles the compiler, and the zig+llvm+lld+clang devkit Zig's own CI
# uses (ci/x86_64-linux-debug.sh) provides LLVM. Both are downloaded once into
# ~/deps. Output: build-fork/stage3/bin/zig (run it with ZIG_LIB_DIR=$PWD/lib).
#
# usage: fork/build-linux.sh [Debug|ReleaseSafe|ReleaseFast]
set -eu

OPTIMIZE="${1:-Debug}"
DEVKIT="zig+llvm+lld+clang-x86_64-linux-musl-0.18.0-dev.92+1e1964473"
BOOT="zig-x86_64-linux-0.18.0-dev.1273+1ba843088"
BOOT_SHA256="e26ec590ef667bf24471e954d572508f847f5f2eb96b44319de37dd313487133"

mkdir -p "$HOME/deps"
if [ ! -x "$HOME/deps/$DEVKIT/bin/zig" ]; then
  curl -fsSL "https://ziglang.org/deps/$DEVKIT.tar.xz" | tar -xJ -C "$HOME/deps"
fi
if [ ! -x "$HOME/deps/$BOOT/zig" ]; then
  curl -fsSL -o "$HOME/deps/$BOOT.tar.xz" "https://ziglang.org/builds/$BOOT.tar.xz"
  echo "$BOOT_SHA256  $HOME/deps/$BOOT.tar.xz" | sha256sum -c -
  tar -xJf "$HOME/deps/$BOOT.tar.xz" -C "$HOME/deps"
  rm -- "$HOME/deps/$BOOT.tar.xz"
fi

OUT="$PWD/build-fork"
mkdir -p "$OUT"
export ZIG_GLOBAL_CACHE_DIR="$OUT/global-cache"
export ZIG_LOCAL_CACHE_DIR="$OUT/local-cache"

"$HOME/deps/$BOOT/zig" build \
  --zig-lib=lib \
  -p "$OUT/stage3" \
  --search-prefix "$HOME/deps/$DEVKIT" \
  -Dstatic-llvm \
  -Duse-zig-libcxx \
  -Dtarget=x86_64-linux-musl \
  -Dcpu=baseline \
  -Doptimize="$OPTIMIZE" \
  -Dno-lib \
  -Dversion-string="0.18.0-dev.fork-macho-bundle"

echo "built: $OUT/stage3/bin/zig"

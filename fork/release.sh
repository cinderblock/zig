#!/bin/sh
# Builds a release of this fork for one host and packages it the way
# ziglang.org's downloads are: a zig-<arch>-<os>-<version> folder with zig,
# lib/, LICENSE, README.md and README-fork.md, as .tar.xz (.zip for Windows).
# Runs on x86_64 Linux and cross-compiles with the pinned devkit for that host
# (fork/deps.sh).
#
# usage: fork/release.sh <arch>-<os> <version> <dist dir>
#   <arch>-<os>: x86_64-linux, aarch64-linux, aarch64-macos, x86_64-windows,
#   or aarch64-windows
set -eu

HOST="$1"
VERSION="$2"
DIST="$3"
case "$HOST" in
  x86_64-linux | aarch64-linux) TARGET="$HOST-musl" ;;
  aarch64-macos) TARGET="$HOST-none" ;;
  x86_64-windows | aarch64-windows) TARGET="$HOST-gnu" ;;
  *) echo "unsupported host: $HOST" >&2; exit 1 ;;
esac

. "$(dirname "$0")/deps.sh"
fetch_boot
fetch_devkit "$TARGET"

NAME="zig-$HOST-$VERSION"
WORK="$PWD/build-release/$HOST"
mkdir -p "$WORK" "$DIST"
PACK="$(mktemp -d "$WORK/pack.XXXXXX")"
STAGE="$PACK/$NAME"
DIST="$(cd "$DIST" && pwd)"
export ZIG_GLOBAL_CACHE_DIR="$PWD/build-release/global-cache"
export ZIG_LOCAL_CACHE_DIR="$WORK/local-cache"

"$ZIG_BOOT" build \
  --zig-lib=lib \
  -p "$WORK/install" \
  --search-prefix "$DEVKIT" \
  -Dstatic-llvm \
  -Duse-zig-libcxx \
  -Dtarget="$TARGET" \
  -Dcpu=baseline \
  -Doptimize=ReleaseFast \
  -Dstrip \
  -Dversion-string="$VERSION"

mkdir "$STAGE"
case "$HOST" in
  *-windows) cp "$WORK/install/bin/zig.exe" "$STAGE/" ;;
  *) cp "$WORK/install/bin/zig" "$STAGE/" ;;
esac
cp -R "$WORK/install/lib/zig" "$STAGE/lib"
cp LICENSE README.md "$STAGE/"
cp fork/README.md "$STAGE/README-fork.md"

cd "$PACK"
case "$HOST" in
  *-windows) python3 -m zipfile -c "$DIST/$NAME.zip" "$NAME" ;;
  *) tar -cJf "$DIST/$NAME.tar.xz" "$NAME" ;;
esac
echo "packaged: $(ls "$DIST/$NAME".*)"

#!/bin/sh
# Runs the -bundle / dynamic_lookup repro against build-fork/stage3/bin/zig.
# usage: fork/repro.sh
set -u
ZIG="$PWD/build-fork/stage3/bin/zig"
export ZIG_LIB_DIR="$PWD/lib"
W="$PWD/build-fork/repro"
mkdir -p "$W"
export ZIG_GLOBAL_CACHE_DIR="$PWD/build-fork/global-cache" ZIG_LOCAL_CACHE_DIR="$W/cache"
A="$PWD/test/standalone/macho_bundle/addon.c"
"$ZIG" version
for T in aarch64-macos x86_64-macos; do
  for args in "-bundle -undefined dynamic_lookup" "-Wl,-bundle -Wl,-undefined,dynamic_lookup" "-Wl,-undefined,dynamic_lookup" "-bundle" "-shared -Wl,-undefined,dynamic_lookup"; do
    rm -f "$W/out"
    # shellcheck disable=SC2086
    "$ZIG" cc -target $T $args -o "$W/out" "$A" > "$W/log" 2>&1
    rc=$?
    echo "== $T $args -> exit $rc: $(file -b "$W/out" 2>/dev/null | cut -c1-70)"
    head -c 3000 "$W/log"
  done
done

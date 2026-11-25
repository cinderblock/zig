#!/bin/sh
# Prints this fork's version: upstream's development version as build.zig
# computes it (0.18.0-dev.<commits since the last release tag>), plus
# ".macho-bundle" and the commit: 0.18.0-dev.1308.macho-bundle+3190d0fdee.
# Needs the release tags (git fetch --tags).
set -eu

describe=$(git describe --match '*.*.*' --tags --abbrev=10)
case "$describe" in
  *-*-g*) ;;
  *) echo "expected <tag>-<height>-g<commit> from git describe, got $describe" >&2; exit 1 ;;
esac
height=${describe%-g*}
height=${height##*-}
commit=${describe##*-g}
version=$(sed -n 's/^const zig_version: std.SemanticVersion = .{ .major = \([0-9]*\), .minor = \([0-9]*\), .patch = \([0-9]*\) };$/\1.\2.\3/p' build.zig)
[ -n "$version" ] || { echo "zig_version not found in build.zig" >&2; exit 1; }
echo "$version-dev.$height.macho-bundle+$commit"

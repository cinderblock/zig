# Pinned downloads for the fork's build scripts. Sourced, not run.
#
# A recent master build of Zig (the bootstrap) compiles the compiler, and a
# zig+llvm+lld+clang devkit for the target (the ones Zig's own CI uses, see
# ci/*.sh) provides LLVM. Each download is SHA-256 checked and unpacked once
# into ~/deps.

BOOT="zig-x86_64-linux-0.18.0-dev.1273+1ba843088"
BOOT_SHA256="e26ec590ef667bf24471e954d572508f847f5f2eb96b44319de37dd313487133"
DEVKIT_VERSION="0.18.0-dev.92+1e1964473"

# Zig publishes devkits only for some targets; x86_64-macos has none for this
# LLVM version.
devkit_sha256() {
  case "$1" in
    x86_64-linux-musl) echo 3d59a8b9ac5ed3c1a046e550f35b5fb89cb5cd5ebf177cdf1ca00ad8150994e1 ;;
    aarch64-linux-musl) echo c25acb7e17486303fdcb9e9a19e252c8dacf0575404ef1e97f508db9cb1d9965 ;;
    aarch64-macos-none) echo 5daddeaad6e135ae4bd09d6c2b4c5a30873b58d10671c13fb8ac1af246df05e6 ;;
    x86_64-windows-gnu) echo e23a8c67f8d40a9fdabdf0bf527ac14c6ec4dcf7021c3260cad54ab998e10537 ;;
    aarch64-windows-gnu) echo 606beda6f8b4936d068f18ea352a7a225ba57e0c1c22bf745f85a443ddee3fff ;;
    *) return 1 ;;
  esac
}

# fetch <url> <sha256>: download, check, and unpack into ~/deps.
fetch() {
  file="$HOME/deps/${1##*/}"
  mkdir -p "$HOME/deps"
  curl -fsSL -o "$file" "$1"
  echo "$2  $file" | sha256sum -c -
  case "$file" in
    *.tar.xz) tar -xJf "$file" -C "$HOME/deps" ;;
    *.zip) unzip -q "$file" -d "$HOME/deps" ;;
  esac
  rm -- "$file"
}

# Sets ZIG_BOOT to the bootstrap Zig.
fetch_boot() {
  [ -x "$HOME/deps/$BOOT/zig" ] || fetch "https://ziglang.org/builds/$BOOT.tar.xz" "$BOOT_SHA256"
  ZIG_BOOT="$HOME/deps/$BOOT/zig"
}

# fetch_devkit <target>: sets DEVKIT to the devkit's directory.
fetch_devkit() {
  name="zig+llvm+lld+clang-$1-$DEVKIT_VERSION"
  sha=$(devkit_sha256 "$1") || { echo "no devkit for $1" >&2; exit 1; }
  case "$1" in *-windows-*) ext=zip ;; *) ext=tar.xz ;; esac
  [ -d "$HOME/deps/$name" ] || fetch "https://ziglang.org/deps/$name.$ext" "$sha"
  DEVKIT="$HOME/deps/$name"
}

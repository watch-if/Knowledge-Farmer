#!/usr/bin/env bash
set -Eeuo pipefail
trap 'printf "::error title=Android glibc build::%s:%d: %s\n" "${BASH_SOURCE[0]##*/}" "$LINENO" "$BASH_COMMAND"' ERR

triple=${1:?Choose a glibc target triple}
cache=${2:?Choose a directory for downloads}
scratch=${3:?Choose a build directory}
tools=$(cd "$(dirname "$0")" && pwd)
source_url=https://codeload.github.com/bminor/glibc/tar.gz/refs/tags/glibc-2.31
updates_url=https://deb.debian.org/debian/pool/main/g/glibc/glibc_2.31-13+deb11u11.debian.tar.xz
source_archive="$cache/glibc-2.31.tar.gz"
updates_archive="$cache/glibc_2.31-13+deb11u11.debian.tar.xz"
source="$scratch/glibc-source"
build="$scratch/glibc"

download_checked() {
  local url=$1 target=$2 digest=$3
  if [[ ! -s "$target" ]]; then
    curl --fail --location --silent --show-error --retry 3 "$url" -o "$target.incomplete"
    mv "$target.incomplete" "$target"
  fi
  printf '%s  %s\n' "$digest" "$target" | sha256sum -c -
}

download_checked "$source_url" "$source_archive" bcc5496be806fba7c0122201b2e246b02170dfd791ad6ac90bf3a52e9b2e27d4
download_checked "$updates_url" "$updates_archive" ff78277778ddefe1eb44680cb19d2d4dff91891effc3b59da424ae61b0bcd482
mkdir -p "$source" "$build"
tar -xzf "$source_archive" --strip-components=1 -C "$source"
tar -xJOf "$updates_archive" debian/patches/git-updates.diff | patch -d "$source" -p1 --batch
patch -d "$source" -p1 --batch < "$tools/android-glibc.patch"

build_triple=$(gcc -dumpmachine)
configure_args=(--prefix=/usr --build="$build_triple" --host="$triple" --disable-werror --disable-profile)
if [[ "$triple" != "$build_triple" ]]; then
  configure_args+=(--with-headers="/usr/$triple/include")
fi

cd "$build"
if ! CC="$triple-gcc" CFLAGS='-O2 -g0 -Wno-error=incompatible-pointer-types -Wno-error=implicit-function-declaration' \
  "$source/configure" "${configure_args[@]}" > configure.log 2>&1; then
  awk '/error:/ { print "::error title=Android glibc configure::" $0 }' configure.log
  tail -25 configure.log
  exit 1
fi
jobs=$(nproc)
build_runtime_libraries() {
  make -j"$jobs" lib || return
  # Build NPTL before librt so libpthread gets its initialization flags.
  for library in math dlfcn nptl rt login; do
    make -j"$jobs" "$library/others" || return
  done
}
if ! build_runtime_libraries > build.log 2>&1; then
  awk '/: error:|undefined reference|No rule to make/ { print "::error title=Android glibc build::" $0; if (++found == 8) exit }' build.log
  tail -25 build.log
  exit 1
fi
# INITFIRST is required to initialize pthread state before other libraries.
readelf -d "$build/nptl/libpthread.so" | grep 'FLAGS_1.*INITFIRST'

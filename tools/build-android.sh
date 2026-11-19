#!/usr/bin/env bash
set -Eeuo pipefail
trap 'printf "::error title=Android APK build::%s:%d: %s\n" "${BASH_SOURCE[0]##*/}" "$LINENO" "$BASH_COMMAND"' ERR

abi=${1:?Usage: build-android.sh arm64-v8a|x86_64 output.apk}
output=$(realpath -m "${2:?Choose an output APK}")
project=$(cd "$(dirname "$0")/.." && pwd)
sdk=${ANDROID_SDK_ROOT:?Set ANDROID_SDK_ROOT}
godot=${GODOT:-godot}
java_home=${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}
template=${FARMER_ANDROID_TEMPLATE:?Set FARMER_ANDROID_TEMPLATE to Godot 4.6.3 android_release.apk}
build_tools="$sdk/build-tools/36.0.0"
cache=${FARMER_ANDROID_DOWNLOADS:-$project/build/android-downloads}
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$cache" "$(dirname "$output")"

case "$abi" in
  arm64-v8a)
    preset='Android ARM64'
    triple=aarch64-linux-gnu
    loader=ld-linux-aarch64.so.1
    python_platform=aarch64
    lean_package=lean-4.19.0-linux_aarch64
    lean_digest=f19136d56bc3a5dc9af21edc88e64256c192d3f42c3e872dbeb30e392d7ad206
    ;;
  x86_64)
    preset='Android Emulator'
    triple=x86_64-linux-gnu
    loader=ld-linux-x86-64.so.2
    python_platform=x86_64
    lean_package=lean-4.19.0-linux
    lean_digest=6fe3ce97a58f44e2b3567d455b994eacec5bfe9ae7774f2a573444480ba813fe
    ;;
  *)
    printf 'Unsupported Android ABI: %s\n' "$abi" >&2
    exit 2
    ;;
esac

download() {
  local url=$1 file=$2
  if [[ ! -s "$file" ]]; then
    curl --fail --location --silent --show-error --retry 3 "$url" -o "$file.incomplete"
    mv "$file.incomplete" "$file"
  fi
}

checksum() {
  printf '%s  %s\n' "$1" "$2" | sha256sum -c -
}

lean_archive="$cache/$lean_package.tar.zst"
download "https://github.com/leanprover/lean4/releases/download/v4.19.0/$lean_package.tar.zst" "$lean_archive"
checksum "$lean_digest" "$lean_archive"
tar --zstd -xf "$lean_archive" -C "$scratch"
lean="$scratch/$lean_package"
if [[ "$abi" == x86_64 ]]; then
  toolchain="$lean/bin"
elif [[ -n ${ZETA_LEAN:-} && -x "$(dirname "$ZETA_LEAN")/clang" ]]; then
  toolchain="$(dirname "$ZETA_LEAN")"
else
  host_package=lean-4.19.0-linux
  host_archive="$cache/$host_package.tar.zst"
  download "https://github.com/leanprover/lean4/releases/download/v4.19.0/$host_package.tar.zst" "$host_archive"
  checksum 6fe3ce97a58f44e2b3567d455b994eacec5bfe9ae7774f2a573444480ba813fe "$host_archive"
  tar --zstd -xf "$host_archive" -C "$scratch"
  toolchain="$scratch/$host_package/bin"
fi

python_name="cpython-3.12.10+20250409-$python_platform-unknown-linux-gnu-install_only_stripped.tar.gz"
python_base=https://github.com/astral-sh/python-build-standalone/releases/download/20250409
download "$python_base/${python_name//+/%2B}" "$cache/$python_name"
download "$python_base/${python_name//+/%2B}.sha256" "$cache/$python_name.sha256"
checksum "$(cut -d' ' -f1 "$cache/$python_name.sha256")" "$cache/$python_name"
tar -xzf "$cache/$python_name" -C "$scratch"
python="$scratch/python"

"$project/tools/build-android-glibc.sh" "$triple" "$cache" "$scratch"
glibc="$scratch/glibc"
crt="$glibc/csu"

native="$scratch/inject/lib/$abi"
runtime="$scratch/runtime"
copy="$scratch/project"
mkdir -p "$native" "$runtime/lean/lib/lean" "$runtime/python/lib" "$copy"
cp "$glibc/elf/ld.so" "$native/libfarmer_loader.so"
cp "$glibc/libc.so" "$native/libfarmer_c.so"
cp "$glibc/math/libm.so" "$native/libfarmer_m.so"
cp "$glibc/dlfcn/libdl.so" "$native/libfarmer_dl.so"
cp "$glibc/nptl/libpthread.so" "$native/libfarmer_pthread.so"
cp "$glibc/rt/librt.so" "$native/libfarmer_rt.so"
cp "$glibc/login/libutil.so" "$native/libfarmer_util.so"

cp "$lean/bin/lean" "$native/libfarmer_lean.so"
cp "$lean"/lib/lean/lib{Init_shared,leanshared_1,leanshared}.so "$native/"
cp "$lean"/LICENSE* "$runtime/lean/"
cp -R "$lean"/lib/lean/{Init,Lean,Std,Init.olean,Lean.olean,Std.olean} "$runtime/lean/lib/lean/"
find "$runtime/lean/lib/lean" -type f ! -name '*.olean' -delete

cp "$python/lib/libpython3.12.so.1.0" "$native/libfarmer_libpython.so"
"$toolchain/clang" --target="$triple" -fPIE -Os -c "$project/tools/python-entry.c" -o "$scratch/python-entry.o"
"$toolchain/ld.lld" -pie -z noexecstack -z max-page-size=65536 --dynamic-linker "/lib/$loader" \
  --allow-shlib-undefined -o "$native/libfarmer_python.so" "$crt/Scrt1.o" "$crt/crti.o" "$scratch/python-entry.o" \
  "$native/libfarmer_libpython.so" "$glibc/libc.so" "$glibc/libc_nonshared.a" "$crt/crtn.o"
readelf -W -l "$native/libfarmer_python.so" | grep -E 'GNU_STACK +.* RW +0'
cp -R "$python/lib/python3.12" "$runtime/python/lib/"
find "$runtime/python" -type d \( -name __pycache__ -o -name site-packages \) -prune -exec rm -rf {} +
find "$runtime/python" -type f \( -name '*.pyc' -o -name '*.a' \) -delete

cp -R "$project"/{assets,src,project.godot,export_presets.cfg,main.tscn,menu.tscn} "$copy/"
if [[ ${FARMER_ANDROID_SMOKE:-0} == 1 ]]; then
  cp "$project/tests/android_game_smoke.gd" "$copy/android_game_smoke.gd"
  cat > "$copy/android_game_smoke.tscn" <<'SCENE'
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://android_game_smoke.gd" id="1"]
[node name="AndroidSmoke" type="Node"]
script = ExtResource("1")
SCENE
  sed -i 's|^run/main_scene=.*|run/main_scene="res://android_game_smoke.tscn"|' "$copy/project.godot"
fi
assets="$copy/assets/android-runtime"
mkdir -p "$assets"
rm -f "$assets/runtime.zip"
python3 - "$runtime" "$assets/runtime.zip" <<'PY'
import sys
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(sys.argv[1])
with ZipFile(sys.argv[2], "w", ZIP_DEFLATED, compresslevel=3) as archive:
    for path in sorted(root.rglob("*")):
        if path.is_file():
            archive.write(path, path.relative_to(root).as_posix())
PY
printf '%s\n' runtime_lean419_python312_1 > "$assets/revision.txt"
{
  printf '%s\n\n' 'Knowledge-Farmer'
  cat "$project/LICENSE"
  printf '\n%s\n' 'GNU libc 2.31 with Debian 11 maintenance and Knowledge-Farmer Android compatibility patches' \
    'Source: https://github.com/bminor/glibc/tree/glibc-2.31' \
    'Debian updates: https://deb.debian.org/debian/pool/main/g/glibc/glibc_2.31-13+deb11u11.debian.tar.xz' \
    'Build and Android patch: https://github.com/watch-if/Knowledge-Farmer/tree/main/tools'
} > "$assets/LICENSE.txt"
cat "$scratch/glibc-source/"{COPYING,COPYING.LIB} >> "$assets/LICENSE.txt"
cat "$runtime/lean/LICENSE" "$runtime/python/lib/python3.12/LICENSE.txt" >> "$assets/LICENSE.txt"

export XDG_CONFIG_HOME="$scratch/config" XDG_CACHE_HOME="$scratch/cache" XDG_DATA_HOME="$scratch/data"
settings="$XDG_CONFIG_HOME/godot"
templates="$XDG_DATA_HOME/godot/export_templates/4.6.3.stable"
mkdir -p "$settings" "$templates"
ln -s "$(realpath "$template")" "$templates/android_release.apk"
cat > "$settings/editor_settings-4.6.tres" <<SETTINGS
[gd_resource type="EditorSettings" format=3]
[resource]
export/android/android_sdk_path = "$sdk"
export/android/java_sdk_path = "$java_home"
export/android/shutdown_adb_on_exit = false
SETTINGS

version_code=${FARMER_ANDROID_VERSION_CODE:-1}
[[ "$version_code" =~ ^[1-9][0-9]*$ ]]
sed -i "s|^version/code=.*|version/code=$version_code|" "$copy/export_presets.cfg"
"$godot" --headless --path "$copy" --export-release "$preset" "$scratch/base.apk"
# Keep the runtime archive seekable without decompressing the outer APK on every read.
runtime_entry=assets/assets/android-runtime/runtime.zip
mkdir -p "$scratch/inject/$(dirname "$runtime_entry")"
ln "$assets/runtime.zip" "$scratch/inject/$runtime_entry"
zip -qd "$scratch/base.apk" "$runtime_entry"
(cd "$scratch/inject" && zip -q -0 -r "$scratch/base.apk" lib "$runtime_entry")
"$build_tools/zipalign" -f -P 16 4 "$scratch/base.apk" "$scratch/aligned.apk"
if [[ -n ${FARMER_ANDROID_KEYSTORE:-} ]]; then
  export FARMER_ANDROID_PASSWORD=${FARMER_ANDROID_PASSWORD:?Set FARMER_ANDROID_PASSWORD}
  "$build_tools/apksigner" sign --ks "$FARMER_ANDROID_KEYSTORE" --ks-key-alias farmer \
    --ks-pass env:FARMER_ANDROID_PASSWORD --key-pass env:FARMER_ANDROID_PASSWORD \
    --out "$output" "$scratch/aligned.apk"
  "$build_tools/apksigner" verify --verbose "$output"
else
  mv "$scratch/aligned.apk" "$output"
  printf 'Built unsigned APK: %s\n' "$output"
fi
unzip -tq "$output"

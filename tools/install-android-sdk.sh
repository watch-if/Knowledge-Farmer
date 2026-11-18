#!/usr/bin/env bash
set -euo pipefail
sdk=${1:?Usage: install-android-sdk.sh /path/to/sdk [additional SDK packages]}
shift
mkdir -p "$sdk/cmdline-tools"
manager="$sdk/cmdline-tools/cmdline-tools/bin/sdkmanager"
if [[ ! -x "$manager" ]]; then
  archive=$(mktemp)
  trap 'rm -f "$archive"' EXIT
  curl -fSL --retry 3 https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -o "$archive"
  unzip -qo "$archive" -d "$sdk/cmdline-tools"
fi
"$manager" --sdk_root="$sdk" --licenses >/dev/null < <(yes)
"$manager" --sdk_root="$sdk" 'platform-tools' 'build-tools;36.0.0' "$@"

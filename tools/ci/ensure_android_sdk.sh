#!/usr/bin/env bash
# Android SDK + JDK'yi doğrular ve Godot editör ayarlarına yazar (yalnız export; idempotent).
# GitHub ubuntu-24.04 runner'ında SDK (ANDROID_HOME) ve JDK 17 hazırdır; yoksa sdkmanager ile kurulur (dl.google.com).
# Çıkış: 0 tamam, 3 ağ yok (GATE_NET), 1 diğer hata.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/android-sdk}}"
JDK="${JAVA_HOME_17_X64:-${JAVA_HOME:-}}"
if [ -z "$JDK" ] && command -v javac >/dev/null; then
  JDK="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
fi
[ -n "$JDK" ] && [ -x "$JDK/bin/keytool" ] || { echo "JDK 17 bulunamadı (JAVA_HOME_17_X64/JAVA_HOME)" >&2; exit 1; }

have_tools() { ls "$SDK"/build-tools/*/apksigner >/dev/null 2>&1; }
if ! have_tools; then
  SM="$SDK/cmdline-tools/latest/bin/sdkmanager"
  if [ ! -x "$SM" ]; then
    mkdir -p "$SDK/cmdline-tools"
    ZIP="$(mktemp -d)/cmdline-tools.zip"
    curl -fL --retry 3 -sS -o "$ZIP" "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" \
      || { echo "GATE_NET: dl.google.com erişilemiyor — Android SDK indirilemedi" >&2; exit 3; }
    unzip -oq "$ZIP" -d "$SDK/cmdline-tools" && rm -rf "$SDK/cmdline-tools/latest" && mv "$SDK/cmdline-tools/cmdline-tools" "$SDK/cmdline-tools/latest"
  fi
  yes | "$SM" --sdk_root="$SDK" --licenses >/dev/null 2>&1 || true
  "$SM" --sdk_root="$SDK" "platform-tools" "build-tools;35.0.1" "platforms;android-35" >&2 \
    || { echo "GATE_NET: Android SDK paketleri kurulamadı" >&2; exit 3; }
fi
have_tools || { echo "build-tools/apksigner yok: $SDK" >&2; exit 1; }
bash "$HERE/write_editor_settings.sh" "$SDK" "$JDK" >&2
echo "$SDK"

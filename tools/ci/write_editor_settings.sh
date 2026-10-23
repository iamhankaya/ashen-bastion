#!/usr/bin/env bash
# Godot editör ayarlarına Android SDK/JDK yollarını yazar (headless export için).
# Kullanım: write_editor_settings.sh <android_sdk> <java_sdk>
set -euo pipefail
SDK="${1:?android sdk yolu}"
JDK="${2:?java sdk yolu}"
V="$(tr -d '[:space:]' < "$(dirname "$0")/../../.godot-version")"
MINOR="$(echo "${V%-stable}" | cut -d. -f1,2)"
DIR="$HOME/.config/godot"
mkdir -p "$DIR"
cat > "$DIR/editor_settings-${MINOR}.tres" <<TRES
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "$JDK"
TRES
echo "editor ayarları yazıldı: $DIR/editor_settings-${MINOR}.tres"

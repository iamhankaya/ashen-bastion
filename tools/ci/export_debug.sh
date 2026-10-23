#!/usr/bin/env bash
# Debug APK üretir ve imzasını doğrular: build/ab-debug.apk. Repodaki standart debug keystore ile imzalanır
# (sır değil; her CI APK'sı aynı imzayla güncelleme olarak kurulur).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export GATE_EXPORT=1
GODOT_BIN="$(bash tools/ci/ensure_godot.sh)"
SDK="$(bash tools/ci/ensure_android_sdk.sh)"
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$ROOT/tools/ci/debug.keystore"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"
"$GODOT_BIN" --headless --import > /dev/null 2>&1 || true
mkdir -p build
rm -f build/ab-debug.apk
"$GODOT_BIN" --headless --export-debug "Android" build/ab-debug.apk 2>&1 | tee build/export.log
[ -s build/ab-debug.apk ] || { echo "APK üretilemedi" >&2; exit 1; }
APKSIGNER="$(ls "$SDK"/build-tools/*/apksigner | sort -V | tail -1)"
"$APKSIGNER" verify --print-certs build/ab-debug.apk
ls -l build/ab-debug.apk

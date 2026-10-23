#!/usr/bin/env bash
# İmzalı release APK üretir: build/ab-release.apk (kalıcı keystore, yalnız ortam değişkenlerinden).
# Gerekli ortam değişkenleri (GitHub secret): ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_USER (alias), ANDROID_KEYSTORE_PASSWORD.
# İsteğe bağlı: AB_VERSION_CODE (tamsayı; geçici olarak export_presets.cfg'ye yazılır, çıkışta geri alınır), AB_VERSION_NAME.
# Çıkış: 0 tamam, 2 secret eksik/geçersiz, 3 ağ yok, 1 diğer hata. Sessiz unsigned/debug-imzalı APK ÜRETMEZ.
# Sır kuralları: keystore/şifre argv'ye, loga, export_presets.cfg'ye ve artefakta yazılmaz; geçici keystore çıkışta silinir.
set -euo pipefail
umask 077
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
else
  ROOT="${AB_ROOT:-$PWD}" # `bash -s < script` ile çalıştırılırsa depo kökünden
fi
cd "$ROOT"
[ -f project.godot ] || { echo "Depo kökü bulunamadı ($ROOT): project.godot yok" >&2; exit 1; }

err() { # err <ileti> : CI'da annotation, her yerde stderr
  [ -n "${GITHUB_ACTIONS:-}" ] && echo "::error title=Release APK::$1"
  echo "HATA: $1" >&2
}

# 1) Secret kontrolü — hiçbir şey indirilmeden/yazılmadan önce
missing=""
for v in ANDROID_KEYSTORE_BASE64 ANDROID_KEYSTORE_USER ANDROID_KEYSTORE_PASSWORD; do
  [ -n "${!v:-}" ] || missing="$missing $v"
done
if [ -n "$missing" ]; then
  err "Eksik secret:$missing — imzalı release APK üretilemez. Keystore üretimi ve secret ekleme adımları: docs/dev/release.md. (Fork PR'larında secret'lar zaten verilmez.)"
  exit 2
fi
if [ "${#ANDROID_KEYSTORE_PASSWORD}" -lt 8 ]; then
  err "ANDROID_KEYSTORE_PASSWORD en az 8 karakter olmalı (docs/dev/release.md)."
  exit 2
fi

# 2) Geçici dizin + temizlik (başarı, hata, INT/TERM)
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ab-release.XXXXXXXX")"
KS="$WORK/release.keystore"
CFG_BAK=""
cleanup() {
  local rc=$?
  trap - EXIT
  [ -n "$CFG_BAK" ] && [ -f "$CFG_BAK" ] && cp "$CFG_BAK" "$ROOT/export_presets.cfg"
  if [ -f "$KS" ]; then shred -u "$KS" 2>/dev/null || rm -f "$KS"; fi
  rm -rf "$WORK"
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

PAT="$WORK/patterns"
{ printf '%s\n' "$ANDROID_KEYSTORE_PASSWORD"; printf '%s\n' "${ANDROID_KEYSTORE_BASE64:200:64}"; } > "$PAT"
printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 -d > "$KS" 2>/dev/null \
  || { err "ANDROID_KEYSTORE_BASE64 geçerli base64 değil (docs/dev/release.md: 'base64 -w0')."; exit 2; }
[ -s "$KS" ] || { err "ANDROID_KEYSTORE_BASE64 boş keystore üretti."; exit 2; }

KEYTOOL="$(command -v keytool || true)"
[ -z "$KEYTOOL" ] && [ -x "${JAVA_HOME_17_X64:-${JAVA_HOME:-/nonexistent}}/bin/keytool" ] && KEYTOOL="${JAVA_HOME_17_X64:-$JAVA_HOME}/bin/keytool"
[ -n "$KEYTOOL" ] || { err "keytool bulunamadı (JDK 17 gerekli)."; exit 1; }

# fp_of <keystore> <alias> <şifre_env_adı> : sertifika SHA-256 (küçük harf, iki noktasız). Şifre argv'ye girmez.
fp_of() {
  local out
  out="$("$KEYTOOL" -J-Duser.language=en -list -v -keystore "$1" -alias "$2" -storepass:env "$3" 2>&1)" || {
    printf '%s\n' "$out" | grep -v '^Picked up' | head -n 3 >&2 || true
    return 1
  }
  printf '%s\n' "$out" | awk '/SHA256:/ {gsub(/[: ]/, "", $2); print tolower($2); exit}'
}

REL_FP="$(fp_of "$KS" "$ANDROID_KEYSTORE_USER" ANDROID_KEYSTORE_PASSWORD)" \
  || { err "Keystore açılamadı: şifre (ANDROID_KEYSTORE_PASSWORD) veya alias (ANDROID_KEYSTORE_USER) yanlış, ya da dosya keystore değil."; exit 2; }
[ -n "$REL_FP" ] || { err "Keystore'dan sertifika parmak izi okunamadı."; exit 2; }
export AB_DEBUG_PW=android
DBG_FP="$(fp_of "$ROOT/tools/ci/debug.keystore" androiddebugkey AB_DEBUG_PW)"
if [ "$REL_FP" = "$DBG_FP" ]; then
  err "Verilen keystore, repodaki herkese açık debug anahtarıyla aynı. Kalıcı bir release keystore üretin (docs/dev/release.md)."
  exit 2
fi

# 3) Araçlar — secret'lar bu adımların ortamına verilmez
CLEAN=(env -u ANDROID_KEYSTORE_BASE64 -u ANDROID_KEYSTORE_USER -u ANDROID_KEYSTORE_PASSWORD)
export GATE_EXPORT=1
GODOT_BIN="$("${CLEAN[@]}" bash tools/ci/ensure_godot.sh)"
SDK="$("${CLEAN[@]}" bash tools/ci/ensure_android_sdk.sh)"
APKSIGNER="$(ls "$SDK"/build-tools/*/apksigner | sort -V | tail -1)"

# 4) Sürüm (yalnız sır olmayan alanlar; çıkışta geri alınır)
if [ -n "${AB_VERSION_CODE:-}" ] || [ -n "${AB_VERSION_NAME:-}" ]; then
  CFG_BAK="$WORK/export_presets.cfg.bak"; cp export_presets.cfg "$CFG_BAK"
  if [ -n "${AB_VERSION_CODE:-}" ]; then
    [[ "$AB_VERSION_CODE" =~ ^[1-9][0-9]{0,8}$ ]] || { err "AB_VERSION_CODE pozitif tamsayı olmalı: '$AB_VERSION_CODE'"; exit 1; }
    sed -i "s/^version\/code=.*/version\/code=$AB_VERSION_CODE/" export_presets.cfg
  fi
  if [ -n "${AB_VERSION_NAME:-}" ]; then
    [[ "$AB_VERSION_NAME" =~ ^[0-9A-Za-z._-]{1,32}$ ]] || { err "AB_VERSION_NAME geçersiz: '$AB_VERSION_NAME'"; exit 1; }
    sed -i "s/^version\/name=.*/version\/name=\"$AB_VERSION_NAME\"/" export_presets.cfg
  fi
fi

# 5) Export (anahtar yalnız Godot sürecinin ortamında)
"$GODOT_BIN" --headless --import > /dev/null 2>&1 || true
mkdir -p build
rm -f build/ab-release.apk build/export-release.log
set +e
env GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KS" \
    GODOT_ANDROID_KEYSTORE_RELEASE_USER="$ANDROID_KEYSTORE_USER" \
    GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$ANDROID_KEYSTORE_PASSWORD" \
    ANDROID_KEYSTORE_BASE64= \
    "$GODOT_BIN" --headless --export-release "Android" build/ab-release.apk > build/export-release.log 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ] || [ ! -s build/ab-release.apk ]; then
  echo "--- export günlüğü (son 40 satır; sır taraması aşağıda) ---" >&2
  tail -n 40 build/export-release.log | grep -vF -f "$PAT" >&2 || true
  err "Godot release export başarısız (çıkış $rc) veya APK üretilmedi."
  rm -f build/ab-release.apk
  exit 1
fi

# 6) İmza doğrulama: geçerli + kalıcı anahtarın parmak izi + debug anahtarı değil
VERIFY="$("$APKSIGNER" verify --verbose --print-certs build/ab-release.apk 2>&1)" \
  || { rm -f build/ab-release.apk; err "apksigner verify başarısız: APK imzasız/bozuk."; exit 1; }
APK_FP="$(printf '%s\n' "$VERIFY" | awk '/certificate SHA-256 digest:/ {print tolower($NF); exit}')"
NSIG="$(printf '%s\n' "$VERIFY" | awk '/certificate SHA-256 digest:/ {n++} END {print n+0}')"
if [ "$NSIG" != "1" ] || [ "$APK_FP" != "$REL_FP" ]; then
  rm -f build/ab-release.apk
  err "APK imzacısı beklenen kalıcı release anahtarı değil (imzacı sayısı=$NSIG, APK=$APK_FP, anahtar=$REL_FP)."
  exit 1
fi
if [ "$APK_FP" = "$DBG_FP" ]; then
  rm -f build/ab-release.apk
  err "APK debug anahtarıyla imzalanmış."
  exit 1
fi

# 7) Sızıntı taraması: günlük + APK içeriği + build/ altındaki metin dosyaları + export_presets.cfg
LEAK=0
UNZ="$WORK/apk"; mkdir -p "$UNZ"; unzip -oq build/ab-release.apk -d "$UNZ"
for target in build/export-release.log export_presets.cfg "$UNZ"; do
  if grep -rIlF -f "$PAT" "$target" > "$WORK/leak.txt" 2>/dev/null; then
    echo "SIZINTI: sır aşağıdaki dosyada bulundu (değer yazılmaz): $(sed "s#$UNZ#<apk>#" "$WORK/leak.txt" | head -n 3 | tr '\n' ' ')" >&2
    LEAK=1
  fi
done
if [ "$LEAK" = "1" ]; then
  rm -f build/ab-release.apk build/export-release.log
  err "Sır sızıntısı tespit edildi; APK ve günlük silindi."
  exit 1
fi
extra="$(find . \( -path ./.git -o -path ./.godot -o -path ./build \) -prune -o -type f \( -name '*.keystore' -o -name '*.jks' -o -name '*.p12' \) -print | awk '$0 != "./tools/ci/debug.keystore"')"
[ -z "$extra" ] || { err "Depo ağacında ek anahtar dosyası var: $extra"; exit 1; }

echo "İmza doğrulandı. Sertifika SHA-256 (herkese açık bilgi): $APK_FP"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && printf 'Release APK sertifika SHA-256: `%s`\n' "$APK_FP" >> "$GITHUB_STEP_SUMMARY"
chmod 644 build/ab-release.apk
ls -l build/ab-release.apk

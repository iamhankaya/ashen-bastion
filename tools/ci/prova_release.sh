#!/usr/bin/env bash
# export_release.sh provası. Geçici (atılacak) test keystore'u üretir; hiçbir şey commit'lenmez, çıkışta silinir.
#   --fast : Godot/SDK gerektirmeyen olumsuz senaryolar (secret yok/eksik, kısa şifre, bozuk base64, yanlış şifre/alias, debug anahtarı)
#   --full : --fast + gerçek export (imzalı APK, parmak izi, temizlik, sızıntı dedektörü, ikinci koşu)
set -uo pipefail
MODE="${1:---fast}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
FAILS=0
PW="Prova-$(head -c 9 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')x"
ALIAS="provakey"
keytool -genkeypair -keystore "$T/prova.keystore" -alias "$ALIAS" -keyalg RSA -keysize 2048 -validity 30 \
  -storepass "$PW" -dname "CN=Prova, O=Prova, C=TR" >/dev/null 2>&1 || { echo "test keystore üretilemedi" >&2; exit 1; }
B64="$(base64 -w0 < "$T/prova.keystore")"

run() { # run <ad> <beklenen_kod> <beklenen_metin|-> <env...> -- ; günlük: $T/<ad>.log
  local name="$1" want="$2" pat="$3"; shift 3
  local got
  (cd "$ROOT" && env -u ANDROID_KEYSTORE_BASE64 -u ANDROID_KEYSTORE_USER -u ANDROID_KEYSTORE_PASSWORD "$@" TMPDIR="$T" bash tools/ci/export_release.sh) > "$T/$name.log" 2>&1
  got=$?
  local ok=1
  [ "$got" = "$want" ] || ok=0
  if [ "$pat" != "-" ] && ! grep -q -- "$pat" "$T/$name.log"; then ok=0; fi
  if grep -qF -e "$PW" "$T/$name.log"; then ok=0; echo "  (günlükte şifre bulundu!)"; fi
  if [ "$ok" = 1 ]; then echo "OK   $name (çıkış $got)"; else echo "FAIL $name: beklenen $want [$pat], gelen $got"; tail -n 8 "$T/$name.log"; FAILS=$((FAILS+1)); fi
}
no_leftover() { # geçici keystore dizini kalmadı mı
  if ls "$T"/ab-release.* >/dev/null 2>&1; then echo "FAIL $1: geçici dizin kaldı"; FAILS=$((FAILS+1)); else echo "OK   $1: geçici keystore/dizin silindi"; fi
}

run "secret yok" 2 "Eksik secret: ANDROID_KEYSTORE_BASE64 ANDROID_KEYSTORE_USER ANDROID_KEYSTORE_PASSWORD" X=1
run "secret kısmen" 2 "Eksik secret: ANDROID_KEYSTORE_USER" ANDROID_KEYSTORE_BASE64="$B64" ANDROID_KEYSTORE_PASSWORD="$PW"
run "kısa şifre" 2 "en az 8" ANDROID_KEYSTORE_BASE64="$B64" ANDROID_KEYSTORE_USER="$ALIAS" ANDROID_KEYSTORE_PASSWORD="abc"
run "bozuk base64" 2 "base64" ANDROID_KEYSTORE_BASE64='@@@bozuk@@@' ANDROID_KEYSTORE_USER="$ALIAS" ANDROID_KEYSTORE_PASSWORD="$PW"
run "keystore olmayan veri" 2 "Keystore açılamadı" ANDROID_KEYSTORE_BASE64="$(printf 'merhaba dunya' | base64 -w0)" ANDROID_KEYSTORE_USER="$ALIAS" ANDROID_KEYSTORE_PASSWORD="$PW"
run "yanlış şifre" 2 "Keystore açılamadı" ANDROID_KEYSTORE_BASE64="$B64" ANDROID_KEYSTORE_USER="$ALIAS" ANDROID_KEYSTORE_PASSWORD="yanlis-sifre-123"
run "yanlış alias" 2 "Keystore açılamadı" ANDROID_KEYSTORE_BASE64="$B64" ANDROID_KEYSTORE_USER="baska" ANDROID_KEYSTORE_PASSWORD="$PW"
# debug anahtarı, ≥8 karakter şifreli kopyada (aynı sertifika)
keytool -importkeystore -srckeystore "$ROOT/tools/ci/debug.keystore" -srcstorepass android -destkeystore "$T/dbgcopy.p12" \
  -deststoretype PKCS12 -deststorepass "$PW" -destkeypass "$PW" >/dev/null 2>&1 || { echo "debug kopyası üretilemedi"; FAILS=$((FAILS+1)); }
DB64="$(base64 -w0 < "$T/dbgcopy.p12")"
run "debug anahtarı reddi" 2 "debug anahtarıyla aynı" ANDROID_KEYSTORE_BASE64="$DB64" ANDROID_KEYSTORE_USER="androiddebugkey" ANDROID_KEYSTORE_PASSWORD="$PW"
no_leftover "olumsuz senaryolar"
[ -s "$ROOT/build/ab-release.apk" ] && [ "$MODE" = "--fast" ] && { echo "FAIL: olumsuz senaryo APK bıraktı"; FAILS=$((FAILS+1)); }

if [ "$MODE" = "--full" ]; then
  GOOD=(ANDROID_KEYSTORE_BASE64="$B64" ANDROID_KEYSTORE_USER="$ALIAS" ANDROID_KEYSTORE_PASSWORD="$PW")
  rm -f "$ROOT/build/ab-release.apk"
  run "imzalı APK (1. koşu)" 0 "İmza doğrulandı" "${GOOD[@]}" AB_VERSION_CODE=7 AB_VERSION_NAME=0.0.1-prova
  [ -s "$ROOT/build/ab-release.apk" ] && echo "OK   APK var" || { echo "FAIL APK yok"; FAILS=$((FAILS+1)); }
  no_leftover "başarılı koşu"
  grep -q '^version/code=1$' "$ROOT/export_presets.cfg" && echo "OK   export_presets.cfg geri alındı" || { echo "FAIL export_presets.cfg değişik kaldı"; FAILS=$((FAILS+1)); }
  run "imzalı APK (2. koşu, idempotent)" 0 "İmza doğrulandı" "${GOOD[@]}"
  # sızıntı dedektörü: Godot'u şifreyi loga basan bir sarmalayıcıyla değiştir
  V="$(tr -d '[:space:]' < "$ROOT/.godot-version")"; REAL="${GODOT_BIN:-$HOME/.cache/ashen-bastion/$V/Godot_v${V}_linux.x86_64}"
  printf '#!/usr/bin/env bash\n[ "${1:-}" = "--version" ] && exec "%s" "$@"\necho "debug: $GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"\nexec "%s" "$@"\n' "$REAL" "$REAL" > "$T/leaky-godot"; chmod +x "$T/leaky-godot"
  run "sızıntı dedektörü" 1 "Sır sızıntısı tespit edildi" "${GOOD[@]}" GODOT_BIN="$T/leaky-godot"
  [ ! -e "$ROOT/build/ab-release.apk" ] && echo "OK   sızıntıda APK silindi" || { echo "FAIL sızıntıda APK kaldı"; FAILS=$((FAILS+1)); }
  no_leftover "sızıntı koşusu"
fi
[ "$FAILS" = 0 ] && echo "PROVA YEŞİL" || echo "PROVA KIRMIZI ($FAILS)"
exit $((FAILS>0))

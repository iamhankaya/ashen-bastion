#!/usr/bin/env bash
# Godot içe aktarmasını (--headless --import) bilinen aralıklı çöküş imzasına karşı sınırlı korumayla koşar (F-042).
# Kullanım: GODOT_BIN=... godot_import.sh <günlük>      (çalışma dizini = proje kökü)
#
# İMZA (yalnız bu yeniden denenir): Godot SIGABRT ile düştü (kabuk çıkış kodu 134, "Aborted (core dumped)") VE günlükte
# içerik hatası satırı yok (^SCRIPT ERROR | Parse Error | ERROR:). CI'da görülen çöküşte (PR #69/#70) Godot günlüğe
# çöküş satırı yazmıyor; ayırt edici olan, test gövdesine/içerik hatasına gelmeden SIGABRT ile ölmesidir.
# Başka her hata (çıkış kodu != 0 ve != 134, ya da 134 + içerik hatası) yeniden denenmez; hemen o kodla çıkar.
#
# En çok BİR yeniden deneme. Her deneme günlüğe, stderr'e ve (varsa) $GITHUB_STEP_SUMMARY'ye yazılır; sessiz yeniden deneme yok.
# İlk deneme günlüğü <günlük>.deneme1 olarak saklanır; <günlük> son denemenin günlüğüdür. İkinci çöküş = çıkış 134 (gate kırmızı).
# KANIT (ASHEN_EVIDENCE_DIR doluysa; ci.yml bunu ayarlar ve artifact olarak yükler): her çöküşte günlük, not, çalışma
# dizinine düşen core* dosyaları ve (core + gdb varsa) `gdb -batch -ex bt` çıktısı o dizine toplanır; bt ilk satırları CI özetine yazılır.
# Yeniden denemeden önce yarım yazılmış .godot önbelleği silinir (bozuk önbellekle ikinci çöküşü önlemek için).
set -uo pipefail
LOG="${1:?kullanım: godot_import.sh <günlük>}"
: "${GODOT_BIN:?GODOT_BIN gerekli}"
NOTE="$(dirname "$LOG")/import_retry.txt"
rm -f "$NOTE" "$LOG.deneme1"

note() { # note <metin>: stderr + günlük + CI özeti
  echo "IMPORT_RETRY: $*" | tee -a "$NOTE" >&2
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "- IMPORT_RETRY: $*" >> "$GITHUB_STEP_SUMMARY"
  return 0
}
ulimit -c unlimited 2>/dev/null || true
EVID="${ASHEN_EVIDENCE_DIR:-}"
evidence() { # evidence <etiket>: çöküş kanıtını topla (en iyi çaba; hata betiği düşürmez)
  [ -n "$EVID" ] || return 0
  local d="$EVID/$(basename "$PWD")-$1-$$" c
  mkdir -p "$d" || return 0
  { echo "core_pattern: $(cat /proc/sys/kernel/core_pattern 2>/dev/null)"; echo "ulimit -c: $(ulimit -c)"; uname -a
    nproc; free -m 2>/dev/null | head -2; } > "$d/ortam.txt" 2>&1
  cp "$LOG" "$d/" 2>/dev/null; [ -f "$LOG.deneme1" ] && cp "$LOG.deneme1" "$d/"; cp "$NOTE" "$d/" 2>/dev/null
  for c in core core.* ./core.* "$(dirname "$LOG")"/core*; do
    [ -f "$c" ] || continue
    mv "$c" "$d/" 2>/dev/null || continue
    if command -v gdb >/dev/null; then
      gdb -batch -ex bt "$GODOT_BIN" "$d/$(basename "$c")" > "$d/bt.txt" 2>&1
      note "geri izleme ($1): $(grep -E '^#[0-9]+' "$d/bt.txt" | head -n 8 | cut -c1-120 | tr '\n' ';')"
    else
      note "core bulundu ($1) ama gdb yok: geri izleme alınamadı (core artifact'ta)"
    fi
  done
  return 0
}
has_content_error() { sed 's/\x1b\[[0-9;]*m//g' "$1" | grep -qE '^(SCRIPT ERROR|Parse Error|ERROR:)'; }
last_line() { sed 's/\x1b\[[0-9;]*m//g' "$1" | grep -v '^\s*$' | tail -n 1 | cut -c1-160; }

"$GODOT_BIN" --headless --import > "$LOG" 2>&1
rc=$?
[ $rc -eq 0 ] && exit 0
if [ $rc -ne 134 ] || has_content_error "$LOG"; then
  exit $rc   # imza değil: yeniden denenmez
fi

note "deneme 1 SIGABRT ile düştü (çıkış 134, içerik hatası yok; son satır: '$(last_line "$LOG")'); .godot silinip 1 kez yeniden denenecek"
cp "$LOG" "$LOG.deneme1"
evidence deneme1
rm -rf .godot
"$GODOT_BIN" --headless --import > "$LOG" 2>&1
rc=$?
if [ $rc -eq 0 ]; then
  note "deneme 2 başarılı (ilk çöküş günlüğü: $LOG.deneme1)"
  exit 0
fi
note "deneme 2 de düştü (çıkış $rc, son satır: '$(last_line "$LOG")'): yeniden deneme yok, gate kırmızı"
evidence deneme2
exit $rc

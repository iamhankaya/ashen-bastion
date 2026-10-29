#!/usr/bin/env bash
# Mutasyon kanıtı (R3 dilim kabulü; CI kapısı DEĞİL): yamayı uygula, verilen test dosyalarını GUT ile koş, KIRMIZI beklenir, yamayı geri al.
#   GODOT_BIN=<godot> tools/ci/mutation_check.sh test/characterization/mutations/<ad>.patch test/unit/test_x.gd [...]
# Çıkış 0 = mutasyon öldürüldü (testler kırmızı); 1 = mutasyon yaşıyor (testler yeşil kaldı); 2 = kullanım/yama hatası.
set -u
patch=${1:?yama}; shift
[ $# -ge 1 ] || { echo "kullanım: mutation_check.sh YAMA TEST.gd..." >&2; exit 2; }
[ -n "${GODOT_BIN:-}" ] || { echo "GODOT_BIN tanımsız" >&2; exit 2; }
git apply --check "$patch" || { echo "yama uygulanamıyor: $patch" >&2; exit 2; }
git apply "$patch"
trap 'git apply -R "$patch"' EXIT
rc=0
for t in "$@"; do
  out=$("$GODOT_BIN" --headless -s res://addons/gut/gut_cmdln.gd -gtest="res://$t" -gexit 2>&1); code=$?
  if echo "$out" | grep -qE "SCRIPT ERROR|Parse Error|Failed to load"; then
    echo "yama/test yüklenemedi (öldürme sayılmaz): $t" >&2; rc=2   # parse hatası sahte "killed" üretmesin
  elif [ $code -ne 0 ]; then
    echo "killed: $t"
  else
    echo "MUTANT_SURVIVED: $t ($patch)" >&2; [ $rc -eq 2 ] || rc=1
  fi
done
exit $rc

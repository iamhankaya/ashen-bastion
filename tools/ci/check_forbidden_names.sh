#!/usr/bin/env bash
# Public repo: yasaklı adlar (esin kaynağı karakter/eser adları) repoya girmez. Desen repoda TUTULMAZ: GATE_FORBIDDEN_RE
# ortam değişkeninden (CI'da GitHub secret) okunur; genişletilmiş düzenli ifade, büyük/küçük harf duyarsız.
# Yoksa adım atlanır ve "atlandı" yazar. Eşleşen DOSYA yolları yazılır (eşleşen metin günlüğe sızmasın), çıkış 1.
# Kullanım: bash tools/ci/check_forbidden_names.sh   (depo kökünden ya da herhangi bir alt dizinden)
set -uo pipefail
cd "$(dirname "$0")/../.."
if [ -z "${GATE_FORBIDDEN_RE:-}" ]; then
  echo "yasaklı ad denetimi: atlandı (GATE_FORBIDDEN_RE tanımlı değil)"
  exit 0
fi
out="$(git grep -lIiE --untracked -e "$GATE_FORBIDDEN_RE" -- . 2>/dev/null)"; rc=$?
if [ $rc -eq 0 ]; then
  echo "$out" >&2
  echo "yasaklı ad denetimi: KIRMIZI — yukarıdaki dosyalarda yasaklı ad var (desen gizli, günlükte yazılmaz)" >&2
  exit 1
elif [ $rc -eq 1 ]; then
  echo "yasaklı ad denetimi: temiz"
  exit 0
fi
echo "yasaklı ad denetimi: GATE_FORBIDDEN_RE geçersiz ya da git grep hatası (çıkış $rc)" >&2
exit 1

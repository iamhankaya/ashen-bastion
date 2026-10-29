#!/usr/bin/env bash
# Ön denetim kancası koşucusu: <dizin>/NN-ad.sh betiklerini ad sırasıyla `bash` ile koşar (çalıştırma biti gerekmez).
# Kullanım: run_checks.sh [dizin]   (varsayılan tools/ci/checks.d; çalışma dizini = proje kökü)
# İlk kırmızı betikte durur ve "CHECK FAIL: <betik>" yazıp o çıkış koduyla çıkar. tools/gate.sh adım 0 bunu çağırır.
set -uo pipefail
DIR="${1:-tools/ci/checks.d}"
[ -d "$DIR" ] || { echo "run_checks: dizin yok: $DIR" >&2; exit 2; }
for chk in "$DIR"/*.sh; do
  [ -e "$chk" ] || continue
  bash "$chk"; rc=$?
  if [ $rc -ne 0 ]; then echo "CHECK FAIL: $chk (çıkış $rc)" >&2; exit "$rc"; fi
  echo "CHECK OK: $chk"
done

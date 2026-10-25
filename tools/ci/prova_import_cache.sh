#!/usr/bin/env bash
# Bozuk .godot içe aktarma önbelleği provası (F-042 madde 3). Gerçek Godot gerekir (~2 dk); gate'e dahil değil.
# Beklenen: bozuk önbellekte --import çıkış 0 verir ama günlükte ERROR: satırı olur (gate scan_log bunu kırmızı yapar);
# `rm -rf .godot` sonrası günlük temizdir. Kullanım: bash tools/ci/prova_import_cache.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT_BIN="$(bash "$ROOT/tools/ci/ensure_godot.sh")"; export GODOT_BIN
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
(cd "$ROOT" && git ls-files -co --exclude-standard -z | tar --null -T - -cf -) | tar -xf - -C "$TMP"
cd "$TMP"
errs() { sed 's/\x1b\[[0-9;]*m//g' "$1" | grep -cE '^(SCRIPT ERROR|Parse Error|ERROR:)' || true; }

bash tools/ci/godot_import.sh i1.log
[ "$(errs i1.log)" = 0 ] || { echo "PROVA KIRMIZI: temiz içe aktarma hata yazdı"; exit 1; }
# (pipefail altında find | head SIGPIPE/141 ile ölür; bu yüzden doğrudan truncate)
find .godot/imported -type f -name '*.ctex' -exec truncate -s 0 {} +
truncate -s 100 .godot/uid_cache.bin
bash tools/ci/godot_import.sh i2.log
[ "$(errs i2.log)" != 0 ] || { echo "PROVA KIRMIZI: bozuk önbellek günlükte görünmedi (sessiz bozuk durum)"; exit 1; }
rm -rf .godot
bash tools/ci/godot_import.sh i3.log
[ "$(errs i3.log)" = 0 ] || { echo "PROVA KIRMIZI: .godot silindikten sonra hâlâ hata"; exit 1; }
echo "PROVA YEŞİL: bozuk önbellek gürültülü (ERROR:) görünür, rm -rf .godot düzeltir"

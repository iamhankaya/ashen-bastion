#!/usr/bin/env bash
# Yerel tam gate: GUT test dosyalarını N parçaya bölüp paralel Godot süreçlerinde koşar, sonra birleştirir (F-066).
# Kullanım: GODOT_BIN=... bash tools/ci/run_gut_parallel.sh N      (depo kökünden; gate.sh adım 6'dan çağrılır)
# Çıkış: 0 yeşil, 1 kırmızı (parça çıkış kodu / USER_LEAK / eksik JUnit / kapsam eksik-yinelenen), 2 kullanım hatası.
# Çıktı: $GATE_DIR/junit.xml (birleşik), gut-K.log, junit-K.xml, gut.log (günlüklerin birleşimi; gate.sh scan_log taraması için).
# Kapsam kanıtı CI'daki ile aynıdır: shard.py check-merge --require-all (her test dosyası tam bir parçada koşmuş olmalı).
# Her süreç KENDİ XDG_DATA_HOME'unu alır: `user://` o dizinde olur; ortak dizinde bir parçanın geçici dosyaları
# (gut_pre_hook/gut_stub_hook taban karşılaştırması) diğer parçada USER_LEAK görünürdü.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
N="${1:-}"
[[ "$N" =~ ^[1-9][0-9]*$ ]] || { echo "kullanım: run_gut_parallel.sh N (N >= 1)" >&2; exit 2; }
[ -n "${GODOT_BIN:-}" ] || { echo "GODOT_BIN tanımlı değil" >&2; exit 2; }
PY="${PYTHON:-python3}"
GATE_DIR="${GATE_DIR:-.gate}"
mkdir -p "$GATE_DIR"

pids=()
for k in $(seq 1 "$N"); do
  "$PY" tools/ci/shard.py config "$k" "$N" "$GATE_DIR/gutconfig-$k.json" --junit "res://$GATE_DIR/junit-$k.xml" || { echo "GATE FAIL: shard.py config $k/$N" >&2; exit 1; }
  mkdir -p "$ROOT/$GATE_DIR/xdg-$k"
  echo "parça $k/$N: $("$PY" tools/ci/shard.py assign "$k" "$N" | wc -l) test dosyası"
  XDG_DATA_HOME="$ROOT/$GATE_DIR/xdg-$k" "$GODOT_BIN" --headless -s res://addons/gut/gut_cmdln.gd -gconfig="res://$GATE_DIR/gutconfig-$k.json" \
    > "$GATE_DIR/gut-$k.log" 2>&1 < /dev/null &
  pids+=($!)
done

bad=0
for k in $(seq 1 "$N"); do
  wait "${pids[$((k - 1))]}"; rc=$?
  tail -n 30 "$GATE_DIR/gut-$k.log"
  if [ $rc -ne 0 ]; then echo "GATE FAIL: GUT parça $k/$N çıkış kodu $rc (bkz. $GATE_DIR/gut-$k.log)" >&2; bad=1; fi
done

cat "$GATE_DIR"/gut-*.log > "$GATE_DIR/gut.log"
if sed 's/\x1b\[[0-9;]*m//g' "$GATE_DIR/gut.log" | grep -E 'USER_LEAK:' > "$GATE_DIR/leak.out"; then
  cat "$GATE_DIR/leak.out" >&2
  echo "GATE FAIL: user:// sızıntısı (USER_LEAK; izin listesi: tools/ci/user_leak_allow.txt)" >&2; bad=1
fi
[ $bad -eq 0 ] || exit 1

for k in $(seq 1 "$N"); do
  [ -f "$GATE_DIR/junit-$k.xml" ] || { echo "GATE FAIL: GUT parça $k/$N JUnit üretmedi" >&2; exit 1; }
done
files=(); for k in $(seq 1 "$N"); do files+=("$GATE_DIR/junit-$k.xml"); done
"$PY" tools/ci/shard.py check-merge --require-all "${files[@]}" || { echo "GATE FAIL: parça kapsamı eksik/yinelenen (tools/ci/shard.py check-merge)" >&2; exit 1; }
"$PY" tools/ci/shard.py merge "$GATE_DIR/junit.xml" "${files[@]}" || { echo "GATE FAIL: JUnit birleştirilemedi" >&2; exit 1; }

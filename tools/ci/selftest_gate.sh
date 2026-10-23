#!/usr/bin/env bash
# Gate öz-testi: gate'in sahte yeşil üretmediğini sınar. Her senaryo çalışma ağacının kopyasında koşar.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILS=0

fresh() { # fresh <ad> : kopya oluşturur, yolu yazar
  local d="$TMP/$1"
  mkdir -p "$d"
  (cd "$ROOT" && tar --exclude=.git --exclude=.godot --exclude=.gate --exclude=build -cf - .) | tar -xf - -C "$d"
  echo "$d"
}
expect() { # expect <ad> <beklenen_kod> <dizin> [env...]
  local name="$1" want="$2" dir="$3"; shift 3
  (cd "$dir" && env "$@" bash tools/gate.sh > "$TMP/$name.log" 2>&1)
  local got=$?
  if [ "$got" = "$want" ]; then echo "OK   $name (çıkış $got)"; else echo "FAIL $name: beklenen $want, gelen $got"; tail -n 15 "$TMP/$name.log"; FAILS=$((FAILS+1)); fi
}

# (0) taban: yeşil
d=$(fresh base); expect "taban yeşil" 0 "$d" X=1

# (a) bozuk .gd
d=$(fresh a); printf 'extends Node\nfunc broken(:\n' > "$d/scripts/sim/zz_broken.gd"; expect "bozuk .gd" 1 "$d" X=1

# (a2) Godot'un reddettiği ama gdtoolkit'in ayrıştırdığı betik (günlük taraması)
d=$(fresh a2)
printf 'extends RefCounted\n\n\nfunc f() -> int:\n\treturn undefined_symbol_xyz\n' > "$d/scripts/sim/zz_semantic.gd"
printf 'extends GutTest\n\n\nfunc test_x() -> void:\n\tvar s = load("res://scripts/sim/zz_semantic.gd")\n\tassert_not_null(s)\n' > "$d/test/unit/test_zz_semantic.gd"
expect "anlamsal ayrıştırma hatası" 1 "$d" X=1

# (b) boş test dizisi
d=$(fresh b); rm -f "$d"/test/unit/*.gd "$d"/test/acceptance/*.gd; expect "boş test dizisi" 1 "$d" X=1

# (c) asgari sayının altı
d=$(fresh c); echo '{"test/unit/test_smoke.gd": 99}' > "$d/tools/gate_min_tests.json"; expect "asgari sayı altı" 1 "$d" X=1

# (d) Stub.todo => test başarısızlığı (stub.gd varsa)
if [ -f "$ROOT/scripts/sim/stub.gd" ]; then
  d=$(fresh d)
  printf 'extends GutTest\n\n\nfunc test_stub() -> void:\n\tStub.todo(&"Selftest.yontem")\n\tassert_true(true)\n' > "$d/test/unit/test_zz_stub.gd"
  expect "Stub.todo başarısızlık" 1 "$d" X=1
fi

# (e) ağ yok simülasyonu
d=$(fresh e); rm -rf "${ASHEN_CACHE_E:=$TMP/emptycache}"; mkdir -p "$ASHEN_CACHE_E"
expect "ağ yok" 3 "$d" ASHEN_CACHE="$ASHEN_CACHE_E" GATE_SIMULATE_NO_NET=1 GODOT_BIN=/nonexistent

[ $FAILS -eq 0 ] && echo "SELFTEST OK" || { echo "SELFTEST FAIL ($FAILS)"; exit 1; }

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
  # Temiz checkout'u taklit: yalnız izlenen + izlenmeyen-ama-ignore-edilmemiş DOSYALAR (boş dizinler taşınmaz)
  (cd "$ROOT" && git ls-files -co --exclude-standard -z | tar --null -T - -cf -) | tar -xf - -C "$d"
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

# (f) pending testler asgari sayıya sayılmaz
d=$(fresh f)
printf 'extends GutTest\n\n\nfunc test_p() -> void:\n\tpending("selftest")\n' > "$d/test/unit/test_zz_pending.gd"
echo '{"test/unit/test_zz_pending.gd": 1}' > "$d/tools/gate_min_tests.json"
expect "pending sayılmaz" 1 "$d" X=1

# (g) GUT'ın saydığı ama çıkış kodunu etkilemeyen hata ([GUT ERROR]): olmayan test dizini
d=$(fresh g); python3 - "$d/.gutconfig.json" <<'PY'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
c["dirs"].append("res://test/yok_boyle_dizin")
json.dump(c, open(p, "w"))
PY
expect "GUT ERROR" 1 "$d" X=1

# (h) veri hatası
d=$(fresh h); python3 - "$d/data/characters/gunslinger.json" <<'PY'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
c["max_hp"] = -1
json.dump(c, open(p, "w"))
PY
expect "veri hatası" 1 "$d" X=1

# (i) to_upper yasağı
d=$(fresh i); printf 'extends RefCounted\n\n\nfunc f(s: String) -> String:\n\treturn s.to_upper()\n' > "$d/scripts/sim/zz_upper.gd"
expect "to_upper" 1 "$d" X=1

# (e) ağ yok simülasyonu
d=$(fresh e); rm -rf "${ASHEN_CACHE_E:=$TMP/emptycache}"; mkdir -p "$ASHEN_CACHE_E"
expect "ağ yok" 3 "$d" ASHEN_CACHE="$ASHEN_CACHE_E" GATE_SIMULATE_NO_NET=1 GODOT_BIN=/nonexistent

[ $FAILS -eq 0 ] && echo "SELFTEST OK" || { echo "SELFTEST FAIL ($FAILS)"; exit 1; }

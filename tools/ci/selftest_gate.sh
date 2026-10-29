#!/usr/bin/env bash
# Gate öz-testi: gate'in sahte yeşil üretmediğini sınar. Her senaryo çalışma ağacının kopyasında koşar.
# Kullanım: selftest_gate.sh [--group N] [--list]
#   --group N : yalnız GROUP tablosunda N numaralı gruba atanmış senaryolar (CI matrisi; F-028). Verilmezse hepsi.
#   --list    : "<senaryo> <grup>" satırlarını yazar ve çıkar.
# Senaryo -> grup tablosu AŞAĞIDADIR (GROUP[...]=N); her senaryo `scenario_<ad>` işlevidir ve tam bir grupta olmalıdır
# (başlangıçta denetlenir; uyumsuzluk çıkış 2). ci.yml selftest matrisi group değerleri = tablodaki gruplar.
# Süreler (S0 ölçümü, docs/dev/v2.0-s0-measure.md §2): tam-gate senaryosu ≈ 340 s, hafifler 1–40 s.
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

# --- senaryo -> grup tablosu (en uzun grup ≈ 409 s; tam-gate senaryoları ayrı gruplarda) ---------------------------------
declare -A GROUP=()
GROUP[taban_yesil]=1
GROUP[bozuk_gd]=1
GROUP[bos_test_dizisi]=1
GROUP[anlamsal_hata]=2
GROUP[to_upper]=2
GROUP[veri_hatasi]=2
GROUP[asgari_sayi_alti]=3
GROUP[stub_todo]=4
GROUP[pending_sayilmaz]=5
GROUP[ag_yok]=5
GROUP[gut_error]=6

scenario_taban_yesil() { local d; d=$(fresh base); expect "taban yeşil" 0 "$d" X=1; }

scenario_bozuk_gd() { # bozuk .gd
  local d; d=$(fresh a); printf 'extends Node\nfunc broken(:\n' > "$d/scripts/sim/zz_broken.gd"
  expect "bozuk .gd" 1 "$d" X=1
}

scenario_anlamsal_hata() { # Godot'un reddettiği ama gdtoolkit'in ayrıştırdığı betik (günlük taraması)
  local d; d=$(fresh a2)
  printf 'extends RefCounted\n\n\nfunc f() -> int:\n\treturn undefined_symbol_xyz\n' > "$d/scripts/sim/zz_semantic.gd"
  printf 'extends GutTest\n\n\nfunc test_x() -> void:\n\tvar s = load("res://scripts/sim/zz_semantic.gd")\n\tassert_not_null(s)\n' > "$d/test/unit/test_zz_semantic.gd"
  expect "anlamsal ayrıştırma hatası" 1 "$d" X=1
}

scenario_bos_test_dizisi() {
  local d; d=$(fresh b); rm -f "$d"/test/unit/*.gd "$d"/test/acceptance/*.gd
  expect "boş test dizisi" 1 "$d" X=1
}

scenario_asgari_sayi_alti() {
  local d; d=$(fresh c); echo '{"test/unit/test_smoke.gd": 99}' > "$d/tools/gate_min_tests.json"
  expect "asgari sayı altı" 1 "$d" X=1
}

scenario_stub_todo() { # Stub.todo => test başarısızlığı (stub.gd varsa; yoksa senaryo atlanır ama grup boş kalmaz)
  if [ ! -f "$ROOT/scripts/sim/stub.gd" ]; then echo "ATLA stub.gd yok"; return; fi
  local d; d=$(fresh d)
  printf 'extends GutTest\n\n\nfunc test_stub() -> void:\n\tStub.todo(&"Selftest.yontem")\n\tassert_true(true)\n' > "$d/test/unit/test_zz_stub.gd"
  expect "Stub.todo başarısızlık" 1 "$d" X=1
}

scenario_pending_sayilmaz() { # pending testler asgari sayıya sayılmaz
  local d; d=$(fresh f)
  printf 'extends GutTest\n\n\nfunc test_p() -> void:\n\tpending("selftest")\n' > "$d/test/unit/test_zz_pending.gd"
  echo '{"test/unit/test_zz_pending.gd": 1}' > "$d/tools/gate_min_tests.json"
  expect "pending sayılmaz" 1 "$d" X=1
}

scenario_gut_error() { # GUT'ın saydığı ama çıkış kodunu etkilemeyen hata ([GUT ERROR]): olmayan test dizini
  local d; d=$(fresh g); python3 - "$d/.gutconfig.json" <<'PY'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
c["dirs"].append("res://test/yok_boyle_dizin")
json.dump(c, open(p, "w"))
PY
  expect "GUT ERROR" 1 "$d" X=1
}

scenario_veri_hatasi() {
  local d; d=$(fresh h); python3 - "$d/data/characters/gunslinger.json" <<'PY'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
c["max_hp"] = -1
json.dump(c, open(p, "w"))
PY
  expect "veri hatası" 1 "$d" X=1
}

scenario_to_upper() {
  local d; d=$(fresh i); printf 'extends RefCounted\n\n\nfunc f(s: String) -> String:\n\treturn s.to_upper()\n' > "$d/scripts/sim/zz_upper.gd"
  expect "to_upper" 1 "$d" X=1
}

scenario_ag_yok() { # ağ yok simülasyonu
  local d; d=$(fresh e); rm -rf "${ASHEN_CACHE_E:=$TMP/emptycache}"; mkdir -p "$ASHEN_CACHE_E"
  expect "ağ yok" 3 "$d" ASHEN_CACHE="$ASHEN_CACHE_E" GATE_SIMULATE_NO_NET=1 GODOT_BIN=/nonexistent
}

# --- tutarlılık: tablo <-> tanımlı senaryolar -----------------------------------------------------------------------------
defined=$(declare -F | sed -n 's/^declare -f scenario_//p' | sort)
listed=$(printf '%s\n' "${!GROUP[@]}" | sort)
if [ "$defined" != "$listed" ]; then
  echo "SELFTEST TABLO HATASI: GROUP tablosu ile scenario_* işlevleri birebir değil" >&2
  diff <(echo "$listed") <(echo "$defined") >&2
  exit 2
fi

ONLY=""
LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --group) ONLY="${2:-}"; shift 2 ;;
    --list) LIST=1; shift ;;
    *) echo "bilinmeyen bağımsız değişken: $1" >&2; exit 2 ;;
  esac
done
if [ "$LIST" = "1" ]; then
  for n in $(printf '%s\n' "${!GROUP[@]}" | sort); do echo "$n ${GROUP[$n]}"; done
  exit 0
fi
if [ -n "$ONLY" ] && ! printf '%s\n' "${GROUP[@]}" | grep -qx "$ONLY"; then
  echo "SELFTEST: grup $ONLY tabloda yok" >&2
  exit 2
fi

ran=0
for n in $(printf '%s\n' "${!GROUP[@]}" | sort); do
  if [ -z "$ONLY" ] || [ "${GROUP[$n]}" = "$ONLY" ]; then
    echo "--- senaryo: $n (grup ${GROUP[$n]})"
    "scenario_$n"
    ran=$((ran+1))
  fi
done
echo "SELFTEST senaryo sayısı: $ran"

[ $FAILS -eq 0 ] && echo "SELFTEST OK" || { echo "SELFTEST FAIL ($FAILS)"; exit 1; }

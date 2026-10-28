#!/usr/bin/env bash
# Gate öz-testi: gate'in sahte yeşil üretmediğini sınar. Her senaryo çalışma ağacının kopyasında koşar.
# Kullanım: selftest_gate.sh [--group N] [--list]
#   --group N : yalnız GROUP tablosunda N numaralı gruba atanmış senaryolar (CI matrisi; F-028). Verilmezse hepsi.
#   --list    : "<senaryo> <grup>" satırlarını yazar ve çıkar.
#   --scenario AD : yalnız o senaryo (hata ayıklama / prova).
# Ortam: SELFTEST_SKIP_TABAN=1 yalnız `taban_yesil` senaryosunu atlar (H1: ci.yml yol süzgeci; negatif senaryolar HER ZAMAN koşar).
#        SELFTEST_GODOT_CACHE=<.godot> (varsayılan $ROOT/.godot) içindeki imported/ + uid_cache.bin her senaryo kopyasına aktarılır (H2).
# Senaryo -> grup tablosu AŞAĞIDADIR (GROUP[...]=N); her senaryo `scenario_<ad>` işlevidir ve tam bir grupta olmalıdır
# (başlangıçta denetlenir; uyumsuzluk çıkış 2). ci.yml selftest matrisi group değerleri = tablodaki gruplar.
# Süreler (S0 ölçümü, docs/dev/v2.0-s0-measure.md §2): tam-gate senaryosu ≈ 340 s, hafifler 1–40 s.
set -uo pipefail
# SELFTEST_ROOT yalnız prova içindir (tools/ci/tests/test_infra_selftest_cache.py): sahte depo ile senaryo mekaniğini sınar.
ROOT="${SELFTEST_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILS=0

fresh() { # fresh <ad> : kopya oluşturur, yolu yazar
  local d="$TMP/$1"
  mkdir -p "$d"
  # Temiz checkout'u taklit: yalnız izlenen + izlenmeyen-ama-ignore-edilmemiş DOSYALAR (boş dizinler taşınmaz)
  (cd "$ROOT" && git ls-files -co --exclude-standard -z | tar --null -T - -cf -) | tar -xf - -C "$d"
  # H2: .godot gitignore'ludur, kopyaya girmez; yalnız imported/ + uid_cache.bin AÇIKÇA aktarılır (class cache aktarılmaz:
  # gate.sh her koşuda --import çalıştırır ve sınıf önbelleğini kendisi üretir; mutasyon sonrası import doğrulaması korunur).
  local gc="${SELFTEST_GODOT_CACHE:-$ROOT/.godot}"
  if [ -d "$gc/imported" ]; then
    mkdir -p "$d/.godot" && cp -a "$gc/imported" "$d/.godot/imported"
    [ -f "$gc/uid_cache.bin" ] && cp -a "$gc/uid_cache.bin" "$d/.godot/uid_cache.bin"
  fi
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
GROUP[test_kimligi_kaybi]=3
GROUP[stub_todo]=4
GROUP[kosmayan_test]=5
GROUP[ag_yok]=5
GROUP[gut_error]=6

scenario_taban_yesil() {
  if [ "${SELFTEST_SKIP_TABAN:-0}" = "1" ]; then echo "SKIPPED_BY_FILTER taban_yesil (ci.yml yol süzgeci: altyapı yolu değişmedi)"; return; fi
  local d; d=$(fresh base); expect "taban yeşil" 0 "$d" X=1
}

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

scenario_test_kimligi_kaybi() { # tabandaki bir test kimliği HEAD'de yok (silinmiş/yeniden adlandırılmış): kimlik kapısı LOST der
  local d base; d=$(fresh c); base="$TMP/base_declared_c.txt"
  # git'siz kopya: taban kimlikleri özgün (mutasyonsuz) ağaçtan üretilir, gate.sh'a GATE_BASE_DECLARED ile verilir
  python3 - "$ROOT" "$base" <<'PY'
import sys
sys.path.insert(0, sys.argv[1] + "/tools/ci")
import check_test_ids as T
open(sys.argv[2], "w", encoding="utf-8").write("
".join(sorted(T.collect_declared(T.FsSource(sys.argv[1])).ids)) + "
")
PY
  python3 - "$d/test/unit/test_art_loader.gd" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
n = re.sub(r"^func test_\w+\(", "func renamed_by_selftest(", t, count=1, flags=re.M)
assert n != t, "selftest: test_art_loader.gd'de test işlevi yok"
open(p, "w", encoding="utf-8").write(n)
PY
  expect "test kimliği kaybı" 1 "$d" GATE_BASE_DECLARED="$base"
  grep -q "test_art_loader.gd::.*LOST (declared kayboldu)" "$TMP/test kimliği kaybı.log" || { echo "FAIL test kimliği kaybı: günlükte LOST yok (başka nedenle kırmızı)"; FAILS=$((FAILS+1)); }
}

scenario_stub_todo() { # Stub.todo => test başarısızlığı (stub.gd varsa; yoksa senaryo atlanır ama grup boş kalmaz)
  if [ ! -f "$ROOT/scripts/sim/stub.gd" ]; then echo "ATLA stub.gd yok"; return; fi
  local d; d=$(fresh d)
  printf 'extends GutTest\n\n\nfunc test_stub() -> void:\n\tStub.todo(&"Selftest.yontem")\n\tassert_true(true)\n' > "$d/test/unit/test_zz_stub.gd"
  expect "Stub.todo başarısızlık" 1 "$d" X=1
}

scenario_kosmayan_test() { # bildirilen ama koşuda pending olan test (dilim dışı): kimlik kapısı MISSING der
  local d; d=$(fresh f)
  printf 'extends GutTest


func test_p() -> void:
	pending("selftest")
' > "$d/test/unit/test_zz_pending.gd"
  expect "koşmayan test" 1 "$d" X=1
  grep -q "MISSING" "$TMP/koşmayan test.log" || { echo "FAIL koşmayan test: günlükte MISSING yok (başka nedenle kırmızı)"; FAILS=$((FAILS+1)); }
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
ONE=""
LIST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --group) ONLY="${2:-}"; shift 2 ;;
    --list) LIST=1; shift ;;
    --scenario) ONE="${2:-}"; shift 2 ;;
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

if [ -n "$ONE" ] && [ -z "${GROUP[$ONE]:-}" ]; then echo "SELFTEST: senaryo $ONE tabloda yok" >&2; exit 2; fi
ran=0
for n in $(printf '%s\n' "${!GROUP[@]}" | sort); do
  if [ -n "$ONE" ] && [ "$n" != "$ONE" ]; then continue; fi
  if [ -z "$ONLY" ] || [ "${GROUP[$n]}" = "$ONLY" ]; then
    echo "--- senaryo: $n (grup ${GROUP[$n]})"
    "scenario_$n"
    ran=$((ran+1))
  fi
done
echo "SELFTEST senaryo sayısı: $ran"

[ $FAILS -eq 0 ] && echo "SELFTEST OK" || { echo "SELFTEST FAIL ($FAILS)"; exit 1; }

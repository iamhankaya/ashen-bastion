#!/usr/bin/env python3
"""Kuru deneme (prova fazı): sahte karakter/mod/başarım yalnız YENİ dosyalarla eklenir; mevcut dosya değişirse ya da sabit listeli test
kırılırsa ilgili R dilimine geri iş çıkar.

  prova_dry_run.py --root <geçici worktree> [--scenario char|mode|ach_data|ach_reducer|all] [--godot BIN] [--gut-dirs unit,acceptance]
                   [--no-run] [--with-family]

Senaryolar (her biri temiz ağaçta, birbirinden bağımsız):
  char         data/characters/zz_dry.json + data/skills/zz_dry_cut.json (havuz zz_dry; davranış mevcut ruzgar_kesigi)
  mode         data/run_modes/zz_dry.json
  ach_data     data/achievements/zz_dry_kills.json (yerleşik toplamlı metrik; olay enemy_killed)
  ach_reducer  data/achievements/zz_dry_reducer.json + scripts/ctrl/achievement_reducers/zz_dry_reducer.gd (yeni reducer DOSYASI)
  Aile kaydı (data/achievements.json satırı) varsayılan olarak eklenmez: o MEVCUT bir dosyayı değiştirir ve kendi başına bulgudur
  (--with-family ile ach_data'ya eklenir, "degisen" sayısında görünür).

Çıktı (stdout): `SCENARIO <ad>: yeni=<n> degisen=<n> {...}`, `VALIDATE <ad>: ok|hata`, `GUT <ad> <dizin>: <geçen>/<toplam> kırık=<n>`,
`FAIL <ad>: <dosya> :: <test>`. Güvenlik: --root repo kökü olamaz; git worktree'si ve geçici dizin altında olmalı (geri alma yalnız orada).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ANSI = re.compile(r"\x1b\[[0-9;]*m")
SCENARIOS = ("char", "mode", "ach_data", "ach_reducer")

REDUCER_GD = """class_name ZzDryReducer
extends AchievementReducer
## Kuru deneme reducer'ı (prova): her öldürmede değeri 1 artırır. Yalnız prova ağacında bulunur.


func on_event(ev: StringName, _payload: Dictionary, state: Dictionary) -> void:
	if ev == &"enemy_killed":
		state["value"] = int(state["value"]) + 1


func reset(state: Dictionary) -> void:
	state["value"] = 0
"""


def _load(root: Path, rel: str):
    return json.loads((root / rel).read_text(encoding="utf-8"))


def _dump(obj, indent=2) -> str:
    return json.dumps(obj, indent=indent, ensure_ascii=False) + "\n"


def scenario_files(root: Path, name: str) -> dict[str, str]:
    """{göreli yol: içerik}; kaynaklar kökteki gerçek örneklerden türetilir (şema değişirse örnek de değişir)."""
    if name == "char":
        c = _load(root, "data/characters/zyfen.json")
        c.update(id="zz_dry", name="ZzDry", display_upper="ZZDRY", order=99, starting_skill="zz_dry_cut")
        s = _load(root, "data/skills/ruzgar_kesigi.json")
        s.update(id="zz_dry_cut", name="ZzDry Kesik", pool="zz_dry")
        return {"data/characters/zz_dry.json": _dump(c), "data/skills/zz_dry_cut.json": _dump(s)}
    if name == "mode":
        m = _load(root, "data/run_modes/quick.json")
        m.update(id="zz_dry", order=9, name="ZzDry", label="ZZDRY")
        return {"data/run_modes/zz_dry.json": _dump(m, 1)}
    if name == "ach_data":
        a = _load(root, "data/achievements/run_kills.json")
        a.update(stat="zz_dry_kills", order=900, persist={"total": None, "best": None})
        return {"data/achievements/zz_dry_kills.json": _dump(a)}
    if name == "ach_reducer":
        a = _load(root, "data/achievements/run_clean_secs.json")
        a.update(stat="zz_dry_reducer", order=901, persist={"total": None, "best": None}, reducer="ZzDryReducer", events=["enemy_killed"])
        a.pop("poll", None)
        return {"data/achievements/zz_dry_reducer.json": _dump(a), "scripts/ctrl/achievement_reducers/zz_dry_reducer.gd": REDUCER_GD}
    raise SystemExit(f"bilinmeyen senaryo: {name}")


def family_edit(root: Path) -> str:
    """Aile kaydı eklenmiş data/achievements.json (MEVCUT dosya değişir: bulguyu göstermek için)."""
    d = _load(root, "data/achievements.json")
    d.append({"id": "zz_dry_fam", "name": "ZZ DRY", "desc": "Sahte.", "stat": "zz_dry_kills", "scope": "run", "steps": [5, 10], "group": "THE CULLING"})
    return _dump(d)


def classify_status(porcelain: str) -> tuple[list[str], list[str]]:
    """git status --porcelain çıktısı -> (yeni, değişen). `??`/`A ` yeni; `M`, `D`, `R` değişen sayılır."""
    new: list[str] = []
    changed: list[str] = []
    for line in porcelain.splitlines():
        if not line.strip():
            continue
        code, path = line[:2], line[3:].strip().strip('"')
        (new if code in ("??", "A ", " A", "AM") else changed).append(path)
    return sorted(new), sorted(changed)


def parse_gut_failures(log: str) -> tuple[list[str], dict[str, int]]:
    """GUT günlüğünden ['dosya :: test'] ve toplamlar. `[Failed]` satırı son görülen `* test_` adına bağlanır."""
    text = ANSI.sub("", log)
    fails: list[str] = []
    cur_file = cur_test = ""
    for line in text.splitlines():
        if line.startswith("res://"):
            cur_file = line.strip()
        elif line.startswith(("* test_", "- test_")):
            cur_test = line[2:].strip()
        elif "[Failed]" in line:
            item = f"{cur_file} :: {cur_test}"
            if item not in fails:
                fails.append(item)
    totals: dict[str, int] = {}
    for key, label in (("tests", "Tests"), ("passing", "Passing Tests"), ("failing", "Failing Tests")):
        m = re.search(rf"^{label}\s+(\d+)", text, re.M)
        if m:
            totals[key] = int(m.group(1))
    return fails, totals


def git(root: Path, *args: str) -> str:
    r = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        raise SystemExit(f"git {' '.join(args)} başarısız: {r.stderr.strip()}")
    return r.stdout


def check_root(root: Path) -> Path:
    """Geri alma yalnız geçici dizindeki ayrı worktree'de: repo kökü/altı, geçici dizin dışı ya da git'siz kök reddedilir."""
    real = root.resolve()
    if real == REPO.resolve() or REPO.resolve() in real.parents:
        raise SystemExit(f"--root repo kökü ya da altı olamaz: {real}")
    tmp = Path(tempfile.gettempdir()).resolve()
    if tmp not in real.parents and os.environ.get("PROVA_ALLOW_ROOT") != str(real):
        raise SystemExit(f"--root geçici dizin altında olmalı ({tmp}); başka yer için PROVA_ALLOW_ROOT={real}")
    if not (real / ".git").exists():
        raise SystemExit(f"--root bir git worktree'si değil: {real}")
    return real


def reset_tree(root: Path, created: list[str]) -> None:
    """Yalnız senaryonun yazdıklarını geri alır: izlenen veri dosyaları checkout, oluşturulan dosyalar silinir.
    (İçe aktarmanın ürettiği izlenmeyen .uid dosyalarına dokunulmaz; durum farkı başlangıç görüntüsüne göre alınır.)"""
    git(root, "checkout", "-q", "--", "data")
    for rel in created:
        (root / rel).unlink(missing_ok=True)


def run_godot(godot: str, root: Path, *args: str, timeout: int = 1800) -> str:
    r = subprocess.run([godot, "--headless", *args], cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
    return (r.stdout or "") + (r.stderr or "")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", required=True)
    ap.add_argument("--scenario", default="all")
    ap.add_argument("--godot", default=os.environ.get("GODOT_BIN", ""))
    ap.add_argument("--gut-dirs", default="unit")
    ap.add_argument("--with-family", action="store_true", help="ach_data'ya data/achievements.json aile kaydını da ekle (mevcut dosyayı değiştirir)")
    ap.add_argument("--no-run", action="store_true", help="yalnız dosya kümesini ve git durumunu raporla (Godot yok)")
    a = ap.parse_args(argv)
    root = check_root(Path(a.root))
    names = list(SCENARIOS) if a.scenario == "all" else [a.scenario]
    if not a.no_run:
        if not a.godot:
            raise SystemExit("Godot yolu yok (--godot ya da GODOT_BIN)")
        run_godot(a.godot, root, "--import")  # senaryodan ÖNCE: üretilen .uid/.import ön duruma girer, deltada görünmez
    created: list[str] = []
    base_new, base_changed = classify_status(git(root, "status", "--porcelain"))
    for name in names:
        reset_tree(root, created)
        created = []
        for rel, body in scenario_files(root, name).items():
            p = root / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(body, encoding="utf-8", newline="\n")
            created.append(rel)
        if a.with_family and name == "ach_data":
            (root / "data/achievements.json").write_text(family_edit(root), encoding="utf-8", newline="\n")
        new, changed = classify_status(git(root, "status", "--porcelain"))
        new, changed = [x for x in new if x not in base_new], [x for x in changed if x not in base_changed]
        print(f"SCENARIO {name}: yeni={len(new)} degisen={len(changed)} {json.dumps({'yeni': new, 'degisen': changed}, ensure_ascii=False)}")
        if a.no_run:
            continue
        run_godot(a.godot, root, "--import")  # yeni class_name (reducer .gd) global sınıf önbelleğine ancak içe aktarmayla girer (CI'da gate adım 2)
        v = run_godot(a.godot, root, "-s", "res://tools/validate_data.gd")
        verr = [l for l in ANSI.sub("", v).splitlines() if "VERİ HATASI" in l]
        print(f"VALIDATE {name}: {'ok' if not verr else 'hata'}")
        for l in verr:
            print(f"VALIDATE_ERR {name}: {l.strip()}")
        for d in [x for x in a.gut_dirs.split(",") if x]:
            log = run_godot(a.godot, root, "-s", "res://addons/gut/gut_cmdln.gd", f"-gdir=res://test/{d}", "-ginclude_subdirs", "-gexit", "-glog=1")
            fails, tot = parse_gut_failures(log)
            print(f"GUT {name} {d}: {tot.get('passing', '?')}/{tot.get('tests', '?')} kırık={len(fails)}")
            for f in fails:
                print(f"FAIL {name}: {f}")
        sys.stdout.flush()
    reset_tree(root, created)
    return 0


if __name__ == "__main__":
    sys.exit(main())

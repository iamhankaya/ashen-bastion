#!/usr/bin/env python3
"""Seçici koşu eşlemesinin geriye dönük sınaması (F-044): geçmiş commit'lerin diff'i için seçimi yeniden hesaplar.

  backtest_map.py [--count 40] [--rev HEAD] [--no-merges]

Her first-parent commit C için (--no-merges: tek tek işçi commit'leri): eşleme C ağacından kurulur (git show; checkout yok), seçim `C^1..C` diff'ine uygulanır.
Denetlenenler (ihlal => çıkış 1):
  * C'de eklenen/değişen her test dosyası seçimde (FULL değilse);
  * C'de değişen eşlenmiş kaynağa (sınıf adı/yol) DOĞRUDAN başvuran her test seçimde (FULL değilse).
Tablo: commit, değişen dosya, sonuç (FULL / seçilen test sayısı / toplam). Tam suite'te kırmızıya dönen testin seçimde olduğunu
gösteren ampirik sınama (kasıtlı kırma) için docs/dev/ci-speed.md §Doğrulama.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_map  # noqa: E402

ROOT = test_map.ROOT


def git(*a: str) -> str:
    return subprocess.run(["git", *a], cwd=ROOT, capture_output=True, text=True, check=True).stdout


def main(argv: list[str]) -> int:
    count = int(argv[argv.index("--count") + 1]) if "--count" in argv else 40
    rev = argv[argv.index("--rev") + 1] if "--rev" in argv else "HEAD"
    flags = ["--no-merges"] if "--no-merges" in argv else ["--first-parent"]
    commits = git("rev-list", *flags, f"-n{count}", rev).split()
    bad = 0
    rows = []
    for c in commits:
        parents = git("rev-list", "--parents", "-n1", c).split()[1:]
        if not parents:
            continue
        changed = [f for f in git("diff", "--name-only", f"{parents[0]}", c).splitlines() if f]
        if not changed:
            continue
        try:
            m = test_map.build(ROOT, c)
        except (KeyError, subprocess.CalledProcessError):
            continue  # proje öncesi commit (project.godot/test dizini yok)
        sel = test_map.select(changed, m)
        total = len(m["tests"])
        if sel == "FULL":
            rows.append((c[:7], len(changed), "FULL", total))
            continue
        problems = []
        tests = set(m["tests"])
        for f in changed:
            if f in tests and f not in sel:
                problems.append(f"değişen test seçilmedi: {f}")
        tree = test_map.Tree(ROOT, c)
        for f in changed:
            if f not in m["files"]:
                continue
            cls = re.search(r"^\s*class_name\s+(\w+)", tree.read(f), re.M) if f.endswith(".gd") else None
            for t in m["tests"]:
                src = tree.read(t)
                if (cls and re.search(rf"\b{cls.group(1)}\b", test_map.strip_comments(src))) or f"res://{f}" in src:
                    if t not in sel:
                        problems.append(f"{f} değişti, doğrudan başvuran {t} seçilmedi")
        bad += bool(problems)
        rows.append((c[:7], len(changed), f"{len(sel)}/{total}" + (" İHLAL" if problems else ""), total))
        for p in problems:
            print("BACKTEST_ERROR:", c[:7], p, file=sys.stderr)
    print("commit   değişen  seçim")
    for c, n, r, _ in rows:
        print(f"{c}  {n:6d}  {r}")
    full = sum(1 for r in rows if r[2] == "FULL")
    print(f"toplam {len(rows)} commit: FULL {full}, kısmi {len(rows) - full}, ihlal {bad}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

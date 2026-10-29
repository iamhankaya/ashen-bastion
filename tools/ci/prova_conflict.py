#!/usr/bin/env python3
"""Çakışma provası (prova fazı): iki paralel dalda aynı anda ikişer sahte karakter/mod/başarım (+ yalnız-eklemeli kayıt satırı) -> birleştirme.

  prova_conflict.py --clone <boş geçici dizin>      # depoyu --shared klonlar; yerel dallar yalnız klonda, hiçbir yere push edilmez

Her dal: 2 karakter (+beceri), 2 mod, 2 başarım metriği (biri reducer dosyalı) ve yalnız-eklemeli listelere (moved_tests, removed_tests,
pending_allowed, baseline_changes) kendi satırlarını ekler. Beklenen: A + B birleşimi ÇAKIŞMASIZ. Kontrol: `.gitattributes`'taki
merge=union kaldırılırsa listelerde ekleme/ekleme çakışması çıkmalı (union'ın gerçekten iş yaptığının kanıtı).
Çıktı: `MERGE <ad>: temiz|ÇAKIŞMA [dosyalar]`; çıkış 0 yalnız asıl birleşim temiz VE kontrol çakışmalıysa.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
APPEND_ONLY = ("moved_tests.txt", "removed_tests.txt", "pending_allowed.txt", "baseline_changes.txt")


def git(cwd: Path, *args: str, check=True) -> subprocess.CompletedProcess:
    r = subprocess.run(["git", "-C", str(cwd), *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if check and r.returncode != 0:
        raise SystemExit(f"git {' '.join(args)}: {r.stdout}{r.stderr}")
    return r


def check_clone_dir(d: Path) -> Path:
    real = d.resolve()
    tmp = Path(tempfile.gettempdir()).resolve()
    if real == REPO.resolve() or REPO.resolve() in real.parents or tmp not in real.parents:
        raise SystemExit(f"--clone geçici dizin altında ve repo dışında olmalı: {real}")
    if real.exists() and any(real.iterdir()):
        raise SystemExit(f"--clone boş olmalı: {real}")
    return real


def make_branch(clone: Path, tag: str, base: str) -> None:
    git(clone, "checkout", "-q", "-B", f"prova/{tag}", base)
    for n in (1, 2):
        cid, mid, sid = f"zz_{tag}{n}", f"zz_{tag}m{n}", f"zz_{tag}_kills{n}"
        (clone / "data/characters" / f"{cid}.json").write_text(f'{{"id": "{cid}", "name": "{cid}", "order": {90 + n}}}\n', encoding="utf-8")
        (clone / "data/skills" / f"{cid}_cut.json").write_text(f'{{"id": "{cid}_cut", "pool": "{cid}"}}\n', encoding="utf-8")
        (clone / "data/run_modes" / f"{mid}.json").write_text(f'{{"id": "{mid}", "order": {8 + n}}}\n', encoding="utf-8")
        (clone / "data/achievements" / f"{sid}.json").write_text(f'{{"stat": "{sid}", "order": {900 + n}}}\n', encoding="utf-8")
    (clone / "scripts/ctrl/achievement_reducers" / f"zz_{tag}_reducer.gd").write_text(f"class_name Zz{tag.upper()}Reducer\nextends AchievementReducer\n", encoding="utf-8")
    for name in APPEND_ONLY:
        p = clone / "tools/ci" / name
        with open(p, "a", encoding="utf-8", newline="\n") as f:
            f.write(f"zz/{tag}_kayit.gd | prova satiri {tag} | T-prova\n")
    git(clone, "add", "-A")
    git(clone, "-c", "user.email=prova@example.invalid", "-c", "user.name=prova", "commit", "-q", "-m", f"prova {tag}")


def try_merge(clone: Path, a: str, b: str) -> tuple[bool, list[str]]:
    git(clone, "checkout", "-q", "--detach", f"prova/{a}")
    r = git(clone, "-c", "user.email=prova@example.invalid", "-c", "user.name=prova", "merge", "--no-edit", f"prova/{b}", check=False)
    conflicts = git(clone, "diff", "--name-only", "--diff-filter=U").stdout.split()
    if r.returncode != 0:
        git(clone, "merge", "--abort", check=False)
    return r.returncode == 0, conflicts


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--clone", required=True)
    ap.add_argument("--base", default="HEAD")
    a = ap.parse_args(argv)
    clone = check_clone_dir(Path(a.clone))
    subprocess.run(["git", "clone", "-q", "--shared", "--no-checkout", str(REPO), str(clone)], check=True)
    base = git(REPO, "rev-parse", a.base).stdout.strip()
    git(clone, "checkout", "-q", "--detach", base)
    git(clone, "config", "core.autocrlf", "false")
    make_branch(clone, "a", base)
    make_branch(clone, "b", base)
    ok, conf = try_merge(clone, "a", "b")
    print(f"MERGE a+b: {'temiz' if ok else 'ÇAKIŞMA ' + ','.join(conf)}")
    # kontrol: union kaldırılmış .gitattributes ile (dal ucunda) aynı birleşim çakışmalı
    attrs = clone / ".gitattributes"
    text = attrs.read_text(encoding="utf-8")
    stripped = re.sub(r"^tools/ci/\S+ merge=union\n", "", text, flags=re.M)
    git(clone, "checkout", "-q", "--detach", "prova/a")
    attrs.write_text(stripped, encoding="utf-8", newline="\n")
    git(clone, "add", ".gitattributes")
    git(clone, "-c", "user.email=prova@example.invalid", "-c", "user.name=prova", "commit", "-q", "-m", "kontrol: union yok")
    git(clone, "branch", "-f", "prova/a_nounion")
    ok2, conf2 = try_merge(clone, "a_nounion", "b")
    print(f"MERGE kontrol(union yok): {'temiz' if ok2 else 'ÇAKIŞMA ' + ','.join(conf2)}")
    return 0 if ok and not ok2 else 1


if __name__ == "__main__":
    sys.exit(main())

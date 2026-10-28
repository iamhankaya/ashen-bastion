#!/usr/bin/env python3
"""Tek tip satır tavanı (S-budget): scripts/**/*.gd dosyaları --max satırı (varsayılan 800 = gdlint 1000 x 0,8) aşamaz.

  check_line_budget.py [--max 800] [--exceptions F] [--base REF] [--root DIR]

Geçiş istisnası: tools/ci/line_budget_exceptions.txt, satır biçimi `yol | tavan` ('#' yorum). Azalan (ratchet) kayıttır:
  LINE_BUDGET: <yol>: <n> > <tavan>                 dosya kendi tavanını (istisna değeri ya da --max) aşıyor
  LINE_BUDGET_STALE: <yol>: ...                     dosya zaten <= --max (ya da yok); satır silinmeli
  LINE_BUDGET_RAISED: <yol>: ...                    --base REF'e göre değer arttı ya da yeni satır eklendi (union yok)
  LINE_BUDGET_FORMAT: ...                           bozuk istisna satırı
Satır sayısı `wc -l` ile aynıdır (\\n sayısı). .claude/, .godot/, .gate/, addons/, build/ ve ajan worktree dizinleri taranmaz.
Hata: stderr + çıkış 1.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
EXCEPTIONS = "tools/ci/line_budget_exceptions.txt"
SKIP_DIRS = {".claude", ".godot", ".gate", "addons", "build"}


def parse_exceptions(text: str) -> dict:
    """{yol: tavan}; bozuk satır {ham_satır: None} olarak kalır (check FORMAT hatası verir)."""
    out: dict = {}
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        path, sep, val = (p.strip() for p in line.partition("|"))
        out[path if sep and val.isdigit() else line] = int(val) if sep and val.isdigit() else None
    return out


def line_count(p: Path) -> int:
    return p.read_bytes().count(b"\n")


def scan(root: Path) -> dict:
    out = {}
    base = root / "scripts"
    for p in base.rglob("*.gd") if base.is_dir() else []:
        rel = p.relative_to(root)
        if SKIP_DIRS & set(rel.parts):
            continue
        out[rel.as_posix()] = line_count(p)
    return out


def check(root: Path, max_lines: int, exceptions: dict, base: dict | None) -> list[str]:
    counts = scan(root)
    errs: list[str] = []
    for path in sorted(counts):
        ceiling = exceptions.get(path) or max_lines
        if counts[path] > ceiling:
            errs.append(f"LINE_BUDGET: {path}: {counts[path]} > {ceiling}")
    for path in sorted(exceptions):
        val = exceptions[path]
        if val is None:
            errs.append(f"LINE_BUDGET_FORMAT: '{path}': beklenen biçim `yol | tavan`")
        elif path not in counts:
            errs.append(f"LINE_BUDGET_STALE: {path}: dosya yok, satırı sil")
        elif counts[path] <= max_lines:
            errs.append(f"LINE_BUDGET_STALE: {path}: {counts[path]} <= {max_lines}, satırı sil")
        if base is not None and val is not None:
            if path not in base:
                errs.append(f"LINE_BUDGET_RAISED: {path}: yeni istisna (base'de yok)")
            elif base[path] is not None and val > base[path]:
                errs.append(f"LINE_BUDGET_RAISED: {path}: {base[path]} -> {val}")
    return errs


def base_exceptions(root: Path, ref: str) -> dict | None:
    r = subprocess.run(["git", "-C", str(root), "show", f"{ref}:{EXCEPTIONS}"], capture_output=True, text=True)
    return parse_exceptions(r.stdout) if r.returncode == 0 else None  # base'de dosya yok = kayıt bu teslimde doğuyor, ratchet yok


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--max", type=int, default=800)
    ap.add_argument("--exceptions", default=None)
    ap.add_argument("--base", default=None, help="azalan kayıt denetimi için git rev (örn. merge-base)")
    ap.add_argument("--root", default=str(REPO))
    a = ap.parse_args(argv)
    root = Path(a.root)
    exc_path = Path(a.exceptions) if a.exceptions else root / EXCEPTIONS
    exceptions = parse_exceptions(exc_path.read_text(encoding="utf-8")) if exc_path.exists() else {}
    base = base_exceptions(root, a.base) if a.base else None
    errs = check(root, a.max, exceptions, base)
    for e in errs:
        print(e, file=sys.stderr)
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())

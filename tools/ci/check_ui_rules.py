#!/usr/bin/env python3
"""UI kuralı: ScrollContainer yalnız `UiKit.make_scroll` ile üretilir.

  check_ui_rules.py [--root DIR] [--exceptions F] [--base REF]

Yasak: `ui_kit.gd` dışında `ScrollContainer.new()`; `.tscn`'de `type="ScrollContainer"` düğümü.
Geçiş istisnası (`tools/ci/ui_rules_exceptions.txt`): her satır bir izinli yer (dosya yolu; aynı dosyada n yer = n satır).
Ratchet: istisna yalnız azalır. Bilinçli delik: `ClassDB.instantiate("ScrollContainer")` ve `extends ScrollContainer` taranmaz. Hata biçimi stderr `ETİKET: ...`, çıkış 1:
  UI_RULE: <yol>:<satır>: ScrollContainer fabrika dışı     (listelenmemiş ihlal)
  UI_RULE_STALE: <yol>: ...                                  (listedeki yer artık ihlal değil)
  UI_RULE_NEW_EXCEPTION: <yol>: ...                          (--base REF'te olmayan yeni istisna satırı)
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

FACTORY = "scripts/ui/ui_kit.gd"
ALWAYS_SKIP = {".git", ".godot", ".gate", ".claude", "__pycache__"}
ROOT_SKIP = {"addons", "node_modules", "build"}
GD_RE = re.compile(r"\bScrollContainer\.new\(")
TSCN_RE = re.compile(r'type="ScrollContainer"')
DEFAULT_EXC = "tools/ci/ui_rules_exceptions.txt"


def strip_gd(line: str) -> str:
    """Yorumu ve string içeriğini atar (satır içi; çok satırlı string desteklenmez)."""
    out, quote, i = [], "", 0
    while i < len(line):
        c = line[i]
        if quote:
            if c == "\\":
                i += 1
            elif c == quote:
                quote = ""
        elif c in "\"'":
            quote = c
        elif c == "#":
            break
        else:
            out.append(c)
        i += 1
    return "".join(out)


def walk(root: Path):
    """Dizin budamalı gezinti; SKIP_DIRS yalnız kök seviyesinde atlanır (.git/.godot/.gate/.claude her yerde)."""
    for cur, dirs, files in os.walk(root):
        top = Path(cur) == root
        dirs[:] = sorted(d for d in dirs if d not in ALWAYS_SKIP and not (top and d in ROOT_SKIP))
        for f in sorted(files):
            yield Path(cur) / f


def violations(root: Path) -> list[tuple[str, int]]:
    found: list[tuple[str, int]] = []
    for p in walk(root):
        rel = p.relative_to(root)
        if p.suffix not in (".gd", ".tscn"):
            continue
        key = rel.as_posix()
        if key == FACTORY:
            continue
        pat, clean = (GD_RE, strip_gd) if p.suffix == ".gd" else (TSCN_RE, lambda s: s)
        for n, line in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            if pat.search(clean(line)):
                found.append((key, n))
    return found


def read_exceptions(text: str) -> list[str]:
    return [s for s in (ln.strip() for ln in text.splitlines()) if s and not s.startswith("#")]


def base_exceptions(root: Path, ref: str, rel: str) -> list[str] | None:
    if subprocess.run(["git", "rev-parse", "--verify", "-q", f"{ref}^{{commit}}"], cwd=root, capture_output=True).returncode:
        raise SystemExit(f"UI_RULE_BASE: --base {ref} çözülemedi (sığ klon ya da yanlış REF); ratchet atlanamaz")
    r = subprocess.run(["git", "show", f"{ref}:{rel}"], cwd=root, capture_output=True, text=True)
    return read_exceptions(r.stdout) if r.returncode == 0 else None  # base'te dosya yok: ilk teslim


def main(argv: list[str]) -> int:
    sys.stderr.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    ap.add_argument("--exceptions", default=None)
    ap.add_argument("--base", default=None)
    a = ap.parse_args(argv)
    root = Path(a.root)
    exc_path = Path(a.exceptions) if a.exceptions else root / DEFAULT_EXC
    exc_rel = exc_path.relative_to(root).as_posix() if exc_path.is_relative_to(root) else DEFAULT_EXC
    exc = read_exceptions(exc_path.read_text(encoding="utf-8")) if exc_path.exists() else []
    allowed = Counter(exc)
    errors: list[str] = []
    seen: Counter[str] = Counter()
    for path, line in violations(root):
        seen[path] += 1
        if seen[path] > allowed[path]:
            errors.append(f"UI_RULE: {path}:{line}: ScrollContainer fabrika dışı")
    for path, n in sorted(allowed.items()):
        if seen[path] < n:
            errors.append(f"UI_RULE_STALE: {path}: istisnada {n} yer var, gerçekte {seen[path]} (satır sil)")
    if a.base:
        base = base_exceptions(root, a.base, exc_rel)
        if base is not None:
            for path, n in sorted((allowed - Counter(base)).items()):
                errors.append(f"UI_RULE_NEW_EXCEPTION: {path}: base'te olmayan {n} yeni istisna satırı (yalnız azalır)")
    for e in errors:
        print(e, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

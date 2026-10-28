#!/usr/bin/env python3
"""Katman denetimi (S-layers): scripts/** bağımlılıkları açık izinli katman matrisine uyar; ihlaller azalan istisna kaydında.

  check_layers.py [--base REF] [--exceptions F] [--emit-baseline] [--root DIR]

Katmanlar (yol): sim=scripts/sim/**, store, domain, validate, view, autoload, ui, ctrl; audio -> view, debug -> ctrl (mevcut dizinler, matriste
adlandırılmamıştı). Satır, sütundaki katmana bağımlı olabilir (ALLOWED). Kenar = bir dosyanın başka dosyadaki `class_name`'e (ya da autoload adına)
yorum/dizge dışında değinmesi (extends, tür ek açıklaması, `Sınıf.metot`, `Sınıf.new`, as/is) ya da `preload/load("res://….gd")` / `extends "res://…"`.
Dinamik `load(değişken)` yok sayılır ve LAYER_DYNAMIC bilgi satırı olarak stdout'a yazılır (hata değil).

İstisna kaydı tools/ci/layer_exceptions.txt, satır `kaynak_dosya -> hedef_sınıf_veya_yol` ('#' yorum); ilk liste `--emit-baseline` ile üretilir, elle yazılmaz.
  LAYER_VIOLATION: <kaynak> -> <hedef> (<katman> -> <katman>)   listelenmemiş ihlal
  LAYER_STALE: <kaynak> -> <hedef>                              listedeki istisna gerçekte ihlal değil
  LAYER_NEW_EXCEPTION: <kaynak> -> <hedef>                      --base REF'te olmayan yeni istisna (union yok; yalnız azalır)
  LAYER_UNMAPPED: <dizin> (...)                                 matriste olmayan dizin / üst düzey dosya
  LAYER_FORMAT: ...                                             bozuk istisna satırı
Hata: stderr + çıkış 1.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
EXCEPTIONS = "tools/ci/layer_exceptions.txt"
LAYERS = ("sim", "domain", "store", "validate", "view", "autoload", "ui", "ctrl")
ALLOWED = {
    "sim": {"sim"},
    "store": {"sim", "store"},
    "domain": {"sim", "domain", "store"},
    "validate": {"sim", "validate"},
    "view": {"sim", "domain", "view"},
    "autoload": {"sim", "domain", "store", "autoload"},
    "ui": {"sim", "domain", "view", "autoload", "ui"},
    "ctrl": set(LAYERS),
}
DIR_LAYER = {**{k: k for k in LAYERS}, "audio": "view", "debug": "ctrl"}
BAD = "\0bad"
CLASS_NAME = re.compile(r"^\s*class_name\s+([A-Za-z_]\w*)", re.M)
IDENT = re.compile(r"(?<![\w.$%@&^])[A-Za-z_]\w*")
PRELOAD = re.compile(r"(?<![\w.])(?:preload|load)\(\s*\"(res://[^\"]+\.gd)\"\s*\)")
EXTENDS_PATH = re.compile(r"^\s*extends\s+\"(res://[^\"]+\.gd)\"", re.M)
DYNAMIC_LOAD = re.compile(r"(?<![\w.])load\(\s*[^\"\s)]")
AUTOLOAD = re.compile(r"^(\w+)=\"\*?res://([^\"]+)\"", re.M)


def strip(src: str, keep_strings: bool) -> str:
    """Yorumları atar; dizge içeriğini boşaltır (keep_strings ise korur). Üç tırnaklı çok satırlı dizgeler dahil."""
    out: list[str] = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "#":
            while i < n and src[i] != "\n":
                i += 1
        elif src.startswith('"""', i) or src.startswith("'''", i):
            q = src[i : i + 3]
            j = src.find(q, i + 3)
            j = n if j < 0 else j + 3
            out.append(src[i:j] if keep_strings else q + q)
            i = j
        elif c in "\"'":
            j = i + 1
            while j < n and src[j] != c and src[j] != "\n":
                j += 2 if src[j] == "\\" else 1
            j = min(j + 1, n)
            out.append(src[i:j] if keep_strings else c + c)
            i = j
        else:
            out.append(c)
            i += 1
    return "".join(out)


def layer_of(path: str) -> str | None:
    parts = path.split("/")
    return DIR_LAYER.get(parts[1]) if len(parts) > 2 else None


def parse_exceptions(text: str) -> set:
    out = set()
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        src, arrow, dst = (p.strip() for p in line.partition("->"))
        out.add((src, dst) if arrow and src and dst else (BAD, line))
    return out


def violations(root: Path) -> tuple[dict, list[str], list[str]]:
    """({(kaynak, hedef): 'katman -> katman'}, eşlenmemiş mesajlar, dinamik load bilgileri)."""
    files = sorted(p.relative_to(root).as_posix() for p in (root / "scripts").rglob("*.gd")) if (root / "scripts").is_dir() else []
    code, kept = {}, {}
    for f in files:
        src = (root / f).read_text(encoding="utf-8", errors="replace")
        code[f], kept[f] = strip(src, False), strip(src, True)
    class_of: dict = {}
    for f in files:
        m = CLASS_NAME.search(code[f])
        if m:
            class_of[m.group(1)] = f
    proj = root / "project.godot"
    auto_file: dict = {}
    if proj.is_file():
        for m in AUTOLOAD.finditer(proj.read_text(encoding="utf-8", errors="replace")):
            auto_file[m.group(1)] = m.group(2)
    targets = {**class_of, **{k: v for k, v in auto_file.items() if v in files}}
    canon = {f: n for n, f in sorted(auto_file.items()) if f in files}
    canon.update({f: n for n, f in class_of.items()})
    fileset = set(files)
    unmapped: dict = {}
    viol: dict = {}
    info: list[str] = []
    for f in files:
        if layer_of(f) is None:
            parts = f.split("/")
            if len(parts) == 2:
                unmapped.setdefault("scripts", []).append(f)
            else:
                unmapped.setdefault("/".join(parts[:2]), [])
            continue
        edges = {targets[t] for t in IDENT.findall(code[f]) if t in targets}
        edges |= {p.removeprefix("res://") for p in PRELOAD.findall(kept[f]) + EXTENDS_PATH.findall(kept[f])}
        edges = {e for e in edges if e in fileset and e != f}
        for e in edges:
            a, b = layer_of(f), layer_of(e)
            if b is not None and b not in ALLOWED[a]:
                viol[(f, canon.get(e, e))] = f"{a} -> {b}"
        dyn = len(DYNAMIC_LOAD.findall(kept[f]))
        if dyn:
            info.append(f"LAYER_DYNAMIC: {f}: {dyn} dinamik load(değişken) yok sayıldı")
    msgs = []
    for d, fs in sorted(unmapped.items()):
        msgs.append(f"LAYER_UNMAPPED: {d} (üst düzey dosya: {', '.join(fs)})" if d == "scripts" else f"LAYER_UNMAPPED: {d} (matriste yok)")
    return viol, msgs, info


def check(root: Path, exceptions, base) -> tuple[list[str], list[str]]:
    viol, unmapped, info = violations(root)
    exc = set(exceptions)
    errs = [f"LAYER_FORMAT: '{t}': beklenen biçim `kaynak_dosya -> hedef`" for s, t in sorted(exc) if s == BAD]
    exc = {e for e in exc if e[0] != BAD}
    errs += [f"LAYER_VIOLATION: {s} -> {t} ({viol[(s, t)]})" for s, t in sorted(set(viol) - exc)]
    errs += [f"LAYER_STALE: {s} -> {t}" for s, t in sorted(exc - set(viol))]
    if base is not None:
        errs += [f"LAYER_NEW_EXCEPTION: {s} -> {t}" for s, t in sorted(exc - {e for e in base if e[0] != BAD})]
    errs += sorted(unmapped)
    return errs, info


def base_exceptions(root: Path, ref: str):
    r = subprocess.run(["git", "-C", str(root), "show", f"{ref}:{EXCEPTIONS}"], capture_output=True, text=True, encoding="utf-8")
    return parse_exceptions(r.stdout) if r.returncode == 0 else None  # base'de dosya yok = kayıt bu teslimde doğuyor, ratchet yok


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--base", default=None, help="azalan kayıt denetimi için git rev (örn. merge-base)")
    ap.add_argument("--exceptions", default=None)
    ap.add_argument("--emit-baseline", action="store_true", help="mevcut ihlallerden ilk istisna listesini stdout'a yazar")
    ap.add_argument("--root", default=str(REPO))
    a = ap.parse_args(argv)
    root = Path(a.root)
    if a.emit_baseline:
        viol, _, _ = violations(root)
        print("# Katman istisnaları (check_layers.py). Biçim: kaynak_dosya -> hedef_sınıf_veya_yol. YALNIZ AZALIR (union yok):")
        print("# yeni satır LAYER_NEW_EXCEPTION, ihlali kalkmış satır LAYER_STALE. İlk liste --emit-baseline ile üretilmiştir.")
        for s, t in sorted(viol):
            print(f"{s} -> {t}")
        return 0
    exc_path = Path(a.exceptions) if a.exceptions else root / EXCEPTIONS
    exceptions = parse_exceptions(exc_path.read_text(encoding="utf-8")) if exc_path.is_file() else set()
    errs, info = check(root, exceptions, base_exceptions(root, a.base) if a.base else None)
    for i in info:
        print(i)
    for e in errs:
        print(e, file=sys.stderr)
    return 1 if errs else 0


if __name__ == "__main__":
    for _s in (sys.stdout, sys.stderr):
        _s.reconfigure(encoding="utf-8")  # Windows: Türkçe mesajlar yerel kod sayfasına düşmesin
    sys.exit(main())

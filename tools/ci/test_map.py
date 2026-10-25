#!/usr/bin/env python3
"""Seçici koşu eşlemesi (F-044): değişen dosyalara göre koşulacak GUT test dosyalarını seçer.

  test_map.py generate            tools/ci/test_map.json'u yeniden üretir (kaynak ağacın statik bağımlılık analizi)
  test_map.py check               json ile ağaç tutarlı mı (güncel + sahipsiz test yok); 0/1
  test_map.py select [DOSYA...]   değişen dosyalar (argüman ya da stdin satırları) -> "FULL" ya da test dosyaları listesi

HIZLI MOD YALNIZ GELİŞTİRİCİ GERİ BİLDİRİMİDİR; PR CI'ı, entegrasyon merge'ü ve son kapı (main) HER ZAMAN tam suite koşar
(docs/dev/ci-speed.md). Güvenlik kuralları (şüphede tam suite):
  * full_if desenleri (sim çekirdeği, data/, test yardımcıları/fixture'lar, gate/CI betikleri, proje ayarları, assets/art/audio)
    ya da eşlemede YERİ OLMAYAN dosya => FULL
  * eşlenen dosya F için seçilen = F'ye (sınıf adı, res:// yolu, autoload adı ya da dizin önekiyle) geçişli olarak bağımlı tüm
    testler; değişen test dosyasının kendisi her zaman seçilir
"""
from __future__ import annotations

import fnmatch
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MAP = Path(__file__).resolve().parent / "test_map.json"

# Değişince tam suite koşan (paylaşılan) yollar. fnmatch; '*' dizin ayracını da kapsar.
FULL_IF = [
    "scripts/sim/*",
    "scripts/autoload/*",
    "data/*",
    "test/helpers/*",
    "test/fixtures/*",
    "test/long/*",
    "tools/gate.sh",
    "tools/gate_*",
    "tools/ci/*",
    "tools/*.gd",
    "tools/*.json",
    "tools/*.txt",
    "tools/*.sh",
    "project.godot",
    ".gutconfig.json",
    ".godot-version",
    "export_presets.cfg",
    "default_bus_layout.tres",
    "addons/*",
    ".github/*",
    "assets/*",
    "art/*",
    "audio/*",
    "themes/*",
    "scenes/*",
]
# Eşlenebilen alanlar: bu dizinlerdeki .gd dosyaları grafiğe girer.
MAPPED_GD = ("scripts/",)
IDENT = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\b")
CLASS_NAME = re.compile(r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
RES = re.compile(r"res://[^\"'\s)]*")


def strip_comments(src: str) -> str:
    """GDScript satır yorumlarını atar (dizge içindeki '#' korunur); yorumdaki sınıf adları bağımlılık sayılmaz."""
    out = []
    for line in src.splitlines():
        q = ""
        for i, ch in enumerate(line):
            if q:
                if ch == q and line[i - 1] != "\\":
                    q = ""
            elif ch in "\"'":
                q = ch
            elif ch == "#":
                line = line[:i]
                break
        out.append(line)
    return "\n".join(out)


class Tree:
    """Kaynak ağacı: çalışma dizini (rev=None) ya da bir git sürümü (geriye dönük sınama; checkout gerektirmez)."""

    def __init__(self, root: Path = ROOT, rev: str | None = None):
        self.root, self.rev = root, rev

    def files(self) -> list[str]:
        if self.rev is None:
            out = subprocess.run(
                ["git", "ls-files", "-co", "--exclude-standard"], cwd=self.root, capture_output=True, text=True, check=True
            ).stdout.splitlines()
            return sorted(p for p in out if (self.root / p).is_file())
        out = subprocess.run(
            ["git", "ls-tree", "-r", self.rev], cwd=self.root, capture_output=True, text=True, check=True
        ).stdout.splitlines()
        self._blobs = {l.split("\t", 1)[1]: l.split()[2] for l in out}
        return sorted(self._blobs)

    def read(self, path: str) -> str:
        if self.rev is None:
            return (self.root / path).read_text(encoding="utf-8", errors="replace")
        if not hasattr(self, "_cache"):
            self.files()
            want = [p for p in self._blobs if p.endswith(".gd") or p == "project.godot"]
            proc = subprocess.run(
                ["git", "cat-file", "--batch"], cwd=self.root, input="".join(self._blobs[p] + "\n" for p in want).encode(),
                capture_output=True, check=True,
            )
            buf, i, self._cache = proc.stdout, 0, {}
            for p in want:
                j = buf.index(b"\n", i)
                size = int(buf[i:j].split()[2])
                self._cache[p] = buf[j + 1 : j + 1 + size].decode("utf-8", errors="replace")
                i = j + 1 + size + 1
        return self._cache[path]


def tracked(root: Path) -> list[str]:
    return Tree(root).files()


def test_files(files: list[str]) -> list[str]:
    return sorted(
        f for f in files
        if f.endswith(".gd") and re.match(r"test/(unit|acceptance)/", f) and Path(f).name.startswith("test_")
    )


def is_full(path: str) -> bool:
    return any(fnmatch.fnmatch(path, pat) for pat in FULL_IF)


def build(root: Path = ROOT, rev: str | None = None) -> dict:
    tree = Tree(root, rev)
    files = tree.files()
    fileset = set(files)
    tests = test_files(files)
    nodes = [f for f in files if f.endswith(".gd") and not f.endswith(".uid") and (f.startswith(MAPPED_GD) or f in tests)]
    # test yardımcıları (test/helpers) da grafiğe girer: testler onlardan geçişli bağımlı olabilir (yardımcıyı değiştirmek FULL)
    nodes += [f for f in files if f.startswith("test/helpers/") and f.endswith(".gd")]
    text = {n: strip_comments(tree.read(n)) for n in nodes}
    classes: dict[str, str] = {}
    for n in nodes:
        for m in CLASS_NAME.finditer(text[n]):
            classes[m.group(1)] = n
    autoload: dict[str, str] = {}
    proj = tree.read("project.godot")
    for m in re.finditer(r'^(\w+)="\*?res://([^"]+)"', proj, re.M):
        autoload[m.group(1)] = m.group(2)
    deps: dict[str, set[str]] = {}
    for n in nodes:
        d: set[str] = set()
        src = text[n]
        for ident in set(IDENT.findall(src)):
            tgt = classes.get(ident) or autoload.get(ident)
            if tgt and tgt != n:
                d.add(tgt)
        for r in RES.findall(src):
            rel = r.removeprefix("res://")
            if rel in fileset:
                d.add(rel)
            else:  # dizin öneki ya da biçimli yol: o önekle başlayan tüm dosyalar (muhafazakâr)
                pre = rel.split("%")[0]
                if pre and pre != rel or rel.endswith("/"):
                    d.update(f for f in files if f.startswith(pre) and f != n)
        # göreli preload("x.gd")
        for rel in re.findall(r'(?:preload|load)\("([^"]+\.gd)"\)', src):
            if not rel.startswith("res://"):
                cand = (Path(n).parent / rel).as_posix()
                if cand in fileset:
                    d.add(cand)
        deps[n] = d
    # geçişli kapanış: test -> ulaşabildiği tüm dosyalar
    rev: dict[str, set[str]] = {}
    for t in tests:
        seen: set[str] = set()
        stack = [t]
        while stack:
            cur = stack.pop()
            for nxt in deps.get(cur, ()):
                if nxt not in seen:
                    seen.add(nxt)
                    stack.append(nxt)
        for f in seen | {t}:
            rev.setdefault(f, set()).add(t)
    mapped = {}
    for f in files:
        if f.endswith(".uid") or is_full(f):
            continue
        if f.startswith(MAPPED_GD) or f.startswith("docs/") or f.startswith("tools/"):
            mapped[f] = sorted(rev.get(f, ()))
    return {
        "version": 1,
        "note": "Üretilir: python3 tools/ci/test_map.py generate. Hızlı mod yalnız geliştirici geri bildirimidir; PR CI/merge/son kapı tam suite.",
        "full_if": FULL_IF,
        "tests": tests,
        "files": mapped,
    }


def load() -> dict:
    return json.loads(MAP.read_text(encoding="utf-8"))


def select(changed: list[str], m: dict | None = None):
    """Döner: "FULL" ya da seçilen test dosyaları (sıralı liste)."""
    m = m or load()
    tests = set(m["tests"])
    chosen: set[str] = set()
    for f in changed:
        f = f.strip()
        if not f or f.endswith(".uid"):
            continue
        if f in tests:
            chosen.add(f)
            continue
        if f.startswith("test/") and f.endswith(".gd") and Path(f).name.startswith("test_") and not any(
            fnmatch.fnmatch(f, p) for p in m["full_if"]
        ):
            continue  # eşlemede olmayan test dosyası = silinmiş/taşınmış test (yeni testler eşleme güncelken tests'tedir)
        if any(fnmatch.fnmatch(f, p) for p in m["full_if"]):
            return "FULL"
        if f in m["files"]:
            chosen.update(m["files"][f])
            continue
        if f.startswith("docs/") and f.endswith(".md"):
            continue  # hiçbir testin bağımlılığı olmayan belge
        return "FULL"  # eşlemede yeri yok: şüphede tam suite
    return sorted(chosen)


def check(root: Path = ROOT) -> int:
    fresh = build(root)
    cur = load()
    rc = 0
    if fresh != cur:
        print("TESTMAP_ERROR: tools/ci/test_map.json güncel değil (python3 tools/ci/test_map.py generate)", file=sys.stderr)
        rc = 1
    covered = set()
    for ts in cur["files"].values():
        covered.update(ts)
    # sahipsiz test: ne eşlemede bir dosyanın ne de kendi kendinin grubunda yeri olan test (her test kendi kendini seçer)
    own = {t for t in cur["tests"] if select([t], cur) == [t]}
    orphan = sorted(set(cur["tests"]) - own)
    if orphan:
        print("TESTMAP_ERROR: sahipsiz test: " + ", ".join(orphan), file=sys.stderr)
        rc = 1
    return rc


def main(argv: list[str]) -> int:
    cmd = argv[1] if len(argv) > 1 else ""
    if cmd == "generate":
        MAP.write_text(json.dumps(build(), indent=1, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
        return 0
    if cmd == "check":
        return check()
    if cmd == "select":
        changed = argv[2:] or sys.stdin.read().splitlines()
        r = select(changed)
        print("FULL" if r == "FULL" else "\n".join(r))
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))

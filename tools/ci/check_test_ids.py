#!/usr/bin/env python3
"""Test kimliği kapısı (S-ids): "çalışan test kimliği kaybı yok" kanıtı. Kimlik = `yol::fonksiyon` (GUT JUnit classname::name).

  check_test_ids.py [--mode full|selected|static] [--junit J...] [--files F] [--base REF | --base-declared F | --no-base]
                    [--removed F] [--moved F] [--pending-allowed F] [--report-only] [--root DIR]

Kümeler:
  declared(rev)         .gutconfig.json dizinlerindeki test_*.gd dosyalarında sütun 0'daki `func test_*` (yorum/string/girintili/class içi yok)
  pending_allowed(rev)  rev'deki KAPALI dilim simgelerine ait kimlikler (tools/v*_slices.txt; check_slices.py profilleri) + tools/ci/pending_allowed.txt
  ran(J)                JUnit'te skip/pending olmayan testcase'ler
Denetimler:
  (i)   declared(HEAD) ⊆ ran ∪ pending_allowed(HEAD)                                   -> MISSING   (JUnit gerekir)
  (ii)  declared(base) ∖ removed ∖ moved_old ⊆ declared(HEAD)                          -> LOST      (declared kayboldu)
  (iii) (declared(base) ∖ pending_allowed(base)) ∖ removed ∖ moved_old ⊆ ran(HEAD)     -> LOST      (koşmadı; JUnit gerekir)
  ayrıca DUP (yinelenen bildirim/JUnit), UNSUPPORTED (Test* iç sınıfı, use_parameters), MOVE_INVALID, REMOVED_INVALID.
Kipler: full = (i)(ii)(iii); selected = (i)(iii) yalnız --files'taki test dosyaları, (ii) tam; static = yalnız (ii) + declared tutarlılığı.
JUnit verilmezse full/selected kipi static sayılır ve çıktı bunu söyler. Hata: stderr `TEST_IDS: <id>: <ETİKET>`, çıkış 1;
--report-only farkı stdout'a yazar ve her zaman 0 çıkar.
Dürüst sınır: kimlik düzeyinde denetim; içi boşaltılmış `func test_x(): pass` ya da döngü içi assertion kaybı yakalanmaz.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import check_slices as cs  # noqa: E402

REPO = HERE.parents[1]
REMOVED, MOVED, PENDING = "tools/ci/removed_tests.txt", "tools/ci/moved_tests.txt", "tools/ci/pending_allowed.txt"
FUNC = re.compile(r"^func\s+(test_\w*)\s*\(")
CLASS = re.compile(r"^class\s+(\w+)")
GUT_DEFAULT = {"dirs": ["res://test/unit", "res://test/acceptance"], "prefix": "test_", "suffix": ".gd", "include_subdirs": True}


# --- kaynak ağacı (çalışma dizini ya da git rev) ------------------------------------------------------------------------------


class FsSource:
    def __init__(self, root: Path):
        self.root = Path(root)

    def files(self) -> list[str]:
        skip = {".git", ".godot", ".gate", ".claude", "addons", "build"}
        return sorted(p.relative_to(self.root).as_posix() for p in self.root.rglob("*") if p.is_file() and not (skip & set(p.relative_to(self.root).parts)))

    def read(self, path: str) -> str | None:
        p = self.root / path
        return p.read_text(encoding="utf-8", errors="replace") if p.is_file() else None

    def prefetch(self, paths) -> None:
        pass


class GitSource:
    def __init__(self, root: Path, rev: str):
        self.root, self.rev, self._cache = Path(root), rev, {}
        r = subprocess.run(["git", "-C", str(self.root), "ls-tree", "-r", "-z", "--name-only", rev], capture_output=True, text=True, encoding="utf-8")
        if r.returncode != 0:
            raise SystemExit(f"TEST_IDS_USAGE: git rev okunamadı: {rev}: {r.stderr.strip()}")
        self._files = sorted(x for x in r.stdout.split("\0") if x)

    def files(self) -> list[str]:
        return self._files

    def prefetch(self, paths) -> None:
        known = set(self._files)
        want = [p for p in paths if p in known and p not in self._cache]
        if not want:
            return
        inp = "".join(f"{self.rev}:{p}\n" for p in want).encode("utf-8")
        out = subprocess.run(["git", "-C", str(self.root), "cat-file", "--batch"], input=inp, capture_output=True, check=True).stdout
        pos = 0
        for p in want:
            nl = out.index(b"\n", pos)
            size = int(out[pos:nl].split()[-1])
            self._cache[p] = out[nl + 1 : nl + 1 + size].decode("utf-8", errors="replace")
            pos = nl + 1 + size + 1

    def read(self, path: str) -> str | None:
        if path not in self._cache:
            self.prefetch([path])
        return self._cache.get(path)


# --- declared ---------------------------------------------------------------------------------------------------------------


def parse_declared(text: str, path: str) -> tuple[list[str], list[str]]:
    """(kimlikler, desteklenmeyenler). Yalnız sütun 0'daki `func test_*`; `\"\"\"` çok satırlı dizge içi sayılmaz."""
    ids: list[str] = []
    unsupported: list[str] = []
    in_str = False
    for line in text.splitlines():
        odd = line.count('"""') % 2 == 1
        if in_str:
            in_str = not odd
            continue
        if odd:
            in_str = True
            continue
        m = FUNC.match(line)
        if m:
            ids.append(f"{path}::{m.group(1)}")
            continue
        c = CLASS.match(line)
        if c and c.group(1).startswith("Test"):
            unsupported.append(f"{path}::{c.group(1)}")
    if "use_parameters(" in text:
        unsupported.append(f"{path}::use_parameters")
    return ids, unsupported


@dataclass
class Declared:
    ids: set = field(default_factory=set)
    dups: list = field(default_factory=list)
    unsupported: list = field(default_factory=list)


def collect_declared(src) -> Declared:
    cfg = dict(GUT_DEFAULT)
    raw = src.read(".gutconfig.json")
    if raw:
        try:
            cfg.update(json.loads(raw))
        except ValueError:
            pass
    dirs = [d.removeprefix("res://").strip("/") for d in cfg["dirs"]]
    prefix, suffix, sub = cfg.get("prefix", "test_"), cfg.get("suffix", ".gd"), cfg.get("include_subdirs", True)
    cand = []
    for f in src.files():
        name = f.rsplit("/", 1)[-1]
        if not (name.startswith(prefix) and name.endswith(suffix)):
            continue
        for d in dirs:
            rest = f[len(d) + 1 :] if f.startswith(d + "/") else None
            if rest is not None and (sub or "/" not in rest):
                cand.append(f)
                break
    src.prefetch(cand)
    out = Declared()
    for f in cand:
        ids, unsup = parse_declared(src.read(f) or "", f)
        out.unsupported += unsup
        for i in ids:
            if i in out.ids:
                out.dups.append(i)
            out.ids.add(i)
    return out


# --- pending_allowed ----------------------------------------------------------------------------------------------------------


def _families():
    """check_slices profilleri (v2, v2.0.2, v2.1, v2.0.3). Test adı deseni `e5b_` gibi harf sonekini de kabul eder."""
    fams = [("tools/v2_slices.txt", cs.V2), ("tools/v202_slices.txt", cs.V202), ("tools/v21_slices.txt", cs.V21),
            ("tools/v203_slices.txt", cs.Profile(("A", "B", "C", "D"), "V203_SLICES_FORCE", "v203", ()))]
    out = []
    for path, p in fams:
        lenient = cs.Profile(p.symbols, p.force_env, p.classname_re.pattern if p.classname_re else None, p.sliceless, p.exclude_re.pattern if p.exclude_re else None)
        lenient.test_re = re.compile(r"^test_([%s])(\d+)[a-z]?_" % "".join(s.lower() for s in p.symbols))
        out.append((path, lenient))
    return out


def pending_allowed(src, ids) -> set:
    allowed = set()
    for path, prof in _families():
        text = src.read(path)
        if text is None:
            continue
        ok, marks, _ = cs.parse(text, prof.symbols)
        for i in ids:
            f, fn = i.split("::", 1)
            if (prof.classname_re and not prof.classname_re.search(f)) or (prof.exclude_re and prof.exclude_re.search(f)):
                continue
            s = cs.slice_of(fn, prof)
            if s and s not in marks:
                allowed.add(i)
    return allowed


# --- kayıt dosyaları ------------------------------------------------------------------------------------------------------------


def _rows(text: str):
    for n, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if line and not line.startswith("#"):
            yield n, line


def parse_removed(text: str) -> tuple[set, list]:
    """`id | gerekçe | görev/bulgu` -> (kimlikler, hatalar)."""
    ids, errs = set(), []
    for n, line in _rows(text):
        parts = [p.strip() for p in line.split("|")]
        if len(parts) != 3 or not all(parts):
            errs.append(f"TEST_IDS: satır {n}: REMOVED_INVALID (biçim: `id | gerekçe | görev/bulgu`)")
        else:
            ids.add(parts[0])
    return ids, errs


def parse_pending_allowed(text: str) -> tuple[set, list]:
    """Çalışma anında pending olan bilinen testler: `id | gerekçe | görev` (removed ile aynı biçim)."""
    return parse_removed(text)


def parse_moved(text: str) -> tuple[dict, list]:
    """`eski -> yeni1[, yeni2...]` -> ({eski: [yeni...]}, hatalar)."""
    moved: dict = {}
    errs = []
    for n, line in _rows(text):
        old, arrow, new = (p.strip() for p in line.partition("->"))
        news = [x.strip() for x in new.split(",") if x.strip()]
        if not arrow or not old or not news or "::" not in old or any("::" not in x for x in news):
            errs.append(f"TEST_IDS: satır {n}: MOVE_INVALID (biçim: `eski -> yeni1, yeni2`)")
        elif old in moved:
            errs.append(f"TEST_IDS: {old}: MOVE_INVALID (bir eski kimlik yalnız bir satırda)")
        else:
            moved[old] = news
    return moved, errs


def check_records(head_ids: set, removed: set, moved: dict) -> list[str]:
    errs = []
    for i in sorted(removed & head_ids):
        errs.append(f"TEST_IDS: {i}: REMOVED_INVALID (HEAD'de hâlâ var)")
    sources: dict = {}
    for old, news in sorted(moved.items()):
        if old in head_ids:
            errs.append(f"TEST_IDS: {old}: MOVE_INVALID (eski kimlik HEAD'de hâlâ var)")
        for n in news:
            if n not in head_ids:
                errs.append(f"TEST_IDS: {n}: MOVE_INVALID (yeni kimlik HEAD'de yok)")
            if sources.setdefault(n, old) != old:
                errs.append(f"TEST_IDS: {n}: MOVE_INVALID (bir yeni kimlik yalnız bir eskiden gelir)")
    return errs


# --- JUnit ------------------------------------------------------------------------------------------------------------------


@dataclass
class Junit:
    ran: set = field(default_factory=set)
    skipped: set = field(default_factory=set)
    dups: list = field(default_factory=list)


def read_junit(paths) -> Junit:
    j = Junit()
    seen: set = set()
    for p in paths:
        for tc in ET.parse(p).getroot().iter("testcase"):
            i = f"{tc.get('classname')}::{tc.get('name')}"
            if i in seen:
                j.dups.append(i)
            seen.add(i)
            if tc.get("status") in ("pending", "skipped") or tc.find("skipped") is not None:
                j.skipped.add(i)
            else:
                j.ran.add(i)
    return j


# --- denetimler ---------------------------------------------------------------------------------------------------------------


def verify(d: Declared, j: Junit, allowed: set, only: set | None = None) -> list[str]:
    """(i) + JUnit yinelenenleri."""
    errs = [f"TEST_IDS: {i}: DUP (JUnit'te yinelenen testcase)" for i in sorted(set(j.dups))]
    for i in sorted(d.ids):
        if only is not None and i.split("::")[0] not in only:
            continue
        if i not in j.ran and i not in allowed:
            errs.append(f"TEST_IDS: {i}: MISSING")
    return errs


def base_sets(root: Path, args) -> tuple[set, set] | None:
    """(declared(base), pending_allowed(base)) ya da taban yok."""
    if args.no_base:
        return None
    if args.base_declared:
        return {l.strip() for l in Path(args.base_declared).read_text(encoding="utf-8").splitlines() if l.strip() and not l.startswith("#")}, set()
    ref = args.base
    if not ref:
        r = subprocess.run(["git", "-C", str(root), "merge-base", "HEAD", "origin/main"], capture_output=True, text=True)
        ref = r.stdout.strip() if r.returncode == 0 and r.stdout.strip() else None
    if not ref:
        return None
    src = GitSource(root, ref)
    d = collect_declared(src)
    return d.ids, pending_allowed(src, d.ids)


def read_optional(root: Path, override, default: str) -> str:
    p = Path(override) if override else root / default
    return p.read_text(encoding="utf-8") if p.is_file() else ""


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--mode", choices=["full", "selected", "static"], default="full")
    ap.add_argument("--junit", nargs="*", default=[])
    ap.add_argument("--files", default=None, help="selected kipi: test dosyası yolları (satır başına)")
    ap.add_argument("--base", default=None)
    ap.add_argument("--base-declared", default=None)
    ap.add_argument("--no-base", action="store_true")
    ap.add_argument("--removed", default=None)
    ap.add_argument("--moved", default=None)
    ap.add_argument("--pending-allowed", default=None)
    ap.add_argument("--report-only", action="store_true")
    ap.add_argument("--root", default=str(REPO))
    a = ap.parse_args(argv)
    root = Path(a.root)
    if a.mode == "selected" and not a.files:
        print("TEST_IDS_USAGE: --mode selected için --files gerekir", file=sys.stderr)
        return 2

    src = FsSource(root)
    d = collect_declared(src)
    errs = [f"TEST_IDS: {i}: DUP (bildirimde yinelenen)" for i in sorted(set(d.dups))]
    errs += [f"TEST_IDS: {i}: UNSUPPORTED (iç sınıf/parametreli test)" for i in sorted(d.unsupported)]
    removed, e1 = parse_removed(read_optional(root, a.removed, REMOVED))
    moved, e2 = parse_moved(read_optional(root, a.moved, MOVED))
    known_pending, e3 = parse_pending_allowed(read_optional(root, a.pending_allowed, PENDING))
    errs += e1 + e2 + e3 + check_records(d.ids, removed, moved)
    allowed = pending_allowed(src, d.ids) | known_pending

    junit_paths = [Path(p) for p in a.junit]
    mode = a.mode if junit_paths else "static"
    j = read_junit(junit_paths) if junit_paths else None
    only = {l.strip() for l in Path(a.files).read_text(encoding="utf-8").splitlines() if l.strip()} if a.mode == "selected" else None

    miss: list[str] = []
    if j is not None:
        miss = verify(d, j, allowed, only)
        errs += miss
    base = base_sets(root, a)
    gone = {i for i in (base[0] if base else set()) if i not in d.ids and i not in removed and i not in moved}
    errs += [f"TEST_IDS: {i}: LOST (declared kayboldu)" for i in sorted(gone)]
    if base and j is not None:
        lost = {i for i in base[0] - base[1] - known_pending - removed - set(moved) if i not in j.ran and i in d.ids and (only is None or i.split("::")[0] in only)}
        errs += [f"TEST_IDS: {i}: LOST (koşmadı)" for i in sorted(lost)]

    if a.report_only:
        ran, skipped = (len(j.ran), len(j.skipped)) if j else (0, 0)
        print(f"TEST_IDS report: mode={mode} declared={len(d.ids)} ran={ran} skipped={skipped} pending_allowed={len(allowed & d.ids)}")
        if j:
            non_slice = sorted(i for i in j.skipped if i not in allowed)
            print(f"dilim dışı pending ({len(non_slice)}): " + ", ".join(non_slice))
            print(f"declared olup ne koşan ne izinli pending ({len(miss)}): " + ", ".join(m.split(": ")[1] for m in miss if m.endswith("MISSING")))
        mins = root / "tools" / "gate_min_tests.json"
        if mins.is_file():
            files = {i.split("::")[0] for i in d.ids}
            orphan = sorted(f for f in json.loads(mins.read_text(encoding="utf-8")) if f not in files)
            print(f"gate_min_tests.json'da olup declared'da dosyası olmayan ({len(orphan)}): " + ", ".join(orphan))
        for e in errs:
            if not e.endswith("MISSING"):
                print(e)
        return 0
    for e in errs:
        print(e, file=sys.stderr)
    print(f"mode={mode} declared={len(d.ids)}" + (" (JUnit yok: (i) ve (iii) atlandı)" if j is None else f" ran={len(j.ran)}"))
    return 1 if errs else 0


if __name__ == "__main__":
    for _s in (sys.stdout, sys.stderr):
        _s.reconfigure(encoding="utf-8")  # Windows: Türkçe mesajlar yerel kod sayfasına düşmesin
    sys.exit(main())

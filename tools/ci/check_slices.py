#!/usr/bin/env python3
"""v2.0 dilim işareti denetimi (tools/v2_slices.txt). İki kullanım:

  check_slices.py <v2_slices.txt>                 sözdizimi: bilinmeyen simge / eksik dosya => hata
  check_slices.py <v2_slices.txt> <junit.xml>     + işaretli her dilimde pending ya da sıfır test => hata

Biçim (V11Slice ile aynı): '#' ile başlayan satırlar yorumdur; kalanlar boşluk/sekmeyle bölünür; geçerli simgeler
K (karakter), B (başarım), M (bakım). Aynı ayrıştırıcı kuralları GDScript tarafında test/helpers/slice_file.gd'dedir;
ikisi de tools/ci/tests/slice_cases.json vaka tablosunu okur (biri değişirse diğeri kırılır).

Dilim sahibi test = ad önekiyle eşleşen test fonksiyonu: test_k<N>_… => K, test_b<N>_… => B, test_m<N>_… => M.
M1, M9, M10 dilimsizdir (işaretsiz de koşar, M'ye sayılmaz). V2_SLICES_FORCE ortam değişkeni (boşluk/virgül ayraçlı
simgeler) işareti zorlar (tur fazı için; SliceFile aynısını yapar).
Çıkış: 0 temiz, 1 hata ("SLICE_ERROR: …" satırları stderr'e).
"""
from __future__ import annotations

import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

SYMBOLS = ("K", "B", "M")
SLICELESS = {("M", 1), ("M", 9), ("M", 10)}
TEST_RE = re.compile(r"^test_([kbm])(\d+)_")


def parse(text: str, valid: tuple[str, ...] = SYMBOLS) -> tuple[bool, list[str], list[str]]:
    """(ok, marks, errors). Yorum satırları ve boş satırlar atlanır; yinelenen simge bir kez; hata varsa marks boş."""
    marks: list[str] = []
    errors: list[str] = []
    for n, line in enumerate(text.splitlines(), 1):
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        for tok in s.split():
            if valid and tok not in valid:
                errors.append(f"satır {n}: geçersiz simge '{tok}' (geçerli: {' '.join(valid)})")
            elif tok not in marks:
                marks.append(tok)
    return (not errors, marks if not errors else [], errors)


def forced() -> list[str]:
    raw = os.environ.get("V2_SLICES_FORCE", "")
    return [t for t in re.split(r"[\s,]+", raw) if t]


def slice_of(test_name: str) -> str | None:
    m = TEST_RE.match(test_name)
    if not m:
        return None
    key = (m.group(1).upper(), int(m.group(2)))
    return None if key in SLICELESS else key[0]


def check_junit(junit: Path, marks: list[str]) -> list[str]:
    errors: list[str] = []
    counts = {s: {"real": 0, "pending": []} for s in marks}
    for case in ET.parse(junit).getroot().iter("testcase"):
        s = slice_of(case.get("name", ""))
        if s not in counts:
            continue
        pending = case.get("status") == "pending" or case.find("skipped") is not None
        if pending:
            counts[s]["pending"].append(f"{case.get('classname')}::{case.get('name')}")
        else:
            counts[s]["real"] += 1
    for s in marks:
        c = counts[s]
        if c["pending"]:
            errors.append(f"{s}: işaretli dilimde {len(c['pending'])} pending test: {', '.join(c['pending'][:5])}")
        if c["real"] == 0 and not c["pending"]:
            errors.append(f"{s}: işaretli dilimde hiç test yok (test_{s.lower()}<N>_… öneki)")
    return errors


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    path = Path(argv[1])
    errors: list[str] = []
    marks: list[str] = []
    if not path.is_file():
        errors.append(f"dilim dosyası yok: {path}")
    else:
        ok, marks, errs = parse(path.read_text(encoding="utf-8"))
        errors += errs
    for t in forced():
        if t not in SYMBOLS:
            errors.append(f"V2_SLICES_FORCE: geçersiz simge '{t}'")
        elif t not in marks:
            marks.append(t)
    if len(argv) > 2 and not errors:
        junit = Path(argv[2])
        if not junit.is_file():
            errors.append(f"JUnit yok: {junit}")
        else:
            errors += check_junit(junit, marks)
    for e in errors:
        print("SLICE_ERROR: " + e, file=sys.stderr)
    if not errors:
        print(f"dilim işaretleri: {' '.join(marks) if marks else '(yok)'}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

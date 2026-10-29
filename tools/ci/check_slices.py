#!/usr/bin/env python3
"""Dilim işareti denetimi (v2.0: tools/v2_slices.txt; v2.0.2: tools/v202_slices.txt). İki kullanım:

  check_slices.py <v2_slices.txt>                 sözdizimi: bilinmeyen simge / eksik dosya => hata
  check_slices.py <v2_slices.txt> <junit.xml>     + işaretli her dilimde pending ya da sıfır test => hata

Parametreler (v2.0.2 genellemesi; hiçbiri verilmezse v2.0 davranışı BİREBİR aynıdır, tools/ci/tests/slice_snapshot_v2.json):
  --file <yol>          dilim dosyası (konumsal bağımsız değişkenin eşdeğeri)
  --symbols "K B M"     geçerli simgeler (boşluk/virgül ayraçlı); TEST_RE bunlardan türer: test_<simge küçük><N>[harf]_…
  --force-env AD        işareti zorlayan ortam değişkeni (varsayılan V2_SLICES_FORCE; v2.0.2: V202_SLICES_FORCE)
  --classname-re RE     yalnız sınıf adı (test dosyası yolu) RE ile eşleşen test durumları sayılır (v2.0.2: v202; eski
                        v1.1 testlerindeki test_p20_ gibi adlarla çakışmayı önler)
  --no-sliceless        M1/M9/M10 dilimsiz istisnası uygulanmaz (yalnız v2.0 simgelerine özgüdür)
  Kısayol: --v202  =  --symbols "P R W Z E A" --force-env V202_SLICES_FORCE --classname-re v202 --no-sliceless
  Kısayol: --v21   =  --symbols "M S K A B" --force-env V21_SLICES_FORCE --classname-re v21 --no-sliceless

Biçim (V11Slice ile aynı): '#' ile başlayan satırlar yorumdur; kalanlar boşluk/sekmeyle bölünür; geçerli simgeler
K (karakter), B (başarım), M (bakım). Aynı ayrıştırıcı kuralları GDScript tarafında test/helpers/slice_file.gd'dedir;
ikisi de tools/ci/tests/slice_cases.json vaka tablosunu okur (biri değişirse diğeri kırılır).

Dilim sahibi test = ad önekiyle eşleşen test fonksiyonu: test_k<N>_… => K, test_b<N>_… => B, test_m<N>_… => M
(v2.0.2: test_p<N>_ => P, test_r<N>_ => R, test_w<N>_ => W, test_z<N>_ => Z, test_e<N>_ => E, test_a<N>_ => A).
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
FORCE_ENV = "V2_SLICES_FORCE"
V202_SYMBOLS = ("P", "R", "W", "Z", "E", "A")
V21_SYMBOLS = ("M", "S", "K", "A", "B")


class Profile:
    """Bir dilim ailesinin ayarları (simgeler, test adı deseni, zorlama değişkeni, sınıf süzgeci, dilimsiz istisnası)."""

    def __init__(self, symbols=SYMBOLS, force_env=FORCE_ENV, classname_re=None, sliceless=SLICELESS, exclude_re=None):
        self.symbols = tuple(symbols)
        self.exclude_re = re.compile(exclude_re) if exclude_re else None
        self.force_env = force_env
        self.classname_re = re.compile(classname_re) if classname_re else None
        self.sliceless = set(sliceless)
        self.test_re = re.compile(r"^test_([%s])(\d+)[a-z]?_" % "".join(t.lower() for t in self.symbols))


# v2.1 K/M/B testleri de test_k/m/b<N>_ adlıdır; v2.0 kapısı v21 sınıflarını saymaz (tek adlandırma kuralı, T-tur 1).
V2 = Profile(exclude_re=r"v21(?![0-9])")
V202 = Profile(V202_SYMBOLS, "V202_SLICES_FORCE", "v202", ())
V21 = Profile(V21_SYMBOLS, "V21_SLICES_FORCE", "v21", ())


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


def forced(profile: Profile = V2) -> list[str]:
    raw = os.environ.get(profile.force_env, "")
    return [t for t in re.split(r"[\s,]+", raw) if t]


def slice_of(test_name: str, profile: Profile = V2) -> str | None:
    m = profile.test_re.match(test_name)
    if not m:
        return None
    key = (m.group(1).upper(), int(m.group(2)))
    return None if key in profile.sliceless else key[0]


def check_junit(junit: Path, marks: list[str], profile: Profile = V2) -> list[str]:
    errors: list[str] = []
    counts = {s: {"real": 0, "pending": []} for s in marks}
    for case in ET.parse(junit).getroot().iter("testcase"):
        if profile.classname_re and not profile.classname_re.search(case.get("classname", "")):
            continue
        if profile.exclude_re and profile.exclude_re.search(case.get("classname", "")):
            continue
        s = slice_of(case.get("name", ""), profile)
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


def parse_args(argv: list[str]) -> tuple[Profile, Path | None, Path | None] | None:
    """(profil, dilim dosyası, junit) ya da kullanım hatasında None."""
    pos: list[str] = []
    opts: dict[str, str | bool] = {}
    flags_with_value = {"--file", "--symbols", "--force-env", "--classname-re"}
    i = 1
    while i < len(argv):
        a = argv[i]
        if a in flags_with_value and i + 1 < len(argv):
            opts[a] = argv[i + 1]
            i += 2
        elif a in ("--v202", "--v21", "--no-sliceless"):
            opts[a] = True
            i += 1
        elif a.startswith("--"):
            return None
        else:
            pos.append(a)
            i += 1
    base = V21 if opts.get("--v21") else V202 if opts.get("--v202") else V2
    symbols = tuple(t for t in re.split(r"[\s,]+", str(opts["--symbols"])) if t) if "--symbols" in opts else base.symbols
    profile = Profile(
        symbols,
        str(opts.get("--force-env", base.force_env)),
        str(opts["--classname-re"]) if "--classname-re" in opts else (base.classname_re.pattern if base.classname_re else None),
        () if (opts.get("--no-sliceless") or opts.get("--v21")) else base.sliceless,
        base.exclude_re.pattern if base.exclude_re and "--classname-re" not in opts else None,
    )
    file_arg = str(opts["--file"]) if "--file" in opts else (pos.pop(0) if pos else None)
    if file_arg is None or len(pos) > 1:
        return None
    return profile, Path(file_arg), (Path(pos[0]) if pos else None)


def main(argv: list[str]) -> int:
    parsed = parse_args(argv)
    if parsed is None:
        print(__doc__, file=sys.stderr)
        return 2
    profile, path, junit = parsed
    errors: list[str] = []
    marks: list[str] = []
    if not path.is_file():
        errors.append(f"dilim dosyası yok: {path}")
    else:
        ok, marks, errs = parse(path.read_text(encoding="utf-8"), profile.symbols)
        errors += errs
    for t in forced(profile):
        if t not in profile.symbols:
            errors.append(f"{profile.force_env}: geçersiz simge '{t}'")
        elif t not in marks:
            marks.append(t)
    if junit is not None and not errors:
        if not junit.is_file():
            errors.append(f"JUnit yok: {junit}")
        else:
            errors += check_junit(junit, marks, profile)
    for e in errors:
        print("SLICE_ERROR: " + e, file=sys.stderr)
    if not errors:
        print(f"dilim işaretleri: {' '.join(marks) if marks else '(yok)'}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

#!/usr/bin/env python3
"""GUT parça ağırlıklarını (tools/ci/shard_weights.json) JUnit sürelerinden yeniler (F-044, altyapı-B).

  refresh_weights.py --junit J1.xml [J2.xml ...] [--write] [--root DİZİN]

JUnit'teki her testsuite adı bir test dosyasıdır; süre (sn) 0,1'e yuvarlanır, aynı dosya birden çok JUnit'te geçerse toplanır.
Kurallar: JUnit'te geçmeyen dosya eski ağırlığını korur (tek parça JUnit'iyle yenileme güvenlidir); test dizininde artık
olmayan dosyalar silinir; JUnit'te olup test dizininde olmayan ad yazılmaz, stderr'e yazılır. Bozuk/eksik/boş JUnit hata
(çıkış 1) ve ağırlık dosyasına dokunulmaz. --write yoksa yalnız fark yazdırılır. Otomatik commit/push yok: dosyayı sen commit'le.
Biçim shard.py'ninkiyle aynıdır (indent=1, sıralı anahtar) ki fark yalnız değişen sayılarda görünsün.
"""
from __future__ import annotations

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import shard  # noqa: E402


def err(msg: str) -> int:
    print(f"REFRESH_WEIGHTS: {msg}", file=sys.stderr)
    return 1


def read_times(paths: list[str]) -> dict[str, float]:
    times: dict[str, float] = {}
    for p in paths:
        try:
            root = ET.parse(p).getroot()
        except (OSError, ET.ParseError) as e:
            raise ValueError(f"JUnit okunamadı: {p} ({e})") from e
        for ts in root.iter("testsuite"):
            name = ts.get("name") or ""
            times[name] = times.get(name, 0.0) + float(ts.get("time") or 0)
    if not times:
        raise ValueError("JUnit'te hiç testsuite yok (boş/sahte yeşil); ağırlıklar değiştirilmedi")
    return times


def main(argv: list[str]) -> int:
    for stream in (sys.stdout, sys.stderr):  # Windows: konsol kod sayfası yerine UTF-8 (boru hattında Türkçe bozulmasın)
        stream.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--junit", nargs="+", required=True, metavar="J")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--root", type=Path, default=shard.ROOT)
    args = ap.parse_args(argv)

    weights_path = args.root / "tools" / "ci" / "shard_weights.json"
    old = json.loads(weights_path.read_text(encoding="utf-8")) if weights_path.is_file() else {}
    files = set(shard.discover(args.root))
    try:
        times = read_times(args.junit)
    except ValueError as e:
        return err(str(e))

    unknown = sorted(set(times) - files)
    for u in unknown:
        print(f"REFRESH_WEIGHTS: JUnit'te olup test dizininde olmayan ad atlandı: {u}", file=sys.stderr)

    new = {f: old[f] for f in files if f in old}
    for f in files & set(times):
        new[f] = round(times[f], 1)

    added = sorted(set(new) - set(old))
    removed = sorted(set(old) - set(new))
    changed = sorted(f for f in set(new) & set(old) if new[f] != old[f])
    for f in added:
        print(f"+ {f}: {new[f]}")
    for f in changed:
        print(f"~ {f}: {old[f]} -> {new[f]}")
    for f in removed:
        print(f"- {f}: {old[f]}")
    still = sorted(files - set(new))
    print(f"özet: +{len(added)} ~{len(changed)} -{len(removed)}; ağırlıksız kalan: {len(still)}")
    for f in still:
        print(f"REFRESH_WEIGHTS: ağırlıksız (JUnit'te yok): {f}", file=sys.stderr)

    if args.write:
        weights_path.write_text(json.dumps(new, indent=1, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"yazıldı: {weights_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

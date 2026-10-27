#!/usr/bin/env python3
"""GUT test dosyalarını N parçaya böler (F-044) ve parça JUnit çıktılarını birleştirir.

  shard.py list                       .gutconfig.json'daki dizinlerde bulunan tüm test dosyaları (gate'in koştuğu küme)
  shard.py assign K N                 K. parçanın (1..N) dosyaları, satır başına bir yol
  shard.py config K N ÇIKTI.json      .gutconfig.json'un kopyası: dirs boş, tests = K. parçanın dosyaları, junit yolu
                                      verilmişse (--junit res://...) o yola yazılır
  shard.py config-files LİSTE ÇIKTI.json  hızlı mod: LİSTE'deki dosyalar için aynı yapılandırma (junit yolu .gutconfig.json'dakidir)
  shard.py check-dirs [CONFIG.json]   .gutconfig.json'daki her dizin var olmalı (parçalı yol dirs'i boşalttığı için GUT'un
                                      "olmayan dizin" [GUT ERROR]'u oluşmaz; burada açıkça kırmızı, F-066)
  shard.py merge ÇIKTI.xml G1.xml...  parça JUnit dosyalarını tek dosyada birleştirir (testsuite'ler eklenir)
  shard.py check-merge [--require-all] K1.xml...
                                      her test dosyası en çok bir parçada, bilinmeyen dosya yok; --require-all ile ayrıca
                                      list çıktısındaki HER dosya bir parçada bulunmalı (eksik parça = kırmızı)

Atama deterministiktir: ağırlıklar tools/ci/shard_weights.json (dosya -> sn); ağırlığı olmayan dosya medyan ağırlık alır
(yeni dosya otomatik bir parçaya düşer). Açgözlü en-uzun-önce (LPT): her dosya o ana dek en hafif parçaya. Tüm parçaların
birleşimi = list çıktısı olması yapı gereğidir (tools/ci/tests/test_shard.py + gate'in doğrulama aşaması denetler).
"""
from __future__ import annotations

import json
import statistics
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WEIGHTS = Path(__file__).resolve().parent / "shard_weights.json"


def discover(root: Path = ROOT) -> list[str]:
    cfg = json.loads((root / ".gutconfig.json").read_text(encoding="utf-8"))
    prefix, suffix = cfg.get("prefix", "test_"), cfg.get("suffix", ".gd")
    found: list[str] = []
    for d in cfg["dirs"]:
        base = root / d.removeprefix("res://")
        if not base.is_dir():
            continue
        it = base.rglob("*") if cfg.get("include_subdirs") else base.glob("*")
        for p in it:
            if p.is_file() and p.name.startswith(prefix) and p.name.endswith(suffix):
                found.append(p.relative_to(root).as_posix())
    return sorted(set(found))


def assign(files: list[str], n: int, weights: dict[str, float]) -> list[list[str]]:
    known = [weights[f] for f in files if f in weights]
    default = statistics.median(known) if known else 1.0
    w = {f: float(weights.get(f, default)) for f in files}
    shards: list[list[str]] = [[] for _ in range(n)]
    load = [0.0] * n
    for f in sorted(files, key=lambda x: (-w[x], x)):
        i = min(range(n), key=lambda k: (load[k], k))
        shards[i].append(f)
        load[i] += w[f]
    return [sorted(s) for s in shards]


def load_weights() -> dict[str, float]:
    return json.loads(WEIGHTS.read_text(encoding="utf-8")) if WEIGHTS.is_file() else {}


def merge(paths: list[str]) -> ET.Element:
    out = ET.Element("testsuites")
    totals = {"tests": 0, "failures": 0, "errors": 0}
    for p in paths:
        for ts in ET.parse(p).getroot().iter("testsuite"):
            out.append(ts)
            for k in totals:
                totals[k] += int(ts.get(k) or 0)
    for k, v in totals.items():
        out.set(k, str(v))
    return out


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    cmd = argv[1]
    if cmd == "list":
        print("\n".join(discover()))
        return 0
    if cmd in ("assign", "config"):
        k, n = int(argv[2]), int(argv[3])
        if not 1 <= k <= n:
            print(f"SHARD_ERROR: parça {k}/{n} geçersiz", file=sys.stderr)
            return 2
        files = assign(discover(), n, load_weights())[k - 1]
        if cmd == "assign":
            print("\n".join(files))
            return 0
        cfg = json.loads((ROOT / ".gutconfig.json").read_text(encoding="utf-8"))
        cfg["dirs"] = []
        cfg["tests"] = ["res://" + f for f in files]
        if "--junit" in argv:
            cfg["junit_xml_file"] = argv[argv.index("--junit") + 1]
        Path(argv[4]).write_text(json.dumps(cfg, indent=2), encoding="utf-8")
        return 0
    if cmd == "config-files":
        cfg = json.loads((ROOT / ".gutconfig.json").read_text(encoding="utf-8"))
        cfg["dirs"] = []
        cfg["tests"] = ["res://" + f for f in Path(argv[2]).read_text(encoding="utf-8").split()]
        Path(argv[3]).write_text(json.dumps(cfg, indent=2), encoding="utf-8")
        return 0
    if cmd == "check-dirs":
        path = Path(argv[2]) if len(argv) > 2 else ROOT / ".gutconfig.json"
        cfg = json.loads(path.read_text(encoding="utf-8"))
        gone = [d for d in cfg["dirs"] if not (ROOT / d.removeprefix("res://")).is_dir()]
        for d in gone:
            print(f"SHARD_ERROR: .gutconfig.json dizini yok: {d}", file=sys.stderr)
        return 1 if gone else 0
    if cmd == "merge":
        ET.ElementTree(merge(argv[3:])).write(argv[2], encoding="utf-8", xml_declaration=True)
        return 0
    if cmd == "check-merge":
        seen: dict[str, int] = {}
        require_all = "--require-all" in argv
        for p in [a for a in argv[2:] if a != "--require-all"]:
            for ts in ET.parse(p).getroot().iter("testsuite"):
                seen[ts.get("name")] = seen.get(ts.get("name"), 0) + 1
        want = set(discover())
        dup = sorted(f for f, c in seen.items() if c > 1)
        # Testsuite'i olmayan dosya (içinde hiç test işlevi yok) merge öncesi de JUnit'te yoktur; asgari sayı denetimi
        # (check_junit + gate_min_tests.json) o dosyaları ayrıca yakalar. Burada yalnız yinelenme ve bilinmeyen dosya.
        extra = sorted(set(seen) - want)
        missing = sorted(want - set(seen)) if require_all else []
        for f in missing:
            print(f"SHARD_ERROR: {f} hiçbir parçada koşmadı (JUnit'te yok)", file=sys.stderr)
        for f in dup:
            print(f"SHARD_ERROR: {f} birden çok parçada", file=sys.stderr)
        for f in extra:
            print(f"SHARD_ERROR: {f} tüm test dosyaları listesinde yok", file=sys.stderr)
        return 1 if dup or extra or missing else 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))

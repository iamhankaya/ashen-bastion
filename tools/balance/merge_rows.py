#!/usr/bin/env python3
"""Alt iş çıktılarını (balance.yml parçaları) tek jsonl'a birleştirir: python3 tools/balance/merge_rows.py <dizin> <çıktı.jsonl>

Satırlar `(mod, zorluk, karakter, politika, tohum)` anahtarına göre sıralanır; yinelenen anahtar hatadır (aynı tohum iki
parçada koşmuş demektir, baseline sessizce çift sayılmasın). Çıkış: 0 tamam, 1 yinelenen anahtar, 2 girdi hatası.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mid_rows  # noqa: E402


def main(argv=None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        rows = mid_rows.read_jsonl_files(argv[0])
    except (OSError, ValueError) as e:
        print(f"girdi hatası: {e}", file=sys.stderr)
        return 2
    keyed: dict[tuple, dict] = {}
    for r in rows:
        k = mid_rows.row_key(r)
        if k in keyed:
            print(f"yinelenen anahtar: {k}", file=sys.stderr)
            return 1
        keyed[k] = r
    Path(argv[1]).write_text("".join(json.dumps(keyed[k], sort_keys=True) + "\n" for k in sorted(keyed)), encoding="utf-8")
    print(f"{len(keyed)} satır -> {argv[1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

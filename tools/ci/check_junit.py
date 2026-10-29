#!/usr/bin/env python3
"""JUnit sağlık denetimi: çalışan (skip olmayan) test toplamı > 0.

Dosya başına asgari sayı tablosu emekli: kimlik düzeyindeki kayıp denetimi tools/ci/check_test_ids.py'dedir
(gate.sh adım 7). Burada yalnız "JUnit boş/tamamen skip" kaba korumasını tutarız (check_test_ids yoksa da sahte yeşil olmasın).
"""
import sys
import xml.etree.ElementTree as ET


def main(junit: str) -> int:
    root = ET.parse(junit).getroot()
    # pending/skip edilen testler sayılmaz (hiçbir şey doğrulamazlar)
    ran = sum(int(ts.get("tests")) - int(ts.get("skipped") or 0) for ts in root.iter("testsuite"))
    if ran == 0:
        print("GATE_JUNIT: JUnit toplam çalışan test sayısı sıfır", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("kullanım: check_junit.py JUNIT.xml", file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))

# prova yaması (b): ölçüm sentetik iş yükü

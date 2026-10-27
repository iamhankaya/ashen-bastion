#!/usr/bin/env python3
"""JUnit test sürelerini denetler (F-028/M-C): tek test > LIMIT sn ise hata (bilinçli istisna test/long/ — GUT
dizinlerinde değildir); > WARN sn olanlar bilgi olarak listelenir; toplam GUT süresi > TOTAL_WARN sn ise uyarı
(uyarı gate'i durdurmaz). Kullanım: check_durations.py <junit.xml> [--limit 75] [--warn 20] [--total-warn 720] [--contended]

--contended: JUnit, GUT'u N>1 süreçte paralel koşan bir gate'ten gelir (yerel/selftest tam gate). Testler CPU'yu paylaşır;
JUnit süresi izole süreyi ~2 kat şişirir (run 40460222973: 41,9 -> 75,1 sn) ve toplam, ardışık duvar saatinin üstüne çıkar. 75/720 sn
eşikleri ardışık koşuya göre ayarlıdır; bu yüzden bu modda tek-test aşımı hata değil GATE_SLOW_CONTENDED uyarısı, toplam uyarısı
yoktur. Sert denetim çekişmesiz ölçümde kalır: CI gut parçaları (iş başına tek süreç; verify işi birleşik JUnit'i böyle denetler)
ve GATE_JOBS=1.
"""

import argparse
import sys
import xml.etree.ElementTree as ET


def check(junit: str, limit: float, warn: float, total_warn: float):
    root = ET.parse(junit).getroot()
    slow, notice, total = [], [], 0.0
    for tc in root.iter("testcase"):
        t = float(tc.get("time") or 0.0)
        total += t
        name = f"{tc.get('classname')}::{tc.get('name')}"
        if t > limit:
            slow.append((name, t))
        elif t > warn:
            notice.append((name, t))
    return slow, notice, total


def main(argv) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("junit")
    ap.add_argument("--limit", type=float, default=75.0)
    ap.add_argument("--warn", type=float, default=20.0)
    ap.add_argument("--total-warn", type=float, default=720.0)
    ap.add_argument("--contended", action="store_true", help="JUnit paralel (CPU paylaşan) koşudan: sert denetim yok")
    a = ap.parse_args(argv)
    slow, notice, total = check(a.junit, a.limit, a.warn, a.total_warn)
    for name, t in sorted(notice, key=lambda x: -x[1]):
        print(f"GATE_SLOW_INFO: {t:.1f} sn > {a.warn:.0f} sn: {name}")
    if total > a.total_warn and not a.contended:
        print(
            f"GATE_WARN: toplam test süresi {total:.0f} sn > {a.total_warn:.0f} sn "
            "(test job'ı 15 dk sınırına yaklaşıyor; bölme/sınır artırma işi aç)",
            file=sys.stderr,
        )
    for name, t in slow:
        if a.contended:
            print(
                f"GATE_SLOW_CONTENDED: {t:.1f} sn > {a.limit:.0f} sn: {name} (paralel koşuda ölçüldü, hata sayılmaz; "
                "çekişmesiz doğrulama: GATE_JOBS=1 ya da CI gut parçası)",
                file=sys.stderr,
            )
            continue
        print(
            f"GATE_SLOW: {t:.1f} sn > {a.limit:.0f} sn: {name} (ağır test test/long/ altına taşınır)",
            file=sys.stderr,
        )
    return 1 if slow and not a.contended else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

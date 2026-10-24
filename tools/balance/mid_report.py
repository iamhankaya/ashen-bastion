#!/usr/bin/env python3
"""mid_all.sh çıktısını tabloya çevirir: python3 tools/balance/mid_report.py <dizin>"""
import glob, json, statistics as st, sys

rows = []
for p in glob.glob(sys.argv[1] + "/*.jsonl"):
    rows += [json.loads(l) for l in open(p) if l.strip()]
print("| politika | karakter | n | süre medyan | süre ort. | hp 0-5dk | hp 10-20dk | 5dk öldürme | 5dk seviye | 20dk'ya ulaşan |")
print("|---|---|---|---|---|---|---|---|---|---|")
for pol in ("strong", "kite", "greedy", "idle"):
    for ch in ("gunslinger", "barutcu", "hepsi"):
        r = [x for x in rows if x["policy"] == pol and (ch == "hepsi" or x["character"] == ch)]
        if not r:
            continue
        t = [x["time"] for x in r]
        e = [x["hp_early"] for x in r if x["hp_early"] >= 0]
        m = [x["hp_mid"] for x in r if x["hp_mid"] >= 0]
        k5 = [x["kills5"] for x in r if x["kills5"] >= 0]
        l5 = [x["level5"] for x in r if x["level5"] >= 0]
        f = lambda v: "%.3f" % st.mean(v) if v else "–"
        print(f"| {pol} | {ch} | {len(r)} | {st.median(t):.1f} | {st.mean(t):.1f} | {f(e)} | {f(m)} ({len(m)}) | {f(k5)} | {f(l5)} | {sum(1 for x in r if x['time'] >= 1199)} |")

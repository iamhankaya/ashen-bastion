#!/usr/bin/env python3
"""A/B raporu: tools/balance/ab_all.sh çıktısını (on_*/off_* JSON) tablolara çevirir. Denge AYARI yapmaz; veri üretir.

Kullanım: python3 tools/balance/ab_report.py <dizin> [rapor_tablolari.md] [birlesik.json]
"""
import glob
import json
import os
import random
import statistics as st
import sys
from collections import Counter

LATE = 870.0


def load(d):
    rows = []
    for f in sorted(glob.glob(os.path.join(d, "*.json"))):
        if os.path.basename(f) == "combined.json":
            continue
        rows += json.load(open(f))
    return rows


def q(v, p):
    v = sorted(v)
    if not v:
        return float("nan")
    k = (len(v) - 1) * p
    lo, hi = int(k), min(int(k) + 1, len(v) - 1)
    return v[lo] + (v[hi] - v[lo]) * (k - lo)


def by(rows, policy, arm):
    return {r["seed"]: r for r in rows if r["policy"] == policy and r["pickups"] == (arm == "on")}


def fmt(x, d=1):
    return "–" if x != x else f"{x:.{d}f}"


def summary_table(rows, pairs):
    out = ["| Politika | Kol | n | Hayatta kalma ort./medyan/p25–p75 (sn) | ≥870 sn (14,5 dk) / ≥1200 sn (Lord) | Seviye (medyan) | Öldürme (medyan) | Skor (medyan) | SERİ ×5 oranı | can<%50 sn (medyan) | Ort. geç oyun ≥300 düşman oranı |",
           "|---|---|---|---|---|---|---|---|---|---|---|"]
    for pol, arm in pairs:
        d = by(rows, pol, arm)
        r = list(d.values())
        if not r:
            continue
        t = [x["time"] for x in r]
        late = [x for x in r if x["late_steps"] > 0]
        lc = sum(x["late_crowd_steps"] for x in late) / max(1, sum(x["late_steps"] for x in late)) if late else float("nan")
        out.append("| %s | %s | %d | %s / %s / %s–%s | %d / %d | %s | %s | %s | %.0f%% | %s | %s |" % (
            pol, "eklentili" if arm == "on" else "eklentisiz", len(r), fmt(st.mean(t)), fmt(st.median(t)), fmt(q(t, .25)), fmt(q(t, .75)),
            sum(1 for x in r if x["time"] >= LATE), sum(1 for x in r if x["time"] >= 1200), fmt(st.median(x["level"] for x in r), 0),
            fmt(st.median(x["kills"] for x in r), 0), fmt(st.median(x["score"] for x in r), 0),
            100.0 * sum(1 for x in r if x["best_mult"] >= 5) / len(r), fmt(st.median(x["secs_below_half"] for x in r), 0),
            ("%.2f" % lc) if lc == lc else "–"))
    return out


def deaths_table(rows, pairs):
    kinds = sorted({x["death_cause"] for x in rows if x["death_cause"]})
    out = ["| Politika | Kol | ölen | " + " | ".join(kinds) + " | ölmeyen |", "|---|---|---|" + "---|" * len(kinds) + "---|"]
    for pol, arm in pairs:
        r = list(by(rows, pol, arm).values())
        if not r:
            continue
        c = Counter(x["death_cause"] for x in r if x["result"] == "lost")
        lost = sum(c.values())
        out.append("| %s | %s | %d | %s | %d |" % (pol, "eklentili" if arm == "on" else "eklentisiz", lost,
                   " | ".join("%d (%.0f%%)" % (c[k], 100.0 * c[k] / max(lost, 1)) for k in kinds), len(r) - lost))
    return out


def paired(rows, pol_on, pol_off, rng):
    a, b = by(rows, pol_on, "on"), by(rows, pol_off, "off")
    seeds = sorted(set(a) & set(b))
    d = [a[s]["time"] - b[s]["time"] for s in seeds]
    if not d:
        return None
    meds = []
    for _ in range(2000):
        meds.append(st.median(rng.choice(d) for _ in d))
    meds.sort()
    better = sum(1 for x in d if x > 0.05)
    worse = sum(1 for x in d if x < -0.05)
    p = float("nan")
    try:
        from scipy.stats import wilcoxon
        if any(abs(x) > 0.05 for x in d):
            p = wilcoxon(d).pvalue
    except Exception:
        pass
    return {"n": len(d), "med": st.median(d), "mean": st.mean(d), "lo": meds[50], "hi": meds[1949],
            "better": better, "worse": worse, "p": p,
            "dscore": st.median(a[s]["score"] - b[s]["score"] for s in seeds),
            "dlevel": st.median(a[s]["level"] - b[s]["level"] for s in seeds)}


def pickup_table(rows):
    kinds = sorted({k for x in rows for k in x["pickups_collected"]})
    out = ["| Politika (eklentili) | koşu başına toplanan | " + " | ".join(kinds) + " | buff etkin sn (hasar / atış hızı / sınırsız) |", "|---|---|" + "---|" * len(kinds) + "---|"]
    for pol in ("idle", "kite", "greedy", "greedy_pickup"):
        r = list(by(rows, pol, "on").values())
        if not r:
            continue
        tot = [sum(x["pickups_collected"].values()) for x in r]
        per = [st.mean(x["pickups_collected"].get(k, 0) for x in r) for k in kinds]
        up = [st.mean(x["buff_uptime"].get(k, 0) for x in r) for k in ("damage", "fire_rate", "unlimited")]
        out.append("| %s | %.2f | %s | %s |" % (pol, st.mean(tot), " | ".join("%.2f" % v for v in per), " / ".join("%.1f" % v for v in up)))
    return out


def main(d, out_md=None, out_json=None):
    rows = load(d)
    rng = random.Random(1)
    if out_json:
        json.dump(rows, open(out_json, "w"), separators=(",", ":"))
    pairs = [(p, a) for p in ("idle", "kite", "greedy", "greedy_pickup") for a in ("off", "on")]
    lines = ["## Özet (kol başına)", ""] + summary_table(rows, pairs)
    lines += ["", "## Ölüm nedeni dağılımı (yalnız ölen koşular; tür = son hasarda oyuncuya değen en yüksek temas hasarlı düşman)", ""] + deaths_table(rows, pairs)
    lines += ["", "## Eşli fark (aynı tohum, eklentili − eklentisiz; hayatta kalma süresi sn)", "",
              "| Karşılaştırma | n | medyan fark | ort. fark | medyan %95 GA (bootstrap) | eklentili daha uzun / kısa | Wilcoxon p | medyan skor farkı | medyan seviye farkı |", "|---|---|---|---|---|---|---|---|---|"]
    for on, off in (("idle", "idle"), ("kite", "kite"), ("greedy", "greedy"), ("greedy_pickup", "greedy")):
        r = paired(rows, on, off, rng)
        if r:
            lines.append("| %s (eklentili) − %s (eklentisiz) | %d | %+.1f | %+.1f | %+.1f … %+.1f | %d / %d | %s | %+.0f | %+.1f |" % (
                on, off, r["n"], r["med"], r["mean"], r["lo"], r["hi"], r["better"], r["worse"],
                ("%.3f" % r["p"]) if r["p"] == r["p"] else "–", r["dscore"], r["dlevel"]))
    lines += ["", "## Eklenti kullanımı (eklentili kol)", ""] + pickup_table(rows)
    text = "\n".join(lines) + "\n"
    if out_md:
        open(out_md, "w").write(text)
    print(text)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None, sys.argv[3] if len(sys.argv) > 3 else None)

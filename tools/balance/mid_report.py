#!/usr/bin/env python3
"""mid_all.sh çıktısını tabloya çevirir (gate dışı):

  python3 tools/balance/mid_report.py <dizin> [--policy P] [--char C]
         [--diff mod:zorluk mod:zorluk]          iki hücre arasında kazanma / Lord'a ulaşma farkı (bootstrap %95 GA)
         [--level-ratio quick:normal normal:normal]  Hızlı level_at_end / Normal level_at_1200 (medyanlar)
         [--sanity [--cell normal:easy]]         strong_lord sağlama eşiği: Lord'a ulaşanların medyan lord_hp_frac_end <= 0,5
Satır alanları: tools/balance/mid_run.gd. mod/zorluk alanı olmayan (v2.0.x) satırlar normal:hard sayılır.
Medyan Lord süresi yalnız lord_end=killed koşulardan; sansürlü (Lord'u öldüremeyen) sayısı ayrı yazılır.
Çıkış: 0 tamam, 1 --sanity başarısız, 2 girdi hatası.
"""
from __future__ import annotations

import statistics as st
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mid_rows  # noqa: E402

SANITY_MAX_MEDIAN = 0.5
LEGACY_HEADER = ["| politika | karakter | n | süre medyan | süre ort. | hp 0-5dk | hp 10-20dk | 5dk öldürme | 5dk seviye | 20dk'ya ulaşan |",
                 "|---|---|---|---|---|---|---|---|---|---|"]
LORD_HEADER = ["| hücre | politika | karakter | n | kazanma % (GA) | Lord'a ulaşma % | medyan Lord sn (öldürülen) | sansürlü | vur oranı |",
               "|---|---|---|---|---|---|---|---|---|"]


def _boot_ci(vals: list[float], boot: int = 2000, seed: int = 1) -> tuple[float, float]:
    x = np.array(vals, dtype=float)
    rng = np.random.default_rng(seed)
    idx = rng.integers(0, len(x), size=(boot, len(x)))
    m = x[idx].mean(axis=1)
    return float(np.percentile(m, 2.5)), float(np.percentile(m, 97.5))


def diff_ci(a: list[dict], b: list[dict], fn, boot: int = 2000, seed: int = 1) -> dict:
    """mean(fn(a)) - mean(fn(b)) ve bağımsız bootstrap %95 GA."""
    xa, xb = np.array([fn(r) for r in a], dtype=float), np.array([fn(r) for r in b], dtype=float)
    rng = np.random.default_rng(seed)
    ma = xa[rng.integers(0, len(xa), size=(boot, len(xa)))].mean(axis=1)
    mb = xb[rng.integers(0, len(xb), size=(boot, len(xb)))].mean(axis=1)
    d = ma - mb
    return {"diff": float(xa.mean() - xb.mean()), "lo": float(np.percentile(d, 2.5)), "hi": float(np.percentile(d, 97.5))}


def cell_stats(rows: list[dict]) -> dict:
    reached = [r for r in rows if r.get("reached_lord")]
    killed = [r for r in reached if r.get("lord_end") == "killed"]
    won = [1.0 if r.get("won") else 0.0 for r in rows]
    return {
        "n": len(rows),
        "win_pct": 100.0 * sum(won) / len(rows) if rows else 0.0,
        "win_ci": tuple(100.0 * v for v in _boot_ci(won)) if rows else (0.0, 0.0),
        "reach_pct": 100.0 * len(reached) / len(rows) if rows else 0.0,
        "lord_secs_median": st.median([r["lord_alive_secs"] for r in killed]) if killed else None,
        "lord_censored": len(reached) - len(killed),
        "hit_frac_mean": st.mean([r["lord_hit_frac"] for r in reached]) if reached else None,
    }


def level_ratio(quick: list[dict], normal: list[dict]) -> float | None:
    q = [r["level_at_end"] for r in quick if r.get("level_at_end", -1) >= 0]
    n = [r["level_at_1200"] for r in normal if r.get("level_at_1200", -1) >= 0]
    if not q or not n:
        return None
    return round(st.median(q) / st.median(n), 3)


def sanity(rows: list[dict]) -> dict:
    """Kolay'da Lord'a ulaşanların medyan lord_hp_frac_end <= 0,5 mi (strong_lord gerçekten vuruyor mu)."""
    v = [r["lord_hp_frac_end"] for r in rows if r.get("reached_lord") and r.get("lord_hp_frac_end", -1.0) >= 0]
    if not v:
        return {"pass": None, "median": None, "n": 0}
    med = st.median(v)
    return {"pass": bool(med <= SANITY_MAX_MEDIAN), "median": med, "n": len(v)}


def _f(v) -> str:
    return "%.3f" % st.mean(v) if v else "–"


def legacy_rows(rows: list[dict]) -> list[str]:
    out = []
    for pol in ("strong", "strong_lord", "kite", "greedy", "idle"):
        for ch in ("gunslinger", "zyfen", "hepsi"):
            r = [x for x in rows if x["policy"] == pol and (ch == "hepsi" or x["character"] == ch)]
            if not r:
                continue
            t = [x["time"] for x in r]
            e = [x["hp_early"] for x in r if x["hp_early"] >= 0]
            m = [x["hp_mid"] for x in r if x["hp_mid"] >= 0]
            k5 = [x["kills5"] for x in r if x["kills5"] >= 0]
            l5 = [x.get("level5", -1) for x in r if x.get("level5", -1) >= 0]
            reach = sum(1 for x in r if x["time"] >= mid_rows.consts(x["mode"])["cap"] - 1.0)
            out.append(f"| {pol} | {ch} | {len(r)} | {st.median(t):.1f} | {st.mean(t):.1f} | {_f(e)} | {_f(m)} ({len(m)}) | {_f(k5)} | {_f(l5)} | {reach} |")
    return out


def cells(rows: list[dict]) -> list[tuple]:
    return sorted({mid_rows.cell_of(r) for r in rows})


def main(argv=None) -> int:
    import argparse

    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dir")
    ap.add_argument("--policy")
    ap.add_argument("--char")
    ap.add_argument("--diff", nargs=2, metavar=("A", "B"))
    ap.add_argument("--level-ratio", nargs=2, metavar=("QUICK", "NORMAL"))
    ap.add_argument("--sanity", action="store_true")
    ap.add_argument("--cell", default="normal:easy")
    a = ap.parse_args(argv)
    try:
        rows = mid_rows.read_jsonl_files(a.dir)
        sel = {k: mid_rows.parse_cell(v) for k, v in (("diff0", a.diff[0]), ("diff1", a.diff[1])) } if a.diff else {}
        lr = [mid_rows.parse_cell(v) for v in a.level_ratio] if a.level_ratio else None
        sanity_cell = mid_rows.parse_cell(a.cell)
    except (OSError, ValueError) as e:
        print(f"girdi hatası: {e}", file=sys.stderr)
        return 2
    if a.policy:
        rows = [r for r in rows if r["policy"] == a.policy]
    if a.char:
        rows = [r for r in rows if r["character"] == a.char]

    def of(cell):
        return [r for r in rows if mid_rows.cell_of(r) == cell]

    multi = cells(rows) != [mid_rows.LEGACY_CELL]
    for cell in cells(rows):
        if multi:
            print(f"\n### {cell[0]}:{cell[1]}\n")
        print("\n".join(LEGACY_HEADER + legacy_rows(of(cell))))
    if any("reached_lord" in r for r in rows):
        print("\n" + "\n".join(LORD_HEADER))
        for cell in cells(rows):
            for pol in sorted({r["policy"] for r in of(cell)}):
                for ch in sorted({r["character"] for r in of(cell)}):
                    sub = [r for r in of(cell) if r["policy"] == pol and r["character"] == ch]
                    if not sub:
                        continue
                    s = cell_stats(sub)
                    med = "–" if s["lord_secs_median"] is None else f"{s['lord_secs_median']:.1f}"
                    hit = "–" if s["hit_frac_mean"] is None else f"{s['hit_frac_mean']:.3f}"
                    print(f"| {cell[0]}:{cell[1]} | {pol} | {ch} | {s['n']} | {s['win_pct']:.1f} ({s['win_ci'][0]:.1f}…{s['win_ci'][1]:.1f}) | "
                          f"{s['reach_pct']:.1f} | {med} | {s['lord_censored']} | {hit} |")
    if sel:
        ra, rb = of(sel["diff0"]), of(sel["diff1"])
        if not ra or not rb:
            print("fark: bir hücre boş", file=sys.stderr)
            return 2
        for name, fn in (("kazanma", lambda r: 1.0 if r.get("won") else 0.0), ("Lord'a ulaşma", lambda r: 1.0 if r.get("reached_lord") else 0.0)):
            d = diff_ci(ra, rb, fn)
            print(f"\nfark {a.diff[0]} - {a.diff[1]} {name}: {d['diff'] * 100:+.1f} puan (%95 GA {d['lo'] * 100:+.1f}…{d['hi'] * 100:+.1f})")
    if lr:
        ratio = level_ratio(of(lr[0]), of(lr[1]))
        print(f"\nHızlı–Normal seviye oranı (level_at_end / level_at_1200, medyan): {'–' if ratio is None else ratio}")
    if a.sanity:
        res = sanity(of(sanity_cell))
        verdict = {True: "GEÇTİ", False: "KALDI", None: "KARAR YOK (Lord'a ulaşan koşu yok)"}[res["pass"]]
        print(f"\nSağlama ({a.cell}, medyan lord_hp_frac_end <= {SANITY_MAX_MEDIAN}): {verdict} (medyan {res['median']}, n={res['n']})")
        return 1 if res["pass"] is False else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())

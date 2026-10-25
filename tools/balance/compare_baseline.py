#!/usr/bin/env python3
"""Baseline karşılaştırması (v2.0.2 S2, gate dışı): Gunslinger dengesinin v2.0.1'e göre ±%5 içinde kalıp kalmadığını
bootstrap %95 güven aralığıyla ölçer.

  python3 tools/balance/compare_baseline.py <taban> <yeni> [--char gunslinger] [--noise <B>] [--nodyn <nodyn>]
         [--gate-policies strong,kite] [--info-policies greedy,idle] [--boot 4000] [--seed 1] [--band 0.05]
         [--noise-limit 0.025] [--out rapor.md] [--json rapor.json]

Girdiler: `mid_run.gd` çıktısı (satır başına bir JSON) içeren .jsonl dosyası ya da dizini (tools/balance/baseline_run.sh
çıktıları: docs/design/v2.0.2/balance/baseline-v201-A.jsonl vb.). <taban> = v201-A, <yeni> = yeni kodun A kümesi koşusu.
`--noise` (v201-B) gürültü tabanını, `--nodyn` (v201-nodyn-A) sapma kaynağı ayrıştırmasını açar.

Metrikler (politika başına): survival = ölüm anı, 20 dk'ya ulaşan sansürlü (20 dk sayılır), MEDYAN; hp_mid = 10-20 dk
can oranı ortalaması, ölen koşular 0 sayılır (ortalama); reach10 = 10 dk'ya ulaşan oran (yalnız raporlanır).
Karar dışı yardımcı ölçütler (v2.0.2 400 tohum): kills5 = 5. dk'daki öldürme sayısı (5 dk'ya ulaşmayan koşu hariç, ortalama),
hp_early = 0-5 dk can oranı ortalaması (ortalama). Üçü (reach10 dahil) karara girmez; yalnız A-B gürültü tabanı ve GA raporlanır.
Ölçüt: yeni istatistiğin %95 GA'sı tabanın ±%5 bandıyla çelişmiyor (kesişiyor). Gürültü tabanı (A ile B arasındaki göreli fark)
±%2,5'i aşıyorsa o metrik için sonuç "ölçülemedi" (tohum artırılır). Karar yalnız kapı politikaları (strong, kite) için;
greedy/idle bilgi amaçlıdır. Rapor sapmayı ayrıştırır: (v201 → nodyn) = dinamit kaybı, (nodyn → yeni) = havuz süzgeci/diğer.

Bot dengesi ölçülüyor, oyun dengesi değil.
Çıkış: 0 hepsi PASS, 1 FAIL var, 3 ÖLÇÜLEMEDİ var (FAIL yok), 2 kullanım/girdi hatası.
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import sys
from pathlib import Path

import numpy as np

CAP = 1200.0
SURVIVED = 1199.0  # mid_run.gd: 72000 adım = 1200 sn; >= 1199 hayatta
MID_START = 600.0
DISCLAIMER = "Bot dengesi ölçülüyor, oyun dengesi değil."


def load(path: str, char: str | None = None) -> list[dict]:
    p = Path(path)
    files = sorted(glob.glob(str(p / "*.jsonl"))) if p.is_dir() else [str(p)]
    if not files:
        raise FileNotFoundError(f"girdi yok: {path}")
    rows: list[dict] = []
    for f in files:
        with open(f, encoding="utf-8") as fh:
            rows += [json.loads(line) for line in fh if line.strip()]
    if char:
        rows = [r for r in rows if r.get("character") == char]
    return rows


def survival(r: dict) -> float:
    return CAP if r["time"] >= SURVIVED else float(r["time"])


def hp_mid(r: dict) -> float:
    """Ölen koşu 0 sayılır; hayatta kalanın 10-20 dk ortalaması (örnek yoksa 0)."""
    if r["time"] < SURVIVED or r.get("hp_mid", -1.0) < 0:
        return 0.0
    return float(r["hp_mid"])


def reach10(r: dict) -> float:
    return 1.0 if r["time"] >= MID_START else 0.0


def kills5(r: dict) -> float | None:
    """5. dk'daki öldürme; 5 dk'ya ulaşamayan koşuda mid_run.gd -1 yazar => eksik (None)."""
    return float(r["kills5"]) if r.get("kills5", -1) >= 0 else None


def hp_early(r: dict) -> float | None:
    """0-5 dk can oranı ortalaması; örnek yoksa (-1) eksik (None)."""
    return float(r["hp_early"]) if r.get("hp_early", -1.0) >= 0 else None


METRICS = {
    "survival": (survival, np.median),
    "hp_mid": (hp_mid, np.mean),
    "reach10": (reach10, np.mean),
    "kills5": (kills5, np.mean),
    "hp_early": (hp_early, np.mean),
}
GATE_METRICS = ("survival", "hp_mid")
AUX_METRICS = ("reach10", "kills5", "hp_early")  # karar dışı


def values(rows: list[dict], policy: str, metric: str) -> dict[int, float]:
    fn = METRICS[metric][0]
    out = {int(r["seed"]): fn(r) for r in rows if r["policy"] == policy}
    return {k: v for k, v in out.items() if v is not None}


def boot_ci(x: np.ndarray, stat, rng: np.random.Generator, n: int) -> tuple[float, float]:
    idx = rng.integers(0, len(x), size=(n, len(x)))
    s = np.array([stat(x[i]) for i in idx])
    return float(np.percentile(s, 2.5)), float(np.percentile(s, 97.5))


def rel_diff_ci(a: np.ndarray, b: np.ndarray, stat, rng: np.random.Generator, n: int, paired: bool) -> tuple[float, float, float]:
    """(b'nin a'ya göre göreli farkı = stat(b)/stat(a) - 1) nokta, GA alt, GA üst. Taban 0 ise nan."""
    base = float(stat(a))
    if base == 0.0:
        return float("nan"), float("nan"), float("nan")
    out = np.empty(n)
    if paired:
        idx = rng.integers(0, len(a), size=(n, len(a)))
        for k in range(n):
            sa = stat(a[idx[k]])
            out[k] = (stat(b[idx[k]]) / sa - 1.0) if sa else np.nan
    else:
        ia = rng.integers(0, len(a), size=(n, len(a)))
        ib = rng.integers(0, len(b), size=(n, len(b)))
        for k in range(n):
            sa = stat(a[ia[k]])
            out[k] = (stat(b[ib[k]]) / sa - 1.0) if sa else np.nan
    out = out[~np.isnan(out)]
    point = float(stat(b)) / base - 1.0
    if len(out) == 0:
        return point, float("nan"), float("nan")
    return point, float(np.percentile(out, 2.5)), float(np.percentile(out, 97.5))


def compare(base_rows, new_rows, noise_rows=None, nodyn_rows=None, gate_policies=("strong", "kite"),
            info_policies=("greedy", "idle"), boot=4000, seed=1, band=0.05, noise_limit=0.025) -> dict:
    rng = np.random.default_rng(seed)
    res: dict = {"band": band, "noise_limit": noise_limit, "boot": boot, "policies": {}}
    verdicts = []
    for pol in tuple(gate_policies) + tuple(info_policies):
        gate = pol in gate_policies
        pr: dict = {"gate": gate, "metrics": {}}
        for m, (_, stat) in METRICS.items():
            vb, vn = values(base_rows, pol, m), values(new_rows, pol, m)
            if not vb or not vn:
                pr["metrics"][m] = {"error": "veri yok"}
                continue
            a = np.array(list(vb.values()))
            b = np.array(list(vn.values()))
            entry: dict = {"n_base": len(a), "n_new": len(b), "base": float(stat(a)), "new": float(stat(b))}
            lo, hi = boot_ci(b, stat, rng, boot)
            entry["new_ci"] = [lo, hi]
            lo_band, hi_band = entry["base"] * (1 - band), entry["base"] * (1 + band)
            entry["band"] = [lo_band, hi_band]
            entry["in_band"] = bool(hi >= lo_band and lo <= hi_band)
            common = sorted(set(vb) & set(vn))
            if len(common) >= 10:
                pa_, pb_ = (np.array([vb[s] for s in common]), np.array([vn[s] for s in common]))
                entry["paired"] = dict(zip(("diff", "lo", "hi"), rel_diff_ci(pa_, pb_, stat, rng, boot, True)))
            entry["unpaired"] = dict(zip(("diff", "lo", "hi"), rel_diff_ci(a, b, stat, rng, boot, False)))
            if noise_rows is not None:
                vz = values(noise_rows, pol, m)
                if vz:
                    z = np.array(list(vz.values()))
                    nz = abs(float(stat(z)) / entry["base"] - 1.0) if entry["base"] else float("nan")
                    entry["noise"] = {"n": len(z), "value": float(stat(z)), "rel": nz, "over_limit": bool(nz > noise_limit)}
                    nd = dict(zip(("diff", "lo", "hi"), rel_diff_ci(a, z, stat, rng, boot, False)))
                    entry["noise"]["ci"] = nd
                    half = (nd["hi"] - nd["lo"]) / 2
                    # ±band, A-B gürültü GA'sı bandın yarı genişliğinden dar ise çözülebilir (nan => çözülemez)
                    entry["noise"]["band_resolvable"] = bool(half <= band) if not np.isnan(half) else False
            if nodyn_rows is not None:
                vd = values(nodyn_rows, pol, m)
                if vd:
                    d = np.array(list(vd.values()))
                    entry["decomposition"] = {
                        "nodyn": float(stat(d)),
                        "dinamit_loss": dict(zip(("diff", "lo", "hi"), rel_diff_ci(a, d, stat, rng, boot, False))),
                        "filter_other": dict(zip(("diff", "lo", "hi"), rel_diff_ci(d, b, stat, rng, boot, False))),
                    }
            if gate and m in GATE_METRICS:
                if entry.get("noise", {}).get("over_limit"):
                    entry["verdict"] = "ÖLÇÜLEMEDİ"
                elif entry["in_band"]:
                    entry["verdict"] = "PASS"
                else:
                    entry["verdict"] = "FAIL"
                verdicts.append(entry["verdict"])
            pr["metrics"][m] = entry
        res["policies"][pol] = pr
    if "FAIL" in verdicts:
        res["verdict"] = "FAIL"
    elif "ÖLÇÜLEMEDİ" in verdicts:
        res["verdict"] = "ÖLÇÜLEMEDİ"
    elif verdicts:
        res["verdict"] = "PASS"
    else:
        res["verdict"] = "VERİ YOK"
    return res


def _pct(x) -> str:
    return "–" if x is None or (isinstance(x, float) and np.isnan(x)) else f"{x * 100:+.1f}%"


def render(res: dict, base_name: str, new_name: str) -> str:
    o = [f"# Baseline karşılaştırması: {base_name} → {new_name}", "", f"> {DISCLAIMER}", ""]
    o.append(f"Karar: **{res['verdict']}** (bant ±%{res['band'] * 100:.1f}, gürültü sınırı ±%{res['noise_limit'] * 100:.1f}, "
             f"bootstrap {res['boot']}, %95 GA)")
    o.append("")
    o.append("| politika | metrik | taban | yeni | yeni %95 GA | bant | bantta | eşleşmiş fark (GA) | eşleşmemiş fark (GA) | gürültü | karar |")
    o.append("|---|---|---|---|---|---|---|---|---|---|---|")
    for pol, pr in res["policies"].items():
        for m, e in pr["metrics"].items():
            if "error" in e:
                o.append(f"| {pol} | {m} | – | – | – | – | – | – | – | – | {e['error']} |")
                continue
            pa_ = e.get("paired")
            pairs = f"{_pct(pa_['diff'])} ({_pct(pa_['lo'])}…{_pct(pa_['hi'])})" if pa_ else "–"
            up = e["unpaired"]
            noise = e.get("noise")
            nz = (f"{_pct(noise['rel'])} (GA {_pct(noise['ci']['lo'])}…{_pct(noise['ci']['hi'])}){' ⚠' if noise['over_limit'] else ''} "
                  f"(n={noise['n']})") if noise else "–"
            tag = e.get("verdict", "bilgi" if not pr["gate"] else "bilgi (metrik)")
            o.append(
                f"| {pol}{'' if pr['gate'] else ' (bilgi)'} | {m} | {e['base']:.3f} | {e['new']:.3f} | "
                f"{e['new_ci'][0]:.3f}…{e['new_ci'][1]:.3f} | {e['band'][0]:.3f}…{e['band'][1]:.3f} | "
                f"{'evet' if e['in_band'] else 'hayır'} | {pairs} | {_pct(up['diff'])} ({_pct(up['lo'])}…{_pct(up['hi'])}) | {nz} | {tag} |")
    if any("decomposition" in e for pr in res["policies"].values() for e in pr["metrics"].values()):
        o += ["", "## Sapma kaynağı", "",
              "(v201 → nodyn) = dinamit kaybı; (nodyn → yeni) = havuz süzgeci ve diğer değişiklikler. Göreli fark, %95 GA.", "",
              "| politika | metrik | v201 | nodyn | yeni | dinamit kaybı | süzgeç/diğer |", "|---|---|---|---|---|---|---|"]
        for pol, pr in res["policies"].items():
            for m, e in pr["metrics"].items():
                d = e.get("decomposition")
                if not d:
                    continue
                dl, fo = d["dinamit_loss"], d["filter_other"]
                o.append(f"| {pol} | {m} | {e['base']:.3f} | {d['nodyn']:.3f} | {e['new']:.3f} | "
                         f"{_pct(dl['diff'])} ({_pct(dl['lo'])}…{_pct(dl['hi'])}) | {_pct(fo['diff'])} ({_pct(fo['lo'])}…{_pct(fo['hi'])}) |")
    o += ["", f"_{DISCLAIMER}_", ""]
    return "\n".join(o)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("base")
    ap.add_argument("new")
    ap.add_argument("--char", default="gunslinger")
    ap.add_argument("--noise", help="gürültü tabanı kolu (v201-B)")
    ap.add_argument("--nodyn", help="dinamitsiz kol (v201-nodyn-A)")
    ap.add_argument("--gate-policies", default="strong,kite")
    ap.add_argument("--info-policies", default="greedy,idle")
    ap.add_argument("--boot", type=int, default=4000)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--band", type=float, default=0.05)
    ap.add_argument("--noise-limit", type=float, default=0.025)
    ap.add_argument("--out")
    ap.add_argument("--json")
    a = ap.parse_args(argv)
    try:
        base, new = load(a.base, a.char), load(a.new, a.char)
        noise = load(a.noise, a.char) if a.noise else None
        nodyn = load(a.nodyn, a.char) if a.nodyn else None
    except (OSError, ValueError) as e:
        print(f"girdi hatası: {e}", file=sys.stderr)
        return 2
    if not base or not new:
        print("girdi boş (karakter süzgeci?)", file=sys.stderr)
        return 2
    res = compare(base, new, noise, nodyn, tuple(p for p in a.gate_policies.split(",") if p), tuple(p for p in a.info_policies.split(",") if p),
                  a.boot, a.seed, a.band, a.noise_limit)
    md = render(res, os.path.basename(a.base.rstrip("/")), os.path.basename(a.new.rstrip("/")))
    print(md)
    if a.out:
        Path(a.out).write_text(md, encoding="utf-8")
    if a.json:
        Path(a.json).write_text(json.dumps(res, indent=1, ensure_ascii=False, default=float) + "\n", encoding="utf-8")
    return {"PASS": 0, "FAIL": 1, "ÖLÇÜLEMEDİ": 3}.get(res["verdict"], 2)


if __name__ == "__main__":
    sys.exit(main())

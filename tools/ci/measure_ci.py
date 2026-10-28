#!/usr/bin/env python3
"""CI süre ölçümü (T20261028-33 Ölçüm protokolü). Yalnız standart kütüphane + `gh` CLI.

Metrikler (koşu başına): duvar = max(completedAt) - min(startedAt) (kuyruk hariç, atlanan işler hariç); kritik yol =
needs grafında en uzun iş zinciri (matrix üyelerinin en uzunu; kuyruktan bağımsız); runner_min = iş sürelerinin toplamı (bilgi).
Soğuk/sıcak etiketi koşu günlüğündeki önbellek satırından KAYIT edilir ("ilk koşu soğuktur" varsayımı yok).

  measure_ci.py run <koşu-id> [--workflow .github/workflows/ci.yml]   tek koşunun metrikleri (JSON)
  measure_ci.py compare --before id,id,... --after id,id,... [--workflow ...]   etiketli medyan tablosu + %30 kabulü

Kabul: aynı etikette hem medyan duvar hem medyan kritik yol Tson <= 0.70 * Tönce; taraf başına >= 5 koşu.
Aykırı değer (medyandan > 2 MAD) RAPORLANIR, dışarıda bırakılmaz.
"""
import argparse
import json
import re
import statistics
import subprocess
import sys
from datetime import datetime
from pathlib import Path

ZERO = "0001-01-01T00:00:00Z"
THRESHOLD = 0.70
MIN_SAMPLES = 5


def _ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def _ran(j):
    return j.get("startedAt") not in (None, "", ZERO) and j.get("completedAt") not in (None, "", ZERO)


def _dur(j):
    return (_ts(j["completedAt"]) - _ts(j["startedAt"])).total_seconds()


def _job_id(name):
    return name.split(" (")[0]


def parse_needs(yml_text):
    """jobs altındaki `needs:` bildirimlerini {iş: [bağımlılıklar]} olarak çıkarır (liste ya da tek ad)."""
    needs, cur = {}, None
    in_jobs = False
    for line in yml_text.splitlines():
        if line.startswith("jobs:"):
            in_jobs = True
            continue
        if not in_jobs:
            continue
        mj = re.match(r"^  ([\w-]+):\s*$", line)
        if mj:
            cur = mj.group(1)
            continue
        mn = re.match(r"^    needs:\s*(.+?)\s*$", line)
        if mn and cur:
            val = mn.group(1)
            needs[cur] = [x.strip() for x in val.strip("[]").split(",") if x.strip()]
    return needs


def metrics(jobs, needs):
    ran = [j for j in jobs if _ran(j)]
    if not ran:
        return {"wall": 0, "critical_path": 0, "runner_min": 0, "jobs_run": 0, "jobs_skipped": len(jobs)}
    wall = (max(_ts(j["completedAt"]) for j in ran) - min(_ts(j["startedAt"]) for j in ran)).total_seconds()
    longest = {}
    for j in ran:
        k = _job_id(j["name"])
        longest[k] = max(longest.get(k, 0), _dur(j))
    memo = {}

    def cp(k):
        if k not in memo:
            memo[k] = longest.get(k, 0) + max((cp(d) for d in needs.get(k, []) if d in longest), default=0)
        return memo[k]

    return {
        "wall": round(wall),
        "critical_path": round(max(cp(k) for k in longest)),
        "runner_min": round(sum(_dur(j) for j in ran) / 60, 2),
        "jobs_run": len(ran),
        "jobs_skipped": len(jobs) - len(ran),
    }


def cache_label(log_text):
    if "Cache not found for input keys" in log_text:
        return "soguk"
    if "Cache restored from key" in log_text or "Cache hit occurred" in log_text:
        return "sicak"
    return "bilinmiyor"


def skipped_by_filter(log_text):
    return len(re.findall(r"^.*SKIPPED_BY_FILTER", log_text, re.M))


def median(xs):
    return statistics.median(xs)


def outliers(xs):
    med = median(xs)
    mad = median([abs(x - med) for x in xs]) or 1e-9
    return [x for x in xs if abs(x - med) > 2 * mad]


def compare(before, after):
    """Etiket başına (sıcak-sıcak, soğuk-soğuk) medyan oranları; karşılığı olmayan etiket atlanır."""
    out = {}
    for label in sorted({r["label"] for r in before} & {r["label"] for r in after}):
        b = [r for r in before if r["label"] == label]
        a = [r for r in after if r["label"] == label]
        wr = median([r["wall"] for r in a]) / median([r["wall"] for r in b])
        cr = median([r["critical_path"] for r in a]) / median([r["critical_path"] for r in b])
        out[label] = {
            "n_before": len(b), "n_after": len(a), "enough_samples": min(len(a), len(b)) >= MIN_SAMPLES,
            "wall_before": median([r["wall"] for r in b]), "wall_after": median([r["wall"] for r in a]), "wall_ratio": wr,
            "cp_before": median([r["critical_path"] for r in b]), "cp_after": median([r["critical_path"] for r in a]), "cp_ratio": cr,
            "wall_outliers": outliers([r["wall"] for r in b]) + outliers([r["wall"] for r in a]),
            "accepted": wr <= THRESHOLD + 1e-9 and cr <= THRESHOLD + 1e-9,
        }
    return out


def _gh(*args):
    r = subprocess.run(["gh", *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        sys.exit(f"gh {' '.join(args)} başarısız: {r.stderr.strip()[:300]}")
    return r.stdout


def measure_run(run_id, workflow):
    jobs = json.loads(_gh("run", "view", str(run_id), "--json", "jobs"))["jobs"]
    needs = parse_needs(Path(workflow).read_text(encoding="utf-8"))
    log = _gh("run", "view", str(run_id), "--log")
    res = metrics(jobs, needs)
    res.update(run=run_id, label=cache_label(log), skipped_by_filter=skipped_by_filter(log))
    return res


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run")
    r.add_argument("run_id")
    r.add_argument("--workflow", default=".github/workflows/ci.yml")
    c = sub.add_parser("compare")
    c.add_argument("--before", required=True)
    c.add_argument("--after", required=True)
    c.add_argument("--workflow", default=".github/workflows/ci.yml")
    c.add_argument("--workflow-before", default=None, help="Tönce tarafının needs grafı (eski ci.yml); varsayılan --workflow")
    args = ap.parse_args(argv)
    if args.cmd == "run":
        print(json.dumps(measure_run(args.run_id, args.workflow), ensure_ascii=False, indent=2))
        return 0
    b = [measure_run(i, args.workflow_before or args.workflow) for i in args.before.split(",")]
    a = [measure_run(i, args.workflow) for i in args.after.split(",")]
    res = compare(b, a)
    print(json.dumps({"before": b, "after": a, "compare": res}, ensure_ascii=False, indent=2))
    return 0 if res and all(v["accepted"] and v["enough_samples"] for v in res.values()) else 1


if __name__ == "__main__":
    sys.exit(main())

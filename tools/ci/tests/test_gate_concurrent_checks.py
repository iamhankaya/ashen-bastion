"""Gate: lint ve pytest, GUT ile eşzamanlı koşar (PART=all, tam gate); hiçbir denetim atlanmaz (T20261029-30, koşul 1-4)."""

import re
import subprocess
import sys
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
GATE = (ROOT / "tools" / "gate.sh").read_text(encoding="utf-8")

pytestmark = pytest.mark.skipif(sys.platform == "win32" and not Path("C:/Program Files/Git/usr/bin/bash.exe").exists(), reason="bash yok")


def helpers():
    m = re.search(r"^# --- eşzamanlı denetimler \(başla\)\n(.*?)^# --- eşzamanlı denetimler \(bitti\)$", GATE, re.M | re.S)
    assert m, "gate.sh'ta eşzamanlı denetim yardımcıları (işaretli blok) yok"
    return m.group(1)


def harness(tmp_path, body):
    """Yardımcı blok + gate.sh'ın end_step/fail davranışının asgari taklidi; gövde bg işlerini tanımlar."""
    script = tmp_path / "h.sh"
    script.write_text(
        "set -uo pipefail\ncd \"$1\"\nmkdir -p .gate\nSECONDS=0\nSTEP_NAME=''\nend_step() { :; }\n"
        "fail() { reap_bg >/dev/null 2>&1; echo \"GATE FAIL: $*\" >&2; exit 1; }\n" + helpers() + body,
        encoding="utf-8",
        newline="\n",
    )
    return subprocess.run(["bash", str(script), str(tmp_path)], capture_output=True, text=True, encoding="utf-8")


def test_all_checks_run_to_completion_even_when_one_is_red(tmp_path):
    r = harness(
        tmp_path,
        "red() { echo RED-OUTPUT; sleep 0.3; return 1; }\nslow_ok() { sleep 0.8; echo SLOW-OK-OUTPUT; return 0; }\n"
        'bg_start "3. Lint" red\nbg_start "5. Python testleri" slow_ok\nreap_bg; echo "rc=$?"\n',
    )
    out = r.stdout + r.stderr
    assert "rc=1" in out
    assert "RED-OUTPUT" in out and "SLOW-OK-OUTPUT" in out  # kısa devre yok: kırmızı olan ötekini öldürmedi
    assert "=== 3. Lint (eşzamanlı)" in out and "=== 5. Python testleri (eşzamanlı)" in out
    assert re.search(r"süre: \d+ sn", out)


def test_green_checks_return_zero_and_run_concurrently(tmp_path):
    t0 = time.time()
    r = harness(tmp_path, 'a() { sleep 1.2; }\nb() { sleep 1.2; }\nbg_start A a\nbg_start B b\nreap_bg; echo "rc=$?"\n')
    assert "rc=0" in r.stdout + r.stderr
    assert time.time() - t0 < 2.3  # sıralı olsaydı ≥2.4 sn


def test_fail_reaps_background_checks_before_exiting(tmp_path):
    r = harness(tmp_path, 'a() { sleep 0.4; echo A-LATE; return 1; }\nbg_start A a\nfail "GUT kırmızı"\n')
    out = r.stdout + r.stderr
    assert r.returncode == 1 and "GATE FAIL: GUT kırmızı" in out


def test_concurrent_mode_is_limited_to_full_parallel_gate_and_serial_escape_exists():
    assert "GATE_SERIAL" in GATE
    m = re.search(r"^CONC=0\n(.*?)^fi$", GATE, re.M | re.S)
    assert m, "CONC koşulu yok"
    cond = m.group(1)
    for needle in ('"$PART" = "all"', "$FAST -eq 0", '"$JOBS" -gt 1', 'GATE_SERIAL'):
        assert needle in cond


def test_every_check_still_exists_exactly_once_in_gate():
    for needle in ("gdformat --check", "gdlint \"${LINT_ARGS", "to_upper|to_lower", "python3 -m pytest", "bash tools/ci/check_forbidden_names.sh", "res://tools/validate_data.gd"):
        assert GATE.count(needle) == 1, needle
    # eşzamanlı sonuç toplanmadan sahte yeşil korumaları (adım 7) çalışmamalı
    assert GATE.index("reap_bg ||") < GATE.index('step "7. Sahte yeşil korumaları"')

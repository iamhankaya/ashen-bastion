"""v2.1 U6: ekran görüntüsü yakalama CI'ı (denetim #altyapı). Ayrı workflow: gate süresini şişirmez, PNG'ler artifact olur."""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def _src(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def test_shots_workflow_is_separate_from_the_gate():
    assert "shots" not in _src(".github/workflows/ci.yml").lower().replace("shards", "")
    wf = _src(".github/workflows/shots.yml")
    head = wf.split("jobs:")[0]
    assert "workflow_dispatch:" in head and "push:" in head
    assert "tools/capture/shots_v21*.gd" in head and "scripts/ui/**" in head, "yalnız ilgili yollar tetikler"


def test_shots_runs_before_and_after_and_uploads_pngs():
    wf = _src(".github/workflows/shots.yml")
    assert re.search(r"side:\s*\[\s*before\s*,\s*after\s*\]", wf)
    assert "before_ref" in wf, "önceki durum dispatch girdisiyle seçilir"
    assert "bash tools/ci/capture_shots.sh" in wf
    up = wf[wf.index("upload-artifact") :]
    assert "shots-v21-${{ matrix.side }}" in up and "if-no-files-found: error" in up


def test_capture_script_runs_both_v21_scripts_under_xvfb_and_is_valid_bash():
    sh = _src("tools/ci/capture_shots.sh")
    for want in ("shots_v21.gd", "shots_v21_b.gd", "xvfb-run", "ensure_godot.sh"):
        assert want in sh
    assert subprocess.run(["bash", "-n", str(ROOT / "tools/ci/capture_shots.sh")]).returncode == 0


def test_capture_scripts_cover_every_audit_scenario():
    a, b = _src("tools/capture/shots_v21.gd"), _src("tools/capture/shots_v21_b.gd")
    for sc in ("menu_2x", "run_2x", "pause", "pause_2x"):
        assert f'"{sc}"' in a
    for sc in ("scores_2x", "result_2x", "result_combos5_easy", "result_combos5_chip", "band", "band_2x", "band_no_hint"):
        assert f'"{sc}"' in b

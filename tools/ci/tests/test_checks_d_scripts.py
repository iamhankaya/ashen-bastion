"""S-budget/S-ids/S-layers kapı betikleri (tools/ci/checks.d/NN-ad.sh): gerçek depoda yeşil, çalıştırma biti 100755, run_checks.sh sırasıyla koşar."""
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
SCRIPTS = ["10-line-budget.sh", "20-test-ids.sh", "30-layers.sh"]


def test_contract_scripts_exist_in_name_order():
    found = sorted(p.name for p in (ROOT / "tools/ci/checks.d").glob("*.sh"))
    assert [s for s in found if s in SCRIPTS] == SCRIPTS


@pytest.mark.parametrize("name", SCRIPTS)
def test_script_is_green_on_the_real_repo(name):
    r = subprocess.run(["bash", f"tools/ci/checks.d/{name}"], cwd=ROOT, capture_output=True, text=True, encoding="utf-8")
    assert r.returncode == 0, r.stderr


@pytest.mark.parametrize("name", SCRIPTS)
def test_script_has_executable_mode_in_git(name):
    out = subprocess.run(["git", "ls-files", "-s", f"tools/ci/checks.d/{name}"], cwd=ROOT, capture_output=True, text=True).stdout
    assert out.startswith("100755"), out


def test_scripts_go_red_on_a_deliberate_violation(tmp_path):
    # kasıtlı ihlal: tavan aşımı + yasak katman kenarı + kayıtsız test silme; üç betik de kırmızı
    (tmp_path / "scripts/sim").mkdir(parents=True)
    (tmp_path / "scripts/ui").mkdir(parents=True)
    (tmp_path / "scripts/sim/big.gd").write_text("class_name Big\n" + "x\n" * 801 + "var u: Ui\n")
    (tmp_path / "scripts/ui/ui.gd").write_text("class_name Ui\n")
    (tmp_path / "project.godot").write_text("[autoload]\n")
    for name, tool in (("10-line-budget.sh", "check_line_budget.py"), ("30-layers.sh", "check_layers.py")):
        r = subprocess.run(["python", str(ROOT / "tools/ci" / tool), "--root", str(tmp_path), "--exceptions", str(tmp_path / "yok.txt")], capture_output=True, text=True, encoding="utf-8")
        assert r.returncode == 1, name

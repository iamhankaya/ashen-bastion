"""F-153: oturum boyunca ağaç değiştiyse (pytest izlenen dosyaya yazdı / GUT dizinine dosya bıraktı) oturum kırmızıdır;
gate pytest'i GUT ile eşzamanlı koşturur, bu yarışı kapı sessizce geçmemeli. Kalıcı çözüm: testler yalnız tmp_path'e yazar."""
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "ci"))
import tree_guard  # noqa: E402

_before = {}


def pytest_sessionstart(session):
    _before["d"] = tree_guard.digest(ROOT)


def pytest_sessionfinish(session, exitstatus):
    if _before.get("d") is None or tree_guard.digest(ROOT) == _before["d"]:
        return
    print("\nTREE_GUARD: pytest ağacı değiştirdi (izlenen dosya ya da test/scripts/data/addons altında yeni dosya); "
          "testler yalnız tmp_path'e yazmalı (F-153)", file=sys.stderr)
    session.exitstatus = pytest.ExitCode.TESTS_FAILED

#!/usr/bin/env bash
# Statik denetim kancası (altyapı-A0 gate.sh'a checks.d/NN-*.sh çalıştırmayı ekleyince devreye girer; ondan önce kuralı
# tools/ci/tests/test_check_ui_rules.py::test_real_repo_is_green korur). BASE_REF'i A0 export eder: ScrollContainer fabrika kuralı.
set -uo pipefail
cd "$(dirname "$0")/../../.."
python3 tools/ci/check_ui_rules.py ${BASE_REF:+--base "$BASE_REF"}

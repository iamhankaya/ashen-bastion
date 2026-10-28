#!/usr/bin/env bash
# Statik denetim kancası (gate.sh tools/ci/checks.d/NN-*.sh dosyalarını çalıştırır): ScrollContainer fabrika kuralı.
set -uo pipefail
cd "$(dirname "$0")/../../.."
python3 tools/ci/check_ui_rules.py ${BASE_REF:+--base "$BASE_REF"}

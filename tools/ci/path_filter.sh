#!/usr/bin/env bash
# CI yol süzgeci (H1/H10): "bu iş bu değişiklikte koşmalı mı?" kararını run=1|0 olarak GITHUB_OUTPUT'a ve stdout'a yazar.
# Kullanım: path_filter.sh <ERE>   ; ERE, repo köküne göre değişen dosya yoluyla BAŞTAN eşleşir (^(ERE)).
# Ortam: GITHUB_REF, GITHUB_EVENT_NAME, GITHUB_OUTPUT, GITHUB_STEP_SUMMARY, PATH_FILTER_BASE (varsayılan origin/main),
#        PATH_FILTER_FORCE=1 (her zaman koş).
# İLKE: şüphede TAM KOŞU. main, push dışı olaylar (dispatch/schedule/workflow_call), PATH_FILTER_FORCE, shallow klon, taban ref'i
# yok, ortak ata yok ya da diff hatası => run=1. Yalnız diff güvenle alınır ve hiçbir yol eşleşmezse run=0 (SKIPPED_BY_FILTER).
# Karşılaştırma dal ucu ile main'in ortak atası arasındadır (son push değil, dalın TÜM değişikliği).
set -uo pipefail
PATTERN="${1:-}"
[ -n "$PATTERN" ] || { echo "kullanım: path_filter.sh <ERE>" >&2; exit 2; }
BASE="${PATH_FILTER_BASE:-origin/main}"

emit() { # emit <0|1> <neden>
  echo "run=$1"
  [ -n "${GITHUB_OUTPUT:-}" ] && echo "run=$1" >> "$GITHUB_OUTPUT"
  echo "PATH_FILTER: run=$1 — $2" >&2
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "- PATH_FILTER: run=$1 — $2" >> "$GITHUB_STEP_SUMMARY"
  exit 0
}

[ "${PATH_FILTER_FORCE:-0}" = "1" ] && emit 1 "TAM KOŞU (PATH_FILTER_FORCE=1)"
[ "${GITHUB_REF:-}" = "refs/heads/main" ] && emit 1 "TAM KOŞU (main her zaman tam)"
[ "${GITHUB_EVENT_NAME:-push}" != "push" ] && emit 1 "TAM KOŞU (olay: ${GITHUB_EVENT_NAME})"
[ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = "false" ] || emit 1 "TAM KOŞU (shallow klon ya da git yok: diff güvenilmez)"
git rev-parse -q --verify "$BASE" > /dev/null || emit 1 "TAM KOŞU (taban ref'i yok: $BASE)"
MB="$(git merge-base "$BASE" HEAD 2>/dev/null)" && [ -n "$MB" ] || emit 1 "TAM KOŞU (ortak ata bulunamadı)"
CHANGED="$(git diff --name-only "$MB" HEAD 2>/dev/null)" || emit 1 "TAM KOŞU (git diff hatası)"
if printf '%s\n' "$CHANGED" | grep -qE "^($PATTERN)"; then
  emit 1 "eşleşen yol var: $(printf '%s\n' "$CHANGED" | grep -E "^($PATTERN)" | head -n 3 | tr '\n' ' ')"
fi
emit 0 "SKIPPED_BY_FILTER (eşleşen yol yok; $(printf '%s\n' "$CHANGED" | grep -c .) dosya değişti)"

#!/usr/bin/env bash
set -euo pipefail

# andon.sh — stop the line on the first defect, no exceptions.

ok() { printf 'ANDON::PASS: %s\n' "$1"; }
fail() { printf 'ANDON::FAIL: %s\n' "$1" >&2; exit 1; }

# Batch-size limit: reject diffs too large for meaningful human review.
CHANGED=$(git diff --cached --numstat | awk '{s+=$1+$2} END {print s+0}')
[[ "${CHANGED}" -le 400 ]] || fail "diff is ${CHANGED} lines; split it (limit 400)"

# Each of these must pass; none are advisory!

# ruff lint
ruff check . || fail "lint"

# mypy
mypy --strict src/ || fail "types"

# pytest pytest-cov
pytest -q --cov=src --cov-fail-under=80 || fail "tests/coverage"

# pip-audit
#pip-audit -r requirements.txt || fail "known CVEs in dependencies"

ok "line clear"

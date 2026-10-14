#!/usr/bin/env bash
set -euo pipefail

# Lint shell script(s): shellcheck (warning+) plus shfmt diff check.
#
# Usage: check <file> [file ...]
#
# Exit 0 when everything is clean, 1 otherwise.

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

usage() {
  echo "Usage: ${SCRIPT_NAME} <file> [file ...]" >&2
}

if [[ $# -eq 0 ]]; then
  usage
  exit 2
fi

has_cmd() { command -v "$1" >/dev/null 2>&1; }

missing_tools=()
if ! has_cmd shellcheck; then
  missing_tools+=("shellcheck (apt install -y shellcheck / dnf install -y ShellCheck / brew install shellcheck)")
fi

if ! has_cmd shfmt; then
  missing_tools+=("shfmt (apt install -y shfmt / dnf install -y shfmt / brew install shfmt / go install mvdan.cc/sh/v3/cmd/shfmt@latest)")
fi

if [[ ${#missing_tools[@]} -gt 0 ]]; then
  echo "ERROR: missing required tools:" >&2
  printf '  - %s\n' "${missing_tools[@]}" >&2
  exit 2
fi

failures=0
for target in "$@"; do
  echo "==> shellcheck ${target}"
  if ! shellcheck -x -S warning "${target}"; then
    failures=$((failures + 1))
  fi

  echo "==> shfmt -d ${target}"
  if ! shfmt -i 2 -ci -bn -s -d "${target}"; then
    echo "  (run 'shfmt -i 2 -ci -bn -s -w ${target}' to fix)" >&2
    failures=$((failures + 1))
  fi
done

if ((failures > 0)); then
  echo "FAIL: ${failures} check(s) failed" >&2
  exit 1
fi

echo "PASS: all checks passed"

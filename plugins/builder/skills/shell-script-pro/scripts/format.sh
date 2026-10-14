#!/usr/bin/env bash
set -euo pipefail

# Format shell script(s) to the Shell Script Pro preset:
#   shfmt -i 2 -ci -bn -s -w  (Google-like: 2-space indent, indented case
# branches, binary operators start the line, simplify), honoring .editorconfig.
#
# Usage: format.sh <file> [file ...]

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

usage() {
  echo "Usage: ${SCRIPT_NAME} <file> [file ...]" >&2
}

if [[ $# -eq 0 ]]; then
  usage
  exit 2
fi

if ! command -v shfmt >/dev/null 2>&1; then
  echo "ERROR: 'shfmt' command not found. Install it using your package manager (apt install shfmt / dnf install shfmt / brew install shfmt)" >&2
  exit 2
fi

shfmt -i 2 -ci -bn -s -w "$@"

echo "Formatted file(s): $#"

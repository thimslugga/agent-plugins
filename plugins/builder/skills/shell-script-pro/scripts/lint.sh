#!/usr/bin/env bash
set -euo pipefail

# Lint shell script(s): shellcheck (all severities, optional checks on)
# plus a shfmt diff check.
#
# Usage: lint.sh <file> [file ...]
#
# Exit 0 when everything is clean, 1 on findings, 2 on usage/tooling errors.

SCRIPT_NAME="${BASH_SOURCE[0]##*/}"
readonly SCRIPT_NAME

#######################################
# Print usage to stderr.
# Globals:
#   SCRIPT_NAME
# Outputs:
#   Writes usage to stderr.
#######################################
usage() {
  echo "Usage: ${SCRIPT_NAME} <file> [file ...]" >&2
}

#######################################
# Exit 2 unless shellcheck and shfmt are on PATH.
# Outputs:
#   Writes the missing tools and install hints to stderr.
#######################################
require_tools() {
  local -a missing_tools=()

  if ! command -v shellcheck >/dev/null 2>&1; then
    missing_tools+=("shellcheck (apt install -y shellcheck / \
dnf install -y ShellCheck / brew install shellcheck)")
  fi

  if ! command -v shfmt >/dev/null 2>&1; then
    missing_tools+=("shfmt (apt install -y shfmt / dnf install -y shfmt / \
brew install shfmt / go install mvdan.cc/sh/v3/cmd/shfmt@latest)")
  fi

  if ((${#missing_tools[@]} > 0)); then
    echo "ERROR: missing required tools:" >&2
    printf '  - %s\n' "${missing_tools[@]}" >&2
    exit 2
  fi
}

#######################################
# Lint each file with shellcheck and shfmt.
# Arguments:
#   $@ - files to lint.
# Returns:
#   0 when every check passes, 1 otherwise.
#######################################
lint_files() {
  local target
  local failures=0

  for target in "$@"; do
    echo "==> shellcheck ${target}"
    if ! shellcheck -x -S style -o all "${target}"; then
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
    return 1
  fi

  echo "PASS: all checks passed"
}

main() {
  if (($# == 0)); then
    usage
    exit 2
  fi

  require_tools
  lint_files "$@"
}

main "$@"

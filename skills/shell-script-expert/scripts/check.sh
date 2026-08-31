#!/bin/bash
#
# Verification gate for shell scripts: syntax, lint, format.
# A script is not finished until this exits 0.
#
# Usage: check.sh [OPTIONS] <file-or-directory>...

set -Eeuo pipefail

readonly SCRIPT_NAME="${BASH_SOURCE[0]##*/}"

# shfmt flags matching the Google shell style guide: 2 space indent, indented
# case alternatives, and binary operators at the start of a continued line.
readonly SHFMT_FLAGS=(-i 2 -ci -bn)

write='false'
failed=0
err_log=''

#######################################
# Print usage information.
# Outputs:
#   Writes help text to stdout.
#######################################
usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS] <file-or-directory>...

Runs, for every shell script found:
  1. bash -n     syntax check            (always available)
  2. shellcheck  correctness lint        (skipped with a hint if absent)
  3. shfmt -d    Google style formatting (skipped with a hint if absent)

Directories are searched for *.sh, *.bash, and extensionless executables
whose first line is a sh or bash shebang.

Options:
  -w, --write    Apply shfmt formatting in place instead of only reporting
  -h, --help     Show this help and exit

Exit codes:
  0  everything passed
  1  at least one check failed
  2  usage error
EOF
}

log() { printf '%s\n' "$*" >&2; }

die_usage() {
  log "ERROR: $*"
  usage >&2
  exit 2
}

have() { command -v -- "$1" > /dev/null 2>&1; }

#######################################
# Remove the temporary log file.
# Globals:
#   err_log
# Returns:
#   The exit status the script already had.
#######################################
cleanup() {
  local rc=$?
  if [[ -n "${err_log}" && -f "${err_log}" ]]; then
    rm -f -- "${err_log}"
  fi
  return "${rc}"
}

#######################################
# Emit the shell scripts under a file or directory.
# Arguments:
#   A path to a file or directory.
# Outputs:
#   Writes NUL-delimited paths to stdout.
#######################################
collect() {
  local path="$1"

  if [[ -f "${path}" ]]; then
    printf '%s\0' "${path}"
    return 0
  fi

  find "${path}" -type f \( -name '*.sh' -o -name '*.bash' \) -print0

  local candidate
  while IFS= read -r -d '' candidate; do
    if head -n 1 -- "${candidate}" \
      | grep -qE '^#!.*[[:space:]/](ba)?sh([[:space:]]|$)'; then
      printf '%s\0' "${candidate}"
    fi
  done < <(find "${path}" -type f ! -name '*.*' -perm -u+x -print0)
}

#######################################
# Run every available check against one file.
# Globals:
#   err_log, failed, write
# Arguments:
#   Path to a shell script.
# Outputs:
#   Writes findings to stdout.
#######################################
check_file() {
  local file="$1"
  local file_failed=0

  printf '==> %s\n' "${file}"

  if bash -n -- "${file}" 2> "${err_log}"; then
    printf '    syntax     ok\n'
  else
    printf '    syntax     FAIL\n'
    sed 's/^/      /' "${err_log}"
    file_failed=1
  fi

  if have shellcheck; then
    if shellcheck --severity=style --external-sources -- "${file}"; then
      printf '    shellcheck ok\n'
    else
      printf '    shellcheck FAIL\n'
      file_failed=1
    fi
  fi

  if have shfmt; then
    if [[ "${write}" == 'true' ]]; then
      shfmt "${SHFMT_FLAGS[@]}" -w -- "${file}"
      printf '    shfmt      formatted\n'
    elif shfmt "${SHFMT_FLAGS[@]}" -d -- "${file}"; then
      printf '    shfmt      ok\n'
    else
      printf '    shfmt      FAIL (run with --write to fix)\n'
      file_failed=1
    fi
  fi

  if (( file_failed != 0 )); then
    failed=$((failed + 1))
  fi
}

#######################################
# Explain how to install the tools that were not found.
# Outputs:
#   Writes install commands to stdout.
#######################################
report_missing_tools() {
  if ! have shellcheck; then
    cat <<'EOF'

shellcheck is not installed, so the most valuable check was skipped.
  Amazon Linux / Fedora : sudo dnf install -y ShellCheck
  Debian / Ubuntu       : sudo apt-get install -y shellcheck
  macOS                 : brew install shellcheck
  Static binary         : github.com/koalaman/shellcheck/releases
EOF
  fi

  if ! have shfmt; then
    cat <<'EOF'

shfmt is not installed, so formatting was not checked.
  Go toolchain : go install mvdan.cc/sh/v3/cmd/shfmt@latest
  macOS        : brew install shfmt
EOF
  fi
}

#######################################
# Parse options, gather scripts, and report results.
# Globals:
#   err_log, failed, write
# Arguments:
#   The script's command line arguments.
# Returns:
#   0 when every check passed, 1 otherwise.
#######################################
main() {
  trap cleanup EXIT

  local -a paths=()
  while (( $# > 0 )); do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      -w | --write)
        write='true'
        shift
        ;;
      --)
        shift
        paths+=("$@")
        break
        ;;
      -*)
        die_usage "unknown option: $1"
        ;;
      *)
        paths+=("$1")
        shift
        ;;
    esac
  done

  if (( ${#paths[@]} == 0 )); then
    die_usage 'expected at least one file or directory'
  fi

  local path file
  local -a files=()
  for path in "${paths[@]}"; do
    if [[ ! -e "${path}" ]]; then
      die_usage "no such path: ${path}"
    fi
    while IFS= read -r -d '' file; do
      files+=("${file}")
    done < <(collect "${path}")
  done

  if (( ${#files[@]} == 0 )); then
    log 'no shell scripts found'
    exit 1
  fi

  err_log="$(mktemp)"

  for file in "${files[@]}"; do
    check_file "${file}"
  done

  report_missing_tools

  printf '\n%d file(s) checked, %d with findings\n' "${#files[@]}" "${failed}"
  (( failed == 0 ))
}

main "$@"

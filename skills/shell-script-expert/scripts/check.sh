#!/usr/bin/env bash
set -Eeuo pipefail

# check.sh - Verification gate for shell scripts: syntax, lint, format.
# A script is not finished until this exits 0.
#
# Usage: check.sh [OPTIONS] <file-or-directory>...

readonly SCRIPT_NAME="${BASH_SOURCE[0]##*/}"

# shfmt flags matching the Google shell style guide: 2 space indent, indented
# case alternatives, and binary operators at the start of a continued line.
readonly SHFMT_FLAGS=(-i 2 -ci -bn)

write='false'
failed=0
err_log=''
file_list=''
candidate_list=''
missing_tools=0

#######################################
# Print usage information.
# Outputs:
#   Writes help text to stdout.
#######################################
usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS] <file-or-directory>...

Runs, for every shell script found:
  1. shell -n    syntax check            (always available)
  2. shellcheck  correctness lint        (required)
  3. shfmt -d    Google style formatting (required)

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

#######################################
# Remove temporary files.
# Globals:
#   candidate_list, err_log, file_list
# Returns:
#   The exit status the script already had.
#######################################
cleanup() {
  local rc=$?
  local temporary_file
  for temporary_file in "${err_log}" "${file_list}" "${candidate_list}"; do
    if [[ -n "${temporary_file}" && -f "${temporary_file}" ]]; then
      rm -f -- "${temporary_file:?temporary file is unset}"
    fi
  done
  return "${rc}"
}

#######################################
# Emit the shell scripts under a file or directory.
# Arguments:
#   A path to a file or directory.
#   File to append NUL-delimited results to.
#   Temporary file for extensionless candidates.
#######################################
collect() {
  local path="$1"
  local output_file="$2"
  local candidates_file="$3"

  if [[ -f "${path}" ]]; then
    printf '%s\0' "${path}" >>"${output_file}"
    return 0
  fi

  if ! find "${path}" -type f \( -name '*.sh' -o -name '*.bash' \) \
    -print0 >>"${output_file}"; then
    log "ERROR: failed to scan directory: ${path}"
    return 1
  fi

  : >"${candidates_file}"
  if ! find "${path}" -type f ! -name '*.*' -perm -u+x \
    -print0 >"${candidates_file}"; then
    log "ERROR: failed to scan executable files: ${path}"
    return 1
  fi

  local candidate
  while IFS= read -r -d '' candidate; do
    if head -n 1 -- "${candidate}" \
      | grep -qE '^#!.*[[:space:]/](ba)?sh([[:space:]]|$)'; then
      printf '%s\0' "${candidate}" >>"${output_file}"
    fi
  done <"${candidates_file}"
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
  local syntax_shell='bash'
  local first_line=''

  IFS= read -r first_line <"${file}" || true
  if [[ "${first_line}" =~ ^#!.*[[:space:]/]sh([[:space:]]|$) ]]; then
    syntax_shell='sh'
  fi

  printf '==> %s\n' "${file}"

  if "${syntax_shell}" -n -- "${file}" 2>"${err_log}"; then
    printf '    syntax     ok\n'
  else
    printf '    syntax     FAIL\n'
    sed 's/^/      /' "${err_log}"
    file_failed=1
  fi

  if shellcheck --severity=style --external-sources -- "${file}"; then
    printf '    shellcheck ok\n'
  else
    printf '    shellcheck FAIL\n'
    file_failed=1
  fi

  if [[ "${write}" == 'true' ]]; then
    shfmt "${SHFMT_FLAGS[@]}" -w -- "${file}"
    printf '    shfmt      formatted\n'
  elif shfmt "${SHFMT_FLAGS[@]}" -d -- "${file}"; then
    printf '    shfmt      ok\n'
  else
    printf '    shfmt      FAIL (run with --write to fix)\n'
    file_failed=1
  fi

  if ((file_failed != 0)); then
    failed=$((failed + 1))
  fi
}

#######################################
# Explain how to install the tools that were not found.
# Globals:
#   missing_tools
# Outputs:
#   Writes install commands to stdout.
#######################################
report_missing_tools() {
  if ! command -v -- shellcheck >/dev/null 2>&1; then
    missing_tools=$((missing_tools + 1))
    cat <<'EOF'

shellcheck is not installed, so the most valuable check was skipped.
  Amazon Linux / Fedora : sudo dnf install -y ShellCheck
  Debian / Ubuntu       : sudo apt-get install -y shellcheck
  macOS                 : brew install shellcheck
  Static binary         : github.com/koalaman/shellcheck/releases
EOF
  fi

  if ! command -v -- shfmt >/dev/null 2>&1; then
    missing_tools=$((missing_tools + 1))
    cat <<'EOF'

shfmt is not installed, so formatting was not checked.
  Go toolchain : go install mvdan.cc/sh/v3/cmd/shfmt@latest
  macOS        : brew install shfmt
EOF
  fi

  return 0
}

#######################################
# Parse options, gather scripts, and report results.
# Globals:
#   candidate_list, err_log, failed, file_list, missing_tools, write
# Arguments:
#   The script's command line arguments.
# Returns:
#   0 when every check passed, 1 otherwise.
#######################################
main() {
  trap cleanup EXIT

  local -a paths=()
  while (($# > 0)); do
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

  if ((${#paths[@]} == 0)); then
    die_usage 'expected at least one file or directory'
  fi

  err_log="$(mktemp)"
  file_list="$(mktemp)"
  candidate_list="$(mktemp)"

  local path file
  local -a files=()
  for path in "${paths[@]}"; do
    if [[ "${path}" != /* && "${path}" == -* ]]; then
      path="./${path}"
    fi
    if [[ ! -e "${path}" ]]; then
      die_usage "no such path: ${path}"
    fi
    collect "${path}" "${file_list}" "${candidate_list}"
  done

  while IFS= read -r -d '' file; do
    files+=("${file}")
  done <"${file_list}"

  if ((${#files[@]} == 0)); then
    log 'no shell scripts found'
    exit 1
  fi

  report_missing_tools
  if ((missing_tools != 0)); then
    log 'verification failed because required tools are unavailable'
    exit 1
  fi

  for file in "${files[@]}"; do
    check_file "${file}"
  done

  printf '\n%d file(s) checked, %d with findings\n' "${#files[@]}" "${failed}"
  ((failed == 0))
}

main "$@"

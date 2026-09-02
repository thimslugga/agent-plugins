#!/bin/bash
# Set here rather than in the shebang so that "bash template.sh" behaves the
# same way. -E makes the ERR trap fire inside functions, which it does not do
# by default.
set -Eeuo pipefail

# One line describing what this script does.
#
# Usage: template.sh [OPTIONS] <target>...

readonly SCRIPT_NAME="${BASH_SOURCE[0]##*/}"

# Constants are uppercase and readonly. Mutable globals are lowercase.
verbose='false'
dry_run='false'
tmp_dir=''

#######################################
# Print usage information.
# Outputs:
#   Writes help text to stdout.
#######################################
usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS] <target>...

Describe the job in one or two lines.

Options:
  -h, --help       Show this help and exit
  -v, --verbose    Print debug output to stderr
  -n, --dry-run    Print destructive commands instead of running them

Exit codes:
  0  success
  1  runtime failure
  2  usage error

Examples:
  ${SCRIPT_NAME} --dry-run /srv/app
  ${SCRIPT_NAME} -v /srv/app /srv/api
EOF
}

#######################################
# Write a timestamped message to stderr.
# Arguments:
#   Severity label, then the message words.
# Outputs:
#   Writes to stderr. "$*" is deliberate here: joining the words into one
#   message is the documented exception to preferring "$@".
#######################################
log() {
  local level="$1"
  shift
  local timestamp
  timestamp="$(date +'%Y-%m-%dT%H:%M:%S%z')"
  printf '%s [%-5s] %s\n' "${timestamp}" "${level}" "$*" >&2
}

info() { log 'INFO' "$@"; }
warn() { log 'WARN' "$@"; }
error() { log 'ERROR' "$@"; }

debug() {
  if [[ "${verbose}" == 'true' ]]; then
    log 'DEBUG' "$@"
  fi
}

#######################################
# Report a runtime failure and exit 1.
# Outputs:
#   Writes to stderr. Clearing the ERR trap keeps a deliberate exit from
#   also being reported as a crash.
#######################################
die() {
  trap - ERR
  log 'ERROR' "$@"
  exit 1
}

#######################################
# Report a usage error, print help, and exit 2.
# Outputs:
#   Writes to stderr.
#######################################
die_usage() {
  trap - ERR
  log 'ERROR' "$@"
  usage >&2
  exit 2
}

#######################################
# Abort unless every named command is on PATH.
# Arguments:
#   One or more command names.
#######################################
require_cmds() {
  local cmd
  for cmd in "$@"; do
    if ! command -v -- "${cmd}" >/dev/null 2>&1; then
      die "required command not found: ${cmd}"
    fi
  done
}

#######################################
# Remove the working directory. Runs on every exit path.
# Globals:
#   tmp_dir
# Returns:
#   The exit status the script already had.
#######################################
cleanup() {
  local rc=$?
  if [[ -n "${tmp_dir}" && -d "${tmp_dir}" ]]; then
    rm -rf -- "${tmp_dir:?temporary directory is unset}"
  fi
  return "${rc}"
}

#######################################
# Exit with the conventional status for a received signal.
# Arguments:
#   Signal name.
#######################################
on_signal() {
  local signal_name="$1"
  trap - ERR
  warn "received SIG${signal_name}"
  case "${signal_name}" in
    INT) exit 130 ;;
    TERM) exit 143 ;;
    *) exit 1 ;;
  esac
}

#######################################
# Report the first failing command, then exit with its status.
# Outputs:
#   Writes a warning to stderr. Without "trap - ERR" the same failure is
#   announced again at every level of the call stack as it unwinds.
#######################################
on_err() {
  local rc=$?
  trap - ERR
  warn "command failed at ${SCRIPT_NAME}:${BASH_LINENO[0]} (exit ${rc})"
  exit "${rc}"
}

#######################################
# Run a side-effecting command, honouring --dry-run.
# Globals:
#   dry_run
# Arguments:
#   A command and its arguments. No pipes, no redirection.
#######################################
run() {
  if [[ "${dry_run}" == 'true' ]]; then
    info "DRY-RUN: $*"
    return 0
  fi
  debug "exec: $*"
  "$@"
}

#######################################
# Do the real work for one target.
# Arguments:
#   Target path.
#######################################
process() {
  local target="$1"

  if [[ ! -e "${target}" ]]; then
    die "no such path: ${target}"
  fi
  info "processing ${target}"

  # Destructive calls go through run():
  #   run rm -rf -- "${target:?target is unset}"
}

#######################################
# Parse options, then process every target.
# Globals:
#   dry_run, tmp_dir, verbose
# Arguments:
#   The script's command line arguments.
#######################################
main() {
  trap cleanup EXIT
  trap 'on_signal INT' INT
  trap 'on_signal TERM' TERM
  trap on_err ERR

  local -a targets=()
  while (($# > 0)); do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      -v | --verbose)
        verbose='true'
        shift
        ;;
      -n | --dry-run)
        dry_run='true'
        shift
        ;;
      --)
        shift
        targets+=("$@")
        break
        ;;
      -*)
        die_usage "unknown option: $1"
        ;;
      *)
        targets+=("$1")
        shift
        ;;
    esac
  done

  if ((${#targets[@]} == 0)); then
    die_usage 'expected at least one target'
  fi

  require_cmds date mktemp rm

  tmp_dir="$(mktemp -d)"
  debug "workspace: ${tmp_dir}"

  local target
  for target in "${targets[@]}"; do
    process "${target}"
  done

  info 'done'
}

main "$@"

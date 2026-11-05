#!/usr/bin/env bash
set -euo pipefail

# Scaffold a new shell script from the Shell Script Pro template.
#
# Usage: init-script.sh <path> [description]
#
# The templates below live in quoted heredocs (<<'EOF') so they pass through
# byte-for-byte; @DESCRIPTION@, @NAME@, and @GUARD@ are substituted afterwards
# with bash string replacement (no sed, no escaping pitfalls).

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} <path> [description]

Scaffold a new bash script following the Shell Script Pro standard:
shebang, strict mode, header comment, readonly constants,
logging/usage helpers, error handling with traps, and a main entry point.

Examples:
  ${SCRIPT_NAME} deploy "Deploy the webapp to staging"
  ${SCRIPT_NAME} lib/string.sh "String helpers library"
EOF
}

# Emit the template for $1 (executable|library) with placeholders resolved.
render_template() {
  local kind="$1"
  local description="$2"
  local name="$3"
  local guard="__${name//[^a-zA-Z0-9_]/_}_LOADED"
  local content

  if [[ ${kind} == 'library' ]]; then
    content="$(
      cat <<'TEMPLATE_EOF'
#!/usr/bin/env bash

# @DESCRIPTION@
#
# Library: source this file, do not execute it.
#   source "${BASH_SOURCE[0]%/*}/@NAME@"
#
# Libraries must NOT set shell options or traps: that state belongs to the
# script doing the sourcing. Keep this file to pure functions.

# Guard against double-sourcing.
if [[ -n ${@GUARD@:-} ]]; then
  return 0
fi
readonly @GUARD@=1

#######################################
# Short description of what it does.
# Globals:
#   NAME_OF_GLOBAL_USED
# Arguments:
#   $1 - description of first argument.
# Outputs:
#   What gets written to stdout/stderr.
# Returns:
#   0 on success, non-zero on failure.
#######################################
my_module::my_func() {
  local input="$1"

  echo "${input}"
  return 0
}
TEMPLATE_EOF
    )"
  else
    content="$(
      cat <<'TEMPLATE_EOF'
#!/usr/bin/env bash
set -euo pipefail
set -o errtrace # ERR trap fires inside functions/subshells too

# inherit_errexit needs bash 4.4+; silently skip it elsewhere.
shopt -s inherit_errexit 2>/dev/null || true # bash < 4.4 lacks this option

# @DESCRIPTION@
#
# Usage: @NAME@ [options] [args]

#######################################
# Constants
#######################################
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

# Logging knobs (environment overrides welcome):
#   VERBOSE=true  debug output      QUIET=true  silence INFO
#   COLOR=false   disable colors    (colors also auto-disable when stderr
#                                    is not a terminal)
VERBOSE="${VERBOSE:-false}"
QUIET="${QUIET:-false}"
COLOR="${COLOR:-true}"

readonly __RED=$'\033[0;31m'
readonly __YELLOW=$'\033[0;33m'
readonly __CYAN=$'\033[0;36m'
readonly __GRAY=$'\033[2;37m'
readonly __RESET=$'\033[0m'

# Re-entrancy guard for the ERR trap handler below.
__ON_ERROR_ACTIVE='false'

#######################################
# Functions
#######################################

#######################################
# Write a timestamped log line to stderr. Stdout stays reserved for the
# script's real output (data other tools consume).
# Globals:
#   COLOR
# Arguments:
#   $1 - level: INFO, WARN, ERROR, DEBUG, FATAL.
#   $2 - ANSI color code.
#   $@ - message parts.
# Outputs:
#   Writes to stderr.
#######################################
__log() {
  local level="$1"
  local color="$2"
  shift 2
  local ts
  ts="$(date +'%Y-%m-%dT%H:%M:%S%z')"
  if [[ ${COLOR} == 'true' && -t 2 ]]; then
    printf '%s[%s] %-5s %s%s%s\n' "${__GRAY}" "${ts}" "${level}" "${color}" "$*" "${__RESET}" >&2
  else
    printf '[%s] %-5s %s\n' "${ts}" "${level}" "$*" >&2
  fi

  return 0
}

log_info() {
  [[ ${QUIET} == 'true' ]] && return 0
  __log 'INFO' "${__CYAN}" "$@"
}

log_warn() {
  __log 'WARN' "${__YELLOW}" "$@"
}

log_error() {
  __log 'ERROR' "${__RED}" "$@"
}

log_debug() {
  [[ ${VERBOSE} == 'true' ]] || return 0
  __log 'DEBUG' "${__GRAY}" "$@"
}

#######################################
# Print a call-stack backtrace to stderr (outermost call last).
# Outputs:
#   Writes to stderr.
#######################################
__backtrace() {
  local frame=1
  local info
  local line
  local func
  local src

  # The caller builtin prints "line func file" per frame; frame 0 is
  # this function's own caller, so start at 1.
  while info="$(caller "${frame}" 2>/dev/null)"; do
    read -r line func src <<<"${info}"
    printf '  at %s (%s:%s)\n' "${func:-<top>}" "${src}" "${line}" >&2
    ((++frame)) # prefix ++ never evaluates to 0: safe under set -e
  done

  return 0
}

#######################################
# Log a fatal error, kill leftover background jobs, and exit. The ERR
# trap routes every unchecked failure here with its line number.
# Arguments:
#   --status=N  exit status (default 1); remaining args form the message.
#######################################
log_fatal() {
  local status=1
  if [[ ${1:-} == --status=* ]]; then
    status="${1#--status=}"
    shift
  fi

  __log 'FATAL' "${__RED}" "$@"
  if [[ ${VERBOSE} == 'true' ]]; then
    __backtrace
  fi

  local -a child_pids=()
  read -ra child_pids < <(jobs -p 2>/dev/null || true)
  if ((${#child_pids[@]} > 0)); then
    kill -9 -- "${child_pids[@]}" 2>/dev/null || true
  fi

  exit "${status}"
}

#######################################
# ERR trap handler: report the failed command, its line, and its status.
# Never fires for *checked* failures: if/while conditions, &&/|| lists,
# or commands whose status you handle yourself. A bare `return` reaching
# the trap is main's deliberate exit status (already logged), not a crash.
# Arguments:
#   $1 - exit status of the failed command.
#   $2 - line number where it failed.
#   $3 - the failed command text.
#######################################
__on_error() {
  local status="$1"
  local lineno="$2"
  local command="$3"

  # Inside a subshell (command substitution, ( ) group, pipeline segment,
  # process substitution): stay quiet and let the parent shell's trap emit
  # the single report. This exit ends only the subshell; the failing parent
  # command still trips the trap in the parent frame.
  if ((BASH_SUBSHELL > 0)); then
    exit "${status}"
  fi

  # If logging itself fails, exit rather than recurse into the trap.
  [[ ${__ON_ERROR_ACTIVE} == 'true' ]] && exit 1
  __ON_ERROR_ACTIVE='true'

  # Deliberate `return N` from main: exit quietly with its status. This is
  # why main is invoked bare at the bottom of the script: wrapping the call
  # in ||, &&, or if would suppress set -e and this trap inside main.
  if [[ ${command} == return || ${command} == return\ * ]]; then
    exit "${status}"
  fi

  log_fatal --status="${status}" \
    "command failed (exit ${status}) at line ${lineno}: ${command}"
}

#######################################
# Remove temporary artifacts on exit.
# Globals:
#   TMP_DIR
#######################################
cleanup() {
  if [[ -n ${TMP_DIR:-} && -d ${TMP_DIR} ]]; then
    rm -rf "${TMP_DIR}"
  fi

  return 0
}

#######################################
# Abort unless every named variable is set and non-empty.
# Arguments:
#   $@ - variable names to require.
#######################################
require_vars() {
  local name
  local value

  for name in "$@"; do
    value="${!name:-}" # indirection: the variable NAMED by $name
    if [[ -z ${value} ]]; then
      log_fatal "required variable '${name}' is not set"
    fi
  done

  return 0
}

#######################################
# Print usage information.
# Globals:
#   SCRIPT_NAME
# Outputs:
#   Writes usage to stdout.
#######################################
usage() {
  cat <<USAGE
Usage: ${SCRIPT_NAME} [options] [args]

@DESCRIPTION@

Options:
  -h    Show this help and exit.
  -v    Enable debug output (same as VERBOSE=true).

Arguments:
  args  TODO: document positional arguments.
USAGE
}

#######################################
# Validate preconditions before doing work.
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0 if all preconditions hold, non-zero otherwise.
#######################################
check_preconditions() {
  local missing=()
  local cmd

  for cmd in "$@"; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      missing+=("${cmd}")
    fi
  done

  if ((${#missing[@]} > 0)); then
    log_error "missing required commands: ${missing[*]}"
    return 1
  fi

  return 0
}

main() {
  local arg

  trap cleanup EXIT
  trap '__on_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR

  while getopts ':hv' arg; do
    case "${arg}" in
      h)
        usage
        return 0
        ;;
      v)
        VERBOSE='true'
        ;;
      *)
        log_error "Unexpected option '-${OPTARG}'"
        usage >&2
        return 2
        ;;
    esac
  done
  shift $((OPTIND - 1))

  check_preconditions awk || return 1

  log_info "starting ${SCRIPT_NAME}"
  log_debug "arguments: $*"

  # TODO: implement.
  log_error "not implemented yet"
  return 1
}

# Bare invocation: main's deliberate `return N` is a normal, already-logged
# exit status (exited quietly by __on_error), while any unchecked failure
# inside main still trips set -e and the ERR trap. Do NOT wrap this call in
# ||, &&, or if: that would suppress both for the whole of main.
main "$@"
TEMPLATE_EOF
    )"
  fi

  content="${content//@DESCRIPTION@/${description}}"
  content="${content//@NAME@/${name}}"
  content="${content//@GUARD@/${guard}}"
  printf '%s\n' "${content}"
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 2
  fi

  local target="$1"
  local description="${2:-TODO: describe what this script does}"
  local name
  name="$(basename "${target}")"

  if [[ -e ${target} ]]; then
    echo "error: '${target}' already exists" >&2
    exit 1
  fi

  mkdir -p "$(dirname "${target}")"

  # Libraries (.sh under a lib/ dir, meant to be sourced) get a library variant.
  local kind='executable'
  if [[ ${target} == *.sh ]] && [[ ${target} == lib/* || ${target} == */lib/* ]]; then
    kind='library'
  fi

  render_template "${kind}" "${description}" "${name}" >"${target}"

  if [[ ${kind} == 'library' ]]; then
    # Libraries are sourced, never executed.
    chmod -x "${target}"
  else
    chmod +x "${target}"
  fi
  echo "created ${target}"
}

main "$@"

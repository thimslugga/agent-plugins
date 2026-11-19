#!/usr/bin/env bash
set -euo pipefail

# Scaffold a new shell script from the Shell Script Pro template.
#
# Usage: init-script.sh <path> [description]
#
# The templates below live in quoted heredocs (<<'EOF') so they pass through
# byte-for-byte; @DESCRIPTION@, @NAME@, and @GUARD@ are substituted afterwards
# with bash string replacement (no sed, no escaping pitfalls).

SCRIPT_NAME="${BASH_SOURCE[0]##*/}"
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
SCRIPT_NAME="${BASH_SOURCE[0]##*/}"
readonly SCRIPT_NAME

# Logging knobs (environment seeds the lowercase script state; -v / -n
# set it too). Colors are decided once in setup_colors: stderr must be a
# terminal and NO_COLOR (https://no-color.org) must be unset.
#   VERBOSE=true  debug output      QUIET=true  silence info
verbose="${VERBOSE:-false}"
quiet="${QUIET:-false}"
# DRY_RUN=true (or -n): run_cmd prints instead of executing.
dry_run="${DRY_RUN:-false}"

# ANSI codes; stay empty (no escape codes at all) unless setup_colors runs
# on a color-capable terminal.
color_red=''
color_yellow=''
color_cyan=''
color_gray=''
color_reset=''

# printf's %(...)T time builtin needs bash 4.2+ (macOS ships 3.2).
HAS_PRINTF_TIME='false'
if ((BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] >= 402)); then
  HAS_PRINTF_TIME='true'
fi
readonly HAS_PRINTF_TIME

# Working directory created by the script (cleanup removes it).
tmp_dir=''

# Re-entrancy guard for the ERR trap handler below.
__on_error_active='false'

#######################################
# Functions
#######################################

#######################################
# Enable ANSI colors when stderr is a terminal and NO_COLOR is unset.
# Globals:
#   color_red, color_yellow, color_cyan, color_gray, color_reset
#######################################
setup_colors() {
  if [[ -t 2 && -z ${NO_COLOR:-} ]]; then
    color_red=$'\033[0;31m'
    color_yellow=$'\033[0;33m'
    color_cyan=$'\033[0;36m'
    color_gray=$'\033[2;37m'
    color_reset=$'\033[0m'
  fi

  return 0
}

#######################################
# Write a timestamped log line to stderr. Stdout stays reserved for the
# script's real output (data other tools consume). The level tag is the
# only colored part; with colors off the escape variables are empty.
# Globals:
#   HAS_PRINTF_TIME, color_reset
# Arguments:
#   $1 - level tag: INFO, WARN, ERROR, DEBUG.
#   $2 - ANSI color for the tag (may be empty).
#   $@ - message parts.
# Outputs:
#   Writes to stderr.
#######################################
log() {
  local level="$1"
  local tag_color="$2"
  shift 2
  local ts

  if [[ ${HAS_PRINTF_TIME} == 'true' ]]; then
    printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1
  else
    ts="$(date +'%Y-%m-%dT%H:%M:%S%z')"
  fi

  printf '[%s] %s%-5s%s %s\n' \
    "${ts}" "${tag_color}" "${level}" "${color_reset}" "$*" >&2
}

info() {
  [[ ${quiet} == 'true' ]] && return 0
  log 'INFO' "${color_cyan}" "$@"
}

warn() {
  log 'WARN' "${color_yellow}" "$@"
}

err() {
  log 'ERROR' "${color_red}" "$@"
}

debug() {
  [[ ${verbose} == 'true' ]] || return 0
  log 'DEBUG' "${color_gray}" "$@"
}

#######################################
# Run a side-effecting command, honouring -n / DRY_RUN.
# Globals:
#   dry_run
# Arguments:
#   $@ - a command and its arguments. No pipes, no redirection.
# Returns:
#   0 in dry-run mode, otherwise the command's exit status.
#######################################
run_cmd() {
  if [[ ${dry_run} == 'true' ]]; then
    info "DRY-RUN: $*"
    return 0
  fi

  debug "exec: $*"
  "$@"
}

#######################################
# Kill leftover background jobs of this shell.
# Returns:
#   0 always.
#######################################
kill_children() {
  local -a child_pids=()
  read -ra child_pids < <(jobs -p 2>/dev/null || true)
  if ((${#child_pids[@]} > 0)); then
    kill -9 -- "${child_pids[@]}" 2>/dev/null || true
  fi

  return 0
}

#######################################
# Log an error and exit. The EXIT trap (cleanup) removes temp files and
# kills leftover background jobs, and the ERR trap routes every unchecked
# failure here with its line number.
# Arguments:
#   --status=N  exit status (default 1); remaining args form the message.
#######################################
die() {
  local status=1
  if [[ ${1:-} == --status=* ]]; then
    status="${1#--status=}"
    shift
  fi

  err "$@"
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
  [[ ${__on_error_active} == 'true' ]] && exit 1
  __on_error_active='true'

  # Deliberate `return N` from main: exit quietly with its status. This is
  # why main is invoked bare at the bottom of the script: wrapping the call
  # in ||, &&, or if would suppress set -e and this trap inside main.
  if [[ ${command} == return || ${command} == return\ * ]]; then
    exit "${status}"
  fi

  die --status="${status}" \
    "command failed (exit ${status}) at line ${lineno}: ${command}"
}

#######################################
# Kill leftover background jobs and remove temporary artifacts on exit.
# Globals:
#   tmp_dir
#######################################
cleanup() {
  kill_children

  if [[ -n ${tmp_dir:-} && -d ${tmp_dir} ]]; then
    rm -rf "${tmp_dir}"
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
      die "required variable '${name}' is not set"
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
  -n    Dry run: print side-effecting commands instead of running them.
  -v    Enable debug output (same as VERBOSE=true).

Arguments:
  args  TODO(username): document positional arguments.
USAGE
}

#######################################
# Validate preconditions before doing work.
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   0 if all preconditions hold; otherwise exits via die.
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
    die "missing required commands: ${missing[*]}"
  fi

  return 0
}

#######################################
# Parse command-line options. Leaves OPTIND set so the caller can shift.
# Globals:
#   dry_run, verbose
# Arguments:
#   $@ - the script's command-line arguments.
# Returns:
#   0 on success; exits 0 for -h and 2 for a bad option.
#######################################
parse_args() {
  local arg

  while getopts ':hnv' arg; do
    case "${arg}" in
      h)
        usage
        exit 0
        ;;
      n)
        dry_run='true'
        ;;
      v)
        verbose='true'
        ;;
      *)
        err "Unexpected option '-${OPTARG}'"
        usage >&2
        exit 2
        ;;
    esac
  done

  return 0
}

main() {
  trap cleanup EXIT
  trap '__on_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR

  setup_colors
  parse_args "$@"
  shift $((OPTIND - 1))

  check_preconditions awk

  info "starting ${SCRIPT_NAME}"
  debug "arguments: $*"

  # TODO(username): implement.
  err "not implemented yet"
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
  local description="${2:-TODO(username): describe what this script does}"
  local name
  name="${target##*/}"

  if [[ -e ${target} ]]; then
    echo "error: '${target}' already exists" >&2
    exit 1
  fi

  if [[ ${target} == */* ]]; then
    mkdir -p "${target%/*}"
  fi

  # Libraries (.sh under a lib/ dir, meant to be sourced) get a library
  # variant.
  local kind='executable'
  if [[ ${target} == *.sh ]] \
    && [[ ${target} == lib/* || ${target} == */lib/* ]]; then
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

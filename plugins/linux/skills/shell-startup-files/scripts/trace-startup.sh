#!/usr/bin/env bash
#
# List the startup files a Bash or Zsh shell reads, in order, for one mode.
#
# Starts a fresh shell in the requested mode, traces it, and prints one file
# path per line on stdout. Works with Bash 3.2+ (macOS) and any Zsh.

set -euo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly STARTUP_PATTERN='profile|bashrc|bash_login|bash_logout|zshenv|zprofile|zshrc|zlogin|zlogout'

log() {
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$1" "$2" >&2
}

log_info() { log INFO "$*"; }
log_warn() { log WARN "$*"; }
log_error() { log ERROR "$*"; }

die() {
  log_error "$*"
  exit 1
}

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [-s bash|zsh] [-m MODE] [-H HOME_DIR] [-S] [-h]

List the startup files a shell reads, in the order it reads them.

Options:
  -s SHELL     Shell to trace: bash (default) or zsh. A path is accepted.
  -m MODE      login-interactive (default), login, interactive, or script.
  -H HOME_DIR  Run the traced shell with HOME set to this directory.
  -S           Use strace (Linux). Also shows files reached through 'source'.
  -h           Show this help.

Examples:
  ${SCRIPT_NAME}                      # what 'ssh host' or a macOS tab reads
  ${SCRIPT_NAME} -m interactive       # what a Linux terminal tab reads
  ${SCRIPT_NAME} -s zsh -m script     # what a zsh script reads
EOF
}

#######################################
# Map a mode name to the shell's option letters.
# Arguments:
#   Mode name.
# Outputs:
#   Option letters without the leading dash (may be empty) on stdout.
# Returns:
#   0 on success, 1 for an unknown mode.
#######################################
mode_to_flags() {
  case "$1" in
    login-interactive) printf 'li' ;;
    login) printf 'l' ;;
    interactive) printf 'i' ;;
    script) printf '' ;;
    *) return 1 ;;
  esac
}

#######################################
# Trace Bash with xtrace and a PS4 that carries the source file name.
# Bash ignores PS4 from the environment when it runs as root.
# Arguments:
#   Shell binary, option letters.
# Outputs:
#   One startup file per line on stdout.
#######################################
trace_bash_xtrace() {
  local shell_bin="$1"
  local flags="$2"

  # shellcheck disable=SC2016 # PS4 must be expanded by the traced shell, not here.
  PS4='+ ${BASH_SOURCE:-cmdline}:${LINENO}: ' "${shell_bin}" "-${flags}xc" : 2>&1 </dev/null \
    | sed -nE 's/^\++ ([^:]+):[0-9]+: .*/\1/p' \
    | awk '$0 != "cmdline" && $0 != prev { print; prev = $0 }'
}

#######################################
# Trace Zsh with the SOURCE_TRACE option, which announces each file.
# Arguments:
#   Shell binary, option letters.
# Outputs:
#   Zsh's own source trace lines on stdout.
#######################################
trace_zsh_sourcetrace() {
  local shell_bin="$1"
  local flags="$2"

  "${shell_bin}" -o sourcetrace "-${flags}c" exit 2>&1 </dev/null
}

#######################################
# Trace any shell with strace and keep the startup files it opened.
# Arguments:
#   Shell binary, option letters.
# Outputs:
#   One opened startup file per line on stdout, in order.
#######################################
trace_with_strace() {
  local shell_bin="$1"
  local flags="$2"
  local trace_file

  command -v strace >/dev/null 2>&1 || die "strace not found; install it or drop -S"
  trace_file="$(mktemp "${TMPDIR:-/tmp}/trace-startup.XXXXXX")"
  # shellcheck disable=SC2064 # Expand now: trace_file is local to this function.
  trap "rm -f '${trace_file}'" EXIT

  strace -f -e trace=openat,open -o "${trace_file}" \
    "${shell_bin}" "-${flags}c" : >/dev/null 2>&1 </dev/null || true

  sed -nE "s/.*open(at)?\\(.*\"([^\"]*(${STARTUP_PATTERN})[^\"]*)\".*\\) = [0-9]+\$/\\2/p" \
    "${trace_file}" | awk '$0 != prev { print; prev = $0 }'
}

main() {
  local shell_name='bash'
  local mode='login-interactive'
  local home_dir=''
  local use_strace='false'
  local flags
  local shell_bin
  local opt

  while getopts ':s:m:H:Sh' opt; do
    case "${opt}" in
      s) shell_name="${OPTARG}" ;;
      m) mode="${OPTARG}" ;;
      H) home_dir="${OPTARG}" ;;
      S) use_strace='true' ;;
      h)
        usage
        exit 0
        ;;
      :) die "option -${OPTARG} needs a value (try -h)" ;;
      *) die "unknown option -${OPTARG} (try -h)" ;;
    esac
  done

  flags="$(mode_to_flags "${mode}")" || die "unknown mode '${mode}' (try -h)"
  shell_bin="$(command -v "${shell_name}")" || die "shell '${shell_name}' not found"

  if [[ -n ${home_dir} ]]; then
    [[ -d ${home_dir} ]] || die "HOME directory '${home_dir}' does not exist"
    export HOME="${home_dir}"
    unset ZDOTDIR
  fi

  log_info "tracing ${shell_bin} mode=${mode} HOME=${HOME}"

  if [[ ${use_strace} == 'true' ]]; then
    trace_with_strace "${shell_bin}" "${flags}"
    return
  fi

  case "${shell_bin##*/}" in
    bash)
      if ((EUID == 0)); then
        log_warn "bash ignores PS4 for root; falling back to strace"
        trace_with_strace "${shell_bin}" "${flags}"
      else
        trace_bash_xtrace "${shell_bin}" "${flags}"
      fi
      ;;
    zsh) trace_zsh_sourcetrace "${shell_bin}" "${flags}" ;;
    *) die "unsupported shell '${shell_bin##*/}': use bash or zsh, or pass -S" ;;
  esac
}

main "$@"

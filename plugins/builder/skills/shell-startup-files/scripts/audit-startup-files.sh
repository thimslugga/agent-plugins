#!/usr/bin/env bash
#
# Static audit of Bash and Zsh startup files for the usual load-order mistakes.
#
# Reads files only; changes nothing. Prints one finding per line on stdout as
# "LEVEL CODE message". Exits 1 when at least one WARN was found, else 0.
# Works with Bash 3.2+ (macOS).

set -euo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly GUARD_PATTERN='\$-|\$\{-|PS1|-o interactive'

warn_count=0

log() {
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$1" "$2" >&2
}

log_info() { log INFO "$*"; }
log_error() { log ERROR "$*"; }

die() {
  log_error "$*"
  exit 2
}

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [-H HOME_DIR] [-o linux|darwin] [-h]

Audit Bash and Zsh startup files and report load-order problems.

Options:
  -H HOME_DIR  Audit this home directory instead of \$HOME.
  -o OS        Apply rules for this OS (default: detected with uname).
  -h           Show this help.

Output: one "LEVEL CODE message" line per finding. Exit 1 if any WARN.
Codes are explained in references/troubleshooting.md.
EOF
}

report() {
  local level="$1"
  local code="$2"
  shift 2
  printf '%-4s %-4s %s\n' "${level}" "${code}" "$*"
  if [[ ${level} == 'WARN' ]]; then
    warn_count=$((warn_count + 1))
  fi
}

#######################################
# Print the line number of the first interactive guard in a file.
# Arguments:
#   File path.
# Outputs:
#   Line number on stdout, or nothing when there is no guard.
#######################################
find_guard_line() {
  grep -nE "${GUARD_PATTERN}" "$1" 2>/dev/null | head -n 1 | cut -d: -f1 || true
}

#######################################
# Report whether a file prints output before its interactive guard.
# Arguments:
#   File path, guard line number (empty means no guard).
# Returns:
#   0 when a top-level echo/printf comes before the guard.
#######################################
prints_before_guard() {
  local file="$1"
  local guard_line="${2:-0}"

  awk -v guard="${guard_line}" '
    guard > 0 && NR >= guard { exit }
    /^(echo|printf)[[:space:]]/ && $0 !~ />&2|>[[:space:]]*\/dev\// { found = 1; exit }
    END { exit(found ? 0 : 1) }
  ' "${file}"
}

list_existing() {
  local label="$1"
  shift
  local file
  for file in "$@"; do
    if [[ -e ${file} ]]; then
      report INFO "${label}" "exists: ${file}"
    fi
  done
}

audit_bash() {
  local home_dir="$1"
  local bash_profile="${home_dir}/.bash_profile"
  local bash_login="${home_dir}/.bash_login"
  local profile="${home_dir}/.profile"
  local bashrc="${home_dir}/.bashrc"
  local login_file=''
  local guard_line

  list_existing B00 /etc/profile /etc/bash.bashrc /etc/bashrc \
    "${bash_profile}" "${bash_login}" "${profile}" "${bashrc}" "${home_dir}/.bash_logout"

  if [[ -f ${bash_profile} ]]; then
    login_file="${bash_profile}"
  elif [[ -f ${bash_login} ]]; then
    login_file="${bash_login}"
  elif [[ -f ${profile} ]]; then
    login_file="${profile}"
  fi

  if [[ -n ${login_file} ]]; then
    report INFO B01 "bash login shells read only: ${login_file}"
  else
    report INFO B01 "no user login file for bash; only /etc/profile is read at login"
  fi

  if [[ ${login_file} == "${bash_profile}" && -f ${profile} ]] \
    && ! grep -qE '(^|[^_.[:alnum:]])\.profile' "${bash_profile}"; then
    report WARN B02 ".bash_profile exists and does not source ~/.profile, so bash never reads ~/.profile"
  fi

  if [[ -f ${bash_login} && ${login_file} != "${bash_login}" ]]; then
    report WARN B03 ".bash_login is never read because ~/.bash_profile exists"
  fi

  if [[ ${login_file} == "${bash_login}" && -f ${profile} ]]; then
    report WARN B03 ".profile is never read by bash because ~/.bash_login exists"
  fi

  if [[ -f ${bashrc} && -n ${login_file} ]] && ! grep -q 'bashrc' "${login_file}"; then
    report WARN B04 "${login_file} does not source ~/.bashrc, so login shells (ssh, macOS tabs, tmux) miss it"
  fi

  if [[ -f ${bashrc} ]]; then
    guard_line="$(find_guard_line "${bashrc}")"
    if [[ -z ${guard_line} ]]; then
      report WARN B05 ".bashrc has no interactive guard; 'ssh host cmd' may run all of it"
    fi
    if prints_before_guard "${bashrc}" "${guard_line}"; then
      report WARN B06 ".bashrc prints before its interactive guard; this breaks scp, sftp and rsync"
    fi
  fi
}

audit_zsh() {
  local home_dir="$1"
  local os_name="$2"
  local zdot="${ZDOTDIR:-${home_dir}}"
  local zshenv="${zdot}/.zshenv"

  list_existing Z00 /etc/zshenv /etc/zprofile /etc/zshrc /etc/zlogin \
    /etc/zsh/zshenv /etc/zsh/zprofile /etc/zsh/zshrc /etc/zsh/zlogin \
    "${zdot}/.zshenv" "${zdot}/.zprofile" \
    "${zdot}/.zshrc" "${zdot}/.zlogin" "${zdot}/.zlogout"

  if [[ ${zdot} != "${home_dir}" ]]; then
    report INFO Z01 "ZDOTDIR=${zdot}; zsh reads its user files from there"
    list_existing Z00 "${home_dir}/.zshenv"
  fi

  if [[ -f ${zshenv} ]]; then
    if [[ ${os_name} == 'darwin' ]] && grep -qE '(^|[^_[:alnum:]])(PATH|path)(\+?=|=\()' "${zshenv}"; then
      report WARN Z02 ".zshenv sets PATH on macOS; /etc/zprofile runs path_helper afterwards and reorders it. Use .zprofile"
    fi
    if grep -qE '^[[:space:]]*(alias|compinit|autoload|bindkey|PROMPT=|PS1=|echo|print)([[:space:]]|$)' "${zshenv}"; then
      report WARN Z03 ".zshenv holds interactive setup or output; every zsh, scripts included, runs it. Move it to .zshrc"
    fi
  fi

  if [[ -f "${zdot}/.zprofile" && -f "${zdot}/.zlogin" ]]; then
    report INFO Z04 "both .zprofile and .zlogin exist; they differ only in running before and after .zshrc"
  fi

  if [[ -f "${zdot}/.zshrc" && -f "${home_dir}/.profile" && ! -f "${zdot}/.zprofile" ]]; then
    report INFO Z05 "zsh does not read ~/.profile; login environment set there is not seen by zsh"
  fi
}

main() {
  local home_dir="${HOME}"
  local os_name
  local opt

  os_name="$(uname -s | tr '[:upper:]' '[:lower:]')"

  while getopts ':H:o:h' opt; do
    case "${opt}" in
      H) home_dir="${OPTARG}" ;;
      o) os_name="${OPTARG}" ;;
      h)
        usage
        exit 0
        ;;
      :) die "option -${OPTARG} needs a value (try -h)" ;;
      *) die "unknown option -${OPTARG} (try -h)" ;;
    esac
  done

  [[ -d ${home_dir} ]] || die "home directory '${home_dir}' does not exist"
  log_info "auditing home=${home_dir} os=${os_name}"

  audit_bash "${home_dir}"
  audit_zsh "${home_dir}" "${os_name}"

  log_info "done: ${warn_count} warning(s)"
  if ((warn_count > 0)); then
    exit 1
  fi
}

main "$@"

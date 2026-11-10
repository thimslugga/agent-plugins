#!/usr/bin/env bash
set -Eeuo pipefail

# Copy the global config fragments from assets/global/conf.d into mise's
# global conf.d directory, then optionally install the tools they declare.
#
# Usage: apply-global-config.sh [OPTIONS] [FRAGMENT]...
#
# Written for bash 3.2 (the macOS system bash): no associative arrays, no
# mapfile.

SCRIPT_NAME="${BASH_SOURCE[0]##*/}"
readonly SCRIPT_NAME
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
readonly SOURCE_DIR="${SCRIPT_DIR}/../assets/global/conf.d"

verbose='false'
dry_run='false'
force='false'
run_install='false'

usage() {
  cat <<USAGE
Usage: ${SCRIPT_NAME} [OPTIONS] [FRAGMENT]...

Copy tool fragments into \${MISE_CONFIG_DIR:-~/.config/mise}/conf.d. A
FRAGMENT is a file name from assets/global/conf.d, with or without ".toml"
or its numeric prefix (for example "lint" or "60-lint.toml"). An existing
destination file is left alone unless --force is given, in which case it is
first copied to <name>.bak.

Options:
  -l, --list       List the available fragments and exit
  -a, --all        Apply every fragment
  -i, --install    Run "mise install" afterwards
  -f, --force      Replace existing files (keeps a .bak copy)
  -n, --dry-run    Print what would be done and change nothing
  -v, --verbose    Print debug output to stderr
  -h, --help       Show this help and exit

Exit codes:
  0  success
  1  runtime failure
  2  usage error

Examples:
  ${SCRIPT_NAME} --list
  ${SCRIPT_NAME} --dry-run --all
  ${SCRIPT_NAME} --install runtimes shell git lint
USAGE
}

log() {
  local level="$1"
  shift
  local timestamp
  timestamp="$(date +'%Y-%m-%dT%H:%M:%S%z')"
  printf '%s [%-5s] %s\n' "${timestamp}" "${level}" "$*" >&2
}

info() { log 'INFO' "$@"; }
warn() { log 'WARN' "$@"; }

debug() {
  if [[ ${verbose} == 'true' ]]; then
    log 'DEBUG' "$@"
  fi
}

die() {
  trap - ERR
  log 'ERROR' "$@"
  exit 1
}

die_usage() {
  trap - ERR
  log 'ERROR' "$@"
  usage >&2
  exit 2
}

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
  if [[ ${dry_run} == 'true' ]]; then
    info "DRY-RUN: $*"
    return 0
  fi
  debug "exec: $*"
  "$@"
}

#######################################
# Print the mise executable to use.
# Outputs:
#   The path on stdout; nothing when mise is not installed.
#######################################
find_mise() {
  if command -v mise >/dev/null 2>&1; then
    command -v mise
  elif [[ -x "${HOME}/.local/bin/mise" ]]; then
    printf '%s\n' "${HOME}/.local/bin/mise"
  fi
}

#######################################
# Print the available fragment file names, one per line.
#######################################
list_fragments() {
  local path
  for path in "${SOURCE_DIR}"/*.toml; do
    [[ -e ${path} ]] || die "no fragments found in ${SOURCE_DIR}"
    printf '%s\n' "${path##*/}"
  done
}

#######################################
# Resolve a user-supplied fragment name to a file name.
# Arguments:
#   Name such as "lint", "60-lint" or "60-lint.toml".
# Outputs:
#   The matching file name on stdout.
# Returns:
#   1 when nothing matches.
#######################################
resolve_fragment() {
  local wanted="${1%.toml}"
  local name
  local stem
  while IFS= read -r name; do
    stem="${name%.toml}"
    if [[ ${stem} == "${wanted}" || ${stem#[0-9][0-9]-} == "${wanted}" ]]; then
      printf '%s\n' "${name}"
      return 0
    fi
  done < <(list_fragments)
  return 1
}

#######################################
# Copy one fragment into the destination directory.
# Globals:
#   force
# Arguments:
#   Fragment file name, destination directory.
#######################################
apply_fragment() {
  local name="$1"
  local dest_dir="$2"
  local src="${SOURCE_DIR}/${name}"
  local dest="${dest_dir}/${name}"

  if [[ -e ${dest} ]]; then
    if cmp -s -- "${src}" "${dest}"; then
      info "unchanged: ${dest}"
      return 0
    fi
    if [[ ${force} != 'true' ]]; then
      warn "exists, skipped (use --force to replace): ${dest}"
      return 0
    fi
    run cp -p -- "${dest}" "${dest}.bak"
  fi
  run cp -- "${src}" "${dest}"
  if [[ ${dry_run} != 'true' ]]; then
    info "applied: ${dest}"
  fi
}

main() {
  trap on_err ERR
  trap 'die "interrupted"' INT TERM

  local apply_all='false'
  local -a wanted=()
  while (($# > 0)); do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      -l | --list)
        list_fragments
        exit 0
        ;;
      -a | --all)
        apply_all='true'
        shift
        ;;
      -i | --install)
        run_install='true'
        shift
        ;;
      -f | --force)
        force='true'
        shift
        ;;
      -n | --dry-run)
        dry_run='true'
        shift
        ;;
      -v | --verbose)
        verbose='true'
        shift
        ;;
      -*) die_usage "unknown option: $1" ;;
      *)
        wanted+=("$1")
        shift
        ;;
    esac
  done

  local -a names=()
  local name
  local resolved
  if [[ ${apply_all} == 'true' ]]; then
    while IFS= read -r name; do
      names+=("${name}")
    done < <(list_fragments)
  else
    ((${#wanted[@]} > 0)) || die_usage 'name at least one fragment, or pass --all'
    for name in "${wanted[@]}"; do
      resolved="$(resolve_fragment "${name}")" \
        || die_usage "no such fragment: ${name} (see --list)"
      names+=("${resolved}")
    done
  fi

  local dest_dir="${MISE_CONFIG_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/mise}/conf.d"
  run mkdir -p -- "${dest_dir}"
  for name in "${names[@]}"; do
    apply_fragment "${name}" "${dest_dir}"
  done

  if [[ ${run_install} == 'true' ]]; then
    local mise_bin
    mise_bin="$(find_mise)"
    [[ -n ${mise_bin} ]] || die 'mise not found; run scripts/install-mise.sh first'
    run "${mise_bin}" install
  else
    info 'next: review the files, then run: mise install'
  fi
}

main "$@"

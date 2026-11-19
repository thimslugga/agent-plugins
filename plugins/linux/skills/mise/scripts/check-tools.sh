#!/usr/bin/env bash
set -Eeuo pipefail

# Check that tool short names exist in the mise registry before they are
# written to a config. Explicit backend identifiers (anything with a ":")
# are reported as "explicit" and not looked up.
#
# Usage: check-tools.sh [OPTIONS] [TOOL]...
#
# Written for bash 3.2 (the macOS system bash).

SCRIPT_NAME="${BASH_SOURCE[0]##*/}"
readonly SCRIPT_NAME

usage() {
  cat <<USAGE
Usage: ${SCRIPT_NAME} [OPTIONS] [TOOL]...

Look up each TOOL with "mise registry TOOL" and print one line per tool:

  ok        <name>  <backends>
  explicit  <name>  (has a backend prefix; not a registry name)
  missing   <name>

A "@version" suffix is ignored. With -f, names are also read from FILE, one
per line; blank lines and lines starting with "#" are skipped.

Options:
  -f, --file FILE   Read tool names from FILE ("-" for stdin)
  -h, --help        Show this help and exit

Exit codes:
  0  every registry name was found
  1  at least one name is missing, or mise is not installed
  2  usage error

Examples:
  ${SCRIPT_NAME} ripgrep gh awscli ryl
  ${SCRIPT_NAME} -f tools.txt
USAGE
}

log() {
  local level="$1"
  shift
  local timestamp
  timestamp="$(date +'%Y-%m-%dT%H:%M:%S%z')"
  printf '%s [%-5s] %s\n' "${timestamp}" "${level}" "$*" >&2
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
  log 'WARN' "command failed at ${SCRIPT_NAME}:${BASH_LINENO[0]} (exit ${rc})"
  exit "${rc}"
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
# Append the tool names in a file to the tools array.
# Globals:
#   tools
# Arguments:
#   File path, or "-" for stdin.
#######################################
read_names() {
  local file="$1"
  local line
  if [[ ${file} != '-' && ! -r ${file} ]]; then
    die "cannot read: ${file}"
  fi
  while IFS= read -r line || [[ -n ${line} ]]; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    if [[ -n ${line} ]]; then
      tools+=("${line}")
    fi
  done < <(if [[ ${file} == '-' ]]; then cat; else cat -- "${file}"; fi)
}

tools=()

main() {
  trap on_err ERR

  while (($# > 0)); do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      -f | --file)
        (($# >= 2)) || die_usage "$1 needs a value"
        read_names "$2"
        shift 2
        ;;
      -*) die_usage "unknown option: $1" ;;
      *)
        tools+=("$1")
        shift
        ;;
    esac
  done
  ((${#tools[@]} > 0)) || die_usage 'name at least one tool, or pass --file'

  local mise_bin
  mise_bin="$(find_mise)"
  [[ -n ${mise_bin} ]] || die 'mise not found; run scripts/install-mise.sh first'

  local missing=0
  local tool
  local name
  local backends
  for tool in "${tools[@]}"; do
    name="${tool%%@*}"
    if [[ ${name} == *:* ]]; then
      printf '%-9s %s\n' 'explicit' "${name}"
      continue
    fi
    if backends="$("${mise_bin}" registry "${name}" 2>/dev/null)" && [[ -n ${backends} ]]; then
      printf '%-9s %-30s %s\n' 'ok' "${name}" "${backends}"
    else
      printf '%-9s %s\n' 'missing' "${name}"
      missing=$((missing + 1))
    fi
  done

  if ((missing > 0)); then
    log 'ERROR' "${missing} name(s) not in the registry; try: mise search <name>"
    exit 1
  fi
}

main "$@"

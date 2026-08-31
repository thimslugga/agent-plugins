#!/usr/bin/env bash
#
# boilerplate.sh - a starting point for production bash scripts.
#
# Usage:
#   1. Copy this file, rename it, edit the METADATA block and main().
#   2. Or source it as a library:  source /path/to/boilerplate.sh
#      (the "main" block at the bottom only runs when executed directly)
#
# Requires: bash 4.2+ (associative arrays, printf %(fmt)T, exec {fd}>)
# Tested on: Amazon Linux 2023 (bash 5.2), Debian 12, Fedora 40
#
# Lint with:   shellcheck -x boilerplate.sh
# Format with: shfmt -i 2 -ci -bn -w boilerplate.sh
#

# ---------------------------------------------------------------------------
# SECTION 0: STRICT MODE AND SHELL OPTIONS
# ---------------------------------------------------------------------------
# -E  : ERR trap is inherited by functions, subshells and command substitution.
#       Without this, an error inside a function will NOT fire your ERR trap.
# -e  : exit immediately when a command returns non-zero (see caveats below).
# -u  : treat unset variables as an error. Catches typos in variable names.
# -o pipefail : a pipeline fails if ANY stage fails, not just the last one.
#
# set -e caveats worth knowing before you trust it:
#   - It does NOT trigger inside `if`, `while`, `&&`, `||`, or `!` conditions.
#   - `local x=$(false)` hides the failure because `local` returns 0.
#     Write:  local x; x=$(false)
#   - To allow a command to fail on purpose:  somecmd || true
#   - `(( n++ ))` returns exit status 1 when n was 0, which kills the script.
#     Write:  (( n += 1 ))
#   - A function whose LAST line is `[[ cond ]] && action` returns 1 when the
#     condition is false, which also kills the script. End with `return 0`.
set -Eeuo pipefail

# Word splitting only on newline and tab, never on plain spaces.
# This stops "$var" containing spaces from silently becoming two arguments.
# Trade-off: `read -ra parts <<< "a b c"` will no longer split on spaces.
# If you need space splitting in one spot, set IFS locally:
#   local IFS=' '; read -ra parts <<< "$line"
IFS=$'\n\t'

# nullglob    : an unmatched glob expands to nothing instead of the literal "*.txt"
# extglob     : enables !(...), +(...), @(...) pattern matching
# inherit_errexit : (bash 4.4+) command substitution inherits set -e
shopt -s nullglob extglob
if ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4))); then
  shopt -s inherit_errexit
fi

# ---------------------------------------------------------------------------
# SECTION 1: METADATA AND GLOBAL DEFAULTS
# ---------------------------------------------------------------------------
# Resolve the real directory of this script, following symlinks, with no
# dependency on `readlink -f` (which is missing on macOS by default).
# The guard makes the file safe to source more than once: without it, the
# second `readonly` assignment would raise an error.
if [[ -z ${SCRIPT_DIR:-} ]]; then
  _self="${BASH_SOURCE[0]}"
  while [[ -L $_self ]]; do
    _dir=$(cd -P -- "$(dirname -- "$_self")" && pwd)
    _self=$(readlink -- "$_self")
    [[ $_self != /* ]] && _self="$_dir/$_self"
  done
  # Assign first, mark readonly second. `readonly X="$(cmd)"` would hide a
  # failing command substitution behind readonly's own exit status.
  _dir=$(cd -P -- "$(dirname -- "$_self")" && pwd) || exit 1
  readonly SCRIPT_DIR="$_dir"
  readonly SCRIPT_NAME="$(basename -- "$_self")"
  readonly SCRIPT_VERSION="1.0.0"
  unset _dir _self
fi

# Runtime flags. All can be overridden by the environment or by CLI options.
LOG_LEVEL="${LOG_LEVEL:-INFO}"   # DEBUG | INFO | WARN | ERROR | FATAL
LOG_FILE="${LOG_FILE:-}"         # empty means stderr only
DRY_RUN="${DRY_RUN:-0}"          # 1 = print commands instead of running them
ASSUME_YES="${ASSUME_YES:-0}"    # 1 = answer yes to every confirm() prompt
NO_COLOR="${NO_COLOR:-}"         # any non-empty value disables colour
declare -a ARGS=()               # positional arguments left after parsing

# Internal state. Underscore prefix means "do not touch from outside".
declare -a _CLEANUP_STACK=()
_TMP_ROOT=""
_LOCK_FD=""
_LOCK_FILE=""

# ---------------------------------------------------------------------------
# FUNCTION 1: setup_colors - terminal colours that degrade gracefully
# ---------------------------------------------------------------------------
# Colour is only emitted when stderr is a real terminal and NO_COLOR is unset.
# This keeps log files, pipes and CI output clean of escape codes.
setup_colors() {
  if [[ -t 2 && -z $NO_COLOR && ${TERM:-dumb} != "dumb" ]]; then
    C_RESET=$'\033[0m'
    C_RED=$'\033[0;31m'
    C_GREEN=$'\033[0;32m'
    C_YELLOW=$'\033[0;33m'
    C_BLUE=$'\033[0;34m'
    C_MAGENTA=$'\033[0;35m'
    C_CYAN=$'\033[0;36m'
    C_GREY=$'\033[0;90m'
    C_BOLD=$'\033[1m'
  else
    C_RESET='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE=''
    C_MAGENTA='' C_CYAN='' C_GREY='' C_BOLD=''
  fi
}
setup_colors

# ---------------------------------------------------------------------------
# FUNCTION 2: log - levelled logging to stderr and optional log file
# ---------------------------------------------------------------------------
# Everything goes to stderr so that stdout stays clean for real output.
# That means `result=$(myscript.sh)` captures data, not log noise.
#
#   log_debug "cache miss for key=%s"   # printf style is NOT used, plain text
#   log_info  "starting sync"
#   log_warn  "retrying in 5s"
#   log_error "upload failed"
declare -A _LOG_LEVELS=([DEBUG]=10 [INFO]=20 [WARN]=30 [ERROR]=40 [FATAL]=50)

log() {
  local level="${1^^}"
  shift
  # IFS is $'\n\t' globally, so "$*" would join arguments with a newline.
  # A local IFS restores normal "space separated" message building.
  local IFS=' '
  local msg="$*"

  local want="${_LOG_LEVELS[$level]:-20}"
  local threshold="${_LOG_LEVELS[${LOG_LEVEL^^}]:-20}"
  ((want < threshold)) && return 0

  # Built-in timestamp formatting. Much faster than forking `date` per line.
  local ts
  printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1

  local colour=""
  case $level in
    DEBUG) colour=$C_GREY ;;
    INFO) colour=$C_BLUE ;;
    WARN) colour=$C_YELLOW ;;
    ERROR | FATAL) colour=$C_RED ;;
  esac

  printf '%s %s%-5s%s %s\n' "$ts" "$colour" "$level" "$C_RESET" "$msg" >&2

  if [[ -n $LOG_FILE ]]; then
    printf '%s %-5s [%s] %s\n' "$ts" "$level" "$SCRIPT_NAME" "$msg" >>"$LOG_FILE"
  fi
}

log_debug() { log DEBUG "$@"; }
log_info() { log INFO "$@"; }
log_warn() { log WARN "$@"; }
log_error() { log ERROR "$@"; }
log_ok() { printf '%s  %s[ ok ]%s %s\n' "$(printf '%(%H:%M:%S)T' -1)" "$C_GREEN" "$C_RESET" "$*" >&2; }

# ---------------------------------------------------------------------------
# FUNCTION 3: die - log a fatal message and exit
# ---------------------------------------------------------------------------
#   die "config file not found"        # exits 1
#   die "bad argument" 2               # exits 2
die() {
  local msg="${1:-unspecified fatal error}"
  local code="${2:-1}"
  log FATAL "$msg"
  exit "$code"
}

# ---------------------------------------------------------------------------
# FUNCTION 4: usage - self documenting help text
# ---------------------------------------------------------------------------
# Keep this in sync with parse_args(). A script whose --help lies is worse
# than a script with no --help at all.
usage() {
  cat <<EOF
${C_BOLD}${SCRIPT_NAME}${C_RESET} v${SCRIPT_VERSION} - one line description of what this does.

${C_BOLD}USAGE${C_RESET}
  ${SCRIPT_NAME} [OPTIONS] <target> [target...]

${C_BOLD}OPTIONS${C_RESET}
  -h, --help              Show this help and exit
  -V, --version           Print version and exit
  -v, --verbose           Lower the log level to DEBUG
  -q, --quiet             Raise the log level to ERROR
  -n, --dry-run           Show what would run, change nothing
  -y, --yes               Answer yes to all prompts (for cron and CI)
  -c, --config FILE       Read KEY=VALUE settings from FILE
      --log-level LEVEL   DEBUG, INFO, WARN, ERROR or FATAL (default: INFO)
      --log-file FILE     Also append log lines to FILE
      --no-color          Disable coloured output
  --                      Stop option parsing, treat the rest as arguments

${C_BOLD}ENVIRONMENT${C_RESET}
  LOG_LEVEL, LOG_FILE, DRY_RUN, ASSUME_YES, NO_COLOR

${C_BOLD}EXAMPLES${C_RESET}
  ${SCRIPT_NAME} --dry-run --verbose /srv/app
  LOG_LEVEL=DEBUG ${SCRIPT_NAME} --config ./prod.env web01 web02

${C_BOLD}EXIT CODES${C_RESET}
  0  success            2  invalid usage
  1  general failure    3  missing dependency
EOF
}

version() { printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; }

# ---------------------------------------------------------------------------
# FUNCTION 5: parse_args - hand written option parser
# ---------------------------------------------------------------------------
# Why not getopts? Because the bash builtin does not support long options
# like --dry-run. Why not getopt(1)? Because behaviour differs between GNU
# and BSD. A plain while/case loop is portable and easy to read.
#
# Supports both "--config file" and "--config=file" styles.
parse_args() {
  while (($# > 0)); do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      -V | --version)
        version
        exit 0
        ;;
      -v | --verbose) LOG_LEVEL="DEBUG" ;;
      -q | --quiet) LOG_LEVEL="ERROR" ;;
      -n | --dry-run) DRY_RUN=1 ;;
      -y | --yes) ASSUME_YES=1 ;;
      --no-color)
        NO_COLOR=1
        setup_colors
        ;;
      -c | --config)
        [[ ${2:-} ]] || die "--config requires a file path" 2
        load_config "$2"
        shift
        ;;
      --config=*) load_config "${1#*=}" ;;
      --log-level)
        [[ ${2:-} ]] || die "--log-level requires a value" 2
        LOG_LEVEL="$2"
        shift
        ;;
      --log-level=*) LOG_LEVEL="${1#*=}" ;;
      --log-file)
        [[ ${2:-} ]] || die "--log-file requires a path" 2
        LOG_FILE="$2"
        shift
        ;;
      --log-file=*) LOG_FILE="${1#*=}" ;;
      --)
        shift
        ARGS+=("$@")
        break
        ;;
      -*) die "unknown option: $1 (try --help)" 2 ;;
      *) ARGS+=("$1") ;;
    esac
    shift
  done

  [[ -n ${_LOG_LEVELS[${LOG_LEVEL^^}]:-} ]] || die "invalid log level: $LOG_LEVEL" 2
}

# ---------------------------------------------------------------------------
# FUNCTION 6: register_cleanup - LIFO cleanup stack
# ---------------------------------------------------------------------------
# Register work to undo as soon as you create it, not at the end of the
# script. Commands run in reverse order, like an unwinding stack.
#
#   mkdir /srv/staging
#   register_cleanup "rmdir /srv/staging"
#
# Note: the argument is evaluated later, so quote carefully. Prefer
# registering a function name over a long inline command.
register_cleanup() {
  local IFS=' '
  _CLEANUP_STACK+=("$*")
}

_run_cleanup() {
  local i
  for ((i = ${#_CLEANUP_STACK[@]} - 1; i >= 0; i--)); do
    log_debug "cleanup: ${_CLEANUP_STACK[i]}"
    eval "${_CLEANUP_STACK[i]}" || log_warn "cleanup step failed: ${_CLEANUP_STACK[i]}"
  done
  _CLEANUP_STACK=()
}

# ---------------------------------------------------------------------------
# FUNCTION 7: trap handlers - never leak temp files, locks or half done work
# ---------------------------------------------------------------------------
on_exit() {
  local rc=$?
  trap - EXIT INT TERM ERR   # avoid recursion if cleanup itself fails
  _run_cleanup
  log_debug "exiting with code ${rc}"
  exit "$rc"
}

on_signal() {
  local sig="$1"
  log_warn "received SIG${sig}, cleaning up"
  # Convention: 128 + signal number, so callers can tell how you died.
  case $sig in
    INT) exit 130 ;;
    TERM) exit 143 ;;
    *) exit 1 ;;
  esac
}

on_error() {
  local rc=$?
  local line="${BASH_LINENO[0]}"
  local cmd="$BASH_COMMAND"
  local src="${BASH_SOURCE[1]:-$SCRIPT_NAME}"
  log_error "command failed (exit ${rc}) at ${src}:${line}"
  log_error "  -> ${cmd}"
  print_stack_trace
  exit "$rc"
}

print_stack_trace() {
  local i
  local depth=${#FUNCNAME[@]}
  log_error "call stack:"
  for ((i = 2; i < depth; i++)); do
    log_error "  ${FUNCNAME[i]}() at ${BASH_SOURCE[i]}:${BASH_LINENO[i - 1]}"
  done
}

trap on_exit EXIT
trap 'on_signal INT' INT
trap 'on_signal TERM' TERM
trap on_error ERR

# ---------------------------------------------------------------------------
# FUNCTION 8: make_temp - temp files and dirs that clean themselves up
# ---------------------------------------------------------------------------
# Never write to a hard coded /tmp/myfile. That is a symlink attack and a
# collision waiting to happen. mktemp gives you a private, unpredictable name.
#
#   tmpdir=$(make_temp_dir)
#   tmpfile=$(make_temp_file "download")
make_temp_dir() {
  local prefix="${1:-$SCRIPT_NAME}"
  local d
  d=$(mktemp -d -t "${prefix}.XXXXXXXXXX") || die "cannot create temp dir"
  register_cleanup "rm -rf -- '$d'"
  printf '%s\n' "$d"
}

make_temp_file() {
  local prefix="${1:-$SCRIPT_NAME}"
  local f
  f=$(mktemp -t "${prefix}.XXXXXXXXXX") || die "cannot create temp file"
  register_cleanup "rm -f -- '$f'"
  printf '%s\n' "$f"
}

# ---------------------------------------------------------------------------
# FUNCTION 9: require_cmds - fail fast on missing dependencies
# ---------------------------------------------------------------------------
# Check everything you need up front. Failing 40 minutes into a job because
# `jq` is missing is the most avoidable outage there is.
#
#   require_cmds curl jq tar systemctl
require_cmds() {
  local IFS=' '
  local -a missing=()
  local cmd
  for cmd in "$@"; do
    command -v -- "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if ((${#missing[@]} > 0)); then
    die "missing required command(s): ${missing[*]}" 3
  fi
  log_debug "dependencies present: $*"
}

# ---------------------------------------------------------------------------
# FUNCTION 10: require_root / require_not_root
# ---------------------------------------------------------------------------
require_root() {
  ((EUID == 0)) || die "this script must be run as root (try: sudo $SCRIPT_NAME)" 2
}

require_not_root() {
  ((EUID != 0)) || die "refusing to run as root" 2
}

# ---------------------------------------------------------------------------
# FUNCTION 11: acquire_lock - only one instance at a time
# ---------------------------------------------------------------------------
# Essential for anything in cron. Without it, a slow run overlaps the next
# run and you get duplicate work or corrupted state.
#
#   acquire_lock                 # fail immediately if already locked
#   acquire_lock "" 30           # wait up to 30 seconds for the lock
acquire_lock() {
  local lockfile="${1:-/var/lock/${SCRIPT_NAME}.lock}"
  local wait_secs="${2:-0}"

  # Fall back to /tmp when /var/lock is not writable (non-root, containers).
  if ! : >>"$lockfile" 2>/dev/null; then
    lockfile="${TMPDIR:-/tmp}/${SCRIPT_NAME}.lock"
    : >>"$lockfile" || die "cannot create lock file: $lockfile"
  fi

  exec {_LOCK_FD}>"$lockfile" || die "cannot open lock file: $lockfile"
  _LOCK_FILE="$lockfile"

  if ((wait_secs > 0)); then
    flock -w "$wait_secs" "$_LOCK_FD" \
      || die "another instance is running (waited ${wait_secs}s): $lockfile"
  else
    flock -n "$_LOCK_FD" || die "another instance is running: $lockfile"
  fi

  printf '%s\n' "$$" >&"$_LOCK_FD"
  register_cleanup "_release_lock"
  log_debug "lock acquired: $lockfile (pid $$)"
}

_release_lock() {
  [[ -n $_LOCK_FD ]] || return 0
  flock -u "$_LOCK_FD" 2>/dev/null || true
  eval "exec ${_LOCK_FD}>&-" 2>/dev/null || true
  _LOCK_FD=""
}

# ---------------------------------------------------------------------------
# FUNCTION 12: run_cmd - dry run aware command execution
# ---------------------------------------------------------------------------
# Route every state changing command through this. Then --dry-run works
# across the whole script for free, which makes reviews and rehearsals safe.
#
#   run_cmd systemctl restart nginx
#   run_cmd rsync -a "$src/" "$dst/"
run_cmd() {
  if ((DRY_RUN)); then
    printf '%s[dry-run]%s %s\n' "$C_MAGENTA" "$C_RESET" "$(quote_args "$@")" >&2
    return 0
  fi
  log_debug "exec: $(quote_args "$@")"
  "$@"
}

# Render an argument list so it can be pasted back into a shell safely.
quote_args() {
  local out="" arg
  for arg in "$@"; do
    if [[ $arg =~ ^[A-Za-z0-9_./:=-]+$ ]]; then
      out+="$arg "
    else
      out+="'${arg//\'/\'\\\'\'}' "
    fi
  done
  printf '%s' "${out% }"
}

# ---------------------------------------------------------------------------
# FUNCTION 13: retry - exponential backoff with jitter
# ---------------------------------------------------------------------------
# Networks fail. APIs rate limit. Retrying blindly in a tight loop makes it
# worse. Backoff plus jitter spreads the load out.
#
#   retry 5 2 curl -fsS https://api.example.com/health
#     -> up to 5 attempts, base delay 2s: 2s, 4s, 8s, 16s (plus jitter)
retry() {
  local max_attempts="$1" base_delay="$2"
  shift 2
  local attempt=1 delay rc

  while :; do
    # Temporarily disable errexit so a failure here does not kill the script.
    set +e
    "$@"
    rc=$?
    set -e

    ((rc == 0)) && return 0
    ((attempt >= max_attempts)) && break

    delay=$((base_delay * 2 ** (attempt - 1)))
    delay=$((delay + RANDOM % (delay > 1 ? delay : 1)))   # jitter
    log_warn "attempt ${attempt}/${max_attempts} failed (rc=${rc}), retrying in ${delay}s"
    sleep "$delay"
    ((attempt += 1))
  done

  log_error "all ${max_attempts} attempts failed: $(quote_args "$@")"
  return "$rc"
}

# ---------------------------------------------------------------------------
# FUNCTION 14: wait_for - poll a condition until it becomes true
# ---------------------------------------------------------------------------
# The correct alternative to "sleep 30 and hope the service came up".
#
#   wait_for 60 2 "port 5432 open" bash -c 'exec 3<>/dev/tcp/127.0.0.1/5432'
#   wait_for 120 5 "pod ready" kubectl get pod app -o name
wait_for() {
  local timeout="$1" interval="$2" description="$3"
  shift 3
  local elapsed=0

  log_info "waiting for ${description} (timeout ${timeout}s)"
  while ((elapsed < timeout)); do
    if "$@" >/dev/null 2>&1; then
      log_ok "${description} ready after ${elapsed}s"
      return 0
    fi
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done

  log_error "timed out after ${timeout}s waiting for ${description}"
  return 1
}

# ---------------------------------------------------------------------------
# FUNCTION 15: confirm - yes/no prompt that is automation friendly
# ---------------------------------------------------------------------------
# Returns 0 for yes, 1 for no. Auto-answers yes when --yes is set or when
# stdin is not a terminal, so the script never hangs in cron.
#
#   confirm "Delete ${count} snapshots?" || die "aborted by user"
confirm() {
  local prompt="${1:-Continue?}"
  local default="${2:-n}"   # "y" or "n"

  if ((ASSUME_YES)); then
    log_debug "auto-confirmed: ${prompt}"
    return 0
  fi
  if [[ ! -t 0 ]]; then
    log_warn "non-interactive shell, assuming '${default}' for: ${prompt}"
    [[ ${default,,} == "y" ]] && return 0 || return 1
  fi

  local hint="[y/N]"
  [[ ${default,,} == "y" ]] && hint="[Y/n]"

  local answer
  while :; do
    read -r -p "$(printf '%s%s%s %s ' "$C_YELLOW" "$prompt" "$C_RESET" "$hint")" answer </dev/tty
    answer="${answer:-$default}"
    case "${answer,,}" in
      y | yes) return 0 ;;
      n | no) return 1 ;;
      *) printf 'Please answer y or n.\n' >&2 ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# FUNCTION 16: prompt - read input with a default and optional validation
# ---------------------------------------------------------------------------
#   region=$(prompt "AWS region" "eu-central-1")
#   secret=$(prompt_secret "API token")
prompt() {
  local question="$1" default="${2:-}" answer
  local suffix=""
  [[ -n $default ]] && suffix=" [${default}]"

  if [[ ! -t 0 ]]; then
    [[ -n $default ]] || die "no default for '${question}' and no terminal to ask on"
    printf '%s\n' "$default"
    return 0
  fi

  read -r -p "$(printf '%s%s:%s ' "$C_CYAN" "${question}${suffix}" "$C_RESET")" answer </dev/tty
  printf '%s\n' "${answer:-$default}"
}

prompt_secret() {
  local question="$1" answer
  read -r -s -p "$(printf '%s%s:%s ' "$C_CYAN" "$question" "$C_RESET")" answer </dev/tty
  printf '\n' >&2
  printf '%s\n' "$answer"
}

# ---------------------------------------------------------------------------
# FUNCTION 17: load_config - read KEY=VALUE files without sourcing them
# ---------------------------------------------------------------------------
# `source config.env` executes the file. A config file should be data, not
# code. This parser reads plain KEY=VALUE lines and ignores everything else,
# so a compromised config cannot run arbitrary commands as root.
load_config() {
  local file="$1"
  [[ -r $file ]] || die "config file not readable: ${file}"

  local perms
  perms=$(stat -c '%a' "$file" 2>/dev/null || stat -f '%Lp' "$file" 2>/dev/null || echo "")
  [[ $perms =~ [2367]$ ]] && log_warn "config file is world writable: ${file} (${perms})"

  local line key value lineno=0
  while IFS= read -r line || [[ -n $line ]]; do
    ((lineno += 1))
    line="${line%%#*}"                    # strip comments
    line="$(trim "$line")"
    [[ -z $line ]] && continue
    [[ $line != *=* ]] && {
      log_warn "${file}:${lineno}: ignoring malformed line"
      continue
    }

    key="$(trim "${line%%=*}")"
    value="$(trim "${line#*=}")"
    key="${key#export }"

    if [[ ! $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      log_warn "${file}:${lineno}: ignoring invalid key '${key}'"
      continue
    fi

    # Strip one layer of matching quotes.
    [[ $value == \"*\" || $value == \'*\' ]] && value="${value:1:${#value}-2}"

    printf -v "$key" '%s' "$value"
    export "${key?}"
    log_debug "config: ${key}=$(mask_secret "$key" "$value")"
  done <"$file"

  log_info "loaded config: ${file}"
}

# ---------------------------------------------------------------------------
# FUNCTION 18: detect_os - know where you are running
# ---------------------------------------------------------------------------
# Sets OS_KERNEL, OS_ID, OS_VERSION, OS_FAMILY, OS_ARCH, PKG_MANAGER.
# Use it to pick the right package manager or service command instead of
# assuming apt-get exists.
detect_os() {
  OS_KERNEL="$(uname -s)"
  OS_ARCH="$(uname -m)"
  OS_ID="unknown"
  OS_VERSION="unknown"
  OS_FAMILY="unknown"
  PKG_MANAGER=""

  if [[ -r /etc/os-release ]]; then
    # Read without sourcing, same reasoning as load_config.
    local k v
    while IFS='=' read -r k v; do
      v="${v%\"}"
      v="${v#\"}"
      case "$k" in
        ID) OS_ID="$v" ;;
        VERSION_ID) OS_VERSION="$v" ;;
        ID_LIKE) OS_FAMILY="$v" ;;
      esac
    done </etc/os-release
    [[ $OS_FAMILY == "unknown" ]] && OS_FAMILY="$OS_ID"
  elif [[ $OS_KERNEL == "Darwin" ]]; then
    OS_ID="macos"
    OS_FAMILY="darwin"
    OS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
  fi

  local pm
  for pm in dnf microdnf yum apt-get zypper apk pacman brew; do
    if command -v -- "$pm" >/dev/null 2>&1; then
      PKG_MANAGER="$pm"
      break
    fi
  done

  export OS_KERNEL OS_ARCH OS_ID OS_VERSION OS_FAMILY PKG_MANAGER
  log_debug "os: ${OS_ID} ${OS_VERSION} (${OS_FAMILY}) ${OS_ARCH}, pkg=${PKG_MANAGER:-none}"
}

# ---------------------------------------------------------------------------
# FUNCTION 19: version_ge - compare semantic versions correctly
# ---------------------------------------------------------------------------
# String comparison says "1.10.0" < "1.9.0", which is wrong. This does it
# properly, in pure bash, with no dependency on `sort -V`.
#
#   version_ge "$(docker --version | grep -oE '[0-9.]+' | head -1)" "24.0.0" \
#     || die "docker 24+ required"
version_ge() {
  local a="$1" b="$2"
  [[ $a == "$b" ]] && return 0

  local -a va vb
  local IFS='.'
  read -r -a va <<<"${a%%[-+]*}"
  read -r -a vb <<<"${b%%[-+]*}"
  unset IFS

  local i len=$((${#va[@]} > ${#vb[@]} ? ${#va[@]} : ${#vb[@]}))
  for ((i = 0; i < len; i++)); do
    local x="${va[i]:-0}" y="${vb[i]:-0}"
    x="${x//[^0-9]/}" && x="${x:-0}"
    y="${y//[^0-9]/}" && y="${y:-0}"
    ((10#$x > 10#$y)) && return 0
    ((10#$x < 10#$y)) && return 1
  done
  return 0
}

# ---------------------------------------------------------------------------
# FUNCTION 20: string and array helpers
# ---------------------------------------------------------------------------
# The small things you rewrite in every script. Written once, correctly.

# trim "  hello  "  ->  "hello"
trim() {
  local s="${1-}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# in_array "prod" "${environments[@]}"  ->  exit 0 if found
in_array() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ $item == "$needle" ]] && return 0
  done
  return 1
}

# join_by "," "${list[@]}"  ->  "a,b,c"
join_by() {
  local sep="$1"
  shift
  (($# == 0)) && return 0
  printf '%s' "$1"
  shift
  printf '%s' "${@/#/$sep}"
}

# is_int 42 -> 0 ; is_int 4.2 -> 1
is_int() { [[ ${1:-} =~ ^-?[0-9]+$ ]]; }
is_positive_int() { [[ ${1:-} =~ ^[1-9][0-9]*$ ]]; }

# Hide secrets in log output based on the variable name.
mask_secret() {
  local name="${1^^}" value="$2"
  case "$name" in
    *PASS* | *SECRET* | *TOKEN* | *KEY* | *CREDENTIAL*)
      if ((${#value} > 4)); then
        printf '%s' "${value:0:2}****${value: -2}"
      else
        printf '****'
      fi
      ;;
    *) printf '%s' "$value" ;;
  esac
}

# ---------------------------------------------------------------------------
# BONUS: file safety helpers you will want on day two
# ---------------------------------------------------------------------------

# Write stdin to a file atomically. Readers never see a half written file
# because rename(2) within the same filesystem is atomic.
#   generate_config | atomic_write /etc/app/config.yml 0640
atomic_write() {
  local target="$1" mode="${2:-0644}"
  local dir tmp
  dir="$(dirname -- "$target")"
  [[ -d $dir ]] || die "target directory does not exist: ${dir}"

  tmp="$(mktemp -- "${dir}/.$(basename -- "$target").XXXXXX")" || die "mktemp failed in ${dir}"
  register_cleanup "rm -f -- '$tmp'"

  cat >"$tmp"
  chmod "$mode" "$tmp"
  mv -f -- "$tmp" "$target"
  log_debug "atomically wrote ${target} (mode ${mode})"
}

# Keep a timestamped copy before you edit something in place.
backup_file() {
  local file="$1"
  [[ -f $file ]] || return 0
  local stamp
  printf -v stamp '%(%Y%m%d-%H%M%S)T' -1
  local backup="${file}.${stamp}.bak"
  run_cmd cp -a -- "$file" "$backup"
  log_info "backup created: ${backup}"
  printf '%s\n' "$backup"
}

# Refuse to start if the disk is too full to finish.
require_disk_space() {
  local path="$1" needed_mb="$2" available_mb
  available_mb=$(df -Pm -- "$path" | awk 'NR==2 {print $4}')
  ((available_mb >= needed_mb)) \
    || die "need ${needed_mb}MB on ${path}, only ${available_mb}MB free"
  log_debug "disk check ok: ${available_mb}MB free on ${path}"
}

# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------
# Keep main() short. It should read like a table of contents: validate,
# prepare, do the work, report. All the detail lives in named functions.
main() {
  parse_args "$@"

  log_debug "${SCRIPT_NAME} v${SCRIPT_VERSION} starting (pid $$, dry-run=${DRY_RUN})"

  require_cmds awk sed grep df
  detect_os

  # Uncomment the guards your script actually needs.
  # require_root
  # acquire_lock "" 30
  # require_disk_space /var 500

  if ((${#ARGS[@]} == 0)); then
    log_error "no target given"
    usage
    exit 2
  fi

  local workdir
  workdir="$(make_temp_dir)"
  log_info "working directory: ${workdir}"

  local target
  for target in "${ARGS[@]}"; do
    log_info "processing target: ${target}"
    run_cmd true "pretend work on ${target}"
  done

  log_ok "completed ${#ARGS[@]} target(s)"
}

# Only run main when executed directly. When this file is sourced, the caller
# gets all the functions above as a library and nothing else happens.
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  main "$@"
fi

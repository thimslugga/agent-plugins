#!/usr/bin/env bash
set -euo pipefail
umask 077

# macos-log-triage.sh - Collect a bounded macOS log triage bundle.
#
# Usage: bash macos-log-triage.sh [-t HOURS] [-o OUTDIR] [-p PREDICATE] [-a] [-q]
#
#   -t HOURS      Lookback window in hours (default: 6)
#   -o OUTDIR     New output directory; its parent must exist
#                 (default: ~/Desktop/mac-log-triage-<timestamp>)
#   -p PREDICATE  Extra unified log predicate to capture as its own file
#   -a            Also collect a portable .logarchive
#   -q            Suppress progress output
#   -h            Show this help
#
# Run as your normal user. If privileged collection is wanted, run 'sudo -v'
# first. The collector uses cached sudo access without prompting; otherwise
# it collects unprivileged results and marks the bundle partial.
# Exit codes: 0 complete, 1 partial/failed collection, 2 invalid arguments.

HOURS=6
OUTDIR=""
EXTRA_PREDICATE=""
COLLECT_ARCHIVE=0
QUIET=0
USE_SUDO=0
PRIVILEGED=no
FAILURES=0
LOG_SUCCESSES=0
STEP_RESULTS=()

usage() {
  sed -n '/^# macos-log-triage.sh/,/^$/p' "${0}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

log_msg() {
  [[ "${QUIET}" -eq 1 ]] || printf '==> %s\n' "$*" >&2
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

run_privileged() {
  if [[ "${USE_SUDO}" -eq 1 ]]; then
    sudo -n "$@"
  else
    "$@"
  fi
}

# Continue after an individual failure, preserving its stderr and exit status.
collect_step() {
  local kind="${1}" filename="${2}" status
  shift 2
  log_msg "Collecting ${filename}"
  if "$@" >"${OUTDIR}/${filename}" 2>"${OUTDIR}/${filename}.stderr.txt"; then
    STEP_RESULTS+=("${filename}: ok")
    if [[ "${kind}" == log ]]; then
      LOG_SUCCESSES=$((LOG_SUCCESSES + 1))
    fi
  else
    status=$?
    FAILURES=$((FAILURES + 1))
    STEP_RESULTS+=("${filename}: failed (exit ${status})")
    warn "${filename} failed (exit ${status}); see ${filename}.stderr.txt"
  fi
}

system_facts() {
  local failed=0
  printf '=== collected ===\n'
  date '+%Y-%m-%d %H:%M:%S %z' || failed=1
  printf '\n=== sw_vers ===\n'
  sw_vers || failed=1
  printf '\n=== uname -a ===\n'
  uname -a || failed=1
  printf '\n=== hostname ===\n'
  hostname || failed=1
  printf '\n=== timezone ===\n'
  date '+%z %Z' || failed=1
  printf '\n=== uptime ===\n'
  uptime || failed=1
  printf '\n=== kern.boottime ===\n'
  sysctl -n kern.boottime || failed=1
  printf '\n=== disk free ===\n'
  df -h / /System/Volumes/Data || failed=1
  printf '\n=== last reboot ===\n'
  last reboot | sed -n '1,15p' || failed=1
  return "${failed}"
}

# grep exit 1 means no matches; other failures must reach the step status.
# Every command status is handled explicitly in this conditional helper.
# shellcheck disable=SC2310
matching_lines() {
  local status
  if run_privileged "$@"; then
    return 0
  else
    status=$?
    if [[ "${status}" -eq 1 ]]; then
      printf '(no matches)\n'
      return 0
    fi
    return "${status}"
  fi
}

# Each command/pipeline failure is accumulated instead of relying on errexit.
# shellcheck disable=SC2310
install_excerpts() {
  local failed=0
  local rotated_logs=(/var/log/install.log.*.gz)
  printf '=== tail of /var/log/install.log ===\n'
  run_privileged tail -n 500 /var/log/install.log || failed=1
  printf '\n=== update/error lines, current log ===\n'
  matching_lines grep -iE 'softwareupdate|installer|PackageKit|error|fail' \
    /var/log/install.log | tail -200 || failed=1
  printf '\n=== update/error lines, rotated logs ===\n'
  if [[ "${#rotated_logs[@]}" -gt 0 ]]; then
    matching_lines zgrep -iE 'softwareupdate|installer|error|fail' \
      "${rotated_logs[@]}" | tail -200 || failed=1
  else
    printf '(no rotated logs)\n'
  fi
  return "${failed}"
}

# Each collection failure is accumulated so the remaining headers can be read.
# shellcheck disable=SC2310
crash_inventory() {
  local directory report failed=0 count=0
  local report_dirs=()
  for directory in "${HOME}/Library/Logs/DiagnosticReports" /Library/Logs/DiagnosticReports; do
    if [[ -d "${directory}" ]]; then
      report_dirs+=("${directory}")
    else
      printf '%s: absent\n' "${directory}"
    fi
  done
  if [[ "${#report_dirs[@]}" -eq 0 ]]; then
    return 0
  fi
  # Preserve a complete NUL-delimited inventory, then sample at most 25 headers.
  run_privileged find "${report_dirs[@]}" -type f -name '*.ips' -mtime -7 -print0 \
    >"${OUTDIR}/06-crash-paths.nul" || failed=1
  while IFS= read -r -d '' report; do
    printf '\n--- %s\n' "${report}"
    run_privileged head -1 "${report}" || failed=1
    count=$((count + 1))
    if [[ "${count}" -ge 25 ]]; then
      break
    fi
  done <"${OUTDIR}/06-crash-paths.nul"
  printf '\nHeaders sampled: %s (last 7 days)\n' "${count}"
  return "${failed}"
}

while getopts ':t:o:p:aqh' opt; do
  case "${opt}" in
    t) HOURS="${OPTARG}" ;;
    o) OUTDIR="${OPTARG}" ;;
    p) EXTRA_PREDICATE="${OPTARG}" ;;
    a) COLLECT_ARCHIVE=1 ;;
    q) QUIET=1 ;;
    h) usage 0 ;;
    *) usage 2 ;;
  esac
done
shift "$((OPTIND - 1))"
if [[ "$#" -ne 0 || ! "${HOURS}" =~ ^[0-9]+$ || ! "${HOURS}" =~ [1-9] ]]; then
  printf 'error: -t must be a positive integer; positional arguments are not supported\n' >&2
  exit 2
fi

PLATFORM="$(uname -s)"
if [[ "${PLATFORM}" != Darwin ]]; then
  printf 'error: this script only runs on macOS\n' >&2
  exit 1
fi
if ! command -v log >/dev/null 2>&1; then
  printf 'error: Apple unified logging command not found\n' >&2
  exit 1
fi

TS="$(date +%Y%m%d-%H%M%S)"
[[ -n "${OUTDIR}" ]] || OUTDIR="${HOME}/Desktop/mac-log-triage-${TS}"
# Make paths absolute, including paths beginning with a dash. Atomic mkdir
# refuses an existing file, directory, or symlink without touching its contents.
[[ "${OUTDIR}" == /* ]] || OUTDIR="${PWD}/${OUTDIR}"
if ! mkdir -m 700 "${OUTDIR}"; then
  printf 'error: output must be a new directory with an existing parent: %s\n' "${OUTDIR}" >&2
  exit 1
fi
shopt -s nullglob

CALLER_UID="$(id -u)"
if [[ "${CALLER_UID}" -eq 0 ]]; then
  PRIVILEGED='yes (root)'
elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>"${OUTDIR}/privilege.stderr.txt"; then
  USE_SUDO=1
  PRIVILEGED='yes (sudo verified at start)'
else
  warn 'privileged access unavailable; collecting partial results without prompting'
fi

log_msg "Output directory: ${OUTDIR}"
log_msg "Lookback window: ${HOURS}h; shutdown causes and crash inventory: 7d"
collect_step auxiliary 00-system-facts.txt system_facts
collect_step log 01-shutdown-causes.txt run_privileged log show --last 7d --style syslog \
  --predicate 'eventMessage CONTAINS "Previous shutdown cause"'
collect_step auxiliary 02-install-log.txt install_excerpts

# Error and fault messageType values are 16 and 17.
# Preserve query errors instead of silently falling back to a broad export.
collect_step log 03-errors-faults.ndjson run_privileged log show --last "${HOURS}h" \
  --style ndjson --predicate 'messageType == 16 OR messageType == 17'
collect_step log 04-auth-and-updates.txt run_privileged log show --last "${HOURS}h" \
  --info --style syslog --predicate \
  'process IN {"sudo", "logind", "loginwindow", "sshd", "screensharingd", "tccd", "softwareupdated", "installd"}'
if [[ -n "${EXTRA_PREDICATE}" ]]; then
  collect_step log 05-custom-predicate.ndjson run_privileged log show --last "${HOURS}h" \
    --info --style ndjson --predicate "${EXTRA_PREDICATE}"
  printf '%s\n' "${EXTRA_PREDICATE}" >"${OUTDIR}/05-custom-predicate.txt"
fi
collect_step auxiliary 06-crash-reports.txt crash_inventory
if [[ "${COLLECT_ARCHIVE}" -eq 1 ]]; then
  collect_step log 07-collect.txt run_privileged log collect --last "${HOURS}h" \
    --output "${OUTDIR}/unified-${HOURS}h.logarchive"
fi

log_msg 'Writing manifest'
COLLECTION_STATUS=complete
# MANIFEST.txt is excluded from find. The conditional records hashing failures;
# privilege is retained so root-owned logarchive contents remain readable.
# shellcheck disable=SC2094,SC2310
{
  printf 'macOS log triage bundle\nGenerated : '
  date '+%Y-%m-%d %H:%M:%S %z'
  printf 'Window    : %sh (shutdown causes and crash inventory: 7d; install excerpts are line-limited)\n' "${HOURS}"
  printf 'Privileged: %s\n' "${PRIVILEGED}"
  printf '\nFiles (sha256, recursively includes archive contents):\n'
  if ! run_privileged find "${OUTDIR}" -type f ! -path "${OUTDIR}/MANIFEST.txt" \
    -exec shasum -a 256 {} +; then
    FAILURES=$((FAILURES + 1))
    STEP_RESULTS+=('manifest hashing: failed')
  fi
  if [[ "${LOG_SUCCESSES}" -eq 0 ]]; then
    COLLECTION_STATUS=failed
  elif [[ "${FAILURES}" -gt 0 || "${PRIVILEGED}" == no ]]; then
    COLLECTION_STATUS=partial
  fi
  printf '\nSteps:\n'
  printf '%s\n' "${STEP_RESULTS[@]}"
  printf '\nCollection status: %s\n' "${COLLECTION_STATUS}"
} >"${OUTDIR}/MANIFEST.txt" 2>&1

printf '\nTriage bundle: %s\nCollection status: %s\n' "${OUTDIR}" "${COLLECTION_STATUS}"
if [[ -s "${OUTDIR}/03-errors-faults.ndjson" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
  printf '\nNext step:\n  python3 %q %q --top 20\n' \
    "${SCRIPT_DIR}/macos-log-summarize.py" "${OUTDIR}/03-errors-faults.ndjson"
fi
[[ "${COLLECTION_STATUS}" == complete ]]

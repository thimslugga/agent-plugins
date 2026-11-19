#!/bin/sh
# Install mise with the official mise.run installer and, on request, add
# shell activation, login-profile shims and completions.
#
# POSIX sh on purpose: this must run on Alpine and in minimal containers
# where bash is not installed.
#
# Usage: install-mise.sh [OPTIONS]
#
# Exit codes: 0 success, 1 runtime failure, 2 usage error.

set -eu

INSTALLER_URL='https://mise.run'

version=''
install_path="${MISE_INSTALL_PATH:-${HOME}/.local/bin/mise}"
activate_shell=''
want_shims='false'
want_completions='false'
want_musl='false'
force='false'
dry_run='false'
tmp_dir=''

usage() {
  cat <<USAGE
Usage: install-mise.sh [OPTIONS]

Install mise from ${INSTALLER_URL} (official release binary, checksum-verified
by the installer). Does nothing if mise is already at the install path, unless
--force or --version is given.

Options:
  -V, --version VERSION   Install this release, such as v2026.10.4
  -p, --path PATH         Executable path (default: ~/.local/bin/mise)
  -a, --activate SHELL    Add activation to the startup file of bash, zsh or
                          fish. "auto" uses the name of \$SHELL.
  -s, --shims             With --activate: also add "activate --shims" to the
                          login profile, for editors and GUI programs
  -c, --completions       With --activate: install shell completions
  -m, --musl              Install the static musl build
  -f, --force             Run the installer even if mise is already installed
  -n, --dry-run           Print what would be done and change nothing
  -h, --help              Show this help and exit

Examples:
  install-mise.sh --activate auto --completions
  install-mise.sh --version v2026.10.4 --path /usr/local/bin/mise
  install-mise.sh --dry-run --activate zsh --shims
USAGE
}

log() {
  level="$1"
  shift
  printf '%s [%-5s] %s\n' "$(date +'%Y-%m-%dT%H:%M:%S%z')" "${level}" "$*" >&2
}

info() { log 'INFO' "$@"; }
warn() { log 'WARN' "$@"; }

die() {
  log 'ERROR' "$@"
  exit 1
}

die_usage() {
  log 'ERROR' "$@"
  usage >&2
  exit 2
}

cleanup() {
  rc=$?
  if [ -n "${tmp_dir}" ] && [ -d "${tmp_dir}" ]; then
    rm -rf -- "${tmp_dir}"
  fi
  exit "${rc}"
}

# Run a side-effecting command, or print it under --dry-run.
run() {
  if [ "${dry_run}" = 'true' ]; then
    info "DRY-RUN: $*"
    return 0
  fi
  "$@"
}

require_cmd() {
  for cmd in "$@"; do
    command -v "${cmd}" >/dev/null 2>&1 || die "required command not found: ${cmd}"
  done
}

# Append one line to a file unless the exact line is already there.
append_line_once() {
  file="$1"
  line="$2"
  if [ -f "${file}" ] && grep -qxF -- "${line}" "${file}"; then
    info "already present in ${file}"
    return 0
  fi
  if [ "${dry_run}" = 'true' ]; then
    info "DRY-RUN: append to ${file}: ${line}"
    return 0
  fi
  mkdir -p -- "$(dirname -- "${file}")"
  printf '%s\n' "${line}" >>"${file}"
  info "appended to ${file}: ${line}"
}

install_mise() {
  if [ -x "${install_path}" ] && [ "${force}" = 'false' ] && [ -z "${version}" ]; then
    info "mise already installed at ${install_path}; use --force to reinstall"
    return 0
  fi
  require_cmd curl
  if [ -e /run/ostree-booted ]; then
    info 'image-based system detected; installing to the home directory, no layering needed'
  fi
  if [ "${dry_run}" = 'true' ]; then
    info "DRY-RUN: download ${INSTALLER_URL} and run it with" \
      "MISE_INSTALL_PATH=${install_path} MISE_VERSION=${version:-<newest stable>}" \
      "MISE_INSTALL_MUSL=${want_musl}"
    return 0
  fi

  tmp_dir="$(mktemp -d)" || die 'cannot create a temporary directory'
  # Download first, then run: a truncated download must not execute.
  curl -fsSL -o "${tmp_dir}/install.sh" "${INSTALLER_URL}" \
    || die "download failed: ${INSTALLER_URL}"
  [ -s "${tmp_dir}/install.sh" ] || die 'installer download is empty'

  MISE_INSTALL_PATH="${install_path}"
  MISE_INSTALL_HELP=0
  export MISE_INSTALL_PATH MISE_INSTALL_HELP
  if [ -n "${version}" ]; then
    MISE_VERSION="${version}"
    export MISE_VERSION
  fi
  if [ "${want_musl}" = 'true' ]; then
    MISE_INSTALL_MUSL=1
    export MISE_INSTALL_MUSL
  fi
  sh "${tmp_dir}/install.sh" || die 'the mise installer failed'
  [ -x "${install_path}" ] || die "installer finished but ${install_path} is missing"
}

# Print the startup file of an interactive shell.
rc_file_for() {
  case "$1" in
    bash) printf '%s\n' "${HOME}/.bashrc" ;;
    zsh) printf '%s\n' "${ZDOTDIR:-${HOME}}/.zshrc" ;;
    fish) printf '%s\n' "${XDG_CONFIG_HOME:-${HOME}/.config}/fish/config.fish" ;;
    *) return 1 ;;
  esac
}

# Print the login profile to use for shims. Bash reads only the first of
# three files, so reuse the one that exists instead of creating a new one
# that would stop ~/.profile from loading.
login_file_for() {
  case "$1" in
    zsh) printf '%s\n' "${ZDOTDIR:-${HOME}}/.zprofile" ;;
    bash)
      for candidate in "${HOME}/.bash_profile" "${HOME}/.bash_login" "${HOME}/.profile"; do
        if [ -f "${candidate}" ]; then
          printf '%s\n' "${candidate}"
          return 0
        fi
      done
      printf '%s\n' "${HOME}/.profile"
      ;;
    *) return 1 ;;
  esac
}

activate_mise() {
  shell_name="$1"
  if [ "${shell_name}" = 'auto' ]; then
    shell_name="$(basename -- "${SHELL:-}")"
  fi
  rc_file="$(rc_file_for "${shell_name}")" \
    || die_usage "unsupported shell for --activate: ${shell_name:-<empty>}"

  # Use the absolute path: ~/.local/bin is not on PATH on every system.
  if [ "${shell_name}" = 'fish' ]; then
    append_line_once "${rc_file}" "${install_path} activate fish | source"
  else
    append_line_once "${rc_file}" "eval \"\$(${install_path} activate ${shell_name})\""
  fi

  if [ "${want_shims}" = 'true' ]; then
    if login_file="$(login_file_for "${shell_name}")"; then
      append_line_once "${login_file}" \
        "eval \"\$(${install_path} activate ${shell_name} --shims)\""
    else
      warn "--shims is not handled for ${shell_name}; see references/install-and-activation.md"
    fi
  fi

  if [ "${want_completions}" = 'true' ]; then
    run "${install_path}" completion "${shell_name}" --install \
      || warn "could not install ${shell_name} completions"
  fi
}

main() {
  trap cleanup EXIT
  trap 'die "interrupted"' INT TERM

  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      -V | --version)
        [ $# -ge 2 ] || die_usage "$1 needs a value"
        version="$2"
        shift 2
        ;;
      -p | --path)
        [ $# -ge 2 ] || die_usage "$1 needs a value"
        install_path="$2"
        shift 2
        ;;
      -a | --activate)
        [ $# -ge 2 ] || die_usage "$1 needs a value"
        activate_shell="$2"
        shift 2
        ;;
      -s | --shims)
        want_shims='true'
        shift
        ;;
      -c | --completions)
        want_completions='true'
        shift
        ;;
      -m | --musl)
        want_musl='true'
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
      *) die_usage "unknown argument: $1" ;;
    esac
  done

  case "${version}" in
    '' | v*) ;;
    *) version="v${version}" ;;
  esac
  case "${install_path}" in
    /*) ;;
    *) die_usage "--path must be absolute: ${install_path}" ;;
  esac

  install_mise
  if [ -n "${activate_shell}" ]; then
    activate_mise "${activate_shell}"
  fi

  if [ "${dry_run}" = 'false' ]; then
    info "installed: $("${install_path}" --version 2>/dev/null || printf 'unknown version')"
    info "next: open a new terminal, then run: ${install_path} doctor"
  fi
}

main "$@"

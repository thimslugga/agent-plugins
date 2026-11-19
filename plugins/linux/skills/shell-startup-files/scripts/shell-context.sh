# shellcheck shell=bash
#
# Report what kind of shell is running: login or not, interactive or not.
#
# Library: source it in the shell under test, do not execute it. Executing it
# would describe the new child shell instead of the one you are asking about.
#
#   . scripts/shell-context.sh            # Bash or Zsh, current shell
#   ssh host 'bash -s' <scripts/shell-context.sh    # stdin shell on a remote
#
# Defines one function, shell_context::report, and calls it once.

#######################################
# Print the shell name, login state, interactive state and key variables.
# Globals:
#   BASH_VERSION, ZSH_VERSION, SHLVL, ZDOTDIR, BASH_ENV, ENV (all read only)
# Arguments:
#   None.
# Outputs:
#   One "key=value" line per fact on stdout.
# Returns:
#   0 always.
#######################################
shell_context::report() {
  local shell_kind='unknown'
  local login_state='non-login'
  local interactive_state='non-interactive'

  if [ -n "${ZSH_VERSION:-}" ]; then
    shell_kind="zsh ${ZSH_VERSION}"
    if [[ -o login ]]; then login_state='login'; fi
    if [[ -o interactive ]]; then interactive_state='interactive'; fi
  elif [ -n "${BASH_VERSION:-}" ]; then
    shell_kind="bash ${BASH_VERSION}"
    if shopt -q login_shell; then login_state='login'; fi
    case "$-" in *i*) interactive_state='interactive' ;; esac
  fi

  printf 'shell=%s\n' "${shell_kind}"
  printf 'login=%s\n' "${login_state}"
  printf 'interactive=%s\n' "${interactive_state}"
  printf 'argv0=%s\n' "$0"
  printf 'flags=%s\n' "$-"
  printf 'SHLVL=%s\n' "${SHLVL:-unset}"
  printf 'ZDOTDIR=%s\n' "${ZDOTDIR:-unset}"
  printf 'BASH_ENV=%s\n' "${BASH_ENV:-unset}"
  printf 'ENV=%s\n' "${ENV:-unset}"
  printf 'ssh=%s\n' "${SSH_CONNECTION:+yes}"
}

shell_context::report

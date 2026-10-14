# Bash Strict Mode: the full header block

`set -euo pipefail` is the floor, not the ceiling. This is the complete,
copy-pasteable strict-mode header for bash executables, plus the
error-trap pattern that turns any unchecked failure into a diagnosed,
timestamped fatal error. Ported (and debugged) from
[pirate/bash-utils](https://github.com/pirate/bash-utils).

## Script header

```bash
set -euo pipefail
set -o errtrace # ERR trap fires inside functions and subshells too

# inherit_errexit needs bash 4.4+; silently skip it elsewhere.
shopt -s inherit_errexit 2>/dev/null || true # bash < 4.4 lacks this option
```

What each piece does:

| Option | Effect |
|---|---|
| `errexit` (`-e`) | Exit when an unchecked command fails. Backstop only — still check return values explicitly. |
| `nounset` (`-u`) | Using an unset variable is an error. Initialize everything you read. |
| `pipefail` | A pipeline fails if any segment fails (without it, only the last segment's status counts). |
| `errtrace` (`-E`) | The `ERR` trap is inherited by functions, command substitutions, and subshells. Without it, failures inside functions bypass the trap. |
| `inherit_errexit` | Subshells and command substitutions inherit `errexit`. Without it, `x=$(false)` inside `$()` does not trigger `-e` in the parent. Bash 4.4+. |

Use `set` (not shebang flags like `#!/bin/bash -e`) so the options also apply
when the script is run as `bash script.sh`.

## The ERR trap: every unchecked failure becomes a diagnosed fatal

```bash
__ON_ERROR_ACTIVE='false'

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

# Install inside main(), next to `trap cleanup EXIT`:
trap '__on_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR
```

The trap does **not** fire for *checked* failures — commands in `if`/`while`
conditions, `&&`/`||` lists, or anywhere you handle the status yourself.
So explicit handling keeps working and the trap only catches what you missed:

```bash
# checked: no trap, clean return
check_preconditions curl || return 1
# unchecked: trap fires with line number
curl "${url}"
```

End the script with a bare `main "$@"`. Two reasons:

1. Wrapping the call -- `main "$@" || exit "$?"`, `if main ...`, `main ... && ...`
   -- puts `main` in a condition context, which **suppresses `set -e` and the
   `ERR` trap for everything inside `main`**. The whole error-handling design
   silently stops working.
2. A deliberate non-zero `return` from `main` reaches the trap as
   `BASH_COMMAND="return N"`, which `__on_error` above detects and exits with
   quietly (the error was already logged). Genuine failures arrive as the
   failing command text and get the full FATAL treatment. Verified: an
   unchecked `out="$(false)"` inside `main` produces exactly one FATAL line
   with the right line number, while `return 1` after `log_error` exits 1
   with no FATAL noise.

`log_fatal` (shipped in the `scripts/init-script.sh` template) logs the message at
FATAL level, prints a backtrace when `VERBOSE=true`, kills leftover
background jobs, and exits with the given status (default 1):

```bash
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
```

## `return 0`: the set -e footgun this pattern creates

A function's exit status is its **last command's** status. Under `set -e`,
calling a function whose tail happens to return non-zero kills the caller —
silently, with no error message. Real example found while porting this:

```bash
load_env() {
  local key
  local var

  for key in a b; do
    var="ENV_${key}"
    [[ -n ${!var:-} ]] && CONFIG["${key}"]="${!var}"
  done
  # Last iteration's [[ ]] was false -> loop returns 1 -> function returns 1
}

load_env # set -e kills the script here. No message. Exit 1.
```

Rule: **End every function with an explicit `return 0`** unless the exit
status is meaningful API. The `scripts/init-script.sh` template's helpers all do
this. (The original bash-utils code this was ported from has this bug in
`dns_lookup`: an unassigned `STATUS` on the success path.)

## Small helpers that belong with strict mode

```bash
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
```

`require_cmds` already exists as `check_preconditions` in the template.

## Do NOT use these

The following two globals leak into every sourcing script and cause more bugs
than they prevent:

- **`IFS=$'\n'`** — changes word splitting everywhere; the repo itself has to
  work around it (`$(IFS=" "; ...)` in its own trap, `IFS=' '` toggles in
  `json_api`). Keep default `IFS` and quote expansions instead.
- **`shopt -s dotglob`** — makes `*` match dotfiles, so `$dir/*` in cleanup
  code can wipe hidden files. Never set this globally in a library.

Also never ported: `eval "${CMD[@]}"` for running command arrays
(`timed`, `try`, `json_api` in the original) — re-parsing arrays through
`eval` breaks on quotes and spaces. Execute arrays directly:
`"cmd" "${args[@]}"`. The skill forbids `eval` (Operating Rules).

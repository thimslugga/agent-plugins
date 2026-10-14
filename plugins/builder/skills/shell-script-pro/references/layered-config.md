# Layered Configuration: defaults < file < env < CLI args

A schema-driven config loader for bash scripts that need more than
`getopts`: declare defaults, flag/option aliases, and validators once, then
get four-layer precedence with validation for free. Ported from
[pirate/bash-utils](https://github.com/pirate/bash-utils) `util/config.sh`,
rewritten **without `eval`** — the original executes the config file as code
and `eval`s validator strings; this version parses `KEY=value` files with
parameter expansion and matches validators as regexes.

Requires **bash 4.3+** (associative arrays). Not for POSIX `sh` targets —
use plain `getopts` there.

## Usage

```bash
source "lib/config.sh" # or paste the implementation below into your script

declare -A CONFIG_DEFAULTS=(
  [VERBOSE]=0
  [TIMEOUT]=15
  [NAME]=''
  [CONFIG_FILE]=''
)

declare -A CONFIG_FLAGS=([VERBOSE]='v verbose') # boolean flags

declare -A CONFIG_OPTS=( # options with values
  [TIMEOUT]='t timeout'
  [NAME]='n name'
  [CONFIG_FILE]='config-file'
)

declare -A CONFIG_VALIDATORS=([TIMEOUT]='^[0-9]+$')

declare -A CONFIG=()  # merged result

CONFIG_PREFIX='MYAPP' # optional: also read MYAPP_<KEY> from the environment

usage() {
  cat <<EOF
Usage: myapp [options]
  -v, --verbose          Enable debug output
  -t, --timeout SECONDS  Operation timeout (default 15)
  -n, --name NAME        Name to greet (required)
  --config-file PATH     Read defaults from PATH
EOF
}

main() {
  config::load "$@"   # needs your usage() for --help
  config::assert NAME # fail fast on required keys
  config::dump        # log the effective config at debug level
  printf 'Hello, %s (timeout %s)\n' "${CONFIG[NAME]}" "${CONFIG[TIMEOUT]}"
}

main "$@"
```

Precedence, lowest to highest: **defaults < config file < environment
(unprefixed, then `${PREFIX}_`) < CLI arguments**. `config::load` runs a
bootstrap env+args pass first so `--config-file` / `CONFIG_FILE` env are
discovered before the file is read.

Supported CLI forms: `-v`, `--verbose`, `--timeout 5`, `--timeout=5`,
`-t 5`, `-t5`. `-h`/`--help` calls your `usage()` and exits 0. Anything
unrecognized exits 2. `--` stops option parsing; the rest lands in
`CONFIG__REMAINING` for the caller. (Need positional args without `--`?
extend the `*)` branch in `config::__parse_args` instead of calling
`config::__unknown`.)

Config file format: `KEY=value` lines, `#` comments and blank lines
allowed, one layer of matching quotes stripped. Keys not in the schema are
ignored with a warning. A missing file is fatal; an unset `CONFIG_FILE`
skips the file layer entirely.

## Implementation

Save as `lib/config.sh` (sourced, not executable — see the skill's library
rules). Your script must define `usage()` before calling `config::load`.

```bash
#!/usr/bin/env bash

# Layered configuration: defaults < config file < environment < CLI args.
# Requires bash 4.3+. Source this file; see references/layered-config.md.

declare -gA CONFIG__ALIASES=() # alias -> "KEY:kind", kind is flag|opt
# -g: stays global even if this file is sourced inside a function.

#######################################
# Build the alias -> "KEY:kind" lookup from CONFIG_FLAGS/CONFIG_OPTS.
# Globals:
#   CONFIG_FLAGS, CONFIG_OPTS (read)
#   CONFIG__ALIASES (written)
# Arguments:
#   None
#######################################
config::__build_alias_map() {
  local key
  local alias
  local -a words=()

  # Re-declare (not just clear): restores the -A attribute if the caller
  # ever unset this private global; a bare () would make it indexed and
  # break all later CONFIG__ALIASES["k"] stores under set -u.
  declare -gA CONFIG__ALIASES=()
  for key in "${!CONFIG_FLAGS[@]}"; do
    read -ra words <<<"${CONFIG_FLAGS[${key}]}"
    for alias in "${words[@]}"; do
      CONFIG__ALIASES["${alias}"]="${key}:flag"
    done
  done

  for key in "${!CONFIG_OPTS[@]}"; do
    read -ra words <<<"${CONFIG_OPTS[${key}]}"
    for alias in "${words[@]}"; do
      CONFIG__ALIASES["${alias}"]="${key}:opt"
    done
  done

  return 0
}

#######################################
# Exit 2 on an unrecognized argument.
# Arguments:
#   $1 - the offending argument text.
#######################################
config::__unknown() {
  printf 'ERROR: unrecognized argument %s (see --help)\n' "$1" >&2
  exit 2
}

#######################################
# Parse CLI args into CONFIG (args layer). Handles -h/--help, --opt=val,
# --opt val, -o val, -oval, boolean flags, and -- to stop option parsing.
# Globals:
#   CONFIG__ALIASES (read)
#   CONFIG, CONFIG__REMAINING (written)
# Arguments:
#   $@ - the argument list to parse.
#######################################
config::__parse_args() {
  local arg
  local alias
  local value
  local entry
  local key
  local kind

  while (($# > 0)); do
    arg="$1"
    shift
    case "${arg}" in
      -h | --help)
        usage
        exit 0
        ;;
      --) # end of options; the rest are positional, left for the caller
        CONFIG__REMAINING=("$@")
        return 0
        ;;
      --*=*)
        alias="${arg%%=*}"
        alias="${alias#--}"
        value="${arg#*=}"
        entry="${CONFIG__ALIASES[${alias}]:-}"
        [[ -n ${entry} ]] || config::__unknown "${arg}"
        key="${entry%:*}"
        kind="${entry#*:}"
        [[ ${kind} == 'opt' ]] || config::__unknown "${arg}"
        CONFIG["${key}"]="${value}"
        ;;
      --*)
        alias="${arg#--}"
        entry="${CONFIG__ALIASES[${alias}]:-}"
        [[ -n ${entry} ]] || config::__unknown "${arg}"
        key="${entry%:*}"
        kind="${entry#*:}"
        if [[ ${kind} == 'flag' ]]; then
          CONFIG["${key}"]=1
        else
          (($# > 0)) || {
            printf 'error: option %s requires a value\n' "${arg}" >&2
            exit 2
          }
          CONFIG["${key}"]="$1"
          shift
        fi
        ;;
      -?*)
        alias="${arg:1:1}"
        value="${arg:2}"
        entry="${CONFIG__ALIASES[${alias}]:-}"
        [[ -n ${entry} ]] || config::__unknown "${arg}"
        key="${entry%:*}"
        kind="${entry#*:}"
        if [[ ${kind} == 'flag' ]]; then
          [[ -z ${value} ]] || config::__unknown "${arg}"
          CONFIG["${key}"]=1
        else
          if [[ -z ${value} ]]; then
            (($# > 0)) || {
              printf 'error: option -%s requires a value\n' "${alias}" >&2
              exit 2
            }
            value="$1"
            shift
          fi
          CONFIG["${key}"]="${value}"
        fi
        ;;
      *)
        config::__unknown "${arg}"
        ;;
    esac
  done

  return 0
}

#######################################
# Overlay environment variables onto CONFIG (env layer): the bare KEY
# first, then ${CONFIG_PREFIX}_KEY when CONFIG_PREFIX is set.
# Globals:
#   CONFIG_DEFAULTS (schema keys to look up)
#   CONFIG_PREFIX (read)
#   CONFIG (written)
# Arguments:
#   None
#######################################
config::__load_env() {
  local key
  local value
  local prefixed
  for key in "${!CONFIG_DEFAULTS[@]}"; do
    value="${!key:-}"
    [[ -n ${value} ]] && CONFIG["${key}"]="${value}"
    if [[ -n ${CONFIG_PREFIX:-} ]]; then
      prefixed="${CONFIG_PREFIX}_${key}"
      value="${!prefixed:-}"
      [[ -n ${value} ]] && CONFIG["${key}"]="${value}"
    fi
  done

  return 0
}

#######################################
# Read KEY=value pairs from ${CONFIG[CONFIG_FILE]} into CONFIG (file
# layer). An unset CONFIG_FILE skips the layer; a missing file is fatal.
# Globals:
#   CONFIG (reads CONFIG_FILE, written)
#   CONFIG_DEFAULTS (schema: unknown keys warn and are ignored)
# Arguments:
#   None
#######################################
config::__load_file() {
  local file="${CONFIG[CONFIG_FILE]:-}"

  [[ -n ${file} ]] || return 0
  [[ -f ${file} ]] || {
    printf 'error: config file not found: %s\n' "${file}" >&2
    exit 1
  }

  local line
  local key
  local value

  while IFS= read -r line || [[ -n ${line} ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z ${line} || ${line} == \#* ]] && continue
    [[ ${line} == *=* ]] || {
      printf 'error: bad line in %s: %s\n' "${file}" "${line}" >&2
      exit 1
    }
    key="${line%%=*}"
    value="${line#*=}"
    key="${key%"${key##*[![:space:]]}"}"
    key="${key#"${key%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    if ((${#value} >= 2)); then
      if [[ ${value} == \"*\" && ${value} == *\" ]]; then
        value="${value:1:-1}"
      elif [[ ${value} == \'*\' && ${value} == *\' ]]; then
        value="${value:1:-1}"
      fi
    fi
    if [[ -n ${CONFIG_DEFAULTS[${key}]+x} ]]; then
      CONFIG["${key}"]="${value}"
    else
      printf 'warning: ignoring unknown key %s in %s\n' "${key}" "${file}" >&2
    fi
  done <"${file}"

  return 0
}

#######################################
# Check every CONFIG_VALIDATORS regex against the merged CONFIG.
# Exits 1 on the first invalid value.
# Globals:
#   CONFIG_VALIDATORS, CONFIG (read)
# Arguments:
#   None
#######################################
config::validate() {
  local key
  local pattern
  local value

  for key in "${!CONFIG_VALIDATORS[@]}"; do
    pattern="${CONFIG_VALIDATORS[${key}]}"
    value="${CONFIG[${key}]:-}"
    [[ ${value} =~ ${pattern} ]] || {
      printf 'error: invalid config %s=%s\n' "${key}" "${value}" >&2
      exit 1
    }
  done

  return 0
}

#######################################
# Abort unless every named key is set and non-empty in CONFIG.
# Arguments:
#   $@ - config keys to require.
#######################################
config::assert() {
  local key
  local value

  for key in "$@"; do
    value="${CONFIG[${key}]:-}"
    [[ -n ${value} ]] || {
      printf 'error: missing required config %s\n' "${key}" >&2
      exit 1
    }
  done

  return 0
}

#######################################
# Print the effective config to stderr (call it from log_debug).
# Globals:
#   CONFIG (read)
# Arguments:
#   None
#######################################
config::dump() {
  local key

  for key in "${!CONFIG[@]}"; do
    printf 'config: %s=%s\n' "${key}" "${CONFIG[${key}]}" >&2
  done

  return 0
}

#######################################
# Load the full four-layer config: defaults < file < env < CLI args.
# Runs a bootstrap env+args pass first so --config-file / CONFIG_FILE
# from the environment are known before the file layer is read.
# Globals:
#   CONFIG_DEFAULTS, CONFIG_FLAGS, CONFIG_OPTS, CONFIG_VALIDATORS,
#   CONFIG_PREFIX (read)
#   CONFIG (written)
# Arguments:
#   $@ - CLI arguments. Needs the caller's usage() for --help.
#######################################
config::load() {
  local key
  for key in "${!CONFIG_DEFAULTS[@]}"; do
    CONFIG["${key}"]="${CONFIG_DEFAULTS[${key}]}"
  done

  config::__build_alias_map
  # Bootstrap CONFIG_FILE/CONFIG_PREFIX from env and CLI first; every pass
  # only overwrites keys it knows, so passes accumulate in precedence order:
  # defaults < file < env < args.
  config::__load_env
  config::__parse_args "$@"
  config::__load_file
  config::__load_env
  config::__parse_args "$@"
  config::validate

  return 0
}
```

## Notes

- Every function ends with an explicit `return 0` (see
  `references/bash-strict-mode.md`): under `set -e`, a function whose last
  statement is a loop/conditional returning non-zero would otherwise kill
  the caller with no message. This exact bug was found and fixed while
  porting — the test suite covers it.
- `[[ ${value} =~ ${pattern} ]]` keeps the regex **unquoted** on purpose;
  quoting it would match literally (shellcheck SC2076).
- `value="${!key:-}"` is indirect expansion with a default — safe under
  `set -u`, no `eval` needed.
- Tested with 28 assertions covering every layer, precedence order,
  all CLI forms, `--` end-of-options, validators, missing files, and
  unknown arguments.
- `CONFIG__ALIASES` is declared (and re-declared on every rebuild) with
  `declare -gA`: the `-g` keeps it global even if the file is sourced
  inside a function, and re-declaring in `config::__build_alias_map`
  restores the `-A` attribute if the caller ever unset it (a bare `()`
  reset would silently make it indexed and break stores under `set -u`).
- Linting this file standalone reports SC2154 for `CONFIG_FLAGS`,
  `CONFIG_OPTS`, `CONFIG_VALIDATORS` — expected: those are the caller's
  schema, assigned in the consuming script. Lint the consumer with
  `shellcheck -x` (as `scripts/lint.sh` does) and the warnings resolve via
  `source` following.

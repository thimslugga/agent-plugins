# Patterns

Copy-ready solutions for recurring tasks, written in the Google shell style:
2 space indent, braced variables, `(( ))` for numbers, arrays for lists.

## Argument parsing

`getopts` is the built-in option. It handles short flags, bundling (`-vf`),
and option arguments, but it cannot do long options:

```bash
verbose='false'
config=''
while getopts ':hvf:' flag; do
  case "${flag}" in
    h) usage; exit 0 ;;
    v) verbose='true' ;;
    f) config="${OPTARG}" ;;
    :) die_usage "option -${OPTARG} needs an argument" ;;
    *) die_usage "unknown option: -${OPTARG}" ;;
  esac
done
shift $((OPTIND - 1))
```

The manual loop in `assets/template.sh` handles long options. To also accept
`--config=path`:

```bash
--config=*)
  config="${1#*=}"
  shift
  ;;
--config)
  if (( $# < 2 )); then
    die_usage '--config needs a value'
  fi
  config="$2"
  shift 2
  ;;
```

## Reading input

Line by line, keeping whitespace and the final line when it has no newline:

```bash
while IFS= read -r line || [[ -n "${line}" ]]; do
  printf 'line: %s\n' "${line}"
done < "${input_file}"
```

Whole file into an array:

```bash
readarray -t lines < "${input_file}"
```

Never `for line in $(cat file)`. That splits on every space and expands globs.

## Capturing command output into a loop

Piping into `while` puts the loop in a subshell, so anything it sets is lost.
Use process substitution or `readarray`:

```bash
local last=''
while IFS= read -r line; do
  last="${line}"
done < <(some_command)
printf 'last: %s\n' "${last}"

# Or, with the input generation written before the loop:
readarray -t lines < <(some_command)
```

## Iterating over files

```bash
while IFS= read -r -d '' file; do
  process "${file}"
done < <(find /var/log -type f -name '*.log' -print0)
```

When the action is a single command, skip the loop:

```bash
find /var/log -type f -name '*.log' -mtime +30 -print0 \
  | xargs -0 -r rm -f --
```

`-r` stops `xargs` running the command with no input. It is GNU-specific; BSD
`xargs` already behaves that way.

## Running work in parallel

```bash
find . -name '*.jpg' -print0 | xargs -0 -P 4 -n 1 -- ./convert_one.sh
```

Four at a time, one file per invocation. `xargs` returns non-zero if any
invocation failed. Anything more complex than this belongs in Python.

## Only one copy at a time

Cron jobs overlap when a run outlasts the interval. `flock` fixes it:

```bash
exec 9> /var/lock/myjob.lock
if ! flock -n 9; then
  echo 'already running' >&2
  exit 0
fi
# Work here. The lock releases when the script exits.
```

Or wrap it in the crontab entry:
`flock -n /var/lock/myjob.lock /usr/local/bin/myjob.sh`.

## Retry with backoff

```bash
#######################################
# Run a command until it succeeds, backing off between attempts.
# Arguments:
#   Attempt limit, initial delay in seconds, then the command.
# Returns:
#   0 on success, 1 when the attempts are exhausted.
#######################################
retry() {
  local attempts="$1"
  local delay="$2"
  shift 2

  local n=1
  until "$@"; do
    if (( n >= attempts )); then
      warn "giving up on: $* (after ${n} attempts)"
      return 1
    fi
    warn "attempt ${n} failed, retrying in ${delay}s"
    sleep "${delay}"
    n=$((n + 1))
    delay=$((delay * 2))
  done
}

retry 5 2 curl -fsS --max-time 10 -o out.json https://api.example.com/status
```

`curl` needs `-f` to treat HTTP 500 as a failure. Without it, curl exits 0 and
writes the error page into the output file.

## Timeouts

```bash
rc=0
timeout 30s slow_command || rc=$?
if (( rc == 124 )); then
  die 'slow_command timed out'
elif (( rc != 0 )); then
  die "slow_command failed with ${rc}"
fi
```

Exit code 124 means the timeout fired. Add `-k 10s` to send SIGKILL when the
process ignores SIGTERM.

Capture the status with `|| rc=$?` rather than inside `if ! cmd; then`. The
`!` inverts the status, so `$?` is 0 in the branch that handles the failure.

## Temp files and directories

```bash
tmp_dir="$(mktemp -d)"
tmp_file="$(mktemp)"
trap 'rm -rf -- "${tmp_dir}" "${tmp_file}"' EXIT
```

Use `mktemp -d -t myapp.XXXXXX` when the name should be recognisable in
`/tmp`. The `X` characters are required and get replaced with random ones.

## Output that behaves in a pipe

```bash
if [[ -t 1 ]]; then
  readonly C_RED=$'\033[0;31m'
  readonly C_GREEN=$'\033[0;32m'
  readonly C_OFF=$'\033[0m'
else
  readonly C_RED=''
  readonly C_GREEN=''
  readonly C_OFF=''
fi

printf '%sok%s\n' "${C_GREEN}" "${C_OFF}"
```

The `[[ -t 1 ]]` test makes the escape codes disappear when output goes to a
file, a pipe, or a CI log. Honour `NO_COLOR` as well in user-facing tools.

## Confirmation prompts

```bash
confirm() {
  local reply
  read -rp "$1 [y/N] " reply || return 1
  [[ "${reply}" =~ ^[Yy]([Ee][Ss])?$ ]]
}

if [[ ! -t 0 ]]; then
  die 'refusing to prompt without a terminal, pass --yes'
fi
if ! confirm "Delete ${target}?"; then
  die 'aborted'
fi
```

Without the terminal check, the script hangs forever under cron.

## Configuration

Sourcing a config file executes it. Acceptable for a file the script owns,
dangerous for anything written by a user or another system. For simple
key and value files, parse with an allowlist:

```bash
while IFS='=' read -r key value; do
  case "${key}" in
    '' | \#*) continue ;;
    retries) retries="${value}" ;;
    endpoint) endpoint="${value}" ;;
    *) warn "ignoring unknown key: ${key}" ;;
  esac
done < "${config_file}"
```

An allowlist means a hostile config cannot set `PATH` or `LD_PRELOAD`. See
`references/security.md`.

## JSON

```bash
require_cmd jq
local version
version="$(jq -re '.version' < response.json)"
```

`-r` strips the quotes; `-e` makes `jq` exit non-zero when the result is null
or missing, which turns an absent field into a caught error rather than the
literal string `null`.

A second or third `jq` call, or building JSON by string concatenation, is the
signal to move to Python.

## Strings without sed

Parameter expansion is a builtin, so it is faster and has no quoting
surprises:

```bash
path='/var/log/app/service.log'
printf '%s\n' "${path##*/}"        # service.log   (basename)
printf '%s\n' "${path%/*}"         # /var/log/app  (dirname)
printf '%s\n' "${path%.log}"       # strip suffix
printf '%s\n' "${name:-anon}"      # default when empty or unset
printf '%s\n' "${name:?required}"  # abort with a message when empty
name="${name// /_}"                # replace every space
```

Extraction with the regex operator instead of a `sed` pipe:

```bash
if [[ "${line}" =~ ^version:[[:space:]]*([0-9.]+) ]]; then
  version="${BASH_REMATCH[1]}"
fi
```

## Here-documents

```bash
# Quoted delimiter: nothing expands.
cat <<'EOF' > /etc/myapp/config
password=$NOT_EXPANDED
EOF

# Unquoted delimiter: variables expand.
cat <<EOF > /etc/myapp/config
host=${HOSTNAME}
EOF
```

`<<-EOF` allows leading tabs for indentation, and is the one place the style
guide permits a tab.

## Associative arrays

```bash
declare -A limits=([cpu]=2 [memory]=4096)
local key
for key in "${!limits[@]}"; do
  printf '%s=%s\n' "${key}" "${limits[${key}]}"
done
```

Iteration order is unspecified, so sort the keys when order matters. Not
available on macOS system bash 3.2.

## Idempotency

Automation gets re-run, so design for it:

```bash
mkdir -p "${dir}"
grep -qxF "${line}" "${file}" || printf '%s\n' "${line}" >> "${file}"
[[ -L "${link}" ]] || ln -s -- "${target}" "${link}"
systemctl is-active --quiet myapp || systemctl start myapp
```

## Making a script testable

The style guide requires `main "$@"` as the last line, which means sourcing
the file runs it. When a test harness needs to source the functions, keep the
final line and give the harness an explicit opt-out instead:

```bash
main() {
  if [[ "${SOURCED_FOR_TEST:-}" == 'true' ]]; then
    return 0
  fi
  ...
}

main "$@"
```

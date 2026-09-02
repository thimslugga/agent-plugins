# Bash Script Strict mode

`set -Eeuo pipefail` raises the floor. It does not catch errors, it aborts on
some of them. The gap between "some" and "all" is where the bugs live.

The Google style guide requires that shell options be set with `set` rather
than in the shebang, so that running the file as `bash script.sh` behaves
identically. It does not mandate which options; this skill uses all four.

## What each flag does

| Flag          | Effect                                                                         |
| ------------- | ------------------------------------------------------------------------------ |
| `-e`          | Exit when a command fails, subject to the exemptions below                     |
| `-u`          | Treat an unset variable as an error                                            |
| `-o pipefail` | A pipeline fails if any stage fails, not just the last                         |
| `-E`          | Let the `ERR` trap fire inside functions, subshells, and command substitutions |

Without `-E`, an `ERR` trap set at the top of the file stays silent for
failures inside functions, which is where most real work happens.

## Where `set -e` refuses to fire

**1. Anything in a condition.** `set -e` is suspended for the whole tested
command:

```bash
if risky_thing; then :; fi     # failure ignored, by design
risky_thing && echo 'ok'       # failure ignored
risky_thing || echo 'fallback' # failure ignored
! risky_thing                  # failure ignored
```

That is intended behaviour and mostly useful. The trap is that it extends into
functions:

```bash
deploy() {
  build   # fails
  push    # STILL RUNS
}

if deploy; then echo 'shipped'; fi   # prints "shipped"
```

Calling a function from a condition disables `set -e` for every command inside
it. Check the exit code after the call instead of wrapping the call in `if`.

**2. Every stage of a pipeline except the last**, unless `pipefail` is set.

**3. Command substitution behind a declaration builtin.** The builtin's own
exit status is what gets reported:

```bash
local version="$(get_version)"   # get_version failing is invisible
```

Split the declaration from the assignment, which the style guide requires for
exactly this reason:

```bash
local version
version="$(get_version)"         # now set -e sees the failure
```

The same applies to `declare`, `export`, and `readonly`. ShellCheck flags it
as SC2155: <https://github.com/koalaman/shellcheck/wiki/SC2155>

**4. Arithmetic that evaluates to zero.** `(( ))` returns 1 when the result
is 0, which the style guide calls out explicitly:

```bash
count=0
(( count++ ))   # returns 1, script exits
```

Write `count=$((count + 1))`, or use `(( count += 1 ))`, or append
`|| true`.

**5. `read` at end of file.** `read var < file` returns 1 on the final line
when that line has no trailing newline.

## `$?` after a negated command

```bash
if ! timeout 30s slow_command; then
  rc=$?          # always 0: the "!" already inverted the status
fi
```

Capture the status first, then branch on it:

```bash
rc=0
timeout 30s slow_command || rc=$?
if (( rc == 124 )); then
  die 'timed out'
fi
```

## The pipefail plus head problem

```bash
set -o pipefail
grep pattern huge.log | head -1     # exits 141, script dies
```

`head` closes the pipe after one line, `grep` takes SIGPIPE, and `pipefail`
reports 141. Remove the need for the pipe (`grep -m1 pattern huge.log`), or
absorb the status with `|| true` when an empty result is acceptable.

## Checking a whole pipeline

`PIPESTATUS` holds the status of each stage, and any command overwrites it,
including `[`:

```bash
tar -cf - ./* | (cd "${dir}" && tar -xf -)
return_codes=("${PIPESTATUS[@]}")
if (( return_codes[0] != 0 )); then
  die 'tar read failed'
fi
```

## `IFS=$'\n\t'` is not a safety feature

It appears in many templates. It changes word splitting globally and is
inherited by everything downstream, which breaks ordinary code in surprising
places:

```bash
IFS=$'\n\t'
args='--verbose --dry-run'
cmd ${args}            # now one argument: "--verbose --dry-run"
```

Quoting and arrays solve the problem this setting claims to solve, without the
side effects. Set `IFS` narrowly, on the command that needs it:

```bash
while IFS=: read -r user _ uid _; do
  printf '%s %s\n' "${user}" "${uid}"
done < /etc/passwd
```

## `set -u` and empty arrays

On bash older than 4.4, expanding an empty array under `set -u` is an error:

```bash
items=()
printf '%s\n' "${items[@]}"     # bash 3.2 and 4.x: unbound variable
printf '%s\n' "${items[@]:-}"   # safe everywhere
```

macOS ships bash 3.2, so this matters for any script that leaves the Linux
fleet. Guard with `(( ${#items[@]} > 0 ))` before looping.

## Deliberate opt-outs

```bash
optional_step || true    # failure is acceptable here

set +e                   # suspend for a block
run_batch_that_partially_fails
rc=$?
set -e
```

Add a comment saying why. An unexplained `|| true` reads as a bug being
hidden.

## The position to argue

Strict mode belongs at the top of every script, and it is not error handling.
Handle the failures that matter explicitly: check the exit code, log what
failed, clean up, and exit with a meaningful status. Let strict mode catch the
ones nobody thought about.

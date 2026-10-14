# Google's shell script style guide (condensed)

Full guide: <https://google.github.io/styleguide/shellguide.html>

## When to use shell scripts

- Shell scripts are for small glue: short, linear, mostly calling other commands.
- Rewrite in a structured language (Python, Go, …) when the script grows past ~100 lines, needs non-trivial control flow, complex data structures, or heavy string manipulation. "I'll rewrite it later" never happens — rewrite now.
- The skill still applies its standard to whatever shell remains; it does not bless a 500-line bash script.

## File layout

- Executables: `#!/usr/bin/env bash`, no extension preferred (or `.sh` if a build rule renames the file). SUID/SGID forbidden.
- Libraries: must end in `.sh`, must not be executable.
- Order: shebang,`set` options, file header comment (what the file does), `source` includes, constants, functions, `main "$@"` last.
- `set -euo pipefail` near the top. Use `set` (not shebang flags) so `bash script` invocation keeps working.

## Portability

- Default to bash (`#!/usr/bin/env bash` — `env` because bash isn't always at `/bin/bash`). Target POSIX `sh` only when the environment demands it, and say so up front.
- Don't assume GNU coreutils: `date`, `sed`, `grep`, `stat` differ on macOS/BSD. Prefer bash builtins (parameter expansion, `[[ ]]`, `(( ))`, `printf`) — they behave identically everywhere.
- Avoid locale surprises when parsing: `LC_ALL=C` around `sort`/`grep` where byte order matters.
- Never rely on the caller's environment: initialize every variable you read (`set -u` enforces this); don't depend on aliases or shell options set elsewhere.
- Test POSIX targets with `shellcheck -s sh` / `shfmt -ln=posix`; fix every bashism they report or justify it.

## Formatting

- 2-space indent, no tabs (shfmt `-i 2` enforces this).
- Max 80 columns; break long strings with heredocs or `\` continuations.
- Pipelines: one segment per line with the pipe leading, 2-space indent (`shfmt -bn`).
- `; then` / `; do` on the same line as `if`/`for`/`while`; `else`, `fi`, `done` on their own lines.
- `case` branches indented 2 spaces (`shfmt -ci`); one-line branch: `a) x='true' ;;`.

## Constants, variables and quoting

- Constants and exported vars: `UPPER_SNAKE`, `readonly`, declared at the top. OK to compute then `readonly` immediately after.
- Always quote expansions: `"${var}"`, `"$(cmd)"`, `"${arr[@]}"`, `"$@"`. Braces are not quoting — use double quotes too.
- Exception: inside `[[ ]]` and `(( ))` word splitting and globbing don't happen, so quotes are redundant — `shfmt -s` strips them and the standard accepts that: `[[ -n ${var} ]]`, `((i += 1))`. Quote everywhere else.
- Prefer `"${var}"` over `"$var"`; never leave `$1`-style positionals unbraced past `$9` (`${10}`).
- Loop variables should mirror the plural they iterate: `for zone in "${zones[@]}"; do`.
- Function variables: `local`, lowercase. Declare and assign **separately** when the value comes from a command substitution (`local` masks the exit code):

  ```bash
  local output
  output="$(generate)" || return
  ```

## Functions

- Functions below constants and all should be together. No executable code between function definitions.
- Never name a function after a shell built-in, such as test, help, echo, read, wait, cd, or type.
- Non-trivial or library functions get a header comment: description, `Globals:`, `Arguments:`, `Outputs:`, `Returns:`.
- Scripts long enough for one extra function need a `main`; the last non-comment line is `main "$@"`. Short linear scripts skip it.
- Check return values (`if ! cmd; then ...` / `$?` / `PIPESTATUS`); give informative errors on stderr and non-zero exits.
- No `eval`. No aliases in scripts — use functions.
- Options: `getopts` with a `usage()` function.

## Arrays and loops

- Arrays for lists, especially argument lists: `flags=(--foo --bar='baz'); mybinary "${flags[@]}"`.
- Never parse `ls`; never `for x in $(...)`. Use `while IFS= read -r` with process substitution or `readarray -t`:

  ```bash
  while IFS= read -r line; do ...; done < <(your_command)
  ```

- Avoid piping into `while` — the loop runs in a subshell and variable changes are lost.
- Wildcard expansions of filenames: use `./*`, not `*` (filenames can start with `-`).

## Tests, expansion, arithmetic

- `[[ ... ]]` over `[ ... ]` / `test`. `==` for string equality; `-z`/`-n` for emptiness (no filler-character tricks).
- `(( ... ))` / `$(( ... ))` for arithmetic; never `let`, `$[ ]`, or `expr`. Inside `(( ))`, omit `$`: `((i += 3))`.
- `$(command)` over backticks. `printf` over `echo` for anything formatted; errors go to stderr (`>&2`).
- Parameter expansion builtins over subprocesses: `${var#/prefix}`, `${var%.suffix}`, `${var//from/to}`, `${#var}`.

## Error handling

- `set -euo pipefail` at the top of every executable. It's a backstop, not a strategy — check return values explicitly: `if ! cmd; then log_error "..."; return 1; fi`.
- `cd` with a guard, always: `cd "${dir}" || { log_error "cannot cd to '${dir}'"; exit 1; }`.
- Guard destructive commands against empty variables: `rm -rf "${dir:?}/"`.
- Clean up temp artifacts with `trap`: `TMP_DIR="$(mktemp -d)"; trap cleanup EXIT`. Prefer a `cleanup()` function over inline trap strings (quoting inside traps is fragile).
- Validate inputs early (fail fast): argument counts, required commands via `command -v`, preconditions before doing work.
- Meaningful exit codes: 0 success, 1 general error, 2 usage error.
- ERR trap for the failures you didn't handle explicitly: install `trap '__on_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR` in `main()` (needs `set -o errtrace`; see `references/bash-strict-mode.md`). The handler stays quiet for subshell frames (`BASH_SUBSHELL > 0`, single report from the parent) and for a bare `return` (main's deliberate exit status), and fatals everything else with line number, command, and status.
- Invoke `main` bare as the script's last line. Wrapping it (`main "$@" || exit "$?"`, `if main ...`) puts `main` in a condition context and silently disables `set -e` and the ERR trap for the whole function.
- Never swallow errors: no `cmd || true` without a comment explaining why failure is acceptable.

## Logging

- Levels: `INFO`, `WARN`, `ERROR`, `DEBUG`. Errors and diagnostics go to **stderr**; **stdout** is reserved for the script's real output (data other tools consume).
- Timestamp every line: `[2026-09-29T08:30:00-0400] ERROR message`.
- `DEBUG` gated behind a flag (`VERBOSE=true` / `-v`), off by default.
- `FATAL`: log the message, print a backtrace when verbose, kill leftover background jobs, exit with the status (`log_fatal --status=N msg`).
- Colors on stderr only when it's a terminal (`-t 2`); `COLOR=false` disables. `QUIET=true` silences `INFO`.
- One line per event; include what failed and the relevant values: `log_error "cannot read '${file}': permission denied"`.
- The `scripts/init-script.sh` template ships a `log` / `log_info` / `log_warn` / `log_error` / `log_debug` family — use it instead of bare `echo` for diagnostics.

## Bash Pit falls (mywiki.wooledge.org/BashPitfalls)

Top Bash pit falls:

1. Unquoted variables: `rm -rf $dir` with empty/unset `$dir` is catastrophic. Quote everything.
2. `for i in $(cat file)` / `for f in $(ls)` — word splitting; use `while read`.
3. `[ $var = "x" ]` unquoted, or `[ ... == ... ]` — use `[[ ${var} == x ]]`.
4. `cd somewhere` without `|| exit` — the rest of the script then runs in the wrong directory.
5. `cmd1 | while read` — subshell swallows variable assignments.
6. `$*` instead of `"$@"` — mangles arguments with spaces.
7. `export FOO=bar` masking failure, or `local x=$(false)` masking failure — split declaration and assignment.
8. Assuming `((i++))` is safe under `set -e` — it exits when the result is 0; use `((++i))` or `((i += 1))`.
9. `echo` with flags or escapes — use `printf '%s\n'`.
10. Globbing when you meant a literal string — quote it.

When in doubt: <https://mywiki.wooledge.org/BashFAQ> and <http://tldp.org/LDP/abs/html/>.

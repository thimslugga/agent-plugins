# Google's shell script style guide (condensed)

Full guide: <https://google.github.io/styleguide/shellguide.html>

## When to use shell scripts

- Google: shell is for small utilities and wrapper scripts that mostly call other commands. Past ~100 lines, with non-trivial control flow, complex data structures, or heavy string manipulation, Google says to rewrite in a structured language (Python, Go, …), and to do it early because scripts grow.
- This skill treats that as **advisory, not a blocker**: some environments leave shell as the only option. When a script is heading past that point, tell the user once, briefly, and then write the best shell you can to the standard below. Do not refuse or silently swap languages.

## File layout

- Executables: `#!/usr/bin/env bash`, no extension preferred (or `.sh` if a build rule renames the file). SUID/SGID forbidden.
- Libraries: must end in `.sh`, must not be executable.
- Order: shebang, `set` options, file header comment, `source` includes, constants, functions, `main "$@"` last. Every file starts with a top-level comment describing its contents (copyright and author lines are optional).
- A script with at least one function besides `main` must have a `main`; put it as the bottom-most function, and make the last non-comment line `main "$@"`. Short linear scripts skip it.
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

Google Shell Style Guide, "Variable Names", "Constants, Environment Variables, and readonly Variables", "Use Local Variables" and "Variable expansion":

- **Variable names:** same as function names: lowercase `snake_case`. This covers function locals and mutable script-wide state (`verbose`, `dry_run`, `copied_files`). Loop variables mirror the plural they iterate: `for zone in "${zones[@]}"; do`.
- **Constants, `readonly` and exported variables:** `UPPER_SNAKE`, declared at the top of the file. A script-wide variable that is never reassigned is a constant. Mutable state is not: keep it lowercase even when it is seeded from an environment variable (`verbose="${VERBOSE:-false}"`).
- Use `readonly` and `export` rather than `declare -xr`; to do both, one after the other: `readonly NAME='x'` then `export NAME`.
- A constant may be set at runtime or in a conditional, but make it `readonly` immediately afterwards:

  ```bash
  ZIP_VERSION="$(dpkg --status zip | sed -n 's/^Version: //p')"
  if [[ -z ${ZIP_VERSION} ]]; then
    handle_error_and_quit
  fi
  readonly ZIP_VERSION
  ```

- **Local variables:** declare every function-specific variable with `local` so it is visible only inside the function and its children and cannot clobber a global. Declaration and assignment must be separate statements when the value comes from a command substitution, because `local` returns its own exit status, not the substitution's:

  ```bash
  local name="$1"  # fine: no command substitution
  local output     # declare first...
  output="$(generate)" || return  # ...then assign and check
  ```

  Never write `local output="$(generate)"`.
- **Variable expansion**, in order of precedence: stay consistent with the surrounding code; quote variables; prefer `"${var}"` over `"$var"`.
  - Brace-delimit every named variable: `"${PATH}"`, `"${some_var}"`.
  - Do not brace single-character specials and positionals (`$1`, `$?`, `$#`, `$@`, `$$`, `$!`, `$-`) unless needed: `${10}` and above, or to avoid confusion such as `"${1}0${2}0"`. Write `"$1"`, not `"${1}"`.
  - Braces are not quoting; add double quotes as well.
- Always quote expansions: `"${var}"`, `"$(cmd)"`, `"${arr[@]}"`, `"$@"` (use `$*` only when joining into a message). Optionally quote the integer specials `$?`, `$#`, `$$`, `$!`; do quote named ones such as `PPID`.
- Exception: inside `[[ ]]` and `(( ))` word splitting and globbing don't happen, so quotes are redundant. `shfmt -s` strips them and the standard accepts that: `[[ -n ${var} ]]`, `((i += 1))`. Quote everywhere else.

## Functions

- Functions below constants and all should be together. No executable code between function definitions.
- Never name a function after a shell built-in, such as test, help, echo, read, wait, cd, or type.
- Non-trivial or library functions get a header comment: description, `Globals:`, `Arguments:`, `Outputs:`, `Returns:`.
- Scripts long enough for one extra function need a `main`; the last non-comment line is `main "$@"`. Short linear scripts skip it.
- Check return values (`if ! cmd; then ...` / `$?` / `PIPESTATUS`); give informative errors on stderr and non-zero exits.
- No `eval`. No aliases in scripts — use functions.
- Options: `getopts` with a `usage()` function.

## Function design

- **One job per function** (Single Responsibility). A function does one specific thing; if it needs "and" in its description or you struggle to give it a short, clear verb-first name, split it. Parse options, validate input, do the work, and report in separate functions, with `main` as the thin coordinator.
- **Separate output from status.** Data goes out on stdout (`printf '%s\n' "${value}"`, captured with `$( )`); success or failure goes out through `return` (an integer 0-255, read as `$?`). Never smuggle a string through `return`, and never signal failure by printing a magic string. Diagnostics go to stderr, never stdout.
- **Scope every variable with `local`** (declared separately from command-substitution assignment). An undeclared assignment inside a function leaks into the global scope and silently couples functions together. Only constants and intentional script-wide settings are global.
- **Portable output:** prefer `printf '%s\n'` to `echo` for variable data (`echo` mishandles `-n`, `-e`, and backslashes differently across shells); `echo` is fine for fixed text. POSIX sh has no `local`: see `references/portable-shell.md` for the substitute.

```bash
# Data on stdout, status via return: the caller composes the two.
find_config() {
  local dir="$1"
  local candidate="${dir}/app.conf"

  [[ -r ${candidate} ]] || return 1
  printf '%s\n' "${candidate}"
}

if config="$(find_config "${HOME}")"; then
  load_config "${config}"
else
  warn 'no config found, using defaults'
fi
```

## Arrays and loops

- Arrays for lists, especially argument lists: `flags=(--foo --bar='baz'); mybinary "${flags[@]}"`.
- Never parse `ls`; never `for x in $(...)`. Use `while IFS= read -r` with process substitution or `readarray -t`:

  ```bash
  while IFS= read -r line; do ...; done < <(your_command)
  ```

- Avoid piping into `while` — the loop runs in a subshell and variable changes are lost.
- Wildcard expansions of filenames: use `./*`, not `*` (filenames can start with `-`).
- Always write `for arg in "$@"; do`, never the bare `for arg; do`.
- Inside a function, declare the loop variable `local` before the loop so it cannot leak into the global scope.
- `case`: indent alternatives 2 spaces; patterns have no opening parenthesis (`a)` not `(a)`); a one-line alternative has a space after `)` and before `;;`; avoid `;&` and `;;&`; no need to quote match expressions. Put long or multi-command alternatives on separate lines.
- Arrays hold lists, not complex data structures; keep a constant list `readonly` (`readonly FLAGS=(--foo --bar)`).
- `TODO` comments: `# TODO(username): what and why` with the person with the most context, not a bare `TODO:`.

## Tests, expansion, arithmetic

- `[[ ... ]]` over `[ ... ]` / `test`. `==` for string equality; `-z`/`-n` for emptiness (no filler-character tricks).
- `(( ... ))` / `$(( ... ))` for arithmetic and numeric comparison (`(( $# == 0 ))`, not `[[ $# -eq 0 ]]`, and never `[[ $a > $b ]]`, which compares lexicographically); never `let`, `$[ ]`, or `expr`. Inside `(( ))`, omit `$`: `((i += 3))`.
- Avoid `(( ))` as a standalone statement under `set -e`: if the expression evaluates to 0 it returns failure (`i=0; (( i++ ))` exits the script). Use `i=$((i + 1))`, `((++i))`, or test it in an `if`.
- Declare integers with `local -i` / `declare -i` when possible.
- `$(command)` over backticks. `printf` over `echo` for anything formatted; errors go to stderr (`>&2`).
- Parameter expansion builtins over subprocesses: `${var#/prefix}`, `${var%.suffix}`, `${var//from/to}`, `${#var}`, and `${path##*/}` / `${path%/*}` instead of `basename` / `dirname` (note `${path%/*}` returns `path` unchanged when it has no slash).

## Error handling

- `set -euo pipefail` at the top of every executable. It's a backstop, not a strategy — check return values explicitly: `if ! cmd; then err "..."; return 1; fi`.
- `cd` with a guard, always: `cd "${dir}" || { err "cannot cd to '${dir}'"; exit 1; }`.
- Guard destructive commands against empty variables: `rm -rf "${dir:?}/"`.
- Clean up temp artifacts with `trap`: `tmp_dir="$(mktemp -d)"; trap cleanup EXIT`. Prefer a `cleanup()` function over inline trap strings (quoting inside traps is fragile).
- Validate inputs early (fail fast): argument counts, required commands via `command -v`, preconditions before doing work.
- Meaningful exit codes: 0 success, 1 general error, 2 usage error.
- ERR trap for the failures you didn't handle explicitly: install `trap '__on_error "$?" "${LINENO}" "${BASH_COMMAND}"' ERR` in `main()` (needs `set -o errtrace`; see `references/bash-strict-mode.md`). The handler stays quiet for subshell frames (`BASH_SUBSHELL > 0`, single report from the parent) and for a bare `return` (main's deliberate exit status), and fatals everything else with line number, command, and status.
- Invoke `main` bare as the script's last line. Wrapping it (`main "$@" || exit "$?"`, `if main ...`) puts `main` in a condition context and silently disables `set -e` and the ERR trap for the whole function.
- Never swallow errors: no `cmd || true` without a comment explaining why failure is acceptable.

## Logging

- Levels: `INFO`, `WARN`, `ERROR`, `DEBUG`. Errors and diagnostics go to **stderr**; **stdout** is reserved for the script's real output (data other tools consume).
- Timestamp every line: `[2026-09-29T08:30:00-0400] ERROR message`.
- `DEBUG` gated behind a flag (`VERBOSE=true` / `-v`), off by default. `QUIET=true` silences `INFO`.
- Fatal errors: `die [--status=N] message` logs at ERROR level and exits (default status 1). Cleanup of temp files and leftover background jobs belongs in the `EXIT` trap, not in `die`.
- Colors only when stderr is a terminal (`-t 2`) and `NO_COLOR` is unset (<https://no-color.org>). Decide once at startup and leave the escape variables empty otherwise, so the logger needs no per-call branching. Color the level tag only.
- One line per event; include what failed and the relevant values: `err "cannot read '${file}': permission denied"`.
- The logger family is `info` / `warn` / `err` / `debug` / `die` (Google's `err` plus the other levels); `scripts/init-script.sh` ships it. Use it instead of bare `echo` for diagnostics.

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

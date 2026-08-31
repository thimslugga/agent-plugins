# Review checklist

Work down this list in order and report findings in the same order. Data loss
first, cosmetics last. Run `scripts/check.sh` before starting: shellcheck and
shfmt already cover most of P2 and P3, which leaves more attention for P0 and
P1, the two the tools cannot judge.

## P0: could destroy data or systems

- [ ] `rm -rf "$var/..."` where `$var` could be empty or unset. Require `rm -rf -- "${var:?var is unset}"`.
- [ ] Wildcards expanded without a path: `rm -v *` rather than `rm -v ./*`. A
  file named `-r` or `-f` becomes a flag.
- [ ] SUID or SGID set on the script. Forbidden outright. Use `sudo` with a
  narrow sudoers rule.
- [ ] `rm`, `mv`, `chmod -R`, `chown -R` on a path built from user input, an
  environment variable, or a command substitution that can fail.
- [ ] `cd "$dir"` without checking it succeeded, followed by anything
  destructive. A failed `cd` leaves the script in the wrong directory.
- [ ] `>` truncating a file before the new content is known good. Write to a
  temp file and `mv` into place, which is also atomic.
- [ ] Missing `--` before user-supplied paths.
- [ ] `curl ... | bash` or `curl ... | sudo bash`. Download, checksum,
  inspect, then run.
- [ ] `sudo` inside the script rather than requiring the caller to hold
  privileges. It hides how much power the script needs.
- [ ] Destructive default with no `--dry-run` and no confirmation.
- [ ] `find ... -delete` or `-exec rm` where the predicate could match more
  than intended. Ask for the output of the same `find` without the delete.
- [ ] `kill $(pgrep ...)` patterns that can match the script itself or an
  unrelated process.

## P1: injection and quoting

Untrusted input is anything from a form, header, cookie, filename, webhook,
environment variable, or CI variable. Details in `references/security.md`.

- [ ] Unquoted variable expansions. This is the top finding in almost every
  review.
- [ ] User input interpolated into a command string that a shell re-parses:
  `eval`, `sh -c "..."`, `ssh host "..."`. Pass values as separate arguments
  instead.
- [ ] Input validated by banning bad characters rather than allowing good
  ones. An allowlist regex or a `case` is the stronger control.
- [ ] `PATH` inherited from the caller in a privileged script, or binaries
  invoked by bare name where the caller controls the environment.
- [ ] Configuration paths taken from environment variables without
  validation.
- [ ] `source` of a file the script does not own. Sourcing runs code.
- [ ] Filenames handled through `ls` output, or through `for f in $(find ...)`.
- [ ] Word splitting relied on without a narrowly scoped `IFS`, or a list of
  flags held in a string rather than an array.
- [ ] Secrets passed as command-line arguments, where any user can read them
  from `ps`. Use an environment variable, a `0600` file, or stdin.
- [ ] Secrets hard-coded in the script or exposed by `set -x`. Disable tracing
  around the sensitive lines.
- [ ] Temp files with predictable names, which allows a symlink attack. Use
  `mktemp`.
- [ ] Checking a file then acting on it, when something can change in
  between. Prefer atomic operations over test-then-act.

## P2: error handling

- [ ] No `set` line establishing shell options at the top.
- [ ] `local var="$(cmd)"` masking the exit status. See `strict-mode.md`.
- [ ] Functions invoked from `if` or `&&` where the author expected `set -e`
  to protect the body.
- [ ] `rc=$?` read inside `if ! cmd; then`, where it is always 0.
- [ ] `PIPESTATUS` read after another command has already overwritten it.
- [ ] `mktemp` results not registered with a `trap ... EXIT`.
- [ ] Exit codes ignored after commands that matter, particularly `curl`
  without `-f`.
- [ ] Every failure exiting 1, with no distinction between usage errors and
  runtime failures.
- [ ] Errors and progress printed to stdout, which corrupts the script's real
  output and floods cron mail.
- [ ] No cleanup on interrupt: `trap` for `INT` and `TERM` missing.
- [ ] Not idempotent, in a script that cron or a deploy will re-run.

## P3: style guide compliance

Full rules in `references/google-style.md`.

- [ ] Not `#!/bin/bash`, without a stated reason.
- [ ] Indentation other than 2 spaces, or tabs outside a `<<-` here-document.
- [ ] Lines over 80 characters.
- [ ] `$var` instead of `"${var}"` for anything but positional parameters.
- [ ] `[ ... ]` or `test` instead of `[[ ... ]]`; `=` instead of `==`.
- [ ] Numeric comparison inside `[[ ]]` rather than `(( ))`.
- [ ] `eval`, `let`, `expr`, `$[ ... ]`, backticks, or aliases.
- [ ] Piping into `while` instead of process substitution or `readarray`.
- [ ] No file header comment; no header comments on non-obvious functions.
- [ ] Executable code between function definitions, or no `main` in a script
  that has other functions, or `main "$@"` not on the last line.
- [ ] Constants not uppercase and `readonly`, or locals not declared `local`.
- [ ] Library file marked executable, or missing its `.sh` extension.

## P4: portability and maintainability

- [ ] Bashisms under a `#!/bin/sh` shebang.
- [ ] GNU-only flags in a script that may run on macOS. See
  `portability.md`.
- [ ] Bash 4 features in a script that may meet macOS bash 3.2, with no
  version gate.
- [ ] External tools used without `command -v` guards, in a script that runs
  inside a minimal container.
- [ ] Hard-coded paths such as `/usr/bin/python` instead of a lookup.
- [ ] `echo -e`, or `echo` with anything that could start with a dash. Use
  `printf`.
- [ ] No usage or help output.
- [ ] Magic numbers and paths repeated instead of named constants.
- [ ] A comment explaining what the line does rather than why it exists.
- [ ] Over 100 lines, or clearly straining against the language. Recommend
  Python.

## Reporting

Lead with the count of P0 and P1 findings and the single worst line. For each
finding, give the line number, what breaks, and the replacement code. Group P3
and P4 into a short list rather than listing each one, unless the user asked
for a full audit. Cite the ShellCheck code where one applies, so the reader can
look it up at <https://github.com/koalaman/shellcheck/wiki/>.

If the script is beyond repair, say so early and estimate the rewrite, rather
than producing forty small fixes for code that should not exist in shell.

---
name: shell-script-expert
description: >-
  
  Use when the user asks "review this script", "write a bash script", "fix my shell script", "make this script safer", "why does this script fail", 
  "convert this to a script", or working with .sh files, sh/bash/zsh syntax, shellcheck, cronjobs, systemd timers, and bash one-liners.
---

# Shell Script Expert

Shell is glue. It starts processes, routes their output, and checks whether they worked. Every strength follows from 
that, and most failures come from asking it to do more.

Three rules govern the whole skill:

- **Quote every expansion.** Unquoted variables are the single largest source
  of shell bugs.
- **Write Google style.** The
  [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
  is the house standard: `#!/bin/bash`, 2 space indent, 80 columns,
  `"${braced}"` variables, `main "$@"` last. The rules that change generated
  code are in `references/google-style.md`; read it before writing.
- **Ship shellcheck-clean.** A script is not finished until
  `scripts/check.sh` passes. Reading the code is not a substitute for running
  the linter.

## Step 1: Confirm shell is the right tool

Stay in shell when the work is invoking other programs, wiring pipes, testing
exit codes, and moving files. Package installs, service restarts, log
rotation, backup wrappers, CI glue, and container entrypoints all belong here.

Leave shell when any of these appear:

| Signal                                                            | Better tool         |
| ----------------------------------------------------------------- | ------------------- |
| Past 100 lines, or control flow that is no longer straightforward | Python              |
| Parsing JSON, YAML, XML, or CSV beyond a single `jq` call         | Python              |
| Arithmetic beyond counters, or any floating point                 | Python              |
| Data structures: nested maps, records, sorting by field           | Python              |
| Retry with backoff plus structured logging plus state             | Python              |
| Performance matters                                               | Python, Go, or Rust |
| Needs to run where no interpreter is installed                    | Go or Rust          |

The 100 line threshold comes from the style guide, and the reasoning behind it
matters more than the number: scripts grow, and rewriting early is far cheaper
than rewriting later. State the recommendation before writing the script, not
after.

## Step 2: Set the portability target

- **`#!/bin/bash`** is the default. Put shell options on a `set` line rather
  than in the shebang, so that `bash script.sh` behaves the same way.
- **`#!/usr/bin/env bash`** only when the fleet forces it, most often because
  macOS is in scope and `/bin/bash` there is version 3.2.
- **`#!/bin/sh`** only when POSIX portability is a stated requirement. It
  costs arrays, `[[`, `local`, and `pipefail`. Do not pay that price by
  accident.

Minimal container images strip more than expected, so guard external tools
with `command -v` rather than assuming they exist. `references/portability.md`
covers bash version gates, GNU versus BSD tool differences, and Amazon Linux
2023 base images.

Zsh is an interactive shell first. Write automation in bash even when the user
lives in zsh, unless the script is explicitly a zsh plugin or `.zshrc`
fragment.

## Step 3: Build from the template

Copy `assets/template.sh` as the starting skeleton. It supplies the file
header, strict mode, `usage`, stderr logging, `require_cmd`, `trap`-based
cleanup, dry-run support, Google-style function header comments, and argument
parsing that already handles `--` and unknown options correctly.

Strip what the script does not need. An unused `--verbose` flag is noise, not
safety.

### Rules that hold in every script

**Streams have jobs.** Data goes to stdout, errors and progress go to stderr.
This keeps the script usable inside a pipeline and keeps cron from mailing
routine chatter.

**Exit codes are an interface.** 0 for success, 1 for general failure, 2 for
usage error. Leave 126 through 165 alone, since the shell and signals already
own them.

**Strict mode is a backstop, not error handling.** `set -Eeuo pipefail`
belongs at the top of every script, and it silently declines to fire in
several common situations. Read `references/strict-mode.md` before relying on
it, particularly before writing `local var=$(command)`, piping into `head`, or
reading `$?` after `if ! command`.

**Respect blast radius.** For anything that deletes, overwrites, restarts, or
sends: validate the target path, use `rm -rf -- "${target:?target is unset}"`
so an empty variable aborts instead of erasing the filesystem, expand
wildcards as `./*` rather than `*`, and put destructive tools behind a
`--dry-run` flag. When the script is risky and the user has not asked for a
flag, add one anyway and say why.

**Treat input as hostile.** Anything from a form, a header, a filename, an
environment variable, or a CI variable can carry shell metacharacters. Pass
values as arguments rather than assembling command strings, and validate
against an allowlist. See `references/security.md`.

**Temp files come from `mktemp`.** Never `/tmp/myscript.$$`. Register cleanup
with `trap` in the same breath as the creation.

**Loop over `find -print0`, never over `ls`.** Filenames contain spaces and
newlines. Piping into `while` also loses every variable the loop sets, so use
process substitution or `readarray` instead.

**Use `printf`, not `echo -e`.** `echo` flag handling varies between shells
and builds; `printf '%s\n'` does not.

## Step 4: Verify

Run the checker on every script produced or modified:

```bash
./scripts/check.sh path/to/script.sh
```

It runs `bash -n` for syntax, `shellcheck` for correctness, and
`shfmt -i 2 -ci -bn -d` for Google-style formatting when those are installed,
and prints install commands when they are not. Fix every finding, or add a
targeted `# shellcheck disable=SCxxxx` with a comment explaining the reason on
the line above. Blanket disables at the top of a file hide real bugs. Look up
any unfamiliar code at
<https://github.com/koalaman/shellcheck/wiki/>, one page per rule.

Then exercise the failure paths, not only the happy path: missing argument,
missing input file, unwritable output directory, and a command that exits
non-zero in the middle. Most shell bugs live there.

## Reviewing or debugging an existing script

Run `scripts/check.sh` first. ShellCheck finds most of what a manual read
would find, faster and without ego, so the conversation can start with the
findings rather than with style opinions.

Then work through `references/review-checklist.md`, which orders the audit by
severity: destructive operations, then injection and quoting, then error
handling, then style and portability. Report findings in that order and lead
with anything that could destroy data.

For a script that misbehaves rather than fails, `set -x` narrows it fastest.
`PS4='+ ${BASH_SOURCE}:${LINENO}: '` makes the trace readable, and
`bash -x script.sh` avoids editing the file at all.

## Additional resources

- **`assets/template.sh`**: production skeleton, copy and trim
- **`scripts/check.sh`**: syntax, lint, and format gate
- **`references/google-style.md`**: the house style, and where this skill
  extends it
- **`references/strict-mode.md`**: where `set -Eeuo pipefail` fails to fire
- **`references/security.md`**: command injection, environment tampering,
  secrets, privilege
- **`references/patterns.md`**: argument parsing, locking, retries,
  parallelism, safe temp files, config handling, JSON with jq
- **`references/portability.md`**: bash version gates, GNU versus BSD tools,
  minimal container images
- **`references/review-checklist.md`**: severity-ordered audit for existing
  scripts

External sources this skill is built on:

- Google Shell Style Guide:
  <https://google.github.io/styleguide/shellguide.html>
- ShellCheck: <https://www.shellcheck.net/>
- ShellCheck rule explanations: <https://github.com/koalaman/shellcheck/wiki/>
- Bash FAQ, Greg's Wiki: <http://mywiki.wooledge.org/BashFAQ>
- OWASP command injection:
  <https://owasp.org/www-community/attacks/Command_Injection>

Suggest a rewrite in Python whenever the script starts reaching for these
references to work around a limitation rather than to use a feature.

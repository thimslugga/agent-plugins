---
name: "shell-script-pro"
description: >-
   Write, edit, update, or review shell scripts to a consistent professional standard: Google Shell Style Guide conventions, snake_case namespaced function names, shellcheck-clean, shfmt-formatted, portable and safe, with proper error handling and logging. Use whenever creating, editing, updating, linting, or formatting .sh files or extensionless shell scripts.
---

# Shell Script Pro

## Purpose

Produce shell scripts that are correct, readable, consistently styled, portable, and safe.

## Overview

- Google's shell script style guide conventions
- Bash-first
- `set -euo pipefail`
- strict function-naming rules
- explicit error handling on every failure path
- timestamped logging
- zero shellcheck warnings
- shfmt formatting

## Operating Rules

1. No script is done until shellcheck is clean at warning level or every remaining finding carries an inline, reasoned suppression.
2. Always run `shfmt` last; never commit hand formatting that contradicts it.
3. When editing, match the file's existing style; do a full restyle only on request.
4. Never invent a shellcheck code or shfmt flag — check the wiki/man page.
5. Prefer builtins over subprocesses; no `eval`; no aliases in scripts; no SUID/SGID bits.
6. Every script handles errors explicitly and logs with levels to stderr — no silent failures, no bare `echo` for diagnostics.
7. Keep this file's core stable; variant-specific or lengthy guidance belongs in `references/`.

## Workflow

1. **Classify the target.** Executable or library? Bash (default) or POSIX sh?
   - Executables: no extension preferred (or `.sh` if a build rule renames it); `#!/usr/bin/env bash` when macOS is in scope, `#!/bin/bash` for Linux-only scripts (see `references/portability.md`); executable bit set.
   - Libraries: must end in `.sh`, must not be executable, must carry function header comments.
   - POSIX sh (`#!/bin/sh`): pass `-ln=posix` to shfmt, avoid bashisms, skip `[[ ]]` and arrays. Run `scripts/checkbashisms` on the file to catch bashisms, and test with `dash` (see `references/dash-and-posh.md`).
   - Extensionless scripts are detected by shfmt via shebang; EditorConfig `[[bash]]` sections cover them (see `references/tools.md`).
2. **Scaffold or open.** New script: generate from `scripts/init-script.sh` (ships the `__log` dispatcher with color-on-tty + `QUIET`, `log_info`/`log_warn`/`log_error`/`log_debug`, `log_fatal` with backtrace and child cleanup, the `ERR`-trap/`__on_error` pattern from `references/bash-strict-mode.md`, `require_vars`, `cleanup` trap, `check_preconditions`, `getopts` + `usage()`). An alternate minimal template lives at `assets/template.sh` (`die`/`die_usage` style, manual long-option parsing, `--dry-run` support); the `init-script.sh` scaffold is the standard. Existing script: keep its established style for the edit; apply the full standard only to new files or when a restyle was requested. If the project lacks `.shellcheckrc`/`.editorconfig`, install the templates with `scripts/init-configs.sh` (copies the `.editorconfig` and `.shellcheckrc` templates into the project root, never overwrites).
3. **Write to the standard.** Follow `references/style-cheatsheet.md` (Google guide, condensed — including the portability, error-handling, and logging sections), `references/function-naming.md` (naming rules), `references/bash-strict-mode.md` (the full `set -euo pipefail` + `errtrace` header and the `ERR`-trap pattern), and `references/layered-config.md` (eval-free layered config: defaults < file < env < args) when the script takes configuration. See `references/patterns.md` for copy-ready solutions, `references/portability.md` for the shebang/target decision, and `references/security.md` before handling untrusted input. Headlines: `snake_case` verb-first functions, `UPPER_SNAKE` readonly constants, `local` variables declared separately from command-substitution assignment, `[[ ]]`, `$( )`, `(( ))`, quoted expansions, arrays for argument lists, `getopts` + `usage()`, errors to stderr, bare `main "$@"` as the last line (never wrapped in `||`/`&&`/`if` — that suppresses `set -e` and the `ERR` trap inside `main`; see `references/bash-strict-mode.md`). When naming a function, constant, or variable, pick from `references/function-names.txt` and `references/variable-names.txt` before inventing a new name. Every failure path handled explicitly — no silent failures; log with levels to stderr with timestamps, debug gated behind a flag; clean up temp artifacts with `trap`.
4. **Lint.** Run `scripts/lint.sh` (shellcheck `-x -S warning` + `shfmt -d`). Fix every finding. A suppression is allowed only as `# shellcheck disable=SCxxxx # <reason>` with a real reason; look codes up on the shellcheck wiki, never invent them. `references/bad-code-examples.md` is the gallery of patterns shellcheck catches.
5. **Format.** Run `scripts/format.sh` (`shfmt -i 2 -ci -bn -s -w`), honoring any `.editorconfig`. Never hand-format around shfmt's output.
6. **Verify.** `shfmt` parsing doubles as a strict syntax check (stricter than `bash -n`). Smoke-run with representative inputs, including failure cases (missing args, missing commands, bad paths); use `bashdb` for interactive debugging when behavior is wrong. For scripts with real logic, add `bats` tests — see `references/testing.md`.
7. **Report** per the Output Contract.

### Review mode

When asked to review (not change) a script: run `scripts/lint.sh` on it, walk the Output Contract as a checklist against the untouched file, and report findings ordered by severity (correctness/safety first, then portability, then style), each with a `file:line` reference and the concrete fix. Do not edit the file. If the script is vendored third-party code, say so and apply the vendored-code rule from `references/tools.md` instead of the full standard.

## Output Contract

- Path(s) of every script created or changed.
- shellcheck result: clean, or each remaining code listed with its justification.
- shfmt: flags applied; any region intentionally left unformatted and why.
- Naming audit: functions renamed to the standard, namespaces/private prefixes applied.
- Portability: bashisms flagged for POSIX targets; no unchecked GNU-only assumptions.
- Error handling: every failure path handled explicitly; `cd` guarded; destructive commands guarded (`${var:?}`); traps clean up temp files.
- Logging: leveled (INFO/WARN/ERROR/DEBUG), timestamped, stderr; stdout reserved for the script's real output; no bare `echo` diagnostics.
- Testing: smoke-run cases covered; `bats` tests added/updated for logic-bearing scripts (see `references/testing.md`).
- Short changelog: what changed and what it was tested with.

## Tooling

- `shellcheck -x -S warning <file>` — linter and static analysis; `-x` follows `source`; severities: error, warning, info, style. Look up codes at <https://github.com/koalaman/shellcheck/wiki> ; also <https://www.shellcheck.net/>.
- `.shellcheckrc` template in `assets/templates/shellcheckrc`: `shell=bash`, `severity=warning`, `external-sources=true`, `enable=all` (strict optional checks), `SC1091` disabled with reason. Install with `scripts/init-configs.sh`.
- `shfmt -i 2 -ci -bn -s -w <file>` — format to the Google-like preset (2-space indent, indented case branches, binary operators start the line, simplify). `-d` shows diffs without writing (CI-friendly); `-l` lists files needing formatting; `-f .` finds shell files recursively; `-ln=bash|posix` forces the dialect.
- `.editorconfig` — shfmt reads it; use `[*.sh]` plus `[[bash]]` for extensionless scripts. Install the template with `scripts/init-configs.sh` (source: `assets/templates/editorconfig`).
- `scripts/checkbashisms` — vendored copy of the Debian devscripts bashism checker (Perl). Run it on `#!/bin/sh` scripts to catch bash-only constructs; see `references/tools.md` for the distro packages.
- `bashdb` — interactive bash debugger (`bashdb script.sh`).
- `bash-language-server` — editor integration (diagnostics, completion).
- Install commands (apt/apt-get/yum/dnf/rpm-ostree/brew/Go): see `references/tools.md`.

## References

- Google Shell Style Guide — <https://google.github.io/styleguide/shellguide.html>
- BashPitfalls — <https://mywiki.wooledge.org/BashPitfalls> ; BashFAQ — <https://mywiki.wooledge.org/BashFAQ>
- TLDP Advanced Bash-Scripting Guide — <http://tldp.org/LDP/abs/html/>
- pure-bash-bible — <https://github.com/dylanaraps/pure-bash-bible>

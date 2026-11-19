---
name: "shell-script-pro"
description: >-
   Write, edit, lint, format, or review shell scripts (.sh files or extensionless scripts with a shell shebang). Use for any Bash or POSIX sh scripting task.
---

# Shell Script Pro

## Purpose

Produce shell scripts that are correct, readable, consistently styled, portable, and safe.

## Overview

- Google's shell script style guide conventions
- Bash-first
- `set -euo pipefail` for Bash executables; explicit status checks for POSIX sh
- snake_case function names; optional library namespaces
- explicit error handling on every failure path
- timestamped logging
- zero shellcheck warnings
- shfmt formatting

## Operating Rules

1. No script is done until shellcheck is clean at all severities with optional checks enabled (`-S style -o all`) or every remaining finding carries an inline, reasoned suppression.
2. Always run `shfmt` last; never commit hand formatting that contradicts it.
3. When editing, match the file's existing style; do a full restyle only on request.
4. Never invent a shellcheck code or shfmt flag. Cite only codes shellcheck itself printed, and verify flags with `shellcheck --list-optional`, `shfmt --help`, or the man page; use the wiki only when network is available.
5. Prefer builtins over subprocesses; no `eval`; no aliases in scripts; no SUID/SGID bits.
6. Every script handles errors explicitly and logs with levels to stderr — no silent failures, no bare `echo` for diagnostics.
7. Keep this file's core stable; variant-specific or lengthy guidance belongs in `references/`.
8. Use plain `snake_case` function names in standalone scripts, regardless of script size. Do not prefix functions with the script name. Bash libraries may use `library_name::function_name` to avoid collisions; POSIX libraries use an underscore prefix such as `library_name_function_name`. Avoid colon-delimited names in interactive completion functions.

## Deviations from the Google Shell Style Guide

This skill follows Google's guide except where listed here. Each deviation is deliberate.

| Google says | This skill does | Why |
| --- | --- | --- |
| Executables start with `#!/bin/bash` | `#!/usr/bin/env bash` when macOS or an unknown target is in scope; `#!/bin/bash` for Linux-only | `/bin/bash` is bash 3.2 on macOS, and bash is often elsewhere (Homebrew, NixOS). See `references/portability.md` |
| Bash only, no need for POSIX compatibility | A POSIX `sh` track (`references/portable-shell.md`) | Some targets (containers, BusyBox, legacy systems) only have `sh` |
| Rewrite in another language past ~100 lines | Advisory: tell the user once, then write the best shell to the standard | Shell is sometimes the only option, so this is not a blocker |
| Shell is for small utilities | Ships larger helpers (`init-script.sh` scaffold, `references/layered-config.md`) | They serve real tools that must stay in shell; keep them to what the script needs |
| `set` options, `err()` helper | Adds `set -euo pipefail`, an `ERR` trap, leveled `info`/`warn`/`err`/`debug` helpers, `shellcheck -o all` | Stricter failure handling; Google's rules still hold |
| Prefer builtins over external commands | Scaffold's `log` uses `printf '%(...)T'` on bash 4.2+ and falls back to `date` below that | macOS ships bash 3.2 |
| `echo` in examples | `printf '%s\n'` for variable data | `echo` handles `-n`, `-e` and backslashes differently across shells |

## Workflow

The scaffold and strict-mode instructions below apply to Bash targets. For POSIX sh, use [Portable shell decisions](references/portable-shell.md). Override the configuration template's `shell=bash` setting with `shellcheck -s sh` or the applicable project setting.

1. **Classify the target.** Executable or library? Bash (default) or POSIX sh?
   - Executables: no extension preferred (or `.sh` if a build rule renames it); `#!/usr/bin/env bash` when macOS is in scope, `#!/bin/bash` for Linux-only scripts (see `references/portability.md`); executable bit set.
   - Libraries: must end in `.sh`, must not be executable, must carry function header comments.
   - POSIX sh (`#!/bin/sh`): read [Portable shell decisions](references/portable-shell.md). Record the minimum POSIX edition, shell versions, and utility implementations. Use `shellcheck -s sh` and `shfmt -ln=posix`; run `scripts/checkbashisms`, and test with `dash` plus the deployment shells (see `references/dash-and-posh.md`). The Bash scaffold, `ERR` trap, arrays, and `local` conventions do not apply. Do not assume POSIX.1-2024 additions are available on older shells.
   - Extensionless scripts are detected by shfmt via shebang; EditorConfig `[[bash]]` sections cover them (see `references/tools.md`).
2. **Scaffold or open.** New script: generate from `scripts/init-script.sh` (ships the `log` core with color-on-tty + `NO_COLOR` + `QUIET`, `info`/`warn`/`err`/`debug`, `die` (the `EXIT` trap does the cleanup), the `ERR`-trap/`__on_error` pattern from `references/bash-strict-mode.md`, `require_vars`, `cleanup` trap, `check_preconditions`, `run_cmd` with `-n` dry-run, `getopts` + `usage()`). Existing script: keep its established style for the edit; apply the full standard only to new files or when a restyle was requested. If the project lacks `.shellcheckrc`/`.editorconfig`, install the templates with `scripts/init-configs.sh` (copies the `.editorconfig` and `.shellcheckrc` templates into the project root, never overwrites).
3. **Write to the standard.** Headline rules:
   - Functions and variables: lowercase `snake_case` (functions verb-first). Constants and exported variables: `UPPER_SNAKE`, declared at the top; use `readonly`/`export`, not `declare -xr`; make a runtime-set constant `readonly` immediately. Mutable script state stays lowercase. Pick names from `references/function-names.txt` and `references/variable-names.txt` before inventing new ones.
   - One job per function (Single Responsibility): if it needs "and" to describe or has no short verb-first name, split it. `main` only coordinates.
   - Separate output from status: data on stdout (`printf '%s\n'`), success/failure via `return` (0-255). Never return a string through `return`.
   - Scope every function variable with `local`; declare separately from a command-substitution assignment (`local x` then `x="$(cmd)"`), never `local x="$(cmd)"`.
   - Expansion: quote everything; brace named variables (`"${var}"`); do not brace single-character specials or positionals (`"$1"`, `"$?"`, `"$@"`) except `${10}`+ or to avoid ambiguity.
   - Use `[[ ]]`, `$( )`, `(( ))`; quote every expansion; use arrays for argument lists.
   - Parse options with `getopts` plus `usage()`.
   - Handle every failure path explicitly: no silent failures, errors to stderr, leveled timestamped logs with debug behind a flag, temp artifacts cleaned up with `trap`.
   - End the script with a bare `main "$@"`. Never wrap it in `||`/`&&`/`if`: that suppresses `set -e` and the `ERR` trap inside `main`.

   Read the matching reference when the situation applies:
   - Always: `references/style-cheatsheet.md` (Google guide, condensed, including portability, error handling, logging), `references/function-naming.md`, `references/bash-strict-mode.md` (full strict-mode header and `ERR`-trap pattern).
   - Script takes configuration: `references/layered-config.md` (eval-free; defaults < file < env < args).
   - Looking for a ready-made solution: `references/patterns.md`.
   - Choosing a shebang or target: `references/portability.md`.
   - Handling untrusted input: `references/security.md`.
4. **Lint.** Run `scripts/lint.sh` (shellcheck `-x -S style -o all` + `shfmt -d`). Fix every finding. A suppression is allowed only as `# shellcheck disable=SCxxxx # <reason>` with a real reason; look codes up on the shellcheck wiki, never invent them. `references/bad-code-examples.md` is the gallery of patterns shellcheck catches.
5. **Format.** Run `scripts/format.sh` (`shfmt -i 2 -ci -bn -s -w`), honoring any `.editorconfig`. Never hand-format around shfmt's output.
6. **Verify.** `shfmt` parsing doubles as a strict syntax check (stricter than `bash -n`). Smoke-run with representative inputs, including failure cases (missing args, missing commands, bad paths); use `bashdb` for interactive debugging when behavior is wrong. For scripts with real logic, add `bats` tests — see `references/testing.md`.
7. **Report** per the Output Contract.

### Review mode

When asked to review (not change) a script: run `scripts/lint.sh` on it, walk the Output Contract as a checklist against the untouched file, and report findings ordered by severity (correctness/safety first, then portability, then style), each with a `file:line` reference and the concrete fix. Do not edit the file. If the script is vendored third-party code, say so and apply the vendored-code rule from `references/tools.md` instead of the full standard.

## Output Contract

- Path(s) of every script created or changed.
- shellcheck result: clean, or each remaining code listed with its justification.
- shfmt: flags applied; any region intentionally left unformatted and why.
- Function design: each function has one job; data on stdout, status via `return`; every function variable is `local`.
- Naming audit: plain snake_case names in standalone scripts; optional library namespaces and private prefixes where appropriate.
- Portability: bashisms flagged for POSIX targets; no unchecked GNU-only assumptions.
- Error handling: every failure path handled explicitly; `cd` guarded; destructive commands guarded (`${var:?}`); traps clean up temp files.
- Logging: leveled (INFO/WARN/ERROR/DEBUG), timestamped, stderr; stdout reserved for the script's real output; no bare `echo` diagnostics.
- Testing: smoke-run cases covered; `bats` tests added/updated for logic-bearing scripts (see `references/testing.md`).
- Short changelog: what changed and what it was tested with.

## Tooling

- `shellcheck -x -S style -o all <file>` — linter and static analysis; `-x` follows `source`; severities: error, warning, info, style. Look up codes at <https://github.com/koalaman/shellcheck/wiki> ; also <https://www.shellcheck.net/>.
- `.shellcheckrc` template in `assets/shellcheckrc`: `shell=bash`, `severity=style`, `external-sources=true`, `enable=all` (strict optional checks), `SC1091` disabled with reason. Install with `scripts/init-configs.sh`.
- `shfmt -i 2 -ci -bn -s -w <file>` — format to the Google-like preset (2-space indent, indented case branches, binary operators start the line, simplify). `-d` shows diffs without writing (CI-friendly); `-l` lists files needing formatting; `-f .` finds shell files recursively; `-ln=bash|posix` forces the dialect.
- `.editorconfig` — shfmt reads it; use `[*.sh]` plus `[[bash]]` for extensionless scripts. Install the template with `scripts/init-configs.sh` (source: `assets/editorconfig`).
- `scripts/checkbashisms` — vendored copy (devscripts `main`, GPL-2.0+; see README "Third-party code") of the Debian devscripts bashism checker (Perl). Run it on `#!/bin/sh` scripts to catch bash-only constructs; see `references/tools.md` for the distro packages.
- `bashdb` — interactive bash debugger (`bashdb script.sh`).
- `bash-language-server` — editor integration (diagnostics, completion).
- Install commands (apt/apt-get/yum/dnf/rpm-ostree/brew/Go): see `references/tools.md`.

## References

- Google Shell Style Guide — <https://google.github.io/styleguide/shellguide.html>
- BashPitfalls — <https://mywiki.wooledge.org/BashPitfalls> ; BashFAQ — <https://mywiki.wooledge.org/BashFAQ>
- TLDP Advanced Bash-Scripting Guide — <http://tldp.org/LDP/abs/html/>
- pure-bash-bible — <https://github.com/dylanaraps/pure-bash-bible>

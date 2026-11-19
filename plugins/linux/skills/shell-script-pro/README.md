# Shell Script Pro Skill

## Overview

An agent skill for writing, editing, and reviewing shell scripts to a
consistent professional standard: Google Shell Style Guide conventions,
`snake_case` function names (optional library namespaces), `set -euo pipefail` with an `ERR`
trap, zero shellcheck warnings, shfmt formatting, explicit error handling on
every failure path, and leveled timestamped logging.

`SKILL.md` holds the workflow (classify, scaffold, write, lint, format,
verify, report) plus the output contract. `scripts/` holds the executables:
`init-script.sh` scaffolds new scripts from the standard template,
`lint.sh` runs shellcheck plus the shfmt diff check, `format.sh` formats in
place, `init-configs.sh` installs the `.shellcheckrc`/`.editorconfig`
templates, and `checkbashisms` (vendored) catches bashisms in POSIX-target
scripts. `references/` holds the detailed guidance; `assets/` holds the
templates and editor snippets for BATS tests.

## Harness notes

- Needs shell access with a writable working directory; no network.
- `shellcheck` and `shfmt` must be on PATH for `scripts/lint.sh` and
  `scripts/format.sh` (install commands in `references/tools.md`).
- `scripts/lint.sh` exits 0 clean / 1 findings / 2 tooling error. Treat exit 2
  as "install the missing tool", not a code problem.
- `scripts/checkbashisms` needs `perl` on PATH. It skips non-sh shebangs
  (exit bit 2) and reads stdin when piped.
- `scripts/init-script.sh` writes the new file relative to the current working
  directory; run it from the target project directory.
- Read a `references/` file only when the `SKILL.md` workflow step points at it.
- The `.editorconfig` template's shfmt keys use the current spellings
  (`language_dialect`, `case_indent`). CLI flags override EditorConfig, so
  `lint.sh` and `format.sh` are unaffected by a project's `.editorconfig`.

## References

- POSIX Shell Guide — <https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html> ; POSIX utilities index — <https://pubs.opengroup.org/onlinepubs/9699919799/utilities/contents.html> ; POSIX.1-2017 (Base Specifications, Issue 7) — <https://pubs.opengroup.org/onlinepubs/9699919799/>
- dash (Debian Almquist Shell) — <http://gondor.apana.org.au/~herbert/dash/> 
- posh (Policy-compliant Ordinary SHell) — <https://salsa.debian.org/clint/posh> ; a Debian shell restricted to the bare minimum syntax the POSIX standard requires, so a script that runs under posh is likely portable to most POSIX-compliant shells
- Bourne shell history and variants (Sven Mascheck) — <https://www.in-ulm.de/~mascheck/bourne/>
- Autoconf, Portable Shell Programming — <https://www.gnu.org/savannah-checkouts/gnu/autoconf/manual/autoconf-2.70/autoconf.html#Portable-Shell>
- Mascheck, shell and Unix portability notes — <https://www.in-ulm.de/~mascheck/various/> ; ash variants — <https://www.in-ulm.de/~mascheck/various/ash/>
- Tomei, "Shell Scripting: Safe, Portable, and Correct" (;login:, Spring 2016) — <https://www.usenix.org/system/files/login/articles/login_spring16_09_tomei.pdf>
- GNU Bourne Again Shell (bash) — <https://www.gnu.org/software/bash/> ; Bash Features — <https://www.gnu.org/software/bash/manual/bash.html>
- TLDP Advanced Bash-Scripting Guide — <http://tldp.org/LDP/abs/html/> ; Shell Programming! — <https://tldp.org/LDP/abs/html/why-shell.html#BASHDEF>
- Google Shell Style Guide — <https://google.github.io/styleguide/shellguide.html>
- BashPitfalls — <https://mywiki.wooledge.org/BashPitfalls> ; BashFAQ — <https://mywiki.wooledge.org/BashFAQ>
- Pure Bash Bible — <https://github.com/dylanaraps/pure-bash-bible>
- OWASP command injection:
<https://owasp.org/www-community/attacks/Command_Injection>
- Writing Bash Scripts that aren't only Bash: checking for Bashisms and using DASH — <https://www.bowmanjd.com/bash-not-bash-posix/>

## Tools

- ShellCheck — <https://www.shellcheck.net/> ; wiki — <https://github.com/koalaman/shellcheck/wiki>
- shfmt — <https://github.com/mvdan/sh> ; man page — <https://github.com/mvdan/sh/blob/master/cmd/shfmt/shfmt.1.scd>
- shfmt fork (additional support and features) — <https://github.com/patrickvane/shfmt>
- mdformat-shfmt — <https://github.com/hukkin/mdformat-shfmt>
- shfmt wrappers — <https://github.com/MaxWinterstein/shfmt-py>
- EditorConfig — <https://editorconfig.org/>
- checkbashisms — <https://sourceforge.net/projects/checkbaskisms/> ; Debian package — <https://packages.debian.org/sid/devscripts> ; man page — <https://linux.die.net/man/1/checkbashisms>
- Bash Automated Testing System (BATS) — <https://github.com/bats-core/bats-core> ; documentation — <https://bats-core.readthedocs.io/>
- bats.vim — <https://github.com/aliou/bats.vim> ; bats VS Code extension — <https://marketplace.visualstudio.com/items?itemName=jetmartin.bats>
- bashdb — <https://github.com/Trepan-Debuggers/bashdb>
- bash-language-server (LSP) — <https://github.com/bash-lsp/bash-language-server>
- rlwrap — <https://github.com/hanslub42/rlwrap>
- Gum — <https://github.com/charmbracelet/gum>

## Third-party code

`scripts/checkbashisms` is a vendored copy of checkbashisms from the Debian
devscripts project (upstream `main`, refreshed 2026-11-09). It is based on
`/usr/share/lintian/checks/scripts` (Copyright 1998 Richard Braakman, 2002
Josip Rodin) and is Copyright 2003 Julian Gilbey. Licensed under the GNU
General Public License, version 2 or (at your option) any later version; the
full notice is in the script header. This file is separate from the rest of
this skill and is not covered by any other license that applies to it.

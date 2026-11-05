# Shell Script Pro Skill

## Overview

An agent skill for writing, editing, and reviewing shell scripts to a
consistent professional standard: Google Shell Style Guide conventions,
`snake_case` namespaced function names, `set -euo pipefail` with an `ERR`
trap, zero shellcheck warnings, shfmt formatting, explicit error handling on
every failure path, and leveled timestamped logging.

`SKILL.md` holds the workflow (classify, scaffold, write, lint, format,
verify, report) plus the output contract. `scripts/` holds the executables:
`init-script.sh` scaffolds new scripts from the standard template,
`lint.sh` runs shellcheck plus the shfmt diff check, `format.sh` formats in
place, `init-configs.sh` installs the `.shellcheckrc`/`.editorconfig`
templates, and `checkbashisms` (vendored) catches bashisms in POSIX-target
scripts. `references/` holds the detailed guidance; `assets/` holds the
templates, including an alternate minimal template (`template.sh`) and
editor snippets for BATS tests.

## Harness notes

- Needs shell access with a writable working directory; no network.
- `shellcheck` and `shfmt` must be on PATH for `scripts/lint.sh` and
  `scripts/format.sh` (install commands in `references/tools.md`).
- `scripts/lint.sh` exits 0 clean / 1 findings / 2 tooling error. Treat exit 2
  as "install the missing tool", not a code problem.
- `scripts/checkbashisms` needs `perl` on PATH and prints "unescaped left
  brace" warnings on modern Perl; the findings are still valid.
- `scripts/init-script.sh` writes the new file relative to the current working
  directory; run it from the target project directory.
- Read a `references/` file only when the `SKILL.md` workflow step points at it.
- The `.editorconfig` template's shfmt keys use the current spellings
  (`language_dialect`, `case_indent`). CLI flags override EditorConfig, so
  `lint.sh` and `format.sh` are unaffected by a project's `.editorconfig`.

## References

- POSX Shell Guide — <https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html>
- GNU Bourne Again Shell (bash) — <https://www.gnu.org/software/bash/> ; Bash Features — <https://www.gnu.org/software/bash/manual/bash.html>
- TLDP Advanced Bash-Scripting Guide — <http://tldp.org/LDP/abs/html/> ; Shell Programming! — <https://tldp.org/LDP/abs/html/why-shell.html#BASHDEF>
- Google Shell Style Guide — <https://google.github.io/styleguide/shellguide.html>
- BashPitfalls — <https://mywiki.wooledge.org/BashPitfalls> ; BashFAQ — <https://mywiki.wooledge.org/BashFAQ>
- Pure Bash Bible — <https://github.com/dylanaraps/pure-bash-bible>
- OWASP command injection:
<https://owasp.org/www-community/attacks/Command_Injection>
- Writing Bash Scripts that aren't only Bash: checking for Bashisms and using DASH — <https://www.bowmanjd.com/bash-not-bash-posix/>
- Linuxize Best Practices — <https://linuxize.com/post/bash-best-practices/> ; Bash cheatsheet — <https://linuxize.com/cheatsheet/bash/>
- Bash cheatsheet (bertvv) — <https://bertvv.github.io/cheat-sheets/Bash.html>
- OneUptime Bash Best Practices — <https://oneuptime.com/blog/post/2026-02-13-bash-best-practices/view>
- Reddit (r/bash) tips and tricks — <https://www.reddit.com/r/bash/comments/17fj8x0/my_tips_and_tricks_for_bash_scripting_after/>

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

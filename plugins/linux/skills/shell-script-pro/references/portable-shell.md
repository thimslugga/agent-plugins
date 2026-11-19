# Portable shell decisions

Use this guide for POSIX scripts, bootstrap programs, installers, and shell libraries.
Use [portability.md](portability.md) for Bash version gates and operating-system tool differences.

## Choose the compatibility contract

Record the shell dialect, minimum versions, operating systems, and required utilities before implementation.
Unless the project requires another baseline, use POSIX.1-2017 syntax for broad deployment compatibility.
This baseline is a skill convention. A newer standard does not upgrade deployed shells.

| Target | Decision |
| --- | --- |
| Bash | Declare the minimum Bash version. Use the skill's Bash scaffold and strict-mode guidance. |
| POSIX sh | Use `#!/bin/sh` on systems that provide it. Verify syntax and behavior with the actual deployment shells. |
| Historical Bourne shell | Apply old-shell workarounds only when those systems are explicit targets. For Autoconf projects, use M4sh and Autoconf macros. |
| Sourced library | Match the caller's dialect. A library's shebang does not select an interpreter when sourced. |

The older manuals target shells that predate POSIX. Their restrictions on `unset`, functions, and negated patterns are historical compatibility rules.
Do not impose those restrictions on a modern POSIX target. Autoconf's M4sh supplies shell selection and compatibility support.
See [Autoconf 2.69 Portable Shell](https://www.gnu.org/software/autoconf/manual/autoconf-2.69/html_node/Portable-Shell.html)
and the [buildsystem manual](https://buildsystem-manual.sourceforge.net/Portable-Shell.html).

## Shell families and invocation

Treat Bash, dash, ash, and ksh as distinct implementations. Shared Bourne ancestry does not guarantee identical extensions or behavior.
Native zsh requires a compatibility mode for Bourne-style scripts. C shell syntax is a separate language.
The user's login shell and `$SHELL` do not establish the interpreter that runs a script.
See [Autoconf Shellology](https://www.gnu.org/savannah-checkouts/gnu/autoconf/manual/autoconf-2.69/html_node/Shellology.html#Shellology).

The [shell-differences FAQ](https://www.faqs.org/faqs/unix-faq/shell/shell-differences/) is version 1.17, dated July 13, 1997.
Use it for historical context about shell families and interactive features. Its feature matrix is not evidence about current versions.

POSIX mode does not make Bash a reliable detector of nonportable code. Test another implementation and the target utility set.
See the local [Bashism reference](bashism.md).

## Keep the standard edition explicit

`pipefail` and `$'...'` quoting are specified by POSIX.1-2024, with details that can differ from shell extensions.
Older deployment shells can lack them. For the POSIX.1-2017 baseline, avoid both.
See the [POSIX.1-2024 shell specification](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html).

| Requirement | POSIX.1-2017 approach |
| --- | --- |
| Tests and compound conditions | `[ "$a" = "$b" ]` and separate commands joined by `&&` or `\|\|`; avoid `test -a` and `test -o`. |
| Pattern matching | `case`; shell patterns and regular expressions are different languages. |
| Function definitions | `name() { ...; }`; names contain letters, digits, and underscores, with no initial digit. |
| Library namespaces | `library_name_function_name`; `library_name::function_name` is a Bash convention. |
| Argument lists | `set --` and `"$@"`; a delimited string cannot represent arbitrary arguments without an encoding scheme. |
| Sourcing | `. ./library.sh` or an explicit absolute path; a name without a slash triggers a `PATH` search. |
| Redirection | `command >"$output" 2>&1`; redirections apply from left to right. |
| Variable scope | POSIX does not define `local`. Use distinctive library variables or a subshell when parent-state changes are unnecessary. |

See [Shell Functions](https://www.gnu.org/software/autoconf/manual/autoconf-2.69/html_node/Shell-Functions.html)
and [Limitations of Builtins](https://buildsystem-manual.sourceforge.net/Limitations-of-Builtins.html).

## Preserve data and argument boundaries

Use a constant `printf` format for variable data. Forward arguments with `"$@"`.
Keep command names and arguments separate from shell source text. This skill does not use `eval` to simulate arrays.

```sh
printf '%s\n' "$value"
set -- --output "$output" "$input"
some_command "$@"
```

Command substitution removes trailing newlines. Do not use it for arbitrary byte data or strings that require those newlines.
Keep counters and other parent-state changes out of pipeline-fed loops, because pipeline commands can run in subshells.
See [Shell Substitutions](https://buildsystem-manual.sourceforge.net/Shell-Substitutions.html).

For line-oriented input, retain whitespace and backslashes, including an unterminated final line:

```sh
while IFS= read -r line || [ -n "$line" ]; do
  printf '%s\n' "$line"
done < "$input"
```

This pattern treats a failed `read` as the end of input. If read errors must be distinguished from EOF, design that behavior explicitly.
Do not parse `ls` output or split filenames on whitespace. Use quoted globs or `find ... -exec ... {} +` for pathname arguments.
See [Rich's sh tricks](sh-tricks.md) for the underlying edge cases.

## Handle failures and temporary state

Check important commands directly. `set -e` has context-dependent exceptions, and `ERR` traps are not part of this POSIX baseline.
Capture the status in the failure branch before another command replaces it:

```sh
if result=$(some_command "$input"); then
  printf '%s\n' "$result"
else
  status=$?
  printf 'ERROR: command failed with status %s\n' "$status" >&2
  exit "$status"
fi
```

Without `pipefail`, a successful final pipeline command can hide an earlier failure.
If every stage matters, use separate commands and checked intermediate files, or require a tested implementation with `pipefail`.

Declare `mktemp` as a dependency when used; it is not a POSIX.1-2017 utility.
For file replacement, create the temporary file beside the destination and check the transformation before replacement.
Define required permission, ownership, and symlink behavior. A temporary file plus `mv` does not automatically preserve them.
Preserve the original exit status during cleanup, and define signal exits separately. Cleanup must not convert a failure into success.
See [Limitations of Builtins](https://buildsystem-manual.sourceforge.net/Limitations-of-Builtins.html)
and [Signal Handling](https://buildsystem-manual.sourceforge.net/Signal-Handling.html).

## Check utility behavior independently

A POSIX shell can still execute a nonportable utility command. Check required flags and failure behavior with the supported utility implementations.
Use `command -v` for command availability. Probe the required feature when availability alone is insufficient.
An operating-system name is not proof that a particular utility implementation is installed.

The [OneUptime article](https://oneuptime.com/blog/post/2026-01-24-portable-shell-scripts/view) is a useful inventory of problem areas.
Its examples need qualification: `$'...'` gained standard status in 2024, `expr substr` is an extension, and `mktemp` needs a dependency contract.
Its temporary-file edit also needs a successful transformation before `mv`. Treat those examples as illustrations, not templates.
The [POSIX.1-2017 expr specification](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/expr.html) leaves `substr` and similar extension operands unspecified.
See [portability.md](portability.md) for the maintained GNU/BSD comparison.

## Reuse libsh selectively

[libsh](https://github.com/fnichol/libsh) supplies portable helpers, several bundle sizes, and per-function source files.
Evaluate it when shared installer or bootstrap logic would otherwise be duplicated. It is an optional dependency.
Its documented shell and operating-system coverage does not replace tests of the consuming script.

| Helper | Contract to review |
| --- | --- |
| `need_cmd` | Exits the program when the command is missing; it does not return a recoverable failure. |
| `download` | Tries supported download programs and returns failure if none succeeds. HTTPS needs a TLS-capable implementation. |
| `mktemp_directory` / `mktemp_file` | Print the created path. Check status before use. |
| `cleanup_directory` / `cleanup_file` | Register paths for later cleanup; registration does not remove them immediately. |
| `setup_traps` | Installs exit and signal handling. Check interaction with the caller's traps. |

For adoption, choose a suitable bundle or include the required function dependencies.
Record the upstream version or commit and preserve its license notices. Review global variables, diagnostics, and trap side effects before sourcing.
Do not add a runtime network fetch to each script invocation.
See the [libsh README](https://github.com/fnichol/libsh/blob/main/README.md)
and [API](https://github.com/fnichol/libsh/blob/main/API.md).

## Verify the compatibility claim

For a POSIX target, run the available static checks with an explicit dialect:

```sh
shellcheck -s sh -x -S style ./script
shfmt -ln=posix -d ./script
perl scripts/checkbashisms ./script
```

The vendored checker can flag historical compatibility concerns beyond the chosen POSIX baseline. Assess each diagnostic against that baseline.

Run syntax checks and behavior tests under dash and the declared deployment shells, including BusyBox ash when relevant.
Exercise the deployment utility set, such as BSD/macOS utilities as well as GNU tools.
Include empty arguments, spaces, glob characters, leading dashes, unset variables, command failures, and cleanup after interruption.
If arbitrary filenames are supported, include embedded newlines.
Report missing test environments as unverified coverage. A successful Bash run alone does not establish POSIX portability.
See [DASH and POSH](dash-and-posh.md) and [testing.md](testing.md).

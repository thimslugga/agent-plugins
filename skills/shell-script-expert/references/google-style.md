# Google shell style guide

Source: <https://google.github.io/styleguide/shellguide.html>

This skill follows that guide. Below are the rules that actually change what
gets written, plus the two places this skill deliberately goes further.

## Structure

- **Bash only.** Executables start with `#!/bin/bash` and minimal flags. Set
  shell options with `set` on the following lines, so that running the file as
  `bash script.sh` behaves identically. POSIX compatibility is a non-goal
  unless the target environment forces it.
- **Shell is for small utilities and wrappers.** Rewrite in a structured
  language at 100 lines, or as soon as the control flow stops being
  straightforward. The guide is explicit that scripts grow and that rewriting
  early is cheaper.
- **File header comment** on every file, describing its contents.
- **All functions together, below the constants.** No executable code between
  function definitions. Only includes, `set` statements, and constants may
  appear before the first function.
- **`main` is required** once a script has at least one other function, placed
  last, with `main "$@"` as the final non-comment line of the file.
- **File extensions:** executables take `.sh` or no extension; libraries must
  take `.sh` and must not be executable. SUID and SGID are forbidden.

## Formatting

- Indent 2 spaces. No tabs, except inside a `<<-` here-document.
- Maximum line length 80 characters. Split long strings with a here-document
  or an embedded newline.
- `; then` and `; do` go on the same line as `if`, `for`, `while`.
- Pipelines fit on one line, or split one segment per line with the `|` at the
  start of the continued line, indented 2, using `\` for continuation. The
  same applies to `&&` and `||` chains.
- Case alternatives indent 2 from `case`. A single simple action may share the
  line, with a space before `;;`. Anything longer puts the pattern, the
  actions, and the `;;` on their own lines.

```bash
command1 \
  | command2 \
  | command3
```

## Naming

| Thing                            | Style                                                           |
| -------------------------------- | --------------------------------------------------------------- |
| Functions                        | `lower_snake_case`, `package::function` in libraries            |
| Local and mutable variables      | `lower_snake_case`                                              |
| Constants and exported variables | `UPPER_SNAKE_CASE`, declared at the top, `readonly` or `export` |
| Source filenames                 | lowercase, underscores, never hyphens                           |

Braces on the function name line, no space before the parenthesis. The
`function` keyword is optional but must be used consistently within a project;
this skill omits it.

A constant computed at runtime is still a constant: assign it, then mark it
`readonly` on the next line.

## Expansion and quoting

- Prefer `"${var}"` over `"$var"`. Do not brace single-character positional
  parameters or shell specials: `"$1"`, `"$?"`, `"$#"`.
- Braces are not quoting. Quote as well.
- Use `"$@"`, not `$*`, when passing arguments on. `"$*"` is correct only when
  deliberately joining words into one string, such as a log message.
- Use arrays for lists, especially command flags, and expand with
  `"${array[@]}"`.
- Test with `[[ ... ]]`, never `[` or `test`. Use `==` rather than `=`.
- Use `-z` and `-n` for empty tests rather than comparing against `""` or
  padding with filler characters.
- Numeric comparison goes in `(( ... ))`, not `[[ ... ]]`, because `<` and `>`
  compare lexicographically inside `[[ ]]`.
- Expand wildcards with an explicit path: `rm -v ./*`, never `rm -v *`, since
  a filename can begin with a dash.

## Features to avoid

- `eval`, which hides both what was set and whether it worked.
- `let`, `expr`, and `$[ ... ]`. Use `(( ... ))` and `$(( ... ))`.
- Backticks. Use `$( ... )`.
- Aliases inside scripts. Functions do everything aliases do.
- Piping into `while`, because the subshell discards variable changes. Use
  process substitution or `readarray`.
- Building command arguments as a single string, which forces `eval` or nested
  quoting later. Use an array.

## Calling commands

Check return values, either directly or through `$?`:

```bash
if ! mv "${file_list[@]}" "${dest_dir}/"; then
  echo "Unable to move ${file_list[*]} to ${dest_dir}" >&2
  exit 1
fi
```

For pipelines, read `PIPESTATUS` immediately, before any other command
overwrites it, remembering that `[` is itself a command.

Prefer builtins over external processes: parameter expansion instead of `sed`,
`$(( ))` instead of `expr`, `=~` with `BASH_REMATCH` instead of a `sed` pipe.

## Function header comments

Required for any function that is not both obvious and short, and for every
function in a library:

```bash
#######################################
# Delete a file in a sophisticated manner.
# Globals:
#   BACKUP_DIR
# Arguments:
#   File to delete, a path.
# Outputs:
#   Writes progress to stdout.
# Returns:
#   0 if the file was deleted, non-zero on error.
#######################################
del_thing() {
  rm "$1"
}
```

Omit the sections that do not apply.

## Where this skill goes further

Two additions, neither of which contradicts the guide:

1. **`set -Eeuo pipefail` at the top of every script.** The guide requires
   options be set with `set` but does not specify which. It does warn that
   `(( i++ ))` with `i` at zero exits under `set -e`, which
   `references/strict-mode.md` covers along with the other exemptions.
2. **`#!/usr/bin/env bash` as a documented exception.** The guide mandates
   `#!/bin/bash` and allows exceptions where the target environment forces
   one. macOS, where `/bin/bash` is version 3.2, is such an environment. Use
   `#!/bin/bash` by default and switch only when the fleet requires it.

## Companion references

- ShellCheck: <https://www.shellcheck.net/>
- ShellCheck rule explanations, one wiki page per SC code:
  <https://github.com/koalaman/shellcheck/wiki/>
- Bash FAQ, Greg's Wiki, for the awkward corners of the language:
  <http://mywiki.wooledge.org/BashFAQ>
- OWASP command injection: see `references/security.md`

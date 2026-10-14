# Shell script tools

## Install

```bash
# macOS - homebrew
brew install shellcheck shfmt
brew install bats-core

# Fedora
sudo dnf install -y ShellCheck shfmt
sudo dnf install -y bats

# Debian/Ubuntu
sudo apt update
sudo apt install -y shellcheck shfmt
sudo apt install -y bats

# OpenSUSE
sudo zypper in -y  ShellCheck

# EPEL based distros
sudo yum install -y epel-release
sudo yum install -y ShellCheck shfmt

# Go (latest shfmt)
go install mvdan.cc/sh/v3/cmd/shfmt@latest

# Python wrapper (MaxWinterstein/shfmt-py)
python3 -m pip install shfmt-py

# Pre-compiled binary
scversion="stable" # or "v0.4.7", or "latest"
wget -qO- "https://github.com/koalaman/shellcheck/releases/download/${scversion?}/shellcheck-${scversion?}.linux.x86_64.tar.xz" | tar -xJv
cp "shellcheck-${scversion}/shellcheck" /usr/bin/
shellcheck --version
```

### Windows

Windows (via winget):

```powershell
C:\> winget install --id koalaman.shellcheck
```

### pre-commit

To run ShellCheck via pre-commit, add the hook to your .pre-commit-config.yaml:

```text
repos:
-   repo: https://github.com/koalaman/shellcheck-precommit
    rev: v0.11.0
    hooks:
    -   id: shellcheck
#       args: ["--severity=warning"]  # Optionally only show errors and warnings

## args: ["--severity=warning"] # Optionally only show errors and warnings
```

## ShellCheck

```bash
shellcheck -x -S warning script.sh   # -x follows source; fail on warning+
shellcheck -S error script.sh        # errors only (looser)
```

- Severities: `error`, `warning`, `info`, `style`. The skill standard is clean at `warning`.
- Suppression (only with a real valid reason): `# shellcheck disable=SC2086 # word splitting is intended here`
- Look up codes at <https://github.com/koalaman/shellcheck/wiki> — never invent a code.
- Online playground: <https://www.shellcheck.net/>

## shfmt (Format shell programs)

shfmt formats shell programs. If the only argument is a dash (-) or no arguments are given, standard input will be used. If a given path is a directory, all shell scripts found under that directory will be used.

If any EditorConfig files are found, they will be used to apply formatting options. If any parser or printer flags are given to the tool, no EditorConfig formatting options will be used. A default like -i=0 can be used for this purpose.

```bash
shfmt -i 2 -ci -bn -s -w script.sh  # format: Google-like preset, write in place
shfmt -d script.sh                  # diff only, no write (CI-friendly)
shfmt -l .                          # list files that need formatting
shfmt -f .                          # recursively find shell files
shfmt -ln=posix -w script.sh        # force POSIX dialect
shfmt -ln=bash -w no_extension      # force bash for extensionless files
```

- `-i 2` two-space indent, `-ci` indent case branches, `-bn` binary operators start the line, `-s` simplify.
- This preset (`-i 2 -ci -bn`) is documented in the shfmt man page as closely resembling Google's shell style.
- Language auto-detection: by file extension, else by shebang (`#!/bin/sh`, `#!/usr/bin/env bash`), else bash.
- Parsing doubles as a strict syntax check — stricter than `bash -n`.

shfmt can also replace bash -n to check shell scripts for syntax errors. It is more exhaustive, as it parses all syntax statically and requires valid UTF-8:

```shell
$ echo '${foo:1 2}' | bash -n
$ echo '${foo:1 2}' | shfmt >/dev/null
1:9: not a valid arithmetic operator: 2
$ echo 'foo=(1 2)' | bash --posix -n
$ echo 'foo=(1 2)' | shfmt -p >/dev/null
1:5: arrays are a bash feature
```

### Vendored third-party code

Do not lint or reformat code that you do not own (e.g. vendored scripts (`vendor/`, `third_party/`, `third-party/`)):

- shellcheck: exclude the directory from the CI invocation (shellcheck has no
  config-level ignore; scope the file list instead).
- shfmt: mark the directory ignored in `.editorconfig` (shfmt honors it):

  ```ini
  [third_party/**]
  ignore = true
  ```

- Review mode reports vendored files as-is and notes their origin instead of
  applying the standard.

### EditorConfig

- Install the ready-made `.editorconfig` template file with `scripts/init-configs.sh` (template source: `assets/templates/editorconfig`).
- shfmt reads `.editorconfig` in project directory
- shfmt-specific keys for shell files:
  - `indent_size` (like `-i`)
  - `binary_next_line` (`-bn`)
  - `case_indent` (`-ci`)
  - `space_redirects` (`-sr`)
  - `function_next_line`
  - `block_next_line` (`-bl`)
  - `language_dialect`
  - `simplify` (`-s`)
  - `minify` (`-mn`)

### Extensionless scripts in editors

- vim/neovim: detect via shebang and set `filetype=sh` so formatters pick the file up. See <https://qmacro.org/blog/posts/2025/09/01/auto-formatting-extensionless-bash-scripts-in-neovim/>
- For stdin formatting, pass `--filename` so EditorConfig resolution works: `shfmt --filename=deploy < script`.

## checkbashisms

checkbashisms is a Perl script, maintained by the Debian people, to check for portability issues that occur when a shell script has been only written with bash in mind. It is part of the [devscripts](https://packages.debian.org/sid/devscripts) package in Debian. Fortunately, the script is also available in Fedora by installing the so-called `devscripts-checkbashisms` package (which can also be used on RHEL by way). checkbashisms focuses on the syntax constructs that are typically only available in bash, so this is a good and easy way to check your scripts on distributions where /bin/sh is bash by default.

This skill vendors a copy at `scripts/checkbashisms` (upstream devscripts 2.0.0.x, GPL-2.0) so the check is available without installing devscripts. Run it on any `#!/bin/sh` script as part of the POSIX-target workflow:

```bash
scripts/checkbashisms myscript.sh
```

Note: the vendored copy is from 2011 and prints Perl "unescaped left brace" warnings on modern Perl; the findings themselves are still valid. Where the distro package is available (`devscripts` on Debian/Ubuntu, `devscripts-checkbashisms` on Fedora), prefer it.

Debian/Ubuntu:

```bash
sudo apt-get install -y devscripts
```

Fedora:

```bash
sudo dnf install -y devscripts-checkbashisms
```

RHEL/CentOS:

```bash
sudo yum install -y rpmdevtools
```

```bash
checkbashism
```

## Bash Language Server (LSP)

- `bash-language-server` — LSP diagnostics, hover, completion for editors. <https://github.com/bash-lsp/bash-language-server>

## Debugging scripts

- Quick trace without a debugger: `bash -x script.sh` or add `set -x` around a suspicious block.
- `bashdb script.sh` — interactive debugger: breakpoints, stepping, variable inspection. <https://github.com/Trepan-Debuggers/bashdb>

## References

- ShellCheck — <https://www.shellcheck.net/> ; wiki — <https://github.com/koalaman/shellcheck/wiki>
- shfmt — <https://github.com/mvdan/sh> ; man page — <https://github.com/mvdan/sh/blob/master/cmd/shfmt/shfmt.1.scd>
- bashdb — <https://github.com/Trepan-Debuggers/bashdb>
- bash-language-server — <https://github.com/bash-lsp/bash-language-server>

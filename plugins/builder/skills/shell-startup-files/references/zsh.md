# Zsh startup files: full rules

Contents: 1 order, 2 by situation, 3 options that change it, 4 ZDOTDIR,
5 what goes where, 6 PATH in zsh, 7 emulation, 8 not verified here.

## 1. Order

`$ZDOTDIR` stands for `$HOME` when unset.

| # | File | Read when |
|---|---|---|
| 1 | `/etc/zshenv` | always; cannot be overridden |
| 2 | `$ZDOTDIR/.zshenv` | always, unless `-f` |
| 3 | `/etc/zprofile`, `$ZDOTDIR/.zprofile` | login |
| 4 | `/etc/zshrc`, `$ZDOTDIR/.zshrc` | interactive |
| 5 | `/etc/zlogin`, `$ZDOTDIR/.zlogin` | login |
| exit | `$ZDOTDIR/.zlogout`, `/etc/zlogout` | login shell exit |

The `/etc` directory is a build setting. Debian, Ubuntu and Arch use
`/etc/zsh/`; Fedora, RHEL and macOS use `/etc/`.

Logout files run on `exit`, `logout` or end of input. They do not run when the
shell is replaced through `exec`.

## 2. By situation

| Situation | Steps read |
|---|---|
| Script, `zsh -c`, `ssh host 'cmd'`, cron with `SHELL=/bin/zsh` | 1, 2 |
| Linux terminal tab, typing `zsh` | 1, 2, 4 |
| `ssh host`, console login, macOS tab, tmux pane | 1, 2, 3, 4, 5 |
| `zsh -lc cmd` | 1, 2, 3, 5 |

Unlike Bash, the rc file is read by every interactive shell, login or not, and
`.zshenv` gives non-interactive shells a reliable hook with no sshd special
case.

## 3. Options that change it

- `zsh -f` sets NO_RCS: only `/etc/zshenv` is read.
- Unsetting `RCS` inside a startup file stops every later startup file. If it
  is still unset at exit, history is not saved.
- Unsetting `GLOBAL_RCS` stops later files under `/etc` only. A user file can
  set it again. `unsetopt GLOBAL_RCS` in `~/.zshenv` is the way to skip the
  system zprofile/zshrc/zlogin, for example macOS `path_helper`. Know what you
  lose before doing it.
- Guard optional work in `/etc/zshenv` with `if [[ -o rcs ]]; then ... fi` so
  `zsh -f` scripts get a clean shell.
- `file.zwc` made by `zcompile` is used instead of `file` when it is newer.

## 4. ZDOTDIR

- If `ZDOTDIR` is already in the environment (PAM, `/etc/zshenv`, parent
  process), all user files including `.zshenv` come from there.
- If it is set inside `~/.zshenv`, that file is read from `$HOME` and the rest
  (`.zprofile`, `.zshrc`, `.zlogin`, `.zlogout`, history) come from `$ZDOTDIR`.

## 5. What goes where

| File | Use for | Avoid |
|---|---|---|
| `.zshenv` | Small exports every zsh needs; `ZDOTDIR` | Output, aliases, prompt, `compinit`, slow commands, anything needing a tty |
| `.zprofile` | PATH, session environment, login-only actions | Interactive settings |
| `.zshrc` | Options, history, prompt, completion, aliases, functions, key bindings | Exports that non-interactive shells need |
| `.zlogin` | Login actions that need the rc file loaded first | Duplicating `.zprofile` |
| `.zlogout` | Cleanup | |

`.zprofile` and `.zlogin` differ only in position, before and after `.zshrc`.
Use one.

The Zsh guide recommends environment variables in `.zshenv`. That is right for
plain exports. PATH is the exception on macOS (see `platforms.md`): put it in
`.zprofile` there.

## 6. PATH in zsh

`$path` is an array tied to `$PATH`. `typeset -U path PATH` keeps entries
unique, first occurrence wins, which makes repeated sourcing harmless:

```zsh
typeset -U path PATH
path=("$HOME/.local/bin" $path)     # prepend
path+=("/opt/tool/bin")             # append
export PATH
```

Arrays cannot be exported; only the tied scalar `PATH` reaches children.

## 7. Emulation

- Zsh does not read `~/.profile`, `/etc/profile`, `~/.bashrc` or
  `~/.bash_profile` in native mode. Claims that it falls back to `~/.profile`
  are wrong.
- Invoked as `sh` or `ksh`, zsh skips its own files: a login shell reads
  `/etc/profile` then `~/.profile`, and `$ENV` is sourced afterwards if set.
- To reuse a POSIX file from zsh: `emulate sh -c '. ~/.profile'`. Distros that
  want `/etc/profile.d` in zsh do exactly this in the global zprofile.

## 8. Not verified here

The order above is from the Zsh manual. It was not executed when this skill
was written. Confirm on the machine:

```zsh
zsh -o sourcetrace -lic exit        # announces each file
zsh -lixc exit 2>&1 | less          # full trace, PS4 shows file:line
```

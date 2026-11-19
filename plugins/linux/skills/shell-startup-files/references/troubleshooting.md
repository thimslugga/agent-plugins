# Contexts, symptoms and audit codes

Contents: 1 what starts which shell, 2 placement, 3 symptom to cause,
4 audit codes, 5 common wrong beliefs.

## 1. What starts which kind of shell

| How it starts | Login | Interactive |
|---|---|---|
| Console/tty login, `ssh host` | yes | yes |
| `ssh host 'cmd'`, `ssh -t host 'cmd'` | no | no |
| `bash -l`, `zsh -l`, `su - user`, `su -l`, `sudo -i` | yes | yes |
| `su user`, `sudo su`, `sudo -s`, typing `bash` or `zsh` | no | yes |
| Linux terminal emulator tab | no (default) | yes |
| macOS Terminal.app, iTerm2 tab | yes | yes |
| tmux pane or window | yes (tmux default) | yes |
| GNU screen window | no (default) | yes |
| VS Code integrated terminal | macOS yes, Linux no (defaults) | yes |
| Script, `bash -c`, shebang, command substitution | no | no |
| cron job | no | no; runs `/bin/sh` unless `SHELL=` is set |
| Git hook on a server, forced ssh command | no | no; often a restricted minimal PATH |
| systemd unit | no shell | n/a |
| GUI app from dock or launcher | no shell | n/a |

Terminal rows are settings people change. When it matters, source
`scripts/shell-context.sh` in that terminal.

`su user`, `sudo su` and `sudo -s` keep the working directory and start a
non-login shell for the target user: the target's rc file runs, its profile
does not. `sudo -i` and `su -` start a login shell in the target's home.
`sudo cmd` runs no shell and no startup file, and resets most of the
environment (`env_reset`, `secure_path`).

## 2. Placement

| Setting | Bash | Zsh | Why |
|---|---|---|---|
| PATH, exported session env | `~/.profile` or `~/.bash_profile` | `~/.zprofile` | Once per login, inherited by children |
| Env needed by `ssh host cmd` and scripts | `$BASH_ENV` file, or above the guard in `~/.bashrc` | `~/.zshenv` | Only files non-interactive shells read |
| Aliases, functions, prompt, completion, keys, options, history | `~/.bashrc` | `~/.zshrc` | Not inherited; each interactive shell loads them |
| Login-only actions | `~/.bash_profile` | `~/.zprofile` or `~/.zlogin` | Must not repeat per tab |
| Logout cleanup | `~/.bash_logout` | `~/.zlogout` | Login shells only |
| All users | `/etc/profile.d/NN-name.sh` | same where the global zprofile sources `/etc/profile` | Survives package updates |
| GUI apps and user services, Linux | `~/.config/environment.d/*.conf` | same | Not children of a shell |
| systemd units | `Environment=`, `EnvironmentFile=` | same | systemd reads no shell files |
| cron | variables in the crontab or script | same | cron reads no shell files |
| GUI apps, macOS | launchd environment or app settings | same | launchd reads no shell files |
| All users, macOS PATH | file in `/etc/paths.d/` | same | Read by `path_helper` |

Templates for each row are in `assets/`.

## 3. Symptom to cause

| Symptom | Likely cause | Fix |
|---|---|---|
| Alias works in a new tab, missing after `ssh host` | Bash login shell whose login file does not source `~/.bashrc` | Delegate from the login file (`assets/bash/bash_profile`) |
| `~/.profile` stopped working | Something created `~/.bash_profile` or `~/.bash_login` | Source `~/.profile` from it, or merge and delete |
| `ssh host cmd` cannot find a command that works interactively | Non-login, non-interactive shell skips the profile | Bash: export above the guard in `~/.bashrc`, or `BASH_ENV`. Zsh: `~/.zshenv`. Or `ssh host 'bash -lc cmd'` |
| scp, sftp, rsync or git over ssh hangs or shows garbage | A startup file prints for a non-interactive shell | Move the guard up; print nothing above it |
| Works in a terminal, fails in cron | `/bin/sh`, minimal env, no startup files | `PATH=` and `SHELL=` in the crontab, or `bash -lc` |
| Works in a terminal, fails in a systemd unit | No shell files are read | `Environment=`, `EnvironmentFile=` |
| Works in a terminal, missing in a GUI app | App is not a child of a shell | `environment.d` on Linux, launchd on macOS |
| PATH grows duplicates with nesting | Non-idempotent PATH edit in an rc file | `path_prepend`, or `typeset -U path` in zsh |
| macOS: prepended PATH entry ends up last | Set in `~/.zshenv`, reordered by `path_helper` | Move to `~/.zprofile` |
| macOS Bash ignores `~/.bashrc` | Every tab is a login shell | Source it from `~/.bash_profile` |
| tmux pane has a different or doubled PATH | tmux starts login shells; the profile runs again | Idempotent PATH, or `set -g default-command "${SHELL}"` |
| `sudo su` shows root's rc settings but not its profile | Non-login shell | `sudo -i` or `su -` |
| zsh on Linux misses `/etc/profile.d` settings | Global zprofile does not source `/etc/profile`, or the tab is not a login shell | `emulate sh -c '. /etc/profile'` in `~/.zprofile`, or a login-shell terminal |
| Variable set in `~/.zprofile` missing in Linux tabs | Tab is non-login and no ancestor was a zsh login shell | Login-shell terminal, or move to `~/.zshenv` |
| Scripts start slowly | Heavy work in `~/.zshenv` or the `BASH_ENV` file | Move it to the rc file |
| Edit to a startup file has no effect | Wrong file for this mode, or shell not restarted | Trace it; `exec $SHELL -l` to restart |

## 4. Audit codes

Printed by `scripts/audit-startup-files.sh`.

| Code | Meaning | Action |
|---|---|---|
| B00, Z00 | File exists | Information only |
| B01 | Which single user file Bash login shells read | Information only |
| B02 | `.bash_profile` exists and does not source `.profile` | Add `. ~/.profile` to it, or merge |
| B03 | `.bash_login` or `.profile` is shadowed and never read | Merge into the active login file |
| B04 | Login file does not source `.bashrc` | Add the delegation |
| B05 | `.bashrc` has no interactive guard | Add `case $- in *i*) ;; *) return ;; esac` |
| B06 | `.bashrc` prints before the guard | Move the output below the guard |
| Z01 | `ZDOTDIR` is in effect | Information only |
| Z02 | `.zshenv` sets PATH on macOS | Move PATH to `.zprofile` |
| Z03 | `.zshenv` holds interactive setup or output | Move it to `.zshrc` |
| Z04 | Both `.zprofile` and `.zlogin` exist | Keep one unless order matters |
| Z05 | `~/.profile` exists but zsh has no `.zprofile` | Source it with `emulate sh -c`, or port it |

The checks are text heuristics. B02 and B04 look for the file name anywhere in
the login file; B06 only sees `echo`/`printf` at the start of a line. Confirm
a finding by reading the file or tracing.

## 5. Common wrong beliefs

- "macOS Terminal opens a non-login shell." It opens a login shell. Linux
  terminal emulators open non-login shells.
- "`~/.bashrc` is for non-login shells." Interactive non-login shells, plus
  the sshd case. Scripts do not read it.
- "`/etc/bash.bashrc` is part of Bash." It is a distro build option.
- "`~/.bash_profile` runs once per session." Once per login shell: per tab on
  macOS, per pane in tmux.
- "Bash reads `.bash_profile`, then `.bash_login`, then `.profile`." It reads
  the first that exists and stops.
- "`ssh host cmd` reads nothing in Bash." On most Linux builds it reads
  `~/.bashrc`.
- "`ssh -t host cmd` is interactive." A tty is allocated, but `-c` keeps the
  shell non-interactive.
- "Zsh reads `~/.profile`." Only when invoked as `sh` or `ksh`.
- "Put everything in the rc file and it is everywhere." Not in cron, systemd,
  GUI apps or scripts.
- "`.bashrc` is sourced for all shells, interactive or not." Only in the sshd
  case.

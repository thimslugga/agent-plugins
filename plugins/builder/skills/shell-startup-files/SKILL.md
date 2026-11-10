---
name: shell-startup-files
description: Work out which Bash/Zsh startup files run, in what order, for login vs non-login and interactive vs non-interactive shells. Use for any question about .bashrc, .bash_profile, .profile, .zshrc, .zshenv, .zprofile, /etc/profile, BASH_ENV, ZDOTDIR, path_helper, or a PATH, alias or env var that is missing, duplicated or reordered in ssh, cron, tmux, sudo/su, systemd, GUI apps or a new terminal, and when deciding where a shell setting belongs.
---

# Bash and Zsh startup files

Which files a shell reads is decided by how the shell was started, not by the
files themselves. Almost every "my PATH/alias/variable is missing" problem is a
shell started in a different mode than the person assumed. Do not answer from
file names. Classify the shell, read the order, check what the platform's own
files chain to, then verify.

## Workflow

1. **Classify** the shell on two independent axes: login or not, interactive
   or not. If the way it was started is not stated, ask, or have the person
   source `scripts/shell-context.sh` in that shell.
2. **Read the order** from the tables below. For flags, sh mode, the sshd
   case, ZDOTDIR or RCS options, read `references/bash.md` or
   `references/zsh.md`.
3. **Check the wiring**. The shell reads only the files in the tables.
   `/etc/profile.d`, `/etc/bashrc` and "`.bashrc` at login" happen only because
   one file sources another, and that differs per platform:
   `references/platforms.md`.
4. **Verify** when the machine is reachable: `scripts/trace-startup.sh` for
   the real order, `scripts/audit-startup-files.sh` for common mistakes. A
   trace outranks every table here.
5. **Recommend a placement** and say why that file is read in the contexts
   that matter. Start new files from `assets/`.

## The two axes

| Axis | True when | Bash test | Zsh test |
|---|---|---|---|
| Login | `argv[0]` starts with `-` (login, sshd, `su -`), or `-l` | `shopt -q login_shell` | `[[ -o login ]]` |
| Interactive | no script or `-c`, and stdin+stderr are a terminal; or `-i` | `[[ $- == *i* ]]` | `[[ -o interactive ]]` |

| How it starts | Login | Interactive |
|---|---|---|
| `ssh host`, console login, `su -`, `sudo -i` | yes | yes |
| macOS terminal tab, tmux pane | yes | yes |
| Linux terminal tab, typing `bash`/`zsh`, `su user`, `sudo -s` | no | yes |
| `ssh host 'cmd'`, scripts, `bash -c`, cron | no | no |
| systemd units, GUI apps | no shell at all | |

Full list with screen, VS Code, git hooks and sudo details:
`references/troubleshooting.md` section 1.

## Bash order

| Mode | Files, in order |
|---|---|
| Login | `/etc/profile`, then the **first one only** of `~/.bash_profile`, `~/.bash_login`, `~/.profile` |
| Interactive non-login | (`/etc/bash.bashrc` on Debian, Ubuntu, Arch builds), then `~/.bashrc` |
| Non-interactive | only the file named by `$BASH_ENV` |
| Login shell exit | `~/.bash_logout` |

- A login shell does not read `~/.bashrc`; the login file has to source it.
- Creating `~/.bash_profile` silently disables `~/.profile`.
- `ssh host 'cmd'` reads `~/.bashrc` on most Linux builds although the shell
  is non-interactive. So `~/.bashrc` needs an interactive guard near the top,
  and nothing above the guard may print (it breaks scp, sftp, rsync).

## Zsh order

| # | File | Read when |
|---|---|---|
| 1 | `/etc/zshenv`, then `$ZDOTDIR/.zshenv` | always |
| 2 | `/etc/zprofile`, then `$ZDOTDIR/.zprofile` | login |
| 3 | `/etc/zshrc`, then `$ZDOTDIR/.zshrc` | interactive |
| 4 | `/etc/zlogin`, then `$ZDOTDIR/.zlogin` | login |
| exit | `$ZDOTDIR/.zlogout`, then `/etc/zlogout` | login shell exit |

- `$ZDOTDIR` means `$HOME` when unset. Debian, Ubuntu and Arch keep the global
  files in `/etc/zsh/`.
- `.zshrc` runs for every interactive shell, login or not. `.zshenv` runs for
  every zsh including scripts, so keep it tiny and silent.
- Zsh does not read `~/.profile`, `/etc/profile` or any Bash file by itself.
- macOS: `/etc/zprofile` runs `path_helper` after `~/.zshenv`, which pushes
  PATH entries set there behind the system ones. Set PATH in `~/.zprofile`.

## Where things belong

| Setting | Bash | Zsh |
|---|---|---|
| PATH and exported session environment | `~/.profile` or `~/.bash_profile` | `~/.zprofile` |
| Env that `ssh host cmd` and scripts need | `$BASH_ENV` file, or above the guard in `~/.bashrc` | `~/.zshenv` |
| Aliases, functions, prompt, completion, options | `~/.bashrc` | `~/.zshrc` |
| All users | `/etc/profile.d/NN-name.sh` | same, where the global zprofile sources `/etc/profile` |
| GUI apps, systemd, cron | not shell files: `environment.d`, unit `Environment=`, crontab variables | same |

Exported variables are inherited, so once at login is enough. Aliases,
functions and options are not inherited, so every interactive shell must load
them. Full table: `references/troubleshooting.md` section 2.

## Scripts

Run them; no need to read them first. Each has `-h`. Bash 3.2 compatible.

| Script | Use |
|---|---|
| `scripts/shell-context.sh` | Source it (`. scripts/shell-context.sh`) in the shell in question. Prints login/interactive state, argv0, SHLVL, ZDOTDIR, BASH_ENV. Works in Bash and Zsh. |
| `scripts/trace-startup.sh` | `-s bash\|zsh -m login-interactive\|login\|interactive\|script`. Prints the files actually read, in order. `-S` uses strace (Linux) and also shows files reached through `source`. `-H DIR` traces with another HOME. |
| `scripts/audit-startup-files.sh` | Read-only check of a home directory: shadowed `.profile`, missing rc delegation, missing guard, output before the guard, PATH in `.zshenv` on macOS. Exit 1 on warnings. Codes: `references/troubleshooting.md` section 4. |

If the scripts cannot be copied to the machine, the one-liners are:

```bash
PS4='+ ${BASH_SOURCE:-cmdline}:${LINENO}: ' bash -lixc : 2>&1 |
  sed -nE 's/^\++ ([^:]+):[0-9]+: .*/\1/p' | awk '$0!=p{print; p=$0}'   # not as root
zsh -o sourcetrace -lic exit
```

## Templates

`assets/README.md` maps each template to its install path and explains the two
Bash layouts (Fedora/macOS style with `.bash_profile`, Debian style without).

- `assets/bash/`: `profile`, `bash_profile`, `bashrc`, `bash_logout`, `bash_env.sh`
- `assets/zsh/`: `zshenv`, `zprofile`, `zshrc`, `zlogout`
- `assets/system/`: `profile.d-example.sh`, `environment.d-example.conf`, `paths.d-example`

Adapt a template to what the person already has; do not overwrite their files.
Show the change as an edit to their file and tell them to back it up first.

## References

| File | Read when |
|---|---|
| `references/bash.md` | Any Bash detail beyond the table: flags, sh/POSIX mode, the sshd case, BASH_ENV, tested matrix |
| `references/zsh.md` | ZDOTDIR, RCS/GLOBAL_RCS, `-f`, emulation, `$path`, what each zsh file is for |
| `references/platforms.md` | The answer depends on the OS or distro; anything about macOS `path_helper`; graphical logins |
| `references/troubleshooting.md` | A symptom to diagnose, the full context table, audit codes, common wrong beliefs |
| `references/sources.md` | The person cites an article, or two sources disagree: lists each source with its known errors |

## Answering

State the shell kind first ("`ssh host cmd` gives a non-login, non-interactive
Bash"), then the ordered list of files actually read, then the fix and the
file it goes in, then a command to confirm. Correct wrong assumptions plainly;
the usual ones are in `references/troubleshooting.md` section 5. Use `vim` in
edit commands. Say when a claim is platform-dependent and not yet verified on
the person's machine.

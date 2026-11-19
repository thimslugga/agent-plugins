# Bash startup files: full rules

Contents: 1 decision tree, 2 modes, 3 rules the tables hide, 4 the sshd case,
5 sh and POSIX mode, 6 flags, 7 verified matrix.

## 1. Decision tree

```
effective uid != real uid, no -p ........ nothing
invoked as sh ........................... see section 5
login shell (argv0 '-bash', -l, --login)
  --noprofile ........................... nothing
  else  /etc/profile
        first existing of: ~/.bash_profile, ~/.bash_login, ~/.profile
        (non-interactive login: then $BASH_ENV if set)
        on exit: ~/.bash_logout
interactive, not login
  --norc ................................ nothing
  --rcfile F ............................ F
  else  [/etc/bash.bashrc, compile-time option]  then  ~/.bashrc
not interactive, not login
  started by sshd/rshd and SHLVL < 2 .... [/etc/bash.bashrc]  ~/.bashrc  (build-dependent)
  else .................................. $BASH_ENV if set
```

## 2. Modes

| Mode | Files, in order |
|---|---|
| Login, interactive or `--login` | `/etc/profile`, then the first one only of `~/.bash_profile`, `~/.bash_login`, `~/.profile` |
| Interactive non-login | `/etc/bash.bashrc` (some builds), `~/.bashrc` |
| Non-interactive | file named by `$BASH_ENV` |
| Login shell exit | `~/.bash_logout`, plus `/etc/bash.bash_logout` on Debian-family builds |

## 3. Rules the tables hide

- A login shell does not read `~/.bashrc`. It seems to because the distro's
  `~/.bash_profile` or `~/.profile` sources it.
- Only the first existing user login file is read. Creating `~/.bash_profile`
  disables `~/.profile` and `~/.bash_login` without any message.
- `/etc/bash.bashrc` exists only on builds compiled with `SYS_BASHRC` (Debian,
  Ubuntu, Arch). Fedora/RHEL have `/etc/bashrc`, which Bash never reads by
  itself; `/etc/profile` and `~/.bashrc` source it.
- `/etc/profile.d/*.sh` is read only because `/etc/profile` loops over it.
- If a startup file exists but is unreadable, Bash reports an error.
- `$BASH_ENV` is expanded, then used as a path; `PATH` is not searched.
- Exported variables are inherited by child processes. Aliases, non-exported
  functions, `shopt` settings and the prompt are not. That is the whole reason
  for the env-in-profile, interactive-setup-in-rc split.

## 4. The sshd case

`ssh host 'cmd'` runs `bash -c cmd`: non-login, non-interactive. Bash still
reads `~/.bashrc` when it believes a remote shell daemon started it:

- stdin is a network socket (rshd), or
- `SSH_CLIENT` or `SSH2_CLIENT` is set, only on builds compiled with
  `SSH_SOURCE_BASHRC` (Debian, Ubuntu, Fedora, RHEL, Arch enable it; upstream
  default is off; macOS `/bin/bash` 3.2 does not),
- and `SHLVL` is below 2, and Bash was not invoked as `sh`.

Consequences:

- Every `~/.bashrc` needs `case $- in *i*) ;; *) return ;; esac` near the top.
- Nothing above that guard may write to stdout or stderr. Output there breaks
  scp, sftp, rsync, git over ssh, Ansible and anything parsing ssh output.
- Exports placed above the guard are the simplest way to give `ssh host cmd` a
  PATH on those builds.
- `ssh -t host 'cmd'` allocates a tty but still runs `bash -c`, so the shell
  stays non-interactive. Some older write-ups call it interactive.
- To force the login chain: `ssh host 'bash -lc "cmd"'`.

Test on the target instead of assuming:

```bash
ssh host 'echo "[$-] SHLVL=$SHLVL"; shopt -q login_shell && echo login || echo non-login'
```

## 5. Invoked as sh, and POSIX mode

| Invocation | Reads |
|---|---|
| `sh`, login | `/etc/profile`, then `~/.profile` only |
| `sh`, interactive | file named by `$ENV` |
| `sh`, non-interactive | nothing (`BASH_ENV` ignored) |
| `bash --posix` or `POSIXLY_CORRECT`, interactive | file named by `$ENV`, nothing else |

On Debian/Ubuntu `/bin/sh` is dash, on Alpine BusyBox ash: same idea, login
reads `/etc/profile` and `~/.profile`, interactive reads `$ENV`.

## 6. Flags

| Flag | Effect |
|---|---|
| `-l`, `--login` | act as a login shell |
| `-i` | force interactive |
| `--noprofile` | skip `/etc/profile` and the user login file |
| `--norc` | skip `~/.bashrc` (and the system rc) |
| `--rcfile F`, `--init-file F` | read F instead of `~/.bashrc` |
| `-p` | privileged: keep effective uid, read no startup files |

## 7. Verified matrix

Bash 5.2.21 on Ubuntu 24.04, scratch HOME, one marker line per file:

| Command | User files read |
|---|---|
| `bash -l -c true` | `.bash_profile` |
| `bash -l -i -c true` | `.bash_profile` |
| `bash -i -c true` | `.bashrc` |
| `bash -c true` | none |
| `bash --login --noprofile -c true` | none |
| `bash --norc -i -c true` | none |
| `bash --rcfile F -i -c true` | F |
| `BASH_ENV=F bash -c true` | F |
| `BASH_ENV=F bash -l -c true` | `.bash_profile`, then F |
| `ENV=F bash --posix -i -c true` | F |
| as `sh -l -i`, `ENV=F` | `.profile`, then F |
| as `sh -i`, `ENV=F` | F |
| as `sh -c`, `ENV` and `BASH_ENV` set | none |
| `.bash_profile` removed, `bash -l` | `.bash_login` |
| `.bash_login` also removed | `.profile` |
| `SSH_CLIENT=x bash -c true` | `.bashrc` |
| `bash -l -c exit` | login file, then `.bash_logout` |

Rerun on any other platform with `scripts/trace-startup.sh`.

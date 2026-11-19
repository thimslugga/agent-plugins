# Platform wiring

The shell reads only the files in `bash.md` and `zsh.md`. Everything else is
reached because one file sources another, and each platform wires that
differently. Expect what is below, then confirm:

```bash
grep -nE '(^|[^#]*)(\.|source) |profile\.d|path_helper' \
  /etc/profile /etc/bashrc /etc/bash.bashrc /etc/zprofile /etc/zshrc \
  /etc/zsh/zprofile /etc/zsh/zshrc ~/.bash_profile ~/.profile ~/.bashrc \
  ~/.zshenv ~/.zprofile ~/.zshrc 2>/dev/null
```

## Debian, Ubuntu

- Bash: `/etc/profile` sources `/etc/bash.bashrc` (interactive Bash only) and
  `/etc/profile.d/*.sh`. Bash also reads `/etc/bash.bashrc` directly for
  interactive non-login shells.
- Default user file is `~/.profile`; it sources `~/.bashrc` when running under
  Bash and adds `~/bin` and `~/.local/bin`. There is no `~/.bash_profile`;
  creating one disables `~/.profile`.
- `/bin/sh` is dash. Display-manager session scripts source `~/.profile` with
  sh, so keep it POSIX.
- Zsh: files in `/etc/zsh/`. Whether the global zprofile sources
  `/etc/profile` differs by release; grep it. The Ubuntu global zshrc runs
  `compinit` unless `skip_global_compinit=1` is set in `~/.zshenv`.

## Fedora, RHEL, CentOS Stream, Amazon Linux 2023

- Bash: `/etc/profile` sources `/etc/profile.d/*.sh`, then `/etc/bashrc`.
  There is no `/etc/bash.bashrc`.
- Default `~/.bash_profile` sources `~/.bashrc`; default `~/.bashrc` sources
  `/etc/bashrc`, adds `~/.local/bin:~/bin` to PATH and loads `~/.bashrc.d/*`.
- `/etc/bashrc` sources `/etc/profile.d/*.sh` for non-login shells, so
  profile.d applies to terminal tabs too.
- Zsh: files directly in `/etc/`. The global zprofile sources `/etc/profile`
  under emulation.
- Silverblue/Kinoite/IoT: `/etc` is writable and persistent, so
  `/etc/profile.d` works as usual. Inside toolbox/distrobox containers the
  container's own `/etc` applies while `$HOME` is shared.

## Arch

- Bash: built with `/etc/bash.bashrc`. Default `~/.bash_profile` sources
  `~/.bashrc`.
- Zsh: files in `/etc/zsh/`; the global zprofile runs
  `emulate sh -c 'source /etc/profile'`.

## Alpine

- Default shell is BusyBox ash, not Bash. Login reads `/etc/profile` (which
  loops over `/etc/profile.d/*.sh`) then `~/.profile`. Interactive reads `$ENV`.
- Bash and Zsh behave per upstream once installed.

## macOS

- Every Terminal.app and iTerm2 tab is a **login** shell.
- Default shell is zsh. `/bin/bash` is 3.2.
- Bash: `/etc/profile` runs `path_helper`, then sources `/etc/bashrc`. No
  `/etc/bash.bashrc`. `~/.bashrc` is never read unless `~/.bash_profile`
  sources it.
- Zsh: no `/etc/zshenv`. `/etc/zprofile` runs `path_helper`. `/etc/zshrc`
  sets history and loads `/etc/zshrc_Apple_Terminal`. A new account has no
  user zsh files at all.
- GUI apps are started by launchd, not by a shell. They never see shell
  startup files.

### path_helper

`/usr/libexec/path_helper -s` prints a `PATH=...; export PATH` line that the
global profile evaluates. It builds PATH as:

1. lines of `/etc/paths`,
2. lines of each file in `/etc/paths.d/`,
3. whatever PATH already contained, with duplicates removed.

So it never drops your entries, it moves them behind the system ones. Effects:

- PATH set in `~/.zshenv` is reordered, because `/etc/zprofile` runs later.
  Set PATH in `~/.zprofile` or `~/.zshrc`.
- A nested login shell (tmux pane) runs it again and reorders an inherited
  PATH. Idempotent prepends in `~/.zprofile` restore the order each time.
- System-wide additions: add a file to `/etc/paths.d/` (one directory per
  line). Do not edit `/etc/profile` or `/etc/zprofile`; OS updates replace
  them.
- Read order inside `/etc/paths.d` is not guaranteed to be alphabetical on
  APFS. Do not rely on numeric prefixes.
- Do not call `path_helper` yourself and do not disable it.

## Graphical logins on Linux

Whether a desktop session inherits the login chain depends on the display
manager and session type. Some wrap the session in a login shell, some source
`~/.profile` with sh, some do neither. Do not promise either way; check a
variable in a launcher-started app, or use
`~/.config/environment.d/*.conf`, which does not depend on a shell.
`/etc/environment` and `~/.pam_environment` (pam_env) are older shell-free
alternatives; the user-level file is disabled on current distros.

# Sources and how far to trust them

Notes are in this skill's own words. Open the link for the original text.
Where a source disagrees with the manuals or with the tests in `bash.md`
section 7, the correction is listed so the error is not repeated.

## Primary

| Source | Use it for |
|---|---|
| Bash Reference Manual, "Bash Startup Files" https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html | Authoritative Bash rules for every invocation mode |
| Zsh Manual, "Files" https://zsh.sourceforge.io/Doc/Release/Files.html (index: https://zsh.sourceforge.io/Doc/) | Authoritative Zsh order, RCS/GLOBAL_RCS, ZDOTDIR, `.zwc` |
| A User's Guide to the Z-Shell, ch. 2 https://zsh.sourceforge.io/Guide/zshguide02.html | Why each zsh file exists, login/interactive tests, `typeset -U path`, keeping `/etc/zshenv` small |
| `man path_helper` (macOS) | What `path_helper` reads |

## Secondary

| Source | Contributes | Corrections |
|---|---|---|
| rbenv wiki, "Unix shell initialization" https://github.com/rbenv/rbenv/wiki/Unix-shell-initialization | Compact mode list per operation (ssh, remote command, new tab per OS, git hook), sh and fish order | Tested on Bash 4.2 and OS X 10.8. Says `ssh -t host cmd` is interactive: it is not. Says remote Bash commands read only `BASH_ENV`: most Linux builds also read `~/.bashrc`. `environment.plist` and `launchd.conf` no longer work on current macOS |
| solipsys Bash flowchart https://www.solipsys.co.uk/new/BashInitialisationFiles.html | Decision tree including `--login`, `--noprofile`, `--rcfile`, `--norc`, `BASH_ENV` | Its author calls it incomplete: no sh mode, no sshd case. `bash.md` section 1 is this skill's fuller tree |
| The Lumber Room, load-order tables https://shreevatsa.wordpress.com/2008/03/30/zshbash-startup-files-loading-order-bashrc-zshrc-etc/ (also reposted on Medium) | A/B/C tables for both shells; the one-file layout with `shopt -q login_shell` branches | Says zsh seems to read `~/.profile` when `~/.zshrc` is absent: it does not. Lists `/etc/bash.bashrc` without saying it is build-dependent |
| Super User 1840395, complete overview https://superuser.com/questions/1840395 | Flowcharts for both shells tested on Arch; trace-variable technique; warning that `make` runs `zshenv` | Arch paths (`/etc/zsh/`); "typical" uses of files are Arch conventions |
| Super User 183870, .bashrc vs .bash_profile https://superuser.com/questions/183870 | History of login vs rc files; advice to keep env in `~/.profile`; warning that GUI logins may skip it | One answer says `.bashrc` is sourced for all shells: wrong outside the sshd case |
| Super User 789448, choosing between files https://superuser.com/questions/789448 | Layout: POSIX `~/.profile` sourcing `~/.bashrc`; shared env file sourced from both; Debian sshd behaviour | `~/.pam_environment` is deprecated on current distros |
| Stack Overflow 415403 https://stackoverflow.com/questions/415403 | Short statement that `.bashrc` is interactive non-login only while `.zshrc` is every interactive shell | none |
| "Bash Startup Files: Understanding the profile and bashrc Load Order" (article in the original bundle) | cron and systemd rules, idempotent PATH function, context table, `echo` in startup files | Says `ssh host cmd` reads only `BASH_ENV`: see the sshd case. Says `bash -x -l -c exit` shows each file read: xtrace shows commands, not file names, without a PS4 that includes `BASH_SOURCE` |
| r/linuxquestions thread on `sudo -i`, `sudo su`, `su root` https://www.reddit.com/r/linuxquestions/comments/1iz5yhl/ | Worked example: only `sudo -i` gave a login shell and read root's `.bash_profile` | Question only; the explanation is in `troubleshooting.md` section 1 |
| Scripting OS X, "Where PATHs come from" https://scriptingosx.com/2017/05/where-paths-come-from/ | `path_helper`, `/etc/paths`, `/etc/paths.d`, reordering on nested shells, packaging a `paths.d` file | none |
| "Setting $PATH for zsh on macOS" (gist in the original bundle) | Why PATH in `~/.zshenv` ends up last on macOS; fix is `~/.zprofile` | Its sample `.zshenv` has a typo on the darwin branch |
| Softec, "Mastering the path_helper utility" https://www.softec.lu/site/DevelopersCorner/MasteringThePathHelper | Existing PATH is kept and merged; APFS ordering caveat | Recommends editing `/etc/profile` to clear PATH first: avoid, OS updates overwrite it |
| Chris Searle, system path on OS X https://www.chrissearle.org/2014/01/28/setting-system-path-for-command-line-on-mac-osx/ | `/etc/paths` and `/etc/paths.d` usage | Reordering `/etc/paths` has limited effect, see Softec |
| Stack Overflow 9832770 https://stackoverflow.com/questions/9832770 | GUI apps are started by launchd and never see profile settings | none |
| Apple Community thread 253147084 https://discussions.apple.com/thread/253147084 | Observation that macOS has no `/etc/zshenv` and no default `~/.zshrc` | Question only |

## Checked first-hand

- Bash matrix in `bash.md` section 7: executed on Bash 5.2.21, Ubuntu 24.04.
- `scripts/trace-startup.sh` and `scripts/audit-startup-files.sh`: executed
  against Bash on the same system. The zsh branches were not executed.
- Zsh order and macOS, Fedora and Arch wiring: from the sources above, not
  executed. Trace before relying on them.

---
name: "fhs-xdg-dirs"
description: "Decide where files belong on Linux/Unix: FHS spec, XDG base directory spec, and XDG user dirs. Use when writing or reviewing any code, script, package, systemd unit or dotfile setup that reads or writes config, data, state, cache, runtime, log or binary paths, or whenever XDG_* variables, ~/.config, ~/.local, /etc/xdg, user-dirs.dirs, home-directory clutter or FHS paths come up."
---

# FHS, XDG base dirs, and XDG user dirs skill

Three standards answer the question "where does this file go?":

| Standard                            | Scope                                                            | Current version                           |
| ----------------------------------- | ---------------------------------------------------------------- | ----------------------------------------- |
| Filesystem Hierarchy Standard (FHS) | System-wide layout (`/etc`, `/usr`, `/var`, `/run`...)           | 3.0 (2015; now hosted by freedesktop.org) |
| XDG Base Directory Specification    | Per-user application files (config, data, state, cache, runtime) | 0.8, 8 May 2021                           |
| xdg-user-dirs                       | User-facing folders (Desktop, Downloads, Documents...)           | tool release 0.20 (2026)                  |

Note: FHS 2.3 (2004) is the older baseline that many enterprise docs still cite. The differences that matter are in `references/fhs.md`.

## How to use this skill

1. Classify each file the software touches with the decision table.
2. Resolve the path with the rules in "Resolution rules". Never hardcode `~/.config` and never write a new dotfile or dot-directory directly in `$HOME`.
3. For a system service or package, use the FHS column instead of the XDG column.
4. When reviewing existing code, run the review checklist at the end.

## Decision table

Ask these questions in order. The first "yes" wins.

| Question | Per-user (XDG) | System-wide (FHS) |
|---|---|---|
| Is it a socket, pid file, lock or named pipe that must not survive logout or reboot? | `$XDG_RUNTIME_DIR/<app>/` | `/run/<app>/` |
| Can it be deleted at any time with only a speed penalty? | `$XDG_CACHE_HOME/<app>/` | `/var/cache/<app>/` |
| Does the user (or admin) edit it to change behaviour? | `$XDG_CONFIG_HOME/<app>/` | `/etc/<app>/` (vendor defaults: `/etc/xdg/<app>/` or `/usr/share/<app>/`) |
| Is it history, logs, undo data, window layout, recently-used lists, a resume position? | `$XDG_STATE_HOME/<app>/` | `/var/lib/<app>/`, logs in `/var/log/<app>/` |
| Is it data the user would want backed up or moved to a new machine (databases, saves, downloaded models, plugins, keys)? | `$XDG_DATA_HOME/<app>/` | `/var/lib/<app>/` (mutable), `/usr/share/<app>/` (read-only, shipped) |
| Is it an executable the user installed? | `$HOME/.local/bin` | `/usr/local/bin` (admin), `/usr/bin` (package) |
| Is it a document the user created on purpose? | An XDG user dir (ask `xdg-user-dir DOCUMENTS`), or wherever the user chose | n/a |

The config/state/data split is the one people get wrong. A useful test: if you would commit it to a dotfiles repo it is config; if you would back it up but not commit it, it is data; if losing it is only an annoyance, it is state; if losing it costs nothing but time, it is cache.

## XDG Base Directory variables

| Variable | Default when unset **or empty** | Holds |
|---|---|---|
| `XDG_CONFIG_HOME` | `$HOME/.config` | User config |
| `XDG_DATA_HOME` | `$HOME/.local/share` | User data |
| `XDG_STATE_HOME` | `$HOME/.local/state` | Persistent but non-portable state |
| `XDG_CACHE_HOME` | `$HOME/.cache` | Non-essential cached data |
| `XDG_RUNTIME_DIR` | **no default** (systemd sets `/run/user/$UID`) | Sockets, locks, pipes |
| `XDG_CONFIG_DIRS` | `/etc/xdg` | Ordered system config search path |
| `XDG_DATA_DIRS` | `/usr/local/share/:/usr/share/` | Ordered system data search path |
| *(none)* | `$HOME/.local/bin` | User executables |

`XDG_BIN_HOME`, `XDG_LIB_HOME` and similar are **not** in the spec. Some libraries invent them (adrg/xdg has `BinHome`). Do not rely on other software honouring them.

### Resolution rules

These come straight from the spec. Code that skips one of them is non-compliant.

- **Unset and empty are the same.** Use `${VAR:-default}`, not `${VAR-default}`. In other languages test for the empty string as well as absence.
- **Paths must be absolute.** A relative value is invalid; ignore it and use the default (or skip that entry in a `*_DIRS` list).
- **`*_DIRS` are colon-separated and ordered**, most important first. The matching `*_HOME` directory outranks every entry.
- **Lookup** of `app/file` checks `$XDG_CONFIG_HOME` then each `$XDG_CONFIG_DIRS` entry (same pattern for data). The spec does not say whether to take the first hit or merge all hits. Decide, and document it. "First hit wins" is the common choice for config; layered merge (system defaults, then user overrides) is the friendlier one.
- **Writes go to `*_HOME` only.** Never write to a `*_DIRS` entry.
- **Create missing directories with mode `0700`.** Do not change the mode of a directory that already exists.
- **On read, skip anything missing or unreadable** and carry on with the next directory.
- **Namespace under an app subdirectory** (`$XDG_CONFIG_HOME/myapp/config.toml`). A single bare file directly in `~/.config` is tolerated but scales badly.

### XDG_RUNTIME_DIR

- Owned by the user, mode `0700`, on a local filesystem, created at first login and removed at last logout. Contents do not survive a reboot.
- It is usually tmpfs, so it counts against RAM. Keep large files out of it.
- Files can be reaped unless their access time is refreshed at least every 6 hours or they carry the sticky bit.
- **Do not set it yourself in a shell profile.** `pam_systemd`/logind creates it, and it is the only XDG variable a typical distro sets by default. Pointing it somewhere else can break PipeWire and browser screen sharing. If it is unset (cron, `su` without a login session, minimal containers, macOS), fall back to a private `0700` directory such as `$(mktemp -d)` or `${TMPDIR:-/tmp}/<app>-$UID`, verify ownership and mode before use, and print a warning. For long-running services on headless hosts, `loginctl enable-linger <user>` keeps `/run/user/$UID` alive.

### ~/.local/bin

Distributions should put it on `PATH`. Because `$HOME` may be shared between machines of different architectures, compiled binaries here can break on the other host; mention that when a user has an NFS or synced home.

## Reference implementations

Read `references/implementations.md` before writing path-resolution code. It has tested POSIX sh and stdlib Python helpers that apply every rule above, the `github.com/adrg/xdg` Go API with its per-OS default table and a Koanf load-order note, and the Rust crate options. Reuse those instead of writing a quick `os.path.expanduser("~/.config")`.

### macOS policy

The XDG variables are not set on macOS. Libraries disagree: adrg/xdg, `directories` and `platformdirs` map to `~/Library/...`, while most CLI tools (git, neovim, fish) use `~/.config` there too. For a CLI tool, the least surprising behaviour is: honour `XDG_*` when set, otherwise use the Linux defaults on macOS as well. For a GUI app, use `~/Library`. State which policy the tool follows in its README.

## XDG user directories (xdg-user-dirs)

These are the visible folders in a home directory. They are a separate mechanism from the base dirs.

| Name | Key in `user-dirs.dirs` | Default (English) |
|---|---|---|
| DESKTOP | `XDG_DESKTOP_DIR` | `~/Desktop` |
| DOWNLOAD | `XDG_DOWNLOAD_DIR` | `~/Downloads` |
| TEMPLATES | `XDG_TEMPLATES_DIR` | `~/Templates` |
| PUBLICSHARE | `XDG_PUBLICSHARE_DIR` | `~/Public` |
| DOCUMENTS | `XDG_DOCUMENTS_DIR` | `~/Documents` |
| MUSIC | `XDG_MUSIC_DIR` | `~/Music` |
| PICTURES | `XDG_PICTURES_DIR` | `~/Pictures` |
| VIDEOS | `XDG_VIDEOS_DIR` | `~/Videos` |
| PROJECTS | `XDG_PROJECTS_DIR` | `~/Projects` (created by default from 0.20) |

**These are not environment variables.** They are lines in a file. A script that reads `$XDG_DOWNLOAD_DIR` from the environment gets an empty string on almost every system, and the folder names are translated per locale, so `~/Downloads` is also wrong for many users. Ask the tool:

```sh
downloads=$(xdg-user-dir DOWNLOAD)     # prints $HOME if the dir is disabled
```

If the tool is missing, fall back to `$HOME`. In GLib code use `g_get_user_special_dir()`.

Read `references/user-dirs.md` when changing, disabling, localising or administering these directories. It covers the four config files (`user-dirs.dirs`, `user-dirs.locale`, `user-dirs.defaults`, `user-dirs.conf`), the `xdg-user-dirs-update` options, login-time behaviour, how to disable a directory, and the `eval` issue in `xdg-user-dir` before 0.20.

## FHS and XDG side by side

| Role | System (FHS) | User (XDG) | systemd directive | Specifier |
|---|---|---|---|---|
| Config | `/etc` | `$XDG_CONFIG_HOME` | `ConfigurationDirectory=` | `%E` |
| State | `/var/lib` | `$XDG_STATE_HOME` | `StateDirectory=` | `%S` |
| Cache | `/var/cache` | `$XDG_CACHE_HOME` | `CacheDirectory=` | `%C` |
| Logs | `/var/log` | `$XDG_STATE_HOME/log` | `LogsDirectory=` | `%L` |
| Runtime | `/run` | `$XDG_RUNTIME_DIR` | `RuntimeDirectory=` | `%t` |
| Read-only data | `/usr/share`, `/usr/local/share` | `$XDG_DATA_HOME` | | |
| Executables | `/usr/bin`, `/usr/local/bin` | `~/.local/bin` | | |

Prefer the systemd directives over `mkdir` in `ExecStartPre=`: systemd creates the directory with the right owner and exports `CONFIGURATION_DIRECTORY`, `STATE_DIRECTORY`, `CACHE_DIRECTORY`, `LOGS_DIRECTORY` and `RUNTIME_DIRECTORY` to the process. The user-unit mappings have changed between systemd releases, so confirm against `man systemd.exec` and `man systemd.unit` on the target. `systemd-path` prints what the running system resolves:

```sh
systemd-path user-configuration user-state-private user-state-cache user-runtime
```

A tool that runs both as root daemon and as a user should pick by effective UID: FHS paths for UID 0 or a system user, XDG paths otherwise, with the systemd-provided environment variables taking priority when present.

Read `references/fhs.md` for the full FHS 3.0 directory table, the shareable/static classification, what changed from FHS 2.3 (`/run`, `/usr/libexec`, `/var/run`), merged `/usr`, and the path caveats on ostree systems (Fedora Atomic Desktops, IoT, CoreOS), bootc images, Flatpak and containers. Read it whenever the target is a system service, a package, or an immutable or sandboxed host.

## Setting the variables for a login session

Most users should leave the `*_HOME` variables unset; the defaults are the standard. Set them only to relocate a directory. On a systemd desktop the reliable place is `~/.config/environment.d/*.conf`, because it reaches graphical apps and user services as well as shells:

```sh
mkdir -p ~/.config/environment.d
vi ~/.config/environment.d/10-xdg.conf
```

```ini
XDG_CONFIG_HOME=${HOME}/.config
XDG_DATA_HOME=${HOME}/.local/share
XDG_STATE_HOME=${HOME}/.local/state
XDG_CACHE_HOME=${HOME}/.cache
```

For shells without systemd (macOS, Alpine, ssh-only hosts), export the same four in `~/.profile` or `~/.zshenv`. Never export `XDG_RUNTIME_DIR` by hand.

## Cleaning up `$HOME`

Read `references/applications.md` when the user wants to move a specific tool's dotfiles, audit a cluttered home directory, or asks whether an application supports XDG. It lists, per application, the legacy path and the exact environment variable, alias or config line that relocates it (shells, core tools, languages and build tools, cloud and container CLIs, databases), plus which applications are already compliant and which are hardcoded and should be left alone. It also covers `xdg-ninja` and `boxxy`.

Do not quote a relocation variable from memory when that file has an entry; the details (config vs state vs data, minimum versions, directories that must exist first) are easy to get wrong.

## Review checklist

When reviewing code, a package or a dotfile setup, check each of these and report violations with the fix:

1. No new dotfile or dot-directory directly in `$HOME`.
2. No literal `~/.config`, `~/.cache`, `~/.local/share`, `/home/<user>` or `/run/user/1000`.
3. Empty-string variables fall back to the default (`:-`, not `-`).
4. Relative values are rejected.
5. Config lookup walks `XDG_CONFIG_HOME` then `XDG_CONFIG_DIRS`; first-hit or merge behaviour is documented.
6. Writes go only to `*_HOME`; new directories are `0700`; existing modes are untouched.
7. Logs and history are in state, not config or data. Caches are safe to `rm -rf`.
8. Sockets and locks are in `XDG_RUNTIME_DIR`, with a checked `0700` fallback and a warning when it is unset.
9. User folders come from `xdg-user-dir`, never from `$XDG_*_DIR` in the environment or a literal English name.
10. A tool moving from a legacy path keeps reading the old location if it exists, and tells the user how to migrate. It does not silently split state across both.
11. System services use FHS paths through systemd `*Directory=` directives, and `/run` instead of `/var/run`.
12. Tests override `HOME` and the `XDG_*` variables with a temp directory so they never touch the real home.

## Sources

- FHS 3.0: <https://specifications.freedesktop.org/fhs/latest/> and <https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html>
- FHS 2.3: <https://www.pathname.com/fhs/pub/fhs-2.3.html> and <https://www.pathname.com/fhs/>
- XDG Base Directory Specification 0.8: <https://specifications.freedesktop.org/basedir/latest/>
- xdg-user-dirs: <https://www.freedesktop.org/wiki/Software/xdg-user-dirs/> and the `xdg-user-dirs-update(1)`, `user-dirs.dirs(5)`, `user-dirs.defaults(5)`, `user-dirs.conf(5)` man pages
- Arch Wiki: <https://wiki.archlinux.org/title/XDG_Base_Directory> and <https://wiki.archlinux.org/title/XDG_user_directories>
- adrg/xdg (Go): <https://github.com/adrg/xdg>

# xdg-user-dirs: files, commands and behaviour

The directory list and the rule that these are not environment variables are in SKILL.md. This file holds the detail.

## Files

| File | Purpose |
|---|---|
| `$XDG_CONFIG_HOME/user-dirs.dirs` | Current per-user mapping. Shell-sourceable: `XDG_DESKTOP_DIR="$HOME/Desktop"`. Values must be `"$HOME/..."` or an absolute path. |
| `$XDG_CONFIG_HOME/user-dirs.locale` | Locale used when the directories were created. |
| `/etc/xdg/user-dirs.defaults` | Admin defaults, `NAME=relative/path` (e.g. `DOWNLOAD=Downloads`), relative to `$HOME` and translated. |
| `/etc/xdg/user-dirs.conf` | `enabled=True|False`, `filename_encoding=UTF-8|locale`. A per-user `~/.config/user-dirs.conf` overrides it. |

## Commands

```sh
xdg-user-dir DOCUMENTS                                   # query one directory
xdg-user-dirs-update                                     # create/refresh (runs at login)
xdg-user-dirs-update --set DOWNLOAD "$HOME/dl"           # repoint one (absolute path)
xdg-user-dirs-update --force                             # full reset to current locale
xdg-user-dirs-update --dummy-output /tmp/out --force     # dry run; nothing is created
```

## Behaviour worth knowing

- `xdg-user-dirs-update` runs at session start through an XDG autostart entry or the `xdg-user-dirs.service` systemd user unit.
- To **disable** a directory, point it at `$HOME` (`XDG_TEMPLATES_DIR="$HOME/"`). Deleting the folder on older releases makes it reappear at next login; on 0.20 a deleted folder is remapped to `$HOME` instead of being recreated.
- To keep English names under a non-English locale: `LC_ALL=C.UTF-8 xdg-user-dirs-update --force`.
- A custom directory set in `user-dirs.dirs` or with `--set` is not created for you; `mkdir -p` it first. Per-user settings override `/etc/xdg/user-dirs.defaults`.
- Headless servers and containers: set `enabled=False` in `user-dirs.conf` so nothing creates `~/Desktop`.
- Security: before 0.20, `xdg-user-dir` was a shell script that passed its argument to `eval`. Only ever give it a hard-coded name, never user input. 0.20 replaced it with a C binary.

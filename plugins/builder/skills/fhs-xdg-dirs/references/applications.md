# Per-application XDG support and relocation settings

Contents: tools; shells and core tools; languages and build tools; cloud, containers and databases; compliant and hardcoded applications.

Tools:

- `xdg-ninja` scans a home directory and reports which dotfiles can move and how.
- `boxxy` wraps a program that ignores the spec and redirects its files.
- For a directory that cannot move, some desktops (KDE) hide any name listed in `~/.hidden`: `echo .steam >> ~/.hidden`.

The tables below follow the Arch Wiki "XDG Base Directory" support tables (snapshot of November 2026). The wiki itself flags those tables as partly out of date, so confirm against the tool's man page before promising a result. The workarounds need the four `XDG_*_HOME` variables to be exported, because most of these tools do not apply the defaults themselves. Set them in `environment.d` or the shell profile, then move the old files.

## Shells and core tools

| Tool | Legacy path | Setting |
|---|---|---|
| Bash | `~/.bash_history` | `HISTFILE="$XDG_STATE_HOME"/bash/history` after `mkdir -p "$XDG_STATE_HOME"/bash`. `~/.bashrc` and `~/.bash_profile` are hardcoded. |
| bash-completion | `~/.bash_completion` | `BASH_COMPLETION_USER_FILE="$XDG_CONFIG_HOME"/bash-completion/bash_completion` |
| zsh | `~/.zshrc`, `~/.zcompdump`... | `ZDOTDIR="$XDG_CONFIG_HOME"/zsh`. The one file that sets `ZDOTDIR` must stay in `$HOME` (`~/.zshenv`) unless `/etc/zshenv` sets it. See the snippet below for history and completion files. |
| fish | none | Native: `$XDG_CONFIG_HOME/fish/` holds `config.fish`, `conf.d/`, `functions/`, `completions/` and the universal-variable file `fish_variables`. History is in `$XDG_DATA_HOME/fish/fish_history`. Completions generated from man pages go to `$XDG_CACHE_HOME/fish/generated_completions` from 4.0; earlier releases kept them under `$XDG_DATA_HOME/fish`. |
| readline | `~/.inputrc` | `INPUTRC="$XDG_CONFIG_HOME"/readline/inputrc` |
| less | `~/.lesskey`, `~/.lesshst` | Native: `$XDG_CONFIG_HOME/lesskey`, and `$XDG_STATE_HOME/lesshst` or `$XDG_DATA_HOME/lesshst`. Version 590 needs the variables set; 598 applies the defaults. |
| wget | `~/.wgetrc`, `~/.wget-hsts` | `WGETRC="$XDG_CONFIG_HOME/wgetrc"`, then put `hsts-file = /absolute/path/to/state/wget-hsts` in that file (wgetrc does not expand variables) or alias `wget --hsts-file="$XDG_STATE_HOME/wget-hsts"` |
| GNU Screen | `~/.screenrc`, `~/.screen/` | `SCREENRC="$XDG_CONFIG_HOME"/screen/screenrc`, `SCREENDIR="$XDG_RUNTIME_DIR"/screen` |
| tmux | `~/.tmux.conf`, `~/.tmux/plugins` | Native: `~/.config/tmux/tmux.conf` from 3.1, `$XDG_CONFIG_HOME/tmux/tmux.conf` from 3.2. Delete `~/.tmux.conf` after moving it. For TPM plugins, put `set-environment -g TMUX_PLUGIN_MANAGER_PATH "$XDG_DATA_HOME/tmux/plugins/"` in `tmux.conf` before the `run` line. `TMUX_TMPDIR="$XDG_RUNTIME_DIR"` moves the server socket out of `/tmp`. |
| git | `~/.gitconfig`, `~/.git-credentials` | Native: `$XDG_CONFIG_HOME/git/` holds `config`, `ignore`, `attributes` and `credentials`. Git reads both locations, but `git config --global` writes to `~/.gitconfig` unless that file is absent and `$XDG_CONFIG_HOME/git/config` exists, so create the XDG file before deleting the old one. The credential store follows the same rule. |
| ripgrep | none | ripgrep reads no config file unless `RIPGREP_CONFIG_PATH` is set: `RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME"/ripgrep/config`, with one flag per line in that file. |
| Neovim | none (`~/.vimrc` and `~/.vim` are not read) | Native: config in `$XDG_CONFIG_HOME/nvim`, plugins in `$XDG_DATA_HOME/nvim`, ShaDa, swap, undo and log files in `$XDG_STATE_HOME/nvim` (0.8+; earlier releases kept them under `$XDG_DATA_HOME/nvim`), cache in `$XDG_CACHE_HOME/nvim`. `NVIM_APPNAME` (0.9+) changes the `nvim` subdirectory name in all four. |
| ncurses | `~/.terminfo` | `TERMINFO="$XDG_DATA_HOME"/terminfo`, `TERMINFO_DIRS="$XDG_DATA_HOME"/terminfo:/usr/share/terminfo` |
| GnuPG | `~/.gnupg` | `GNUPGHOME="$XDG_DATA_HOME"/gnupg`. The agent socket directory is derived from a hash of `GNUPGHOME`, so systemd socket-activated units need a drop-in with `Environment="GNUPGHOME=%h/.local/share/gnupg"` and the sockets from `gpgconf --list-dirs socketdir`. Take `SSH_AUTH_SOCK` from `gpgconf --list-dirs agent-ssh-socket`. |
| pass | `~/.password-store` | `PASSWORD_STORE_DIR="$XDG_DATA_HOME"/pass` |
| X11 | `~/.Xauthority`, `~/.xinitrc` | `XINITRC="$XDG_CONFIG_HOME"/X11/xinitrc`. Leave `XAUTHORITY` alone on Wayland and with LightDM; moving it breaks Xwayland clients or login. |
| systemd (user manager) | none | Native: user units, `systemctl --user enable` symlinks and `systemctl --user edit` drop-ins go in `$XDG_CONFIG_HOME/systemd/user/`. Units shipped by user-installed packages go in `$XDG_DATA_HOME/systemd/user/`, and runtime and transient units live under `$XDG_RUNTIME_DIR/systemd/`. Manager settings go in `$XDG_CONFIG_HOME/systemd/user.conf`. The manager does not see variables exported in a shell profile, so it keeps using `~/.config` unless `XDG_CONFIG_HOME` is set for the whole login session. |
| environment.d | none | `~/.config/environment.d/*.conf`, read by the systemd user manager at login. Lines are `KEY=VALUE` with `${VAR}` and `${VAR:-default}` expansion; there is no `export` and no other shell syntax. The variables reach user services and graphical sessions that import the systemd user environment (GNOME does). TTY and SSH login shells do not see them, so set the `XDG_*` variables in the shell profile too. |
| XDG autostart | none | Native: `.desktop` files in `$XDG_CONFIG_HOME/autostart/` start at login. System entries live in `$XDG_CONFIG_DIRS/autostart/`, usually `/etc/xdg/autostart/`. A user file with the same name overrides the system one, so to disable a system entry, copy it and add `Hidden=true`. On GNOME, and on KDE Plasma with systemd startup, `systemd-xdg-autostart-generator` turns these files into `app-*@autostart.service` units. |
| GTK 4 | none | Native: `$XDG_CONFIG_HOME/gtk-4.0/settings.ini` and `gtk.css`. On GNOME, GSettings values take precedence over `settings.ini`. File chooser bookmarks are still read from `$XDG_CONFIG_HOME/gtk-3.0/bookmarks`. |

```zsh
# $XDG_CONFIG_HOME/zsh/.zshrc
[ -d "$XDG_STATE_HOME"/zsh ] || mkdir -p "$XDG_STATE_HOME"/zsh
HISTFILE="$XDG_STATE_HOME"/zsh/history
[ -d "$XDG_CACHE_HOME"/zsh ] || mkdir -p "$XDG_CACHE_HOME"/zsh
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME"/zsh/zcompcache
compinit -d "$XDG_CACHE_HOME"/zsh/zcompdump-$ZSH_VERSION
```

## Languages and build tools

| Tool | Legacy path | Setting |
|---|---|---|
| Python | `~/.python_history` | `PYTHON_HISTORY="$XDG_STATE_HOME"/python_history` (3.13+; Python does not create a missing parent directory and silently skips writing), `PYTHONPYCACHEPREFIX="$XDG_CACHE_HOME"/python`, `PYTHONUSERBASE="$XDG_DATA_HOME"/python` |
| mypy | `~/.mypy.ini`, `.mypy_cache` | Config is read from `$XDG_CONFIG_HOME/mypy/config`; `MYPY_CACHE_DIR="$XDG_CACHE_HOME"/mypy` |
| ruff | `.ruff_cache` in each project | `RUFF_CACHE_DIR="$XDG_CACHE_HOME"/ruff` |
| pylint | `~/.pylintrc`, `~/.pylint.d` | `PYLINTRC="$XDG_CONFIG_HOME"/pylint/pylintrc`; data honours `XDG_CACHE_HOME` since 2.10 |
| pyenv | `~/.pyenv` | `PYENV_ROOT="$XDG_DATA_HOME"/pyenv` |
| IPython / Jupyter | `~/.ipython`, `~/.jupyter` | IPython 8+ uses `$XDG_CONFIG_HOME/ipython` only if that directory already exists. jupyter-core 6+ is compliant; 5.x needs `JUPYTER_PLATFORM_DIRS=1`. |
| Rust | `~/.cargo`, `~/.rustup` | `CARGO_HOME="$XDG_DATA_HOME"/cargo`, `RUSTUP_HOME="$XDG_DATA_HOME"/rustup` (add `$CARGO_HOME/bin` to `PATH`) |
| Go | `~/go` | `GOPATH="$XDG_DATA_HOME"/go`, `GOMODCACHE="$XDG_CACHE_HOME"/go/mod`. `GOCACHE` already defaults to `$XDG_CACHE_HOME/go-build`. |
| npm | `~/.npm`, `~/.npmrc` | `NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME"/npm/npmrc`, and in that file: `prefix=${XDG_DATA_HOME}/npm`, `cache=${XDG_CACHE_HOME}/npm`, `logs-dir=${XDG_STATE_HOME}/npm/logs`. Omit `prefix` when Node comes from nvm. |
| nvm | `~/.nvm` | `NVM_DIR="$XDG_DATA_HOME"/nvm` |
| Java | `~/.java` | `_JAVA_OPTIONS=-Djava.util.prefs.userRoot="$XDG_CONFIG_HOME"/java` |
| Gradle / Maven | `~/.gradle`, `~/.m2` | `GRADLE_USER_HOME="$XDG_DATA_HOME"/gradle`; `MAVEN_OPTS=-Dmaven.repo.local="$XDG_DATA_HOME"/maven/repository` |
| GDB | `~/.gdbinit`, `./.gdb_history` | Native config at `$XDG_CONFIG_HOME/gdb/gdbinit` (11.1+); `GDBHISTFILE="$XDG_STATE_HOME"/gdb/history` |
| CUDA | `~/.nv` | `CUDA_CACHE_PATH="$XDG_CACHE_HOME"/nv` |

## Cloud, containers and databases

| Tool | Legacy path | Setting |
|---|---|---|
| AWS CLI | `~/.aws` | `AWS_CONFIG_FILE="$XDG_CONFIG_HOME"/aws/config`, `AWS_SHARED_CREDENTIALS_FILE="$XDG_CONFIG_HOME"/aws/credentials` (1.7.45+). SDKs read the same two variables; other files under `~/.aws` (SSO and CLI caches) are not covered by the wiki entry. |
| Azure CLI | `~/.azure` | `AZURE_CONFIG_DIR="$XDG_DATA_HOME"/azure` |
| GitHub CLI (`gh`) | none | Native: `config.yml` and `hosts.yml` in `$XDG_CONFIG_HOME/gh`, falling back to `$AppData/GitHub CLI` on Windows and `~/.config/gh` elsewhere. `GH_CONFIG_DIR` overrides all of these. The token goes to the system keyring; `hosts.yml` holds it only when no keyring is available or with `--insecure-storage`. Extensions install under `$XDG_DATA_HOME/gh`. |
| Docker CLI | `~/.docker` | `DOCKER_CONFIG="$XDG_CONFIG_HOME"/docker` |
| Podman (`containers`) | none | Native for rootless use: `containers.conf`, `storage.conf`, `registries.conf` and `policy.json` in `$XDG_CONFIG_HOME/containers/`, images and containers in `$XDG_DATA_HOME/containers/storage`, and Quadlet units in `$XDG_CONFIG_HOME/containers/systemd/`. Registry logins go to `$XDG_RUNTIME_DIR/containers/auth.json` and are lost at logout; set `REGISTRY_AUTH_FILE="$XDG_CONFIG_HOME"/containers/auth.json` to keep them. |
| Toolbx (`toolbox`) | none | Config in `$XDG_CONFIG_HOME/containers/toolbox.conf` (TOML), which overrides `/etc/containers/toolbox.conf`. Containers live in Podman's rootless storage. Each container shares the host `$HOME`, so tools run inside it use the host's dotfiles and XDG directories. |
| Distrobox | `~/.distroboxrc` | Config files, lowest to highest priority: `/usr/share/distrobox/distrobox.conf`, `/usr/etc/distrobox/distrobox.conf`, `/etc/distrobox/distrobox.conf`, `~/.config/distrobox/distrobox.conf`, `~/.distroboxrc`. The docs give a fixed `~/.config` path, not `$XDG_CONFIG_HOME`. The Go rewrite parses these files as plain `key=value` and does not expand `$HOME`, so use absolute paths. Containers share the host `$HOME` unless created with `--home`. `distrobox-export` writes `.desktop` files to `~/.local/share/applications` and command wrappers to `~/.local/bin`. |
| kubectl | `~/.kube` | `KUBECONFIG="$XDG_CONFIG_HOME"/kube/config`, `KUBECACHEDIR="$XDG_CACHE_HOME"/kube` |
| k9s / minikube | `~/.k9s`, `~/.minikube` | `K9SCONFIG="$XDG_CONFIG_HOME"/k9s`; `MINIKUBE_HOME="$XDG_DATA_HOME"/minikube` (it still nests a `.minikube` inside) |
| Ansible | `~/.ansible` | `ANSIBLE_HOME="$XDG_CONFIG_HOME"/ansible` (2.14+). To keep caches out of config: `ANSIBLE_GALAXY_CACHE_DIR="$XDG_CACHE_HOME"/ansible/galaxy_cache`, `ANSIBLE_LOCAL_TEMP="$XDG_CACHE_HOME"/ansible/tmp`, `ANSIBLE_SSH_CONTROL_PATH_DIR="$XDG_CACHE_HOME"/ansible/cp` |
| Vagrant | `~/.vagrant.d` | `VAGRANT_HOME="$XDG_DATA_HOME"/vagrant` |
| PostgreSQL | `~/.psqlrc`, `~/.psql_history`, `~/.pgpass` | `PSQLRC="$XDG_CONFIG_HOME/pg/psqlrc"`, `PSQL_HISTORY="$XDG_STATE_HOME/psql_history"`, `PGPASSFILE="$XDG_CONFIG_HOME/pg/pgpass"`, `PGSERVICEFILE="$XDG_CONFIG_HOME/pg/pg_service.conf"`; create the directories first |
| MySQL client | `~/.mysql_history` | `MYSQL_HISTFILE="$XDG_DATA_HOME"/mysql_history` |
| SQLite | `~/.sqliterc`, `~/.sqlite_history` | Native config at `$XDG_CONFIG_HOME/sqlite3/sqliterc` (3.44.0+); `SQLITE_HISTORY="$XDG_STATE_HOME"/sqlite_history` |
| redis-cli | `~/.rediscli_history` | `REDISCLI_HISTFILE="$XDG_DATA_HOME"/redis/rediscli_history`, `REDISCLI_RCFILE="$XDG_CONFIG_HOME"/redis/redisclirc` |

## Compliant, and hardcoded

**Follow the spec natively:** fish, git, tmux, Neovim, systemd and GTK 4 (see the shells table), gh and Podman (see the cloud and containers table), Vim (recent releases), curl 7.73.0+ (`$XDG_CONFIG_HOME/curlrc`), nano, htop, pip, pipx, poetry, pnpm, helm 3, rclone, Emacs 27.1+ (`$XDG_CONFIG_HOME/emacs/init.el`), Firefox 147+ (`$XDG_CONFIG_HOME/mozilla/`). Many of these keep using the legacy path when it still exists (Emacs, Firefox, pipx, IPython), so move or delete the old directory to switch over.

**Hardcoded, leave alone:** OpenSSH (`~/.ssh`, upstream "won't fix"; other software expects it there), Terraform (`~/.terraform.d`), adb (`~/.android`), gsutil (`~/.gsutil`), .NET SDK (`~/.dotnet`), Flatpak (`~/.var`), Snap (`~/snap`), Steam, and Chromium, which keeps cache data under `~/.config`.

uv is not in the wiki tables; check `uv cache dir` and `uv tool dir` on the target instead of assuming.

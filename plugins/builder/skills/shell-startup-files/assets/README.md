# Templates

Copy, then edit. File names here have no leading dot; add it on install.

| Template | Install as | Read by |
|---|---|---|
| `bash/profile` | `~/.profile` | sh login shells; Bash login shells if no `~/.bash_profile` |
| `bash/bash_profile` | `~/.bash_profile` | Bash login shells |
| `bash/bashrc` | `~/.bashrc` | Bash interactive shells (and `ssh host cmd` on most Linux builds) |
| `bash/bash_logout` | `~/.bash_logout` | Bash login shell exit |
| `bash/bash_env.sh` | any path named by `$BASH_ENV` | non-interactive Bash |
| `zsh/zshenv` | `~/.zshenv` | every zsh |
| `zsh/zprofile` | `${ZDOTDIR:-~}/.zprofile` | zsh login shells |
| `zsh/zshrc` | `${ZDOTDIR:-~}/.zshrc` | zsh interactive shells |
| `zsh/zlogout` | `${ZDOTDIR:-~}/.zlogout` | zsh login shell exit |
| `system/profile.d-example.sh` | `/etc/profile.d/NN-name.sh` | all users, login shells |
| `system/environment.d-example.conf` | `~/.config/environment.d/NN-name.conf` | systemd user services and GUI sessions (Linux) |
| `system/paths.d-example` | `/etc/paths.d/NN-name` | macOS `path_helper`, one directory per line |

Pick one Bash layout:

- **Fedora/macOS style**: `bash_profile` + `profile` + `bashrc`. Remove the
  `.bashrc` block at the end of `profile`, since `bash_profile` delegates.
- **Debian/Ubuntu style**: `profile` + `bashrc` only. Do not install
  `bash_profile`.

Back up before overwriting: `cp -p ~/.bashrc ~/.bashrc.bak.$(date +%Y%m%d)`.
Compare first with `vim -d ~/.bashrc assets/bash/bashrc`.

# Install and activate mise

Contents: [Choose a method](#choose-a-method) - [mise.run installer](#miserun-installer) -
[Package managers](#package-managers) - [Windows](#windows) - [Verify a manual download](#verify-a-manual-download) -
[Activation](#activation) - [Shims](#shims) - [Which mechanism to use](#which-mechanism-to-use) -
[Completions](#completions) - [Update and uninstall](#update-and-uninstall) - [Directories](#directories)

Source pages: https://mise.jdx.dev/installing-mise.html, /shell-setup.html, /dev-tools/shims.html

## Choose a method

| Platform | Recommended | Notes |
| --- | --- | --- |
| macOS | `mise.run` | `brew install mise` builds from source, is slower and trails releases. MacPorts: `sudo port install mise`. |
| Linux | `mise.run` | Writes only `~/.local/bin/mise`, so it suits image-based systems (Fedora Silverblue, Fedora IoT) with no package layering. |
| Windows | `irm https://mise.run/powershell \| iex` | winget, Scoop and Chocolatey can lag. |
| CI | `jdx/mise-action` or a committed `bin/mise` wrapper | See `lockfile-ci-docker.md`. |
| Docker | Official images | See `lockfile-ci-docker.md`. |

Use one installation per machine. Two copies on `PATH` can leave an older binary in use;
check with `command -v mise` and `mise --version`.

The bundled `scripts/install-mise.sh` wraps the `mise.run` installer (download, then run),
adds activation idempotently and supports `--dry-run`. `scripts/install-mise.ps1` does the
same on Windows.

## mise.run installer

```sh
curl -fsSL https://mise.run | sh                              # ~/.local/bin/mise
curl -fsSL https://mise.run | MISE_VERSION=v2026.10.4 sh      # reproducible
curl -fsSL https://mise.run | MISE_INSTALL_PATH="$HOME/bin/mise" sh
curl -fsSL https://mise.run | MISE_INSTALL_MUSL=1 sh          # static build (Alpine, old glibc)
curl -fsSL https://mise.run/zsh | sh                          # install + append activation (/bash, /fish)
```

Without `MISE_VERSION` the script picks the newest stable release that is at least 24 hours
old and keeps an existing executable that is the same or newer. It checks the archive
against checksums embedded in the script or `SHASUMS256.txt` from GitHub Releases.

| Variable | Effect |
| --- | --- |
| `MISE_INSTALL_PATH` | Executable path. Default `~/.local/bin/mise`. |
| `MISE_VERSION` | Release such as `v2026.10.4`. Bypasses the release-age delay. |
| `MISE_SELF_UPDATE_MINIMUM_RELEASE_AGE` | Skip releases newer than this (`7d`, `0s`). Falls back to `MISE_MINIMUM_RELEASE_AGE`, then `24h`. |
| `MISE_INSTALL_SKIP_IF_EXISTS` | `1`: skip the download when that version is already installed. |
| `MISE_INSTALL_MUSL` | `1`: install the static musl build. |
| `MISE_INSTALL_OS`, `MISE_INSTALL_ARCH` | Override the platform, such as `MISE_INSTALL_ARCH=x64` on Apple silicon. |
| `MISE_INSTALL_FROM_GITHUB` | `1`: download only from GitHub Releases. |
| `MISE_INSTALL_HELP` | `0`: do not print the activation hint. |
| `MISE_DEBUG`, `MISE_QUIET` | `1`: debug output, or errors only. |

Builds: `macos-x64`, `macos-arm64`, `linux-x64`, `linux-arm64`, `linux-armv7`, each Linux
one also as `-musl`. The glibc builds need glibc 2.18 or newer. GitHub Releases also has
`windows-x64` and `windows-arm64`.

To check the installer's signature first:

```sh
gpg --keyserver hkps://keys.openpgp.org --recv-keys 24853EC9F655CE80B48E6C3A8B81C9D17413A06D
curl -fsSL -o install.sh.sig https://mise.jdx.dev/install.sh.sig
gpg --output install.sh --decrypt install.sh.sig && sh ./install.sh
```

## Package managers

```sh
# Fedora 43+, RHEL 10, CentOS Stream 10 (not for image-based systems; use mise.run there)
sudo dnf copr enable jdxcode/mise && sudo dnf install mise
# RHEL 9, CentOS Stream 9, AlmaLinux 9, Rocky 9
sudo dnf copr enable jdxcode/mise centos-stream+epel-next-9 && sudo dnf install mise
# Debian 11+, Ubuntu 22.04+
sudo apt install -y extrepo && sudo extrepo enable mise && sudo apt update && sudo apt install -y mise
# Ubuntu 26.04+ (PPA)
sudo add-apt-repository -y ppa:jdxcode/mise && sudo apt update && sudo apt install -y mise
# Alpine (community repository)
apk add mise
# Arch
sudo pacman -S mise
# Others
cargo install --locked mise        # or: cargo binstall mise
npm install -g mise                # precompiled binary; the package is `mise`, not @jdxcode/mise
nix-env -iA nixpkgs.mise
```

On Alpine and NixOS mise compiles tools from source by default; from 2027.8.0 the default
becomes precompiled binaries. Set `all_compile = true` to keep compiling.

packslip (https://packslip.dev) installs mise's signed release without running a script:

```sh
packslip install github.com/jdx/mise --pin ps1_nlhmwtfeufglxv5myvwvronk7a
```

## Windows

```powershell
irm https://mise.run/powershell | iex      # PowerShell 5.1+, installs to ~\.local\bin
winget install jdx.mise                    # lags; self-update disabled, use `winget upgrade jdx.mise`
scoop install mise
choco install mise
```

Installer variables: `MISE_VERSION`, `MISE_INSTALL_PATH`, `MISE_INSTALL_MODIFY_PATH=0`
(leave the user Path alone), `MISE_INSTALL_SHIMS_PATH=1` (also add the shims directory),
`MISE_INSTALL_FROM_GITHUB=1`. Keep `mise.exe` and `mise-shim.exe` together.

cmd.exe cannot be activated: put `%LOCALAPPDATA%\mise\shims` on the user `Path`. Git Bash,
MSYS2 and Cygwin use the bash, zsh or fish activation line in their own startup file.

## Verify a manual download

```sh
mise_version=2026.10.4
mise_platform=linux-x64
base="https://github.com/jdx/mise/releases/download/v${mise_version}"
curl -fL -o mise "$base/mise-v${mise_version}-${mise_platform}"
curl -fL -O "$base/SHASUMS256.txt" -O "$base/SHASUMS256.txt.minisig"
minisign -Vm SHASUMS256.txt -P RWTC3g8W3z4RZK3V3qv7fa1QY4JEWyBtqIHW+85QlJpZc5yG+uNYNBSZ &&
  grep " ./mise-v${mise_version}-${mise_platform}$" SHASUMS256.txt | sed 's| ./mise-.*| mise|' | sha256sum -c
install -m 755 ./mise ~/.local/bin/mise
```

On macOS use `shasum -a 256 -c` in place of `sha256sum -c`.

## Activation

Activation hooks an interactive shell so that tools are on `PATH` and `[env]` is set at
each prompt and on `cd`. Add one line per shell, then open a new terminal.

```sh
# bash (~/.bashrc)
activation='eval "$(mise activate bash)"'
grep -qxF "$activation" ~/.bashrc 2>/dev/null || printf '%s\n' "$activation" >> ~/.bashrc

# zsh (${ZDOTDIR:-$HOME}/.zshrc)
zshrc="${ZDOTDIR:-$HOME}/.zshrc"; activation='eval "$(mise activate zsh)"'
grep -qxF "$activation" "$zshrc" 2>/dev/null || printf '%s\n' "$activation" >> "$zshrc"
```

```fish
# fish (~/.config/fish/config.fish); Homebrew and some packages activate fish automatically
mise activate fish | source
```

```powershell
# PowerShell ($PROFILE)
(&mise activate pwsh) | Out-String | Invoke-Expression
```

Nushell: in `env.nu`, `^mise activate nu | save ($nu.default-config-dir | path join mise.nu) --force`;
in `config.nu`, `use ($nu.default-config-dir | path join mise.nu)`. Xonsh:
`execx($(mise activate xonsh))`. Elvish: see the shell-setup page.

- The line runs `mise` by name. If `command -v mise` prints nothing when the startup file
  runs, write `~/.local/bin/mise` instead. Once activated, mise adds its own directory.
- macOS Terminal opens bash as a login shell, which reads `~/.bash_profile` only. Add
  `[ -f ~/.bashrc ] && . ~/.bashrc` there.
- PowerShell 5.1 and Nushell update at the next prompt, not on `cd`, so
  `cd dir; node -v` on one line still uses the previous directory's tools.
- Verify with `mise doctor`: it must report `activated: yes`.

## Shims

A shim is a small executable named after a tool's command. When run, it reads the config
for the current directory, picks the version, sets `[env]` for that program, and runs the
real executable. Shim directory: `~/.local/share/mise/shims` (`%LOCALAPPDATA%\mise\shims`
on Windows).

Use both: shims in the login profile for editors and GUI programs, full activation in the
interactive startup file.

```sh
# zsh
#   ~/.zprofile
eval "$(mise activate zsh --shims)"
#   ~/.zshrc
eval "$(mise activate zsh)"

# bash: put the --shims line in the login file that already exists
# (~/.bash_profile, else ~/.bash_login, else ~/.profile), and the plain line in ~/.bashrc
eval "$(mise activate bash --shims)"
```

```fish
if status is-interactive
    mise activate fish | source
else
    mise activate fish --shims | source
end
```

On Ubuntu and Debian, `~/.profile` usually sources `~/.bashrc`. Creating a new
`~/.bash_profile` stops `~/.profile` from loading, so either reuse `~/.profile` or start
the new file with `[[ -f ~/.profile ]] && source ~/.profile`.

What shims do not do:

- They do not export `[env]` into the shell itself, only into the program they launch.
- They run only `preinstall` and `postinstall` hooks; `cd`, `enter`, `leave` and
  `watch_files` need `mise activate`.
- `which node` prints the shim; `mise which node` prints the real path.
- A virtualenv from `_.python.venv` is not on `PATH` through shims alone.
- A tool the current directory's config does not select fails with
  `No version is set for shim`.
- When the configured version is missing and `not_found_auto_install` is off, the shim
  runs the next executable of that name on `PATH`, which can be an unrelated system
  binary (`python3` on Debian). Set `not_found_system_fallback = false` to fail instead.

`mise reshim` rebuilds the shims; it is rarely needed.

## Which mechanism to use

| Method | Environment applies to | Updates | Use for |
| --- | --- | --- | --- |
| `mise activate` | The current shell | At each prompt and, in most shells, on `cd` | Interactive terminals |
| `mise activate --shims` | Adds shim directories to `PATH` | Each time a shim runs | Editors, IDEs, GUI apps, login profiles |
| A shim | The program it launches and its children | Each time it runs | Commands found through `PATH` |
| `mise exec -- cmd` | One command and its children | Once per command | Scripts, CI, Docker |
| `mise run task` | A task and its dependencies | Once per task | Named project commands |
| `mise en` | A new shell | Once; does not follow `cd` | Sessions without activation |
| `mise env` | Prints assignments | When run | Other tools, agent env files |

## Completions

```sh
mise completion bash --install        # ~/.local/share/bash-completion/completions/mise
mise completion zsh --install         # ~/.local/share/zsh/site-functions/_mise; prints the fpath line
mise completion fish --install        # ~/.config/fish/completions/mise.fish
mise completion powershell --install
```

The Homebrew, pacman, Ubuntu PPA and COPR packages install bash, zsh and fish completions
themselves. Bash needs the bash-completion package. The scripts also complete task names
and task arguments declared with `usage`.

## Update and uninstall

- `mise self-update` for official binaries (also updates plugins; `--no-plugins` to skip).
  Package installs update through their package manager. `mise upgrade` updates tools.
- Automatic: `mise settings self_update.auto=true` (or an interval such as `1d`).
- Self-update skips releases younger than `self_update.minimum_release_age` (default
  24h). `mise self-update 2026.10.4` installs a named release without the delay.
- A project that needs a newer mise sets `min_version = "2026.10.0"` in `mise.toml`.
- Uninstall: `mise implode --dry-run`, then `mise implode` (add `--config` to remove the
  config directory too), then remove the activation lines.

## Directories

| Purpose | Linux | macOS | Windows | Override |
| --- | --- | --- | --- | --- |
| Global config | `~/.config/mise` | `~/.config/mise` | `%USERPROFILE%\.config\mise` | `MISE_CONFIG_DIR`, `XDG_CONFIG_HOME` |
| Tools and plugins | `~/.local/share/mise` | `~/.local/share/mise` | `%LOCALAPPDATA%\mise` | `MISE_DATA_DIR`, `XDG_DATA_HOME` |
| Cache | `~/.cache/mise` | `~/Library/Caches/mise` | `%TEMP%\mise` | `MISE_CACHE_DIR`, `XDG_CACHE_HOME` |
| State | `~/.local/state/mise` | `~/.local/state/mise` | `%USERPROFILE%\.local\state\mise` | `MISE_STATE_DIR`, `XDG_STATE_HOME` |
| System config | `/etc/mise` | `/etc/mise` | `\etc\mise` | `MISE_SYSTEM_CONFIG_DIR` |

Set these in the environment that starts mise (shell startup file, CI job), never in
`[env]`: mise chooses its directories before it reads `mise.toml`.

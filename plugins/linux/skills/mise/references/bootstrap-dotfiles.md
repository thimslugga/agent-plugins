# Machine setup: bootstrap and dotfiles

Contents: [When to use which](#when-to-use-which) - [mise bootstrap](#mise-bootstrap) -
[Host packages](#host-packages) - [Dotfiles: track in place](#dotfiles-track-in-place) -
[Dotfiles: deploy from a repository](#dotfiles-deploy-from-a-repository) -
[Sync across machines](#sync-across-machines) - [Global config layout](#global-config-layout)

Source pages: https://mise.jdx.dev/bootstrap.html, /bootstrap/packages/, /dotfiles.html,
/dotfiles/sync.html

These features are newer than tools, env and tasks, and change quickly. Read the source
page before relying on a detail, and always run the `--dry-run` form first.

## When to use which

| Need | Use |
| --- | --- |
| A CLI whose version each project chooses | `[tools]` |
| A system library, compiler toolchain or desktop app shared by every project | `[bootstrap.packages]` |
| Shell startup files, editor config, Git config on every machine | `[dotfiles]` / `mise dot` |
| A whole machine from scratch | `mise bootstrap` (runs all of the above) |

## mise bootstrap

`mise bootstrap` sets up a machine from mise configuration: host packages, system files,
services, Git repositories, dotfiles, shell activation, tools, and a `bootstrap` task. It
never runs on its own.

```toml
# ~/.config/mise/config.toml
[bootstrap.mise_shell_activate]
zsh = true                  # bash = true, or fish = "auto"

[tools]
node = "24"

[tasks.bootstrap]
run = "node --version"
```

```sh
mise bootstrap --dry-run    # list what each part would change
mise bootstrap              # apply; add --yes to skip confirmation prompts
mise bootstrap status
mise bootstrap --adopt you/mise-config   # start a new machine from a repository
```

Parts that declare state skip whatever already matches, so it is safe to run again. Each
part has its own subcommands, such as `mise bootstrap packages apply`. In a project
`mise.toml` the same sections need `mise trust` first.

Sections include `[bootstrap.packages]`, `[bootstrap.apt.sources]`, `[bootstrap.files]`,
`[bootstrap.directories]`, `[bootstrap.services]`, `[bootstrap.repos]`,
`[bootstrap.mise_shell_activate]`, `[bootstrap.user]`, `[bootstrap.macos.defaults]`,
`[bootstrap.linux.systemd.units]`, `[bootstrap.hooks]` and `[bootstrap.remote]`.

## Host packages

```toml
[bootstrap.packages]
"dnf:openssl-devel" = "latest"
"apt:libssl-dev" = "latest"
"brew:openssl@3" = "latest"
```

```sh
mise bootstrap packages status
mise bootstrap packages apply --dry-run     # prints the package manager commands
mise bootstrap packages apply
mise bootstrap packages upgrade
```

A `manager:` prefix names the package manager (`apk`, `apt`, `aur`, `brew`, `brew-cask`,
`choco`, `dnf`, `flatpak`, `flatpak-user`, `macos-app` and others). mise does not switch
these per directory or create shims for them. `"latest"` is satisfied by any installed
version; `apply` does not upgrade. On image-based Fedora, layered `dnf` packages are the
wrong tool: prefer `flatpak-user:` entries and a toolbox or distrobox for build
dependencies.

## Dotfiles: track in place

The files stay where they are; mise saves their versions in a local Git repository.

```sh
mise dot track ~/.zshrc ~/.config/nvim ~/.config/mise
mise dot save                         # checkpoint after editing
mise dot status
```

`mise dot track` adds `"~/.zshrc" = { mode = "track" }` to the global config. To save
every edit automatically, declare the watcher and apply services:

```toml
[bootstrap.services.mise-history]
builtin = "history-watch"
```

```sh
mise bootstrap services apply
```

Track the whole `~/.config/mise` directory so `conf.d/` and environment files travel with
`config.toml`. Files ending in `.local.toml` stay on each machine.

## Dotfiles: deploy from a repository

The files live in a source directory; `mise dot apply` makes the live files match.

```toml
# ~/src/dotfiles/mise.toml
[dotfiles]
"~/.gitconfig" = { source = "git/config", mode = "copy" }
"~/.config/nvim" = { source = "nvim" }          # symlink is the default mode
"~" = { source = "home", mode = "symlink-each", exclude = ["*.md", ".git"] }
```

```sh
cd ~/src/dotfiles
mise trust
mise dot apply --dry-run
mise dot apply
mise dot status
```

| Mode | Result |
| --- | --- |
| `symlink` (default) | Link the target to the source |
| `symlink-each` | Walk a directory and link each file |
| `copy` | A regular file the application can also rewrite |
| `template` | Render a file that differs per machine |
| `track` | Keep editing in place, with history |
| `absent` | Remove an old file from every machine |

An entry's key is its target; relative sources start from the directory of the config
file that declares them. A repository's `mise.toml` is project config: mise reads its
`[dotfiles]` only after trust and only inside that directory, or with
`mise -C ~/src/dotfiles dot apply`. `mise dot add <file>` moves an existing file into the
dotfiles directory and links it back.

## Sync across machines

```sh
mise dot origin set https://github.com/you/dotfiles.git --sync sync
mise dot sync        # fetch and push history
mise dot pull        # update live files from the remote
mise dot conflicts ~/.zshrc
mise dot pull --take-remote ~/.zshrc     # or --keep-local
```

On another machine, `mise bootstrap --adopt you/dotfiles` restores them. Use a private
repository: shell history files, tokens in config files and SSH config are easy to commit
by accident. Review `mise dot status` before the first sync.

## Global config layout

A layout that stays readable as the tool list grows (`assets/global/` has the files,
`scripts/apply-global-config.sh` copies them):

```text
~/.config/mise/
├── config.toml            # [settings] and anything personal
├── config.local.toml      # machine-specific values, never shared
├── conf.d/
│   ├── 10-runtimes.toml   # python, node, go, rust, ...
│   ├── 20-shell.toml      # ripgrep, fd, jq, fzf, ...
│   ├── 30-git.toml
│   ├── 40-security.toml
│   ├── 50-cloud.toml
│   ├── 60-lint.toml
│   └── 70-agents.toml
└── tasks/                 # global file tasks, such as scaffold/python
```

`conf.d/*.toml` loads in alphabetical order before `config.toml`, so `config.toml`
overrides its fragments. `mise config ls` shows the files in effect.

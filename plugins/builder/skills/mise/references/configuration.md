# Configuration: files, tools, versions, backends, trust

Contents: [File locations and precedence](#file-locations-and-precedence) - [How sections merge](#how-sections-merge) -
[Which file a command writes](#which-file-a-command-writes) - [Config environments](#config-environments) -
[.miserc.toml](#miserctoml) - [Top-level keys](#top-level-keys) - [Version requests](#version-requests) -
[Version files from other managers](#version-files-from-other-managers) - [Backends](#backends) -
[Tool options](#tool-options) - [Automatic install and update](#automatic-install-and-update) -
[Trust and security](#trust-and-security) - [Hooks](#hooks) - [Deprecated syntax](#deprecated-syntax)

Source pages: https://mise.jdx.dev/configuration.html, /dev-tools/, /dev-tools/versions.html,
/dev-tools/backends/, /security.html, /hooks.html, /configuration/environments.html

## File locations and precedence

mise loads config in this order; a later file overrides an earlier one:

1. System config in `/etc/mise` (`config.toml`, `conf.d/*.toml`).
2. Global config in `~/.config/mise` (`config.toml`, `conf.d/*.toml`, `config.local.toml`).
3. Config files in every directory from the filesystem root down to the current directory.
4. Global override files, `~/.config/mise/config.override.toml`, which beat all project
   config including `mise.local.toml`.

Within one directory, highest precedence first:

| File | Use |
| --- | --- |
| `mise.local.toml` | Personal overrides. Keep out of version control. |
| `mise.toml` | Shared project config |
| `mise/config.toml`, `mise/conf.d/*.toml` | Config in a `mise/` directory |
| `.mise/config.toml`, `.mise/conf.d/*.toml` | Hidden `.mise/` directory |
| `.config/mise.toml` | Under `.config/` |
| `.config/mise/config.toml`, `.config/mise/conf.d/*.toml` | In `.config/mise/` |
| `.tool-versions` | asdf-format tool versions |

- `.mise.toml` and `.mise.local.toml` (dotfile names) also work and override the undotted
  names.
- `conf.d/*.toml` fragments load in alphabetical order before the directory's own
  `config.toml`. Use hyphens in fragment names; dots (`node.tools.toml`) are deprecated.
  A folder inside `conf.d` with its own `mise.toml` is a fragment with its own root.
- `mise config ls` lists the loaded files, lowest precedence first.
- `ceiling_paths` stops the upward search. `MISE_GLOBAL_CONFIG_FILE` replaces all global
  files with one file.

`config_root` is the directory relative paths resolve against and the value of
`{{ config_root }}`. For project config it is the project directory, even when the file
is `.config/mise.toml`, `.mise/config.toml` or a `conf.d` fragment. For global config it
is the home directory.

## How sections merge

Values merge; whole files are not replaced.

| Section | How files combine |
| --- | --- |
| `[tools]` | Per tool. The nearest file's entry replaces that tool's whole entry, including options. |
| `[env]`, `[vars]` | Per variable; the nearest file wins. |
| `[settings]` | Per setting. Ignored in untrusted project config. |
| `[tasks]` | Per task name. A nearer directory's task replaces the parent's. |
| `[tool_config]` | Not merged; applies to tools declared in the same config root. |

## Which file a command writes

`mise use`, `mise set`, `mise unset`, `mise settings --local` and `mise tasks add` write
the lowest-precedence file in the nearest directory that has config.

```sh
# In a directory with mise.toml and mise.local.toml:
mise use node@24                 # writes mise.toml
mise use --env local node@25     # writes mise.local.toml
mise use --env staging node@24   # writes mise.staging.toml
mise use -g node@24              # writes the global config
mise use --path ./sub node@24    # writes the config in that directory or that file
mise use --override node@24      # writes ~/.config/mise/config.override.toml
```

- No config anywhere: mise creates `mise.toml` in the current directory. In the home
  directory it writes the global config.
- `--env` on `mise use` chooses the file to write. The global `-E` flag chooses which
  environment files load. They are different flags.
- `mise unuse node@24` matches the request as written (`node = "24"`), not the resolved
  version.
- `settings.write_targets` can send new global tools, bootstrap packages and dotfiles to
  separate `conf.d` files.

## Config environments

`mise.<env>.toml` and `mise.<env>.local.toml` load when the environment is selected.
The selection cannot be made in `mise.toml`, because it decides which files load.

| Method | Example |
| --- | --- |
| CLI flag | `mise -E production run deploy` |
| Environment variable | `MISE_ENV=production` (comma-separated for several) |
| `.miserc.toml` | `env = ["production"]` |

Precedence in one directory: `mise.toml` < `mise.<env>.toml` < `mise.local.toml` <
`mise.<env>.local.toml`. An environment file in a parent directory does not override an
ordinary file in a child directory.

With the `auto_env` setting on, platform environments load automatically: `unix`,
`linux`/`macos`/`windows`, and `linux-x64`/`macos-arm64`/... So `mise.macos.toml` and
`mise.windows.toml` hold per-platform tools, with matching lockfiles.

## .miserc.toml

Holds only the settings mise needs before it looks for config files: `env`, `auto_env`,
`env_conf_d`, `ceiling_paths`, `ignored_config_paths`, `override_config_filenames`,
`override_tool_versions_filenames`. Found from the current directory upward
(`.miserc.local.toml`, `.miserc.toml`, `.config/miserc.toml`), then
`~/.config/mise/miserc.toml`, then `/etc/mise/miserc.toml`. It never needs trust.

## Top-level keys

| Key | Purpose |
| --- | --- |
| `[tools]` | Tool versions and per-tool options |
| `[tool_config]` | Policy for this root's tools; `locked = true` requires the lockfile |
| `[tool_alias]` | Custom version names for a tool |
| `[plugins]` | Plugin repository URLs and local plugin paths |
| `[env]` | Environment variables for commands and tasks |
| `[vars]` | Values for templates, not exported |
| `redactions` | `env` or `vars` keys to hide in output |
| `[tasks]`, `[task_config]`, `[task_templates]` | Tasks, their discovery and shared definitions |
| `[settings]` | mise's own behavior |
| `[hooks]`, `[[watch_files]]` | Commands on `cd`, enter, leave, install, and file change |
| `[shell_alias]` | Shell aliases while in the directory; needs activation |
| `[wrappers]` | Commands that intercept a binary name |
| `include` | Config files merged into this one (local path, `git::`, `oci::`, `zip::`) |
| `min_version` | Oldest mise release that can use this file |
| `monorepo_root`, `[monorepo]` | `//path:task` addressing |
| `[doctor]` | Project checks for `mise doctor project` |
| `[bootstrap]`, `[dotfiles]`, `[dotfile_groups]`, `[history]` | Machine setup; see `bootstrap-dotfiles.md` |
| `[deps]`, `[oci]`, `[daemons]`, `[secrets.*]` | Experimental; need `experimental = true` |
| `[_]` | Free-form data that mise ignores |

`include` example for an organization baseline (included file ranks just below the
including file; it cannot contain `[tasks]` or `[settings]`):

```toml
include = [
  "./config/tools.toml",
  "git::https://github.com/myorg/platform.git//mise.toml?ref=v1.2.0",
]
```

Every key and setting: https://mise.jdx.dev/configuration/reference.html and
https://mise.jdx.dev/configuration/settings.html. JSON schema: `schema/mise.json` in the mise repository.
`mise lsp` and `mise fmt` validate and format config files.

## Version requests

| Request | Example | Selects |
| --- | --- | --- |
| Exact | `"24.11.1"` | That release |
| Prefix | `"24"`, `"3.14"` | A release that starts with the prefix. Matches at separators: `1.2` matches `1.2.3`, not `1.20`. |
| `latest` | `"latest"` | The release the backend considers newest |
| Alias | `"lts"` | What the alias stands for (Node.js LTS line) or a `[tool_alias]` entry |
| `prefix:` | `"prefix:1.20"` | Prefix match even when a release has exactly that name |
| `ref:`, `tag:`, `branch:`, `rev:` | `"ref:main"` | A build from a VCS reference, where the backend supports it |
| `path:` | `"path:/opt/homebrew/opt/node@24"` | An existing directory; needs trust |
| `system` | `"system"` | No mise install; the copy already on `PATH` runs |
| `sub-` | `"sub-1:latest"` | Subtract from another request's resolved version |

- No npm-style ranges (`^24`, `>=20`): mise warns, treats them as literal versions and
  fails to install.
- Prefixes and `latest` skip prereleases unless `prerelease = true` is set on the tool.
- Resolution order: lockfile entry, then aliases, then an installed version that matches,
  then the backend's version list. So a new release does not change the environment until
  `mise upgrade` or `mise install tool@prefix`.
- `latest` is not necessarily the highest semver. `version_order = "semver"` fixes
  ordering for aqua, github, gitlab, forgejo and http tools that publish out of order.
- Several versions: `python = ["3.14", "3.13"]`; the first provides the unversioned command.
- `MISE_<TOOL>_VERSION=22` overrides every config file for the commands that see it.

```sh
mise ls --current node           # the version this directory uses
mise latest node@24              # newest available match
mise latest --installed node@24  # installed match
mise outdated                    # configured tools with newer matches
```

## Version files from other managers

`.tool-versions` is always read. Idiomatic files (`.nvmrc`, `.node-version`,
`.python-version`, `.ruby-version`, `.go-version`, `go.mod`, `rust-toolchain.toml`,
`.bun-version`, `package.json` `devEngines`) are read only for enabled tools:

```sh
mise settings add idiomatic_version_file_enable_tools node            # global
mise settings add --local idiomatic_version_file_enable_tools node    # project mise.toml
```

A version in `mise.toml` takes precedence over these files; keep one source of truth.
Tools listed only in `.tool-versions` are not locked by `mise lock`. Convert with
`mise generate config --tool-versions .tool-versions`.

## Backends

A backend is the source mise installs a tool from. A registry short name picks one; an
identifier `backend:name` picks it explicitly and works without a registry entry.

```sh
mise registry ripgrep                    # backends for a short name
mise search markdown                     # fuzzy search the registry
mise search --match-type equal npm:typescript-language-server
mise backends ls
mise use github:BurntSushi/ripgrep@15
mise use 'npm:@biomejs/biome' "cargo:ripgrep[features=pcre2]"
```

Prefer, in order: `packslip:` (publisher-signed), `aqua:` or `github:`/`gitlab:`/`forgejo:`
(release assets), `http:`/`s3:` (your own archives), a language package backend, then a
plugin.

| Backend | Installs | Example | Needs |
| --- | --- | --- | --- |
| `core` | Tools built into mise | `core:node` | nothing |
| `packslip` | Releases with signed manifests | `packslip:github.com/jdx/hk` | a publisher that signs |
| `aqua` | Release assets described by the aqua registry | `aqua:BurntSushi/ripgrep` | a registry entry |
| `github`, `gitlab`, `forgejo` | Release assets from a forge | `github:BurntSushi/ripgrep` | release assets |
| `http`, `s3` | Archives at URLs you provide | `http:my-tool` with `url` | URLs |
| `cargo` | Rust crates | `cargo:eza` | `rust`; `cargo-binstall` for prebuilt binaries |
| `go` | Go modules | `go:github.com/DarthSim/hivemind` | `go` |
| `npm` | npm packages | `npm:prettier` | `node` to run the tool |
| `pypi` (also `pipx:`) | Python packages | `pypi:black` | `uv` or pipx, and `python` |
| `gem` | Ruby gems | `gem:rubocop` | `ruby` |
| `dotnet`, `spm` | NuGet tools, Swift packages | `dotnet:GitVersion.Tool` | the SDK |
| `conda` | Conda packages with dependencies | `conda:ffmpeg` | nothing |
| `vfox` | Lua plugins | `vfox:version-fox/vfox-cmake` | trust in the plugin |
| `asdf` (legacy) | Shell-script plugins | `asdf:MetricMike/asdf-awscli` | bash, Unix |
| `ubi` (deprecated) | Release assets | `ubi:BurntSushi/ripgrep` | migrate to `github:` |

Language package backends install command-line tools into isolated directories. They do
not manage a project's dependencies; those stay in `pyproject.toml`, `package.json`,
`Cargo.toml`, `go.mod` or `Gemfile`. Declare the runtime in the same config
(`mise use node@24 npm:prettier`): mise installs it first but never adds it for you.

## Tool options

```toml
[tools]
node = { version = "24", postinstall = "corepack enable" }
shellcheck = { version = "latest", os = ["linux", "macos"] }
trivy = { version = "latest", minimum_release_age = "1d" }
"cargo:cargo-edit" = { version = "latest", depends = ["rust"] }
rust = { version = "stable", components = ["clippy", "rustfmt"] }
```

| Option | What it does |
| --- | --- |
| `version` | The version request. Use `prefix`, `ref` or `path` keys for those kinds. |
| `os` | Install and use only on these platforms |
| `depends` | Install these tools first |
| `install_env` | Environment for the install commands and `postinstall` |
| `postinstall` | Command to run after install (makes the config need trust) |
| `lazy`, `lazy_bins` | Install on first use of one of its commands |
| `auto_update` | Global config only: update the tool before it runs (`true` or `"6h"`) |
| `minimum_release_age` | Select only versions at least this old |
| `prerelease` | Include prereleases |
| `version_order` | `semver` or `source` |

Backend-specific options (GitHub `matching`, PyPI `extras`, npm, cargo `features`) are on
each backend's page.

## Automatic install and update

| When you run | mise installs | Controlled by |
| --- | --- | --- |
| `mise exec` | Missing tools the config selects | `exec_auto_install` |
| `mise run` | Missing tools the task needs | `task.run_auto_install` |
| An unknown command in an activated shell, or a shim for a missing version | The configured tool that provides it | `not_found_auto_install` |
| A command of a `lazy = true` tool | That tool, on first use | the tool option |

`auto_install = false` turns the first three off. Global tools can self-update with
`auto_update` or `tool_update.global_auto = "12h"`; never in CI, offline or with
`locked = true`. Upgrades prune the replaced version after `upgrade.prune_after`.

## Trust and security

A `mise.toml` loads without trust only when it has no template syntax (`{{`, `{%`, `{#`)
and contains nothing but `min_version`, `[tools]` entries with plain version strings, and
`[tasks]` without `secrets`. Anything else needs trust: tool option tables, `[env]`,
`[hooks]`, `[settings]`, `[tool_alias]`, `include`, `path:` versions.

```sh
mise trust                # trust the nearest untrusted config
mise trust --show         # status of config files here and above
mise trust --all          # this directory, parents and subdirectories
mise trust --untrust      # remove trust
mise trust --ignore       # never load this config
```

- `mise run`, `mise install`, `mise exec` and `mise watch` trust their active config
  automatically when typed in a terminal. The MCP server and hooks never do.
- Trusting a config in a repository's main checkout also trusts the same path in its git
  worktrees.
- `trusted_config_paths = ["~/work"]` in global settings trusts a tree.
- `MISE_SAFE=1` (safe mode) ignores project `[env]`, never runs `_.source`, and never
  fetches includes: use it to inspect a repository you have not reviewed.
- Paranoid mode (`MISE_PARANOID=1`, https://mise.jdx.dev/paranoid.html) requires
  content-bound trust for every project config and pinned remote includes.
- `minimum_release_age` defaults to `24h` for every backend that reports release dates.
  Order of precedence: `--minimum-release-age` flag, the tool option, the setting.
  Exempt tools with `minimum_release_age_excludes = ["trivy", "npm:*"]`.
- Sandboxing (`--deny-net`, `--deny-write`, `--allow-read` on `mise exec` and tasks) is
  off by default and Linux/macOS only: https://mise.jdx.dev/sandboxing.html

## Hooks

```toml
[hooks]
enter = "mise install --quiet"                      # needs mise activate
leave = { run = "echo bye", shell = "bash -c" }
cd = { task = "check-tools" }
postinstall = ["npm install", { task = "codegen" }]

[[watch_files]]
patterns = ["uv.lock"]
run = "uv sync --locked"
```

`cd`, `enter`, `leave` and `watch_files` run only in activated shells. `preinstall` and
`postinstall` run with shims and `mise install` too. Hook commands are Tera templates and
run with the project's tools and `[env]`; a failing hook prints a warning and the rest
still run.

## Deprecated syntax

| Deprecated | Use instead | Removed in |
| --- | --- | --- |
| Top-level `env_file`, `dotenv` | `env._.file` | 2027.4.0 |
| Top-level `env_path` | `env._.path` | 2027.4.0 |
| `env.mise.*` | `env._.*` | 2026.12.0 |
| `value`/`values` in a `_.file`, `_.path`, `_.source` table | `path` | 2026.12.0 |
| `[alias]` | `[tool_alias]` | no date |
| `experimental_monorepo_root` | `monorepo_root` | 2027.12.0 |
| Tera `arg()`, `option()`, `flag()` in task `run` | a `usage` spec | deprecated |
| `ubi:` backend | `github:` | deprecated |
| `mise tasks add` replacing a task silently | pass `--force` | warns 2027.5.0, refused 2028.5.0 |
| Dots in `conf.d` fragment names | hyphens | deprecated |

---
name: mise
description: "Install, configure and operate mise (mise-en-place, jdx/mise): dev tool versions, env vars, tasks, lockfiles, shims, CI, Docker, MCP and agent shells. Use whenever mise, mise.toml, .tool-versions, mise use/install/exec/run, replacing asdf/nvm/pyenv, or picking a project's tool versions or task runner comes up, even if mise is not named."
---

# mise

mise (pronounced "meez", https://github.com/jdx/mise) does three jobs from one `mise.toml`:
it installs and selects **dev tools** per directory, sets **environment variables**, and
runs **tasks**. It also has a lockfile, an MCP server, an LSP server, and machine setup
(`mise bootstrap`, `mise dotfiles`).

Verified against the mise **2026.11.x** docs and registry. mise ships several releases a
week and renames or deprecates things often. Treat this skill as a map: confirm details
with `mise <command> --help` or the page listed in `references/docs-map.md`.

## Operating rules

1. **Look before writing.** In the project, run `mise --version`, `mise config ls`,
   `mise ls --current` and `mise tasks ls`. An existing `mise.toml`, `.tool-versions`,
   `mise.lock` or `mise-tasks/` sets the conventions to follow.
2. **Verify names, never guess.** `scripts/check-tools.sh <name>...` (or
   `mise registry <name>`) confirms a short name; `mise search <text>` finds one. A name
   that is not in the registry needs an explicit backend, such as `pipx:ryl`.
3. **Prefer the CLI for simple changes**: `mise use`, `mise unuse`, `mise set`,
   `mise settings`, `mise tasks add`. They pick the right file and keep the lockfile in
   step. Hand-edit structured sections, then run `mise fmt` and `mise tasks validate`.
4. **Project scope by default.** `mise use node@24` writes the project `mise.toml`. Use
   `-g` only for a personal default; it affects every directory. Run from `$HOME`,
   `mise use` writes the global config even without `-g`.
5. **Outside interactive shells, do not rely on activation.** In scripts, CI, Docker and
   agent shells use `mise exec -- <cmd>` or `mise run <task>`; both load tools and `[env]`
   and install what is missing. Write `mise run build`, not the `mise build` shorthand.
6. **Respect trust.** A config with `[env]`, hooks, templates, `[settings]`, tool option
   tables or `include` needs `mise trust`. Read the file first: those sections run code.
7. **Expect the 24-hour release delay.** `minimum_release_age` defaults to `24h`, so
   `latest` and prefixes skip releases from the last day. Name the exact version or pass
   `--minimum-release-age 0s` when a brand-new release is needed.
8. **Dry-run what changes a machine.** The bundled scripts, `mise bootstrap`,
   `mise dot apply`, `mise prune` and `mise implode` all take `--dry-run`. Use it first
   and show the result.
9. **State what changed.** Show the resulting `mise.toml` fragment and the command that
   proves it (`mise exec -- node --version`, `mise run test`).

## Everyday commands

| Goal | Command |
| --- | --- |
| Add or change a project tool | `mise use node@24` (`--pin` writes the exact version) |
| Personal default | `mise use -g node@24` |
| Personal override in a shared repo | `mise use --env local node@26` (writes `mise.local.toml`; gitignore it) |
| Install what the config declares | `mise install` (`--locked` to require `mise.lock`) |
| Run without activation | `mise exec -- node --version`, `mise run test` |
| Run a version once | `mise exec node@24 -- node --version` |
| Show selection and origin | `mise ls --current`, `mise tool ripgrep`, `mise which rg`, `mise config ls` |
| Versions and updates | `mise ls-remote node 24`, `mise outdated`, `mise upgrade`, `mise upgrade --bump node` |
| Remove | `mise unuse node` (config), `mise uninstall node@22` (files), `mise prune --dry-run` |
| Env vars | `mise set KEY=value`, `mise unset KEY`, `mise env --json-extended` |
| Settings | `mise settings`, `mise settings jobs=4`, `mise settings add <list> <item>` (`--local` for the project) |
| Tasks | `mise tasks ls`, `mise tasks info <t>`, `mise run <t>`, `mise watch <t>`, `mise tasks validate` |
| Lock | `mise lock --platform linux-x64,macos-arm64`, `mise install --locked` |
| Diagnose | `mise doctor`, `mise doctor path`, `MISE_DEBUG=1 mise <cmd>`, `mise cache clear <tool>` |

## Minimal config

```toml
min_version = "2026.10.0"

[tools]
node = "24"                                   # prefix: newest 24.x
python = "3.14"
uv = "latest"
"npm:prettier" = "3"                          # explicit backend; quote the key
shellcheck = { version = "latest", os = ["linux", "macos"] }

[env]
NODE_ENV = { default = "development" }        # only when not already set
_.file = ".env"                               # optional; a missing file is not an error
_.path = ["bin", "{{config_root}}/node_modules/.bin"]

[tasks.test]
description = "Run the test suite"
run = "uv run --locked pytest"
```

Precedence, later wins: `/etc/mise` < `~/.config/mise/config.toml` < parent directories <
project `mise.toml` < `mise.local.toml` < `~/.config/mise/config.override.toml`. Sections
merge per key, not per file. No npm-style ranges (`^24`, `>=20`).

Facts that are easy to get wrong:

- Shims put tools on `PATH` but do not export `[env]` into the shell or run `cd` hooks.
- Inline task `run` stops at the first error; a shebang script or custom `shell` does not.
  Add `set -euo pipefail`.
- mise's flags go before the task name: `mise run --dry-run build --release`.
- Set `PATH` only through `_.path`. `MISE_*` variables in `[env]` do not configure mise.
- Backends carry requirements: `pipx:` tools need `uv`, `npm:` tools need `node`,
  `cargo:` tools need `rust`. Declare the runtime in the same config.
- `mise.local.toml` is plain text, not secret storage.

## Where to read next

Read the reference that matches the task before acting; each has a table of contents.

| Task | Read |
| --- | --- |
| Install mise, activate a shell, shims, completions, update, uninstall | `references/install-and-activation.md` |
| Config files, precedence, write targets, version requests, backends, tool options, trust, hooks, deprecated keys | `references/configuration.md` |
| `[env]`, directives, templates, `[vars]`, secrets (SOPS, age, fnox), redaction | `references/env-and-secrets.md` |
| TOML and file tasks, `usage` arguments, templates, running, watch, sharing | `references/tasks.md` |
| Python + uv, Node + pnpm, Bun, Go, Rust | `references/languages.md` |
| `mise.lock`, GitHub Actions, GitLab CI, Docker, dev containers | `references/lockfile-ci-docker.md` |
| Claude Code hook, Codex, MCP server, `mise skills`, editors, `mise lsp` | `references/agents-mcp-editors.md` |
| `mise bootstrap`, host packages, `mise dotfiles`, global config layout | `references/bootstrap-dotfiles.md` |
| Which tool name, command and backend; `ryl`; overlaps | `references/tool-catalog.md` |
| Something does not work | `references/troubleshooting.md` |
| Upstream page for a topic | `references/docs-map.md` |

## Scripts

Run a script with `--help` first, and with `--dry-run` before letting it change anything.
Paths are relative to this skill's directory.

| Script | Purpose |
| --- | --- |
| `scripts/install-mise.sh` | POSIX sh. Installs mise through the `mise.run` installer; `--version`, `--path`, `--musl`, `--activate bash\|zsh\|fish\|auto`, `--shims`, `--completions`, `--dry-run`. Idempotent. |
| `scripts/install-mise.ps1` | Windows equivalent: `-Version`, `-Activate`, `-ShimsOnPath`. |
| `scripts/apply-global-config.sh` | Copies fragments from `assets/global/conf.d/` into `~/.config/mise/conf.d/`; `--list`, `--all`, `--install`, `--force` (keeps `.bak`), `--dry-run`. Never overwrites without `--force`. |
| `scripts/check-tools.sh` | Looks up tool names in the registry; prints `ok`, `explicit` or `missing`; exit 1 when any is missing. |
| `scripts/setup_claude_hook.py` | Merges the mise `SessionStart` hook into a Claude Code `settings.json`; `--project DIR`, `--user`, `--shell`, `--mise-bin`, `--dry-run`. Idempotent. |

```sh
sh scripts/install-mise.sh --dry-run --activate auto --completions
bash scripts/apply-global-config.sh --dry-run runtimes shell git lint
bash scripts/check-tools.sh ripgrep gh awscli ryl
python3 scripts/setup_claude_hook.py --project . --dry-run
```

Installing software and editing shell startup files changes the user's machine: show the
dry run and get agreement before the real run, unless the user already asked for it.

## Assets

Copy an asset, then adapt it to the project; do not paste one unchanged over an existing
file. After copying a project template run `mise fmt`, `mise install` and
`mise tasks validate`.

| Asset | Use |
| --- | --- |
| `assets/project/python-uv.mise.toml` | Python project with uv, ruff, mypy, pytest tasks |
| `assets/project/node-pnpm.mise.toml` | Node.js project with pnpm tasks |
| `assets/project/go.mise.toml` | Go project with golangci-lint and gofumpt |
| `assets/project/rust.mise.toml` | Rust project with clippy, rustfmt, nextest |
| `assets/project/iac-aws.mise.toml` | OpenTofu, tflint, cfn-lint, trivy, AWS CLI tasks |
| `assets/project/hygiene.mise.toml` | Repo hygiene: shell, YAML (ryl), TOML, Markdown, workflows, spelling, links, secrets |
| `assets/global/config.toml` | Global `[settings]` starter |
| `assets/global/conf.d/*.toml` | Global tool sets: runtimes, shell, git, security, cloud, lint, agents |
| `assets/tasks/bash-task` | File task template with `#MISE` and `#USAGE` headers |
| `assets/tasks/python-uv-task.py` | Python file task with PEP 723 inline dependencies |
| `assets/ci/github-actions.yml` | Workflow using `jdx/mise-action` |
| `assets/ci/Dockerfile`, `assets/ci/dockerignore` | Image build on the official mise image |
| `assets/ci/pre-commit-config.yaml` | prek / pre-commit config that runs mise tasks and ryl |
| `assets/agents/claude-settings-hook.json` | Claude Code `SessionStart` hook |
| `assets/agents/mcp.json`, `assets/agents/vscode-mcp.json` | MCP server entries for `mise mcp` |

The commands inside the task templates belong to third-party tools (ruff, tflint, ryl,
gitleaks and others). Check each against the version the project installs.

## Workflows

**Adopt mise in an existing project**

1. Inspect: `mise config ls`, `mise ls --current`, and the version files already present
   (`.tool-versions`, `.nvmrc`, `.python-version`, `go.mod`, `rust-toolchain.toml`).
2. Declare tools with `mise use <tool>@<version>`, or enable the existing files with
   `mise settings add --local idiomatic_version_file_enable_tools <tool>`.
3. Wrap the commands the project already runs as tasks; start from an `assets/project/`
   template when the project has none.
4. Put personal overrides in `mise.local.toml` and add it to `.gitignore`.
5. `mise lock`, then commit `mise.toml` and `mise.lock`.
6. Prove it: `mise install && mise run <task>`.

**Set up a workstation**

1. `sh scripts/install-mise.sh --dry-run --activate auto --shims --completions`, then the
   real run.
2. `bash scripts/apply-global-config.sh --list`, choose fragments, dry-run, apply,
   then `mise install`.
3. `mise doctor` in a new terminal must report `activated: yes`.

**Make a coding agent use the project's tools**

1. `mise install` in the project.
2. `python3 scripts/setup_claude_hook.py --project . --dry-run`, then without `--dry-run`.
3. Optionally add the MCP server: `claude mcp add mise -- mise --cd "$PWD" mcp`.
4. Until the hook is active, wrap commands in `mise exec --`.

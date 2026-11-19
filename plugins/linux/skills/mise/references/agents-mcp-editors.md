# Coding agents, MCP and editors

Contents: [Why agents miss mise tools](#why-agents-miss-mise-tools) - [Claude Code hook](#claude-code-hook) -
[Codex and other agents](#codex-and-other-agents) - [Worktrees](#worktrees) - [MCP server](#mcp-server) -
[Agent skills from tools](#agent-skills-from-tools) - [Editors](#editors) - [Language server](#language-server)

Source pages: https://mise.jdx.dev/agents.html, /mcp.html, /ide-integration.html

## Why agents miss mise tools

A coding agent runs each command in a non-interactive shell. `mise activate` in `.zshrc`
or `.bashrc` never runs there, so the agent gets neither the project's tools nor `[env]`
unless one of these is true:

| Approach | Tools | `[env]` in the shell | Follows `cd` | Setup |
| --- | --- | --- | --- | --- |
| `mise hook-env` before each command | Yes | Yes | Between commands | One hook |
| `mise exec -- cmd` / `mise run task` | Yes | Yes (for that command) | Yes | None |
| Shims on `PATH` | Yes | Only for the launched tool | Yes | Login profile |

mise has no agent-specific mode. `mise hook-env` is what `mise activate` runs before each
prompt, and it works without a prompt.

## Claude Code hook

Claude Code sources the file named by `$CLAUDE_ENV_FILE` before each Bash command. Only
`SessionStart`, `Setup`, `CwdChanged` and `FileChanged` hooks can write to it. Add to
`~/.claude/settings.json` or the project's `.claude/settings.json`
(`assets/agents/claude-settings-hook.json`; `scripts/setup_claude_hook.py` merges it into
an existing file):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "[ -n \"$CLAUDE_ENV_FILE\" ] && echo 'eval \"$(mise hook-env -s bash)\"' >> \"$CLAUDE_ENV_FILE\"; true"
          }
        ]
      }
    ]
  }
}
```

- The appended line, `eval "$(mise hook-env -s bash)"`, runs before every command, so it
  follows the directory the agent is in when a command starts. It does not refresh inside
  one command: in `cd subproject && node --version`, `node` is still the parent's.
- Use `-s zsh` if Claude Code runs commands in zsh.
- The line must find `mise`. If `command -v mise` fails in the agent's shell, write the
  absolute path: `eval "$(~/.local/bin/mise hook-env -s bash)"`.
- When nothing changed, `hook-env` prints nothing and costs a few milliseconds.
- For one fixed environment for the whole session instead:
  `mise env -s bash >> "$CLAUDE_ENV_FILE"` (evaluated once, does not follow `cd`).
- mise does not install missing tools here. Run `mise install` in the project first. A
  config mise does not trust is not loaded.

## Codex and other agents

Codex runs commands through the login shell by default, so put shims in the login profile
(`eval "$(mise activate zsh --shims)"` in `~/.zprofile`) and run `mise install`. Shims are
weaker: `echo "$FOO"` in the shell sees nothing from `[env]`, and a tool the current
directory does not select fails with `No version is set for shim`.

Any agent that sources a file before each command, or lets you point its shell at an rc
file, can use the `hook-env` line. A command that runs once at session start is not
enough, because it changes only that process. When nothing else is available, wrap
commands in `mise exec --`.

Working habits for an agent inside a mise project:

- Run project commands as tasks: `mise tasks ls`, then `mise run <task>`.
- Prefer `mise exec -- <cmd>` to guessing whether the shell is activated.
- `mise watch <task> --once` blocks until a source changes, runs the task once and exits
  with its status. Use it instead of a sleep-and-poll loop.
- `mise run --output summary <task>` prints nothing for passing tasks and full output for
  failures, which keeps logs short.

## Worktrees

Agents often work in a git worktree such as `.claude/worktrees/<name>`. The `hook-env`
line needs nothing per worktree. Trusting a config in the main checkout also trusts the
same path in its worktrees. Installed tools live in mise's data directory, so a new
worktree does not reinstall them. `.miserc.local.toml` and `mise.local.toml` are per
checkout and must be created in each worktree.

## MCP server

`mise mcp` runs a Model Context Protocol server over stdin and stdout. Nothing listens on
a port.

```sh
claude mcp add mise -- mise --cd /absolute/path/to/project mcp
```

```json
{
  "mcpServers": {
    "mise": {
      "command": "/absolute/path/to/mise",
      "args": ["--cd", "/absolute/path/to/project", "mcp"]
    }
  }
}
```

Always pass `--cd`; without it the server uses the client's working directory. Use the
absolute path to mise (`command -v mise`), because GUI clients often do not inherit the
shell's `PATH`. VS Code uses a `servers` key in `.vscode/mcp.json`
(`assets/agents/vscode-mcp.json`).

| Resource | Contents |
| --- | --- |
| `mise://tools` | Active tool versions, requests, install paths, source config |
| `mise://tools?include_inactive=true` | Plus other installed versions |
| `mise://tasks` | Task definitions, including monorepo subprojects |
| `mise://env` | Resolved environment variable names and values |
| `mise://config` | Active config file paths and the project root |

| Tool | Arguments | What it does |
| --- | --- | --- |
| `list_commands` | `include_hidden` | Lists mise commands with their effect: `read`, `write` or `destructive` |
| `run_task` | `task`, `args` | Runs a task with dependencies and environment; returns output when it finishes |
| `install_tool` | `tool`, `version` | Installs a tool, as `mise install` does |

Security and behavior:

- `mise://env` evaluates the project's environment config and returns real values,
  including secrets.
- The server cannot show the trust prompt. Reads fail with `Failed to load config` until
  you run `mise trust` in the project. `run_task` and `install_tool` refuse untrusted
  projects.
- To inspect an untrusted project, add `"env": { "MISE_SAFE": "1" }` to the server entry:
  `mise://env` returns no project values and `run_task` fails; the other resources work.
- `run_task` runs without stdin and sets `MISE_YES=1`. Output is not streamed. Limit run
  time with the `task.timeout` setting.
- `install_tool` refuses tool options (`"tool[option=value]"`), because options such as
  `postinstall` are commands.
- The server loads config once. After editing `mise.toml` or task files, restart it from
  the client. `run_task` always uses the current files.

## Agent skills from tools

A tool installed with the `packslip:` backend may ship an agent skill (a directory with
`SKILL.md`). mise can link the skill for the active version:

```sh
mise skills ls              # skills the active tools ship
mise skills sync            # link into .agents/skills (and .claude/skills)
mise skills sync --global   # link under the home directory instead
mise skills sync --prune    # remove links for skills that are no longer active
```

`skills.auto_sync` re-links after every install and `mise use`.

## Editors

An editor's terminal, language servers, debugger and extensions can each run with a
different environment.

| Need | Integration |
| --- | --- |
| A fixed executable or SDK directory | `mise which node`, `mise where java`, or the `~/.local/share/mise/installs/<tool>/global` link |
| A tool that follows the current project | Shims on `PATH` |
| A command with the project environment | `mise exec -- command` |
| Features that follow config changes | An editor plugin |

GUI editors read the login shell's environment. Put `eval "$(mise activate zsh --shims)"`
in `~/.zprofile` (bash: the login file that already exists), then restart the editor; some
desktops need a new login session.

| Editor | Plugin |
| --- | --- |
| VS Code | mise-vscode (`hverlin.mise-vscode`) |
| JetBrains IDEs | intellij-mise |
| Neovim | miser.nvim |
| Emacs | mise.el |
| Zed | mise-zed |

Neovim without a plugin (`init.lua`):

```lua
-- Prepend mise shims to PATH
vim.env.PATH = vim.env.HOME .. "/.local/share/mise/shims:" .. vim.env.PATH
```

Vim (`~/.vimrc`): `let $PATH = $HOME . '/.local/share/mise/shims:' . $PATH`. If
`MISE_DATA_DIR` is set, use `$MISE_DATA_DIR/shims`. On Windows add
`%LOCALAPPDATA%\mise\shims` to the user `Path`.

Diagnose a mismatch from the project directory: compare `mise which node` and
`mise exec -- node --version` with what the editor runs.

## Language server

`mise lsp` is a Language Server Protocol server for mise config files (`mise.toml`,
`.mise.toml`, `mise.<env>.toml`, `mise.local.toml`, `mise/config.toml`, `conf.d` files).
It ignores other TOML files. It provides diagnostics (syntax, unknown keys, wrong types,
deprecated keys, unknown task names, dependency cycles), completion of keys, tool names
and task names, hover documentation, quick fixes, formatting (same as `mise fmt`), go to
definition and rename for tasks. Without an editor, run `mise fmt --check` and
`mise tasks validate`.

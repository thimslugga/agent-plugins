# Bash LSP Agent Plugin

Connects Claude Code to [bash-language-server](https://github.com/bash-lsp/bash-language-server)
so Claude gets code intelligence for shell scripts:

- Diagnostics after each edit. ShellCheck findings are fed back to Claude, so it
  sees unquoted variables and similar problems without running a linter.
- An `LSP` tool for go-to-definition, find references, and symbol lookup on
  functions and variables, including across `source`d files.

## Prerequisites

Install these on the `PATH` of the shell that starts `claude`:

- `bash-language-server`: `npm install -g bash-language-server`
- `shellcheck`: required for diagnostics
- `shfmt`: optional, used for formatting

## Installation

Install from this repository's marketplace:

```text
/plugin marketplace add thimslugga/agent-plugins
/plugin install bash-lsp@agent-plugins
```

Or load the plugin for one session from a checkout:

```bash
claude --plugin-dir plugins/bash-lsp
```

The server starts the first time Claude edits a matching file. Run `/plugin` and
open the **Errors** tab if no diagnostics appear.

## Kiro

`dev.kiro/settings/lsp.json` holds the same server in Kiro CLI format. Kiro
reads LSP config from the workspace file `.kiro/settings/lsp.json`, so merge the
`bash` entry into that file and restart Kiro CLI.

## Limitations

- Only files ending in `.sh` or `.bash` are matched. Scripts with a shebang but
  no extension are not sent to the server.
- Claude Code does not start plugin language servers in cloud sessions.
- `.lsp.json` is Claude Code specific. LSP servers are not a portable Agent
  Plugins 1.0 component.

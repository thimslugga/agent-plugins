# Documentation map

mise changes weekly. When a detail matters and the installed version differs from
2026.11.x, read the upstream page. `mise <command> --help` is authoritative for flags.

| Topic | URL |
| --- | --- |
| Repository, releases, changelog | https://github.com/jdx/mise |
| Index for LLMs | https://mise.jdx.dev/llms.txt |
| Getting started | https://mise.jdx.dev/getting-started.html |
| Installing mise | https://mise.jdx.dev/installing-mise.html |
| Shell setup (activation, completions) | https://mise.jdx.dev/shell-setup.html |
| Walkthrough: adopt mise in a project | https://mise.jdx.dev/walkthrough.html |
| Configuration (`mise.toml`) | https://mise.jdx.dev/configuration.html |
| Settings | https://mise.jdx.dev/configuration/settings.html |
| Config environments (`MISE_ENV`) | https://mise.jdx.dev/configuration/environments.html |
| `MISE_*` environment variables | https://mise.jdx.dev/configuration/environment-variables.html |
| Dev tools | https://mise.jdx.dev/dev-tools/ |
| Version requests and version files | https://mise.jdx.dev/dev-tools/versions.html |
| Backends | https://mise.jdx.dev/dev-tools/backends/ |
| Shims | https://mise.jdx.dev/dev-tools/shims.html |
| Lockfile | https://mise.jdx.dev/dev-tools/mise-lock.html |
| GitHub tokens | https://mise.jdx.dev/dev-tools/github-tokens.html |
| Registry (short names) | https://mise.jdx.dev/registry.html |
| Tools and stats listing | https://mise-tools.jdx.dev/ |
| Environments (`[env]`) | https://mise.jdx.dev/environments/ |
| Secrets | https://mise.jdx.dev/environments/secrets/ |
| Templates (Tera) | https://mise.jdx.dev/templates.html |
| Tasks | https://mise.jdx.dev/tasks/ |
| TOML tasks | https://mise.jdx.dev/tasks/toml-tasks.html |
| File tasks | https://mise.jdx.dev/tasks/file-tasks.html |
| Task templates | https://mise.jdx.dev/tasks/templates.html |
| Running tasks | https://mise.jdx.dev/tasks/running-tasks.html |
| Task arguments | https://mise.jdx.dev/tasks/task-arguments.html |
| Task configuration reference | https://mise.jdx.dev/tasks/task-configuration.html |
| Monorepo tasks | https://mise.jdx.dev/tasks/monorepo.html |
| Hooks | https://mise.jdx.dev/hooks.html |
| IDE integration | https://mise.jdx.dev/ide-integration.html |
| Coding agents | https://mise.jdx.dev/agents.html |
| MCP server | https://mise.jdx.dev/mcp.html |
| Continuous integration | https://mise.jdx.dev/continuous-integration.html |
| Security, trust, release age | https://mise.jdx.dev/security.html |
| Dotfiles | https://mise.jdx.dev/dotfiles.html |
| Bootstrap | https://mise.jdx.dev/bootstrap.html |
| Tips and tricks | https://mise.jdx.dev/tips-and-tricks.html |
| Troubleshooting | https://mise.jdx.dev/troubleshooting.html |
| CLI reference (`/cli/<command>.html`) | https://mise.jdx.dev/cli/ |
| Cookbook index | https://mise.jdx.dev/mise-cookbook/ |
| Cookbook: Python | https://mise.jdx.dev/mise-cookbook/python.html |
| Cookbook: Node.js | https://mise.jdx.dev/mise-cookbook/nodejs.html |
| Cookbook: Docker | https://mise.jdx.dev/mise-cookbook/docker.html |
| Cookbook: scaffolding tasks (presets) | https://mise.jdx.dev/mise-cookbook/presets.html |
| Language: Python | https://mise.jdx.dev/lang/python.html |
| Language: Node.js | https://mise.jdx.dev/lang/node.html |
| Language: Bun | https://mise.jdx.dev/lang/bun.html |
| Language: Go | https://mise.jdx.dev/lang/go.html |
| Language: Rust | https://mise.jdx.dev/lang/rust.html |
| Usage spec (task arguments) | https://usage.jdx.dev/spec/ |
| ryl (YAML linter) | https://github.com/owenlamont/ryl, https://ryl-docs.pages.dev/ |
| ryl hooks for prek and pre-commit | https://github.com/owenlamont/ryl-pre-commit |

The docs source is the `docs/` directory of the repository, and the registry is
`registry/<name>.toml`. Cloning the repository (`git clone --depth 1 https://github.com/jdx/mise`)
and reading those files is the most reliable way to check a detail for the current
release.

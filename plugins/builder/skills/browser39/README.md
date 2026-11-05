# browser39-websearch

Agent skill for searching and fetching the web through the browser39 headless-browser MCP server.

browser39 is a single ~52MB Rust binary (embedded V8, no external browser) exposing 29 MCP tools: search, fetch, click, fill, DOM queries, cookies, sessions, and config management. This skill pairs the binary with a usage strategy: CAPTCHA-aware search engine rotation and token-efficient content preselection.

## Layout

- `SKILL.md` — the skill contract: usage strategy plus an Installation section.
- `scripts/install-browser39` — installs the browser39 binary (latest GitHub release for your OS/arch) into `~/.local/bin`. Flags: `--version`, `--dir`, `--force`, `--dry-run`.
- `agents/openai.yaml` — Codex UI metadata.

## Usage

1. Install: `./scripts/install-browser39`
2. Verify: `browser39 --version`
3. Register in your MCP client: `{"mcpServers": {"browser39": {"command": "browser39", "args": ["mcp"]}}}`
4. Load this skill whenever using browser39's MCP tools for web search/fetch.

## Harness notes

- Requires shell and network access.
- The installer needs only `curl` on PATH: no Rust, npm, or browser. `BROWSER39_INSTALL_DIR` overrides the install dir, like `--dir`.
- `SKILL.md` is the usage contract: engine rotation on CAPTCHA signals, two-step section-preselection fetches, DOM queries for single values.

## Testing

- `bash -n scripts/install-browser39`
- `shellcheck -S warning scripts/install-browser39`
- `shfmt -d scripts/install-browser39`
- `./scripts/install-browser39 --dry-run`
- Full run into a temp dir: `./scripts/install-browser39 --dir /tmp/b39-test`, then `/tmp/b39-test/browser39 --version`

## Attribution

- The browser39 binary: [alejandroqh/browser39](https://github.com/alejandroqh/browser39) (GitHub releases, fetched by `scripts/install-browser39`).
- The skill itself (`SKILL.md`, `license: MIT`, `version: 1.1.0`), `scripts/install-browser39`, `README.md`, and `agents/openai.yaml` are original to this install; there is no upstream skill.

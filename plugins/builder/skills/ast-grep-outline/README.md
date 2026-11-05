# ast-grep-outline

Cheap structural map of a codebase via `ast-grep outline`: top-level items (imports, functions, classes, structs, interfaces, modules, enums) and their direct members, with line numbers, before reading full source. Read code in stages: find candidate files, outline them, then open only the source range the outline points to.

Ported from ast-grep/agent-skill (MIT). See Attribution below. Companion to the `ast-grep` skill (structural code search with AST rules).

## Layout

- `SKILL.md`: the skill: when to use it, the argument guide (`--items`, `--view`, `--match`, `--type`, `--pub-members`, `--json=stream`), and the limits (local syntax only: no reference resolution, type inference, or call graphs)
- `agents/openai.yaml`: Codex UI metadata (`display_name`, `short_description`); other harnesses ignore it

## Usage

Loads when exploring or modifying a codebase and a cheap structural map helps first: table of contents of a file before editing, public surface of an unfamiliar directory, members of a known symbol with line numbers, which files import a package, or the resulting structure after an edit.

Prerequisite: the `ast-grep` binary. Installed here at `~/workspace/bin/ast-grep` (v0.45.3). Note the name: upstream's `sg` alias is deprecated, and on this box `/usr/bin/sg` is shadow-utils' switch-group tool, not ast-grep. Use `ast-grep`.

Upstream install options: `brew install ast-grep`, `npm install -g @ast-grep/cli`, or `cargo install ast-grep` (installs it as the deprecated `sg` name).

Pair with the `ast-grep` skill: outline first to find candidates, then `ast-grep run`/`scan` or `rg` for reference and call-graph questions outline cannot answer.

## Harness setup

| Harness | Install to |
|---|---|
| Claude Code | `~/.claude/skills/ast-grep-outline/` |
| Codex | `~/.codex/skills/ast-grep-outline/` or project `.agents/skills/ast-grep-outline/` |
| Kiro | `~/.kiro/skills/ast-grep-outline/` or project `.kiro/skills/ast-grep-outline/` |
| Muse | `~/workspace/skills/ast-grep-outline/` |
| Pi | `~/.pi/agent/skills/ast-grep-outline/` or project `.agents/skills/ast-grep-outline/` |

## Testing

- SKILL.md frontmatter parses as YAML (`name`, `description`, `license`); `name` matches the directory.
- `agents/openai.yaml` parses as YAML.
- Documented commands verified against ast-grep 0.45.3: `outline <file>`, `--items imports`/`exports`, `--view signatures`/`expanded`, `--match <regex> --type class`, directory scan, `--json=stream`.

## Attribution

- Upstream: [ast-grep/agent-skill](https://github.com/ast-grep/agent-skill) (main branch, fetched 2026-10-04). Path: `ast-grep/skills/outline/SKILL.md`.
- License: MIT, per the repo README ("This skill follows ast-grep's MIT license for any included documentation or examples"). The repo ships no LICENSE file.
- Changes in this port: added `license: MIT` to the SKILL.md frontmatter; added `README.md` and `agents/openai.yaml`.

# ast-grep

Structural code search with ast-grep: translate natural-language queries into AST rules instead of text matching. The skill walks a five-step workflow (understand the query, write example code, write the rule, test it with the CLI, then search the codebase), with the full rule syntax in `references/rule_reference.md`.

Ported from ast-grep/agent-skill (MIT). See ATTRIBUTION.md.

## Layout

- `SKILL.md`: the skill: when to use it, the five-step rule workflow, CLI commands (`run`, `scan`, `--debug-query`, `--json`), rule-writing tips, common use cases
- `references/rule_reference.md`: comprehensive ast-grep rule syntax: atomic, relational, and composite rules, metavariables
- `agents/openai.yaml`: Codex interface metadata
- `agents/harness-notes.md`: per-harness install paths

## Usage

Loads when the user needs structural code search: "find all async functions without error handling", "find setState calls inside useEffect", "find functions with more than 3 parameters". Plain-text searches stay with grep/rg.

Prerequisite: the `ast-grep` binary. Installed here at `~/workspace/bin/ast-grep` (v0.45.3). Note the name: upstream's `sg` alias is deprecated, and on this box `/usr/bin/sg` is shadow-utils' switch-group tool, not ast-grep. Use `ast-grep`.

## Harness setup

| Harness | Install to |
|---|---|
| Claude Code | `~/.claude/skills/ast-grep/` |
| Codex | `~/.codex/skills/ast-grep/` or project `.agents/skills/ast-grep/` |
| Kiro | `~/.kiro/skills/ast-grep/` or project `.kiro/skills/ast-grep/` |
| Muse | `~/workspace/skills/ast-grep/` |
| Pi | `~/.pi/agent/skills/ast-grep/` or project `.agents/skills/ast-grep/` |

## Testing

- SKILL.md frontmatter parses as YAML (`name`, `description`, `license`); `name` matches the directory.
- `references/rule_reference.md` is the file SKILL.md points to.
- `agents/openai.yaml` parses as YAML.
- Workflow verified end to end against ast-grep 0.45.3: inline rules via `--stdin`, rule files via `--rule`, `run --pattern`, composite `all`/`not`/`has` rules, `--json` output schema, `--debug-query=pattern`.
- Observed upstream discrepancy: the repo README says a zero-match run exits successfully; on 0.45.3 a zero-match `run` exits 1. The skill body makes no such claim, so nothing in the port needed changing.

## Not installed

The upstream repo ships a second skill, `ast-grep-outline` (cheap structural codebase maps via `ast-grep outline`); it was not installed here. Say the word and it goes in as its own skill.

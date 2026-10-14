# Harness notes: ast-grep-outline

Per-harness differences for the `ast-grep-outline` skill. The skill body is harness-neutral; this file records what changes per runtime.

## Install paths

| Harness | Location |
|---|---|
| Claude Code | `~/.claude/skills/ast-grep-outline/` |
| Codex | `~/.codex/skills/ast-grep-outline/` or project `.agents/skills/ast-grep-outline/` |
| Kiro | `~/.kiro/skills/ast-grep-outline/` or project `.kiro/skills/ast-grep-outline/` |
| Muse | `~/workspace/skills/ast-grep-outline/` |
| Pi | `~/.pi/agent/skills/ast-grep-outline/` or project `.agents/skills/ast-grep-outline/` |

## Notes

- Prerequisite on every harness: the `ast-grep` binary on PATH. Upstream install options: `brew install ast-grep`, `npm install -g @ast-grep/cli`, `cargo install ast-grep` (this installs it as `sg`, which upstream now deprecates in favor of `ast-grep`).
- The skill's examples all use the `ast-grep` command name. Do not substitute `sg`: it is deprecated upstream, and on some Linux boxes `/usr/bin/sg` is shadow-utils' switch-group tool.
- Docs-only skill (SKILL.md, no references or scripts), no hooks, so no harness caveats there.
- Companion to the `ast-grep` skill: outline first to find candidates, then `ast-grep run`/`scan` or `rg` for reference and call-graph questions outline cannot answer.

## Codex metadata

`agents/openai.yaml` carries Codex UI metadata (`display_name`, `short_description`). It is ignored by other harnesses.

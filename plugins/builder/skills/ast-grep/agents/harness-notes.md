# Harness notes: ast-grep

Per-harness differences for the `ast-grep` skill. The skill body is harness-neutral; this file records what changes per runtime.

## Install paths

| Harness | Location |
|---|---|
| Claude Code | `~/.claude/skills/ast-grep/` |
| Codex | `~/.codex/skills/ast-grep/` or project `.agents/skills/ast-grep/` |
| Kiro | `~/.kiro/skills/ast-grep/` or project `.kiro/skills/ast-grep/` |
| Muse | `~/workspace/skills/ast-grep/` |
| Pi | `~/.pi/agent/skills/ast-grep/` or project `.agents/skills/ast-grep/` |

## Notes

- Prerequisite on every harness: the `ast-grep` binary on PATH. Upstream install options: `brew install ast-grep`, `npm install -g @ast-grep/cli`, `cargo install ast-grep` (this installs it as `sg`, which upstream now deprecates in favor of `ast-grep`).
- The skill's examples all use the `ast-grep` command name. Do not substitute `sg`: it is deprecated upstream, and on some Linux boxes `/usr/bin/sg` is shadow-utils' switch-group tool.
- Docs-only skill (SKILL.md + references), no scripts or hooks, so no harness caveats there.

## Codex metadata

`agents/openai.yaml` carries Codex UI metadata (`display_name`, `short_description`). It is ignored by other harnesses.

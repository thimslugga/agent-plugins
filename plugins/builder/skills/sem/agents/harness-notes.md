# Harness notes: sem

Per-harness differences for the `sem` skill. The skill body is harness-neutral; this file records what changes per runtime.

## Install paths

| Harness | Location |
|---|---|
| Claude Code | `~/.claude/skills/sem/` |
| Codex | `~/.codex/skills/sem/` or project `.agents/skills/sem/` |
| Kiro | `~/.kiro/skills/sem/` or project `.agents/skills/sem/` |
| Muse | `~/workspace/skills/sem/` |
| Pi | `~/.pi/agent/skills/sem/` or project `.agents/skills/sem/` |

## Notes

- Hard prerequisite on every harness: the `sem` CLI on PATH and a Git repository. Without the binary the skill cannot do anything. Upstream install: `curl -fsSL https://raw.githubusercontent.com/Ataraxy-Labs/sem/main/install.sh | sh`, or `brew install sem-cli` on macOS, or `winget install AtaraxyLabs.sem` on Windows. Name conflict note from the skill: make sure `sem --version` reports sem, not GNU Parallel's `sem`.
- If the harness exposes the sem MCP server (tools named `mcp__sem__*`), the skill says to prefer those over the shell CLI. They are the same verbs with compact output and `elapsed_ms`.
- Docs-only skill (SKILL.md, no scripts or hooks), so no harness caveats there.

## Codex metadata

`agents/openai.yaml` carries Codex UI metadata (`display_name`, `short_description`). It is ignored by other harnesses.

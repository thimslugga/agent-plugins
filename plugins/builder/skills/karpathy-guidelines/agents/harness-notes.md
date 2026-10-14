# Harness notes: karpathy-guidelines

Per-harness differences for the `karpathy-guidelines` skill. The skill body is
harness-neutral; this file records what changes per runtime.

## Install paths

| Harness | Location |
|---|---|
| Claude Code | `~/.claude/skills/karpathy-guidelines/` |
| Codex | `~/.codex/skills/karpathy-guidelines/` or project `.agents/skills/karpathy-guidelines/` |
| Kiro | `~/.kiro/skills/karpathy-guidelines/` or project `.kiro/skills/karpathy-guidelines/` |
| Muse | `~/workspace/skills/karpathy-guidelines/` |
| Pi | `~/.pi/agent/skills/karpathy-guidelines/` or project `.agents/skills/karpathy-guidelines/` |

## Composition

This skill is designed to compose with `ponytail` and the `*-pro` skills:
`ponytail` decides how little to write, the `*-pro` skills decide how to
write it, `karpathy-guidelines` decides what to touch and when you're done. Where
a `*-pro` standard conflicts with the project's existing conventions, the
precedence rule in `SKILL.md` defers to the project on all harnesses.

## Codex metadata

`agents/openai.yaml` carries Codex UI metadata (`display_name`,
`short_description`). It is ignored by other harnesses.

# Harness notes: gauntlet-loop

Per-harness differences for the `gauntlet-loop` skill. The skill body is
harness-neutral; this file records what changes per runtime.

## Install paths

| Harness | Location |
|---|---|
| Claude Code | `~/.claude/skills/gauntlet-loop/` |
| Codex | `~/.codex/skills/gauntlet-loop/` or project `.agents/skills/gauntlet-loop/` |
| Kiro | `~/.kiro/skills/gauntlet-loop/` or project `.kiro/skills/gauntlet-loop/` |
| Muse | `~/workspace/skills/gauntlet-loop/` |
| Pi | `~/.pi/agent/skills/gauntlet-loop/` or project `.agents/skills/gauntlet-loop/` |

## Invocation

`/gauntlet-loop <goal>` everywhere; on Pi the skill command form is
`/skill:gauntlet-loop` (requires `"enableSkillCommands": true` in
settings.json).

## Loop mechanics per harness

The skill's Portability section names `/loop` and `ultracode` as Claude
Code features and gives the fallback wording for other agents: "Keep
looping until the critic picks ours. Run the builders and critics as
parallel subagents."

- Claude Code: use the skill's literal template (`/loop` pacing,
  `ultracode` orchestration).
- Muse: run builder and critic pairs as parallel subagents; keep
  looping within the session until the critic picks ours blind.
- Pi: run the loop with Pi subagents (stock Pi has no built-in
  subagents; run sequentially or via the pi-submarine extension),
  keeping the parent session in charge.
- Kiro, Codex: parallel subagents per the fallback wording.

## Codex metadata

`agents/openai.yaml` carries Codex UI metadata (`display_name`,
`short_description`, `default_prompt`). It is ignored by other
harnesses.

# Harness notes: caveman

Per-harness differences for the `caveman` skill. The skill body is
harness-neutral; this file records what changes per runtime.

## Install paths

| Harness | Location |
|---|---|
| Claude Code | `~/.claude/skills/caveman/` |
| Codex | `~/.codex/skills/caveman/` or project `.agents/skills/caveman/` |
| Kiro | `~/.kiro/skills/caveman/` or project `.kiro/skills/caveman/` |
| Muse | `~/workspace/skills/caveman/` |
| Pi | `~/.pi/agent/skills/caveman/` or project `.agents/skills/caveman/` |

## Invocation

The skill is opt-in: `allow_implicit_invocation: false` in
`agents/openai.yaml`. Nothing applies until the reader invokes it.

| Harness | Command |
|---|---|
| Claude Code, Codex, Kiro, Copilot | `/caveman` |
| Pi | `/skill:caveman` (requires `"enableSkillCommands": true` in settings.json) |

Stays on until "stop caveman" or "normal mode". `/caveman status`
reports the mode without changing it. Inside an agent harness the
system prompt outranks this skill: announce tool calls when the
harness requires it, and give status lines or confirmations when asked.
The harness decides *when* you speak, caveman decides *how*.

## Hooks

`hooks/` bundles self-contained SessionStart hooks (Node and POSIX
sh), the Claude Code manifest (`hooks.json`), and the static
always-on rule (`hooks/caveman-activate.md`) for agents without hooks.
`scripts/install-hooks.sh` installs them:

- Claude Code: SessionStart hook merged into
  `~/.claude/settings.json`.
- Codex: `.codex/hooks.json` plus `[features] hooks = true` at
  project scope, mirroring upstream.
- Other harnesses: copy `hooks/caveman-activate.md` into the
  harness's persistent instructions.

`--mode off|manual|caveman|ultracave` writes the user default-mode
config (`~/.config/caveman/config.json`). The hook resolves the mode
from `CAVEMAN_DEFAULT_MODE`, repo-local `.caveman.json`, the user
config, then the `caveman` default; `off` and `manual` stay silent.
Valid modes in this bundle: off, manual, caveman, ultracave (megacave
removed by request).

## Mode state

The bundled hooks resolve the configured default mode on every
session start; there is no cross-session tracker. Other hosts relay
the hook's `CAVEMAN MODE ACTIVE` banner when present. Never infer a
mode from the configured default.

## Sibling skills

Upstream ships `ultracave` (grammar stripped; `/caveman ultra` is its
alias) and `megacave` (Classical Chinese) as separate skills. This
install carries only `caveman`; the Chinese-specific parts were removed
by request. Install `ultracave` from the upstream repo if you want the
`ultra` alias to resolve.

## Codex metadata

`agents/openai.yaml` carries Codex UI metadata (`display_name`,
`short_description`, `default_prompt`) plus the invocation policy. It
is ignored by other harnesses.

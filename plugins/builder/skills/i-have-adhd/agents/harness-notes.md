# Harness notes: i-have-adhd

Per-harness differences for the `i-have-adhd` skill. The skill body is
harness-neutral; this file records what changes per runtime.

## Install paths

| Harness | Location |
|---|---|
| Claude Code | `~/.claude/skills/i-have-adhd/` |
| Codex | `~/.codex/skills/i-have-adhd/` or project `.agents/skills/i-have-adhd/` |
| Kiro | `~/.kiro/skills/i-have-adhd/` or project `.kiro/skills/i-have-adhd/` |
| Muse | `~/workspace/skills/i-have-adhd/` |
| Pi | `~/.pi/agent/skills/i-have-adhd/` or project `.agents/skills/i-have-adhd/` |

## Invocation

The skill is opt-in by design: `disable-model-invocation: true` in the
front matter (honored by Claude Code and Copilot) and
`allow_implicit_invocation: false` in `agents/openai.yaml`. Nothing
applies until the reader invokes it.

| Harness | Command |
|---|---|
| Claude Code, Codex, Kiro, Copilot, Zed, Hermes | `/i-have-adhd` |
| Pi | `/skill:i-have-adhd` (requires `"enableSkillCommands": true` in settings.json) |
| Gemini CLI | `/i-have-adhd` via `agents/gemini.toml` copied to `~/.gemini/commands/i-have-adhd.toml` |

Stays on until "stop adhd mode" or "normal mode". Inside an agent
harness the system prompt outranks this skill: announce tool calls when
the harness requires it, keep time estimates aimed at whoever executes
the steps, and let task or plan tools do the per-turn restating instead
of duplicating it in prose (rule 6 of the skill's exception list).

## Always-on (optional)

Upstream supports an always-on posture instead of per-session
invocation. The two routes, both documented in the repo's INSTALL.md:

- Paste the ten-rule "Output style" block into the harness's
  `AGENTS.md` (or equivalent per-session instructions file).
- Use the repo's `hooks/` SessionStart injection (Claude Code),
  `gemini-extension.json` (Gemini CLI extension), or `opencode.json`
  (OpenCode plugin). The hooks are bundled in this install's
  `hooks/` folder; see below.

## Hooks

`hooks/` bundles the upstream SessionStart hooks with one path patch:
the scripts resolve `SKILL.md` next to the skill (`../SKILL.md`)
instead of the repo's `skills/i-have-adhd/` layout (see
ATTRIBUTION.md). `scripts/install-hooks.sh` installs them:

- Claude Code: SessionStart hook merged into
  `~/.claude/settings.json`, gated by the
  `~/.claude/.i-have-adhd-always` flag file (`--enable` / `--disable`
  manage it).
- Codex: always-on snippet appended to `~/.codex/AGENTS.md`, the
  upstream-documented Codex route (no hook).
- Other harnesses: paste the 10-rule "Output style" block into the
  harness's persistent instructions file.

`--dry-run` previews, `--force` replaces, `--uninstall` removes. The
hook scripts are fail-open: any error exits 0 so a broken install
never blocks session start.

## Codex metadata

`agents/openai.yaml` carries Codex UI metadata (`display_name`,
`short_description`, `default_prompt`) plus the invocation policy. It
is ignored by other harnesses.

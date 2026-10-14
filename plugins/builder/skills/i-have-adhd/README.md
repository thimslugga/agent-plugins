# i-have-adhd

Shapes agent output so a reader with ADHD can act on it. Action first,
numbered steps, restated state, no preamble, no recaps, no closing
pleasantries.

Invoke with `/i-have-adhd`; the rules stay on for the rest of the
session until the reader says "stop adhd mode" or "normal mode".

## What it does

A session-level output style, not a task skill. Once invoked, every
response follows ten rules:

1. Lead with the next action (command, path, or snippet first).
2. Number multi-step tasks; one bounded action per step.
3. End with one concrete next action doable in under two minutes.
4. Suppress tangents; finish the first issue before offering the second.
5. Restate state every turn ("step 3 of 5 done").
6. Give time estimates in concrete units, never "a bit".
7. Make completed work visible in concrete terms.
8. Matter-of-fact tone for errors: location, cause, fix. No drama.
9. Cap visible lists at 5 items per group; never omit relevant items.
10. No preamble, no recaps, no closing pleasantries.

Explicit exceptions: explain fully when asked to explain, confirm before
destructive actions, name the doubtful assumption after three failed
fixes, ask one short question when the request is genuinely ambiguous.
A pre-send checklist strips announcement sentences, "anything else?"
closers, sidebars, and hedging.

## Layout

- `SKILL.md`: the whole skill. Front matter carries
  `disable-model-invocation: true`, so it never applies until invoked.
- `agents/openai.yaml`: display name and short description for
  OpenAI-compatible agents, with `allow_implicit_invocation: false` to
  preserve the opt-in posture.
- `agents/gemini.toml`: Gemini CLI custom-command definition (`/i-have-adhd`).
- `LICENSE`: MIT (Ayoub Ghriss). See `ATTRIBUTION.md`.

This install carries the skill plus its always-on hooks. The upstream
repo also ships evals (`evals/`, `scripts/run_evals.py`), an OpenCode
plugin, and multi-harness packaging (`plugin.json`, `opencode.json`,
`qwen-extension.json`, `gemini-extension.json`) if you want other
integration routes.

## Hooks

`hooks/` bundles the upstream always-on SessionStart hooks:
`always-on.mjs` (Node, primary), `always-on.sh` (POSIX sh fallback),
`always-on.ps1` (PowerShell fallback), and `hooks.json`, the Claude
Code hook manifest. The only change from upstream: the scripts resolve
`SKILL.md` next to the skill (`../SKILL.md`) instead of the repo's
`skills/i-have-adhd/` layout, and the manifest uses a
`__SKILL_DIR__` placeholder the installer replaces (upstream's
manifest targets the plugin layout via `CLAUDE_PLUGIN_ROOT`).

`scripts/install-hooks.sh` wires them up:

- Claude Code: merges the SessionStart hook into
  `~/.claude/settings.json`. The hook fires only when the flag file
  `~/.claude/.i-have-adhd-always` exists; `--enable` creates it,
  `--disable` removes it.
- Codex: appends the always-on snippet to `~/.codex/AGENTS.md`
  (upstream documents no hook route for Codex).

`--dry-run` previews every action, `--force` replaces existing
entries, `--uninstall` removes them. "stop adhd mode" still turns the
rules off for the session.

## Usage

Install the skill folder for your harness, then start any session with
`/i-have-adhd`. It stays on for the whole session across topic changes.

| Harness | Invoke with |
|---|---|
| Claude Code, Codex, Kiro, Copilot, Zed, Hermes | `/i-have-adhd` |
| Pi | `/skill:i-have-adhd` (needs `"enableSkillCommands": true` in settings.json) |
| Gemini CLI | `/i-have-adhd` via the bundled `agents/gemini.toml` as a custom command |

Turn it off with "stop adhd mode" or "normal mode".

## Testing

No tests ship with the skill folder itself. Upstream keeps its eval
and packaging tests in the repo (`tests/`, run with pytest), covering
the always-on hooks, install docs, plugin packaging, and judge
scenarios. If you change `SKILL.md`, the meaningful check is a read
through the Before/After pairs in the repo's README: each rule must
still be illustrated by both sides.

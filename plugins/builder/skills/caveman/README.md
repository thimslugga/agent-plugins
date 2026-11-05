# caveman

Talk like smart caveman. Same brain, fewer tokens.

A session-level voice: answer first, ceremony gone, every technical
fact kept. Invoke with `/caveman`; it stays on until the user says
"stop caveman" or "normal mode".

## What it does

Makes the model answer first and cut the ceremony: no greeting,
hedging, filler, recap, or closer. Articles drop when the sentence
still reads in one pass. Code, commands, paths, numbers, and exact
error strings never change. Compression never costs meaning: clarity
beats compression, and negations are never dropped.

Measured once (upstream `evals/snapshots/results.json`:
claude-opus-5-5, ten prompts, single run, output length only, tiktoken
o200k approximation): caveman 3% fewer output tokens at the median
than a plain `Answer concisely.` control, inside the noise; ultracave
35%. No quality-equivalence claim is published. Mode persists until
changed or stopped.

The upstream repo has one sibling skill, `ultracave` (grammar stripped:
fragments, one word when one word is enough, each fact once). This
install carries only `caveman`; `/caveman ultra` points at the sibling
if you install it separately.

Auto-clarity: the voice drops to normal prose for security warnings,
irreversible-action confirmations, step sequences a fragment could
scramble, and a user who repeats a question. Resumes after the clear
part.

## Example output

Question: "Why does my React component re-render?"

Normal prose:

> Your component re-renders because you create a new object reference each render. Wrapping it in `useMemo` will fix the issue.

caveman:

> New object ref each render, so React re-renders. Wrap the prop in `useMemo`.

ultracave:

> Inline object prop, new ref, re-render. `useMemo`.

## Hooks

`hooks/` bundles self-contained SessionStart hooks written for this
install: `caveman-sessionstart.mjs` (Node) and
`caveman-sessionstart.sh` (POSIX sh). They resolve the default mode
(`CAVEMAN_DEFAULT_MODE` env var, repo-local `.caveman.json`, user
`~/.config/caveman/config.json`, default `caveman`) and print the
skill's ruleset. Silent for `off`/`manual`; fail-open so a broken
install never blocks a session. `hooks/hooks.json` is the Claude Code
hook manifest; `hooks/caveman-activate.md` is the static always-on
rule for agents without a hook system.

`scripts/install-hooks.sh` wires them up:

- Claude Code: merges the SessionStart hook into
  `~/.claude/settings.json`.
- Codex: writes `.codex/hooks.json` and enables `[features]
  hooks = true` in the current project (project scope, mirroring
  upstream).
- Other agents: copy `hooks/caveman-activate.md` into the agent's
  persistent instructions (`.cursor/rules/`, `.windsurf/rules/`,
  `.clinerules/`, `.github/copilot-instructions.md`, `AGENTS.md`).

`--mode off|manual|caveman|ultracave` writes the user default-mode
config. `--dry-run` previews, `--uninstall` removes, `--force`
replaces.

## Layout

- `SKILL.md`: the skill, plus a short "Hook install" assist section.
  Customized from upstream: the Classical-Chinese (`megacave` /
  `/caveman wenyan`) parts were removed (see Attribution below);
  everything else unchanged.
- `agents/openai.yaml`: Codex UI metadata (`display_name`,
  `short_description`, `default_prompt`), with
  `allow_implicit_invocation: false` to keep the opt-in posture.
  Other harnesses ignore it.
- `LICENSE`: Apache 2.0 (Julius Brussee).

Not carried over from the repo: the `ultracave` sibling skill, the
full upstream installer (`bin/install.js`), the OpenCode/OMP plugins,
and the `evals/` benchmarks.

## Usage

Install the skill folder for your harness, then start any session with
`/caveman`. It applies to every response for the rest of the session.

| Harness | Invoke with |
|---|---|
| Claude Code, Codex, Kiro, Copilot | `/caveman` |
| Pi | `/skill:caveman` (needs `"enableSkillCommands": true` in settings.json) |

`/caveman status` reports the current mode without changing it.
`stop caveman` or `normal mode` returns to normal prose.

Startup policy (Claude Code only): want sessions to start with normal
prose? Set `{"defaultMode":"manual"}` in `.caveman.json` for one
project, `~/.config/caveman/config.json` for your user, or
`CAVEMAN_DEFAULT_MODE=manual`. Then `/caveman` activates the voice and
`/ultracave` selects the sibling. Stop persists across compaction and
resume; a fresh session starts off again. OpenCode keeps its caveman
default because the upstream installer also supplies static activation
rules.

Claude Code and the standalone OpenCode plugin read stored mode state.
Other hosts report the mode known in the conversation, or `unknown`
if none is known.

## Harness setup

| Harness | Install to |
|---|---|
| Claude Code | `~/.claude/skills/caveman/` |
| Codex | `~/.codex/skills/caveman/` or project `.agents/skills/caveman/` |
| Kiro | `~/.kiro/skills/caveman/` or project `.kiro/skills/caveman/` |
| Muse | `~/workspace/skills/caveman/` |
| Pi | `~/.pi/agent/skills/caveman/` or project `.agents/skills/caveman/` |

- Inside an agent harness the system prompt outranks this skill:
  announce tool calls when the harness requires it, and give status
  lines or confirmations when asked. The harness decides *when* you
  speak, caveman decides *how*.
- There is no cross-session mode tracker: the hooks resolve the
  configured default on every session start. Other hosts relay the
  hook's `CAVEMAN MODE ACTIVE` banner when present. Never infer a mode
  from the configured default.

## Testing

No tests ship with the skill folder itself; upstream keeps its evals
in the repo (`evals/`, not carried over). The sanity check after any
edit is the Example output section above: the caveman answer must be
shorter, answer-first, and keep `useMemo` and the causal fact intact.

## Attribution

- Upstream: [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman), `skills/caveman/` (`SKILL.md`, `README.md`; fetched 2026-10-04).
- License: Apache License 2.0 (copied to `LICENSE`).
- Customizations (per the user's request): removed the Classical-Chinese
  parts (the `/caveman wenyan` alias, all `megacave` references, its
  sibling-skills table row, the `/megacave` invocation, its example
  output and benchmark number). The Persistence paragraph now says
  `/caveman ultra` points at the `ultracave` sibling, which is not
  included. A "Hook install" assist section was added at the end of
  `SKILL.md`; otherwise `SKILL.md` is faithful to upstream. The README
  is rewritten in this repo's format.
- Original work for this install (not upstream code): `hooks/` (both
  SessionStart scripts, the `hooks.json` template, and
  `caveman-activate.md`, derived from `SKILL.md`),
  `scripts/install-hooks.sh`, `README.md`, `agents/openai.yaml`.

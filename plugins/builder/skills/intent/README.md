# intent

Design with Intent: a UX strategy system for AI tools. 17 skills covering research, strategy, flows, content, accessibility, ethics, and measurement, plus 6 specialist agents. Upstream: [ghaida/intent](https://github.com/ghaida/intent) (CC0-1.0). This is a faithful port adapted for this workspace. See ATTRIBUTION.md for provenance and the exact modifications.

Where the impeccable skill focuses on how things look, intent focuses on why they exist: problem framing, evidence, systems thinking, flows, content, accessibility, ethics, and measurement.

## What it does

- Entry point is this skill (`SKILL.md`, the upstream `intent` foundation skill): sets project context, holds the UX principles and the anti-pattern catalog (72+ named deceptive, addictive, and manipulative patterns with severity ratings), and routes to the 16 specialist skills.
- The 16 specialists live under `skills/`: `strategize`, `investigate`, `blueprint`, `journey`, `organize`, `wireframe`, `articulate`, `evaluate`, `fortify`, `include`, `transpose`, `localize`, `measure`, `philosopher`, `storytelling`, `specify`. Each has its own `SKILL.md` with a trigger description; cross-references between them are rewritten to relative paths.
- `references/` holds 8 deep reference documents (research methods, information architecture, interaction patterns, content strategy, accessibility, service design, measurement frameworks, ethical design).
- `upstream-agents/` holds the 6 upstream specialist agents (noor, ember, wren, vigil, rune, sage) as system-prompt files. They are reference material for spawning subagents, not auto-registered.
- Typical chains: Ember frames the problem (`strategize` + `investigate`), Wren designs the experience (`journey` + `organize` + `wireframe` + `articulate`), Vigil ensures quality (`evaluate` + `fortify` + `include`), Rune hands off (`specify`). Sage (`philosopher`) can be entered any time the problem needs more exploration.

## Layout

- `SKILL.md` — entry point: invocation, project context protocol, UX principles, anti-pattern catalog, skill routing logic.
- `skills/<name>/SKILL.md` — the 16 specialist skills (verbatim from upstream apart from cross-reference rewrites).
- `references/` — the 8 foundation reference docs.
- `upstream-agents/` — the 6 upstream agent prompts (noor, ember, wren, vigil, rune, sage).
- `agents/openai.yaml` — adaptation notes for OpenAI-based agents.
- `agents/harness-notes.md` — notes for this harness.
- `ATTRIBUTION.md` — upstream provenance, license, and what was changed in this port.

## Usage

Invoke by reading `SKILL.md` and following its workflow; there is no slash-command runner in this harness, so "invoke `/strategize`" in the text means "read `skills/strategize/SKILL.md`". Start UX work at the entry point skill, let it establish project context, then follow its routing to the specialist skill for the job. To use an upstream agent persona, spawn a subagent with the corresponding `upstream-agents/<name>.md` as its system prompt.

## Testing

- Every `SKILL.md` frontmatter parses as YAML and carries `name`, `description`, `version`.
- No remaining `/skillname` slash-command references; all cross-references are relative paths that resolve on disk.
- Every internal markdown link target inside the skill resolves.

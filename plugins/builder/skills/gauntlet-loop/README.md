# gauntlet-loop

Turns any goal into one short, paste-ready "gauntlet loop" prompt: a
prompt that makes an agent set a concrete quality bar, split the work
into small judgeable pieces, run a builder and a separate harsh critic
on each, compare blind against the bar, and loop until it wins.

Works for builds, writing, code, research, or design. Triggers on
`/gauntlet-loop`, "gauntlet loop", "gauntlet this", "make a gauntlet
prompt", "loop until it beats X".

## What it does

The skill does not do the work. It writes the prompt that makes another
agent grind on the work until it beats a real reference.

1. **Read the goal.** One line restatement in your head, not on screen.
2. **Set the bar.** If the user supplied a reference, use it. If not,
   offer 2 or 3 candidate bars, one line each, and stop. Wait for the
   pick; do not write the prompt yet.
3. **Write the prompt.** One block, paste-ready, around 120 to 180
   words, no preamble, no headings inside it, no narration after it.
4. **Offer to run it.** One flat line under the prompt: "I can run this
   here." Not a question.

The bar is the whole trick. It must be named (a specific thing, not a
category), fetchable (the critic can actually obtain it), and comparable
(the two can sit side by side while a judge picks one). A bar that is
too easy lets the loop exit on round one; prefer the hardest bar the
agent can genuinely reach. When the goal has a measurable half (load
time, token cost, benchmark score, word count, pass rate), name it next
to the reference.

The generated prompt keeps a harsh critic honest: separate agent, fresh
context, blind A/B against the bar, names the single biggest remaining
gap. Exit only when ours wins blind or the user stops the run, never
after a fixed round count. Minimal wins: no architecture, no file
layout, no decomposition, no round count, no stack choice unless the
user demanded them.

## Layout

- `SKILL.md`: the whole skill. Faithful to upstream, including the
  Portability section for non-Claude-Code agents.
- `agents/openai.yaml`: Codex UI metadata (`display_name`,
  `short_description`, `default_prompt`). Other harnesses ignore it.
- `LICENSE` note: the upstream repo is licensed CC BY 4.0; the zip the
  user supplied contained only `SKILL.md`. See Attribution below.

## Usage

`/gauntlet-loop <goal>`. Answer the bar question when it offers
candidates, paste the returned prompt into a fresh session, and let it
loop. Or say "run it here" to execute the loop in the current session.

## Harness setup

| Harness | Install to |
|---|---|
| Claude Code | `~/.claude/skills/gauntlet-loop/` |
| Codex | `~/.codex/skills/gauntlet-loop/` or project `.agents/skills/gauntlet-loop/` |
| Kiro | `~/.kiro/skills/gauntlet-loop/` or project `.kiro/skills/gauntlet-loop/` |
| Muse | `~/workspace/skills/gauntlet-loop/` |
| Pi | `~/.pi/agent/skills/gauntlet-loop/` or project `.agents/skills/gauntlet-loop/` |

On Pi the command is `/skill:gauntlet-loop` (needs
`"enableSkillCommands": true` in settings.json).

The skill's Portability section names `/loop` and `ultracode` as Claude
Code features. How the loop runs elsewhere:

- Claude Code: the skill's literal template (`/loop` pacing,
  `ultracode` orchestration).
- Codex, Kiro, Muse: builder and critic pairs as parallel subagents;
  keep looping in the session until the critic picks ours blind.
- Pi: stock Pi has no built-in subagents; run sequentially or via the
  pi-submarine extension, keeping the parent session in charge.

## Testing

No tests ship with the skill; it is a single-file prompt-authoring
skill. The sanity check after any edit: generate a prompt for a
concrete goal (e.g. "landing page for my running brand") and verify
the output is one 120-to-180-word block with a baked-in,
named-and-fetchable bar, blind critic comparison, and no
over-specification.

## Attribution

- Upstream: [robonuggets/gauntlet-loop](https://github.com/robonuggets/gauntlet-loop),
  `.claude/skills/gauntlet-loop/SKILL.md` (copied 2026-10-04).
- Technique and original prompt by Matt Shumer, named while building
  Claude of Duty (mshumer/Claude-of-Duty).
- License: Creative Commons Attribution 4.0 International (CC BY 4.0).
  The user-supplied zip contained only `SKILL.md`; the license file
  lives in the upstream repo.
- Changes: `SKILL.md` is unchanged from upstream. Added `README.md` and
  `agents/openai.yaml`.

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
- `agents/openai.yaml`: display name and short description for
  OpenAI-compatible agents.
- `LICENSE` note: the upstream repo is licensed CC BY 4.0; the zip the
  user supplied contained only `SKILL.md`. See `ATTRIBUTION.md`.

## Usage

`/gauntlet-loop <goal>`. Answer the bar question when it offers
candidates, paste the returned prompt into a fresh session, and let it
loop. Or say "run it here" to execute the loop in the current session.

## Testing

No tests ship with the skill; it is a single-file prompt-authoring
skill. The sanity check after any edit: generate a prompt for a
concrete goal (e.g. "landing page for my running brand") and verify
the output is one 120-to-180-word block with a baked-in,
named-and-fetchable bar, blind critic comparison, and no
over-specification.

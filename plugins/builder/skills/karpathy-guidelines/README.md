# karpathy-guidelines

Behavioral skill for coding work: think before coding, keep changes surgical,
and execute goal-driven. Ports all four principles of the Karpathy guidelines
(multica-ai/andrej-karpathy-skills, MIT), derived from
[Andrej Karpathy's observations](https://x.com/karpathy/status/2015883857489522876)
on LLM coding pitfalls.

## What it does

- **Think before coding:** state assumptions explicitly, surface tradeoffs,
  push back when warranted; with an ask-vs-proceed threshold (proceed when a
  wrong guess is cheap, ask when the step is hard to undo).
- **Simplicity first:** minimum code that solves the problem, nothing
  speculative. This section is a summary: the `ponytail` skill is the
  authority on simplicity when both are loaded.
- **Surgical changes:** touch only what the task requires; match the project's
  existing conventions even when they differ from your preferences; clean up
  only the orphans your own edits created.
- **Goal-driven execution:** turn imperative tasks into verifiable success
  criteria ("write a test that reproduces it, then make it pass") and loop
  until each is met with evidence.
- **Closing checklist:** a four-item self-review (assumptions stated, diff
  traces to the request, orphans handled, criteria evidenced) before reporting
  a task done.

## Layout

- `SKILL.md`: the skill (frontmatter plus the four principles, closing
  checklist, and precedence rule).
- `agents/openai.yaml`: Codex UI metadata (`display_name`,
  `short_description`). Other harnesses ignore it.

No scripts or references: like `ponytail`, this is a behavioral skill, and a
checker for "did you touch only what you must" would be speculative tooling.
The diff-review test in section 3 is the enforcement mechanism.

## Usage

Install per Harness setup below, then invoke when writing, editing,
reviewing, or refactoring code. It composes with the other behavior skills:
`ponytail` decides how little to write, the `*-pro` skills decide how to write
it, and `karpathy-guidelines` decides what to touch and when you're done.

## Harness setup

| Harness | Install to |
|---|---|
| Claude Code | `~/.claude/skills/karpathy-guidelines/` |
| Codex | `~/.codex/skills/karpathy-guidelines/` or project `.agents/skills/karpathy-guidelines/` |
| Kiro | `~/.kiro/skills/karpathy-guidelines/` or project `.kiro/skills/karpathy-guidelines/` |
| Muse | `~/workspace/skills/karpathy-guidelines/` |
| Pi | `~/.pi/agent/skills/karpathy-guidelines/` or project `.agents/skills/karpathy-guidelines/` |

Where a `*-pro` standard conflicts with the project's existing
conventions, the precedence rule in `SKILL.md` defers to the project.

## Testing

Behavioral skill; verification is by inspection:

- `SKILL.md` frontmatter parses as YAML (`name`, `description`, `license`
  present; name matches the directory).
- No em dashes; no invented tooling references.
- Each principle has a bold rule line, concrete bullets, and a test.

---
name: karpathy-guidelines
description: "Think before coding, keep changes surgical, and execute goal-driven. Use when writing, editing, reviewing, or refactoring code to surface assumptions and tradeoffs, avoid touching unrelated code, clean up only your own mess, and define verifiable success criteria before implementing. Pairs with ponytail (simplicity)."
license: MIT
---

# Karpathy Guidelines

Behavioral guidelines to reduce common LLM coding mistakes, derived from Andrej Karpathy's observations on LLM coding pitfalls.

**Tradeoff:** these rules bias toward caution over speed. For trivial tasks (e.g. typo fixes, obvious one-liners), use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly.
- If multiple interpretations exist, present them. Don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.

**Ask vs. proceed:** state assumptions and proceed when the cost of being wrong
is low (a wrong guess is cheap to detect and redo). Stop and ask when the step
is hard to undo (deletions, schema changes, published interfaces, anything
irreversible) or when confusion persists after investigation.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

**The test:** would a senior engineer call this overcomplicated? If yes,
simplify.

This principle overlaps the `ponytail` skill, which covers it in depth
(intensity levels, the six-step ladder, when not to be lazy). When both skills
are loaded, `ponytail` is the authority on simplicity; this section is the
summary.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match the project's existing conventions, even if you'd do it differently. Project conventions outrank this skill's preferences and any opinionated guideline: never reformat or restyle surrounding code to satisfy a standard nobody asked for.
- If you notice unrelated dead code, mention it. Don't delete it.

When your changes create orphans:

- Remove imports, variables, or functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

**The test:** every changed line should trace directly to the user's request.
Before finishing, review the diff and justify each hunk.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform imperative tasks into verifiable goals:

- "Add validation" becomes "write tests for invalid inputs, then make them pass"
- "Fix the bug" becomes "write a test that reproduces it, then make it pass"
- "Refactor X" becomes "ensure tests pass before and after"

For multi-step tasks, state a brief plan with a verification step per step:

```
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it
work") require constant clarification.

## Closing checklist

Before reporting a coding task done:

1. Assumptions and plan: stated before implementation, not after mistakes; any hard-to-undo step was confirmed, not guessed.
2. Diff review: every changed line traces to the request; no drive-by refactors or rewrites of code that should have been left alone.
3. Orphans: anything your edits made unused is removed; pre-existing dead code untouched.
4. Success criteria: each criterion from section 4 is met, with evidence (test output, command results), not assertion.

## Precedence

Project conventions outrank everything here. If a project's explicit standards
conflict with these rules, follow the project. These rules also defer to the
user's direct instructions on any single task.

---
name: gauntlet-loop
description: >-
  Create a short, paste-ready agent prompt that turns a concrete goal and a real reference into an 
  iterative builder-critic loop.
  Use when user invokes /gauntlet-loop or $gauntlet-loop, says "gauntlet loop" or "gauntlet this", 
  requests a gauntlet prompt, or asks to keep improving work until it beats a named bar. 
  Do not use for ordinary one-pass implementation or reviews.
---

# Gauntlet Loop

Turn the user's goal into one short prompt they can paste into a fresh agent session.

## Rules

1. Write the orchestration prompt.
2. Do not perform the underlying work unless the user asks you to run it.

## Workflow

1. Read the goal and identify the intended artifact.
2. Resolve the comparison bar:
   - Use a user-supplied reference only when it is named, obtainable, and comparable.
   - Otherwise, offer two or three concrete candidate bars, then stop for the user's choice.
3. Write one paste-ready prompt. Use a single fenced block without headings or bullet lists inside it.
4. Add one line after the block: `I can run this here.`

If the user asks you to run it, become the lead agent and follow the generated prompt.

## Choose a Real Bar

The loop is useful only when the critic compares real artifacts.

A valid bar is:

- **Named:** A specific artifact, product, page, repository, benchmark, or publication.
- **Obtainable:** Agents can access, open, run, render, or otherwise inspect it.
- **Comparable:** The result and reference can be judged side by side using the same conditions.

Prefer the strongest obtainable bar. Pair subjective quality with an objective measure when the goal
has one, such as latency, cost, test results, pass rate, dimensions, or word count.

Useful bars include:

| Goal | Suitable bar |
| --- | --- |
| Website, app, or UI | A named live product captured at matching viewports |
| Game, 3D, or visual work | Footage or screenshots from a named shipped title |
| Writing | A specific published piece using a comparable format and length |
| Code or tooling | A named implementation plus its tests or benchmark |
| Research or analysis | A named report or paper section with comparable coverage |
| Deck or document | A real artifact with a comparable purpose and page count |

Reject category labels such as "best-in-class sites." Reject references that agents cannot inspect.

## Agent Prompt Template

Adapt this template to the goal. Replace every bracketed value.

```text
Complete [GOAL].

The bar is [BAR]. Obtain the real reference first. Compare actual outputs directly under equivalent conditions, not descriptions of them.

Break the work into the smallest pieces that can be built, verified, and judged independently. Use parallel builder subagents for independent pieces when delegation is available. Give each builder clear ownership. Use a separate critic subagent with fresh context. The critic must inspect the actual artifact and evidence, compare ours with the bar blind when practical, choose the stronger result, and identify the single largest remaining gap. Send that gap back for revision. If delegation is unavailable, use a separate review pass and disclose that limitation.

Continue the builder-critic loop until ours wins the comparison and every objective check passes. Never weaken the bar, alter tests, or change the rubric to manufacture a win. Stop only when complete, when I stop the run, or when a concrete permission, evidence, or external-state blocker prevents progress. Report blockers precisely.

Send concise progress updates while working. Preserve my decisions, permissions, scope, and repository conventions.
```

## Adapt the Template

- Identify the bar precisely. Include a stable URL, title, repository, version, or artifact when known.
- Add a cost or time ceiling only when the user supplies one.
- Name tools only when the task requires them and agents can use them.
- For visual work, require matching viewport, state, and capture conditions.
- For code, name the relevant tests or benchmarks. Forbid changing them solely to win.
- Do not prescribe architecture, file layout, decomposition, round count, or stack without user input.
- Do not emit vendor specific (e.g. Claude, Codex, ChatGPT, Gemini, etc) commands, model aliases, or unavailable orchestration features.
- Keep the finished prompt near 140 to 200 words when the goal permits.

The prompt itself authorizes scoped delegation. It does not authorize unrelated mutations, publishing,
spending, deployment, or changes outside the user's stated goal.

## Run Mode

When the user asks you to run the generated prompt:

- Establish the bar before changing the artifact.
- Inspect the current workspace and preserve unrelated user changes.
- Delegate independent work only within the requested scope.
- Keep builder and critic responsibilities separate.
- Verify the actual artifact after every material revision.
- Continue until the defined exit condition is reached.
- Stop for required authorization or genuinely unavailable evidence.

## Failure Modes

- **Vague bar:** The critic invents its comparison and approves weak work.
- **Unobtainable bar:** The comparison becomes unsupported imitation.
- **Self-review:** The builder rationalizes its own decisions.
- **Soft scoring:** Numerical ratings drift upward without proving superiority.
- **Fixed rounds:** The loop stops because a counter expires.
- **Moving checks:** Builders weaken tests or rubrics instead of improving the artifact.
- **Unavailable controls:** Prompts depend on commands or orchestration the active agent surface lacks.
- **Over-specification:** Premature implementation choices crowd out useful agent judgment.

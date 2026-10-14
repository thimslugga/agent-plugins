---
id: "<NNNN>"
title: "<descriptive proposal title>"
status: <draft | in-review | approved | rejected | withdrawn>
date: "<YYYY-MM-DD>"
updated: "<YYYY-MM-DD>"
authors: [<name>]
reviewers: [<name>, <name>]
adr: []
outcome: ""
tags: [<area>]
---

# RFC-<NNNN>: <title>

## Summary

A short paragraph covering the problem, the proposed solution, and the
main trade-off accepted. Write it so it stands alone: a reader who sees
only this paragraph should understand what is being proposed and what it
costs.

## Context and Problem Statement

The current situation, the constraints in play, and the specific pain
being solved. Quantify where possible: latency numbers, error rates,
volume of affected code, hours of manual work. State facts rather than
preferences. A reader with no history on this should finish this section
understanding why doing nothing is not acceptable.

## Goals and Non-Goals

**Goals** — what this proposal is trying to achieve, as outcomes rather
than implementation steps.

**Non-Goals** — what is explicitly out of scope. This section prevents
review from expanding indefinitely; be generous with it.

## Proposed Solution

The technical design: architecture, API changes, data model, package
boundaries, tooling. Include diagrams and code blocks where they clarify
more than prose. Enough detail that a reviewer can find the flaws and an
implementer can start.

## Impact and Migration

What changes for existing users, callers, and operators.

- **Breaking changes:** what stops working, and for whom.
- **Migration path:** the steps to get from current state to proposed
  state, and who performs them.
- **Rollout:** whether this ships behind a flag, in phases, or at once.
- **Rollback:** how to undo it if the change goes wrong in production.

Write "None" against any item that genuinely does not apply.

## Drawbacks

The costs of doing this, stated plainly: added complexity, new
dependencies, performance regressions, ongoing maintenance burden,
capability lost. If this section is empty, the proposal has not been
examined closely enough.

## Alternatives Considered

Each option genuinely on the table, with the specific reason it is not
preferred. Include the null option (change nothing) and say what happens
if the problem goes unaddressed.

## Supporting Materials

Spikes, benchmark results, prototypes, and exploratory branches, with
links. State the methodology behind any numbers so a reader can judge
them. Write "None" if no experimental work was done rather than
describing work that did not happen.

## Open Questions

Unresolved points where feedback is specifically wanted. Phrase each as a
question with the options under consideration, not as a topic heading.
Move items out of this section as review resolves them.

## Decision

<!-- Leave empty while status is draft or in-review. -->

## References

Links to documentation, source, prior RFCs, related ADRs, and external
technical material. Write "None" if there are no references.

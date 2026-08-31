---
id: "<NNNN>"
title: "<active verb phrase, e.g. 'Migrate to SQLite cache'>"
status: <proposed | accepted | rejected | deprecated | superseded>
date: "<YYYY-MM-DD>"
deciders: [<name>, <name>]
tags: [<area>, <area>]
supersedes: []
superseded_by: []
---

# ADR-<NNNN>: <title>

## Context

The situation that forces a decision. Cover the technical, organizational,
and operational factors in play, and the constraints that narrow the field.
State facts, not preferences. A reader with no history on this project
should finish this section understanding why doing nothing was not an option.

## Decision

The chosen path, stated in one or two sentences up front, in active voice:
"We will use X." Follow with the reasoning that made it the choice.

## Alternatives Considered

Each option that was genuinely on the table, with the reason it lost.
Include the null option (change nothing) where relevant. One short
paragraph or bullet per alternative.

## Consequences

### Positive

- What this buys, in concrete terms.

### Negative

- What this costs. Include work now required, capability now lost, and
  risk now accepted. If this list is empty, the analysis is incomplete.

### Neutral

- Structural shifts that are neither win nor loss but change how the
  system is built or operated.

## Compliance and Verification

How the team confirms the decision is actually being followed. Name the
specific automated test, lint rule, CI check, or review step. If
enforcement is manual, say so plainly rather than implying automation
that does not exist.

## Revisit When

The condition that should reopen this decision. A threshold, a date, or
an event, e.g. "cache exceeds 5 GB" or "the vendor contract renews".
Write "No foreseeable trigger" if there genuinely is none.

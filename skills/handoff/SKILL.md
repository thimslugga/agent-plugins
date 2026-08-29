---
name: handoff
description: "Compacts the current conversation into a handoff document so a fresh agent can continue the work in a new session."
disable-model-invocation: true
---

# Handoff

Compacts the current conversation into a handoff document so a fresh agent can continue the work in a new session.

## Rules

1. Write a handoff document summarising the current conversation so a fresh agent
can continue the work.

2. Save the handoff document to a temporary directory of the user's OS — not the current workspace.

3. Include a "suggested skills" section in the document, which suggests skills
that the next agent should invoke.

4. Do not duplicate content already captured in other artifacts (specs, plans, RFCs,
ADRs, issues, commits, diffs). Reference them by path or URL instead.

5. You MUST redact any sensitive information, such as secrets, API keys, passwords, or personally
identifiable information (PII).

6. If the user passed arguments, treat them as a description of what the next
session will focus on and tailor the document accordingly.

## When to use

- The conversation is long and the work needs to continue in a fresh session
- Handing the current task to another agent (or another person's agent) that
  has no access to this conversation
- Preserving hard-won context - decisions made, dead ends explored, current
  state - before it is lost to context compaction

## When not to use

- The work is finished; write a commit message, PR description, or docs
  instead
- The context is already fully captured in artifacts (a plan file, an issue,
  a spec) - point the next session at those directly

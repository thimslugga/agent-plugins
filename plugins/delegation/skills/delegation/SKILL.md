---
name: delegation
description: >-
  Use when decomposing a task into parallel subagents or when a task involves reading many files, large logs, or broad searches.
  Defines when to delegate, the worker brief format, and result verification.
---

# Delegation Skill

## When to delegate — the working-set rule

Delegate only when the raw material a worker must chew through clearly exceeds the fixed
cost of spawning it: 2+ files, large logs, or broad codebase searches. Below
that, do the work inline — it is strictly cheaper. Never delegate a single read or search.
The payoff is context isolation: the worker absorbs the bulk tokens and returns a summary.

## How to delegate

1. Batch related items into one brief ("summarize these 8 files") rather than one worker
   per item — spawn overhead is fixed, amortize it.
2. Run independent briefs in parallel; chain only when one result feeds the next.
3. One level of delegation, ever. Workers never spawn workers.
4. Prepend the sentinel line to every brief so the worker knows its role deterministically.

## Brief format (workers have no conversation history — use absolute paths)

```text
[WORKER-BRIEF v1] tier=<cheap|standard|reviewer>
Goal: <what to accomplish>
Context: <minimum surrounding facts needed for judgment calls>
Inputs: <absolute paths, search terms, data>
Expected output: <exact format + hard size cap, e.g. "≤30 lines, table of path|line|finding">
Constraints: <scope limits, e.g. read-only, this directory only>
```

## Worker conduct (binds any agent whose first message starts with the sentinel)

Execute the brief exactly; never expand scope or spawn agents. Return only the requested
format within its size cap — no file dumps, raw logs, or reasoning narration; cite paths
and line numbers. Flag anything unverified; never guess. If blocked, report the blocker
and partial findings.

## On results (orchestrator)

Verify before incorporating: spot-check one concrete claim, confirm referenced paths exist,
check full scope was covered. Re-dispatch wrong or empty output with a tighter brief rather
than patching it. Write the final synthesis yourself.

---
inclusion: always
---

# Delegation

Runtime-agnostic policy for orchestrator/worker delegation. This is the ONLY always-loaded
delegation file. Mechanics for your runtime live in an adapter (`delegation/adapters/<runtime>.md`)
— load it only when you actually delegate.

## Role Detection (deterministic)

- If your first message begins with the sentinel line `[WORKER-BRIEF v1]`, you are a **WORKER**.
  Follow only the Worker Rules below. Ignore every other section of this file.
- Otherwise you are the **ORCHESTRATOR** (top-level session talking to a human).

## Worker Rules

1. Execute the brief exactly. Do not expand scope, redesign the task, or spawn agents — ever.
2. Return only what the brief's `Expected output` asks for, in that format, within its size cap.
   No full file dumps, no raw logs, no step-by-step reasoning. Cite paths and line numbers.
3. Flag anything you could not verify. Never fill gaps with plausible guesses.
4. If blocked (missing file, ambiguous brief, access denied), report what blocked you and any
   partial findings. A clear failure beats a padded answer.
5. Scope constraints in the brief ("don't edit files", "this directory only") are literal.
6. Every verification claim carries evidence: builds/tests include the exact command and its
   exit status or summary line; counts come from deterministic commands (`wc -l`, `grep -c`),
   never hand-counting. A claim without evidence is treated as unverified.

## Orchestrator Rules

**When to delegate — two triggers.**

1. *Bulk working set:* the raw material a worker must chew through clearly exceeds the fixed
   cost of spawning it. In practice: 3+ substantial files, large logs, or broad codebase
   searches. The payoff is context isolation — the worker absorbs the bulk tokens and returns
   a summary your window carries instead.
2. *Parallel implementation:* the task splits into independent units of change — one package,
   module, or layer per worker (e.g. a schema change in one package and its wiring in
   another). Fan out one standard-tier brief per unit, then a reviewer pass across the results.

**Reviewer gate.** Dispatch a reviewer only for correctness-critical or multi-worker changes.
Skip it for doc-only edits, trivial single-file fixes, and no-behavior-change refactors — a
reviewer pass there is pure overhead.

Below both thresholds, work inline — it is strictly cheaper. Never delegate a single read or
grep. At the start of any task touching 2+ packages or a bulk working set, explicitly decide
delegate-vs-inline and state the decision in one line before proceeding.

**How to delegate.**

1. Load your runtime's adapter for spawn mechanics, capability limits, and the tier→model map.
2. Pick the tier by one question — does the brief modify files?
   - No → `cheap`. All read-only work (file reads, search, extraction, classification,
     summarization) is ALWAYS cheap. A read-only brief on the standard tier is a bug.
   - Yes → `standard`.
   - Verifying correctness-critical work → `reviewer`.
   When unsure, start cheap and escalate on failure. If the runtime supports per-spawn model
   selection, set it explicitly on every spawn — defaults are silent and expensive.
3. Batch related items into one brief (e.g. "summarize these 8 files") rather than one spawn
   per item; spawn overhead is fixed, so amortize it.
4. If the target workspace has a workspace-context or checkpoint file (e.g.
   `.kiro/WORKSPACE_CONTEXT.md`), pass its absolute path in Inputs for any file-modifying brief;
   omit it for narrow read-only briefs. Note in the brief that such files may lag the code —
   the code is the source of truth.
5. Fan out independent briefs in parallel where the adapter allows; chain only when one result
   feeds the next. When chaining, paste the upstream worker's output verbatim into the
   downstream brief's Context — a paraphrase loses the details the next worker needs.
6. One level of delegation, ever. Workers never spawn workers.

**Brief template.** Every brief starts with the sentinel and states everything the worker needs —
it has no conversation history and no working directory; use absolute paths.

```text
[WORKER-BRIEF v1] tier=<cheap|standard|reviewer>
Goal: <what to accomplish>
Context: <the minimum surrounding facts needed for judgment calls>
Inputs: <absolute paths, search terms, data>
Expected output: <exact format + hard size cap, e.g. "≤30 lines, table of path|line|finding">
Constraints: <scope limits, e.g. read-only, this directory only>
```

**On results.** Verify before incorporating: spot-check one concrete claim, validate that
referenced paths/symbols exist, check the full scope was covered. For counts and measurements,
the brief must instruct the worker to use deterministic commands (`wc`, `grep -c`) — cheap models
miscount by hand and answer confidently. Reconcile contradictions
yourself. If output is wrong or empty, re-dispatch with a tighter brief or a higher tier —
never patch garbage. Hard cap: 3 re-dispatch cycles on the same task, then stop and escalate
to the user with all accumulated findings. You write the final synthesis; never pass worker
output through verbatim.

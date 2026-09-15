# Extracting procedures from closed items

**Contents**
- [What you are extracting](#what-you-are-extracting)
- [The procedure record](#the-procedure-record)
- [Worked example: a merged PR](#worked-example-a-merged-pr)
- [Worked example: a recurring action item](#worked-example-a-recurring-action-item)
- [The rework signal catalogue](#the-rework-signal-catalogue)
- [Clustering into candidates](#clustering-into-candidates)
- [The candidate record](#the-candidate-record)
- [Extraction failure modes](#extraction-failure-modes)

## What you are extracting

Not a summary. A **procedure**: the reconstructable sequence someone executed, with its branch points and its definition of done.

The test is whether a competent newcomer could execute it from your extraction alone. "Fixed the migration timeout" fails that test. "Ran the migration in batches of 5k with `--lock-timeout=5s`, monitored replica lag in Grafana, aborted above 30s lag" passes it.

Most items will not give you a complete procedure. Record what is there and mark the rest `unknown`. Gaps are themselves informative: a cluster of items whose steps are all `unknown` usually means the procedure lives entirely in one person's head, which raises the toil score rather than lowering it.

## The procedure record

One per item read closely. JSON or inline notes — the schema matters more than the format.

```json
{
  "source_id": "ENG-1423",
  "url": "https://linear.app/org/issue/ENG-1423",
  "trigger": "Customer reports export missing a column after a schema change",
  "preconditions": ["staging DB access", "member of #data-platform"],
  "steps": [
    {"n": 1, "action": "Locate the Avro schema", "detail": "schemas/exports/*.avsc", "tool": "grep"},
    {"n": 2, "action": "Add field with a default", "detail": "defaults required for backward compat", "tool": "editor"},
    {"n": 3, "action": "Regenerate the Go structs", "detail": "make generate-schemas", "tool": "make"},
    {"n": 4, "action": "Backfill historical partitions", "detail": "unknown — done by @dana, no command recorded", "tool": "unknown"}
  ],
  "decision_points": [
    "If the field is non-nullable, a backfill is required before deploy, otherwise the consumer breaks"
  ],
  "artifacts": ["schema PR", "backfill job run", "changelog entry"],
  "verification": "Consumer integration test in CI, plus a manual row-count check against the prior partition",
  "failure_modes": [
    "Forgot the default → consumers 500 on old records (ENG-1201)",
    "Forgot the changelog → support blindsided (ENG-1355)"
  ],
  "elapsed": "4 days, 11 comments, 2 review rounds",
  "tribal_knowledge": [
    "The backfill job must run before deploy, never after — documented nowhere",
    "@dana is the only person who has run it"
  ]
}
```

`tribal_knowledge` and `failure_modes` are the two fields that most directly become skill content. If an item yields entries in both, read the entire thread carefully — it is worth the tokens.

## Worked example: a merged PR

**Input** (PR #882, "fix flaky checkout test", 14 review comments, 3 force-pushes, 6 days open)

**Naive extraction** — "Fixed a flaky test." Useless: no recurrence handle, no steps, no evidence of cost.

**Useful extraction:**

```json
{
  "source_id": "#882",
  "trigger": "CI flake on checkout suite, ~1 in 8 runs",
  "steps": [
    {"n": 1, "action": "Reproduce under load", "detail": "pytest -n 8 --count 50 tests/checkout", "tool": "pytest"},
    {"n": 2, "action": "Identify shared fixture state", "detail": "session-scoped fixture mutated per test"},
    {"n": 3, "action": "Narrow fixture scope to function", "detail": "cost: +40s suite runtime, accepted"},
    {"n": 4, "action": "Prove the fix", "detail": "200 consecutive runs green before requesting review"}
  ],
  "decision_points": ["Scope narrowing vs. explicit teardown — chose scope, simpler to review"],
  "verification": "200 consecutive green runs, linked in the PR body",
  "failure_modes": ["First two attempts added sleeps; reviewer rejected both"],
  "elapsed": "6 days, 14 comments, 3 force-pushes",
  "tribal_knowledge": [
    "Reviewers here reject retries and sleeps as flake fixes on principle",
    "The house standard is 200 consecutive runs as proof, stated in review but written down nowhere"
  ]
}
```

The mineable content is almost entirely in the last two fields. The pattern — *diagnose a flaky test to root cause, prove with N consecutive runs, never paper over with sleeps* — is a strong skill candidate if it recurs, and the 14 comments are direct evidence of what re-deriving it costs.

## Worked example: a recurring action item

**Input**: three postmortems (INC-31, INC-44, INC-58) each carrying an action item shaped like "add alerting for X before it pages again."

**Extraction**: the three procedures are near-identical — pick a metric, pick a threshold from recent history, write the alert rule, route it, document the runbook link. Two of the three were never completed.

This is the archetype of a high-scoring candidate: high frequency, high toil, high rework, high determinism, plainly agent-actionable. The non-completion is the strongest possible evidence of toil — the work was important enough to write down three times and still did not get done.

## The rework signal catalogue

Ranked by how reliably each predicts a real skill opportunity.

| Signal | Where to find it | Why it is strong |
|---|---|---|
| **Same review comment across different PRs** | Review threads | Direct proof of an unwritten checklist. The reviewer is running a skill in their head. |
| **Recurring postmortem action items** | Incident docs | The org has stated three times that this procedure matters and has not encoded it. |
| **Reopened / reverted / hotfixed** | `reopened_count`, revert commits | The definition of done was wrong or unstated — a skill can state it. |
| **Follow-up item referencing a predecessor** | "Follow-up to ENG-x" in titles/bodies | The first pass missed a step that a procedure would have caught. |
| **One person explaining context to another** | Comment threads | Tribal knowledge caught in the act of transfer. Copy it nearly verbatim. |
| **Long assign-to-first-commit gap** | Timestamps | Ramp-up cost: the assignee had to load context that a skill could carry. |
| **Comment count in the top decile** | `comment_count` | Coordination cost. Sometimes disagreement rather than toil — read before scoring. |
| **Identical file paths across unrelated items** | `files` | The same surface is edited repeatedly, usually by the same procedure. |
| **"How do I…" in a comment thread** | Bodies and comments | Literally a request for a skill. |

Two cautions. Long cycle time alone is weak — it often means the item was deprioritized, not hard. And high comment count sometimes means a genuine design disagreement, which is exactly the kind of judgment you should *not* try to encode.

## Clustering into candidates

Group by the **shape of the work**, not by component, label, or team. Four questions decide whether two items belong together:

1. Same trigger class? (schema change, flaky test, new tenant onboarding, cert rotation)
2. Same decision structure, even with different inputs?
3. Same definition of done?
4. Would one set of instructions serve both without a pile of conditionals?

If 1–3 are yes and 4 is no, you probably have one skill with two reference files rather than two skills. Prefer that shape: it keeps triggering unambiguous, which is the thing that most often makes skills fail in practice.

Name the cluster after the *procedure*, not the domain. `rds-schema-change` beats `database-stuff`. The name should make the trigger obvious to someone who has never read the skill.

## The candidate record

This is the input to `skillmine.py score`. Write these to `work/candidates.json` as a JSON array.

```json
[
  {
    "id": "cand-01",
    "name": "schema-change-propagation",
    "pattern": "Propagate a field addition through Avro schema, generated Go structs, backfill, and changelog, in the order the consumers require.",
    "evidence": ["ENG-1423", "ENG-1201", "ENG-1355", "#882"],
    "scores": {
      "frequency": 4,
      "toil": 4,
      "rework": 5,
      "determinism": 4,
      "actionability": 4,
      "stability": 3
    },
    "artifact": "skill",
    "duplicate_of": null,
    "trigger_language": [
      "add a column to the export",
      "schema change for the events topic",
      "consumer is missing a field"
    ],
    "notes": "Backfill step is undocumented and known only to @dana — highest-value content to capture.",
    "open_questions": ["Exact backfill command; ask @dana before drafting"]
  }
]
```

`trigger_language` should be lifted from the actual wording in the source items rather than paraphrased. That wording is what someone will type when they need the skill, so it belongs in the eventual description nearly verbatim.

## Extraction failure modes

- **Summarizing instead of extracting.** If your steps have no commands, paths, or tool names in them, you summarized.
- **Inventing plausible steps.** The corpus is the authority. `unknown` is a legitimate and useful value.
- **Mining only titles.** Titles cluster beautifully and teach nothing. The procedure is in the thread.
- **Clustering by label.** Labels reflect ownership and triage, not procedure shape.
- **Treating one dramatic incident as a pattern.** A single memorable outage will dominate your attention out of proportion to its frequency. The gate is three occurrences, regardless of how vivid one of them is.
- **Extracting the domain instead of the procedure.** "Payments work" is a domain. "Reconcile a failed Stripe webhook against the ledger" is a procedure.

# Scoring and artifact selection

**Contents**
- [The model](#the-model)
- [Gates](#gates)
- [Dimension anchors](#dimension-anchors)
- [Tiers](#tiers)
- [The artifact decision matrix](#the-artifact-decision-matrix)
- [When the answer is "fix the system"](#when-the-answer-is-fix-the-system)
- [Calibration notes](#calibration-notes)
- [Worked scoring examples](#worked-scoring-examples)

## The model

Six dimensions, each 0–5, combined into two composites and one priority number.

```
impact      = 0.40·frequency + 0.35·toil + 0.25·rework          # 0–5
feasibility = 0.40·determinism + 0.40·actionability + 0.20·stability  # 0–5
priority    = impact × feasibility                               # 0–25
```

Multiplying rather than adding is deliberate. A pattern that recurs constantly but cannot be executed by an agent scores near zero, which is correct — it is a documentation opportunity, not a skill opportunity. Addition would let high impact mask zero feasibility, which is precisely the mistake that produces skills nobody can run.

`scripts/mindcraft.py score` computes this. Score the six dimensions by judgment against the anchors below; let the script do the arithmetic and the gating so the ranking is reproducible and re-runnable after someone disputes a score.

## Gates

Applied before scoring. A gated candidate appears in the rejected section of the report with its reason — visible, not deleted, because "we considered this and here is why not" is often the most useful part of the report to a reader who was about to propose it.

| Gate | Condition | Reason code |
|---|---|---|
| Evidence | fewer than 3 cited source items | `insufficient-evidence` |
| Rarity | `frequency` < 2 | `too-rare` |
| Actionability | `actionability` < 2 | `not-agent-actionable` |
| Duplication | `duplicate_of` is set | `duplicate` |

The evidence gate does the most work. It is the difference between a report grounded in the corpus and a report of things that sound like they ought to be true of any engineering team.

## Dimension anchors

### frequency — how often the pattern occurred in the window

| | |
|---|---|
| 0 | Once. Not a pattern. |
| 1 | Twice, and the two look coincidental. |
| 2 | 3–4 occurrences, or 2 with a strong structural reason to expect more (new subsystem, new customer tier). |
| 3 | 5–8 occurrences. Clearly recurring. |
| 4 | 9–15 occurrences, or a fixed cadence (every release, every onboarding). |
| 5 | 16+, or daily/near-daily. |

Normalize to the window and say so. Nine occurrences in 90 days is a 4; nine in three years is a 2.

### toil — cost per occurrence, in the currency chosen in Phase 0

| | |
|---|---|
| 0 | Trivial, minutes, no context loading. |
| 1 | Under an hour, mostly mechanical. |
| 2 | A few hours, or needs a context reload each time. |
| 3 | A day, or requires a handoff to a specific person. |
| 4 | Multiple days, or blocks others while it happens. |
| 5 | A week-plus, or pages someone, or blocks a release. |

Prefer observable proxies from the corpus — cycle time, comment count, number of participants, review rounds — over intuition about how hard the work "feels."

### rework — how often it goes wrong or has to be redone

| | |
|---|---|
| 0 | Never observed to fail. |
| 1 | One instance needed a minor follow-up. |
| 2 | Occasional follow-ups, no user impact. |
| 3 | Regular follow-ups, or a recurring review comment catching the same miss. |
| 4 | Frequent rework, reverts, or reopens. |
| 5 | Caused an incident, or reworked more often than not. |

### determinism — how repeatable the procedure is

| | |
|---|---|
| 0 | Pure judgment. Every instance is genuinely novel. |
| 1 | Mostly judgment with a thin shared scaffold. |
| 2 | Recognizable shape, heavy case-by-case variation. |
| 3 | Stable steps with real decision points that need reasoning. |
| 4 | Stable steps with a few well-understood branches. |
| 5 | Same steps every time. (At 5, suspect a script rather than a skill — see the matrix.) |

### actionability — can an agent execute it with tools that exist now

| | |
|---|---|
| 0 | Requires physical presence, or authority an agent cannot hold. |
| 1 | Requires access nobody is willing to grant an agent. |
| 2 | Agent can prepare and draft; a human must execute the consequential steps. |
| 3 | Agent can execute most of it; one or two human checkpoints. |
| 4 | Agent can execute end to end with a review before the irreversible step. |
| 5 | Fully agent-executable, reversible, verifiable. |

A 2 is not a rejection — "agent drafts, human applies" is a legitimate and common skill shape, and often the right one for anything touching production.

### stability — how long the encoded knowledge stays correct

| | |
|---|---|
| 0 | Changing now. Would be stale on arrival. |
| 1 | Weeks. Tied to an active migration. |
| 2 | A quarter or so. |
| 3 | Roughly a year. |
| 4 | Multi-year. Tied to an architecture unlikely to move. |
| 5 | Effectively permanent. Domain or regulatory rather than implementation. |

Low stability does not veto a skill, but it should appear in the notes: a skill encoding a migration is worth building if the migration has 40 instances left, and worth skipping if it has 4.

## Tiers

| Priority | Tier | Meaning |
|---|---|---|
| ≥ 15.0 | `build-now` | Strong on both axes. Build in this cycle. |
| 9.0 – 14.99 | `backlog` | Real, not urgent. Revisit next review or when frequency climbs. |
| 4.0 – 8.99 | `monitor` | Plausible pattern, thin evidence. Recheck next window. |
| < 4.0 | `drop` | Document the finding; do not build. |

Expect a healthy 90-day corpus to yield roughly 2–5 `build-now` candidates. Substantially more usually means the scores are inflated; zero usually means the corpus is too small or too heterogeneous, which is itself a finding worth reporting.

## The artifact decision matrix

Run each surviving candidate through this before writing a proposal. Skills are one option and frequently not the best one.

| If the pattern is… | Build | Why |
|---|---|---|
| determinism 5, actionability 5, no judgment | **script / CLI** | A skill adds a triggering step and a context read to something that should just run. Ship the script; wrap it in a skill only if choosing *when* to run it needs judgment. |
| deterministic and checkable at merge time | **CI check, linter rule, pre-commit hook** | Automation that cannot be forgotten beats a skill that must be invoked. This is the correct answer for most "same review comment repeatedly" findings. |
| needs live external data or write access | **MCP tool / connector** (+ a thin skill) | Skills carry procedure, not credentials or live access. |
| determinism 3–4, real decision points, context assembly | **skill** | The sweet spot: judgment plus a stable procedure plus org-specific knowledge. |
| stable facts, consulted occasionally | **doc / reference file** | If it is read rather than executed, a doc in the place people already look wins. |
| covered by an existing skill at ~80% | **extend that skill** | A near-duplicate skill fragments triggering and both end up under-firing. |
| recurring purely because a system is broken | **fix the system** | See below. |
| judgment-dominant, genuinely novel each time | **nothing** | Some work is just the job. |

A single candidate often decomposes: a script for the mechanical core, a CI check for the forgettable part, and a skill that decides when to use each and handles the judgment around them. Say so explicitly — a decomposed proposal is more useful than a monolithic one, and it lets the cheap pieces ship first.

## When the answer is "fix the system"

Some patterns recur because something upstream is broken: a flaky deploy pipeline, a missing API, a schema that forces manual reconciliation, an alert with no runbook. A skill that routes around this makes the breakage permanent and moves its cost from visible (people complain) to invisible (the agent absorbs it).

Flag these explicitly with the underlying defect and the evidence for it. Then, if the fix is not happening this quarter, propose the skill anyway as stated mitigation with an expiry condition: *build this, and delete it when ENG-900 lands.* Naming the expiry is what keeps the mitigation from silently becoming the architecture.

## Calibration notes

- **Score the corpus, not your priors.** If deploys look risky but only two closed items touch deploys, `frequency` is 2. Note the intuition separately as a hypothesis to check next window.
- **Do not double-count.** A pattern that is high-toil *because* it is high-rework should not get a 5 in both; pick the primary driver and note the linkage.
- **Frequency dominates by design** (0.40 weight, plus the rarity gate). Skills earn their keep through repetition; a spectacular one-off is a story, not a skill.
- **Round to whole numbers.** Half-points imply a precision the evidence does not support and make disagreement harder to express.
- **Write one sentence of justification per score.** It makes the numbers auditable and it is where you will catch yourself inflating.

## Worked scoring examples

**Recurring postmortem action item — "add alerting before it pages again"** (INC-31, INC-44, INC-58, two never completed)

frequency 3 · toil 3 · rework 4 · determinism 4 · actionability 4 · stability 4
→ impact 3.25, feasibility 4.0, **priority 13.0 → backlog**, artifact `skill`

Strong on every axis but frequency, which the corpus caps at three occurrences. Honest outcome: real, build it after the higher-frequency work. The two incomplete instances belong in the notes as evidence of toil.

**"Reviewer asks for a changelog entry"** (11 PRs)

frequency 4 · toil 1 · rework 3 · determinism 5 · actionability 5 · stability 4
→ impact 2.70, feasibility 4.80, **priority 12.96 → backlog**, artifact **CI check, not a skill**

Frequent and perfectly deterministic, but cheap per occurrence. The matrix routes it to a merge check, which costs an afternoon and never forgets. Proposing a skill here would be the classic mining error: a real pattern, the wrong artifact.

**"Onboard a new enterprise tenant"** (7 tickets, 3 reopened for missed steps)

frequency 3 · toil 4 · rework 4 · determinism 4 · actionability 3 · stability 3
→ impact 3.20, feasibility 3.40, **priority 10.88 → backlog**, artifact `skill`

Sits just under `build-now`. If the sales pipeline implies onboarding volume doubles next quarter, frequency becomes 4, priority becomes 13.4 — still backlog. Note the sensitivity rather than nudging a score to reach the tier you want.

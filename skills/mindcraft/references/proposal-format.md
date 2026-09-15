# Output formats

Two deliverables: a findings report, and one skill stub per `build-now` candidate.

**Contents**
- [The findings report](#the-findings-report)
- [The skill stub](#the-skill-stub)
- [Writing the description](#writing-the-description)
- [Handing off to skill-creator](#handing-off-to-skill-creator)

## The findings report

`scripts/mindcraft.py report` renders the ranked tables, the rejected section, and the signals appendix from scored candidates. Write the corpus statement and the per-candidate narrative yourself — the script cannot know how you sampled or what you noticed.

Structure:

```markdown
# Skill mining review — <scope>, <window>

## Corpus
<N> closed items from <sources>, <date range>. Read closely: <M> (<sampling method>).
Not covered: <what was excluded and why>.

## Summary
<2–4 sentences. What the closed work actually shows. Lead with the finding,
not the method.>

| # | Candidate | Artifact | Priority | Tier | Evidence |
|---|---|---|---|---|---|
| 1 | schema-change-propagation | skill | 14.2 | backlog | ENG-1423, ENG-1201, ENG-1355 (+3) |

## Build now
### 1. <name> — priority <x>, <artifact>
**Pattern.** <One paragraph: the procedure, its trigger, its definition of done.>
**Evidence.** <Item IDs with one line each on what that item contributes.>
**Why it recurs.** <Root cause. If a broken system, say so.>
**What the skill would contain.** <Concrete: the steps, the checks, the tribal
knowledge captured, the scripts bundled.>
**Scores.** frequency 4 · toil 4 · rework 5 · determinism 4 · actionability 4 · stability 3
**Open questions.** <What you could not determine from the corpus, and who to ask.>

## Backlog
<Same shape, compressed to a paragraph each.>

## Not recommended
| Candidate | Reason | Detail |
|---|---|---|
| deploy-orchestration | not-agent-actionable | Requires prod credentials nobody will grant an agent; propose an MCP connector instead. |
| billing-edge-cases | insufficient-evidence | Only 2 items, and they share no procedure. |

## Fix the system instead
<Patterns that exist because something upstream is broken. Defect, evidence,
and the expiry condition if a mitigating skill is built anyway.>

## Signals appendix
<Script output: n-grams, rework markers, path churn, outliers. Raw material so
the reader can check the clustering rather than take it on faith.>
```

Two sections carry disproportionate weight. **Not recommended** is where a reader checks whether you thought carefully or just listed plausible automations. **Fix the system instead** is where the report earns the right to be taken seriously by someone senior, because it declines to paper over a defect.

## The skill stub

One per `build-now` candidate, saved as `proposals/<name>/SKILL.md`. A stub, not a finished skill — `skill-creator` finishes it.

```markdown
---
name: schema-change-propagation
description: Propagate a field addition or type change through the Avro schemas, generated Go structs, historical backfill, and changelog in the order consumers require. Use when adding or changing a column in an export, changing an event topic schema, or when a downstream consumer reports a missing or malformed field. Also use before deploying any change under schemas/exports/, since the backfill must run before the deploy rather than after.
---

# Schema change propagation

## Why this exists
Mined from ENG-1423, ENG-1201, ENG-1355, ENG-1402 (90 days). Three of the four
needed follow-up work: two missed the backfill ordering, one missed the
changelog. The ordering constraint is documented nowhere and is currently known
only to @dana.

## Procedure
1. Locate the schema under `schemas/exports/*.avsc`.
2. Add the field **with a default** — non-defaulted fields break consumers on
   historical records (ENG-1201).
3. `make generate-schemas` to regenerate the Go structs. Commit the generated
   output; CI diffs it.
4. **If the field is non-nullable**, run the backfill *before* deploying.
   Command unverified — confirm with @dana before first use.
5. Add a changelog entry under `CHANGELOG.d/`. Support is blindsided without it
   (ENG-1355).

## Verification
Consumer integration suite in CI, plus a row-count check against the prior
partition.

## Open questions
- Exact backfill invocation (step 4)
- Whether the ordering constraint holds for nullable fields
```

Carry the evidence into the stub. The "why this exists" section is what stops the skill from being deleted in six months by someone who cannot tell whether it was mined from real work or invented.

## Writing the description

The description is the whole triggering mechanism, and skills under-trigger far more often than they over-trigger. Three rules:

**Use the corpus's own words.** You collected `trigger_language` during extraction for exactly this. If tickets say "the export is missing a column," that phrase belongs in the description — it is what someone will type.

**State the trigger contexts, not just the capability.** "Handles schema changes" describes the skill to someone who already knows they need it. "Use when adding a column to an export, when a consumer reports a missing field, or before deploying anything under `schemas/exports/`" reaches someone who does not.

**Include the non-obvious entry point.** The highest-value clause is often the one nobody would think to look for — the pre-deploy check above. That clause is why the skill fires when it matters most.

## Handing off to skill-creator

Then invoke `skill-creator` with the stub and, critically, the source items as test prompts:

```
Build out proposals/schema-change-propagation/SKILL.md.

Test prompts drawn from the mined items:
1. "Need to add a `region` column to the customer export" (ENG-1423)
2. "Consumer is 500ing on old records after yesterday's deploy" (ENG-1201)
3. "Adding two fields to the events topic, what do I need to touch?" (ENG-1402)
```

Real closed items make better test prompts than invented ones, because they are phrased the way the work actually arrives — and you already know what the correct outcome was, since it is recorded in the item.

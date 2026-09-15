---
name: mindcraft
description: >-
Mine closed and resolved work items — tickets, issues, pull requests, epics, goals, action items, incidents, retro notes, changelogs — for recurring procedures worth encoding as agent skills, scripts, or automation. Use whenever someone wants to review completed work for automation or skill opportunities, asks "what skills should we build", runs a retrospective over closed tickets or merged PRs, wants to turn repeated toil into something an agent can execute, audits a backlog or sprint for patterns worth capturing, or wants a postmortem, recurring review comment, or repeated runbook turned into a reusable skill. Reach for this even when the person only says "look at what we shipped last quarter and tell me what to automate."
---

# Mindcraft Skill Miner

Closed work items are the only honest record of what a team actually does. Roadmaps describe intent; closed tickets and merged PRs describe behavior. This skill turns that record into a ranked, evidence-backed list of procedures worth encoding — and is equally firm about which ones should *not* become skills.

The output is a findings report plus draft skill stubs, handed to `skill-creator` for the ones worth building.

## The thesis you are testing

A procedure deserves to be encoded when all of these hold:

1. **It recurred.** Three or more independent occurrences in the corpus. Below that you are pattern-matching on noise.
2. **It was re-derived each time.** Someone reconstructed the steps, asked "where does X live?", or waited on the one person who knew. That re-derivation is the cost you are removing.
3. **It has a stable decision structure.** Same triggers, same branch points, same definition of done — even if the specific inputs vary.
4. **An agent could actually execute it** with tools that exist today.
5. **The knowledge is not already in the model's weights.** "Write a Python function" is base competence. "Our Terraform modules live in `infra/modules`, and RDS changes need a `#dba` review before apply" is not.

If any one fails, the candidate is rejected — with the reason recorded. Rejections are a deliverable, not a failure.

## Scale the effort to the corpus

| Corpus size | Approach |
|---|---|
| Under ~20 items | Read them all directly. Skip the scripts, cluster by hand, score inline. Ceremony costs more than it returns. |
| ~20–200 items | Normalize to JSONL, run `signals` for mechanical repetition, then read the high-signal subset closely. |
| Over ~200 items | Normalize everything, run `signals`, sample: all rework-flagged items, all items above the 75th percentile in cycle time or comment count, plus a random 10% for coverage. |

Announce which tier you are in and why, so the person knows how deep the read went.

## Workflow

### Phase 0 — Frame the review

Establish before gathering anything: which system(s) hold the items, what time window, which team or repo or project, and who consumes the output (an engineer who will build the skills, or a lead who wants a decision). If two or more of these are genuinely ambiguous, ask — otherwise choose sensible defaults (last 90 days, the repo or project in context) and state the choice explicitly so it can be corrected.

Also ask what "expensive" means here: engineer hours, calendar latency, error rate, or on-call load. That choice drives the `toil` scores later, and different answers produce different rankings from the same corpus.

### Phase 1 — Gather the corpus

Read `references/sourcing.md` for concrete extraction commands per system (GitHub via `gh`, Linear via MCP tools, Jira, git history, local task files, transcripts).

Pull *closed/resolved/merged only*. Open items describe hopes; closed items describe what happened. Include the discussion, not just the title — comment threads are where the tribal knowledge is.

Normalize to one JSONL file:

```bash
python3 scripts/mindcraft.py normalize --source github-prs --input raw/prs.json --output work/records.jsonl
```

### Phase 2 — Extract the procedure from each item

Read `references/extraction.md` for the extraction schema and worked examples.

For each item worth reading closely, recover the *procedure that was performed*, not the summary of what changed: trigger, preconditions, ordered steps with the actual commands or tool calls, decision points, artifacts produced, verification, and failure modes. Where the item does not say, write `unknown` rather than inventing a plausible step — invented steps are how a skill-mining report becomes fiction.

Pay disproportionate attention to **rework signal**, which is denser than happy-path signal:

- reopened tickets, reverted commits, follow-up issues that reference a predecessor
- review comments that make the *same request across different PRs* — the single strongest checklist-skill signal there is
- comment threads that are one person explaining context to another
- long gaps between "assigned" and "first commit" (the item needed knowledge nobody had loaded)
- incident postmortems with action items that recur across incidents

Run the mechanical pass to find repetition you would miss by eye:

```bash
python3 scripts/mindcraft.py signals --input work/records.jsonl --output work/signals.json
```

This counts n-grams over titles and labels, flags rework markers, ranks touched file paths, and surfaces cycle-time and comment-count outliers. It finds *lexical* repetition. You find *semantic* repetition — two tickets worded completely differently that describe the same procedure. Use both; neither alone is sufficient.

### Phase 3 — Cluster into candidate patterns

Group extracted procedures by the *shape of the work*, not by component or label. "Add a field to the API" and "Add a field to the export job" may be one pattern (schema change propagation) even though they touch different services and carry different labels.

Every candidate carries an evidence list of at least three source item IDs. A candidate that cannot cite three real items is dropped at this phase, not argued for later. This rule is what keeps the report grounded in the corpus rather than in your priors about what teams usually automate.

### Phase 4 — Dedupe against what already exists

```bash
python3 scripts/mindcraft.py inventory --path ~/.agents/skills --path .agents/skills --output work/inventory.json
```

For each candidate, check whether an existing skill already covers it. Three outcomes: genuinely new; **extend an existing skill** (usually the better answer — a skill that covers 80% of the pattern plus a reference file beats a near-duplicate skill that fragments triggering); or already covered, in which case the real finding may be that the existing skill is not triggering, which is a description problem, not a missing-skill problem.

### Phase 5 — Score and pick the artifact type

Read `references/scoring.md` for the rubric, the anchors for each 0–5 dimension, and the artifact decision matrix.

Score six dimensions (frequency, toil, rework, determinism, actionability, stability), then:

```bash
python3 scripts/mindcraft.py score --input work/candidates.json --output work/scored.json
```

The script applies the gates, computes `impact`, `feasibility`, and `priority = impact × feasibility` (0–25), and assigns a tier. Do not compute these by hand — reproducible arithmetic is the point, and it lets someone re-run the ranking after disagreeing with one of your scores.

Then decide what each candidate should actually *be*. A skill is one option among several, and often not the best one:

- Fully deterministic, same inputs every time → **a script** (possibly bundled inside a skill)
- Deterministic and enforceable at merge time → **a CI check, linter rule, or pre-commit hook**, which never forgets and never needs triggering
- Needs live external data or write access → **an MCP tool or connector**, with a skill wrapping the judgment around it
- Recurring judgment plus context assembly plus a stable procedure → **a skill**
- Referenced rarely, purely factual → **a doc**, linked from wherever people already look
- Recurs because a system is broken → **fix the system**. Say this plainly when the evidence shows it. A skill that routes around a broken deploy pipeline makes the pipeline permanent.

### Phase 6 — Write the findings

Read `references/proposal-format.md` for the report and stub templates.

Produce `findings.md` with the ranked candidates, each carrying its evidence trail, and a rejected-candidates section with reasons. Then write a draft `SKILL.md` frontmatter stub for each build-now candidate — name plus a trigger-rich description drawn from the *actual language in the source items*, since that language is what the person will use when they need the skill.

```bash
python3 scripts/mindcraft.py report --input work/scored.json --signals work/signals.json --output findings.md
```

### Phase 7 — Hand off

Offer to build the top-ranked candidate with `skill-creator`, which handles drafting, test prompts, evaluation, and packaging. Carry the mined evidence in: the source items become the test prompts, which makes them realistic by construction rather than imagined.

## Honesty constraints

These exist because a skill-mining report is unusually easy to fake — the genre rewards confident lists, and nobody checks the citations.

- **Every claim cites item IDs.** "Deploys are error-prone" is an opinion. "Deploys are error-prone: ENG-412, ENG-455, ENG-501 each reverted within 24h" is a finding.
- **Report the corpus honestly.** Say how many items existed, how many you read closely, and how you sampled. A report over 40 of 900 tickets is still useful; a report that implies it covered 900 is not.
- **Rank by evidence, not by how good the skill would be to build.** The most interesting candidate is frequently the rarest one.
- **When the corpus does not support strong findings, say so.** "Twelve closed items, no pattern recurs more than twice — come back after another quarter" is a correct and complete answer.
- **Count occurrences, do not estimate time saved.** You can defend "this pattern appeared 9 times in 90 days." You cannot defend "this saves 14 engineer-hours per month" unless the items carry real time tracking — and if they do, cite it.

## Files

- `references/sourcing.md` — extraction commands and field mappings per system
- `references/extraction.md` — procedure-extraction schema, worked examples, rework-signal catalogue
- `references/scoring.md` — 0–5 anchors per dimension, gates, tiers, artifact decision matrix
- `references/proposal-format.md` — findings report template and skill stub template
- `scripts/mindcraft.py` — CLI: `normalize`, `signals`, `inventory`, `score`, `report`
- `scripts/test_mindcraft.py` — pytest suite for the CLI (`python3 -m pytest scripts/ -q`)

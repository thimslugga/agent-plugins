---
name: adr-skill
description: >-
  Create and maintain Architecture Decision Records (ADRs). 
  Use when the user proposes a significant architectural change, records a 
  refactoring decision, resolves a technical debate, or asks to write, update, 
  deprecate, or supersede an ADR.
compatibility: Requires python.
---

# Architecture Decision Records (ADR) Skill

Write and maintain ADRs: lightweight plain-text files capturing architectural
choices, their context, and their consequences.

## Why ADRs exist

Architecture consists of the decisions that are hard to change. ADRs address
two failures:

- **Context loss.** Future developers cannot see why code was written a certain
  way, and remove constraints they do not know exist. ADRs record the rationale.
- **Discussion decay.** ADRs preserve the conclusion and the forces that shaped
  it, without replaying the debate.

## Rules

1. **Keep it to one or two pages.** An ADR records a decision. It is not a
   design specification.
2. **Treat the body as immutable.** Once an ADR is committed, its prose stands
   as the record of what was decided at that time. Only the `status`,
   `supersedes`, and `superseded_by` fields may change afterward.
3. **State the downsides.** Every choice has costs. List negative consequences,
   technical debt incurred, and new constraints accepted.

## Creating an ADR

1. Determine the number from ADR filenames in `docs/adr/`. Increment the highest
   four-digit prefix, or start at `0001` when none exist. The frontmatter `id`,
   H1 heading, and filename prefix must carry the same number.

2. Name the file `NNNN-short-descriptive-title.md` and write it to `docs/adr/`.
   Use lowercase kebab case after the numeric prefix.

3. Build the body from `assets/adr-template.md`. Keep every heading at its
   template level and in order. Where a section does not apply, write one
   sentence explaining why rather than removing or leaving the heading empty.

4. Set `status`:
   - `proposed` — under review, not yet agreed
   - `accepted` — agreed and in force
   - `rejected` — considered and declined; keep the record because the
     reasoning has value

5. Add a row to the index. Rewrite only the content between the
   `BEGIN GENERATED INDEX` and `END GENERATED INDEX` markers in
   `docs/adr/INDEX.md`, preserving everything outside them. Include exactly one
   row per ADR, sorted by ascending numeric ID, with values copied verbatim from
   its filename and frontmatter. Create the index from `assets/index-template.md`
   if it does not exist.

## Superseding a decision

To reverse or replace an accepted decision, make three edits:

1. Write a new ADR with the next number, setting `supersedes: [NNNN]`.
2. On the old ADR, set `status: superseded` and `superseded_by: [NNNN]`.
   Change nothing else in that file.
3. Update both rows in the index.

Use `status: deprecated` instead when a decision is abandoned with no
replacement, leaving `superseded_by` empty.

## Validate the ADR set

Run the bundled validator from this skill directory, passing the project's ADR
directory:

```shell
python scripts/validate_adrs.py <project-root>/docs/adr
```

Use `--json` for machine-readable output. Exit code `0` means the ADR documents,
supersession links, and generated index agree; exit code `1` means validation
failed. Fix every reported error before finishing.

The validator checks deterministic structure and cross-document consistency. It
does not judge page length, prose quality, factual tone, or body immutability;
review those separately because they require human judgment or version history.

## Where documents live

```text
docs/
├── adr/
│   ├── INDEX.md  # index, one line per ADR
│   ├── 0001-use-structured-logging.md
│   └── 0002-migrate-to-sqlite-cache.md
├── rfc/
│   ├── INDEX.md  # index, one line per RFC
│   └── 0001-plugin-permission-model.md
└── design/
    └── type-enrichment-pipeline.md
```

## Before finalizing

- [ ] The forces and constraints that drove the decision are stated.
- [ ] Discarded alternatives are listed with the reason each lost.
- [ ] The Negative consequences list is populated with specifics.
- [ ] The tone is factual, with no unquantifiable praise ("elegant", "clean", "perfect").
- [ ] The index row is added and its number matches the file.
- [ ] `scripts/validate_adrs.py` reports `VALID`.

## Resources

- **`assets/adr-template.md`** — skeleton for ADR files
- **`assets/index-template.md`** — skeleton for `docs/adr/INDEX.md`
- **`scripts/validate_adrs.py`** — deterministic ADR and index validator

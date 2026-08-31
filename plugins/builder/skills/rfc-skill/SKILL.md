---
name: rfc-skill
description: >-
  Create and advance Requests for Comments (RFCs).
  Use when the user proposes a major feature, explores design alternatives 
  under uncertainty, seeks technical consensus, or asks to write, review, 
  approve, reject, or withdraw an RFC. Precedes ADR creation.
compatibility: Requires python.
---

# Request for Comments

RFCs are collaborative design proposals: fluid documents used to explore
options, surface uncertainty, and build consensus before a decision is made.

## RFCs and ADRs

The two document types form one pipeline and differ in what they are for:

- **RFC** is a working document. It presents multiple options, states what is
  still unknown, and changes during review. It may be rejected or withdrawn.
- **ADR** is a settled record. Its body is immutable once committed.

An approved RFC produces one or more ADRs. The RFC stays in place afterward as
the record of *how* the decision was reached; the ADR carries *what* was
decided. Rejected and withdrawn RFCs also stay, since the reasoning has value.

Reach for an ADR directly when the decision is already made and only needs
recording. Reach for an RFC when the question is still open.

## Creating an RFC

1. Determine the number from RFC filenames in `docs/rfc/`. Increment the highest
   four-digit prefix, or start at `0001` when none exist. RFC and ADR numbers are
   independent. The frontmatter `id`, H1 heading, and filename prefix must carry
   the same number.

2. Name the file `NNNN-short-descriptive-title.md` and write it to `docs/rfc/`.
   Use lowercase kebab case after the numeric prefix.

3. Build the body from `assets/rfc-template.md`. Keep every heading at its
   template level and in order. Where a section other than Decision does not
   apply, write one sentence explaining why rather than removing or leaving the
   heading empty. Leave Decision empty while the RFC is open.

4. Set `status: draft`, populate `authors` and `reviewers`, and leave `adr` and
   `outcome` empty.

5. Add a row to the Open table of `docs/rfc/INDEX.md`. See
   [Maintaining the index](#maintaining-the-index).

## Lifecycle

| Status | Meaning |
|---|---|
| `draft` | Author is still writing; not yet open for feedback |
| `in-review` | Open for feedback and under active discussion |
| `approved` | Consensus reached; ADRs created |
| `rejected` | Reviewers declined the proposal |
| `withdrawn` | Author pulled the proposal |

On every transition, update `status` and `updated`, then refresh the index.

On reaching a terminal state (`approved`, `rejected`, or `withdrawn`), fill in
Decision with the outcome, reasoning, conditions, and material changes made
during review.

- For `approved`, create the resulting ADRs and populate `adr`; leave `outcome`
  empty because the index derives its links from `adr`.
- For `rejected` or `withdrawn`, leave `adr` empty and set `outcome` to the short
  reason shown in the index.

## Maintaining the index

Rewrite only the content between the `BEGIN GENERATED INDEX` and
`END GENERATED INDEX` markers in `docs/rfc/INDEX.md`, preserving everything
outside them. Keep both table headers even when a table has no rows.

- Open contains `draft` and `in-review`, sorted by `updated` descending and then
  ID descending. Reviewers are copied from frontmatter and joined with `, `.
- Closed contains `approved`, `rejected`, and `withdrawn`, sorted by `updated`
  ascending and then ID ascending.
- Approved Outcome links are generated from the ADR IDs and matching sibling
  `docs/adr/NNNN-*.md` filenames, joined with `, `.
- Rejected and withdrawn Outcome values are copied from `outcome`.

Write `-` in any generated cell with no value. Create `docs/rfc/INDEX.md` from
`assets/index-template.md` when it does not exist.

## Handing off to ADRs

When an RFC reaches `approved`:

1. Identify each durable decision the RFC settles. One RFC often yields several
   ADRs; split by decision, not by document.
2. Create each ADR using the `adr-skill` skill.
3. Populate the RFC's `adr` field with the resulting four-digit ADR IDs and
   reference the source RFC from each ADR's Context section.

An approved RFC with an empty or unresolved `adr` field is incomplete.

## Validate the RFC set

Run the bundled validator from this skill directory, passing the project's RFC
directory:

```shell
python scripts/validate_rfcs.py <project-root>/docs/rfc
```

Use `--json` for machine-readable output. Exit code `0` means the RFC documents,
lifecycle metadata, ADR handoffs, and generated index agree; exit code `1` means
validation failed. Fix every reported error before finishing.

The validator checks deterministic structure and cross-document consistency. It
does not judge proposal quality, technical correctness, factual tone, or whether
an RFC followed every historical lifecycle transition.

## Where documents live

```text
docs/
├── adr/
│   ├── INDEX.md
│   └── 0001-use-structured-logging.md
├── rfc/
│   ├── INDEX.md
│   └── 0001-plugin-permission-model.md
└── design/
    └── type-enrichment-pipeline.md
```

## Before opening for review

- [ ] The problem is stated with specifics, not generalities.
- [ ] Non-goals are listed, bounding the scope of debate.
- [ ] Alternatives include the null option and the reason each lost.
- [ ] The Drawbacks section names real costs of the proposed approach.
- [ ] Impact covers breaking changes, migration, rollout, and rollback.
- [ ] Open Questions are phrased as questions with options, not topics.
- [ ] The index row is present and matches the RFC metadata.
- [ ] `scripts/validate_rfcs.py` reports `VALID`.

## Resources

- **`assets/rfc-template.md`** — skeleton for RFC files
- **`assets/index-template.md`** — skeleton for `docs/rfc/INDEX.md`
- **`scripts/validate_rfcs.py`** — deterministic RFC, ADR handoff, and index validator

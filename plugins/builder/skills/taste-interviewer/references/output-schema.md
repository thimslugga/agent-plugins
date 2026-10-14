# Voice Profile Output Schema

The compiled profile is a markdown file. Order matters: the quick reference card
comes first because consuming models weight early context; the full Q&A is
evidence and lives in the appendix.

## Frontmatter

Every profile starts with a frontmatter block:

```markdown
---
name: <subject's name>
version: 1
updated: <YYYY-MM-DD>
format: <general | newsletter | social | essays | ...>
interview_date: <YYYY-MM-DD>
questions_asked: <count>
---
```

Bump `version` and `updated` on every refresh. Use `format: general` for the
core profile; format-specific variants share the core and add a Format Deltas
section.

## Section order

1. `# VOICE PROFILE: <name>`
2. `## QUICK REFERENCE CARD`
   - `### Always`: specific patterns to follow, each with a frequency label.
   - `### Never`: specific things to avoid, each with a frequency label. This
     list is the taste; it should be the longest and most specific part of the
     card.
   - `### Signature phrases and structures`: real examples the subject gave.
   - `### Voice calibration`: short quotes from the interview that capture tone.
3. `## CORE IDENTITY`: 2-3 sentences. The only summary section in the file.
4. Category sections (`## BELIEFS`, `## WRITING MECHANICS`, etc.): distilled
   constraints with frequency labels, in the interviewer's words but tightened.
   Every tendency carries one of HARD RULE, STRONG TENDENCY, LIGHT PREFERENCE.
5. `## FORMAT DELTAS` (only for format-specific variants): how this voice shifts
   for the format, and which core rules bend or drop.
6. `## INTERVIEW TRANSCRIPT`: the full Q&A appendix. `### Q<n>: <question>`
   followed by the subject's answer, verbatim or lightly cleaned for clarity.
   This is evidence, not steering.
7. `## ANTI-OVERFITTING GUIDE`: spirit over letter; the frequency tiers and what
   each means; natural variation (do not start every piece the same way, do not
   avoid a word forever); the litmus test ("does this sound like something I
   would actually write, or like an AI trying hard to imitate me?"); the three
   things that matter most if everything else is forgotten.
8. `## HOW TO USE THIS FILE`: instructions for the consuming model: reference
   the card first, treat the file as a source of truth applied with judgment,
   let content dictate structure.

## Frequency labels

- **HARD RULE**: never violate. Rare; mostly the Never list.
- **STRONG TENDENCY**: default 70-80% of the time; breaking it is fine when the
  content demands it.
- **LIGHT PREFERENCE**: nice to have; context decides. The default when no
  stronger signal emerged.

When in doubt, label down, not up. An over-labeled profile produces caricature.

## Worked mini-example

```markdown
## QUICK REFERENCE CARD

### Always
- Open with the concrete thing, not the context-setting. (STRONG TENDENCY)
- Use short paragraphs; one idea each. (STRONG TENDENCY)

### Never
- Never use "leverage" as a verb or "circle back" in any form. (HARD RULE)
- Never open with "In today's fast-paced world". (HARD RULE)
- Never end with a summary of what was just said. (STRONG TENDENCY)
- Never hedge with "I think" or "perhaps" when the point is certain. (STRONG TENDENCY)
```

# asd-ste100

Simplified Technical English (ASD-STE100) for agent output: rewrites dense, ambiguous English into short, single-meaning, active-voice sentences so a downstream agent or system can parse it with no human in the loop to resolve ambiguity. Two modes: Strict (procedures, error messages, tool descriptions, inter-agent instructions) and STE-flavored (READMEs, PR descriptions, prose).

Ported from danyuchn/asd-ste100-skill (MIT). See Attribution below.

## Layout

- `SKILL.md`: the skill: when to use it, the two modes, core rewrite rules (structural rules to apply, lexical rules as direction of travel), the six-habit scan checklist, the sentence-by-sentence process, output format (rewritten text alone by default, rule table on request), boundaries
- `references/writing-rules.md`: fuller summary of the 9 rule sections and dictionary structure, with citations
- `examples/before-after.md`: worked examples, including official STE examples and agent-output examples
- `examples/linter-edge-cases.md`: intentional test fixture for the linter (not compliant prose)
- `scripts/ste-lint.py`: stdlib-only deterministic linter for the structural rules (stdin or file args, `--json`, `--baseline N`, `--disable rule1,rule2`, `--selftest`); never flags hedges or modality
- `agents/openai.yaml`: Codex interface metadata

## Usage

Loads when English text must be parsed without a human to resolve ambiguity: tool descriptions, error messages, inter-agent instructions, system prompts, status reports. Trigger phrases: disambiguate, STE100 rewrite, apply Simplified Technical English, plain-language rewrite, rewrite so an agent cannot misread this. Not for creative or marketing copy.

The linter covers the mechanical structural rules only (semicolons, sentence length, phrasal verbs, nominalization, marketing adjectives, synonym rotation, passive voice, compound tenses, dangling conjunctions). It does not check noun-cluster length, does not verify meaning preservation, and never flags hedges: "The request may have failed." passes clean by design.

It does not reproduce ASD's ~900-word approved dictionary (not freely redistributable); lexical rules are applied as direction of travel, and the skill says so in its output rather than implying dictionary compliance.

## Harness setup

| Harness | Install to |
|---|---|
| Claude Code | `~/.claude/skills/asd-ste100/` |
| Codex | `~/.codex/skills/asd-ste100/` or project `.agents/skills/asd-ste100/` |
| Kiro | `~/.kiro/skills/asd-ste100/` or project `.kiro/skills/asd-ste100/` |
| Muse | `~/workspace/skills/asd-ste100/` |
| Pi | `~/.pi/agent/skills/asd-ste100/` or project `.agents/skills/asd-ste100/` |

The linter needs Python 3 on PATH, nothing else.

## Testing

- SKILL.md frontmatter parses as YAML (`name`, `description`, `version`, `license`); `name` matches the directory.
- `agents/openai.yaml` parses as YAML.
- `scripts/ste-lint.py --selftest` passes; stdlib-only (`json`, `re`, `sys`).
- The documented test fixture behaves as claimed: `examples/linter-edge-cases.md` yields exactly the 2 expected findings.
- Functional checks green: stdin and file input, `--json` output parses, `--baseline` and `--disable` behave, hedge text ("The request may have failed.") passes clean.
- The upstream README's claim verified: SKILL.md lints clean at `--baseline 41` (exactly 41 hard violations; the rule tables quote the patterns they forbid).

## Attribution

- Upstream: [danyuchn/asd-ste100-skill](https://github.com/danyuchn/asd-ste100-skill) (main branch, fetched 2026-10-04). Paths: `SKILL.md`, `LICENSE`, `references/writing-rules.md`, `examples/`, `scripts/ste-lint.py`.
- License: MIT, Copyright (c) 2026 Dustin Yuchen Teng (`LICENSE` kept).
- Changes in this port: added `license: MIT` to the SKILL.md frontmatter; added `README.md` and `agents/openai.yaml`. The SKILL.md body is otherwise byte-faithful to upstream.

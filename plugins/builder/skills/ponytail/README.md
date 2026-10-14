# ponytail

An agent skill that forces the laziest solution that actually works:
simplest, shortest, most minimal. Channels a senior dev who has seen every
over-engineered codebase: question whether the task needs to exist at all
(YAGNI), reach for the standard library before custom code, native platform
features before dependencies, one line before fifty. Supports intensity
levels: lite, full (default), ultra.

Ported from Dietrich Gebert's ponytail project (MIT). See ATTRIBUTION.md.

## Layout

- `SKILL.md` — the skill: persistence contract, the ladder (YAGNI-first
  decision order), rules, output format, intensity levels, when not to be
  lazy, boundaries.
- `agents/openai.toml` — provider-specific adaptation notes.
- `ATTRIBUTION.md` — upstream credit and license.

## Usage

Switch intensity (default is full):

```
/ponytail lite|full|ultra
```

It also activates whenever you say "ponytail", "be lazy", "lazy mode",
"simplest solution", "minimal solution", "yagni", "do less", or "shortest
path", or complain about over-engineering, bloat, boilerplate, or
unnecessary dependencies.

Turn it off with "stop ponytail" or "normal mode". The level persists until
changed or the session ends.

## Design decisions

- **No scripts by design**: the skill is a reasoning posture, not tooling.
  A checker script for over-engineering would be speculative bloat, which
  the skill itself forbids. YAGNI applies to the skill too.
- **Faithful port**: `SKILL.md` preserves the upstream text and structure
  verbatim (including its `license: MIT` frontmatter field); only line
  wrapping was normalized.

## Testing

- Verified all seven ladder rungs, all seven rules, the three intensity
  levels, the off-switch phrases, and the boundaries are present in
  `SKILL.md`.
- Frontmatter validated as YAML (`name`, `description`, `argument-hint`,
  `license`).
- Byte-compared against the upstream source (6,637 bytes upstream;
  1 byte delta is a trailing-newline normalization).

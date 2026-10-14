# poka-yoke

Mistake-proof code so misuse cannot be expressed, rather than warning against it. Design interfaces where invalid states are unrepresentable; audit existing code for footguns; after an incident, fix the hazard (the property that made the mistake available), not just the mistake. Every finding is ranked on two axes: what happens when the mistake occurs (Control / Warning / Detection / rung zero) and how the device notices (contact / fixed-value / motion-step inspection).

Ported from github/awesome-copilot (MIT; original method by rainmanjam/poka-yoke). See ATTRIBUTION.md.

## Layout

- `SKILL.md`: the method: the two ranking axes, designing new interfaces, auditing existing code, post-incident hazard fixing, output quality bar, anti-patterns, and an honest evidence section with the benchmark's limits
- `references/hazard-catalog.md`: the taxonomy of hazard shapes with IDs and devices
- `references/lang-python.md`, `references/lang-typescript.md`, `references/lang-rust-go.md`: language-specific patterns
- `scripts/detect_hazards.py`: stdlib-only heuristic scanner (Python 3.9+): regex rules plus a Python AST pass; `--paths` / `--diff` / `--staged` / `--since`, `--severity`, `--id`, `--all`, `--json`
- `assets/devices/lint/README.md`: how to enable each linter the scanner defers to (ruff, mypy, ESLint, typescript-eslint, eslint-plugin-jest, Clippy, golangci-lint); added in this port, upstream's script pointed at this path but the directory did not exist
- `agents/openai.yaml`: Codex interface metadata
- `agents/harness-notes.md`: per-harness install paths

## Usage

Loads for mistake-proofing work: "make invalid states unrepresentable", "poka-yoke this repo", "review this diff for ways to get it wrong", "make sure this never happens again", type-safe API design, and post-incident reviews. Especially for money, auth, permissions, deletion, migrations, and pipelines where failure is silent.

Run the scanner first (`python3 scripts/detect_hazards.py --paths .`), then read for what no scanner can see. The scanner reports what it scanned: zero files exits 2, never a false all-clear. Findings exit 1, clean exits 0, so `--diff --json` gates CI.

## Harness setup

| Harness | Install to |
|---|---|
| Claude Code | `~/.claude/skills/poka-yoke/` |
| Codex | `~/.codex/skills/poka-yoke/` or project `.agents/skills/poka-yoke/` |
| Kiro | `~/.kiro/skills/poka-yoke/` or project `.kiro/skills/poka-yoke/` |
| Muse | `~/workspace/skills/poka-yoke/` |
| Pi | `~/.pi/agent/skills/poka-yoke/` or project `.agents/skills/poka-yoke/` |

## Testing

- SKILL.md frontmatter parses as YAML (`name`, `description`, `license`, `compatibility`, `metadata`); `name` matches the directory. Already harness-neutral; no Copilot syntax.
- Scanner verified against a fixture with 14 planted hazards: default mode found 10 (7 high, 3 medium) and correctly suppressed the 4 rules a real linter covers (bare except, assert-as-validation, float equality, naive datetime); `--all` re-enabled those plus the dangling-task rule; `--severity high`, `--id C1 F2`, and `--json` filtering all correct; `--diff`/`--staged` verified in a scratch git repo.
- Exit contract verified: findings exit 1, clean scan exits 0, zero-files exits 2 with "NOT an all-clear" on stderr.
- `assets/devices/lint/README.md` now exists, so the script's hint no longer dangles.
- `agents/openai.yaml` parses as YAML.

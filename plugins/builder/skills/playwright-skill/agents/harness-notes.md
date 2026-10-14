# Harness notes: playwright-skill

Install source: https://github.com/lackeyjb/playwright-skill, v5.0.0 (MIT).
Skill payload adapted from upstream `skills/playwright-skill/` with one
deliberate layout change (below). Only `README.md`, `agents/`,
`ATTRIBUTION.md`, and the `LICENSE` copy were added.

## Layout change vs upstream

Upstream keeps `run.js` and `lib/helpers.js` at the skill root. Per local
convention they moved to `scripts/run.js` and `scripts/lib/helpers.js`, and
upstream `API_REFERENCE.md` moved to `references/api-reference.md`.

`scripts/run.js` was edited minimally to keep working after the move: it now
resolves the skill root as `path.resolve(__dirname, '..')` instead of
`__dirname`, so `npm install` / `npm run setup` still run in the skill root,
`node_modules` resolves there, and `PW_SKILL_DIR` still points at the
directory containing `SKILL.md`. `package.json` `main` updated to
`scripts/run.js`. `SKILL.md` path references (`$SKILL_DIR/run.js`,
`$SKILL_DIR/lib/helpers`, the API reference link) were updated to match.
No logic changes.

Upstream dev files intentionally not bundled: `.claude-plugin/`,
`.github/`, `tests/`, `CHANGELOG.md`, `CONTRIBUTING.md`.

## What it needs from the harness

- Node.js 20+, npm, and a shell tool.
- One-time `npm run setup` in the skill directory (Playwright + Chromium).
  Needs network access for that step only.
- A display for headed mode, or `PW_HEADLESS=true` for headless environments.

## Verification at install (2026-10-09)

- `node --check` passes on `scripts/run.js` and `scripts/lib/helpers.js`.
- `SKILL.md` frontmatter parses (name, description, license MIT,
  compatibility note, version 5.0.0).
- The `references/api-reference.md` link resolves.
- `package.json` parses as JSON; `main` points at the moved executor.
- Upstream tests not run here: they need a real Chromium, which this sandbox
  cannot provide reliably.

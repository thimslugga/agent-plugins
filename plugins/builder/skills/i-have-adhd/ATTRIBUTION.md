# Attribution

`i-have-adhd` is packaged as-is from upstream.

- Upstream: ayghri/i-have-adhd (https://github.com/ayghri/i-have-adhd)
- License: MIT, Copyright (c) 2026 Ayoub Ghriss (copied to `LICENSE`)
- Source material: `skills/i-have-adhd/SKILL.md`,
  `skills/i-have-adhd/agents/gemini.toml`,
  `skills/i-have-adhd/agents/openai.yaml`
  (copied 2026-10-04)

Original additions in this install: `README.md`,
`agents/harness-notes.md`, and this file. `SKILL.md` and the agents
files are unchanged from upstream.

Hook bundling (2026-10-04): `hooks/` carries the upstream
`hooks.json`, `always-on.sh`, `always-on.ps1`, and `always-on.mjs`.
Adaptations for the skill-dir layout: the three scripts resolve
`../SKILL.md` instead of the repo's `../skills/i-have-adhd/SKILL.md`,
and the shipped `hooks.json` uses a `__SKILL_DIR__` placeholder
(replaced by `scripts/install-hooks.sh`) instead of the upstream
`CLAUDE_PLUGIN_ROOT` plugin-layout invocation. `SKILL.md` gained a
short "Always-on hooks" assist section pointing at the installer.
New: `scripts/install-hooks.sh` (Claude Code settings merge, Codex
AGENTS.md snippet, `--enable`/`--disable` flag management,
`--dry-run`/`--force`/`--uninstall`).

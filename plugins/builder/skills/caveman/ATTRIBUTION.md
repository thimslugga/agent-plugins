# Attribution

`caveman` is customized from upstream.

- Upstream: JuliusBrussee/caveman
  (https://github.com/JuliusBrussee/caveman), `skills/caveman/`
- License: Apache License 2.0 (copied to `LICENSE`)
- Source material: `skills/caveman/SKILL.md`,
  `skills/caveman/README.md` (fetched 2026-10-04)

Customizations in this install (per the user's request):

- Removed the Classical-Chinese parts: the `/caveman wenyan` alias,
  all `megacave` references, the megacave row of the sibling-skills
  table, the `/megacave` invocation, the megacave example output, and
  the megacave benchmark number.
- The Persistence paragraph now says `/caveman ultra` points at the
  `ultracave` sibling skill, which is not included in this install.
- The README is rewritten in this repo's standard format (what it
  does, layout, usage, testing) with the Chinese-specific content
  dropped.

`SKILL.md` is otherwise faithful to upstream, except the "Hook
install" assist section added at the end. Not carried over: the
`ultracave` sibling skill, the repo's hooks and activation rules, and
the `evals/` benchmarks.

Hook bundling (2026-10-04): `hooks/` is original work written for
this install (not upstream code). `caveman-sessionstart.sh` (POSIX)
and `caveman-sessionstart.mjs` (Node) implement the upstream mode
resolution order (env var, repo-local `.caveman.json`, user config,
default `caveman`) and print this skill's ruleset; valid modes are
off, manual, caveman, ultracave (megacave/wenyan removed by request);
both are fail-open. `hooks/hooks.json` is the Claude Code manifest
template (`__SKILL_DIR__` placeholder). `hooks/caveman-activate.md`
is the static always-on rule derived from `SKILL.md` for agents
without hooks. New: `scripts/install-hooks.sh` (Claude Code settings
merge, Codex project-scope `.codex/` files, `--mode` default-mode
config, `--dry-run`/`--force`/`--uninstall`).

Original additions in this install: `README.md`,
`agents/openai.yaml`, `agents/harness-notes.md`, and this file.

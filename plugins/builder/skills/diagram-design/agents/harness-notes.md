# Harness notes: diagram-design

Install source: https://github.com/cathrynlavery/diagram-design, v2.6.68
(MIT). Skill payload copied verbatim from `skills/diagram-design/` upstream;
only this root README.md, `agents/`, `ATTRIBUTION.md`, and the LICENSE copy
were added. Nothing in `SKILL.md`, `references/`, `assets/`, or `scripts/`
was modified.

## What it needs from the harness

- File read/write and a way to show the user an HTML file (preview, artifact,
  or attachment). The core deliverable is a self-contained `.html` file.
- Python 3 (stdlib only) for `scripts/self_check.py` and `scripts/export_svg.py`.
- Playwright + Chromium only if PNG export is required. SVG export has no
  extra dependencies.

## Harness-neutral already

The skill body is written as progressive-disclosure prompt content with no
Claude/MCP tool references in the hot path, so it ports cleanly. Upstream's
Claude Code slash commands (`commands/` in the repo: doctor, export-diagram,
import-*, profile) are not bundled; each maps to a reference doc already in
`references/` (doctor.md, export.md, import-drawio.md, import-excalidraw.md,
import-mermaid.md, profiles.md).

## Behavioral notes for the agent

- Honor the section-0 style-guide gate on first use in a project; in headless
  runs, fall back to defaults and say so.
- Run `self_check.py` on every generated diagram before delivery.
- Upstream repo also carries dev-only `docs/`, `scripts/`, and CI workflows
  for contributing to the skill itself; intentionally not bundled.

## Verification at install (2026-10-09)

- SKILL.md frontmatter parses (name, description, license MIT, version 2.6).
- All 60 `references/*.md` links from SKILL.md resolve.
- `python3 -m py_compile scripts/*.py` passes for all five scripts.
- `python3 scripts/self_check.py assets/example-flowchart.html` returns OK.

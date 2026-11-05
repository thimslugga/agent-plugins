# diagram-design

Generate branded diagrams as self-contained HTML files with inline SVG, using an
editorial design system. Forty-four visual types: architecture, architecture delta,
flowchart, sequence, state machine, ER/data model, timeline, swimlane, quadrant,
radar/spider, polar, loop/flywheel, nested, tree, org chart, layer stack, exploded
axonometric, axonometric plan, Venn, pyramid/funnel, treemap, heatmap, bar, waterfall,
line, Gantt, scatter, Sankey, fishbone, Wardley map, kanban, user journey, deployment,
dependency graph, UML class, story map, DB schema, and more. Imports `.drawio`,
Mermaid, and `.excalidraw` sources.

Upstream: https://github.com/cathrynlavery/diagram-design (MIT, v2.6.68 at install).

## Layout

- `SKILL.md` — the skill itself (progressive disclosure: read it first, then the
  type and semantic references it points to as needed).
- `references/` — 60 reference docs: one per diagram type (`type-*.md`), semantic
  patterns, style guide, onboarding, profiles, import/export procedures, primitives.
- `assets/` — example diagram HTML files (~200) showing every visual type in light,
  dark, and full-bleed variants; used as style targets.
- `scripts/` — Python helpers, all runnable with stdlib-only Python 3 except where
  noted:
  - `self_check.py` — verify a generated diagram (accessible-SVG contract,
    single-file safety, motion contract). No third-party deps.
  - `export_svg.py` — HTML to standalone SVG.
  - `drawio_extract.py`, `excalidraw_extract.py`, `mermaid_extract.py` — import
    helpers.
- `agents/openai.yaml` — Codex UI metadata.
- `LICENSE` — upstream license.

## Usage

Drop this directory into any agent's skills folder (for example
`~/workspace/skills/diagram-design/`). No install step, no dependencies for the
core workflow. When the agent needs a diagram, it reads `SKILL.md` and follows the
referenced type/semantic docs.

First-use behavior is built into the skill: section 0 of `SKILL.md` is a style
guide gate that asks the user to customize branding (website URL, design-system
folder, pasted tokens, saved profile, or keep default) before the first diagram in
a new project. Named client profiles can be saved and reused.

Export: SVG via `scripts/export_svg.py` (pure Python). PNG requires Playwright
plus Chromium; see `references/export.md`.

## Harness notes

- Needs file read/write and a way to show the user an HTML file (preview,
  artifact, or attachment).
- Don't preload all 60 references; load only the type (`type-*.md`) and
  semantic reference the task needs.
- Upstream's Claude Code slash commands (doctor, export-diagram, import-*,
  profile) are not bundled. Harnesses without a /command surface treat each as
  a named procedure backed by its reference doc: `references/doctor.md`,
  `export.md`, `import-drawio.md`, `import-excalidraw.md`, `import-mermaid.md`,
  `profiles.md`.
- In headless runs where the section-0 style-guide gate can't ask, fall back to
  the shipped default tokens and say so.
- Run `scripts/self_check.py` on every generated diagram before delivery.
- Without Playwright, deliver HTML/SVG and note the PNG limitation.
- No remote assets beyond the approved Google Fonts stylesheet. In
  network-restricted sandboxes, prefer system font stacks or note the font
  substitution.
- The skill defers quick unicode diagrams to wiretext and attribute-only
  before/after comparisons to tables; don't force a diagram where prose or a
  table serves better.

## Testing

- At install (2026-10-09), `SKILL.md` frontmatter parsed with `name`,
  `description`, `license: MIT`, and payload version 2.6.
- `python3 -m py_compile scripts/*.py` — all five scripts compile.
- `python3 scripts/self_check.py assets/example-flowchart.html` — passes (`OK`).
- All 60 `references/*.md` links from `SKILL.md` resolve.

Not run here: full diagram generation (needs a model pass) and PNG export
(needs Playwright/Chromium in the target environment).

## Attribution

- Upstream: [cathrynlavery/diagram-design](https://github.com/cathrynlavery/diagram-design), v2.6.68.
- License: MIT, Copyright (c) 2025 Cathryn Lavery (`LICENSE` kept).
- Payload copied verbatim from upstream `skills/diagram-design/`; nothing in
  `SKILL.md`, `references/`, `assets/`, or `scripts/` was modified. Added:
  `README.md`, `agents/openai.yaml`, and the `LICENSE` copy. Upstream's
  dev-only `docs/`, `scripts/`, and CI workflows are intentionally not bundled.

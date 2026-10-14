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
- `agents/` — harness adaptation notes (`openai.yaml`, `harness-notes.md`).
- `LICENSE`, `ATTRIBUTION.md` — upstream license and credit.

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

## Testing

- `python3 -m py_compile scripts/*.py` — all five scripts compile.
- `python3 scripts/self_check.py assets/example-flowchart.html` — passes (`OK`).
- All 60 `references/*.md` links from `SKILL.md` resolve.

Not run here: full diagram generation (needs a model pass) and PNG export
(needs Playwright/Chromium in the target environment).

# Attribution

- **Upstream**: [github/awesome-copilot](https://github.com/github/awesome-copilot) (main branch, fetched 2026-10-04; sparse checkout of `skills/poka-yoke/`); the method originates at [rainmanjam/poka-yoke](https://github.com/rainmanjam/poka-yoke) (see the SKILL.md `metadata.source` field and its evidence section)
- **Paths**: `skills/poka-yoke/SKILL.md`, `references/` (hazard-catalog, lang-python, lang-rust-go, lang-typescript), `scripts/detect_hazards.py`, plus the repo `LICENSE`
- **License**: MIT (in SKILL.md frontmatter upstream)
- **Modifications in this port**:
  - **Fixed the CI exit contract.** SKILL.md documents `detect_hazards.py --diff --json` as "CI, exits non-zero on findings", but upstream's `main()` returned 0 unconditionally. The script now returns 1 when reportable findings exist, 0 when clean, 2 when zero files were scanned (unchanged).
  - **Filled the dangling lint reference.** The script's closing hint says "see assets/devices/lint/", but no `assets/` directory existed upstream. Added `assets/devices/lint/README.md` with per-linter enablement guidance (ruff, mypy, ESLint, typescript-eslint, eslint-plugin-jest, Clippy, golangci-lint) derived from the script's own `COVERED_BY` mapping and device strings.
  - Added `README.md`, `agents/openai.yaml`, and `agents/harness-notes.md` per local convention.
  - SKILL.md body is otherwise faithful to upstream and already harness-neutral.
- **Verification**: scanner run against a 14-hazard fixture (default mode: 10 findings with correct severity, covered rules correctly suppressed; `--all`, `--severity`, `--id`, `--json`, `--diff`, `--staged` all verified); exit codes 1/0/2 verified; `python3 --version` on this box is 3.12, within the stated 3.9+ compatibility. The skill's benchmark claims are upstream's, quoted with their stated limits in SKILL.md; not re-run here.

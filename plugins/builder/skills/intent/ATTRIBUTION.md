# Attribution

- **Upstream**: [ghaida/intent](https://github.com/ghaida/intent) (main branch, cloned 2026-10-08; skill frontmatter version 1.6.0).
- **Paths**: `skills/` (17 skills: `intent` + 16 specialists), `agents/` (6 agent prompts), `LICENSE`.
- **License**: CC0-1.0 (upstream LICENSE kept in this port).
- **Modifications in this port**:
  - Restructured as a single workspace skill: the upstream `intent` foundation skill became the root `SKILL.md` (with its `references/` moved to the root alongside it); the other 16 skills sit under `skills/<name>/`; the 6 agent prompts sit under `upstream-agents/` (kept out of `agents/` to preserve the local convention that `agents/` holds `openai.yaml` + `harness-notes.md`).
  - Rewrote `/skillname` slash-command references to relative file paths throughout (`skills/<name>/SKILL.md` from the root skill, `../<name>/SKILL.md` between nested skills, `../skills/<name>/SKILL.md` from the agents). Self-references to `/intent` point at the root `SKILL.md`.
  - Adapted the invocation banner trigger line ("When `/intent` is invoked" → "When this skill is invoked"); the banner content itself is unchanged.
  - Added `README.md`, `agents/openai.yaml`, and `agents/harness-notes.md` per local convention.
  - Skill bodies are otherwise verbatim from upstream.
- **Verification**: every `SKILL.md` frontmatter parses as YAML with `name`/`description`/`version`; no remaining `/skillname` slash references; every internal markdown link target resolves on disk.

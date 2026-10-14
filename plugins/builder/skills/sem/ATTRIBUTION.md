# Attribution

- **Upstream**: [Ataraxy-Labs/sem](https://github.com/Ataraxy-Labs/sem) (main branch, fetched 2026-10-04)
- **Paths**: `skills/sem/SKILL.md` (identical to `agent-skill/SKILL.md` in the same repo; the user pointed at the `skills/` copy)
- **License**: MIT OR Apache-2.0 (both LICENSE-MIT and LICENSE-APACHE kept in this port)
- **Modifications in this port**:
  - Added `README.md`, `agents/openai.yaml`, and `agents/harness-notes.md` per local convention.
  - SKILL.md is otherwise faithful to upstream, including its frontmatter.
- **Verification**: frontmatter parses (`name`, `description`, `license`, `compatibility`, `metadata`); `name` matches the directory. Docs-only skill, no scripts. The CLI commands were not smoke-tested: the `sem` binary is not installed in this environment.

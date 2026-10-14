# Attribution

- **Upstream**: [ast-grep/agent-skill](https://github.com/ast-grep/agent-skill) (main branch, fetched 2026-10-04)
- **Paths**: `ast-grep/skills/outline/SKILL.md`
- **License**: MIT, per the repo README ("This skill follows ast-grep's MIT license for any included documentation or examples"). The repo ships no LICENSE file.
- **Modifications in this port**:
  - Added `license: MIT` to SKILL.md frontmatter.
  - Added `README.md`, `agents/openai.yaml`, and `agents/harness-notes.md` per local convention.
- **Verification**: the documented commands were smoke-tested against ast-grep 0.45.3 (`outline <file>`, `--items imports`/`exports`, `--view signatures`/`expanded`, `--match` + `--type`, directory scan, `--json=stream`); all green.

# Attribution

- **Upstream**: [ast-grep/agent-skill](https://github.com/ast-grep/agent-skill) (main branch, fetched 2026-10-04)
- **Paths**: `ast-grep/skills/ast-grep/` (`SKILL.md`, `references/rule_reference.md`)
- **License**: MIT, per the repo README ("This skill follows ast-grep's MIT license for any included documentation or examples"). The repo ships no LICENSE file.
- **Modifications in this port**:
  - Added `license: MIT` to SKILL.md frontmatter.
  - Added `README.md`, `agents/openai.yaml`, and `agents/harness-notes.md` per local convention.
  - Did not port the repo's second skill, `ast-grep-outline` (`ast-grep/skills/outline/SKILL.md`); it is a separate skill and was out of scope for this install.
- **Verification**: the skill's core workflow was smoke-tested against ast-grep 0.45.3 (inline rules via `--stdin`, rule files via `--rule`, `run --pattern`, composite `all`/`not`/`has` rules, `--json` output, `--debug-query=pattern`); all green. One upstream README claim found stale: zero-match `run` exits 1 on 0.45.3, not 0 as the README says. The skill body makes no such claim.

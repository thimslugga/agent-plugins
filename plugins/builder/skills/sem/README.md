# sem

Entity-level code questions in any Git repo: sem parses 30+ languages with tree-sitter and answers about functions, classes, methods, and the calls between them. Four questions, four verbs: where is it (`sem find`, `sem grep`), what does my change touch (`sem impact`), is it correct (`sem check`), what should a human review (`sem certify`). Plus `sem diff` (entity-level diffs), `sem graph`, and `sem history`.

Ported from Ataraxy-Labs/sem (MIT OR Apache-2.0). See ATTRIBUTION.md.

## Layout

- `SKILL.md`: the skill: the four questions and their verbs, MCP-first guidance, the full CLI reference, how to draw the blast radius in a reply, the install check
- `agents/openai.yaml`: Codex interface metadata
- `agents/harness-notes.md`: per-harness install paths

## Usage

Loads for entity-level code questions: where something is defined or called, what a change breaks, which tests to run, whether a change is correct, what changed in a commit or PR, what to review. Use proactively before refactors and in code review, where line-level git output is noisy.

Prerequisite: the `sem` CLI on PATH (the skill's compatibility field says so). It is not installed in this environment yet. If the agent has the sem MCP server (tools named `mcp__sem__*`), the skill says to call those instead of the shell.

## Harness setup

| Harness | Install to |
|---|---|
| Claude Code | `~/.claude/skills/sem/` |
| Codex | `~/.codex/skills/sem/` or project `.agents/skills/sem/` |
| Kiro | `~/.kiro/skills/sem/` or project `.kiro/skills/sem/` |
| Muse | `~/workspace/skills/sem/` |
| Pi | `~/.pi/agent/skills/sem/` or project `.agents/skills/sem/` |

## Testing

- SKILL.md frontmatter parses as YAML (`name`, `description`, `license`, `compatibility`, `metadata`); `name` matches the directory.
- `agents/openai.yaml` parses as YAML.
- Docs-only skill: no scripts to run.
- Not verified: the CLI commands themselves, because the `sem` binary is not installed here. The skill is inert without it.

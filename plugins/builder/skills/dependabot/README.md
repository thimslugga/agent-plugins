# dependabot

Comprehensive guide for configuring and managing GitHub Dependabot: writing and optimizing `dependabot.yml`, grouped updates, monorepo patterns, multi-ecosystem groups, security update configuration, auto-triage rules, ignore and allow rules, private registries, and PR comment commands. Covers all 23 supported ecosystems with a four-step configuration workflow (detect ecosystems, map directories, configure entries, optimize).

Ported from github/awesome-copilot (MIT). See Attribution below.

## Layout

- `SKILL.md`: the skill: the three Dependabot capabilities, the four-step configuration workflow, monorepo strategies, grouping, multi-ecosystem groups, PR customization, schedule optimization, security updates, PR commands, ignore/allow rules, advanced options, FAQ, pre-commit scanning
- `references/dependabot-yml-reference.md`: complete YAML options reference
- `references/example-configs.md`: real-world configuration examples
- `references/pr-commands.md`: full PR comment commands reference
- `agents/openai.yaml`: Codex interface metadata

## Usage

Loads when the user asks about creating or optimizing `dependabot.yml`, managing Dependabot pull requests, dependency update strategies, grouped updates, monorepo patterns, security update configuration, or supply-chain security topics related to Dependabot.

The "Pre-Commit Dependency Scanning via AI Coding Agents" section was rewritten in this port to be agent-agnostic (upstream gave Copilot CLI and Copilot Chat setup steps). It names three ways for an agent to reach GitHub: the GitHub MCP Server's `dependabot` toolset, the `gh` CLI, or a harness GitHub connector.

## Harness setup

| Harness | Install to |
|---|---|
| Claude Code | `~/.claude/skills/dependabot/` |
| Codex | `~/.codex/skills/dependabot/` or project `.agents/skills/dependabot/` |
| Kiro | `~/.kiro/skills/dependabot/` or project `.kiro/skills/dependabot/` |
| Muse | `~/workspace/skills/dependabot/` |
| Pi | `~/.pi/agent/skills/dependabot/` or project `.agents/skills/dependabot/` |

## Testing

- SKILL.md frontmatter parses as YAML (`name`, `description`, `license`); `name` matches the directory.
- All three `references/` files SKILL.md points to exist.
- `agents/openai.yaml` parses as YAML.
- All 57 `yaml` code blocks across SKILL.md and the references parse as valid YAML.
- Docs-only skill: no scripts to run.

## Attribution

- Upstream: [github/awesome-copilot](https://github.com/github/awesome-copilot).
- License: MIT, Copyright GitHub, Inc. (`LICENSE` kept).
- Changes in this port: the "Pre-Commit Dependency Scanning via AI Coding Agents" section was rewritten to be agent-agnostic (see Usage); added `README.md` and `agents/openai.yaml`.

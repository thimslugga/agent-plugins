# Builder Agent Plugin

## Installation

Kiro IDE > Powers > Add Custom Power > Import power from GitHub > `https://github.com/thimslugga/agent-plugins/tree/main/plugins/builder`

Kiro installs the plugin at: `~/.kiro/powers/installed/builder/`

## plugin.json

### Keywords

Board activation keywords will affect the dynamic load of the Power:

```json
"keywords": [
  "ai",
  "ai-agents",
  "skills",
  "agent-plugins",
  "mcp",
  "a2a",
  "multi-agent",
  "tool-use",
  "hooks",
  "steering"
]
```

Adding task-oriented terms such as architecture, coding standards, security review, mermaid, and project structure should make activation more likely for relevant requests.

## Powers

### Steering files

- Native steering in `.kiro/steering/` or `~/.kiro/steering/` is loaded directly.
- Steering files inside a Power is available only when that Power is dynamically activated.
- "inclusion: always" means "always while this Power is relevant/active," not "globally in every Kiro session."

Power activation exposes the steering inventory; the agent may still need to read the relevant files through the Power interface.


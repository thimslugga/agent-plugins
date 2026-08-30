# Agent Plugins

Personal agent plugins

## Overview

## Project layout

```text
my-plugin/
  plugin.json              # $schema declares Agent Plugins 1.0 and plugin metadata and configuration
  skills/                  # Portable: agent skills
    test-runner/
      SKILL.md             # Testing skill instructions
      run-tests.sh         # Supporting script
  mcp.json                 # Portable: MCP server configuration
  scripts/
    validate-tests.sh      # Hook script
  com.github.copilot/      # Copilot-specific components
    agents/
      test-reviewer.agent.md  # Code review agent
    commands/
    rules/
    hooks/
      test-reviewer.agent.md  # Code review agent
```

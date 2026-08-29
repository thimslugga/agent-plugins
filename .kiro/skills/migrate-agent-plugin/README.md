# Agent Plugin

An Agent Plugin is a self-contained directory. Every plugin has a root plugin.json; skills and MCP configuration are optional.

## What is it?

Agent Plugin:

```text
my-plugin/
├── plugin.json  # Identifies the plugin + the Agent Plugins version it targets
├── skills/  # Agent Skills in the standard format
│   └── summarize/
│       ├── SKILL.md
│       ├── scripts/
│       │   └── analyze.sh
│       └── references/
│           └── checklist.md
├── mcp.json  # stdio, Streamable HTTP, or HTTP+SSE MCP servers
└── com.vendor.client/                  # Optional client extension
    └── hooks/
        └── hooks.json
├── LICENSE
└── CHANGELOG.md
```

- `plugin.json` identifies the plugin and the Agent Plugins version it targets.
- `skills/` contains Agent Skills in the format defined by the Agent Skills specification.
- `mcp.json` describes stdio, Streamable HTTP, or legacy HTTP+SSE MCP servers.
- Reverse-domain extension namespaces let individual clients add behavior without changing the portable core.
- Hooks and similar capabilities are not portable v1 components. A client can add them through a reverse-domain extension namespace it owns and documents.

## Manifest File

Every Agent Plugin contains exactly one portable manifest at plugin.json in the plugin root. The document must be a JSON object and must declare the canonical schema identifier and a plugin name.

`plugin.json` file:

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
  "name": "hello-plugin"
}
```

<https://agent-plugins.org/plugin-authors/manifest>

## Skills

`skills/greet/SKILL.md`:

```markdown
---
name: greet
description: Greet the user and offer help.
---

Greet the user and offer help.
```

## MCP Servers

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json",
  "mcpServers": {
    "validator": {
      "type": "stdio",
      "command": "./bin/validator",
      "args": ["--data", "${PLUGIN_DATA}/validator"],
      "env": {
        "CONFIG": "${PLUGIN_ROOT}/config.json"
      },
      "cwd": "${PLUGIN_ROOT}"
    },
    "deployment-api": {
      "type": "streamable-http",
      "url": "https://deploy.example.com/mcp",
      "headers": {
        "X-Tenant": "public-tenant"
      }
    }
  }
}
```

- <https://agent-plugins.org/plugin-authors/mcp-servers>
- <https://agent-plugins.org/schemas/1.0.0/mcp.schema.json>
- <https://modelcontextprotocol.io/specification>

## Client Extensions

Client extensions let a particular client define additional manifest data, files, and behavior. Agent Plugins reserves no central registry; namespaces use reverse-domain identifiers to avoid collisions.

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
  "name": "example-plugin",
  "extensions": {
    "com.example.client": {
      "setting": true
    }
  }
}
```

## Vs Kiro Powers

Powers built with the legacy POWER.md format continue to work. For new powers, we recommend using the Agent Plugins format. You can convert existing powers or create new ones using the Power Builder.

Kiro Powers:

```text
my-power/
├── POWER.md             # Identifies the power and contains onboarding steps
├── steering/            # Agent steering in the standard format
│   └── summarize.md
└── mcp.json             # stdio, Streamable HTTP, or HTTP+SSE MCP servers
```

- <https://kiro.dev/powers/>
- <https://kiro.dev/docs/powers/create/>
- <https://kiro.dev/launch/powers/add/?name=power-builder>

## License

Agent Plugins is openly licensed and developed in public. Its initial Technical Steering Committee includes Core Maintainers from Amazon, Cursor, Microsoft, OpenAI, and Vercel.

## References

- <https://kiro.dev/blog/powers-supports-plugins/>
- <https://agent-plugins.org/>
- <https://agent-plugins.org/specification>
- <https://github.com/agentplugins/agent-plugins-spec>
- <https://agentskills.io/specification>
- <https://modelcontextprotocol.io/specification>
- <https://agentclientprotocol.com/get-started/introduction>
- <https://microsoft.github.io/language-server-protocol/>
- <https://cedarpolicy.com/en>

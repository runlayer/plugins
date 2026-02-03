# Runlayer Plugins

A curated collection of Claude Code plugins to supercharge your development workflow.

## Installation

Add this marketplace to Claude Code:

```bash
claude /plugin marketplace add https://github.com/runlayer/plugins
```

Then install any plugin:

```bash
claude /plugin install runlayer-plugins/mcp-builder
```

## Plugins

| Plugin | Description |
|--------|-------------|
| **mcp-builder** | Build production-quality MCP servers for any API or service |
| **plugin-builder** | Build local plugin scaffolds for Claude Code with Runlayer MCP integration |

---

### mcp-builder

A skill that guides you through building MCP (Model Context Protocol) servers from scratch. Covers architecture decisions, tool design patterns, and implementation workflows.

**Supports:** TypeScript, Python, and other languages

**Triggers:**
- "Build an MCP server for [service]"
- "Create MCP tools for [API]"
- "Connect [service] via MCP"

**What you get:**
- Architecture guidance (transport, state, auth)
- Tool design with proper schemas and annotations
- Shared utilities (retry, error handling, pagination)
- Testing and evaluation workflows
- Quality checklist

---

### plugin-builder

A skill that guides you through building Claude Code plugin scaffolds. Integrates with Runlayer MCP to discover available servers and configure tool connectors.

**Prerequisites:** Runlayer MCP must be installed and authorized

**Triggers:**
- "Create a plugin for [domain]"
- "Build a plugin"
- "Scaffold a new plugin"

**What you get:**
- Guided workflow with native UI components
- Skills and/or Commands based on your automation preference
- CONNECTORS.md with available integrations
- .mcp.json configured with real Runlayer server URLs
- Proper directory structure for marketplace or standalone use

**Output structure:**
```
<plugin-slug>/
├── .claude-plugin/plugin.json
├── skills/<skill-name>/SKILL.md
├── commands/<command>.md
├── CONNECTORS.md
└── .mcp.json (if tools needed)
```

## Contributing

1. Fork this repository
2. Create your plugin in a new directory
3. Add a `.claude-plugin/plugin.json` manifest
4. Update `marketplace.json` to include your plugin
5. Submit a pull request

## License

MIT

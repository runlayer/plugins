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

## Contributing

1. Fork this repository
2. Create your plugin in a new directory
3. Add a `.claude-plugin/plugin.json` manifest
4. Update `marketplace.json` to include your plugin
5. Submit a pull request

## License

MIT

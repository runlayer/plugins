# Runlayer Cursor Plugin

MCP governance for Cursor: block shadow MCPs, enforce policies, protect secrets. Includes skills for building MCP servers and Cursor plugins.

## What's Included

### Hooks

- **beforeMCPExecution** -- validates MCP tool calls against Runlayer backend (fail-closed)
- **beforeReadFile** -- blocks access to `.env` and MCP config files
- **sessionStart** -- warns if Runlayer CLI is not configured

### Rules

- **mcp-governance** -- prevents shadow MCP installation, requires user approval
- **secrets-hygiene** -- blocks reading `.env`, `mcp.json`, `.mcp.json` files

### Skills

- **mcp-security-audit** -- scan workspace for shadow MCPs and security risks
- **mcp-builder** -- guided workflow for building production MCP servers (TypeScript/Python)
- **plugin-builder** -- scaffold Cursor plugins with rules, skills, hooks, and MCP integration

### Commands

- `/runlayer:build-mcp` -- start the MCP server build workflow
- `/runlayer:build-plugin` -- start the plugin scaffolding workflow

## Setup

### Prerequisites

The hooks require the Runlayer CLI to authenticate with your tenant:

```bash
# Install uv (if not already installed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Log in to your Runlayer tenant
uvx runlayer login --host https://YOUR-TENANT.runlayer.com
```

Rules, skills, and commands work without any configuration.

### If you have CLI-installed hooks

If you previously installed hooks via `uvx runlayer setup hooks --install`, uninstall them first to avoid duplicates:

```bash
uvx runlayer setup hooks --uninstall --yes
```

## How the Hook Works

The `beforeMCPExecution` hook validates every MCP tool call:

1. Reads credentials from `~/.runlayer/config.yaml`
2. Sends the tool call to Runlayer backend for validation
3. Backend checks if the MCP server is Runlayer-managed
4. Returns allow/deny based on organizational policies

**Fail-closed**: if config is missing, network fails, or response is invalid, the call is blocked.

## License

MIT

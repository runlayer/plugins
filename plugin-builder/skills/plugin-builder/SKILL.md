---
name: plugin-builder
description: Build local plugin scaffolds for Claude Code. Use this skill when the user wants to create a new plugin, scaffold plugin skills/commands, or set up MCP connector configurations. Triggers include "create a plugin", "build a plugin", "scaffold a plugin", "new plugin for [domain]", or any request involving Claude Code plugin development.
---

# Plugin Builder

Build local plugin scaffolds for Claude Code. **Requires Runlayer MCP.**

## Before You Start: Check Runlayer MCP

**MANDATORY REQUIREMENT: This plugin cannot function without Runlayer MCP. There is no alternative. Do not offer to proceed without it. Do not ask the user if they want to continue without it. Do not suggest workarounds.**

1. Check if `mcp__runlayer__list_servers` is available in your tools

2. **If NOT available:**
   - Say: "This plugin requires Runlayer MCP. Let me help you set it up."
   - Ask for their Runlayer URL (e.g., `https://your-org.runlayer.com`)
   - Direct them to: `<their-runlayer-url>/servers/d0b2d0c6-5d87-4f87-a2e1-7f0a60a6c0b5`
   - Tell them to click "Add to MCP client" and follow the setup
   - Say: "Let me know when you've installed it and restarted your agent."
   - **STOP HERE. Do not continue. Do not offer alternatives.**

2b. **If tools exist but return connection/auth errors before you even call them:**
   - Say: "I see Runlayer MCP is configured, but it doesn't seem to be authenticated. Please re-authorize and let me know when you're ready."
   - **STOP HERE. Do not continue. Do not offer alternatives.**

3. **If available** - call `mcp__runlayer__list_servers(scope="accessible")` to test it

4. **If you get an auth error:**
   - Say: "Please re-authorize the Runlayer MCP and let me know when you're ready to continue."
   - **STOP HERE. Do not continue. Do not offer alternatives.**

5. **Only proceed to the next section when `list_servers` returns successfully.**

## Directory Context

**Always check the current directory first:**

1. Run `ls -la` to understand the directory structure
2. Check if this is already a plugin marketplace (look for `.claude-plugin/marketplace.json`)
3. If it's a marketplace, new plugins should be created as subdirectories
4. If it's not a marketplace, confirm with the user where they want to create the plugin
5. **Always ask the user to confirm the location before creating any files**

## Workflow

### Step 1: Gather Server Information

Call these Runlayer tools to understand available integrations:

```
mcp__runlayer__list_servers(scope="accessible")
mcp__runlayer__list_catalog_servers(limit=50)
```

Map the results to potential tool categories (metrics, logs, CRM, ticketing, etc.).

### Step 2: Capture Intent (Use Native UI Components)

Use `AskUserQuestion` with select components rather than freeform questions.

**Question 1: Plugin Name and Description**
Ask for:
- Plugin name (slug format, e.g., `customer-support`)
- 1-2 sentence description

**Question 2: Automation Preference**
```
options:
- "Fully automated (Recommended)" - Skills trigger automatically based on context
- "Manual triggers only" - Commands require explicit /command invocation
- "Both" - Skills for automation, Commands as fallback triggers
```
Default: Fully automated

**Question 3: Items to Generate**
For each capability they want, ask whether it should be a Skill or Command:
- Skill = Reusable expertise that triggers automatically in context
- Command = User-invoked workflow (e.g., `/draft-response`)

Recommend Skill-first with Command as optional fallback.

**Question 4: Tool Categories**
Based on the servers discovered in Step 1, present options:
```
options (multi-select):
- CRM (Salesforce, HubSpot, etc.)
- Ticketing (Zendesk, Jira, Linear, etc.)
- Communication (Slack, Email, etc.)
- Analytics/Metrics
- Knowledge Base/Docs
```

**Question 5: Elicitation Method**
```
options:
- "Native agent UI (Recommended)" - Use select components for user input
- "Freeform questions" - Ask short text questions
```

### Step 3: Generate Files

Create the following structure:

```
<plugin-slug>/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── <skill-name>/
│       └── SKILL.md
├── commands/
│   └── <command-name>.md
├── CONNECTORS.md
└── .mcp.json (only if tools are needed)
```

**Important structure rules:**
- Only `plugin.json` goes inside `.claude-plugin/`
- Skills live in `skills/<name>/SKILL.md`
- Commands live in `commands/<name>.md`
- `.mcp.json` is at the plugin root (not inside `.claude-plugin/`)

### File Templates

**plugin.json:**
```json
{
  "name": "<plugin-slug>",
  "description": "<1-2 sentence description>",
  "version": "1.0.0",
  "author": {
    "name": "<author>"
  }
}
```

**SKILL.md:**
```markdown
---
name: <skill-name>
description: <When this skill should activate. Be specific about triggers and contexts.>
---

# <Skill Title>

<Detailed instructions for how the assistant should behave when this skill activates.>

## When to Use

<Specific triggers and contexts>

## Workflow

<Step-by-step guidance>

## Best Practices

<Domain-specific guidance>
```

**Command .md:**
```markdown
---
name: <command-name>
description: <What this command does>
---

# /<command-name>

<Instructions for executing this command>

## Usage

`/<plugin-name>:<command-name> [args]`

## Workflow

<Step-by-step execution>
```

**CONNECTORS.md:**
```markdown
# Connectors

This plugin can integrate with the following tool categories:

| Category | Placeholder | Available Servers |
|----------|-------------|-------------------|
| CRM | `crm_tool` | Salesforce, HubSpot |
| Ticketing | `ticket_tool` | Zendesk, Jira |
| ... | ... | ... |

## Configuration

Configure your MCP servers in `.mcp.json` based on which services you use.
```

**.mcp.json (only if tools are needed):**
```json
{
  "mcpServers": {
    "<server-name>": {
      "url": "<runlayer-server-url-from-list_servers>"
    }
  }
}
```

**CRITICAL for .mcp.json:**
- Only include this file if the plugin needs external tools
- URLs MUST come from `mcp__runlayer__list_servers` results - never guess URLs
- Use the actual server URLs returned by Runlayer

## Plugin Examples

### Customer Support Plugin
- **Skills:** ticket-triage, customer-research, response-drafting, escalation, knowledge-management
- **Commands (fallback):** /triage, /draft-response, /escalate, /research, /kb-article
- **Tools:** Ticketing (Zendesk), CRM (Salesforce), Knowledge Base

### Sales Plugin
- **Skills:** account-research, call-prep, competitive-intelligence, daily-briefing, draft-outreach
- **Commands (fallback):** /pipeline-review, /call-summary, /forecast
- **Tools:** CRM (Salesforce, HubSpot), Web Research, Enrichment

### DevOps Plugin
- **Skills:** incident-response, deployment-review, metrics-analysis
- **Commands (fallback):** /deploy-status, /incident-summary
- **Tools:** Monitoring (Datadog), CI/CD (GitHub Actions), Alerting (PagerDuty)

## Testing

After generating the plugin, instruct the user to test locally:

```bash
claude --plugin-dir /path/to/<plugin-slug>
```

Then try invoking skills by describing relevant tasks, or commands with `/<plugin-slug>:<command-name>`.

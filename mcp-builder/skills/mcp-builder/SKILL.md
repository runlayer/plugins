---
name: mcp-builder
description: Build, test, and deploy production-quality MCP (Model Context Protocol) servers. Full lifecycle -- build locally, test interactively with MCP Inspector, iterate until working, then optionally deploy to Runlayer. Triggers include "build an MCP server", "create MCP tools", "implement MCP", "add tools for [service]", "connect [service] via MCP", or any MCP server development task.
---

# MCP Server Builder

Build, test, and deploy MCP servers that enable LLMs to accomplish real-world tasks through well-designed tools. Server quality is measured by how effectively agents can use the tools, not by API coverage alone.

## Before You Start

**Ask the user which programming language they want to use before doing anything else.** Use AskQuestion to prompt for their preferred language. Do not proceed until they answer. Then load the corresponding language-specific reference from `references/`:

- **TypeScript** -> read `references/typescript.md`
- **Python** -> read `references/python.md`
- **Other** -> use the language-agnostic patterns in `references/guidelines.md` and adapt to the chosen language

Apply the language-specific conventions (naming, SDK, validation library, project structure, idioms) from the loaded reference throughout the entire build.

## Development Process

Follow six phases in order. **Phases 1-5 are mandatory. Do NOT skip any phase. Do NOT declare the server complete until Phase 5 passes.**

1. **Research & Plan** -- Study the target API (endpoints, auth, data models, rate limits, pagination). Plan tool coverage. Prioritize comprehensive API coverage over workflow shortcuts when uncertain.
2. **Implement** -- Build infrastructure first (API client, auth, errors, formatters), then tools incrementally.
3. **Review & Build** -- Build, lint, fix all errors. Review for duplication, consistent errors, type coverage.
4. **Evaluate** -- Create 10 complex realistic questions requiring multiple tool calls with stable verifiable answers.
5. **Verify (MANDATORY)** -- Test the server by sending real MCP protocol messages. At minimum: initialize, tools/list, and one tool call. Iterate on failures. The server is NOT done until this passes. See `references/testing.md`.
6. **Deploy (Optional)** -- When tests pass, offer to deploy to Runlayer via `uvx runlayer deploy`. See `references/deploy.md`.

## Architecture Decisions

Determine these upfront:

**Transport:**
- `stdio` -- local/CLI tools, single user, simple setup
- `Streamable HTTP` -- remote/cloud, multi-client, serverless. Avoid SSE (deprecated).

**State:**
- Stateless (recommended for remote) -- fresh server per request, horizontal scaling, no session leaks
- Stateful -- when session continuity is required

**Auth:**
- OAuth 2.1 -- remote servers with user identity
- API key via env vars -- simpler integrations
- None -- local-only tools

**Language conventions (applied after user selects language):**

| Language | Server name | Validation | SDK |
|---|---|---|---|
| TypeScript | `{service}-mcp-server` | Zod | `@modelcontextprotocol/sdk` |
| Python | `{service}_mcp` | Pydantic | `mcp` (FastMCP) |
| Other | `{service}-mcp` | JSON Schema | Implement protocol directly |

## Tool Design Rules

1. **Name**: `{service}_{action}_{resource}` in snake_case. Always prefix with service name.
2. **Required fields**: `name`, `title`, `description`, `inputSchema`, `outputSchema`, `annotations`
3. **Annotations**: Set `readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint` on every tool.
4. **Descriptions**: Must precisely match functionality. Include parameter docs, return schema, usage examples (when to use AND when NOT to use), and error conditions.
5. **Schemas**: Use strict mode. Add constraints (min/max/pattern/enum) and `.describe()` on every field.
6. **Responses**: Return both `content` (text) and `structuredContent` (typed data).

For detailed patterns, validation examples, response formatting, error handling, pagination, auth, testing, security, logging, and deployment guidance, read `references/guidelines.md`.

## Project Structure

```
{service}-mcp-server/
├── src/
│   ├── index.ts          # Entry point (dual-mode: local + serverless)
│   ├── tools/            # Tool implementations + registry
│   ├── resources/        # MCP resource handlers (if needed)
│   ├── services/         # API clients, external service wrappers
│   ├── schemas/          # Validation schemas
│   ├── utils/            # Shared helpers (retry, formatting, errors)
│   ├── auth/             # Auth, token storage, middleware
│   └── types/            # Type definitions
├── tests/
│   ├── unit/
│   └── integration/
└── README.md
```

## Implementation Workflow

1. **Scaffold** the project structure above
2. **Build shared utilities first:**
   - `makeApiRequest` -- centralized HTTP client with auth, timeout, retries
   - `handleApiError` -- maps HTTP status to MCP error codes with context
   - `createToolResponse` / `createErrorResponse` -- consistent response envelopes
   - `withRetry` -- exponential backoff (retry 429, 5xx, network errors; skip other 4xx)
3. **Implement tools** one at a time, each with:
   - Schema-validated input (strict mode, constraints, descriptions)
   - Handler wrapped in `withRetry`
   - Both text + structured content in response
   - Pagination for any list operation (default 20-50 items, return `has_more` + `next_offset`)
   - Character limit enforcement (truncate at ~25K chars with message)
4. **Implement resources** if the service has URI-addressable data
5. **Set up transport** (stdio or Streamable HTTP based on deployment target)
6. **Add dual-mode entry point** (serverless handler export + local server start)
7. **Test** -- unit tests for handlers/validators, integration tests gated on env vars
8. **Evaluate** -- 10 QA pairs per the evaluation format

## Quality Checklist

Before declaring the server complete:

- [ ] Every tool has name, title, description, inputSchema, outputSchema, annotations
- [ ] All annotations correctly set (readOnlyHint, destructiveHint, idempotentHint, openWorldHint)
- [ ] All inputs schema-validated with constraints and descriptions
- [ ] Error messages are actionable and safe (no internal details)
- [ ] Retry with exponential backoff on transient failures
- [ ] All list tools support pagination with `has_more` / `next_offset`
- [ ] Character limit enforced with truncation message
- [ ] No duplicated code -- shared utilities extracted
- [ ] Strict typing throughout, no `any` types
- [ ] Async/await for all I/O
- [ ] Auth validated on every request
- [ ] No secrets in logs
- [ ] Build completes without errors

## Phase 5: Verify (MANDATORY -- DO NOT SKIP)

**This phase is required. The server is NOT complete until these tests pass.** Read `references/testing.md` for detailed patterns.

### Minimum Viable Test (always run, no credentials needed)

Even without API credentials, you MUST verify the server works at the MCP protocol level by piping JSON-RPC messages to the server process:

1. **Initialize** -- Send `initialize` request, confirm server responds with `protocolVersion`, `capabilities`, and `serverInfo`.
2. **List tools** -- Send `tools/list`, confirm all expected tools appear with correct names, schemas, and annotations.
3. **Error handling** -- Call a tool (e.g. a read tool) and verify it returns a graceful `isError: true` response (not a crash) when credentials are missing or the resource doesn't exist.

Example for stdio servers:

```bash
# Test 1: Initialize
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}' | node dist/index.js 2>/dev/null

# Test 2: List tools (send initialize + notification + list in sequence)
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}\n{"jsonrpc":"2.0","method":"notifications/initialized"}\n{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}\n' | node dist/index.js 2>/dev/null

# Test 3: Call a tool and verify error handling
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}\n{"jsonrpc":"2.0","method":"notifications/initialized"}\n{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"SERVICE_TOOL_NAME","arguments":{}}}\n' | node dist/index.js 2>/dev/null
```

Adapt `node dist/index.js` for Python (`uv run server.py`) as needed.

**If any test fails, fix the code and re-run. Do not proceed to Phase 6.**

### Full Interactive Testing (when credentials are available)

1. **Start MCP Inspector:**
   - TypeScript: `npx @anthropic-ai/mcp-inspector npx tsx src/index.ts`
   - Python: `npx @anthropic-ai/mcp-inspector uv run server.py`

2. **Test each tool systematically:**
   - Start with read-only tools (lowest risk)
   - Test edge cases: empty inputs, pagination boundaries, max lengths
   - Verify error handling with invalid inputs
   - Test destructive operations last (with user confirmation)

3. **On failure:**
   - Capture the error message from Inspector output
   - Fix the issue in code
   - Re-run the failing test
   - Continue until all tools pass

4. **Exit criteria:** All tools respond correctly to valid inputs and return proper MCP errors for invalid inputs.

## Phase 6: Deploy (Optional)

When all interactive tests pass, ask the user:

> "Your MCP server is working correctly. Would you like to deploy it to Runlayer?"

If yes, read `references/deploy.md` for full details, then:

### Step 1: Collect credentials

Use AskQuestion to prompt for **both** values. Do not guess or skip.

1. **Personal API Key** — "Go to your Runlayer dashboard → Settings → API Keys → Personal API Key. Paste it here."
2. **Runlayer tenant URL** — "What is your Runlayer tenant URL? (e.g. `https://mycompany.runlayer.com` or `https://ecs.prod.runlayer.com`)"

### Step 2: Ensure Streamable HTTP transport

If the server was built with stdio-only transport, **add dual-mode support before deploying**:
- Add `express` dependency
- Add `/health` endpoint (returns `{"status":"ok"}`)
- Add `/mcp` POST endpoint with `StreamableHTTPServerTransport`
- Use `PORT` env var to switch: stdio when no PORT, HTTP when PORT is set
- Rebuild, test health + MCP endpoints locally with `curl`

### Step 3: Create deployment files

1. **Dockerfile** — Use template from `references/deploy.md`. Test locally with `docker build .` before proceeding.
2. **`.dockerignore`** — Exclude `node_modules`, `dist`, `.git`, `.env`, `tests`
3. **Initialize deployment** to get an ID:
   ```bash
   uvx runlayer deploy init --secret <API_KEY> --host <TENANT_URL>
   ```
   This generates `runlayer.yaml` with the deployment ID. Edit it to set `service.port` to match your server.

### Step 4: Deploy

```bash
uvx runlayer deploy --secret <API_KEY> --host <TENANT_URL>
```

### Step 5: Report success

Show:
- Deployment ID
- MCP proxy URL: `https://<tenant>/api/v1/proxy/<deployment-id>/mcp`
- Cursor MCP config snippet for connecting to the deployed server
- Any env vars the user still needs to configure in Runlayer (API keys, credentials for the target service)

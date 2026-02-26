---
name: mcp-builder
description: Build production-quality MCP (Model Context Protocol) servers that enable LLMs to interact with external services through well-designed tools. Use this skill when the user wants to create, scaffold, or implement an MCP server for any API or service, in any language. Triggers include requests to "build an MCP server", "create MCP tools", "implement MCP", "add tools for [service]", "connect [service] via MCP", or any task involving MCP server development, tool design, or MCP architecture decisions.
---

# MCP Server Builder

Build MCP servers that enable LLMs to accomplish real-world tasks through well-designed tools. Server quality is measured by how effectively agents can use the tools, not by API coverage alone.

## Before You Start

**Ask the user which programming language they want to use before doing anything else.** Use AskQuestion to prompt for their preferred language. Do not proceed until they answer. Then load the corresponding language-specific reference from `references/`:

- **TypeScript** -> read `references/typescript.md`
- **Python** -> read `references/python.md`
- **Other** -> use the language-agnostic patterns in `references/guidelines.md` and adapt to the chosen language

Apply the language-specific conventions (naming, SDK, validation library, project structure, idioms) from the loaded reference throughout the entire build.

## Development Process

Follow four phases in order:

1. **Research & Plan** -- Study the target API (endpoints, auth, data models, rate limits, pagination). Plan tool coverage. Prioritize comprehensive API coverage over workflow shortcuts when uncertain.
2. **Implement** -- Build infrastructure first (API client, auth, errors, formatters), then tools incrementally.
3. **Review & Test** -- Build, lint, test with MCP Inspector. Review for duplication, consistent errors, type coverage.
4. **Evaluate** -- Create 10 complex realistic questions requiring multiple tool calls with stable verifiable answers.

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

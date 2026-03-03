# MCP Interactive Testing Guide

Patterns for testing MCP servers locally using the MCP Inspector CLI.

---

## Setup

The [MCP Inspector](https://github.com/modelcontextprotocol/inspector) provides a visual UI and CLI for testing MCP servers.

### Starting the Inspector

Detect language from project files, then launch:

**TypeScript:**
```bash
npx @anthropic-ai/mcp-inspector npx tsx src/index.ts
```

**Python:**
```bash
npx @anthropic-ai/mcp-inspector uv run server.py
```

**With environment variables:**
```bash
npx @anthropic-ai/mcp-inspector -e API_KEY=xxx -e BASE_URL=https://api.example.com npx tsx src/index.ts
```

The Inspector opens a web UI (default `http://localhost:6274`) showing available tools, resources, and prompts.

### CLI Mode (Headless)

For automated testing without the web UI:

```bash
npx @anthropic-ai/mcp-inspector --cli npx tsx src/index.ts
```

CLI mode allows sending JSON-RPC requests directly:

```json
{"method": "tools/call", "params": {"name": "service_list_items", "arguments": {"limit": 5}}}
```

---

## Test Strategy

### Order of Operations

1. **Connection** -- Verify the server starts and Inspector connects
2. **Tool discovery** -- Confirm all tools appear with correct schemas
3. **Read-only tools** -- Test safe operations first
4. **Parameterized tools** -- Test with various input combinations
5. **Edge cases** -- Empty inputs, boundary values, invalid types
6. **Error handling** -- Malformed requests, missing auth, nonexistent resources
7. **Pagination** -- Verify `has_more` / `next_offset` behavior
8. **Destructive tools** -- Create/update/delete operations (with user confirmation)

### Per-Tool Test Checklist

For each tool, verify:

- [ ] Tool appears in Inspector tool list with correct name and description
- [ ] Input schema matches expected parameters
- [ ] Valid input returns structured response with `content` and `structuredContent`
- [ ] Missing required params returns clear error
- [ ] Invalid param types return validation error
- [ ] Empty string / zero / null edge cases handled
- [ ] Response stays under 25K character limit (truncation works)
- [ ] Annotations are correct (`readOnlyHint`, `destructiveHint`, etc.)

---

## Common Test Patterns

### Read-Only Tools

```json
{"method": "tools/call", "params": {"name": "github_list_repos", "arguments": {"limit": 5}}}
```

Verify: returns array, respects limit, includes pagination info.

### Pagination

```json
{"method": "tools/call", "params": {"name": "github_list_repos", "arguments": {"limit": 2, "offset": 0}}}
{"method": "tools/call", "params": {"name": "github_list_repos", "arguments": {"limit": 2, "offset": 2}}}
```

Verify: second call returns different items, `has_more` is correct.

### Error Cases

```json
{"method": "tools/call", "params": {"name": "github_get_repo", "arguments": {"owner": "nonexistent-user-xyz", "repo": "nope"}}}
```

Verify: returns `isError: true` with actionable message, no stack traces.

### Destructive Operations

Always confirm with the user before testing write/delete tools. Use test/sandbox resources when possible.

---

## OAuth / Authenticated Servers

**CLI mode (`--cli`) does not support OAuth flows.** There is no browser to handle the redirect/consent screen.

Options for testing OAuth-protected MCP servers:

| Approach | How |
|---|---|
| **UI mode (recommended)** | Drop `--cli`; the web UI handles the full OAuth dance (enter Client ID, Secret, scope in the Authentication panel) |
| **Pre-obtained token** | Complete OAuth manually, then pass the token: `--header "Authorization: Bearer <token>"` |
| **API key fallback** | Support both OAuth and API key auth in your server; use the key for CLI testing via `-e API_KEY=xxx` |
| **Static headers** | For servers accepting custom headers: `--header "X-API-Key: your-key"` |

For remote Streamable HTTP servers with OAuth:

```bash
# UI mode -- handles OAuth redirect automatically
npx @anthropic-ai/mcp-inspector --transport http --server-url https://my-server.example.com/mcp

# CLI mode -- requires pre-obtained Bearer token
npx @anthropic-ai/mcp-inspector --cli https://my-server.example.com/mcp \
  --transport http \
  --header "Authorization: Bearer <access_token>" \
  --method tools/list
```

---

## Common Failures and Fixes

| Symptom | Likely Cause | Fix |
|---|---|---|
| Inspector can't connect | Server crashes on startup | Check stderr output; fix import/config errors |
| Tool not listed | Not registered in tool registry | Add tool to server's tool list |
| "Invalid params" | Schema mismatch between tool def and handler | Align Zod/Pydantic schema with handler expectations |
| Empty response | Handler returns `undefined`/`None` | Ensure handler returns `{ content: [...] }` |
| Timeout | API call hangs or no response sent | Add timeout to HTTP client; check async/await |
| "Method not found" | Tool name typo or case mismatch | Verify exact tool name in registry |
| Auth error from API | Missing or expired credentials | Check env vars passed via `-e` flag |
| Truncated data | Response exceeds character limit | Verify truncation logic includes "truncated" message |

## Iteration Workflow

```
1. Run test in Inspector
2. If PASS → move to next tool/test
3. If FAIL →
   a. Copy error from Inspector output
   b. Identify root cause (see table above)
   c. Fix code
   d. Inspector auto-reloads on file change (stdio) or restart server
   e. Re-run the same test
   f. Repeat until PASS
4. When ALL tools pass → proceed to Phase 6 (Deploy)
```

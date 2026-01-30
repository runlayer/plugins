# MCP Server Detailed Guidelines

Detailed patterns for input validation, response formatting, error handling, pagination, auth, transport, testing, security, logging, and deployment.

---

## Input Validation

Use schema validation (Zod/Pydantic/JSON Schema) for every tool input:

- Explicit types, constraints (min/max/pattern/enum), and `.describe()` on every field
- `.default()` for optional fields with sensible defaults
- Strict mode to reject unexpected fields
- Custom validators for domain rules (e.g., allowlisted sort fields)

Security validations:
- Sanitize file paths (prevent directory traversal)
- Validate URLs and external identifiers
- Check parameter sizes and ranges
- Prevent command injection in system calls

**TypeScript example:**
```typescript
const SearchInput = z.object({
  query: z.string().min(2).max(200).describe("Search string"),
  limit: z.number().int().min(1).max(100).default(20).describe("Max results"),
  offset: z.number().int().min(0).default(0).describe("Results to skip"),
}).strict();
```

**Python example:**
```python
class SearchInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra='forbid')
    query: str = Field(..., min_length=2, max_length=200, description="Search string")
    limit: int = Field(default=20, ge=1, le=100, description="Max results")
    offset: int = Field(default=0, ge=0, description="Results to skip")
```

---

## Response Formatting

### Dual format support

Support `response_format` parameter with `"json"` and `"markdown"` options:

| Format | Guidance |
|---|---|
| JSON | All fields, consistent naming, complete metadata |
| Markdown | Headers, lists, human-readable timestamps, display names with IDs in parens |

### Structured content

Always return both text and structured data:

```
{
  content: [{ type: "text", text: JSON.stringify(data) }],
  structuredContent: data,
  isError: false
}
```

### Character limit

Define `CHARACTER_LIMIT = 25000`. When exceeded:
1. Truncate data (e.g., halve result set)
2. Set `truncated: true`
3. Add `truncation_message` telling the agent to use offset/filters

### Content encoding

| Content | Encoding |
|---|---|
| Text | UTF-8 |
| Images, PDFs, binary | Base64 |
| Rich text docs | Export as Markdown |
| Spreadsheets | Export as CSV |

Provide `SKIP_INLINE_IMAGES` env var to strip base64 images from responses.

---

## Error Handling

### Three-layer strategy

1. **Framework/middleware**: Catch unhandled errors, log with context, return safe messages. Distinguish auth (401/403) from server (5xx).
2. **API error mapping**: Map HTTP status to MCP error codes:
   - 404 → InvalidParams ("Resource not found")
   - 403 → InvalidRequest ("Permission denied")
   - 429 → InternalError ("Rate limit exceeded")
   - 400 → InvalidParams ("Invalid request parameters")
   - 5xx → InternalError ("Unexpected error")
3. **Tool handler**: try/catch wrapping each tool, passing context to error mapper.

### Error message principles

- **Actionable**: "Try using filter='active_only' to reduce results"
- **Specific**: Include what failed and why
- **Safe**: Never expose stack traces, secrets, or internals
- **Context-aware**: "Failed to read file: Permission denied"

### Error response format

```
{ isError: true, content: [{ type: "text", text: "Error: <message>. <suggestion>" }] }
```

Report tool errors within result objects, not as protocol-level errors.

### Retry with exponential backoff

```
withRetry(handler, {
  maxRetries: 2,
  initialDelayMs: 1000,
  backoffMultiplier: 2,
  maxDelayMs: 10000
})
```

Retry: 429, 5xx, network errors. Skip: other 4xx.

---

## Pagination

Every list tool must support pagination:

```
Input:  { limit: int (default 20, max 100), offset: int (default 0) }
Output: { total, count, offset, items[], has_more, next_offset }
```

Rules:
- Always respect `limit`
- Never load all results into memory
- Default 20-50 items per page
- Return `has_more` and `next_offset`/`next_cursor`
- Support offset-based or cursor-based depending on the underlying API

---

## Authentication & Authorization

### OAuth 2.1 (remote servers)

- Validate access tokens before every request
- Store tokens per-user with expiry tracking
- Support token refresh
- Inject credentials via middleware (keep core logic clean)
- Register clients from env vars at startup

### API key (simpler integrations)

- Store in env vars, never in code
- Validate on startup with clear error messages

### Token storage interface

Implement pluggable backends:
- FileSystem — local dev
- In-Memory — testing
- DynamoDB/Redis/DB — production/serverless

---

## Transport

### stdio (local)

- Single user, simple setup
- Do NOT log to stdout — use stderr
- No network configuration

### Streamable HTTP (remote)

- Multi-client, bidirectional
- Stateless mode: `sessionIdGenerator: undefined`
- Serverless: `enableJsonResponse: true` (no streaming SSE)
- Ensure `Content-Type: application/json` on all responses including errors

### Avoid SSE — deprecated in favor of Streamable HTTP.

---

## Testing

### Layers

| Layer | What |
|---|---|
| Unit | Handlers, validators, formatters, utilities |
| Integration | Real API calls, auth flows, end-to-end tools |
| Security | Auth validation, input sanitization |
| Performance | Load, timeouts, large responses |

### Integration test architecture

- One shared server for all tests (global setup)
- Generous timeouts (30s+)
- Retry once for flaky network
- Gate on env vars — skip when credentials unavailable
- Track/cleanup created resources after tests

### LLM evaluation

Create 10 QA pairs:
- Independent, read-only, require multiple tool calls
- Single verifiable stable answer (not dynamic state)
- Realistic human use cases, no keyword shortcuts

```xml
<evaluation>
  <qa_pair>
    <question>Question here</question>
    <answer>Verifiable answer</answer>
  </qa_pair>
</evaluation>
```

---

## Security

- Schema validation on all inputs
- Sanitize file paths (directory traversal)
- Validate URLs and identifiers
- Prevent command injection
- Local HTTP: bind to `127.0.0.1`, validate `Origin` header, DNS rebinding protection
- Never log full tokens (first 8 chars only)
- Never log client secrets
- Stack traces only in development mode
- Don't expose internal errors to clients

---

## Logging

### Request/response

```
[timestamp] --> METHOD /path
[timestamp] <-- METHOD /path STATUS (duration_ms)
```

### Severity

| Status | Level |
|---|---|
| 5xx | error [SERVER ERROR] |
| 401 | warn [AUTH FAILED] |
| 4xx | warn [CLIENT ERROR] |
| 2xx | info |

### Component prefix

```
[ServicePreset] Using scopes from environment
[ClientRegistry] Registered client: abc...
[MCP] AUTH SUCCESS: (abc12345...)
[MCP] AUTH FAILURE: { status: 401 }
```

---

## Deployment

### Environment variables

Organize into categories:

```bash
# Server
PORT=3000
BASE_URL=http://localhost:3000

# Auth (required)
OAUTH_CLIENT_ID=...
OAUTH_CLIENT_SECRET=...
OAUTH_REDIRECT_URIS=...
OAUTH_SCOPES="scope1 scope2"

# Infrastructure
AWS_LAMBDA_FUNCTION_NAME=auto-detected
DYNAMODB_TABLE_ARN=arn:aws:dynamodb:...

# Feature flags
ENABLE_RESOURCE_LISTING=true
SKIP_INLINE_IMAGES=true
NODE_ENV=development
```

### Serverless (Lambda)

- Detect via `AWS_LAMBDA_FUNCTION_NAME`
- JSON responses (no SSE streaming)
- DynamoDB for token storage
- Export handler + conditionally start Express
- Support API Gateway v1 and v2

### Dual-mode entry point

```
const isLambda = !!process.env.AWS_LAMBDA_FUNCTION_NAME;
export const handler = createLambdaHandler(app);
if (!isLambda) start();
```

### Monorepo (multi-MCP)

```
root/
├── packages/
│   ├── framework/       # Shared MCP + OAuth
│   ├── test-utils/      # Shared test infra
│   └── mcps/            # Provider implementations
├── infra/               # IaC
└── package.json         # Workspace config
```

Use `workspace:*` for internal dependencies.

---

## Tool Annotations Reference

| Annotation | Type | Default | Set true when |
|---|---|---|---|
| `readOnlyHint` | bool | false | Tool does not modify state |
| `destructiveHint` | bool | true | Tool may delete/overwrite data |
| `idempotentHint` | bool | false | Repeated calls have no additional effect |
| `openWorldHint` | bool | true | Tool interacts with external systems |

Annotations are hints, not security guarantees.

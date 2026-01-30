# TypeScript MCP Server Reference

Conventions, SDK usage, and patterns for building MCP servers in TypeScript.

---

## Naming & Setup

- Server name: `{service}-mcp-server` (lowercase, hyphens)
- Package name in `package.json`: same as server name
- Tool names: `snake_case` with service prefix (`github_create_issue`)

## SDK & Imports

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import express from "express";
import { z } from "zod";
```

Use **modern APIs only**:
- `server.registerTool()`, `server.registerResource()`, `server.registerPrompt()`
- Do NOT use deprecated `server.tool()` or `server.setRequestHandler()`

## Server Initialization

```typescript
const server = new McpServer({
  name: "{service}-mcp-server",
  version: "1.0.0"
});
```

## Project Structure

```
{service}-mcp-server/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts          # Entry point
│   ├── types.ts          # Type definitions
│   ├── constants.ts      # CHARACTER_LIMIT, API_BASE_URL, etc.
│   ├── tools/            # Tool implementations
│   ├── services/         # API clients
│   ├── schemas/          # Zod schemas
│   └── utils/            # Shared helpers
├── tests/
└── dist/
```

## Tool Registration

```typescript
server.registerTool(
  "service_search_users",
  {
    title: "Search Users",
    description: "Search users by name or email. Returns paginated results.\n\nUse when: finding user accounts.\nDo NOT use when: you already have the user ID (use service_get_user instead).",
    inputSchema: {
      query: z.string().min(2).max(200).describe("Search string"),
      limit: z.number().int().min(1).max(100).default(20).describe("Max results"),
      offset: z.number().int().min(0).default(0).describe("Results to skip"),
    },
    outputSchema: {
      total: z.number(),
      users: z.array(z.object({ id: z.string(), name: z.string(), email: z.string() })),
      has_more: z.boolean(),
      next_offset: z.number().optional(),
    },
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: true,
    },
  },
  async ({ query, limit, offset }) => {
    const data = await makeApiRequest<SearchResult>("users/search", "GET", undefined, { q: query, limit, offset });
    const output = {
      total: data.total,
      users: data.users,
      has_more: data.total > offset + data.users.length,
      next_offset: data.total > offset + data.users.length ? offset + data.users.length : undefined,
    };
    return {
      content: [{ type: "text", text: JSON.stringify(output, null, 2) }],
      structuredContent: output,
    };
  }
);
```

## Zod Schemas

```typescript
const CreateInput = z.object({
  name: z.string().min(1).max(100).describe("Resource name"),
  type: z.enum(["typeA", "typeB"]).describe("Resource type"),
  tags: z.array(z.string()).max(10).optional().describe("Optional tags"),
}).strict();

type CreateInput = z.infer<typeof CreateInput>;
```

Key methods: `.min()`, `.max()`, `.int()`, `.email()`, `.enum()`, `.optional()`, `.default()`, `.describe()`, `.strict()`

## Error Handling

```typescript
function handleApiError(error: unknown): string {
  if (error instanceof AxiosError) {
    switch (error.response?.status) {
      case 404: return "Error: Resource not found. Check the ID is correct.";
      case 403: return "Error: Permission denied.";
      case 429: return "Error: Rate limit exceeded. Wait before retrying.";
      default: return `Error: API request failed (${error.response?.status}).`;
    }
  }
  if (error instanceof z.ZodError) {
    return `Error: Invalid input - ${error.errors.map(e => e.message).join(", ")}`;
  }
  return `Error: ${error instanceof Error ? error.message : String(error)}`;
}
```

## Shared API Client

```typescript
async function makeApiRequest<T>(
  endpoint: string,
  method: "GET" | "POST" | "PUT" | "DELETE" = "GET",
  data?: unknown,
  params?: Record<string, unknown>
): Promise<T> {
  const response = await axios({
    method,
    url: `${API_BASE_URL}/${endpoint}`,
    data,
    params,
    timeout: 30000,
    headers: { "Content-Type": "application/json", Accept: "application/json" },
  });
  return response.data;
}
```

## Resource Registration

```typescript
server.registerResource(
  {
    uri: "service://documents/{id}",
    name: "Document",
    description: "Access documents by ID",
    mimeType: "text/plain",
  },
  async (uri: string) => {
    const id = uri.replace("service://documents/", "");
    const content = await fetchDocument(id);
    return { contents: [{ uri, mimeType: "text/plain", text: content }] };
  }
);
```

## Transport Setup

### Streamable HTTP (remote)

```typescript
const app = express();
app.use(express.json());

app.post("/mcp", async (req, res) => {
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined,
    enableJsonResponse: true,
  });
  res.on("close", () => transport.close());
  await server.connect(transport);
  await transport.handleRequest(req, res, req.body);
});

app.listen(parseInt(process.env.PORT || "3000"));
```

### stdio (local)

```typescript
const transport = new StdioServerTransport();
await server.connect(transport);
```

### Dual-mode entry point

```typescript
const isLambda = !!process.env.AWS_LAMBDA_FUNCTION_NAME;
export const handler = createLambdaHandler(app);
if (!isLambda) {
  app.listen(parseInt(process.env.PORT || "3000"));
}
```

## package.json

```json
{
  "name": "{service}-mcp-server",
  "version": "1.0.0",
  "type": "module",
  "main": "dist/index.js",
  "scripts": {
    "start": "node dist/index.js",
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "clean": "rm -rf dist"
  },
  "engines": { "node": ">=18" },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.6.1",
    "axios": "^1.7.9",
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@types/node": "^22.10.0",
    "tsx": "^4.19.2",
    "typescript": "^5.7.2"
  }
}
```

## tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "lib": ["ES2022"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "declaration": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

## TypeScript Rules

- Enable `strict: true` in tsconfig
- Define interfaces for all data structures
- Never use `any` — use `unknown` or proper types
- All async functions have explicit `Promise<T>` return types
- Use type guards: `axios.isAxiosError()`, `instanceof z.ZodError`
- Use `?.` and `??` for null safety
- Build must pass: `npm run build` with zero errors before completion

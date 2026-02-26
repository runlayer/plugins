# Python MCP Server Reference

Conventions, SDK usage, and patterns for building MCP servers in Python.

---

## Naming & Setup

- Server name: `{service}_mcp` (lowercase, underscores)
- Tool names: `snake_case` with service prefix (`github_create_issue`)

## SDK & Imports

```python
from mcp.server.fastmcp import FastMCP, Context
from pydantic import BaseModel, Field, field_validator, ConfigDict
from typing import Optional, List, Dict, Any
from enum import Enum
import httpx
import json
```

SDK docs: `https://raw.githubusercontent.com/modelcontextprotocol/python-sdk/main/README.md`

## Server Initialization

```python
mcp = FastMCP("{service}_mcp")
```

## Project Structure

```
{service}_mcp/
├── pyproject.toml
├── src/
│   ├── __init__.py
│   ├── server.py         # Entry point + FastMCP instance
│   ├── tools/            # Tool implementations
│   ├── services/         # API clients
│   ├── schemas/          # Pydantic models
│   ├── utils/            # Shared helpers
│   └── constants.py      # CHARACTER_LIMIT, API_BASE_URL, etc.
└── tests/
```

## Tool Registration

```python
class UserSearchInput(BaseModel):
    """Input for user search."""
    model_config = ConfigDict(str_strip_whitespace=True, extra='forbid')

    query: str = Field(..., min_length=2, max_length=200, description="Search string")
    limit: int = Field(default=20, ge=1, le=100, description="Max results")
    offset: int = Field(default=0, ge=0, description="Results to skip")

@mcp.tool(
    name="service_search_users",
    annotations={
        "title": "Search Users",
        "readOnlyHint": True,
        "destructiveHint": False,
        "idempotentHint": True,
        "openWorldHint": True,
    }
)
async def service_search_users(params: UserSearchInput) -> str:
    """Search users by name or email. Returns paginated results.

    Use when: finding user accounts.
    Do NOT use when: you already have the user ID (use service_get_user).

    Args:
        params: Validated search parameters.

    Returns:
        JSON string with schema: { total: int, users: [...], has_more: bool, next_offset: int|null }
    """
    try:
        data = await _make_api_request("users/search", params={"q": params.query, "limit": params.limit, "offset": params.offset})
        users = data.get("users", [])
        total = data.get("total", 0)
        response = {
            "total": total,
            "users": users,
            "has_more": total > params.offset + len(users),
            "next_offset": params.offset + len(users) if total > params.offset + len(users) else None,
        }
        return json.dumps(response, indent=2)
    except Exception as e:
        return _handle_api_error(e)
```

## Pydantic Models (v2)

```python
class CreateInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, validate_assignment=True, extra='forbid')

    name: str = Field(..., min_length=1, max_length=100, description="Resource name")
    type: str = Field(..., pattern=r'^(typeA|typeB)$', description="Resource type")
    tags: Optional[List[str]] = Field(default_factory=list, max_length=10, description="Optional tags")

    @field_validator('name')
    @classmethod
    def validate_name(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Name cannot be empty")
        return v.strip()
```

Key v2 rules:
- Use `model_config = ConfigDict(...)` not nested `Config` class
- Use `@field_validator` not deprecated `@validator`
- Use `model_dump()` not deprecated `dict()`
- Validators require `@classmethod` decorator

## Error Handling

```python
def _handle_api_error(e: Exception) -> str:
    if isinstance(e, httpx.HTTPStatusError):
        match e.response.status_code:
            case 404: return "Error: Resource not found. Check the ID is correct."
            case 403: return "Error: Permission denied."
            case 429: return "Error: Rate limit exceeded. Wait before retrying."
            case _: return f"Error: API request failed ({e.response.status_code})."
    if isinstance(e, httpx.TimeoutException):
        return "Error: Request timed out. Try again."
    return f"Error: {type(e).__name__}: {e}"
```

## Shared API Client

```python
async def _make_api_request(endpoint: str, method: str = "GET", **kwargs) -> dict:
    async with httpx.AsyncClient() as client:
        response = await client.request(
            method,
            f"{API_BASE_URL}/{endpoint}",
            timeout=30.0,
            **kwargs
        )
        response.raise_for_status()
        return response.json()
```

## Context Parameter

```python
@mcp.tool()
async def advanced_tool(query: str, ctx: Context) -> str:
    """Tool with context for logging and progress."""
    await ctx.report_progress(0.25, "Starting search...")
    await ctx.log_info("Processing query", {"query": query})
    results = await search_api(query)
    await ctx.report_progress(0.75, "Formatting results...")
    return format_results(results)
```

Context capabilities: `report_progress()`, `log_info()`, `log_error()`, `log_debug()`, `elicit()`, `read_resource()`.

## Resource Registration

```python
@mcp.resource("service://documents/{id}")
async def get_document(id: str) -> str:
    """Access documents by ID."""
    return await fetch_document(id)
```

## Transport Setup

```python
# stdio (default, local)
if __name__ == "__main__":
    mcp.run()

# Streamable HTTP (remote)
if __name__ == "__main__":
    mcp.run(transport="streamable_http", port=8000)
```

## Lifespan Management

```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def app_lifespan():
    db = await connect_to_database()
    yield {"db": db}
    await db.close()

mcp = FastMCP("{service}_mcp", lifespan=app_lifespan)

@mcp.tool()
async def query_data(query: str, ctx: Context) -> str:
    db = ctx.request_context.lifespan_state["db"]
    return await db.query(query)
```

## Python Rules

- Type annotations on all function parameters and return values
- Pydantic models for all input validation (never manual validation)
- `async def` for all tools, `async with` for resources needing cleanup
- `httpx` for HTTP (async), not `requests`
- Specific exception types (`httpx.HTTPStatusError`), not bare `Exception`
- Module-level constants in `UPPER_CASE`
- Group imports: stdlib, third-party, local
- Comprehensive docstrings with Args, Returns, error conditions, and usage examples
- Verify with `python -m py_compile server.py` before completion

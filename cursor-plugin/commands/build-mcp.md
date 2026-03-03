---
name: build-mcp
description: Build, test, and optionally deploy an MCP server
---

# Build MCP Server

Complete MCP server lifecycle: build, test interactively, iterate until working, then optionally deploy to Runlayer.

## What it does

1. Asks which programming language to use (TypeScript, Python, or other)
2. Loads language-specific conventions and SDK patterns
3. Walks through architecture decisions (transport, state, auth)
4. Scaffolds the project structure
5. Implements tools incrementally with proper schemas, error handling, and pagination
6. Runs quality checklist
7. **Launches MCP Inspector for interactive testing**
8. **Iterates on failures until all tools work**
9. **Offers to deploy to Runlayer when ready**

## Usage

Invoke with `/runlayer:build-mcp` or say "build an MCP server for [service]".

---
name: build-mcp
description: Build a production-quality MCP server for any API or service
---

# Build MCP Server

Start the guided MCP server build workflow. This command activates the **mcp-builder** skill.

## What it does

1. Asks which programming language to use (TypeScript, Python, or other)
2. Loads language-specific conventions and SDK patterns
3. Walks through architecture decisions (transport, state, auth)
4. Scaffolds the project structure
5. Implements tools incrementally with proper schemas, error handling, and pagination
6. Runs quality checklist before completion

## Usage

Invoke with `/runlayer:build-mcp` or say "build an MCP server for [service]".

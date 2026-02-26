---
name: build-plugin
description: Scaffold a new Cursor plugin with rules, skills, commands, hooks, and MCP integration
---

# Build Cursor Plugin

Start the guided Cursor plugin scaffolding workflow. This command activates the **plugin-builder** skill.

## What it does

1. Gathers plugin requirements (name, description, components)
2. Discovers available MCP integrations via Runlayer (if configured)
3. Generates the full plugin directory structure
4. Creates properly formatted rules (.mdc), skills (SKILL.md), commands, hooks, and agents
5. Configures MCP servers from Runlayer if tools are needed
6. Provides testing and submission instructions

## Usage

Invoke with `/runlayer:build-plugin` or say "create a plugin for [domain]".

---
name: claude-code-advanced
version: 1.0.0
description: Advanced Claude Code MCP configuration with full AIRIS catalog, Playwright, Magic, and Morphllm
tool: claude-code
install_target: local (~/.claude/mcp.json or .claude/mcp.json + .gitignore)
layer: 4
---

# Claude Code Advanced Local Pack

This pack installs advanced MCP servers for Claude Code. It is **not committed to repos** — it extends your local Claude Code environment.

## What this installs

### AIRIS MCP Gateway
60+ tools via 3 meta-tools (airis-find, airis-schema, airis-exec).

- `airis-find`: Discover tools by name or description
- `airis-schema`: Get the input schema for a tool
- `airis-exec`: Execute any tool in the catalog

Dynamic MCP: 3 tools visible at session start (~600 tokens), full catalog available on demand. 98% token reduction vs. loading all 60+ tools.

Via AIRIS, you get access to:
- **mindbase**: Knowledge graph persistence. Store research findings, architecture decisions, decisions across sessions.
- **serena**: Session state + brownfield project memory. Resume interrupted work. Persistent project context.
- **tavily**: Deep web search with summarization.
- **airis-agent**: Sub-agent dispatch (parallel task execution, wave orchestration).
- Any other catalog server (Stripe, Supabase, etc.) — discovered via airis-find, auto-enabled on first use.

### context7
Up-to-date library documentation on demand.
- `resolve-library-id` → `get-library-docs`
- Fetches actual current docs, not training-data approximations.
- Low token overhead: only loads docs for libraries you ask about.

### Playwright
Browser-based testing and interaction.
- Navigate to URLs, take snapshots, click elements, fill forms, evaluate JS
- Required for frontend profile tasks

### Magic
AI UI component generation from natural language.
- Describe a component → get production-quality code
- Respects project code style if eslint/prettier config exists

### Morphllm
- **FastApply**: 10x faster file edits for large files or multi-point modifications
- **WarpGrep**: Code search without polluting the main context window
- Requires `MORPH_API_KEY` environment variable

## MCP Config (reference)

The bootstrap script generates this. Do not commit it to repos.

```json
{
  "mcpServers": {
    "airis-mcp-gateway": {
      "type": "sse",
      "url": "AIRIS_GATEWAY_URL"
    },
    "context7": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    },
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-playwright@latest"]
    },
    "magic": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@21st-dev/magic-mcp@latest"]
    },
    "morphllm": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@morph-llm/morph-mcp@latest"],
      "env": {
        "MORPH_API_KEY": "${MORPH_API_KEY}"
      },
      "enabledTools": ["edit_file", "warpgrep_codebase_search"]
    }
  }
}
```

## Prerequisites

- AIRIS MCP Gateway running locally: `docker compose up -d` in your airis-mcp-gateway directory
- `MORPH_API_KEY` set in your environment (for Morphllm)
- Node.js 18+ (for npx-based servers)

## Context discipline

Even with all these tools available, follow these rules to keep sessions clean:

1. **Let AIRIS discover tools** — don't load all servers manually. Use `airis-find` first.
2. **context7 on demand** — only fetch docs when your task touches a specific library.
3. **WarpGrep for code search** — don't read large files into context when a targeted search suffices.
4. **Minimal context envelopes for sub-agents** — each dispatched sub-agent should receive only the spec + files it needs, not the full session context.
5. **mindbase for persistence** — store research findings there, not in the main conversation.

## Installation

```bash
bash local-packs/bootstrap.sh \
  --tool claude-code \
  --airis-url http://localhost:9400/sse \
  --morph-key $MORPH_API_KEY
```

Or bootstrap without Morphllm (if you don't have a key):
```bash
bash local-packs/bootstrap.sh --tool claude-code --airis-url http://localhost:9400/sse
```

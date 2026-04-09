#!/usr/bin/env bash
# Detects which AI coding tools are configured in the target repository.
# Outputs a comma-separated list of detected tool IDs.

set -euo pipefail

detected=()

# Claude Code
if [ -d ".claude" ] || [ -f "CLAUDE.md" ] || [ -f "AGENTS.md" ]; then
  detected+=("claude-code")
fi

# Cursor
if [ -d ".cursor" ] || [ -f ".cursorrules" ]; then
  detected+=("cursor")
fi

# GitHub Copilot (VS Code)
if [ -d ".vscode" ] || [ -f ".github/copilot-instructions.md" ]; then
  detected+=("copilot")
fi

# Codex
if [ -d ".codex" ]; then
  detected+=("codex")
fi

# OpenCode
if [ -d ".opencode" ] || [ -f ".opencode/mcp.json" ]; then
  detected+=("opencode")
fi

# If nothing detected, default to all tools
if [ ${#detected[@]} -eq 0 ]; then
  echo "tools=claude-code,cursor,copilot,codex,opencode"
else
  IFS=','
  echo "tools=${detected[*]}"
fi

#!/bin/bash
# SDD Preflight — deterministic validation
# Exit 0 = ready, Exit 1 = needs bootstrap
set -euo pipefail

AGENTS_MD="AGENTS.md"

# --- Bootstrap check ---
if [ -f "$AGENTS_MD" ] && grep -q "rojas:section:project-stack" "$AGENTS_MD"; then
  echo "BOOTSTRAP=complete"
else
  echo "BOOTSTRAP=missing"
  exit 1
fi

# --- OpenSpec check ---
if [ -d "openspec/changes" ] && [ "$(ls -A openspec/changes 2>/dev/null)" ]; then
  echo "SPECS=available"
else
  echo "SPECS=empty"
fi

# --- MCP config check ---
MCP_FILE=""
if [ -f ".mcp.json" ]; then
  MCP_FILE=".mcp.json"
elif [ -f ".claude/mcp.json" ]; then
  MCP_FILE=".claude/mcp.json"
fi

if [ -n "$MCP_FILE" ]; then
  echo "MCP_CONFIG=found"
  # Check for specific MCPs in config
  for mcp in airis-mcp-gateway figma context7 serena; do
    if grep -q "\"$mcp\"" "$MCP_FILE" 2>/dev/null; then
      echo "MCP_${mcp}=configured"
    else
      echo "MCP_${mcp}=absent"
    fi
  done
else
  echo "MCP_CONFIG=missing"
fi

# --- Playwright CLI check (preferred over MCP) ---
if [ -f "package.json" ] && grep -q "playwright" package.json 2>/dev/null; then
  echo "PLAYWRIGHT_CLI=available"
else
  echo "PLAYWRIGHT_CLI=absent"
fi

# --- NPX availability ---
if command -v npx &> /dev/null; then
  echo "NPX=available"
else
  echo "NPX=missing"
fi

# --- Spec location check ---
# Warn if spec files exist in openspec/specs/ that also exist in a change folder
if [ -d "openspec/specs" ]; then
  for spec in openspec/specs/*.md; do
    [ -f "$spec" ] || continue
    BASENAME=$(basename "$spec")
    for change_dir in openspec/changes/*/specs/; do
      [ -d "$change_dir" ] || continue
      if [ -f "${change_dir}${BASENAME}" ]; then
        echo "SPEC_WARNING=duplicate_${BASENAME}"
      fi
    done
  done
fi

# --- Multi-repo detection ---
if [ -f "openspec/config.yaml" ] && grep -q "repos:" openspec/config.yaml 2>/dev/null; then
  echo "MULTI_REPO=true"
else
  echo "MULTI_REPO=false"
fi

exit 0

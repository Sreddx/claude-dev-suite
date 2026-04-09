#!/usr/bin/env bash
# local-packs/bootstrap.sh
# Bootstrap advanced MCP configurations locally (never touches repos)
# Usage: bash local-packs/bootstrap.sh --tool claude-code --airis-url http://localhost:9400/sse

set -euo pipefail

TOOL=""
AIRIS_URL="http://localhost:9400/sse"
MORPH_KEY=""
SCOPE="global"  # global (~/.claude/mcp.json) or project (.claude/mcp.json)
DRY_RUN="false"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool)       TOOL="$2";      shift 2 ;;
    --airis-url)  AIRIS_URL="$2"; shift 2 ;;
    --morph-key)  MORPH_KEY="$2"; shift 2 ;;
    --scope)      SCOPE="$2";     shift 2 ;;
    --dry-run)    DRY_RUN="true"; shift ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if [ -z "$TOOL" ]; then
  echo "Error: --tool is required (claude-code, cursor, copilot, opencode)"
  exit 1
fi

# Determine target config path
case "$TOOL" in
  claude-code)
    if [ "$SCOPE" = "global" ]; then
      TARGET_DIR="$HOME/.claude"
    else
      TARGET_DIR=".claude"
    fi
    TARGET_FILE="$TARGET_DIR/mcp.json"
    ;;
  cursor)
    if [ "$SCOPE" = "global" ]; then
      TARGET_DIR="$HOME/.cursor"
    else
      TARGET_DIR=".cursor"
    fi
    TARGET_FILE="$TARGET_DIR/mcp.json"
    ;;
  copilot)
    if [ "$SCOPE" = "global" ]; then
      TARGET_DIR="$HOME/.vscode"
    else
      TARGET_DIR=".vscode"
    fi
    TARGET_FILE="$TARGET_DIR/mcp.json"
    ;;
  opencode)
    TARGET_DIR=".opencode"
    TARGET_FILE="$TARGET_DIR/mcp.json"
    ;;
  *)
    echo "Error: unsupported tool '$TOOL'"
    exit 1
    ;;
esac

# Build MCP config
PACK_TEMPLATE="$SCRIPT_DIR/../templates/mcp/$TOOL.json"
if [ ! -f "$PACK_TEMPLATE" ]; then
  echo "Error: no template found for $TOOL at $PACK_TEMPLATE"
  exit 1
fi

# Create temp config with substitutions
TEMP_CONFIG=$(mktemp /tmp/local-pack-XXXXXX.json)
sed "s|AIRIS_GATEWAY_URL|${AIRIS_URL}|g" "$PACK_TEMPLATE" > "$TEMP_CONFIG"

# Substitute MORPH_API_KEY if provided
if [ -n "$MORPH_KEY" ]; then
  sed -i "s|\"\${MORPH_API_KEY}\"|\"${MORPH_KEY}\"|g" "$TEMP_CONFIG"
fi

if [ "$DRY_RUN" = "true" ]; then
  echo "[DRY RUN] Would install MCP config for $TOOL to: $TARGET_FILE"
  echo ""
  echo "--- Generated config ---"
  cat "$TEMP_CONFIG"
  echo ""
  echo "--- End config ---"
  rm -f "$TEMP_CONFIG"
  exit 0
fi

mkdir -p "$TARGET_DIR"

# Deep merge if target exists, otherwise copy
if [ -f "$TARGET_FILE" ]; then
  echo "Merging with existing config at $TARGET_FILE"
  bash "$SCRIPT_DIR/../installer/install.sh" \
    --tool "$TOOL" \
    --airis-url "$AIRIS_URL" \
    --target "$TARGET_DIR" 2>/dev/null || {
    # Fallback: use Node merge directly
    node -e "
      const fs = require('fs');
      const target = JSON.parse(fs.readFileSync('$TARGET_FILE', 'utf8'));
      const source = JSON.parse(fs.readFileSync('$TEMP_CONFIG', 'utf8'));
      function deepMerge(t, s) {
        const r = Object.assign({}, t);
        for (const [k, v] of Object.entries(s)) {
          if (k in r && typeof r[k] === 'object' && !Array.isArray(r[k])) {
            r[k] = deepMerge(r[k], v);
          } else if (!(k in r)) {
            r[k] = v;
          }
        }
        return r;
      }
      const merged = deepMerge(target, source);
      fs.writeFileSync('$TARGET_FILE', JSON.stringify(merged, null, 2) + '\n');
      console.log('Merged successfully');
    "
  }
else
  echo "Installing new config to $TARGET_FILE"
  cp "$TEMP_CONFIG" "$TARGET_FILE"
fi

rm -f "$TEMP_CONFIG"

echo ""
echo "Done. MCP config installed to: $TARGET_FILE"
echo ""
echo "IMPORTANT: This config is LOCAL ONLY."

# Warn if we installed to a project path (might be accidentally committed)
if [ "$SCOPE" = "project" ]; then
  echo ""
  echo "WARNING: You installed to a project-scoped path ($TARGET_FILE)."
  echo "Add this to your .gitignore to prevent accidental commit:"
  echo ""
  echo "  $TARGET_FILE"
  echo ""
fi

echo "Restart your AI tool to pick up the new MCP servers."

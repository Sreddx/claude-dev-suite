#!/usr/bin/env bash
# Installs MCP configurations for a specific tool.
# Merge-safe: deep merges with existing configs, never overwrites user keys.

set -euo pipefail

TOOL=""
AIRIS_URL="http://localhost:9400/sse"
CONTEXT7="true"
AIRIS_CATALOG="all"
DRY_RUN="false"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES_DIR="$(dirname "$SCRIPT_DIR")/templates"

while [[ $# -gt 0 ]]; do
  case $1 in
    --tool) TOOL="$2"; shift 2 ;;
    --airis-url) AIRIS_URL="$2"; shift 2 ;;
    --context7) CONTEXT7="$2"; shift 2 ;;
    --airis-catalog) AIRIS_CATALOG="$2"; shift 2 ;;
    --dry-run) DRY_RUN="$2"; shift 2 ;;
    --target) TARGET_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

TARGET_DIR="${TARGET_DIR:-.}"

# Map tool to config path and template
declare -A CONFIG_PATHS=(
  ["claude-code"]=".claude/mcp.json"
  ["cursor"]=".cursor/mcp.json"
  ["copilot"]=".vscode/mcp.json"
  ["opencode"]=".opencode/mcp.json"
)

declare -A TEMPLATE_FILES=(
  ["claude-code"]="claude-code.json"
  ["cursor"]="cursor.json"
  ["copilot"]="vscode.json"
  ["opencode"]="opencode.json"
)

merge_json() {
  local template="$1"
  local target="$2"

  if [ ! -f "$target" ]; then
    echo "  Creating $target"
    mkdir -p "$(dirname "$target")"
    cp "$template" "$target"
    return
  fi

  echo "  Deep merging into $target"
  # Use node for reliable JSON deep merge
  node -e "
    const fs = require('fs');
    const existing = JSON.parse(fs.readFileSync('$target', 'utf8'));
    const template = JSON.parse(fs.readFileSync('$template', 'utf8'));

    function deepMerge(target, source) {
      for (const key of Object.keys(source)) {
        if (key in target) {
          if (typeof target[key] === 'object' && typeof source[key] === 'object'
              && !Array.isArray(target[key])) {
            deepMerge(target[key], source[key]);
          }
          // Existing key — don't overwrite
        } else {
          target[key] = source[key];
        }
      }
      return target;
    }

    const merged = deepMerge(existing, template);
    fs.writeFileSync('$target', JSON.stringify(merged, null, 2) + '\n');
  "
}

merge_toml_codex() {
  local template="$1"
  local target="$2"

  if [ ! -f "$target" ]; then
    echo "  Creating $target"
    mkdir -p "$(dirname "$target")"
    cp "$template" "$target"
    return
  fi

  echo "  Appending new MCP servers to $target (preserving existing)"
  # Read template, append only sections not already present
  while IFS= read -r line; do
    if [[ "$line" =~ ^\[mcp_servers\. ]]; then
      section_name="$line"
      if ! grep -qF "$section_name" "$target" 2>/dev/null; then
        echo "" >> "$target"
        echo "$line" >> "$target"
        # Read until next section or EOF
        while IFS= read -r subline; do
          if [[ "$subline" =~ ^\[ ]] && [[ ! "$subline" =~ ^\[mcp_servers\. ]]; then
            break
          fi
          echo "$subline" >> "$target"
        done
      fi
    fi
  done < "$template"
}

# --- Main ---

if [ -z "$TOOL" ]; then
  echo "Error: --tool is required"
  exit 1
fi

echo "Processing tool: $TOOL"

# Replace placeholder URLs in templates
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

if [ "$TOOL" == "codex" ]; then
  TEMPLATE="$TEMPLATES_DIR/mcp/codex.toml"
  TARGET="$TARGET_DIR/.codex/config.toml"

  cp "$TEMPLATE" "$TEMP_DIR/config.toml"
  sed -i "s|AIRIS_GATEWAY_URL|$AIRIS_URL|g" "$TEMP_DIR/config.toml"

  if [ "$DRY_RUN" == "true" ]; then
    echo "[DRY RUN] Would merge $TEMPLATE -> $TARGET"
  else
    merge_toml_codex "$TEMP_DIR/config.toml" "$TARGET"
  fi
else
  TEMPLATE_FILE="${TEMPLATE_FILES[$TOOL]:-}"
  CONFIG_PATH="${CONFIG_PATHS[$TOOL]:-}"

  if [ -z "$TEMPLATE_FILE" ] || [ -z "$CONFIG_PATH" ]; then
    echo "Warning: Unknown tool '$TOOL' — skipping MCP config"
    exit 0
  fi

  TEMPLATE="$TEMPLATES_DIR/mcp/$TEMPLATE_FILE"
  TARGET="$TARGET_DIR/$CONFIG_PATH"

  cp "$TEMPLATE" "$TEMP_DIR/mcp.json"
  sed -i "s|AIRIS_GATEWAY_URL|$AIRIS_URL|g" "$TEMP_DIR/mcp.json"

  if [ "$CONTEXT7" != "true" ]; then
    # Remove context7 server from template before merging
    node -e "
      const fs = require('fs');
      const cfg = JSON.parse(fs.readFileSync('$TEMP_DIR/mcp.json', 'utf8'));
      const root = cfg.mcpServers || cfg.servers || cfg;
      delete root['context7'];
      fs.writeFileSync('$TEMP_DIR/mcp.json', JSON.stringify(cfg, null, 2) + '\n');
    "
  fi

  if [ "$DRY_RUN" == "true" ]; then
    echo "[DRY RUN] Would merge $TEMPLATE -> $TARGET"
    cat "$TEMP_DIR/mcp.json"
  else
    merge_json "$TEMP_DIR/mcp.json" "$TARGET"
  fi
fi

echo "Done: $TOOL"

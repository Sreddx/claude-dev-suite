#!/bin/bash
# Install SDD Dev Suite agents filtered by repo role
set -euo pipefail

ROLE="${1:-standalone}"
SOURCE_DIR="${2:-.claude/agents}"
TARGET_DIR="${3:-.claude/agents}"
DRY_RUN="${4:-false}"
VERSION="${5:-1.0.0}"

# All 14 agents — shared by coordination, monorepo, and standalone
ALL_AGENTS="orchestrator planner researcher team-leader validator agent-prep agent-sync devstart frontend tester-front backend database tester-back github-ops"

# Define agent sets per role
case "$ROLE" in
  coordination)
    # Full suite — coordinator hub delegates to sub-repos and needs awareness of all agent capabilities
    AGENTS="$ALL_AGENTS"
    ;;
  monorepo)
    # Full suite — monorepo orchestrates all domains internally
    AGENTS="$ALL_AGENTS"
    ;;
  frontend)
    # Receives delegation from coordinator + planning + fe implementation + quality gate
    AGENTS="orchestrator planner researcher frontend tester-front github-ops validator"
    ;;
  backend)
    # Receives delegation from coordinator + planning + be implementation + quality gate
    AGENTS="orchestrator planner researcher backend database tester-back github-ops validator"
    ;;
  standalone|*)
    AGENTS="$ALL_AGENTS"
    ;;
esac

mkdir -p "$TARGET_DIR"

for agent in $AGENTS; do
  SRC="$SOURCE_DIR/${agent}.md"
  TGT="$TARGET_DIR/${agent}.md"

  if [ ! -f "$SRC" ]; then
    echo "WARNING: Source agent $SRC not found, skipping"
    continue
  fi

  if [ -f "$TGT" ]; then
    # Check for SDD version marker — only update managed agents
    if grep -q "sdd-dev-suite:agent:${agent}" "$TGT"; then
      if [ "$DRY_RUN" == "true" ]; then
        echo "[DRY RUN] Would update managed agent: $agent"
      else
        cp "$SRC" "$TGT"
        echo "Updated managed agent: $agent"
      fi
    else
      echo "Skipping user-customized agent: $agent (no SDD version marker)"
    fi
  else
    if [ "$DRY_RUN" == "true" ]; then
      echo "[DRY RUN] Would install new agent: $agent"
    else
      cp "$SRC" "$TGT"
      echo "Installed new agent: $agent"
    fi
  fi
done

# Role-specific CLAUDE.md content
CLAUDE_NOTE=""
case "$ROLE" in
  coordination)
    CLAUDE_NOTE="This is the SDD coordination hub. All 14 agents installed. Run /sdd here to start any workflow and delegate to sub-repos."
    ;;
  monorepo)
    CLAUDE_NOTE="This is a monorepo with all domains. All 14 agents installed. Run /sdd here to orchestrate across packages."
    ;;
  frontend)
    CLAUDE_NOTE="Frontend implementation repo. Orchestrated from the coordination repo. Includes orchestrator for receiving delegation. For local fixes only: /sdd mode 4."
    ;;
  backend)
    CLAUDE_NOTE="Backend implementation repo. Orchestrated from the coordination repo. Includes orchestrator for receiving delegation. For local fixes only: /sdd mode 4."
    ;;
esac

if [ -n "${CLAUDE_NOTE:-}" ] && [ "$DRY_RUN" != "true" ]; then
  echo ""
  echo "Repo role: $ROLE"
  echo "CLAUDE.md note: $CLAUDE_NOTE"
fi

# Sync schemas directory
SCHEMAS_SRC="$(dirname "$SOURCE_DIR")/../schemas"
SCHEMAS_TARGET="$(dirname "$TARGET_DIR")/../schemas"
if [ -d "$SCHEMAS_SRC" ]; then
  mkdir -p "$SCHEMAS_TARGET"
  for schema in "$SCHEMAS_SRC"/*.md; do
    [ -f "$schema" ] || continue
    BASENAME=$(basename "$schema")
    if [ "$DRY_RUN" == "true" ]; then
      echo "[DRY RUN] Would install schema: $BASENAME"
    else
      cp "$schema" "$SCHEMAS_TARGET/$BASENAME"
      echo "Installed schema: $BASENAME"
    fi
  done
fi

echo "Agent installation complete for role: $ROLE ($AGENTS)"

#!/bin/bash
# claude-dev-suite — Shell installer
# Usage: curl -fsSL https://raw.githubusercontent.com/Sreddx/claude-dev-suite/main/install.sh | bash
#        curl -fsSL https://raw.githubusercontent.com/Sreddx/claude-dev-suite/main/install.sh | bash -s -- --profile frontend
#        curl -fsSL https://raw.githubusercontent.com/Sreddx/claude-dev-suite/main/install.sh | bash -s -- --dry-run
set -euo pipefail

# --- Defaults ---
REPO_URL="https://github.com/Sreddx/claude-dev-suite"
BRANCH="main"
TARGET_DIR="."
PROFILE=""
REPO_TYPE=""
DRY_RUN="false"
AGENT_SUITE="true"
AGENT_SUITE_VERSION="1.0.0"
KEEP_CLONE="false"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()  { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }
ok()    { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
err()   { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }
dry()   { printf "${YELLOW}[DRY RUN]${NC} %s\n" "$1"; }

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)      PROFILE="$2"; shift 2 ;;
    --repo-type)    REPO_TYPE="$2"; shift 2 ;;
    --target)       TARGET_DIR="$2"; shift 2 ;;
    --branch)       BRANCH="$2"; shift 2 ;;
    --dry-run)      DRY_RUN="true"; shift ;;
    --no-agents)    AGENT_SUITE="false"; shift ;;
    --version)      AGENT_SUITE_VERSION="$2"; shift 2 ;;
    --keep-clone)   KEEP_CLONE="true"; shift ;;
    --help|-h)
      cat <<EOF
claude-dev-suite installer

Usage:
  curl -fsSL https://raw.githubusercontent.com/Sreddx/claude-dev-suite/main/install.sh | bash
  bash install.sh [OPTIONS]

Options:
  --profile <name>     Apply a profile: frontend, backend-api, brownfield, high-risk
  --repo-type <type>   Auto-select profiles: frontend, backend, monorepo,
                        brownfield-frontend, brownfield-backend, coordination, standalone
  --target <dir>       Target directory (default: current directory)
  --branch <branch>    Branch to install from (default: main)
  --dry-run            Preview changes without applying
  --no-agents          Skip agent suite installation
  --version <ver>      Agent suite version (default: 1.0.0)
  --keep-clone         Keep the cloned repo (default: remove after install)
  --help               Show this help

Examples:
  # Install baseline into current directory
  bash install.sh

  # Install with frontend profile
  bash install.sh --profile frontend

  # Install into a specific project
  bash install.sh --target ./my-project --repo-type monorepo

  # Preview what would be installed
  bash install.sh --dry-run
EOF
      exit 0
      ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

# --- Resolve target ---
TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

# --- Header ---
printf "\n${BOLD}╔═══════════════════════════════════════════════╗${NC}\n"
printf "${BOLD}║       claude-dev-suite installer               ║${NC}\n"
printf "${BOLD}║       Spec-Driven Development baseline         ║${NC}\n"
printf "${BOLD}╚═══════════════════════════════════════════════╝${NC}\n\n"

info "Target directory: $TARGET_DIR"
if [ -n "$PROFILE" ]; then info "Profile: $PROFILE"; fi
if [ -n "$REPO_TYPE" ]; then info "Repo type: $REPO_TYPE"; fi
if [ "$DRY_RUN" == "true" ]; then warn "DRY RUN mode — no files will be modified"; fi

# --- Prerequisites ---
info "Checking prerequisites..."

if ! command -v git &>/dev/null; then
  err "git is required but not installed"
  exit 1
fi

if ! command -v node &>/dev/null; then
  err "Node.js is required but not installed (needed for AGENTS.md merge)"
  exit 1
fi

ok "Prerequisites met (git, node)"

# --- Clone the repo to a temp directory ---
CLONE_DIR=$(mktemp -d /tmp/claude-dev-suite-XXXXXX)
trap 'if [ "$KEEP_CLONE" != "true" ]; then rm -rf "$CLONE_DIR"; fi' EXIT

info "Fetching claude-dev-suite ($BRANCH)..."
git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$CLONE_DIR" 2>/dev/null
ok "Fetched claude-dev-suite"

SRC="$CLONE_DIR"

# --- Resolve effective profiles ---
EFFECTIVE_PROFILES=""
if [ -n "$REPO_TYPE" ] && [ -z "$PROFILE" ]; then
  case "$REPO_TYPE" in
    frontend)             EFFECTIVE_PROFILES="frontend" ;;
    backend)              EFFECTIVE_PROFILES="backend-api" ;;
    monorepo)             EFFECTIVE_PROFILES="frontend backend-api" ;;
    brownfield-frontend)  EFFECTIVE_PROFILES="frontend brownfield" ;;
    brownfield-backend)   EFFECTIVE_PROFILES="backend-api brownfield" ;;
    coordination)         EFFECTIVE_PROFILES="" ;;
    standalone)           EFFECTIVE_PROFILES="" ;;
    *)
      warn "Unknown repo_type '$REPO_TYPE' — using baseline only"
      EFFECTIVE_PROFILES=""
      ;;
  esac
elif [ -n "$PROFILE" ]; then
  EFFECTIVE_PROFILES="$PROFILE"
fi

# --- Resolve effective repo role ---
EFFECTIVE_ROLE="standalone"
if [ -n "$REPO_TYPE" ]; then
  case "$REPO_TYPE" in
    coordination)                          EFFECTIVE_ROLE="coordination" ;;
    monorepo)                              EFFECTIVE_ROLE="monorepo" ;;
    frontend|brownfield-frontend)          EFFECTIVE_ROLE="frontend" ;;
    backend|brownfield-backend)            EFFECTIVE_ROLE="backend" ;;
    *)                                     EFFECTIVE_ROLE="standalone" ;;
  esac
fi

# ============================================================
# Step 1: Merge AGENTS.md
# ============================================================
info "Step 1/9: Merging AGENTS.md..."
if [ "$DRY_RUN" == "true" ]; then
  node "$SRC/installer/merge-agents.js" \
    --template "$SRC/templates/AGENTS.md" \
    --target "$TARGET_DIR/AGENTS.md" \
    --dry-run "true"
else
  node "$SRC/installer/merge-agents.js" \
    --template "$SRC/templates/AGENTS.md" \
    --target "$TARGET_DIR/AGENTS.md" \
    --dry-run "false"
  ok "AGENTS.md merged"
fi

# ============================================================
# Step 2: Init or merge OpenSpec
# ============================================================
info "Step 2/9: Setting up OpenSpec..."
if [ ! -d "$TARGET_DIR/openspec" ]; then
  if [ "$DRY_RUN" == "true" ]; then
    dry "Would create: openspec/specs, openspec/changes, openspec/config.yaml"
  else
    mkdir -p "$TARGET_DIR/openspec/specs" "$TARGET_DIR/openspec/changes"
    cp "$SRC/templates/openspec/config.yaml" "$TARGET_DIR/openspec/config.yaml"
    printf '# OpenSpec\nSpecs live in `openspec/specs/`. Changes live in `openspec/changes/`.\n' > "$TARGET_DIR/openspec/README.md"
    ok "OpenSpec initialized"
  fi
else
  if [ "$DRY_RUN" == "true" ]; then
    dry "OpenSpec exists — would merge config (copy-if-missing)"
  else
    mkdir -p "$TARGET_DIR/openspec/specs" "$TARGET_DIR/openspec/changes"
    cp -n "$SRC/templates/openspec/config.yaml" "$TARGET_DIR/openspec/config.yaml" 2>/dev/null || true
    ok "OpenSpec config merged (copy-if-missing)"
  fi
fi

# ============================================================
# Step 3: Sync schemas and templates
# ============================================================
info "Step 3/9: Syncing schemas and templates..."
if [ "$DRY_RUN" == "true" ]; then
  for schema in "$SRC/schemas/"*.md; do
    [ -f "$schema" ] || continue
    BASENAME=$(basename "$schema")
    if [ ! -f "$TARGET_DIR/schemas/$BASENAME" ]; then
      dry "Would install schema: $BASENAME"
    else
      info "Schema exists, would skip: $BASENAME"
    fi
  done
  for tmpl in "$SRC/templates/openspec/"*.md; do
    [ -f "$tmpl" ] || continue
    BASENAME=$(basename "$tmpl")
    if [ ! -f "$TARGET_DIR/templates/openspec/$BASENAME" ]; then
      dry "Would install template: $BASENAME"
    else
      info "Template exists, would skip: $BASENAME"
    fi
  done
else
  mkdir -p "$TARGET_DIR/schemas" "$TARGET_DIR/templates/openspec"
  for schema in "$SRC/schemas/"*.md; do
    [ -f "$schema" ] || continue
    BASENAME=$(basename "$schema")
    if [ ! -f "$TARGET_DIR/schemas/$BASENAME" ]; then
      cp "$schema" "$TARGET_DIR/schemas/$BASENAME"
      ok "Installed schema: $BASENAME"
    fi
  done
  for tmpl in "$SRC/templates/openspec/"*.md; do
    [ -f "$tmpl" ] || continue
    BASENAME=$(basename "$tmpl")
    if [ ! -f "$TARGET_DIR/templates/openspec/$BASENAME" ]; then
      cp "$tmpl" "$TARGET_DIR/templates/openspec/$BASENAME"
      ok "Installed template: $BASENAME"
    fi
  done
fi

# ============================================================
# Step 4: Init .claude directory
# ============================================================
info "Step 4/9: Setting up .claude directory..."
if [ "$DRY_RUN" == "true" ]; then
  if [ ! -d "$TARGET_DIR/.claude" ]; then
    dry "Would create .claude/ directory structure"
  else
    info ".claude/ already exists"
  fi
else
  mkdir -p "$TARGET_DIR/.claude/skills" "$TARGET_DIR/.claude/commands" "$TARGET_DIR/.claude/agents"
  ok ".claude directory ready"
fi

# ============================================================
# Step 5: Install SDD commands and scripts
# ============================================================
info "Step 5/9: Installing SDD commands and scripts..."
if [ "$DRY_RUN" == "true" ]; then
  dry "Would install .claude/commands/sdd.md"
  dry "Would install scripts/sdd-preflight.sh"
  dry "Would install scripts/sdd-session-report.sh"
else
  mkdir -p "$TARGET_DIR/.claude/commands" "$TARGET_DIR/scripts"

  # /sdd command
  SRC_CMD="$SRC/.claude/commands/sdd.md"
  TGT_CMD="$TARGET_DIR/.claude/commands/sdd.md"
  if [ -f "$SRC_CMD" ]; then
    cp "$SRC_CMD" "$TGT_CMD"
    ok "Installed .claude/commands/sdd.md"
  fi

  # Scripts
  if [ -f "$SRC/scripts/sdd-preflight.sh" ]; then
    cp "$SRC/scripts/sdd-preflight.sh" "$TARGET_DIR/scripts/sdd-preflight.sh"
    chmod +x "$TARGET_DIR/scripts/sdd-preflight.sh"
    ok "Installed scripts/sdd-preflight.sh"
  fi
  if [ -f "$SRC/scripts/sdd-session-report.sh" ]; then
    cp "$SRC/scripts/sdd-session-report.sh" "$TARGET_DIR/scripts/sdd-session-report.sh"
    chmod +x "$TARGET_DIR/scripts/sdd-session-report.sh"
    ok "Installed scripts/sdd-session-report.sh"
  fi
fi

# ============================================================
# Step 6: Install skills
# ============================================================
info "Step 6/9: Installing skills..."
SKILLS_TARGET="$TARGET_DIR/.claude/skills"
if [ "$DRY_RUN" == "true" ]; then
  for skill_dir in "$SRC/skills/rojas-"*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    dry "Would install skill: $skill_name"
  done
  if [ -d "$SRC/skills/community" ]; then
    for skill_dir in "$SRC/skills/community"/*/; do
      [ -d "$skill_dir" ] || continue
      skill_name=$(basename "$skill_dir")
      dry "Would install community skill: $skill_name"
    done
  fi
else
  mkdir -p "$SKILLS_TARGET"
  # Rojas skills
  for skill_dir in "$SRC/skills/rojas-"*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    src="$skill_dir/SKILL.md"
    target_dir="$SKILLS_TARGET/$skill_name"
    if [ -f "$src" ]; then
      mkdir -p "$target_dir"
      cp "$src" "$target_dir/SKILL.md"
      ok "Installed skill: $skill_name"
    fi
  done
  # Community skills
  if [ -d "$SRC/skills/community" ]; then
    for skill_dir in "$SRC/skills/community"/*/; do
      [ -d "$skill_dir" ] || continue
      skill_name=$(basename "$skill_dir")
      src="$skill_dir/SKILL.md"
      if [ -f "$src" ]; then
        mkdir -p "$SKILLS_TARGET/$skill_name"
        cp "$src" "$SKILLS_TARGET/$skill_name/SKILL.md"
        ok "Installed community skill: $skill_name"
      fi
    done
  fi
fi

# ============================================================
# Step 7: Install agents
# ============================================================
if [ "$AGENT_SUITE" == "true" ]; then
  info "Step 7/9: Installing SDD Dev Suite agents..."
  AGENTS_SOURCE="$SRC/agents/claude"
  AGENTS_TARGET="$TARGET_DIR/.claude/agents"

  if [ -d "$AGENTS_SOURCE" ]; then
    node "$SRC/installer/merge-claude-agents.js" \
      --source "$AGENTS_SOURCE" \
      --target "$AGENTS_TARGET" \
      --version "$AGENT_SUITE_VERSION" \
      --role "$EFFECTIVE_ROLE" \
      --dry-run "$DRY_RUN"
    if [ "$DRY_RUN" != "true" ]; then
      ok "Agents installed (role: $EFFECTIVE_ROLE)"
    fi
  else
    warn "Agent source directory not found — skipping"
  fi
else
  info "Step 7/9: Skipping agent installation (--no-agents)"
fi

# ============================================================
# Step 8: Apply profile
# ============================================================
if [ -n "$EFFECTIVE_PROFILES" ]; then
  info "Step 8/9: Applying profiles: $EFFECTIVE_PROFILES"
  for PROF in $EFFECTIVE_PROFILES; do
    PROFILE_FILE="$SRC/profiles/${PROF}.md"
    if [ ! -f "$PROFILE_FILE" ]; then
      warn "Unknown profile '$PROF' — skipping"
      continue
    fi

    SECTION_BLOCK=$(node -e "
      const fs = require('fs');
      const content = fs.readFileSync('${PROFILE_FILE}', 'utf8');
      const match = content.match(/\`\`\`markdown\n([\s\S]*?)\n\`\`\`/);
      if (match) process.stdout.write(match[1]);
    ")

    if [ -n "$SECTION_BLOCK" ]; then
      TEMP_TEMPLATE=$(mktemp /tmp/profile-agents-XXXXXX.md)
      printf '%s\n' "$SECTION_BLOCK" > "$TEMP_TEMPLATE"
      node "$SRC/installer/merge-agents.js" \
        --template "$TEMP_TEMPLATE" \
        --target "$TARGET_DIR/AGENTS.md" \
        --dry-run "$DRY_RUN"
      rm -f "$TEMP_TEMPLATE"
      if [ "$DRY_RUN" != "true" ]; then
        ok "Applied profile: $PROF"
      fi
    else
      warn "No AGENTS.md section found in profile $PROF — skipping"
    fi
  done
else
  info "Step 8/9: No profiles to apply (baseline only)"
fi

# ============================================================
# Step 9: Create compatibility entrypoints
# ============================================================
info "Step 9/9: Creating compatibility entrypoints..."
if [ "$DRY_RUN" == "true" ]; then
  if [ ! -f "$TARGET_DIR/CLAUDE.md" ]; then
    dry "Would create CLAUDE.md"
  fi
  if [ ! -f "$TARGET_DIR/.github/copilot-instructions.md" ]; then
    dry "Would create .github/copilot-instructions.md"
  fi
else
  if [ ! -f "$TARGET_DIR/CLAUDE.md" ] && [ -f "$TARGET_DIR/AGENTS.md" ]; then
    printf '%s\n' \
      '<!-- This file is managed by claude-dev-suite. Do not edit manually. -->' \
      '<!-- See AGENTS.md for the full agent and AI tooling guidance. -->' \
      '' \
      '> **Claude Code users:** The primary guidance for this repo lives in [`AGENTS.md`](./AGENTS.md).' \
      '> All SDD workflow rules, skill references, MCP integration notes, and conventions are defined there.' \
      > "$TARGET_DIR/CLAUDE.md"
    ok "Created CLAUDE.md"
  fi
  if [ ! -f "$TARGET_DIR/.github/copilot-instructions.md" ] && [ -f "$TARGET_DIR/AGENTS.md" ]; then
    mkdir -p "$TARGET_DIR/.github"
    printf '%s\n' \
      '<!-- This file is managed by claude-dev-suite. Do not edit manually. -->' \
      '<!-- See AGENTS.md for the full agent and AI tooling guidance. -->' \
      '' \
      '> **GitHub Copilot users:** The primary guidance for this repo lives in [`AGENTS.md`](../AGENTS.md).' \
      '> All SDD workflow rules, skill references, MCP integration notes, and conventions are defined there.' \
      > "$TARGET_DIR/.github/copilot-instructions.md"
    ok "Created .github/copilot-instructions.md"
  fi
fi

# --- OpenSpec CLI commands (multi-tool adapters) ---
info "Installing OpenSpec CLI commands..."
if [ "$DRY_RUN" == "true" ]; then
  dry "Would install .claude/commands/opsx/ (4 commands)"
  dry "Would install .claude/skills/openspec-*/ (4 skills)"
  dry "Would install .opencode/ skills and commands (if applicable)"
  dry "Would install .github/skills/openspec-*/ (4 skills)"
  dry "Would install .github/prompts/opsx-*.prompt.md (4 prompts)"
else
  # Claude Code commands
  if [ -d "$SRC/.claude/commands/opsx" ]; then
    mkdir -p "$TARGET_DIR/.claude/commands/opsx"
    cp -r "$SRC/.claude/commands/opsx/"* "$TARGET_DIR/.claude/commands/opsx/"
    ok "Installed .claude/commands/opsx/"
  fi

  # Claude Code skills
  for skill_dir in "$SRC/.claude/skills/openspec-"*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    mkdir -p "$TARGET_DIR/.claude/skills/$skill_name"
    cp "$skill_dir/SKILL.md" "$TARGET_DIR/.claude/skills/$skill_name/SKILL.md"
    ok "Installed .claude/skills/$skill_name"
  done

  # OpenCode skills and commands
  if [ -d "$SRC/.opencode" ]; then
    mkdir -p "$TARGET_DIR/.opencode"
    cp -r "$SRC/.opencode/"* "$TARGET_DIR/.opencode/"
    ok "Installed .opencode/ skills and commands"
  fi

  # GitHub skills
  for skill_dir in "$SRC/.github/skills/openspec-"*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    mkdir -p "$TARGET_DIR/.github/skills/$skill_name"
    cp "$skill_dir/SKILL.md" "$TARGET_DIR/.github/skills/$skill_name/SKILL.md"
    ok "Installed .github/skills/$skill_name"
  done

  # GitHub prompts
  if ls "$SRC/.github/prompts/opsx-"*.prompt.md &>/dev/null; then
    mkdir -p "$TARGET_DIR/.github/prompts"
    cp "$SRC/.github/prompts/opsx-"*.prompt.md "$TARGET_DIR/.github/prompts/"
    ok "Installed .github/prompts/opsx-*.prompt.md"
  fi

  # Root openspec config
  if [ -f "$SRC/openspec/config.yaml" ] && [ ! -f "$TARGET_DIR/openspec/config.yaml" ]; then
    mkdir -p "$TARGET_DIR/openspec"
    cp "$SRC/openspec/config.yaml" "$TARGET_DIR/openspec/config.yaml"
    ok "Installed openspec/config.yaml"
  fi
fi

# --- Summary ---
printf "\n${BOLD}╔═══════════════════════════════════════════════╗${NC}\n"
printf "${BOLD}║       Installation complete!                   ║${NC}\n"
printf "${BOLD}╚═══════════════════════════════════════════════╝${NC}\n\n"

if [ "$DRY_RUN" == "true" ]; then
  warn "This was a dry run. No files were modified."
  info "Run without --dry-run to apply changes."
else
  info "Installed to: $TARGET_DIR"
  if [ -n "$EFFECTIVE_PROFILES" ]; then
    info "Profiles applied: $EFFECTIVE_PROFILES"
  fi
  info "Agent suite: $AGENT_SUITE (role: $EFFECTIVE_ROLE)"
  echo ""
  info "Next steps:"
  info "  1. Review the changes: git diff"
  info "  2. Start the SDD workflow: run /sdd in Claude Code"
  info "  3. For local MCP setup: bash local-packs/bootstrap.sh --tool claude-code"
fi

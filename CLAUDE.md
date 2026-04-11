# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Source of Truth

`AGENTS.md` is the repo-contract source of truth for the distributed workflow. This file is a Claude compatibility entrypoint and repository-operating summary, not a second contractual center.

## What This Repo Is

A **centralized standard distribution system** for spec-driven development (SDD) across org repos. It ships a four-layer architecture:

- **Layer 1 — OpenSpec**: Upstream SDD framework (`opsx:*` skills)
- **Layer 2 — Rojas Baseline**: The delivery contract synced to every repo (AGENTS.md sections, 7 `rojas:*` wrapper skills, OpenSpec config, compatibility entrypoints)
- **Layer 3 — Repo Profiles**: Optional per-repo extensions (frontend, backend-api, brownfield, high-risk)
- **Layer 4 — Local Extensions**: Developer-local MCP configs via `local-packs/` — **never committed to target repos**

This repo itself is not built or compiled. There are no `npm install` / `make` steps. It is a distribution artifact that can be installed via GitHub Action, shell one-liner, or npx.

## OpenSpec Integration (Layer 1)

The repo ships OpenSpec CLI skills and commands at multiple adapter levels:

- **`.claude/commands/opsx/`** — Claude Code slash commands (`/opsx-apply`, `/opsx-archive`, `/opsx-explore`, `/opsx-propose`)
- **`.claude/skills/openspec-*/`** — Claude Code skills for OpenSpec operations
- **`.opencode/skills/openspec-*/`** — OpenCode skills (same content, different adapter)
- **`.opencode/command/opsx-*.md`** — OpenCode commands
- **`.github/skills/openspec-*/`** — GitHub-level skills (Copilot/Codex)
- **`.github/prompts/opsx-*.prompt.md`** — GitHub Copilot prompt files
- **`openspec/config.yaml`** — Root OpenSpec configuration

These are brand-agnostic (use `openspec`/`opsx` terminology, not `rojas:*`) and wrap the upstream `@fission-ai/openspec` CLI.

## Key Operational Commands

**Quick install (individual repo):**
```bash
curl -fsSL https://raw.githubusercontent.com/Sreddx/claude-dev-suite/main/install.sh | bash
npx claude-dev-suite install
```

**Sync to a target repo (dry run first):**
```bash
gh workflow run sdd-sync-targeted.yml -f repos="owner/repo" -f dry_run="true"
gh workflow run sdd-sync-targeted.yml -f repos="owner/repo" -f dry_run="false"
gh workflow run sdd-sync-targeted.yml -f repos="owner/repo" -f profile="frontend" -f dry_run="false"
# Sync to a specific branch (e.g. develop):
gh workflow run sdd-sync-targeted.yml -f repos="owner/repo" -f target_branch="develop" -f dry_run="false"
```

**Bootstrap developer-local MCP tools (never synced to repos):**
```bash
bash local-packs/bootstrap.sh --tool claude-code --airis-url http://localhost:9400/sse
bash local-packs/bootstrap.sh --tool opencode --airis-url http://localhost:9400/sse --scope project
```
Supported bootstrap tools: `claude-code`, `cursor`, `copilot`, `opencode`.

**Installer scripts (used by the Action):**
```bash
bash installer/detect-tools.sh /path/to/repo          # outputs: claude-code,cursor,...
bash installer/install.sh --tool claude-code --target /path/to/repo   # merges MCP config
node installer/merge-agents.js /path/to/AGENTS.md /path/to/template.md  # non-destructive merge
```

## Architecture: How the Action Works

The GitHub Action (`action.yml`) runs these steps on a target repo:
1. Detect tools in use (`.claude/`, `.cursor/`, `.vscode/`, `.codex/`, `.opencode/`)
2. Merge `AGENTS.md` — non-destructive, version-aware via `<!-- rojas:section:name:version -->` markers
3. Sync MCP configs per detected tool (deep JSON merge, respects existing user keys)
4. Init or merge OpenSpec directory (copy-if-missing only)
5. Sync schemas and templates — `schemas/` (format definitions) and `templates/openspec/` (progress.md, handoff.md), copy-if-missing
6. Install SDD commands and scripts — `/sdd` entrypoint, `sdd-preflight.sh`, `sdd-session-report.sh`
7. Install or update skills (force override for rojas:* and community skills)
8. Install or update agent files (version-marker aware, never overwrites user-customized agents)
9. Apply profile if selected
10. Create compatibility entrypoints as real files (`CLAUDE.md`, `.github/copilot-instructions.md`) — not symlinks, so GitHub API and Copilot can read them
11. Commit and open PR (or direct push)

**Non-destructive guarantees:** AGENTS.md versioned section markers, deep JSON merge for MCP configs, copy-if-missing for OpenSpec/schemas/templates, create-if-missing for compatibility entrypoints, version-marker check for agents.

## AGENTS.md Merge Rules

`installer/merge-agents.js` uses HTML comment markers to manage sections:
```
<!-- rojas:section:sdd-workflow:1.1.0 -->
...content...
<!-- /rojas:section:sdd-workflow -->
```
- New sections: appended
- Same version: skipped (idempotent)
- Older version: updated (only between markers)
- Content without rojas markers: **never touched**

## Skills (Layer 2 Wrappers)

Located in `skills/rojas-*/SKILL.md`. Seven wrappers over OpenSpec:

| Skill | Purpose |
|---|---|
| `rojas:explore` | Enriched exploration with live docs, web research, brownfield project memory |
| `rojas:research` | Deep multi-hop investigation with persistent knowledge storage |
| `rojas:propose` | Spec creation with API validation via context7, sub-agent review |
| `rojas:implement` | Strategy-first implementation: isolate when useful, then select best available tooling |
| `rojas:verify` | Isolated verification sub-agent (builder/verifier separation) |
| `rojas:orchestrate` | Task DAG analysis, wave-based parallel dispatch |
| `rojas:kickstart` | Greenfield project bootstrap: PRD/backlog intake → spec decomposition → wave planning |

All skills include mandatory reporting protocol, enforce builder/verifier separation, and are context-optimized (pass only relevant specs/files to sub-agents).

## Profiles (Layer 3)

Located in `profiles/`. Applied on top of baseline:
- `frontend` — Magic for UI generation, Playwright for E2E, a11y checks
- `backend-api` — OpenAPI spec-first, contract validation, integration testing
- `brownfield` — Mandatory serena project memory scan before any work
- `high-risk` — Human review gates, secret pattern checks, 2-reviewer PRs

## Governance (Non-Negotiable Escalation Triggers)

See `docs/GOVERNANCE.md`. Mandatory human review on:
- Auth, payments, PII, infrastructure, external API key changes
- Sub-agent failure on same task (2 failures)
- Spec validation failures or self-contradictions
- HIGH severity verification issues
- Scope expansion beyond spec
- High-risk profile: >1 core module touched

## Versioning

Skills use frontmatter `version: X.Y.Z`. AGENTS.md sections use inline version markers. Both follow semantic versioning. Profiles version independently. See `docs/VERSIONING.md`.

## Testing Strategy

No automated test runner. Fixture repos defined in `docs/TESTING.md`:
- greenfield, brownfield, partial, custom-agents, multi-tool, protected, frontend, high-risk

Validate with dry-run workflow runs against fixture repos before merging changes to `main`.

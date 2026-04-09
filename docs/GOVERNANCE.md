# Governance and Safety Guardrails

This document defines the rules under which the Rojas SDD Cycle standard operates, escalates, and stops. It is binding for all skills, sub-agents, and automation in this standard.

---

## Core Principle

**The SDD standard is a delivery accelerator, not an autonomous agent.** It does not make decisions that belong to humans. When doubt exists, it stops and asks.

---

## Escalation Triggers

The following conditions **always** require escalating to a human before proceeding:

### Domain triggers
- Any spec or task touches: authentication, authorization, session management, tokens, or credentials
- Any spec or task touches: payment flows, billing, subscription state, or financial data
- Any spec or task touches: PII (personally identifiable information), GDPR-regulated data, or health data
- Any spec or task touches: infrastructure config, CI/CD pipelines, deployment manifests, or cloud resource definitions
- Any spec or task touches: database migrations with destructive operations (DROP, TRUNCATE, column removal)
- Any spec or task touches: external API keys, OAuth flows, or third-party authentication

### Process triggers
- A greenfield project begins planning without the user providing PRD/backlog input (or explicitly saying "proceed without PRD")
- A brownfield change begins implementation without either prior `rojas:explore` memory or an explicit minimal-memory fallback
- Any spec, proposal, or tasks.md is written without presenting the 📋 validation gate to the user
- Any agent encounters ambiguity and proceeds without asking the ❓ clarification gate
- The validator issues a PASS without presenting the ✅ manual test checklist to the user
- A sub-agent has failed the same task twice without resolution
- A spec validation finds the proposal is incomplete or self-contradictory
- The verify step finds a HIGH severity issue
- The implementation scope has expanded beyond the approved spec without explicit re-approval
- A dependency version pinned in the spec no longer exists or has a known CVE

### Volume triggers (`high-risk` profile)
- The change touches more than one core module simultaneously
- The change modifies shared infrastructure used by multiple services
- The change removes or renames a public API endpoint

---

## User Interaction Gates (Non-Negotiable)

The SDD standard enforces four mandatory user interaction points. Gate message formats are defined in `schemas/approval-gates.md` and cannot be bypassed by agents:

| Gate | Format | Trigger | Skippable? |
|------|--------|---------|------------|
| 📥 Greenfield intake | PRD/backlog request | Start of greenfield project | Only with explicit "proceed without PRD" |
| 📋 Plan/artifact approval | Validation request with artifact path | After any spec/proposal/tasks.md is written | Never |
| ❓ Clarification | Specific questions about ambiguity | When any agent encounters unclear requirements | Never |
| ✅ Manual test validation | Checklist of what to verify | After validator issues PASS | Only Mode 4 bugfixes (logged) |

Any agent that skips a gate is in violation of governance policy and triggers an escalation.

---

## Secrets and Credentials

**Rule: The standard never stores, logs, transmits, or suggests secrets.**

Specific behaviors:
- Skills must never include API keys, tokens, or passwords in spec artifacts, comments, or research notes
- Sub-agents that encounter credential placeholders must flag them for human configuration — never fill them
- `MORPH_API_KEY`, `AIRIS_*`, and all similar env vars are local-only — never committed to repos
- The `high-risk` profile adds an explicit pre-commit check for secret patterns
- If a secret is accidentally included in a spec or task file, the verify step treats it as a HIGH blocker

**`.gitignore` entries that must be present in repos using local packs:**
```gitignore
# Local developer MCP and tool configs — never commit
.claude/mcp.json
.cursor/mcp.json
.vscode/mcp.json
.opencode/mcp.json
.codex/config.toml
local-packs/

# Agent memory and session state — local only
.claude/projects/
.agent/memory/
.serena/
.mindbase/
```

---

## Destructive Change Policy

**The standard never:**
- Deletes files or directories
- Removes keys from existing MCP configs
- Overwrites AGENTS.md sections that do not have rojas markers
- Truncates or replaces existing OpenSpec artifacts
- Force-pushes to any branch

**The standard may:**
- Update content within rojas-managed AGENTS.md sections (version-gated)
- Replace skill files with newer versions (version-gated)
- Add new keys to MCP configs (deep merge, never removal)
- Close stale sdd-sync PRs it previously opened (only its own PRs, identified by the `sdd-sync` label)

---

## CI/CD and Infrastructure Changes

SDD skills **do not** modify:
- `.github/workflows/` (except to add the required `.github/copilot-instructions.md` compatibility file if missing)
- `Dockerfile`, `docker-compose.yml`, Kubernetes manifests
- Terraform, Pulumi, or CloudFormation templates
- Database migration files (Flyway, Liquibase, Alembic)
- Any file outside `openspec/`, `AGENTS.md`, `CLAUDE.md`, `.agent/`, and tool MCP config paths

If an implementation task would require modifying these files, `rojas:implement` must:
1. Note the requirement in the task output
2. Emit a WARNING in the verify report
3. Defer those specific changes to a human reviewer

---

## MCP Approval Model

MCP servers are classified by risk tier:

| Tier | Servers | Approval required |
|---|---|---|
| Baseline (always safe) | context7, airis-find/schema/exec meta-tools | None — included in baseline |
| Standard | Playwright, serena, mindbase, tavily | Local pack opt-in |
| External service | Stripe, Supabase, any third-party API server | Explicit opt-in per repo |
| Experimental | Any server not in AIRIS catalog | Explicit approval + pinned version |

The baseline sync **never** installs Tier 2+ MCP configs. They are available via `local-packs/` and bootstrapped by individual developers.

Org-wide MCP server enablement requires a governance review before being added to any tier.

---

## Experimental Integrations

Rules for experimental tools and skills:
1. They live in `local-packs/experimental/` — never in `skills/` or `profiles/`
2. They carry a visible `status: experimental` frontmatter flag
3. They are not referenced from AGENTS.md templates
4. They are explicitly excluded from all sync workflows
5. They must graduate through a defined pilot → validated → stable path before promotion

---

## Version Pinning and Rollback

### Pinning
Every repo using the standard should be able to pin to a specific version:
```bash
gh workflow run sdd-sync-targeted.yml \
  -f repos="my-repo" \
  -f version="20260301"
```

### Rollback
If a sync causes issues:
1. The sync always creates a PR (not a direct push) — reject the PR to prevent the change
2. For ruleset-based syncs, the PR is already the rollback gate
3. For any committed sync, `git revert` the sync commit (it is always a single, labeled commit)

### Audit trail
Every sync commit is tagged: `chore(sdd): sync claude-dev-suite v{VERSION}`
Every skill file carries its version in frontmatter.
Every AGENTS.md section carries its version in the HTML comment marker.
This makes it trivial to audit which version of the standard is running where.

---

## Repo Exclusions and Opt-Out Policy

Any repo can opt out of the org-wide ruleset:
1. Add repo to the ruleset's exclusion list in org Settings > Rulesets
2. Or: set a topic `sdd-exempt` on the repo to signal intent

Exclusion reasons that are legitimate:
- Archive/read-only repos
- Infrastructure-as-code repos without application code
- Experimental throwaway repos

Exclusion reasons that are NOT legitimate:
- "We don't want specs" (the whole point is that you do)
- "SDD is too heavy for our workflow" (use a lighter profile)

Disputed exclusions are escalated to the engineering lead, not resolved autonomously.

---

## Human Review Gates

The following actions always require a human to review and approve the PR:

1. First-ever sync to a repo (no prior baseline)
2. Any sync that modifies more than 5 files
3. Any sync to a repo tagged `critical` or `production`
4. Any sync that includes a profile change (baseline → frontend, etc.)
5. The `high-risk` profile — all PRs require a second human reviewer

Auto-merge of sdd-sync PRs is permitted only for:
- Repos with an established baseline (at least 1 prior accepted sync)
- Changes that are skills-only or AGENTS.md-only
- Repos without the `critical` topic

---

## Success Metrics Enforcement

The standard reinforces that outcomes — not activity — matter. Skills are designed to:
- Minimize cycle time (explore → archive), not maximize token usage
- Reduce rework (catch issues at spec time, not after implementation)
- Produce verifiable specs with measurable coverage
- Flag when implementation has drifted from spec

Metrics that should be tracked per org rollout:
- Mean time explore → archive per feature
- Defect escape rate (bugs found post-archive)
- Spec coverage (features with complete openspec artifacts vs. total)
- Rework rate (PRs that required re-implementation after verify failed)
- Sync adoption rate (% of repos on latest baseline)

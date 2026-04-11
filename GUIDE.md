# Rojas SDD Cycle — Guide

Complete reference for using the SDD Dev Suite.

For OS-specific tool installation, see [docs/install/README.md](docs/install/README.md).

---

## Contents

1. [What is SDD?](#1-what-is-sdd)
2. [Four-Layer Architecture](#2-four-layer-architecture)
3. [Installation](#3-installation)
4. [First-time bootstrap](#4-first-time-bootstrap)
5. [SDD flow — mono-repo](#5-sdd-flow--mono-repo)
6. [SDD flow — multi-repo](#6-sdd-flow--multi-repo)
7. [Skills reference](#7-skills-reference)
8. [Profiles](#8-profiles)
9. [MCP infrastructure](#9-mcp-infrastructure)
10. [Local developer packs](#10-local-developer-packs)
11. [Org-wide rollout](#11-org-wide-rollout)
12. [How the installer works](#12-how-the-installer-works)
13. [Observability](#13-observability)
14. [Governance](#14-governance)

---

## 1. What is SDD?

Spec-Driven Development means **agreeing on what you're building before you build it**. The spec is structured so both humans and agents can read it. Tooling ensures you built what the spec says.

```
Explore → Research → Propose → Implement → Verify → Archive
```

No code is written before a spec exists. No spec is implemented before a human approves it.

**Why it works with AI:**
- Agents work better with clear specs than with vague instructions
- Every feature has an audit trail: spec → tasks → code → verification
- Independent tasks run in parallel across sub-agents
- Verification always runs in a fresh context — no confirmation bias

---

## 2. Four-Layer Architecture

```
Layer 1 — OpenSpec         Upstream SDD framework. We consume, never fork.
                           opsx:explore / propose / apply / verify / archive

Layer 2 — Rojas Baseline  The shared delivery contract. Committed to every repo.
                           AGENTS.md sections + rojas:* skills + OpenSpec config

Layer 3 — Repo Profiles    Optional. Committed only to repos that need them.
                           frontend / backend-api / brownfield / high-risk

Layer 4 — Local Extensions Developer-local only. Never committed to repos.
                           Advanced MCP configs, personal memory, experimental tools
```

The separation matters:
- Layers 1–2: what the team builds and how
- Layer 3: how specific teams build
- Layer 4: how individual developers work

Conflating them causes bloat and fragility.

---

## 3. Installation

### Via GitHub Action (recommended)

```yaml
# .github/workflows/sdd-sync.yml
- uses: Sreddx/claude-dev-suite@main
  with:
    agent_suite: 'true'
    agent_suite_version: '1.0.0'
    github_token: ${{ secrets.GITHUB_TOKEN }}
```

**With a profile:**
```bash
gh workflow run sdd-sync-targeted.yml \
  -f repos="my-frontend-repo" \
  -f profile="frontend" \
  -f dry_run="false"
```

**With a repo role (multi-repo setups):**
```bash
# Coordination hub — orchestration agents only
gh workflow run sdd-sync-targeted.yml -f repos="my-hub" -f repo_role="coordination"

# Implementation repos — domain agents only
gh workflow run sdd-sync-targeted.yml -f repos="my-api" -f repo_role="backend"
gh workflow run sdd-sync-targeted.yml -f repos="my-ui" -f repo_role="frontend"
```

**Dry run first:**
```bash
gh workflow run sdd-sync-targeted.yml -f repos="my-repo" -f dry_run="true"
```

### Manual

```bash
cp -r agents/claude/ <your-project>/.claude/agents/
cp -r skills/ <your-project>/.claude/skills/
```

### What gets installed

```
.claude/
  agents/         ← 14 SDD Dev Suite agents
  skills/         ← 7 rojas:* skills + 3 community skills
  commands/sdd.md ← /sdd entrypoint
AGENTS.md         ← SDD contract sections (non-destructive merge)
schemas/          ← Format definitions (task-format, approval-gates, spec-frontmatter)
templates/openspec/ ← progress.md, handoff.md
openspec/
  config.yaml
  specs/
  changes/
scripts/          ← sdd-preflight.sh, sdd-session-report.sh
CLAUDE.md         ← Compatibility pointer (created only if missing)
```

Agent files that don't have the SDD version marker are **never touched** by future syncs. Customized agents are safe.

---

## 4. First-time bootstrap

Open Claude Code in your repo and run `/sdd`. If no `project-stack` section exists in AGENTS.md, the orchestrator determines the bootstrap path:

### Greenfield detection

If `project-stack` is absent AND no source code directories exist → **GREENFIELD**. Otherwise → **BROWNFIELD**.

### Greenfield bootstrap

The orchestrator invokes `rojas:kickstart` and outputs the 📥 PRD/backlog intake request:

```
1. Orchestrator detects greenfield → outputs 📥 intake request
2. User provides PRD and/or backlog (markdown, XLSX, CSV, paste — any format)
3. Orchestrator parses input → outputs structured summary (epics, stories, priorities)
4. Orchestrator asks ❓ clarifying questions (tech stack, deployment, ambiguities)
5. Orchestrator proposes openspec decomposition → 📋 approval gate
6. Orchestrator proposes implementation waves → 📋 approval gate
7. agent-prep bootstraps AGENTS.md and project-stack
8. Implementation begins wave by wave with approval gates
```

This gate is **non-skippable** unless the user explicitly says "proceed without PRD."

### Brownfield bootstrap

`agent-prep` runs immediately (no PRD required):

1. Scans the codebase — detects tech stack, architecture, ORM, test framework
2. Generates a **domain map** — maps directories to agent domains:
   ```
   frontend_paths:      src/components/**, src/pages/**
   backend_paths:       src/api/**, src/services/**
   database_paths:      prisma/**, migrations/**
   test_frontend_paths: tests/e2e/**, tests/components/**
   test_backend_paths:  tests/api/**, tests/integration/**
   ```
3. Writes `<!-- rojas:section:project-stack -->` to AGENTS.md
4. Runs `devstart` — validates environment, probes MCP availability
5. Recommends external skills for your stack

After bootstrap, all agents read the domain map and project-stack from AGENTS.md. No agent operates blind.

---

## 5. SDD flow — mono-repo

### Starting a session

Every session starts with `/sdd`. It runs `scripts/sdd-preflight.sh` and shows an MCP status report, then asks which mode you want.

```
╔═══════════════════════════════════════════════════╗
║            SDD Dev Suite — Ready                  ║
╠═══════════════════════════════════════════════════╣
║ ✓  airis-mcp-gateway   Tool discovery             ║
║ ✓  context7            Library docs               ║
║ ✗  serena              Session persistence        ║
╠═══════════════════════════════════════════════════╣
║ serena DOWN: state saved to .claude/state/ only   ║
╚═══════════════════════════════════════════════════╝
```

### 5 modes

| Mode | Use when |
|------|---------|
| **1 — Plan + implement** | Starting a new feature end-to-end |
| **2 — Implement from plan** | You have an existing `tasks.md` ready to execute |
| **3 — Research** | You need to explore or investigate before planning |
| **4 — Bugfix** | Fixing a single-domain issue; minimal scope |
| **5 — Bootstrap** | First-time project setup |

### Mode 1 — full cycle

```
/sdd → Mode 1

researcher       researches unknowns → openspec/changes/<n>/research.md
                   ❓ may ask clarifying questions if scope is ambiguous

planner          decomposes into:
                   proposal.md      what and why
                   design.md        architecture decisions
                   tasks.md         task checklist with domain tags + acceptance criteria

                 automated plan checks:
                   ✓ every task has domain tag + acceptance criteria
                   ✓ no cross-domain file references without markers
                   ✓ API contracts documented for frontend→backend dependencies
                   ✓ test task exists for every implementation task

┌─────────────────────────────────────┐
│  📋 PLAN APPROVAL GATE              │
│  "Validation required before        │
│   proceeding" — approve or feedback  │
└─────────────────────────────────────┘

orchestrator     dispatches implementation agents directly (no intermediary)
                   ❓ implementation agents may ask clarifications

  Wave 1:  frontend + backend + database  (parallel, domain-isolated)
  Wave 2:  tester-front + tester-back     (parallel)
  Wave 3:  github-ops                     (commits + PRs)

agent-sync       updates AGENTS.md + task state

validator        quality scorecard /18
                 + ✅ manual test checklist (at least 3 specific items)

┌─────────────────────────────────────┐
│  ✅ MANUAL TEST GATE                │
│  "Before marking this feature       │
│   complete, verify the following…"   │
│  Reply ✅ to confirm or report issues│
└─────────────────────────────────────┘

opsx:archive
```

### User interaction gates

The workflow pauses for human input at four key moments:

| Gate | Emoji | When | Agent |
|------|-------|------|-------|
| Greenfield intake | 📥 | Start of a new greenfield project | orchestrator |
| Plan/artifact approval | 📋 | After any spec, proposal, or tasks.md is written | planner / orchestrator |
| Clarification | ❓ | When any agent encounters ambiguity | any agent |
| Manual test validation | ✅ | After validator issues a PASS | validator / orchestrator |

All gates use standardized message formats defined in `schemas/approval-gates.md`. The 📋 and ✅ gates are non-skippable. The ❓ gate fires only for genuinely blocking ambiguity. The 📥 gate can only be bypassed with "proceed without PRD."

### Domain isolation

Every implementation agent owns its domain from the project-stack domain map. Agents don't read files outside their domain. `agent-sync` flags violations.

- **frontend** → `frontend_paths`
- **backend** → `backend_paths`
- **database** → `database_paths`
- **tester-front** → `test_frontend_paths`
- **tester-back** → `test_backend_paths`

If no domain map exists (bootstrap not run), agents use hardcoded defaults with a `[DOMAIN] WARNING`.

### Backend: Postman collection sync

After implementing any API endpoint, `backend` automatically:
- Updates the existing `*.postman_collection.json` if one exists, or
- Creates `postman/<project-name>.postman_collection.json` using Postman v2.1 format

All collections use `{{base_url}}` and `{{auth_token}}` variables.

### Database: ORM detection

`database` detects the ORM from project files before any work:

| Detected file | ORM |
|---------------|-----|
| `prisma/schema.prisma` | Prisma |
| `drizzle.config.*` | Drizzle |
| `alembic.ini` | Alembic (Python) |
| `manage.py` + `*/models.py` | Django ORM |
| `db/migrate/` + `Gemfile` | ActiveRecord (Ruby) |
| `go.mod` + `migrations/*.sql` | golang-migrate |
| ... | 11 ORMs total |

All migration operations use the ORM's CLI directly — no MCP needed.

### Frontend: Playwright CLI-first

Playwright is always run via CLI, not MCP:

```bash
npx playwright test                          # all e2e
npx playwright test tests/e2e/feature.spec.ts
npx playwright test --ui
npx playwright test --debug
```

The Playwright MCP is only used for interactive browser debugging (screenshots, DOM inspection).

If GSAP is in `package.json`, the frontend agent references gsap-core, gsap-timeline, and gsap-scrolltrigger skills automatically.

### Quality scorecard

```
Completeness:         _/3
Correctness:          _/3
Code quality:         _/3
Test coverage:        _/3
Standards compliance: _/3
Documentation:        _/3
Total:               _/18   pass threshold: 12/18
```

Any BLOCKER issue prevents the manual test gate from being skipped.

### Manual test handoff

After the validator issues a PASS, it outputs a structured ✅ checklist:

- **What was implemented** — 1–3 sentence plain-English summary
- **Manual test checklist** — at least 3 specific, actionable items (not generic)
- **Where to look** — key files changed and entry point (URL, CLI command, or component)
- **Known limitations** — what automated tests did not cover

The developer must reply ✅ to confirm or report issues before the cycle can archive.

### Session resilience

- Implementers mark tasks complete in `tasks.md` as they go
- `agent-sync` persists state after each wave (serena or `.claude/state/` fallback)
- `progress.md` is updated at each wave boundary with task counts and status (see `templates/openspec/progress.md`)
- To resume: `/sdd` → orchestrator reads `progress.md` and task state, reports current wave, continues

---

## 6. SDD flow — multi-repo

For architectures with separate repos (e.g., `api` + `frontend`), all planning and orchestration happens from one **coordination repo**. Implementation repos are dispatched as Agent Teams teammates.

### Setup

1. **Sync roles:**
   ```bash
   gh workflow run sdd-sync-targeted.yml -f repos="my-hub" -f repo_role="coordination"
   gh workflow run sdd-sync-targeted.yml -f repos="my-api" -f repo_role="backend"
   gh workflow run sdd-sync-targeted.yml -f repos="my-ui" -f repo_role="frontend"
   ```

   Role → agents installed:
   | Role | Agents |
   |------|--------|
   | `standalone` | All 14 |
   | `coordination` | orchestrator, planner, researcher, validator, agent-prep, agent-sync, devstart |
   | `backend` | backend, database, tester-back, github-ops |
   | `frontend` | frontend, tester-front, github-ops |

2. **Enable Agent Teams** in the coordination repo:
   ```bash
   cp templates/settings/claude-settings.json .claude/settings.json
   ```

3. **Configure `openspec/config.yaml`** in the coordination repo:
   ```yaml
   repos:
     api:
       path: ../my-api
       branch_prefix: feat/
     frontend:
       path: ../my-ui
       branch_prefix: feat/
   contracts_dir: openspec/contracts
   ```

### Coordination flow

```
/sdd in coordination repo → Mode 1

planner tags every task with repo:
  - [ ] [repo:api] POST /api/tickets — acceptance: returns 201
  - [ ] [repo:frontend] TicketList — acceptance: renders from API
    depends_on: [repo:api] POST /api/tickets

PLAN APPROVAL GATE

orchestrator detects MULTI_REPO=true (preflight)

dispatch teammate → my-api (backend agent)
  implements [repo:api] tasks
  writes contracts → openspec/contracts/tickets.yaml
  updates openspec/state/tasks-live.json

dispatch teammate → my-ui (frontend agent)
  waits for contracts_ready in tasks-live.json
  implements [repo:frontend] tasks

testers run per repo (parallel)
github-ops opens PRs per repo
validator runs cross-repo verification
```

### Wave structure (multi-repo)

| Wave | Work |
|------|------|
| 1 | Database migrations |
| 2 | Backend endpoints + Postman collection + OpenAPI contracts |
| 3 | Frontend consuming contracts |
| 4 | Testers (per repo, parallel) |
| 5 | github-ops (per repo, parallel PRs) |
| 6 | Validator (cross-repo) |

### Shared task state

`openspec/state/tasks-live.json` is the cross-repo coordination file. `agent-sync` updates it after each wave so teammates can check each other's progress.

### Implementation repos

Implementation repos (`backend` / `frontend` role) only support `/sdd Mode 4` (bugfix) for local quick fixes. All planning, research, and orchestrated work goes through the coordination repo.

---

## 7. Skills reference

| Skill | Wraps | MCP needed | Purpose |
|-------|-------|-----------|---------|
| `rojas:explore` | `opsx:explore` | context7, serena | Codebase exploration + brownfield project memory |
| `rojas:research` | — | context7, serena | Multi-hop research, output to `research.md` |
| `rojas:propose` | `opsx:new`, `opsx:ff` | context7, serena | Spec creation + automated plan checks |
| `rojas:implement` | `opsx:apply` | airis-mcp-gateway, context7, serena | Strategy-first implementation with TDD |
| `rojas:verify` | `opsx:verify` | — | Isolated quality gate + manual test handoff |
| `rojas:orchestrate` | — | airis-mcp-gateway, serena | DAG analysis, wave-based parallel dispatch |
| `rojas:kickstart` | `rojas:explore`, `rojas:propose` | — | Greenfield project bootstrap: PRD/backlog intake → spec decomposition → wave planning |

All MCP dependencies are optional — skills fall back to native tools when unavailable.

---

## 8. Profiles

Profiles are opt-in Layer 3 extensions. Applied at sync time, committed to repos that need them.

| Profile | When to use | What it adds |
|---------|-------------|-------------|
| `frontend` | React/Vue/Angular | Playwright CLI conventions, GSAP skills, UI a11y checks |
| `backend-api` | REST/GraphQL APIs | Contract testing, OpenAPI spec integration |
| `brownfield` | Large existing codebases | Mandatory codebase scan before any work |
| `high-risk` | Auth, payments, PII | Human review gates, 2-reviewer PRs, audit trail |

Apply:
```bash
gh workflow run sdd-sync-targeted.yml -f repos="my-repo" -f profile="frontend"
```

Profile files: `profiles/`

---

## 9. MCP infrastructure

No MCP is required. Every agent has a fallback.

### Core MCP servers

| Server | Purpose | Fallback |
|--------|---------|---------|
| **airis-mcp-gateway** | 60+ tools via 3 meta-tools (airis-find, airis-schema, airis-exec) | Native Grep/Glob/WebSearch |
| **context7** | Up-to-date library documentation | WebSearch + package.json; API calls marked `needs-verification` |
| **serena** | Session state, brownfield project memory | File-based state in `.claude/state/` |
| **figma** | Design context for frontend work | Skip; more manual design-to-code iterations |

### Playwright

Always CLI-first (`npx playwright test`). Never a required MCP. Use as MCP only for interactive browser debugging.

### Database

No MCP. Uses the project's ORM CLI directly (npx prisma, alembic, rails, etc.).

### Validator

No MCP. Read-only — uses only Read, Glob, Grep, Bash.

### airis-mcp-gateway usage

The gateway provides 60+ tools via 3 meta-tools, reducing token cost by ~98%:

```
airis-find "memory"          → discover available tools
airis-schema "tool-name"     → get input schema
airis-exec "tool-name" {...} → call the tool
```

Available catalog: context7, serena, stripe, supabase, and others — discovered on demand.

---

## 10. Local developer packs

Advanced MCP configs are **never synced to repos**. Install locally:

```bash
bash local-packs/bootstrap.sh --tool claude-code --airis-url http://localhost:9400/sse
```

This installs to `~/.claude/mcp.json` — the repo is never touched.

Supported tools: `claude-code`, `cursor`, `copilot`, `opencode`.

### AIRIS Gateway

The gateway must be running for airis-mcp-gateway tools:

```bash
# In your airis-mcp-gateway directory
docker compose up -d

# Check
curl http://localhost:9400/sse
```

### Gitignore for local configs

```gitignore
.claude/mcp.json
.cursor/mcp.json
.vscode/mcp.json
.claude/state/
```

---

## 11. Org-wide rollout

### Targeted sync

```bash
# Dry run one repo
gh workflow run sdd-sync-targeted.yml -f repos="my-repo" -f dry_run="true"

# Apply to one repo
gh workflow run sdd-sync-targeted.yml -f repos="my-repo" -f dry_run="false"

# Multiple repos
gh workflow run sdd-sync-targeted.yml -f repos="repo-a,repo-b,repo-c"

# All repos
gh workflow run sdd-sync-targeted.yml -f repos="all" -f exclude="claude-dev-suite"
```

### Via Repository Rulesets (Enterprise Cloud)

1. **Org Settings → Rulesets → New ruleset**
2. Rule: **Require workflows to pass**
3. Workflow: `Sreddx/claude-dev-suite/.github/workflows/sdd-sync-ruleset.yml@main`
4. Start in **Evaluate** mode, switch to **Active** after pilot evidence
5. Exclude: `claude-dev-suite`, archived repos, infra-only repos

### Recommended sequence

```
1. dry_run=true on one repo → review output
2. dry_run=false on one repo → open and review PR
3. Expand to 3-5 pilot repos
4. Validate results (cycle time, defect rate, team feedback)
5. Org-wide via ruleset
```

---

## 12. How the installer works

### Tool detection

`detect-tools.sh` finds which AI tools are in use:
- `.claude/` → Claude Code
- `.cursor/` → Cursor
- `.vscode/` or `.github/copilot-instructions.md` → Copilot
- `.codex/` → Codex
- `.opencode/` → OpenCode

### AGENTS.md merge

Versioned section markers:

```markdown
<!-- rojas:section:sdd-workflow:1.1.0 -->
...managed content...
<!-- /rojas:section:sdd-workflow -->
```

- Section missing → append
- Same version → skip
- Older version → update content between markers
- No markers → **never touch**

### Agent install

`installer/install-agents.sh` filters agents by repo role. For each agent:
- Agent missing → install
- Agent has SDD version marker → update
- Agent has no marker (user-customized) → skip

### Skill versioning

Skills use semver in frontmatter. The installer skips skills at the same or newer version. Downgrade never happens.

---

## 13. Observability

Copy `templates/settings/hooks.json` into `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [{
      "command": "echo \"[TRACE] $(date -Iseconds) tool=$TOOL_NAME\" >> .claude/state/agent-trace.log"
    }],
    "PreToolUse": [{
      "matcher": "Write|Edit",
      "agent": "validator",
      "command": "echo \"BLOCKED\" && exit 1"
    }],
    "Stop": [{
      "command": "bash scripts/sdd-session-report.sh 2>/dev/null || true"
    }]
  }
}
```

- **Trace log** — every tool call logged to `.claude/state/agent-trace.log`
- **Validator block** — prevents validator from accidentally writing files
- **Session report** — `scripts/sdd-session-report.sh` prints tool usage summary and rotates the log

---

## 14. Governance

### User interaction gates (non-negotiable)

| Gate | Format | When | Skippable? |
|------|--------|------|------------|
| 📥 Greenfield intake | PRD/backlog request | Start of greenfield project | Only with explicit "proceed without PRD" |
| 📋 Plan/artifact approval | Validation request | After any spec/proposal/tasks.md written | Never |
| ❓ Clarification | Specific questions | When any agent encounters ambiguity | Never |
| ✅ Manual test validation | Checklist to verify | After validator issues PASS | Only Mode 4 bugfixes (logged) |

### Mandatory escalation triggers

- Change touches auth, payments, PII, or infrastructure config
- A greenfield project begins planning without PRD/backlog input
- Any spec is written without presenting the 📋 validation gate
- Any agent proceeds through ambiguity without asking the ❓ clarification gate
- Validator passes without presenting the ✅ manual test checklist
- A sub-agent fails the same task twice
- A spec references external APIs with no reachable docs
- `high-risk` profile is active and scope exceeds one core module

See [docs/GOVERNANCE.md](docs/GOVERNANCE.md) for the full escalation model.

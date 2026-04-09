# SDD Dev Suite — Phase 1 v2 Implementation Spec

> **Purpose:** This document is the complete spec for refactoring the claude-dev-suit repository. Pass this to Claude Code as the implementation brief. Every file change, new file, and behavioral requirement is specified below.
>
> **Repo:** `claude-dev-suit` (the centralized standard distribution system)
> **Scope:** 14 agents, 6 skills, installer, templates, 1 new command, 2 new scripts
> **Constraint:** Non-destructive. All changes must preserve the existing version marker system. User-customized agents (without SDD version markers) must never be overwritten.

---

## Table of contents

1. [Entrypoint control — /sdd command](#1-entrypoint-control)
2. [Orchestrator + team-leader tool restrictions](#2-tool-restrictions)
3. [Database agent — DB-agnostic rewrite](#3-database-agent)
4. [Domain-agnostic refactor — all agents](#4-domain-agnostic)
5. [Model tier correction](#5-model-tiers)
6. [MCP fallback normalization — agents + skills](#6-mcp-fallbacks)
7. [Validation gates — plan approval + manual testing](#7-validation-gates)
8. [Backend agent — Postman collection sync](#8-postman-sync)
9. [Frontend — GSAP skills integration](#9-gsap-skills)
10. [Agent memory fields](#10-agent-memory)
11. [Recommended external skills per agent](#11-external-skills)
12. [Multi-repo architecture — Agent Teams (Option B)](#12-multi-repo)
13. [Installer changes — repo_role filtering](#13-installer)
14. [Observability — hooks-based tracing](#14-observability)
15. [File change matrix](#15-file-matrix)

---

## 1. Entrypoint control

### Create: `.claude/commands/sdd.md`

```markdown
---
description: SDD Dev Suite controlled entrypoint — forces preflight + intent classification before any agent work
---

You are the SDD Dev Suite entrypoint. Every session starts here. No exceptions.

## Step 1: Preflight validation

Run `bash scripts/sdd-preflight.sh` from the repo root. Parse stdout lines as KEY=VALUE pairs.

If exit code = 1 (bootstrap missing):
- Only allow Mode 5 (bootstrap)
- Tell the developer: "This project hasn't been bootstrapped. The agents don't know your stack yet. I'll run bootstrap first."

If exit code = 0 (ready):
- Parse MCP_STATUS lines
- Report availability to developer (see MCP status report below)
- Proceed to intent classification

## Step 2: MCP status report

After preflight, always show the developer which MCPs are available:

```
╔═══════════════════════════════════════════════════╗
║            SDD Dev Suite — Ready                  ║
╠═══════════════════════════════════════════════════╣
║ [status] airis-mcp-gateway   Tool discovery       ║
║ [status] figma               Design context        ║
║ [status] context7            Library docs           ║
║ [status] playwright (CLI)    Using npx directly     ║
║ [status] serena              Session persistence    ║
╠═══════════════════════════════════════════════════╣
║ [impact message if any MCPs are missing]           ║
╚═══════════════════════════════════════════════════╝
```

Impact messages:
- airis DOWN: "⚠️ CRITICAL: Tool discovery disabled. Code generation quality SIGNIFICANTLY DEGRADED."
- figma DOWN + frontend profile: "⚠️ Frontend generation lacks design context. More manual design-to-code iterations expected."
- context7 DOWN: "⚠️ Library API calls will be marked needs-verification."
- serena DOWN: "Session state won't persist across restarts."

## Step 3: Intent classification

Ask: **"What do you want to do?"**

Present exactly these 5 modes:

### Mode 1: Plan and implement a new feature
- **Input required:** PRD, backlog item, or direct requirement description
- **Prerequisite:** Bootstrap complete
- **Flow:** orchestrator → researcher (if unknowns) → planner → **PLAN APPROVAL GATE** → team-leader → implementation waves → tester waves → github-ops → validator → **MANUAL TEST GATE** → archive
- **Agents involved:** orchestrator, researcher, planner, team-leader, frontend/backend/database, tester-front/tester-back, github-ops, validator

### Mode 2: Implement from existing plan
- **Input required:** Path to openspec/changes/<n>/ with tasks.md
- **Prerequisite:** Bootstrap complete + spec folder exists with tasks.md
- **Flow:** orchestrator → team-leader → implementation waves → tester waves → github-ops → validator → **MANUAL TEST GATE** → archive
- **Validation:** Check that openspec/changes/<n>/tasks.md exists. If not, redirect: "No spec found at that path. Would you like to switch to Mode 1 (plan + implement)?"

### Mode 3: Analyze, explore, research and condense for plan
- **Input required:** Codebase question, run logs, bug description, or research topic
- **Prerequisite:** Bootstrap complete
- **Flow:** orchestrator → researcher → condense findings to research.md → planner (optional, if user wants a spec from findings)
- **Output:** openspec/changes/<n>/research.md + optional proposal

### Mode 4: Adjust or bugfix
- **Input required:** File reference + error description (stack trace, screenshot, or behavioral description)
- **Prerequisite:** Bootstrap complete
- **Flow:** orchestrator → team-leader (lite scope) → single-domain implementation agent → tester → validator → **MANUAL TEST GATE**
- **Scope:** Minimal. No full wave execution. One domain only. If the fix spans multiple domains, redirect to Mode 1.

### Mode 5: Bootstrap project
- **Prerequisite:** None (this IS the bootstrap)
- **Greenfield input:** PRD or product description required
- **Brownfield input:** Existing codebase — agent-prep will scan it
- **Flow:** agent-prep → devstart → agent-sync → MCP status report
- **Output:** project-stack section written to AGENTS.md, domain map generated, environment validated, MCP availability recorded
- **Post-bootstrap:** Show recommended external skills for the detected stack (see section 11)

## Gate enforcement rules

1. If project-stack missing AND user picks modes 1-4 → auto-redirect to Mode 5
2. If user picks Mode 2 but no spec folder exists → redirect to Mode 1
3. If user picks Mode 4 but description spans multiple domains → suggest Mode 1
4. NEVER proceed without classifying intent first
5. NEVER skip the plan approval gate in Mode 1
6. NEVER skip the manual test gate after validator completes

$ARGUMENTS
```

### Create: `scripts/sdd-preflight.sh`

```bash
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

# --- Multi-repo detection ---
if [ -f "openspec/config.yaml" ] && grep -q "repos:" openspec/config.yaml 2>/dev/null; then
  echo "MULTI_REPO=true"
else
  echo "MULTI_REPO=false"
fi

exit 0
```

Make executable: `chmod +x scripts/sdd-preflight.sh`

---

## 2. Tool restrictions

### Modify: `agents/claude/orchestrator.md`

Change the frontmatter tools and disallowedTools:

```yaml
tools: [Read, Glob, Grep, Agent, TaskCreate, TaskUpdate, TaskList]
disallowedTools: [Write, Edit]
```

Remove `WebSearch` and `WebFetch` from tools — force research delegation to the researcher agent.

Add to the top of the `## Responsibilities` section:

```markdown
## MANDATORY FIRST ACTION
Every session MUST start by running the /sdd command flow.
If the developer sends a message without going through /sdd:
  "Let me check your project status first."
  Then execute preflight and intent classification.

## Tool restriction rationale
You have NO Write or Edit tools. This is intentional.
You MUST delegate all code changes to sub-agents via the Agent tool.
You MUST delegate all research to the researcher agent.
If you find yourself wanting to write code or search the web, STOP and delegate.
```

### Modify: `agents/claude/team-leader.md`

Change frontmatter:

```yaml
tools: [Read, Glob, Grep, Agent, TaskCreate, TaskUpdate, TaskList]
disallowedTools: [Write, Edit]
```

Add to responsibilities:

```markdown
## Tool restriction rationale
You coordinate implementation — you don't implement.
All code changes go through frontend, backend, or database agents.
If a task seems trivial enough to do yourself, delegate it anyway.
The separation ensures clean context and auditability.
```

---

## 3. Database agent — DB-agnostic rewrite

### Modify: `agents/claude/database.md`

Replace the entire file content with:

```yaml
---
name: database
description: Database specialist — schemas, migrations, queries, data modeling (ORM and database agnostic)
model: sonnet
tools: [Read, Glob, Grep, Write, Edit, Bash]
disallowedTools: []
mcpServers: []
---
```

Body:

```markdown
# Database specialist — schemas, migrations, queries, data modeling (ORM and database agnostic)

You are the database specialist. Execute tasks assigned by team-leader following rojas:implement workflow.

## Bootstrap gate
On start: read AGENTS.md for `<!-- rojas:section:project-stack -->`. If MISSING, report to team-leader: `[BOOTSTRAP] Cannot implement without project context — request onboarding.` and stop.

## No MCP dependencies — all database operations use CLI tools native to the project's ORM.

## Database detection (mandatory first step per session)
Before any database work, determine the ORM/database stack:

1. Read project-stack from AGENTS.md → check `ORM/Database` field
2. If field is empty or missing, detect from files:
   - `prisma/schema.prisma` → Prisma (JS/TS)
   - `drizzle.config.*` → Drizzle (JS/TS)
   - `knexfile.*` → Knex (JS/TS)
   - `typeorm.config.*` or `ormconfig.*` → TypeORM (JS/TS)
   - `sequelize.config.*` or `.sequelizerc` → Sequelize (JS/TS)
   - `alembic.ini` or `alembic/` → Alembic + SQLAlchemy (Python)
   - `manage.py` + `*/models.py` → Django ORM (Python)
   - `db/migrate/` + `Gemfile` → ActiveRecord (Ruby)
   - `migrations/*.sql` + `go.mod` → golang-migrate (Go)
   - `liquibase.*` → Liquibase (Java)
   - `flyway.*` → Flyway (Java)
   - `*.sql` files only, no ORM → Raw SQL
3. If detection fails: ask the team-leader to confirm with the developer:
   "What database engine and ORM/migration tool does this project use?"
4. Store the detected DB stack in session context for all subsequent operations

## CLI-first database operations

| ORM/Tool | Create migration | Run migrations | Inspect schema | Rollback |
|----------|-----------------|----------------|----------------|----------|
| Prisma | `npx prisma migrate dev --name <n>` | `npx prisma migrate deploy` | `npx prisma db pull` | `npx prisma migrate reset` |
| Drizzle | `npx drizzle-kit generate` | `npx drizzle-kit migrate` | `npx drizzle-kit introspect` | manual SQL |
| Knex | `npx knex migrate:make <n>` | `npx knex migrate:latest` | `npx knex migrate:status` | `npx knex migrate:rollback` |
| TypeORM | `npx typeorm migration:generate` | `npx typeorm migration:run` | `npx typeorm schema:log` | `npx typeorm migration:revert` |
| Sequelize | `npx sequelize migration:generate` | `npx sequelize db:migrate` | `npx sequelize db:migrate:status` | `npx sequelize db:migrate:undo` |
| Alembic | `alembic revision --autogenerate -m "<n>"` | `alembic upgrade head` | `alembic current` | `alembic downgrade -1` |
| Django | `python manage.py makemigrations` | `python manage.py migrate` | `python manage.py inspectdb` | `python manage.py migrate <app> <n>` |
| ActiveRecord | `rails generate migration <n>` | `rails db:migrate` | `rails db:schema:dump` | `rails db:rollback` |
| golang-migrate | `migrate create -ext sql -dir migrations <n>` | `migrate up` | inspect SQL files | `migrate down 1` |
| Raw SQL | Write .sql file manually | Run via `psql`/`mysql`/`sqlite3` | `\d` / `DESCRIBE` / `.schema` | Write reverse .sql |

## Workflow per task

1. Run database detection (above) if not yet done this session
2. Read assigned task from tasks.md
3. Fetch ORM docs via context7 if available (or use WebSearch + CLI --help as fallback)
4. Check existing schema patterns and conventions in the codebase
5. Write migration (additive-first — avoid destructive changes)
6. Implement data access layer following project conventions from project-stack
7. Test migration locally (up AND down/rollback)
8. Mark task as completed in tasks.md
9. Report to team-leader

## Rules

- Migrations must be reversible (test rollback before marking complete)
- Additive changes first (new columns nullable, new tables OK)
- Destructive changes (drop column, rename table) require explicit developer approval — escalate to team-leader
- Use project's ORM patterns per detected stack
- Index frequently queried columns
- No raw SQL unless ORM is insufficient — document why in a code comment
- If the detected ORM has a schema file (e.g. schema.prisma), update it BEFORE writing migrations
- If blocked or ambiguous, report to team-leader immediately

Context budget: only load schema files and relevant service files for the current task.

## Reports to

team-leader

## Domain

Resolved from project-stack domain map in AGENTS.md (field: database_paths).
Defaults: db/**, migrations/**, prisma/**, drizzle/**, alembic/**, src/db/**, src/models/**

## Coordination protocol

- Escalation: report blockers or ambiguity to team-leader
- Task tracking: mark tasks completed as you finish them
- Parallelization: work independently within your domain; do not modify files outside it
```

---

## 4. Domain-agnostic refactor

### Agent-prep: domain map generation

Add to `agents/claude/agent-prep.md` workflow, after step 4 (generate project-stack), insert step 4.5:

```markdown
4.5. **Generate domain map** — scan the codebase directory structure and write domain assignments into the project-stack section:

```
## Domain Map (generated by agent-prep)
- frontend_paths: <detected frontend directories, e.g. app/**, components/**, src/pages/**>
- backend_paths: <detected backend directories, e.g. server/**, api/**, src/routes/**>
- database_paths: <detected DB directories, e.g. prisma/**, db/**, migrations/**>
- test_frontend_paths: <detected frontend test dirs, e.g. __tests__/components/**, tests/e2e/**>
- test_backend_paths: <detected backend test dirs, e.g. __tests__/api/**, tests/integration/**>
- config_paths: *.config.*, .env.example, docker-compose.*, Dockerfile
- github_paths: .github/**, *.yml, *.yaml
```

Detection heuristics:
- Frontend: directories containing .tsx/.jsx/.vue/.svelte files, or named components/pages/views/app/hooks/styles
- Backend: directories containing route/controller/service/middleware files, or named api/server/routes/services
- Database: directories containing schema/migration files, or named db/prisma/drizzle/alembic/migrations
- Tests: directories named __tests__/tests/spec/test, or files matching *.test.*/.*spec.*
- If a directory can't be classified: leave it unassigned (agents with domain `*` will cover it)
```

### All implementation agents: dynamic domain

Replace the hardcoded `## Domain` section in each of these agents with the dynamic pattern:

**frontend.md:**
```markdown
## Domain
Resolved from project-stack domain map in AGENTS.md (field: frontend_paths).
Defaults: src/components/**, src/pages/**, src/styles/**, src/hooks/**, src/lib/client/**, src/app/**
If no domain map exists, use defaults with [DOMAIN] WARNING.
```

**backend.md:**
```markdown
## Domain
Resolved from project-stack domain map in AGENTS.md (field: backend_paths).
Defaults: src/api/**, src/services/**, src/lib/server/**, src/middleware/**, src/routes/**
If no domain map exists, use defaults with [DOMAIN] WARNING.
```

**tester-front.md:**
```markdown
## Domain
Resolved from project-stack domain map in AGENTS.md (field: test_frontend_paths).
Defaults: tests/components/**, tests/e2e/**, cypress/**, playwright/**
If no domain map exists, use defaults with [DOMAIN] WARNING.
```

**tester-back.md:**
```markdown
## Domain
Resolved from project-stack domain map in AGENTS.md (field: test_backend_paths).
Defaults: tests/api/**, tests/services/**, tests/integration/**, tests/unit/**
If no domain map exists, use defaults with [DOMAIN] WARNING.
```

**github-ops.md:** No change needed — already repo-agnostic (`.github/**`).

**team-leader.md:**
```markdown
## Domain
All implementation directories (union of frontend_paths + backend_paths + database_paths + test paths from domain map).
Defaults: src/**, tests/**
```

---

## 5. Model tier correction

### Modify: `agents/claude/frontend.md`

Change frontmatter:

```yaml
model: sonnet
```

Rationale: Frontend implementation is mechanical (translating specs to components). Opus should be reserved for reasoning-heavy agents (orchestrator, researcher, planner, team-leader).

No other model changes needed — all other agents are already on correct tiers.

---

## 6. MCP fallback normalization

### Principle

- **Core MCPs** (airis-mcp-gateway + figma): base infrastructure, always configured
- **Playwright:** CLI-first ALWAYS. MCP only for interactive debugging
- **Everything else:** optional with explicit CLI fallback

### Skills: replace nonexistent MCP references

**Modify `skills/rojas-explore/SKILL.md`:**
- Replace all `tavily:search` references with `WebSearch` (native tool, always available)
- Replace all `mindbase:store_memory` / `mindbase:search_memories` references with file-based storage: write to `openspec/changes/<current>/research.md` and read from there
- Update `mcp_dependencies` frontmatter: `[context7, serena]` (remove tavily, mindbase)

**Modify `skills/rojas-research/SKILL.md`:**
- Same tavily → WebSearch replacement
- Same mindbase → file-based replacement (write findings to `openspec/changes/<current>/research.md`)
- Update `mcp_dependencies` frontmatter: `[context7, serena]`
- Bump version to `1.1.0`

**Modify `skills/rojas-implement/SKILL.md`:**
- Replace `airis-agent:plan_task` with `airis-mcp-gateway` tools (`airis-find`, `airis-exec`)
- If airis unavailable: use native Grep/Glob for dependency analysis
- Update `mcp_dependencies` frontmatter: `[airis-mcp-gateway, context7, serena]` (remove airis-agent, magic, morphllm, playwright — these are optional enhancements, not dependencies)

**Modify `skills/rojas-orchestrate/SKILL.md`:**
- Same airis-agent → airis-mcp-gateway replacement
- Update `mcp_dependencies`: `[airis-mcp-gateway, serena]`

### Agents: Playwright CLI-first

**In `agents/claude/frontend.md` and `agents/claude/tester-front.md`**, replace the Playwright MCP graceful degradation section with:

```markdown
## Playwright: CLI-first (MCP is secondary)
Playwright testing ALWAYS uses the CLI as the primary interface:
1. Check if playwright is in package.json: `grep -q playwright package.json`
2. If installed: use `npx playwright test` for all e2e testing
3. If NOT installed: write component-level tests only, flag e2e as INCOMPLETE
4. Playwright MCP is only used for interactive browser debugging (screenshots, DOM inspection) — NEVER as the primary test runner

Primary CLI commands:
- Run all e2e: `npx playwright test`
- Run specific file: `npx playwright test tests/e2e/feature.spec.ts`
- Run with UI: `npx playwright test --ui`
- Debug mode: `npx playwright test --debug`
- Generate report: `npx playwright show-report`
- Update snapshots: `npx playwright test --update-snapshots`
```

### Validator: remove unnecessary MCP

**In `agents/claude/validator.md`**, remove `airis-mcp-gateway` from mcpServers:

```yaml
mcpServers: []
```

Update MCP graceful degradation section to simply:

```markdown
## No MCP dependencies
The validator uses only native read-only tools (Read, Glob, Grep, Bash) and linters/type-checkers via Bash.
No MCP server is needed for verification.
```

---

## 7. Validation gates — plan approval + manual testing

This is a critical behavioral change that affects the orchestrator, skills, and the /sdd command flow.

### Gate 1: Plan approval (after planner, before implementation)

**Modify `agents/claude/orchestrator.md`**, add to responsibilities:

```markdown
## PLAN APPROVAL GATE (never skip)

After the planner produces proposal.md, design.md, and tasks.md:

1. Present the plan summary to the developer:
   - Feature scope (from proposal.md)
   - Architecture decisions (from design.md)
   - Task breakdown with domain tags and dependencies (from tasks.md)
   - Estimated wave structure
   - Risk flags (if any tasks touch auth, payments, PII, infra)

2. Ask explicitly: "Do you approve this plan for implementation? (yes / revise / cancel)"

3. If "revise": ask what needs to change, re-invoke planner with feedback
4. If "cancel": stop the flow, archive as draft
5. If "yes": proceed to implementation waves

6. AUTOMATED CHECKS before proceeding (even after approval):
   - All tasks in tasks.md have a domain tag (frontend/backend/db/test)
   - All tasks have acceptance criteria
   - No circular dependencies in task graph
   - If any task touches auth/payments/PII: emit HIGH RISK warning
   - If API contracts span frontend + backend: verify contract stubs exist in design.md or as OpenAPI files

If automated checks fail, report findings and ask developer to confirm anyway or revise.

This gate is NON-NEGOTIABLE. Never proceed to implementation without explicit developer approval.
```

**Modify `skills/rojas-propose/SKILL.md`**, add after step 5 (Present to user):

```markdown
5.5. **Automated plan validation** — before presenting for approval, run these checks:
   - [ ] Every task in tasks.md has: domain tag, acceptance criteria, dependency list (even if empty)
   - [ ] No task references files outside its domain (cross-domain tasks must be split or marked as sequential)
   - [ ] If handoff.md is needed (multi-wave, cross-repo, high-risk): it exists or is flagged for creation
   - [ ] API contracts: if frontend tasks consume backend endpoints, the endpoint signatures are documented in design.md or as OpenAPI stubs
   - [ ] Test tasks exist for every implementation task (TDD enforcement)
   Report check results alongside the plan for developer review.
```

### Gate 2: Manual testing (after validator, before archive)

**Modify `agents/claude/orchestrator.md`**, add after validator invocation:

```markdown
## MANUAL TEST GATE (never skip)

After the validator agent completes its quality scorecard:

1. Present the validator's scorecard to the developer (Completeness, Correctness, Code quality, Test coverage, Standards compliance, Documentation — each scored 1-3, total /18)

2. Present a manual testing checklist derived from the spec's acceptance criteria:
   ```
   ╔═══════════════════════════════════════════════════╗
   ║         Manual Testing Required                   ║
   ╠═══════════════════════════════════════════════════╣
   ║ Please test the following before we archive:      ║
   ║                                                   ║
   ║ □ [acceptance criterion 1 from tasks.md]          ║
   ║ □ [acceptance criterion 2 from tasks.md]          ║
   ║ □ [acceptance criterion N from tasks.md]          ║
   ║                                                   ║
   ║ Run the app locally and verify each item.         ║
   ║ Report: all pass / issues found                   ║
   ╚═══════════════════════════════════════════════════╝
   ```

3. Wait for developer response:
   - "all pass" → proceed to archive (opsx:archive)
   - "issues found: [description]" → create fix tasks, dispatch to appropriate agent, re-run tester + validator after fix, return to this gate
   - Developer can also say "skip" for non-critical changes (Mode 4 bugfixes) — but log that manual testing was skipped in the archive record

4. If the validator scorecard has ANY BLOCKER severity issues: manual testing gate is BLOCKED until blockers are resolved. The developer cannot skip.

This gate ensures that automated verification is complemented by human verification of actual runtime behavior. Agents can verify code structure and tests — only a human can verify the product works as intended.
```

**Modify `skills/rojas-verify/SKILL.md`**, add after step 6 (Surface issues):

```markdown
7. **Handoff to manual testing** — after surfacing issues, always append:
   - A list of acceptance criteria from the original tasks.md that require manual verification
   - Specific instructions for what the developer should test manually (e.g., "Open the app, navigate to /tickets, create a new ticket, verify it appears in the list")
   - Any areas where automated tests could not cover the behavior (e.g., visual layout, UX flow, third-party integrations)
   
   This handoff is consumed by the orchestrator's MANUAL TEST GATE.
```

---

## 8. Backend agent — Postman collection sync

### Modify: `agents/claude/backend.md`

Add to the workflow, after step 7 (Run tests and verify passing), insert step 7.5:

```markdown
7.5. **Postman collection sync** — if the task created or modified API endpoints (controllers, routes, handlers):

   a. Check if a Postman collection exists in the project:
      - Look for: `*.postman_collection.json`, `postman/`, `docs/api/`, or a path referenced in project-stack
      - Also check for OpenAPI/Swagger files: `openapi.yaml`, `swagger.json`, `docs/api-spec.*`

   b. If a Postman collection EXISTS:
      - Read the existing collection file
      - For each new or modified endpoint:
        - Add/update the request entry with: method, URL, headers, body schema, description
        - Use the project's base URL variable (e.g., `{{base_url}}`)
        - Include example request body from the spec or implementation
        - Include expected response schema
        - Group by folder matching the route group/controller name
      - Write the updated collection back

   c. If NO Postman collection exists:
      - Create a new collection file at `postman/<project-name>.postman_collection.json`
      - Use Postman Collection v2.1 format
      - Include: collection info, base URL variable, all endpoints from this task
      - Organize endpoints into folders by route group/controller
      - Add to .gitignore exclusion check: if postman/ is gitignored, warn the developer

   d. Collection entry format for each endpoint:
      ```json
      {
        "name": "Create Ticket",
        "request": {
          "method": "POST",
          "header": [{"key": "Content-Type", "value": "application/json"}],
          "url": {
            "raw": "{{base_url}}/api/tickets",
            "host": ["{{base_url}}"],
            "path": ["api", "tickets"]
          },
          "body": {
            "mode": "raw",
            "raw": "{\"title\": \"Example\", \"description\": \"...\"}",
            "options": {"raw": {"language": "json"}}
          },
          "description": "Creates a new ticket. Requires authentication."
        },
        "response": []
      }
      ```

   e. Report to team-leader: "Postman collection updated: added/modified N endpoints in <collection-file>"
```

Add to the Rules section:

```markdown
- Always update the Postman collection when creating or modifying API endpoints — this is mandatory, not optional
- If the project uses OpenAPI/Swagger instead of Postman, update that file instead following the same principle
- Postman collection must use environment variables for base URL, auth tokens, and other environment-specific values
```

---

## 9. Frontend — GSAP skills integration

### Modify: `agents/claude/frontend.md`

Add to the workflow, in step 4 (check existing components):

```markdown
4. Check existing components/patterns before creating new ones (reuse-first)
   - If task involves animation, transitions, or scroll-driven behavior:
     a. Check if GSAP is in package.json dependencies
     b. If GSAP present: reference gsap-core + gsap-timeline skills for correct API usage
     c. If ScrollTrigger needed: reference gsap-scrolltrigger skill
     d. If React project with GSAP: use useGSAP hook (NOT raw useEffect + gsap.context)
     e. Performance: always prefer GSAP transform aliases (x, y, rotation, scale) over CSS properties
     f. Cleanup: always revert GSAP contexts on component unmount
   - If task involves animation but GSAP is NOT in package.json:
     a. Use CSS animations/transitions for simple cases
     b. If complex sequencing needed: suggest adding GSAP to the developer and wait for approval
```

### Modify: `profiles/frontend.md`

Add a new section:

```markdown
## Animation skills (GSAP)

When the frontend profile is active and `gsap` is detected in package.json, the following skills are available to the frontend and tester-front agents:

Install: `npx skills add https://github.com/greensock/gsap-skills`

Skills provided:
| Skill | When to use |
|-------|-------------|
| gsap-core | Any GSAP tween: gsap.to(), .from(), .fromTo(), easing, stagger |
| gsap-timeline | Sequencing animations, position parameter, labels, nesting |
| gsap-scrolltrigger | Scroll-linked animations, pinning, scrub, trigger/end markers |
| gsap-plugins | Flip, Draggable, SplitText, MotionPath, ScrollSmoother |
| gsap-react | useGSAP hook, refs, gsap.context(), cleanup, SSR safety |
| gsap-performance | Transforms over layout props, will-change, batching, ScrollTrigger refresh |
| gsap-frameworks | Vue/Svelte lifecycle, scoping, cleanup on unmount |
| gsap-utils | clamp, mapRange, normalize, snap, toArray, pipe |

These skills prevent the most common GSAP mistakes agents make:
- Using gsap.context() instead of useGSAP hook in React
- Forgetting ScrollTrigger.refresh() after DOM changes
- Animating layout properties (width, height, top, left) instead of transforms
- Missing cleanup on component unmount causing memory leaks
```

---

## 10. Agent memory fields

### Modify: `agents/claude/agent-prep.md`

Add to frontmatter:

```yaml
memory: project
```

### Modify: `agents/claude/researcher.md`

Add to frontmatter:

```yaml
memory: project
```

This gives both agents persistent directories (`~/.claude/agents/<name>/memory/`) that survive across sessions, building up codebase knowledge over time — complementing serena's session state persistence.

---

## 11. Recommended external skills per agent

### Modify: `agents/claude/agent-prep.md`

Add to the workflow, at the end (after step 8 — report findings):

```markdown
9. **Recommend external skills** based on detected stack:

   Always recommend:
   ```
   [DEVSTART] Recommended skills for your stack:
   ```

   If frontend detected:
   - `/plugin install frontend-design@claude-plugins-official` (production-grade UI design)
   - `npx skills add https://github.com/greensock/gsap-skills` (if gsap in package.json)

   If backend detected:
   - `/plugin install security-guidance@claude-plugins-official` (OWASP, secure coding)

   For all projects:
   - `/plugin install code-review@claude-plugins-official` (structured review for validator)
   - `/plugin install commit-commands@claude-plugins-official` (consistent git workflow for github-ops)

   These are Layer 4 (local) recommendations — they enhance individual developer experience but are never synced to repos.
```

---

## 12. Multi-repo architecture — Agent Teams (Option B)

### Principle

Developers work EXCLUSIVELY from the coordination repo. The orchestrator uses Claude Code Agent Teams to spawn teammates in separate worktrees per implementation repo. No manual repo switching.

### Modify: `agents/claude/orchestrator.md`

Add new section:

```markdown
## Multi-repo dispatch via Agent Teams

When preflight detects MULTI_REPO=true (repos: section in openspec/config.yaml):

1. Enable Agent Teams: verify CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 in settings
2. Read repo configuration from openspec/config.yaml:
   ```yaml
   repos:
     api:
       path: ../api
       branch_prefix: feat/
     frontend:
       path: ../frontend
       branch_prefix: feat/
   contracts_dir: openspec/contracts
   ```

3. After plan approval, dispatch teammates per repo:
   - "Create a teammate working in [repo.path] with the backend agent profile.
      Task: implement tasks tagged repo:api from openspec/changes/<n>/tasks.md.
      Use the shared task list in openspec/state/tasks-live.json for coordination."
   - "Create a teammate working in [repo.path] with the frontend agent profile.
      Task: implement tasks tagged repo:frontend.
      Blocked until: api contract tasks marked complete in shared task list."

4. Cross-repo dependency management:
   - Backend teammates complete API endpoint implementations first
   - Backend teammate writes/updates API contract files (OpenAPI or Postman) in openspec/contracts/
   - Frontend teammate unblocks when contract files are available
   - Team lead (orchestrator) monitors shared task list progress

5. Each teammate reads its own repo's AGENTS.md for repo-specific conventions
   Cross-repo specs always come from the coordination repo's openspec/

6. Implementation repos only support /sdd Mode 4 (bugfix) for local quick fixes
   All planning, research, and orchestrated implementation goes through this coordination repo
```

### Modify: `agents/claude/planner.md`

Add new section:

```markdown
## Cross-repo planning

When project-stack lists multiple repos (multi-repo mode):

1. Every task in tasks.md MUST include a `repo:` field:
   ```markdown
   - [ ] [repo:api] Create POST /api/tickets endpoint — acceptance: returns 201 with ticket ID
   - [ ] [repo:api] Create GET /api/tickets endpoint — acceptance: returns paginated list
   - [ ] [repo:frontend] Create TicketList component — acceptance: renders tickets from API
   - [ ] [repo:frontend] Create CreateTicketForm component — acceptance: submits to POST endpoint
   ```

2. Generate API contract stubs for any cross-repo interface:
   - Place in openspec/contracts/<api-name>.yaml (OpenAPI format)
   - Backend tasks reference: "implement to match contract"
   - Frontend tasks reference: "consume per contract"

3. Cross-repo dependency rules:
   - Backend API tasks ALWAYS come before frontend consumption tasks
   - Database migration tasks ALWAYS come before backend tasks that use new schema
   - Frontend tasks that consume backend APIs are automatically blocked until the API contract is committed
   - Mark dependencies explicitly: `depends_on: [repo:api] Create POST /api/tickets`

4. Wave structure for multi-repo:
   - Wave 1: database migrations (if any)
   - Wave 2: backend API endpoints + contract generation + Postman collection
   - Wave 3: frontend components consuming APIs
   - Wave 4: testers (per repo, parallel)
   - Wave 5: github-ops (per repo, parallel PRs)
   - Wave 6: validator (cross-repo verification)
```

### Modify: `openspec/config.yaml` template (templates/openspec/config.yaml)

Add optional repos section:

```yaml
# Multi-repo configuration (optional — omit for monorepo/standalone projects)
# repos:
#   api:
#     path: ../api              # relative path from coordination repo
#     branch_prefix: feat/      # git branch naming
#   frontend:
#     path: ../frontend
#     branch_prefix: feat/
# contracts_dir: openspec/contracts
```

### Create template: `.claude/settings.json`

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

This goes in `templates/settings/claude-settings.json` and is copied to coordination repos only.

---

## 13. Installer changes — repo_role filtering

### Modify: `action.yml`

Add new input:

```yaml
  repo_role:
    description: 'Role of this repo: standalone (all agents), coordination (orchestration only), frontend (frontend agents only), backend (backend agents only)'
    default: 'standalone'
```

### Create: `installer/install-agents.sh`

```bash
#!/bin/bash
# Install SDD Dev Suite agents filtered by repo role
set -euo pipefail

ROLE="${1:-standalone}"
SOURCE_DIR="${2:-.claude/agents}"
TARGET_DIR="${3:-.claude/agents}"
DRY_RUN="${4:-false}"
VERSION="${5:-1.0.0}"

# Define agent sets per role
case "$ROLE" in
  coordination)
    AGENTS="orchestrator planner researcher team-leader validator agent-prep agent-sync devstart"
    ;;
  frontend)
    AGENTS="frontend tester-front github-ops"
    ;;
  backend)
    AGENTS="backend database tester-back github-ops"
    ;;
  standalone|*)
    AGENTS="orchestrator planner researcher team-leader frontend backend database validator github-ops devstart tester-back tester-front agent-sync agent-prep"
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
case "$ROLE" in
  coordination)
    CLAUDE_NOTE="This is the SDD orchestration hub. Run /sdd here to start any workflow."
    ;;
  frontend)
    CLAUDE_NOTE="Frontend implementation repo. Orchestrated from the coordination repo. For local fixes only: /sdd mode 4."
    ;;
  backend)
    CLAUDE_NOTE="Backend implementation repo. Orchestrated from the coordination repo. For local fixes only: /sdd mode 4."
    ;;
esac

if [ -n "${CLAUDE_NOTE:-}" ] && [ "$DRY_RUN" != "true" ]; then
  echo ""
  echo "Repo role: $ROLE"
  echo "CLAUDE.md note: $CLAUDE_NOTE"
fi

echo "Agent installation complete for role: $ROLE ($AGENTS)"
```

### Wire into `action.yml`

Add a new step after "Init .claude directory":

```yaml
    - name: Install or update agents
      if: inputs.agent_suite == 'true'
      shell: bash
      run: |
        bash ${{ github.action_path }}/installer/install-agents.sh \
          "${{ inputs.repo_role }}" \
          "${{ github.action_path }}/agents/claude" \
          ".claude/agents" \
          "${{ inputs.dry_run }}" \
          "${{ inputs.agent_suite_version }}"
```

---

## 14. Observability — hooks-based tracing

### Create: `templates/settings/hooks.json`

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "command": "echo \"[TRACE] $(date -Iseconds) BLOCKED Write/Edit on validator\" && exit 1",
        "description": "Block Write/Edit on validator agent (read-only enforcement)",
        "agent": "validator"
      }
    ],
    "PostToolUse": [
      {
        "command": "echo \"[TRACE] $(date -Iseconds) tool=$TOOL_NAME\" >> .claude/state/agent-trace.log",
        "description": "Log every tool call for session observability"
      }
    ],
    "Stop": [
      {
        "command": "bash scripts/sdd-session-report.sh 2>/dev/null || true",
        "description": "Generate agent invocation summary at session end"
      }
    ]
  }
}
```

### Create: `scripts/sdd-session-report.sh`

```bash
#!/bin/bash
# Generate session summary from trace log
TRACE_LOG=".claude/state/agent-trace.log"

if [ ! -f "$TRACE_LOG" ]; then
  echo "No trace log found — session had no tool calls"
  exit 0
fi

echo ""
echo "═══════════════════════════════════════"
echo "  SDD Session Report"
echo "═══════════════════════════════════════"
echo ""
echo "Tool calls: $(wc -l < "$TRACE_LOG")"
echo ""
echo "Tools used:"
grep -oP 'tool=\K\S+' "$TRACE_LOG" | sort | uniq -c | sort -rn | head -20
echo ""
echo "Timeline (first 10 / last 5):"
head -10 "$TRACE_LOG"
echo "..."
tail -5 "$TRACE_LOG"
echo ""
echo "═══════════════════════════════════════"

# Clean up for next session
mv "$TRACE_LOG" "$TRACE_LOG.$(date +%Y%m%d%H%M%S).bak" 2>/dev/null || true
```

Make executable: `chmod +x scripts/sdd-session-report.sh`

---

## 15. File change matrix

| # | File | Type | Priority | Description |
|---|---|---|---|---|
| 1 | `.claude/commands/sdd.md` | **CREATE** | P0 | 5-mode entrypoint with gates |
| 2 | `scripts/sdd-preflight.sh` | **CREATE** | P0 | Deterministic env validation |
| 3 | `agents/claude/orchestrator.md` | MODIFY | P0 | disallowedTools, /sdd mandatory, plan gate, manual test gate, Agent Teams dispatch |
| 4 | `agents/claude/team-leader.md` | MODIFY | P0 | disallowedTools, repo-aware dispatch |
| 5 | `agents/claude/database.md` | REWRITE | P0 | Full DB-agnostic rewrite, CLI-first, detection workflow |
| 6 | `agents/claude/frontend.md` | MODIFY | P0 | model→sonnet, dynamic domain, GSAP, playwright CLI-first |
| 7 | `agents/claude/backend.md` | MODIFY | P1 | Dynamic domain, Postman collection sync step |
| 8 | `agents/claude/tester-front.md` | MODIFY | P1 | Dynamic domain, playwright CLI-first |
| 9 | `agents/claude/tester-back.md` | MODIFY | P1 | Dynamic domain |
| 10 | `agents/claude/agent-prep.md` | MODIFY | P1 | Domain map generation, memory field, DB detection, skill recommendations |
| 11 | `agents/claude/researcher.md` | MODIFY | P1 | memory field, tavily→WebSearch, mindbase→file |
| 12 | `agents/claude/validator.md` | MODIFY | P1 | Remove airis MCP, empty mcpServers, manual test handoff |
| 13 | `agents/claude/planner.md` | MODIFY | P1 | Cross-repo planning, contract generation, plan validation checks |
| 14 | `agents/claude/agent-sync.md` | MODIFY | P2 | Multi-repo state sync |
| 15 | `agents/claude/github-ops.md` | MODIFY | P2 | Dynamic domain (minor) |
| 16 | `skills/rojas-explore/SKILL.md` | MODIFY | P2 | tavily→WebSearch, mindbase→file |
| 17 | `skills/rojas-research/SKILL.md` | MODIFY | P2 | Same + version bump to 1.1.0 |
| 18 | `skills/rojas-implement/SKILL.md` | MODIFY | P2 | airis-agent→airis-exec, GSAP profile, Postman note |
| 19 | `skills/rojas-verify/SKILL.md` | MODIFY | P2 | Manual test handoff section |
| 20 | `skills/rojas-orchestrate/SKILL.md` | MODIFY | P2 | Agent Teams multi-repo, plan gate checkpoint |
| 21 | `skills/rojas-propose/SKILL.md` | MODIFY | P2 | Automated plan validation checks |
| 22 | `installer/install-agents.sh` | **CREATE** | P1 | Role-filtered agent installation |
| 23 | `action.yml` | MODIFY | P1 | Add repo_role input, wire install-agents.sh |
| 24 | `profiles/frontend.md` | MODIFY | P2 | GSAP skills section |
| 25 | `templates/openspec/config.yaml` | MODIFY | P2 | Add optional repos section |
| 26 | `templates/settings/claude-settings.json` | **CREATE** | P2 | Agent Teams env var |
| 27 | `templates/settings/hooks.json` | **CREATE** | P2 | Observability hooks + validator Write/Edit block |
| 28 | `scripts/sdd-session-report.sh` | **CREATE** | P2 | Session summary generator |

**Totals:** 28 changes — 22 modifications, 6 new files. Zero new agents.

---

## Implementation order for Claude Code

Execute in this exact sequence:

```
Wave 1 (P0 — entrypoint + restrictions):
  1. Create scripts/sdd-preflight.sh
  2. Create .claude/commands/sdd.md
  3. Modify orchestrator.md (tools, gates, Agent Teams)
  4. Modify team-leader.md (tools)
  5. Rewrite database.md (full DB-agnostic)
  6. Modify frontend.md (model, domain, GSAP, playwright)

Wave 2 (P1 — agent refactors):
  7. Modify backend.md (domain, Postman sync)
  8. Modify tester-front.md (domain, playwright)
  9. Modify tester-back.md (domain)
  10. Modify agent-prep.md (domain map, memory, detection, skills)
  11. Modify researcher.md (memory, MCP fixes)
  12. Modify validator.md (remove MCP, manual test handoff)
  13. Modify planner.md (cross-repo, validation, contracts)
  14. Create installer/install-agents.sh
  15. Modify action.yml (repo_role)

Wave 3 (P2 — skills + templates + observability):
  16-21. Modify all 6 skills (MCP references, gates, GSAP)
  22. Modify profiles/frontend.md (GSAP)
  23. Modify templates/openspec/config.yaml (repos)
  24. Create templates/settings/claude-settings.json
  25. Create templates/settings/hooks.json
  26. Create scripts/sdd-session-report.sh
  27. Modify agent-sync.md (multi-repo)
  28. Modify github-ops.md (domain)

Post-implementation:
  - Run dry-run sync on a test repo to verify installer
  - Test /sdd command flow end-to-end
  - Verify validator cannot write (hook blocks it)
  - Test multi-repo detection in preflight
```

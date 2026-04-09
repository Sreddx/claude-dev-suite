# SDD Dev Suite — Claude Code Agent Team

14 Claude Code agents that execute the SDD cycle as coordinated specialists.

---

## Architecture

```
                       ┌─────────┐
                       │  USER   │
                       └────┬────┘
                            │  /sdd
                   ┌────────┴────────┐
                   │  ORCHESTRATOR   │  opus — read-only coordinator
                   │                 │  MCP: airis-mcp-gateway, serena
                   └──┬───┬───┬─────┘
          ┌───────────┤   │   ├───────────────┐
          │           │   │   │               │
   ┌──────┴──────┐  ┌─┴───┴──┐  ┌──────┐  ┌──┴───────┐
   │  PLANNER    │  │  TEAM  │  │VALID-│  │ Support  │
   │  opus       │  │ LEADER │  │ ATOR │  │ Agents   │
   │  propose    │  │ opus   │  │sonnet│  │          │
   └──────┬──────┘  └───┬────┘  └──────┘  │researcher│
          │        ┌────┼────┐             │devstart  │
   ┌──────┴──────┐ │    │    │             │agent-sync│
   │ RESEARCHER  │ │    │    │             │agent-prep│
   │ opus        │ │    │    │             └──────────┘
   └─────────────┘ │    │    │
                   │    │    │
            ┌──────┘    │    └──────┐
            │           │           │
      ┌─────┴────┐ ┌────┴───┐ ┌────┴─────┐
      │ FRONTEND │ │BACKEND │ │ DATABASE │
      │ sonnet   │ │sonnet  │ │ sonnet   │
      │ context7 │ │context7│ │ CLI-only │
      └─────┬────┘ └────┬───┘ └──────────┘
            │            │
      ┌─────┴────┐ ┌─────┴────┐ ┌──────────┐
      │TESTER-   │ │TESTER-   │ │GITHUB-OPS│
      │FRONT     │ │BACK      │ │  haiku   │
      │ haiku    │ │ haiku    │ └──────────┘
      └──────────┘ └──────────┘
```

---

## Agent Roster

| Agent | Model | Reports to | MCP | Role |
|-------|-------|------------|-----|------|
| orchestrator | opus | user | airis-mcp-gateway, serena | Full cycle coordination, gates |
| researcher | opus | orchestrator | airis-mcp-gateway, context7 | Multi-hop research |
| planner | opus | orchestrator | airis-mcp-gateway, context7, serena | Spec decomposition |
| team-leader | opus | orchestrator | serena | Wave dispatch (no write access) |
| frontend | sonnet | team-leader | context7 | UI + GSAP + Playwright CLI |
| backend | sonnet | team-leader | context7 | APIs + Postman collection sync |
| database | sonnet | team-leader | — | 11-ORM detection, CLI-first migrations |
| validator | sonnet | orchestrator | — | Read-only quality gate, /18 scorecard |
| github-ops | haiku | team-leader | — | Branches, PRs, CI monitoring |
| devstart | sonnet | orchestrator | context7 | Env bootstrap, MCP probe |
| tester-front | haiku | team-leader | context7 | e2e (Playwright CLI) + component tests |
| tester-back | haiku | team-leader | context7 | API + integration tests |
| agent-sync | sonnet | orchestrator | serena | AGENTS.md state, multi-repo task list |
| agent-prep | sonnet | orchestrator | airis-mcp-gateway, context7, serena | Codebase scan, domain map, project-stack |

**orchestrator and team-leader have `disallowedTools: [Write, Edit]`** — they coordinate but never touch code directly.

---

## Starting a session — `/sdd`

Every session starts with `/sdd`. It runs `scripts/sdd-preflight.sh` and shows:

```
╔═══════════════════════════════════════════════════╗
║            SDD Dev Suite — Ready                  ║
╠═══════════════════════════════════════════════════╣
║ ✓  airis-mcp-gateway   Tool discovery             ║
║ ✓  figma               Design context             ║
║ ✓  context7            Library docs               ║
║ ✓  playwright (CLI)    Using npx directly         ║
║ ✗  serena              Session persistence        ║
╠═══════════════════════════════════════════════════╣
║ serena DOWN: state saved to .claude/state/ only   ║
╚═══════════════════════════════════════════════════╝

What do you want to do?
  1 — Plan and implement a new feature
  2 — Implement from existing plan
  3 — Research / explore
  4 — Bugfix
  5 — Bootstrap this project
```

If bootstrap is missing (no `project-stack` section in AGENTS.md), the orchestrator determines whether this is greenfield or brownfield:
- **Greenfield** (no source code directories): invokes `rojas:kickstart` → 📥 PRD/backlog intake before any work
- **Brownfield** (existing code but no project-stack): runs `agent-prep` (Mode 5) automatically

---

## Bootstrap (Mode 5)

Run once per project. The bootstrap path depends on whether the project is greenfield or brownfield.

### Greenfield detection

If `project-stack` section is absent from AGENTS.md AND no source code directories exist → **GREENFIELD**. Otherwise → **BROWNFIELD**.

### Greenfield bootstrap

The orchestrator invokes `rojas:kickstart` and outputs the 📥 PRD/backlog intake request. No specs, tasks, or agent-prep output until the user provides input or explicitly says "proceed without PRD."

```
1. Orchestrator detects greenfield → outputs 📥 intake request
2. User provides PRD and/or backlog
3. Orchestrator parses input → outputs structured summary
4. Orchestrator asks ❓ clarifying questions (if any)
5. Orchestrator proposes openspec decomposition → 📋 approval gate
6. Orchestrator proposes implementation waves → 📋 approval gate
7. agent-prep bootstraps AGENTS.md and project-stack
8. Implementation begins wave by wave with approval gates
```

### Brownfield bootstrap

`agent-prep` runs immediately (no PRD required):

1. Scan the codebase — detect tech stack, architecture, ORM, test framework
2. Generate a **domain map** — maps directories to agents:
   ```
   frontend_paths:  src/components/**, src/pages/**
   backend_paths:   src/api/**, src/services/**
   database_paths:  prisma/**, migrations/**
   test_*_paths:    tests/**, __tests__/**
   ```
3. Write `<!-- rojas:section:project-stack -->` to AGENTS.md
4. Recommend external skills for the detected stack

After bootstrap, all agents read the domain map from AGENTS.md to know which files are theirs.

---

## Mono-repo flow (Mode 1)

```
/sdd → Mode 1
  │
  ├─ researcher     → openspec/changes/<n>/research.md
  ├─ planner        → proposal.md + design.md + tasks.md
  │
  │  ┌─────────────────────────┐
  │  │  📋 PLAN APPROVAL GATE  │  developer reviews and approves spec
  │  └─────────────────────────┘
  │     ❓ clarification questions may be asked at any point
  │
  ├─ team-leader dispatches:
  │    Wave 1  frontend + backend + database  (parallel, domain-isolated)
  │    Wave 2  tester-front + tester-back     (parallel)
  │    Wave 3  github-ops                     (PRs per domain)
  │
  ├─ agent-sync    → updates AGENTS.md, task state
  ├─ validator     → quality scorecard /18 + manual test handoff
  │
  │  ┌─────────────────────────┐
  │  │  ✅ MANUAL TEST GATE    │  developer verifies acceptance criteria in running app
  │  └─────────────────────────┘
  │
  └─ opsx:archive
```

### User interaction gates

The workflow pauses for human input at four key moments:

| Gate | Emoji | When | Agent |
|------|-------|------|-------|
| Greenfield intake | 📥 | Start of a new greenfield project | orchestrator |
| Plan/artifact approval | 📋 | After any spec, proposal, or tasks.md is written | planner / orchestrator |
| Clarification | ❓ | When any agent encounters ambiguity | any agent |
| Manual test validation | ✅ | After validator issues a PASS | validator / orchestrator |

All gates use standardized message formats defined in `schemas/approval-gates.md` and are non-skippable (except greenfield intake, which can be bypassed with "proceed without PRD"). Task format is defined in `schemas/task-format.md`. Spec frontmatter is defined in `schemas/spec-frontmatter.md`.

### Automated plan checks (before approval)

Before presenting the plan, `rojas:propose` validates:
- Every task has a domain tag + acceptance criteria
- No cross-domain file references without sequential markers
- API contracts documented if frontend consumes backend endpoints
- Test task exists for every implementation task

### Quality scorecard

```
Completeness:         _/3
Correctness:          _/3
Code quality:         _/3
Test coverage:        _/3
Standards compliance: _/3
Documentation:        _/3
Total:               _/18   (threshold: 12/18 to pass)
```

BLOCKER issues prevent the manual test gate from being skipped.

### Manual test handoff format

After the validator passes, it outputs a structured ✅ checklist including:
- What was implemented (1–3 sentence summary)
- Manual test checklist (at least 3 specific items)
- Where to look (actual files/paths and entry points)
- Known limitations / not tested

The developer must reply ✅ to confirm or report issues before the cycle can close.

---

## Multi-repo flow

For architectures with separate repos (e.g., `api` + `frontend`), work originates in one coordination repo.

### Setup

1. Sync roles:
   ```bash
   # Hub — gets orchestration agents only
   gh workflow run sdd-sync-targeted.yml -f repos="my-hub" -f repo_role="coordination"

   # Implementation repos — get only their domain agents
   gh workflow run sdd-sync-targeted.yml -f repos="my-api" -f repo_role="backend"
   gh workflow run sdd-sync-targeted.yml -f repos="my-ui" -f repo_role="frontend"
   ```

2. Enable Agent Teams in the coordination repo:
   ```bash
   cp templates/settings/claude-settings.json .claude/settings.json
   ```

3. Configure `openspec/config.yaml` in the coordination repo:
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

### How coordination works

All planning, research, and orchestration happens in the **coordination repo**. The orchestrator dispatches Agent Teams teammates into each implementation repo.

```
Coordination repo (/sdd Mode 1)
  │
  ├─ researcher + planner  (run here, produce tasks.md with repo: tags)
  │
  │  PLAN APPROVAL GATE
  │
  ├─ orchestrator reads MULTI_REPO=true from preflight
  │
  ├─ Dispatch teammate → my-api  (backend agent)
  │    implements [repo:api] tasks
  │    writes contracts to openspec/contracts/
  │    updates openspec/state/tasks-live.json
  │
  ├─ Dispatch teammate → my-ui  (frontend agent)
  │    blocks until contracts_ready in tasks-live.json
  │    implements [repo:frontend] tasks consuming contracts
  │
  ├─ testers run per repo (parallel)
  ├─ github-ops opens PRs per repo
  └─ validator runs cross-repo verification
```

### Task format in multi-repo mode

```markdown
- [ ] [repo:api] POST /api/tickets — acceptance: returns 201 with ticket ID
- [ ] [repo:api] GET /api/tickets — acceptance: returns paginated list
- [ ] [repo:frontend] TicketList component — acceptance: renders from API
  depends_on: [repo:api] POST /api/tickets
```

### Wave structure (multi-repo)

| Wave | Work |
|------|------|
| 1 | Database migrations |
| 2 | Backend endpoints + Postman collection + OpenAPI contracts |
| 3 | Frontend components consuming contracts |
| 4 | Testers (per repo, parallel) |
| 5 | github-ops (per repo, parallel PRs) |
| 6 | Validator (cross-repo) |

Implementation repos only support `/sdd Mode 4` (bugfix) locally. All planned work goes through the coordination repo.

---

## MCP fallbacks

No MCP is required. Every agent falls back gracefully:

| MCP | Fallback |
|-----|---------|
| airis-mcp-gateway | Native Grep/Glob/WebSearch |
| context7 | WebSearch + package.json versions; API calls marked `needs-verification` |
| serena | File-based state in `.claude/state/`; tasks tracked in `tasks.md` |
| figma | Skip design context; more manual design-to-code iterations |

**Playwright** is CLI-first always — `npx playwright test`. It is never a runtime dependency via MCP.

**Database** has no MCP. It detects the ORM from the project files and uses CLI tools directly.

---

## Observability

Copy `templates/settings/hooks.json` into `.claude/settings.json` to activate:

- **Trace log** — every tool call appended to `.claude/state/agent-trace.log`
- **Validator write block** — PreToolUse hook that exits 1 if validator tries Write or Edit
- **Session report** — `scripts/sdd-session-report.sh` runs at stop, prints tool usage summary, rotates log

---

## Customization

Agents are fully customizable after install. The sync never overwrites a file that lacks the SDD version marker.

**Override domain paths** (e.g., your backend lives in `server/` not `src/api/`):
```yaml
## Domain
server/**, src/services/**
```

**Add project-specific rules** to any agent:
```markdown
## Project-specific rules
- All API responses use { data, error, meta } envelope
- Auth via Clerk — docs at clerk.com/docs
- Database is Drizzle + PostgreSQL only
```

**Add a custom agent**: Create `.claude/agents/my-agent.md` without a version marker — it will never be touched by sync.

---

## Quick reference

| I want to… | Do this |
|------------|---------|
| Start a new greenfield project | `/sdd` → orchestrator detects greenfield → 📥 PRD/backlog intake |
| Start a new feature | `/sdd` → Mode 1 |
| Execute an existing spec | `/sdd` → Mode 2, provide path to `tasks.md` |
| Research something | `/sdd` → Mode 3 |
| Fix a bug | `/sdd` → Mode 4 |
| Set up a brownfield project | `/sdd` → Mode 5 (or auto-detected) |
| Resume after session break | `/sdd` → orchestrator reads `progress.md` + `tasks.md`, reports wave status, continues |
| Check environment | Ask orchestrator to run `devstart` |
| Override domain for an agent | Edit `## Domain` section in `.claude/agents/<agent>.md` |

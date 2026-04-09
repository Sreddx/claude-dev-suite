# Repo Topologies

This document explains how the Rojas SDD workflow should adapt to different repository topologies.

## Why topology matters

The same feature workflow behaves differently depending on whether you are working in:
- a greenfield single repo
- a brownfield repo
- a monorepo
- split frontend/backend repos

Topology changes how you explore, propose, partition tasks, and verify work.

## Agent sets by topology

Setting `repo_type` in the GitHub Action auto-selects both the profile overlay and the agent set installed into the repo.

| `repo_type` | Profiles applied | Agents installed |
|---|---|---|
| `coordination` | baseline only | **All 14** — hub delegates to sub-repos; needs full agent awareness |
| `monorepo` | frontend + backend-api | **All 14** — orchestrates all domains internally |
| `frontend` | frontend | orchestrator + planner + researcher + frontend + tester-front + github-ops + validator |
| `backend` | backend-api | orchestrator + planner + researcher + backend + database + tester-back + github-ops + validator |
| `brownfield-frontend` | frontend + brownfield | orchestrator + planner + researcher + frontend + tester-front + github-ops + validator |
| `brownfield-backend` | backend-api + brownfield | orchestrator + planner + researcher + backend + database + tester-back + github-ops + validator |
| `standalone` (default) | baseline only | **All 14** |

### Why orchestrator is always included in frontend/backend repos

Even a single-purpose repo needs a local orchestrator to:
- Receive delegation from the coordination hub without context switching
- Run standalone `/sdd` workflows for isolated fixes (mode 4)
- Coordinate local waves when planner and implementation agents run in the same repo

### Why team-leader, agent-prep, agent-sync, and devstart are excluded from frontend/backend repos

These agents are infrastructure-layer concerns that live in the coordination hub or monorepo:
- `team-leader` — cross-domain wave coordination; redundant when only one domain is present
- `agent-prep` — project memory bootstrapping; done once at the coordination level
- `agent-sync` — cross-agent state consistency; not needed for a single-domain repo
- `devstart` — environment bootstrapping; handled by the hub during onboarding

## 1. Greenfield single repo

### Characteristics
- Minimal legacy constraints
- Few or no existing architectural boundaries
- Specs can shape the project from day one

### SDD guidance
- The orchestrator detects greenfield (no project-stack AND no source code directories) and invokes `rojas:kickstart`.
- The 📥 PRD/backlog intake gate fires first — no specs, tasks, or agent-prep output until the user provides a PRD and/or backlog (or explicitly says "proceed without PRD").
- After intake, the orchestrator parses the input, asks ❓ clarifying questions, and proposes an openspec decomposition + wave plan for 📋 approval before creating any files.
- Keep `AGENTS.md` short but authoritative.
- Create architectural ADRs early for foundational choices.
- Use specs to establish module boundaries before implementation starts.
- Favor a lightweight handoff artifact when the change introduces cross-cutting foundations.

### Main risk
- Overdesigning too early or writing giant specs before enough is known.

## 2. Brownfield repo

### Characteristics
- Existing code and conventions already constrain the change
- Historical quirks matter
- Verification must protect against regressions

### SDD guidance
- The PRD/backlog intake gate (📥) is **skipped** for brownfield repos. The existing codebase is the context.
- Always start with `rojas:explore` to establish project memory — this serves as the planning input source instead of a PRD.
- `agent-prep` runs first (before any planning) to scan the codebase and generate project-stack.
- Capture existing boundaries, conventions, and exceptions before proposing.
- Treat the proposal as a change against a known baseline, not a greenfield redesign.
- Prefer handoff artifacts for changes that touch legacy integration points.

### Main risk
- Proposal ignores reality of the current codebase and causes rework during implementation.

## 3. Monorepo

### Characteristics
- Multiple packages/apps/services live together
- A change may touch one package or several
- Validation often needs both local and cross-package checks

### SDD guidance
- Explore phase should identify package boundaries and owners.
- Proposal should explicitly state which packages are in scope.
- Tasks should be partitioned by package or boundary.
- Verify should distinguish package-local success from system-level integration success.
- Use a handoff artifact whenever implementation spans multiple packages or waves.

### Main risk
- Context bloat and hidden cross-package drift.

## 4. Split frontend/backend repos

### Characteristics
- UI and API evolve in different repos
- Contracts can drift
- One side may be blocked by the other

### SDD guidance
- Proposal should name the upstream/downstream contract explicitly.
- Use linked specs or a shared contract reference where possible.
- Separate local verification from cross-repo dependency risk.
- Use a handoff artifact whenever one repo depends on approved work landing in another.

### Main risk
- The feature is locally correct in one repo but misaligned at the interface boundary.

## Recommended use of handoff artifacts by topology

| Topology | Handoff recommendation |
|---|---|
| Greenfield single repo | Optional for simple changes; recommended for foundational work |
| Brownfield repo | Recommended |
| Monorepo | Recommended; strongly preferred for cross-package work |
| Split frontend/backend repos | Strongly recommended |

## Design rule

Do not inflate the baseline with topology-specific behavior for every repo.
Prefer:
- a small universal baseline
- topology playbooks like this document
- optional overlays or templates when the topology meaningfully changes execution

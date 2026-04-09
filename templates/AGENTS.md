# Rojas Development Standards

This project follows Rojas's Spec-Driven Development (SDD) cycle.

<!-- rojas:section:sdd-workflow:1.2.0 -->
## SDD Workflow

We follow a spec-first, change-first approach. **Never write code without an active named change and its complete planning artifacts.**

### Interface rule
- Humans should use `rojas:*` as the default interface
- `opsx:*` remains the underlying engine
- Direct `opsx:*` usage is an expert exception, not the standard team-facing path

### Cycle
1. `rojas:explore` — investigate the problem space with live docs and research
2. `rojas:research` — deep dive into unknowns, persist findings
3. `rojas:propose` — create spec scaffold and close with implementation handoff guidance
4. `rojas:implement` — build step by step with isolation-first execution (wraps `opsx:apply`)
5. `rojas:verify` — check completeness with isolated reviewer (wraps `opsx:verify`)
6. `opsx:archive` — close the change

### Orchestration
Use `rojas:orchestrate` to automatically analyze `tasks.md` dependencies and dispatch parallel sub-agents for independent tasks.

### Change folder contract
Every active change must have a named folder at `openspec/changes/<change-name>/` containing:
- `proposal.md` — what and why (required)
- `design.md` — architecture decisions (required)
- `tasks.md` — implementation checklist with full per-task metadata (required)
- `research.md` — exploration findings (recommended)
- `handoff.md` — compact execution bridge for multi-wave or high-risk changes (required when applicable)

No implementation may begin until all three required artifacts exist and the change name passes validation.

### Change naming rules
- Format: `verb-scope-outcome` in kebab-case
- Must be derived from the feature or PRD scope
- **Numeric IDs are prohibited** — `1`, `change-1`, `update`, `misc`, and any pure number are all invalid
- Good: `bootstrap-client-portal-mvp`, `add-notification-service`, `harden-auth-session-expiry`
- Bad: `1`, `change-1`, `update`, `misc`
- Derive from PRD scope during `rojas:kickstart` or `rojas:propose`; get user approval before creating the folder

### Required task format (opsx-compatible + rojas-enriched)
`opsx:apply` toggles checkboxes on the top-level `- [ ] N.N` line. `opsx:verify` reads completion
state from those same lines. Do not replace them — add rojas metadata as indented sub-bullets beneath
each checkbox so the rojas orchestration layer can read wave, profile, and dependency without
breaking the opsx contract.

```markdown
## Wave 0 — Foundation

- [ ] 0.1 Task title here
  - **Change:** <change-name>
  - **Spec:** `openspec/changes/<change-name>/specs/<capability>.md`
  - **Spec wave slice:** <`## Wave N — [scope]` section name, or `n/a`>
  - **Stories:** <US-XXX-YY, ...>
  - **Owner profile:** <frontend | backend | database | fullstack>
  - **Dependencies:** <N.N, N.M | none>
  - **Definition of done:** <what must be true for this task to be complete>
  - **Verification gate:** <test command, Playwright check, manual step, or opsx:verify assertion>
```

Note: delta specs live at `openspec/changes/<change-name>/specs/` during active work.
`opsx:archive` merges them into `openspec/specs/` (main source of truth) on completion.

### Multi-wave spec rule
Any spec file implemented across more than one wave must contain explicit `## Wave N — [scope]` sections.
Tasks must reference the specific wave slice (`Spec wave slice` field), not the whole spec file.

### Rules
- No code before a spec exists
- **No coding without an active named change folder** — `proposal.md`, `design.md`, and `tasks.md` must all be present before any implementation starts
- All implementation uses TDD
- Verify before archive — always
- Commits reference `<change-name>` (never a number)
- **Brownfield repos**: always run `rojas:explore` first to generate project memory via serena; if skipped, downstream phases must offer minimal-memory initialization rather than proceeding silently
- **Isolation first**: if a task can be partitioned usefully, use a sub-agent or logical isolation before deciding on tool-specific accelerators
- **Frontend tasks**: use Playwright and Magic when available, otherwise follow the same testing intent with runtime-available tools
- **General tasks**: use Morphllm when available, otherwise preserve the same TDD and context-budgeting discipline
- **Reporting**: every sub-agent creation and skill invocation must be reported explicitly to the user
- **Checkpoints**: make planning-approved, wave/task, pre-verify, and post-verify checkpoints visible
<!-- /rojas:section:sdd-workflow -->

<!-- rojas:section:skills:1.1.0 -->
## Skills (Layer 2 — Rojas)

These skills wrap OpenSpec commands with sub-agent orchestration and MCP integration:

| Skill | Wraps | MCP Dependencies | Purpose |
|---|---|---|---|
| `rojas:explore` | `opsx:explore` | context7, tavily, serena | Enriched exploration + brownfield project memory |
| `rojas:research` | *(standalone)* | tavily, context7, mindbase, serena | Deep research with persistence |
| `rojas:propose` | `opsx:new`, `opsx:ff` | context7 | Spec creation with API validation |
| `rojas:implement` | `opsx:apply` | airis-agent, context7, playwright, magic, morphllm | Parallel sub-agents + profile-based tooling |
| `rojas:verify` | `opsx:verify` | mindbase | Isolated verification agent |
| `rojas:orchestrate` | *(meta)* | airis-agent, serena | Task dependency analysis + parallel dispatch |
| `rojas:kickstart` | `rojas:explore`, `rojas:propose` | — | Greenfield project bootstrap: PRD/backlog intake → spec decomposition → wave planning |

Layer 1 (`/opsx:*`) commands remain available and unmodified.
<!-- /rojas:section:skills -->

<!-- rojas:section:mcp-integration:1.1.0 -->
## MCP Integration

### Core Infrastructure
- **AIRIS Gateway** — 60+ tools via Dynamic MCP (3 meta-tools). Use `airis-find` to discover, `airis-exec` to run. Servers auto-enable on first use from the full catalog.
- **context7** — up-to-date library docs. Use `resolve-library-id` then `query-docs`.
- **mindbase** — knowledge graph for persisting research findings across sessions.
- **serena** — session state persistence for resuming interrupted work and brownfield project memory.
- **tavily** — deep web search with summarization for research phases.

### Implementation Tools
- **Playwright** — browser-based testing for frontend implementations. Navigate, snapshot, click, fill forms, evaluate JS. Every frontend task requires Playwright verification.
- **Magic** (`@21st-dev/magic-mcp`) — AI-powered UI component generation from natural language. Writes only component-related files, respects project code style.
- **Morphllm** (`@morph-llm/morph-mcp`) — FastApply for 10x faster file edits (`edit_file`) + WarpGrep for context-clean code search (`warpgrep_codebase_search`). Use for general implementation tasks.

### Context Optimization
- Use AIRIS Dynamic MCP (3 meta-tools) instead of loading all 60+ tools
- Each sub-agent should receive only its task's relevant specs and files
- Query context7 only when the task involves a specific library
- Persist research to mindbase to avoid redundant searches
- Use Morphllm WarpGrep instead of polluting main context with file reads
<!-- /rojas:section:mcp-integration -->

<!-- rojas:section:conventions:1.1.0 -->
## Conventions

- Specs live in `openspec/` — all implementation must conform to them
- Skills live in `.claude/skills/` — shared across all AI coding tools
- When using sub-agents, budget context: pass only relevant specs + files per task
- If a sub-agent fails twice on the same task, escalate to the user
- Use `airis-find` to discover any tool you need — don't assume availability

### Reporting (mandatory)
- **Announce every skill invocation** with purpose, MCP tools, and loaded context
- **Announce every sub-agent dispatch** with task, profile (frontend/general), tools, and isolation mode
- **Report sub-agent completion** with status, modified files, test results
- **Report wave/phase completion** with progress percentage and next steps
- No silent dispatches. No hidden transitions. Full transparency always.
<!-- /rojas:section:conventions -->

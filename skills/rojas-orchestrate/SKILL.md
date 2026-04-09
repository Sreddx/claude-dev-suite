---
name: rojas:orchestrate
version: 1.4.0
description: Meta-orchestrator — strategy-first wave execution, explicit checkpoints, runtime-aware isolation, and reporting
triggers: ["orchestrate", "orquestar", "run all", "ejecutar todo"]
layer: 2
wraps: null
mcp_dependencies: [airis-mcp-gateway, serena]
compatible_tools: [claude-code, cursor, opencode, codex, copilot]
---

# rojas:orchestrate

The meta-skill that coordinates the implementation phase. Reads `tasks.md`, analyzes dependencies, and dispatches isolated task execution in the optimal order with maximum practical parallelism.

## Flow

```
Read tasks.md + handoff.md
        │
Execution readiness check
(memory / runtime / isolation mode)
        │
airis-find + airis-exec
(analyze dependencies, build DAG)
        │
Planning-approved checkpoint
        │
┌─────┼─────┐
│     │     │
A     B     C ← independent tasks: parallel isolated execution
│     │     │
done  done  │
      │     │
      D ← depends on B: waits, then dispatches
      │
Wave checkpoint + serena save
      │
Pre-verify checkpoint
      │
rojas:verify (isolated reviewer)
      │
Post-verify checkpoint
```

1. **Pre-flight: verify change folder is complete**
   Before parsing anything, run all of the following checks. If any fail, surface the issue to the user and stop — do not dispatch any waves against an incomplete or unnamed change.

   - [ ] Change folder name is kebab-case (`verb-scope-outcome`) — if numeric (e.g. `1`, `2`), stop and warn: "Change folder names must be descriptive (e.g. `bootstrap-client-portal-mvp`), not numeric. Rename the folder and update commit references before proceeding."
   - [ ] `openspec/changes/<change-name>/proposal.md` exists and is non-empty
   - [ ] `openspec/changes/<change-name>/design.md` exists and is non-empty
   - [ ] `openspec/changes/<change-name>/tasks.md` exists and is non-empty
   - [ ] Every task in `tasks.md` carries: `Change`, `Wave`, `Spec`, `Stories`, `Owner profile`, `Dependencies`, `Definition of done`, `Verification gate`

   If `design.md` is missing, offer to create it from the information in `proposal.md` before proceeding.

2. **Parse approved execution inputs** — read `openspec/changes/<change-name>/tasks.md` and, if present, `openspec/changes/<change-name>/handoff.md`
3. **Check readiness**
   - Restore prior progress via `serena:read_memory` when resuming (or read `openspec/changes/<change-name>/tasks.md` for file-based fallback)
   - If the repo is brownfield and no project memory exists, offer minimal initialization before dispatching waves
   - Determine whether the runtime supports true sub-agents or requires logical isolation
4. **Build dependency graph** — use `airis-find` + `airis-exec` via airis-mcp-gateway to analyze task relationships and build a DAG (fallback: manual dependency analysis from tasks.md)
5. **Planning-approved checkpoint** — confirm approved scope, selected execution mode, and wave plan before starting work
6. **Dispatch wave 1** — all tasks with no unmet dependencies, using true sub-agents when supported and logical isolation otherwise
7. **Monitor completion** — as each isolated task finishes, check off task and evaluate the next wave
8. **Dispatch subsequent waves** — tasks whose dependencies are now met
9. **Wave checkpoint** — after each wave, record progress, open risks, and recommended next actions; persist to `serena:write_memory` (or update `openspec/changes/<change-name>/tasks.md` as fallback)
10. **Pre-verify checkpoint** — summarize completed scope, touched areas, known risks, and verification priorities
11. **Final verification** — dispatch `rojas:verify` as isolated review
12. **Post-verify checkpoint** — record pass/fail outcome, remediation path if needed, and archive-readiness
13. **Report** — explicit summary (see Reporting Protocol below)

## Reporting Protocol

**Every skill invocation and sub-agent dispatch MUST be reported explicitly to the user.** This is non-negotiable across all `rojas:*` skills.

### On Skill Invocation
Always announce:
```
[rojas:<skill>] Starting — <purpose>
  MCP tools: <list of MCP servers being used>
  Context: <what files/specs are loaded>
```

### On Sub-Agent Creation
Always announce:
```
[SUB-AGENT] Dispatching "<agent-description>"
  Task: <task from tasks.md>
  Profile: <frontend | general>
  Tools: <playwright, magic, morphllm, context7, etc.>
  Isolation: <true-subagent | logical-isolation | inline>
  Files in context: <count>
```

### On Sub-Agent Completion
Always report:
```
[SUB-AGENT] Completed "<agent-description>"
  Status: <success | failed>
  Files modified: <list>
  Tests: <passed/failed count>
  Duration: <time>
```

### On Wave Completion
```
[ORCHESTRATE] Wave <N> complete
  Tasks done: <list>
  Next wave: <list of tasks to dispatch>
  Progress: <N/M tasks> (<percentage>%)
  Session saved: <serena checkpoint ID>
  Open risks: <list>
  Recommended checkpoint/commit: <yes/no + reason>
```

### On Skill Completion
```
[rojas:<skill>] Complete
  Summary: <one-line result>
  Artifacts: <files created/modified>
  Next recommended: <next skill in the cycle>
```

This ensures full transparency for the user at all times — no silent agent dispatches or hidden skill transitions

## Context Budgeting

Each isolated task execution receives a **minimal context envelope**:

```
{
  task: "specific task from tasks.md",
  handoff: "openspec/changes/<current>/handoff.md (if present)",
  specs: ["only relevant spec sections"],
  files: ["only files this task needs to read/modify"],
  mcp: ["context7 for library docs"]
}
```

When present, `handoff.md` should be the first execution bridge document used to keep global context compact without copying the full planning record into every isolated task execution.

This prevents context window bloat and improves sub-agent accuracy.

## Execution Checkpoints

Use explicit checkpoints to keep long-running execution understandable and resumable:

1. **Planning-approved checkpoint** — approved scope, chosen isolation mode, and expected wave structure are all explicit
2. **Wave checkpoint** — after each wave, summarize completions, blockers, risk, and whether a local commit is recommended
3. **Pre-verify checkpoint** — before verification starts, summarize touched files/modules and required checks
4. **Post-verify checkpoint** — record whether the change is ready for archive or must return to implementation

These checkpoints complement Serena state. Serena preserves progress; checkpoints preserve operator clarity.

## Session Resilience

State saved to serena after each wave:
```json
{
  "change": "bootstrap-client-portal-mvp",
  "completed_tasks": ["task-1", "task-2"],
  "in_progress": ["task-3"],
  "pending": ["task-4", "task-5"],
  "wave": 2,
  "timestamp": "2026-03-12T10:00:00Z"
}
```

If the session is interrupted, `rojas:orchestrate` resumes from the last checkpoint — no work is repeated.

## Escalation Policy

- Task fails once → retry with adjusted context (more files, different approach)
- Task fails twice → escalate to user with full error context from both attempts
- Never retry a third time automatically
- If repeated failure suggests spec drift rather than execution failure, stop and return to `rojas:propose` or spec revision before continuing

## Progress tracking (mandatory at wave boundaries)

After EACH wave completes (all tasks in the wave are checked off in tasks.md):

1. Read `openspec/changes/<change-name>/progress.md`
   - If it doesn't exist, create it from `templates/openspec/progress.md`
2. Update the wave's status row: `pending` → `in-progress` → `done`
3. Update task counts from tasks.md
4. Add a session log entry
5. If Serena MCP is available, also persist to project memory:
   - Key: `progress/<change-name>`
   - Value: current wave status summary
6. If Serena is NOT available, the progress.md file IS the state — ensure it's saved

On session resume:
1. Read progress.md to determine current state
2. Report to user: "Resuming from Wave N — [status summary]"
3. Continue from the first incomplete wave

## When to Use

- Multi-task changes where parallelism matters
- Complex features spanning multiple files/modules
- When you want hands-off execution of an approved spec

## When NOT to Use

- Single-task changes — use `rojas:implement` directly
- Exploration phase — use `rojas:explore` instead

## Next Step

After orchestration completes (including verification), proceed to `opsx:archive`.

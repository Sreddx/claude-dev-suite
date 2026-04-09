---
name: rojas:implement
version: 1.3.0
description: Strategy-first implementation wrapper: use sub-agents when partitioning helps, then choose the best available tooling per runtime
triggers: ["implement", "implementar", "build", "construir", "apply"]
layer: 2
wraps: opsx:apply
mcp_dependencies: [airis-mcp-gateway, context7, serena]
compatible_tools: [claude-code, cursor, opencode, codex, copilot]
---

# rojas:implement

Build step by step following the spec's `tasks.md`. Wraps OpenSpec's `opsx:apply` with a strategy-first execution model:

1. **Prefer sub-agents when partitioning provides useful isolation**
2. **Then select the best available tooling for the runtime and task type**
3. **Fallback to inline or logically isolated execution when true sub-agents or MCPs are unavailable**

## Flow

1. **Pre-flight: verify change folder is complete**
   Before loading anything, run all of the following checks. If any fail, surface the issue to the user and stop — do not proceed to implementation against an incomplete or unnamed change.

   - [ ] Change folder name is kebab-case (`verb-scope-outcome`) — if numeric (e.g. `1`, `2`), stop and warn: "Change folder names must be descriptive (e.g. `bootstrap-client-portal-mvp`), not numeric. Rename the folder and update commit references before proceeding."
   - [ ] `openspec/changes/<change-name>/proposal.md` exists and is non-empty
   - [ ] `openspec/changes/<change-name>/design.md` exists and is non-empty
   - [ ] `openspec/changes/<change-name>/tasks.md` exists and is non-empty
   - [ ] Every task in `tasks.md` carries: `Change`, `Wave`, `Spec`, `Stories`, `Owner profile`, `Dependencies`, `Definition of done`, `Verification gate`

   If `design.md` is missing, offer to create it from the information in `proposal.md` before proceeding rather than skipping the check.

2. **Load approved planning context** — read `openspec/changes/<change-name>/tasks.md` and, if present, `openspec/changes/<change-name>/handoff.md`
3. **Check execution readiness**
   - If the repo is brownfield and no Serena project memory exists, offer a minimal initialization before implementation continues
   - If no true sub-agents are available in the runtime, switch explicitly to logical isolation mode and announce that behavior
4. **Analyze dependencies** — identify which tasks are independent vs sequential
5. **For each task**:
   - **Choose execution strategy first** — if the task can be isolated usefully, dispatch a sub-agent; otherwise keep it inline
   - **Context budget** — gather only the specs, design sections, and source files relevant to this task
   - **Fetch docs** — `context7:query-docs` for any library the task touches when available; otherwise rely on canonical repo docs and explicitly note the fallback
   - **Execute with TDD** — tests first, then implementation
   - **Mark complete** — check off task in `tasks.md`
6. **Sequential tasks** — wait for blocking tasks to complete before dispatching dependent ones
7. **Pre-verify checkpoint** — summarize completed tasks, remaining risk, modified areas, and recommended verification focus
8. **Wrap up** — run `opsx:apply` to record completion in OpenSpec

## Execution Strategy

Use this priority order:

1. **True sub-agent isolation** — preferred when the runtime supports separate agents/threads and the task benefits from partitioning
2. **Logical isolation** — use a fresh role/task prompt and a narrow context envelope when the runtime lacks true sub-agents
3. **Inline execution** — use only when the task is too small or too coupled to benefit from separation

The standard principle is: **sub-agents are an execution strategy, not a vendor-specific feature.**

## Tooling Profiles

Once the execution strategy is chosen, activate the best tooling the runtime can actually support.

### Frontend Implementation
- **Preferred tools when available**
  - `magic` for UI/component generation
  - `playwright` for browser-based verification
  - `context7` for framework/library docs
- **Fallback when unavailable**
  - implement components directly in code
  - use the project's existing UI/unit/integration tests
  - document that browser verification was approximated rather than run through Playwright

### General Implementation
- **Preferred tools when available**
  - `morphllm:edit_file` (FastApply) for faster edits
  - `morphllm:warpgrep_codebase_search` for code search
  - `context7` for library docs
- **Fallback when unavailable**
  - use native editor/file operations in the current runtime
  - use project-native search/test flows
  - keep the same TDD and context-budgeting discipline

### Profile Detection
Detect automatically based on task content:
- Task mentions UI, component, page, layout, CSS, DOM → **Frontend profile**
- Everything else → **General profile**

## Sub-Agent Protocol

Each isolated task execution receives:
- The specific task description from `tasks.md`
- `handoff.md` when present, as the compact bridge from approved planning to implementation
- Relevant spec sections (not the entire spec)
- Only the source files it needs to modify
- Best-available docs/tooling access for that runtime
- Instructions to follow TDD

If `handoff.md` exists, treat it as the execution summary, while `proposal.md`, `design.md`, and `tasks.md` remain the source of truth.

Each isolated task execution does **not** receive:
- Other tasks' context
- Full project history
- Unrelated specs or design docs

## Execution Checkpoints

Use visible checkpoints to protect continuity and reduce context drift:

1. **Planning-approved checkpoint** — approved spec + implementation path confirmed
2. **Task checkpoint** — after each critical or risky task, record what changed and what remains
3. **Pre-verify checkpoint** — before handing off to `rojas:verify`, summarize completed scope, known risks, and required checks
4. **Post-verify checkpoint** — after verification, record pass/fail state and next required action

For longer changes, recommend a local commit at meaningful milestones, but do not make commits mandatory for every task.

## Escalation

If a task fails twice:
1. Collect error context from both attempts
2. Surface to the user with a summary of what was tried
3. Do not retry a third time automatically

## When to Use

- After `rojas:propose` has been approved
- When `tasks.md` exists and is ready for implementation
- When execution is mostly sequential or the DAG does not justify full orchestration
- Prefer `rojas:orchestrate` for complex multi-task or multi-wave changes

## Next Step

After all tasks are complete, proceed to `rojas:verify`.

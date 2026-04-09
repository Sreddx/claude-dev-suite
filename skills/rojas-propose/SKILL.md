---
name: rojas:propose
version: 1.5.0
description: Human-facing proposal workflow with API validation, review, and explicit implementation handoff guidance
triggers: ["propose", "proponer", "spec", "new feature", "nueva feature"]
layer: 2
wraps: opsx:propose, opsx:new, opsx:ff, opsx:continue
mcp_dependencies: [context7, serena]
compatible_tools: [claude-code, cursor, opencode, codex, copilot]
---

# rojas:propose

Human-facing proposal workflow. The recommended interface for people is `rojas:propose`.

- **Recommended human entrypoint:** `rojas:propose`
- **Default profile engine:** `opsx:propose` (one-step — all four artifacts at once)
- **Expanded profile engine:** `opsx:new` → `opsx:ff` → `opsx:continue` (step-through)
- **Direct `opsx:*` usage:** allowed as an expert exception, not the standard team-facing path

Create a spec scaffold with enriched validation and a clear handoff into implementation.

## Flow

### Pre-check (mandatory)

Before generating ANY artifact:
1. Verify `openspec/config.yaml` exists. If not, run `openspec init` first.
2. Read `openspec/config.yaml` to determine the active profile.
3. You MUST use the opsx engine commands below — do NOT write proposal.md, design.md, tasks.md, or spec files directly. The opsx commands generate the correct file structure and frontmatter.
4. After opsx generates files, enrich with rojas metadata only (indented sub-bullets on tasks).
5. Validate all generated spec frontmatter against `schemas/spec-frontmatter.md`.

### Enforcement rule

If `opsx:propose` (or `opsx:new` + `opsx:ff` + `opsx:continue`) is not available in the current environment:
- Check if openspec CLI is installed (`which opsx` or `npx opsx --version`)
- If not installed, tell the user: "OpenSpec CLI is not installed. Run `openspec init` in this repo first."
- DO NOT fabricate the file structure manually as a fallback
- Exception: if the user explicitly says "skip openspec CLI, write manually", then use the format from `schemas/spec-frontmatter.md` exactly — no improvisation

### Steps

1. **Confirm proposal path and OpenSpec profile** — use `rojas:propose` as the standard entrypoint.
   Check `openspec/config.yaml` for the active profile, then invoke the correct underlying engine:

   - **Default profile** (`workflows` key absent or does not include `new`):
     ```
     opsx:propose
     ```
     Produces all four artifacts at once: `proposal.md`, `changes/<name>/specs/`, `design.md`, `tasks.md`.
     Delta specs land at `openspec/changes/<change-name>/specs/` — **not** in `openspec/specs/` directly.

   - **Expanded profile** (`workflows` includes `new`, `ff`, `continue`):
     ```
     opsx:new <change-name>   ← folder scaffold only, no artifacts
     opsx:ff                  ← produces proposal.md + changes/<name>/specs/ + design.md only
     opsx:continue            ← one additional required step that produces tasks.md
     ```
     `opsx:ff` does **not** produce `tasks.md`. The `opsx:continue` call after `opsx:ff` is mandatory.

   **Change name rules — enforced, not optional:**
   - Format: `verb-scope-outcome` in kebab-case
   - Must be derived from the feature or PRD scope, never assigned a number
   - Good: `introduce-payment-gateway`, `bootstrap-client-portal-mvp`, `harden-auth-session-expiry`, `add-notification-service`
   - Bad: `1`, `change-1`, `update`, `misc`, any pure number
   - If the caller provides a numeric name, reject it and ask for a descriptive one before proceeding
   - If you cannot derive a name from context, ask the user — do not default to a number
2. **Check prior exploration context** — if this is a brownfield repo and no Serena project memory exists, offer a minimal initialization before proceeding:
   - "You skipped `rojas:explore`. Do you want to initialize a minimal project memory now so proposal and implementation do not start from zero context?"
   - Minimal memory should capture project name, stack, key modules, and major constraints
3. **Validate APIs** — for any external API or library referenced in the proposal:
   - `context7:resolve-library-id` to confirm the library exists
   - `context7:query-docs` to verify API signatures, parameters, and return types
4. **Sub-agent review** (when the runtime supports real sub-agents) — dispatch a spec-reviewer sub-agent to evaluate:
   - Completeness: all requirements covered?
   - Feasibility: can this be built with the proposed approach?
   - Coherence: does the design match project conventions?
   If the runtime does not support true sub-agents, run the same review as a logically isolated pass with a fresh prompt and explicit role separation.
5. **Present to user** — show proposal with reviewer feedback for approval
5.5. **Automated plan validation** — before presenting for approval, run these checks:
   - [ ] Every task in tasks.md has: domain tag, acceptance criteria, dependency list (even if empty)
   - [ ] No task references files outside its domain (cross-domain tasks must be split or marked as sequential)
   - [ ] If handoff.md is needed (multi-wave, cross-repo, high-risk): it exists or is flagged for creation
   - [ ] API contracts: if frontend tasks consume backend endpoints, the endpoint signatures are documented in design.md or as OpenAPI stubs
   - [ ] Test tasks exist for every implementation task (TDD enforcement)
   Report check results alongside the plan for developer review.
6. **Close with a handoff decision** — explicitly decide:
   - `rojas:implement` vs `rojas:orchestrate`
   - whether `handoff.md` should be created before execution
   - whether a fresh session is recommended

## Fast-Forward Mode (expanded profile only)

`opsx:ff` fast-forwards through the first three artifacts:
- `openspec/changes/<change-name>/proposal.md` — what and why
- `openspec/changes/<change-name>/specs/<capability>.md` — delta specifications (not main specs/)
- `openspec/changes/<change-name>/design.md` — architectural decisions

`opsx:ff` does **not** produce `tasks.md`. After `opsx:ff` completes, one additional call is required:
```
opsx:continue   ← produces tasks.md once design is locked
```

`opsx:propose` (default profile) produces all four artifacts including `tasks.md` in a single call.

The `rojas:propose` layer adds API validation and execution-transition guidance before signaling ready.

## When to Use

- Starting any new feature or change
- After `rojas:explore` or `rojas:research` has clarified the approach
- When converting informal requirements into structured specs
- When a human wants the canonical wrapper flow rather than raw `opsx:*` commands

## Handoff Guidance

After proposal approval, decide whether the change needs a compact implementation handoff artifact.

Use `templates/openspec/handoff.md` when the change is:
- high-risk
- brownfield with legacy integration points
- multi-wave or dependency-heavy
- cross-package or cross-repo
- likely to be implemented by parallel sub-agents

The handoff should stay compact and refer back to canonical files (`proposal.md`, `design.md`, `tasks.md`) instead of duplicating all context.

## Completion Convention

Every `rojas:propose` run should end with:
1. **What is now ready** — approved or review-ready planning artifacts
2. **What decision the user must make next** — implement, orchestrate, or revise
3. **Suggested continuation prompt** — especially when a fresh session is preferred

### Suggested continuation prompts

**Straight implementation path**
> Start a fresh session and run `rojas:implement` for `<change-name>`. Use `tasks.md` as the execution checklist. If `handoff.md` exists, treat it as the compact execution bridge.

**Parallel / DAG path**
> Start a fresh session and run `rojas:orchestrate` for `<change-name>`. Build the task DAG from `tasks.md`, use `handoff.md` as the execution bridge if present, and checkpoint progress after each wave.

**If handoff should be created first**
> Before implementation, create `openspec/changes/<change-name>/handoff.md` from the template and keep it compact: scope, boundaries, closed decisions, canonical files, and verification expectations.

## Next Step

After proposal is approved:
- proceed to `rojas:implement` for straightforward task-by-task execution
- proceed to `rojas:orchestrate` for multi-task or parallel work
- create `handoff.md` first when the approved change needs a tighter bridge between planning and implementation
- prefer a fresh session when the approved context is large, cross-cutting, or wave-based

---
name: rojas:verify
version: 1.1.0
description: Isolated verification — independent reviewer checks approved scope, correctness, coherence, and handoff boundaries
triggers: ["verify", "verificar", "review", "revisar", "check"]
layer: 2
wraps: opsx:verify
mcp_dependencies: []
compatible_tools: [claude-code, cursor, opencode, codex, copilot]
---

# rojas:verify

Verify that implementation matches spec intent. Wraps OpenSpec's `opsx:verify` with an isolated reviewer sub-agent that was NOT involved in implementation.

## Flow

1. **Load specs** — read the full spec (proposal, design, tasks) for the current change, plus `handoff.md` if present
2. **Load research** (if exists) — read `openspec/changes/<current>/research.md` for findings from the explore/research phases
3. **Dispatch isolated reviewer** — a fresh reviewer context with NO implementation carry-over:
   - reads specs independently
   - uses `handoff.md` first when present to understand approved scope boundaries, closed decisions, and verification expectations
   - reviews the implementation code
   - checks against the verification dimensions below
   - if the runtime lacks true sub-agents, use a logically isolated verification pass and state that explicitly
4. **Run opsx:verify** — OpenSpec's native verification
5. **Combine reports** — merge reviewer findings with opsx:verify output
6. **Surface issues** — present to user with severity (blocker / warning / suggestion) and say whether the change is archive-ready or must return to implementation

## Three Verification Dimensions

### Completeness
- All tasks in `tasks.md` are checked off
- All requirements in specs have corresponding implementation
- Test coverage exists for all specified behaviors

### Correctness
- Implementation matches spec intent (not just letter)
- Edge cases from design.md are handled
- No regressions in existing functionality

### Coherence
- Design decisions from `design.md` are reflected in code structure
- Code follows project conventions from AGENTS.md
- No architectural drift from the original proposal

## Why Isolated?

The reviewer must be a separate agent/context from the implementer to avoid confirmation bias. An agent that wrote the code will naturally think it's correct.

## When to Use

- After `rojas:implement` completes all tasks
- Before `opsx:archive` — always verify first
- When resuming work and need to check current state

**Profile note:** `opsx:verify` is available in the **expanded profile** only
(`workflows` list in `openspec/config.yaml` must include `verify`).
For repos on the default profile, run the three verification dimensions as a logically isolated
review pass without invoking `opsx:verify` directly, and note that explicitly in the output.

## Next Step

If verification passes, proceed to `opsx:archive`. If issues found, return to `rojas:implement` for fixes.

Verification should also emit a **post-verify checkpoint**: pass/fail status, blockers, follow-up path, and whether the approved scope stayed intact.

## Manual Test Handoff

After surfacing issues, always append:
- A list of acceptance criteria from the original tasks.md that require manual verification
- Specific instructions for what the developer should test manually (e.g., "Open the app, navigate to /tickets, create a new ticket, verify it appears in the list")
- Any areas where automated tests could not cover the behavior (e.g., visual layout, UX flow, third-party integrations)

This handoff is consumed by the orchestrator's MANUAL TEST GATE.

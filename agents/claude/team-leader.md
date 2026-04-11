---
name: team-leader
description: REFERENCE ONLY — do not dispatch. Wave dispatch logic has been merged into orchestrator. See orchestrator.md for the current dispatch protocol.
tools: [Read]
model: haiku
color: pink
---

<!-- sdd-dev-suite:agent:team-leader:2.0.0 -->

# team-leader — REFERENCE DOCUMENT (not a spawning agent)

> **This agent no longer dispatches sub-agents.** Its wave coordination logic has been merged into `orchestrator.md`.
>
> **Why:** Claude Code has a hard platform limit — sub-agents cannot spawn sub-agents. The Agent tool is only available to the main session. team-leader sat at nesting level 2 and could never dispatch level-3 agents, causing silent failures.
>
> **What to do instead:** Use the orchestrator directly. It now handles all wave dispatch. See `orchestrator.md` → "Wave execution (direct dispatch — no intermediary)".

## Dispatch chain (DEPRECATED — kept for reference)

The old three-level chain was:
```
orchestrator → team-leader → frontend/backend/database → tester-*
```
This broke silently because level 3 agents never executed.

## Replacement (CURRENT — in orchestrator.md)

```
orchestrator → frontend
             → backend
             → database
             → tester-front
             → tester-back
             → github-ops
             → validator
             → planner
             → researcher
             → agent-sync
             → agent-prep
             → devstart
```

## Preserved reference: cross-domain conflict resolution

These rules are now enforced by the orchestrator:

- Frontend + backend share an API contract → define the contract in design.md BEFORE dispatching either
- Database migration needed by backend → dispatch database first, then backend
- FE + BE tasks are domain-isolated → dispatch in parallel
- Tester-* run after their domain implementation is complete

## Preserved reference: escalation logic

- Agent fails once → retry with adjusted context
- Agent fails twice → escalate to orchestrator (now: escalate to user)
- Never auto-retry a third time

## Preserved reference: wave completion checklist

After all tasks in a wave are complete:
1. Verify every task is checked off in tasks.md
2. Dispatch agent-sync to update AGENTS.md and persist state
3. Report wave completion to orchestrator
4. Only dispatch next wave after full confirmation

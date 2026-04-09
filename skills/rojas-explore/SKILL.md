---
name: rojas:explore
version: 1.1.0
description: Enriched exploration — wraps opsx:explore with context7, tavily, and serena for brownfield project memory
triggers: ["explore", "investigar", "what about", "qué hay sobre"]
layer: 2
wraps: opsx:explore
mcp_dependencies: [context7, serena]
compatible_tools: [claude-code, cursor, opencode, codex, copilot]
---

# rojas:explore

Investigate the problem space before proposing a spec. Enriches OpenSpec's native `opsx:explore` with live documentation and web research.

## Flow

1. **Detect context** — read existing `openspec/specs/` and `AGENTS.md` for project conventions
2. **Brownfield detection** — if the repo has existing source code (not a greenfield project):
   - Check `openspec/changes/<current>/research.md` for prior session findings
   - If no project memory exists, **ask the user** to generate a consistent project memory:
     > "This is a brownfield repository with existing code. To maintain a consistent reference across the full SDD cycle (especially for archive), I recommend generating a project memory now. Should I scan the codebase and create a structured project memory via serena?"
   - If approved, scan key files (README, package.json, architecture docs, main modules) and persist via `serena:write_memory` with tag `project:memory` (or write to `openspec/changes/<current>/research.md` if serena unavailable)
   - This memory will be referenced during `rojas:verify` and `opsx:archive` for broad progress tracking
3. **Identify libraries** — scan the codebase for dependencies relevant to the exploration topic
4. **Fetch current docs** — use `context7:resolve-library-id` then `context7:query-docs` for each relevant library
5. **Web research** (if needed) — use `WebSearch` for external context, patterns, or prior art
6. **Delegate to OpenSpec** — execute `opsx:explore` with the enriched context
7. **Persist findings** — write key discoveries to `openspec/changes/<current>/research.md` for cross-session retrieval

## Brownfield Project Memory

When exploring a brownfield repo for the first time, the generated project memory should include:

```json
{
  "project_name": "...",
  "tech_stack": ["..."],
  "architecture_summary": "...",
  "key_modules": ["..."],
  "conventions": ["..."],
  "known_constraints": ["..."],
  "exploration_date": "YYYY-MM-DD"
}
```

This memory becomes the **baseline reference** for:
- `rojas:verify` — comparing implementation against project norms
- `opsx:archive` — documenting broad progress and spectrum of the change relative to the project

## When to Use

- Requirements are unclear or ambiguous
- The task involves unfamiliar libraries or APIs
- You need to investigate before committing to an approach
- Starting a new feature area with unknown constraints
- **Brownfield repos** — always run explore first to generate project memory

## Behavior by Tool

- **Claude Code (SuperClaude)**: dispatch as sub-agent via Agent tool; context7 and tavily available as native MCP calls
- **Cursor / Copilot**: follow this flow inline; MCP calls via configured servers
- **Codex / OpenCode**: same flow; MCP via local config

## Next Step

After exploration, proceed to `rojas:research` (if deeper investigation needed) or `rojas:propose` (if ready to spec).

If the user still chooses to skip exploration in a brownfield repo later, downstream skills should offer a **minimal Serena memory initialization** rather than silently proceeding with zero persistent context.

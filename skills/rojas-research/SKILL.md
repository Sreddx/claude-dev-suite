---
name: rojas:research
version: 1.1.0
description: Deep research with multi-hop search, live docs, and persistent knowledge storage
triggers: ["research", "investigar a fondo", "deep dive", "buscar"]
layer: 2
wraps: null
mcp_dependencies: [context7, serena]
compatible_tools: [claude-code, cursor, opencode, codex, copilot]
---

# rojas:research

Deep investigation for unknowns that require multi-hop search, evidence collection, and persistent storage. Standalone skill — does not wrap an OpenSpec command.

## Flow

1. **Check existing knowledge** — read `openspec/changes/<current>/research.md` for prior research on this topic
2. **Plan research** — decompose the question into 3-5 sub-questions
3. **Parallel search** — for each sub-question:
   - `context7:query-docs` for library-specific answers
   - `WebSearch` (native tool) for web results
   - `airis-find` + `airis-exec` for any specialized tool that might help
4. **Synthesize** — combine findings, resolve contradictions, note confidence levels
5. **Persist** — write findings to `openspec/changes/<current>/research.md` with structured sections
6. **Save session** — use `serena:write_memory` to preserve research state for cross-session continuity (if available); fallback: write to `openspec/changes/<current>/research.md` as file-based state
7. **Output report** — write findings to `openspec/changes/<current>/research.md`

## Evidence Management

- Track sources for every claim
- Note confidence level (high/medium/low) per finding
- Flag contradictions explicitly
- Prefer primary sources (official docs via context7) over secondary (blog posts via WebSearch)

## When to Use

- The exploration phase revealed significant unknowns
- Technical decisions require evidence (choosing between libraries, patterns, etc.)
- Compliance or security questions need documented answers
- Any time you'd otherwise guess — research instead

## Next Step

After research, proceed to `rojas:propose` with evidence-backed decisions.

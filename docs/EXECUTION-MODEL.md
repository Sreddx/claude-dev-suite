# Execution Model

This document separates **workflow behavior** from **tool capability**.

## Purpose

Not every supported AI tool executes work the same way. Some offer robust native subagents, while others are better treated as consumers of repo guidance plus local configuration.

This document helps teams reason about execution without over-claiming parity.

## Key concepts

| Term | Meaning |
|---|---|
| **Repo contract** | The source of truth in the repository: `AGENTS.md`, specs, ADRs, handoff artifacts. |
| **Execution adapter** | Tool-specific layer that helps the tool consume the repo contract. |
| **True isolation** | A subagent/task runs in a genuinely separate context or thread. |
| **Logical isolation** | A workflow simulates separation through prompts, task partitioning, or conventions. |

## Workflow policy

Document workflow behavior in this order:
1. **Human-facing wrapper** (`rojas:*`)
2. **Underlying engine** (`opsx:*`)
3. **Runtime behavior** (true isolation, logical isolation, inline fallback)

This keeps the user-facing model stable even when runtimes differ.

## Fallback policy

When documenting MCPs, subagents, or advanced tooling, always distinguish:
- **preferred path** — what to use when the runtime supports it
- **fallback path** — what to do when the tool/runtime is unavailable
- **contractual expectation** — what outcome still must hold regardless of tooling

Examples:
- Builder/verifier separation is contractual; true subagents are runtime-dependent.
- Browser verification via Playwright is preferred for frontend work; equivalent project-native tests are the fallback when Playwright is unavailable.
- Serena project memory is preferred for brownfield continuity; minimal-memory initialization is the fallback when full explore was skipped.

## Practical model by tool

| Tool | Repo contract | Execution style | Isolation expectation |
|---|---|---|---|
| Claude Code | Strong | Skill-driven + subagents | Often true isolation |
| Cursor | Strong | Rules/skills/subagents | Tool-supported isolation |
| Copilot | Basic | Repo instructions + user-driven workflow | Mostly logical isolation |
| Codex | Strong | AGENTS + skills + subagents | Strong isolation support |
| OpenCode | Strong | Agents/commands/config adapters | Tool-supported isolation |

## Policy recommendation

When documenting workflow behavior, specify whether a claim is about:
1. the **repo contract**,
2. the **tool runtime**, or
3. a **recommended team convention**.

Example:
- “Builder/verifier separation is **required by the workflow design**.”
- “True isolated verification is **strongest in tools with real subagent support**.”
- “Other tools may approximate that with logical separation.”

# Tool Compatibility

This document is the canonical compatibility reference for the Rojas SDD standard across supported AI coding tools.

## Support level taxonomy

| Level | Meaning |
|---|---|
| **Guaranteed** | Installed or created consistently by the baseline sync. Part of the repo-level contract. |
| **Supported** | The tool can follow the standard with the documented repo artifacts, but some behavior depends on the tool runtime or local setup. |
| **Recommended** | A practice the standard encourages, but does not enforce technically. |
| **Local-only** | Must live in developer-local config and is never committed by baseline sync. |
| **Experimental** | Mentioned or partially scaffolded, but not yet first-class in the standard. |

## Compatibility matrix

| Capability | Claude Code | Cursor | Copilot | Codex | OpenCode |
|---|---|---|---|---|---|
| Reads repo-level delivery contract | **Guaranteed** via `CLAUDE.md` + `AGENTS.md` | **Supported** via `AGENTS.md` and Cursor-native rule/skill systems | **Guaranteed** via `.github/copilot-instructions.md` + `AGENTS.md` | **Supported** via `AGENTS.md` | **Supported** via `AGENTS.md` |
| OpenSpec / spec artifacts in repo | **Guaranteed** | **Guaranteed** | **Guaranteed** | **Guaranteed** | **Guaranteed** |
| Baseline skill packaging in repo | **Guaranteed** (`.claude/skills/`) | **Supported** by reading repo contract, but not first-class packaged by baseline | **Supported** indirectly through repo instructions | **Supported** indirectly through repo instructions | **Supported** indirectly through repo instructions |
| Native agents / subagents available in tool | **Supported** | **Supported** | **Tool-dependent / limited** | **Supported** | **Supported** |
| Local bootstrap path in this repo | **Guaranteed** | **Guaranteed** | **Guaranteed** | **Experimental** (template exists, no bootstrap flow yet) | **Guaranteed** |
| MCP setup in baseline repo sync | **Local-only** | **Local-only** | **Local-only** | **Local-only** | **Local-only** |
| Best fit for first-class execution today | **Strongest** | **Strong** | **Basic compatibility** | **Strong but less wired here** | **Strong but less wired here** |

## Tool notes

### Claude Code
- Best-supported execution path in the current standard.
- Repo entrypoints: `CLAUDE.md`, `AGENTS.md`, `.claude/skills/`, `openspec/`.
- Use Claude-specific skills as an adapter layer, not as the source of truth.

### Cursor
- Good fit for a multi-tool standard because it can work with `AGENTS.md` while also offering native rules, skills, and subagents.
- Cursor-native layers should remain optional accelerators over the repo contract.

### Copilot
- Baseline compatibility is intentionally lighter.
- Works best as a consumer of repo guidance and specs, not as the canonical execution environment for advanced orchestration.

### Codex
- Strong conceptual fit because Codex explicitly supports `AGENTS.md` and layered project instructions.
- Current repo support is honest but incomplete on local bootstrap: template exists, but exposed bootstrap flow is not landed yet.

### OpenCode
- Strong fit for adapter-based operation through repo contract plus OpenCode-specific agents/commands/config.
- Current standard should treat OpenCode as supported, not identical to Claude Code.

## Runtime honesty rules

Every skill or guide that mentions tooling should say whether a capability is:
- required by the repo contract,
- preferred when supported by the runtime, or
- approximated through fallback behavior.

Do not describe MCPs or subagents as universally available just because one runtime supports them well.

## Recommended policy for future additions

When adding tool-specific support, document it in four dimensions:
1. **Repo contract entrypoint**
2. **Execution adapter**
3. **Local bootstrap status**
4. **Limitations / behavioral differences**

Do not claim parity just because a tool can read the repo.

## Official references
- Claude Code overview: <https://docs.anthropic.com/en/docs/claude-code/overview>
- Claude Code skills: <https://code.claude.com/docs/en/skills>
- Claude Code sub-agents: <https://code.claude.com/docs/en/sub-agents>
- Cursor rules: <https://cursor.com/docs/rules>
- Cursor skills: <https://cursor.com/docs/skills>
- Cursor subagents: <https://cursor.com/docs/subagents>
- OpenCode config: <https://opencode.ai/docs/config>
- OpenCode agents: <https://opencode.ai/docs/agents>
- OpenCode commands: <https://opencode.ai/docs/commands>
- Codex AGENTS.md: <https://developers.openai.com/codex/guides/agents-md>
- Codex skills: <https://developers.openai.com/codex/skills>
- Codex subagents: <https://developers.openai.com/codex/subagents>

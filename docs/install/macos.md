# macOS Install Guide

Use this guide to get **Claude Code**, **Cursor**, **Codex**, or **OpenCode** installed on macOS without mixing in MCP or AIRIS setup.

## Baseline prerequisites

Install or confirm these first:

- **Git**
- **Node.js** — current LTS is the safest default when a tool depends on Node-based install flows
- A terminal environment you are comfortable with (`Terminal`, `iTerm2`, etc.)

## Tool installation

### Claude Code
1. Install Claude Code using Anthropic's official macOS instructions.
2. Confirm the CLI launches successfully from your terminal.
3. Open the target repo.
4. Expect this standard to integrate through `CLAUDE.md`, `AGENTS.md`, `.claude/skills/`, and `openspec/`.

**Support level:** strongest fit in this repo.

### Cursor
1. Install Cursor from its official macOS distribution.
2. Launch it once and confirm it can open a folder on disk.
3. Open a repo using this standard.
4. Expect baseline compatibility through shared repo artifacts rather than a committed tool-specific layer.

**Support level:** strong baseline compatibility.

### Codex
1. Install Codex from OpenAI's official macOS instructions.
2. Confirm the CLI starts successfully.
3. Open a repo using this standard.
4. Expect baseline repo compatibility, with **no first-class `bootstrap.sh` flow for Codex in this repo yet**.

**Support level:** baseline-compatible, but local advanced setup is still manual/future work here.

### OpenCode
1. Install OpenCode from its official macOS instructions.
2. Confirm it launches and can open your local repo.
3. Use the repo normally with the Rojas baseline artifacts.

**Support level:** strong baseline compatibility; local advanced wiring remains separate.

## Verification checklist

Before you move on, verify:

- The tool opens or runs without errors
- `git --version` works
- `node --version` works if your chosen tool expects Node
- You can open the target repo locally

## Important boundary

These macOS steps are only for **installation and basic readiness**.

If you later want AIRIS or other MCP-based local integrations, configure those separately in your personal tool config after the tool is installed. Do not treat that as part of the baseline installer flow.

AIRIS repository: <https://github.com/Sreddx/airis-mcp-gateway>

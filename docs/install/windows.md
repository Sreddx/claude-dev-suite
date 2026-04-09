# Windows Install Guide

Use this guide to get **Claude Code**, **Cursor**, **Codex**, or **OpenCode** installed on Windows without mixing in MCP or AIRIS setup.

## Baseline prerequisites

Install or confirm these first:

- **Git** — available in PowerShell, Command Prompt, or your preferred terminal
- **Node.js** — current LTS is the safest default when a tool depends on Node-based install flows
- **A terminal you actually like using** — PowerShell is fine; Windows Terminal is nicer

## Tool installation

### Claude Code
1. Install Claude Code using Anthropic's official instructions for Windows.
2. Open a terminal and confirm the CLI launches successfully.
3. Clone or open the repo you want to work in.
4. Expect this standard to integrate through repo artifacts like `CLAUDE.md`, `AGENTS.md`, `.claude/skills/`, and `openspec/`.

**Support level:** strongest fit in this repo.

### Cursor
1. Install Cursor from its official Windows distribution.
2. Open the app once and confirm it can open a local folder.
3. Open a repo using this standard.
4. Expect baseline compatibility through shared repo artifacts, primarily `AGENTS.md` and `openspec/`.

**Support level:** strong baseline compatibility.

### Codex
1. Install Codex from OpenAI's official Windows instructions.
2. Confirm the CLI starts successfully.
3. Open a repo using this standard.
4. Expect baseline repo compatibility, but **do not expect a first-class local bootstrap flow from this repo yet**.

**Support level:** baseline-compatible, but local advanced setup is not first-class here yet.

### OpenCode
1. Install OpenCode from its official Windows instructions.
2. Confirm it launches and can open your local repo.
3. Use the repo normally with the Rojas baseline artifacts.

**Support level:** strong baseline compatibility; local advanced wiring remains separate.

## Verification checklist

Before you move on, verify:

- The tool opens or runs without errors
- `git --version` works in your terminal
- `node --version` works if your chosen tool expects Node
- You can open the target repo locally

## Important boundary

These Windows install steps stop at **tool installation and basic readiness**.

If you later want local MCP integrations or AIRIS-based tooling, configure that in your personal tool config after installation. Keep it out of the repo and out of this install layer.

AIRIS repository: <https://github.com/Sreddx/airis-mcp-gateway>

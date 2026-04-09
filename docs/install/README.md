# Install Guide by OS and Tool

This install layer is intentionally narrow:

- **Covers:** getting Claude Code, Cursor, Codex, or OpenCode installed and ready to use with the Rojas SDD baseline
- **Does not cover:** MCP server setup, AIRIS wiring, or credentialed local integrations
- **Keeps support-level honesty:** baseline repo compatibility is broader than first-class local bootstrap support

If you later want local MCP integrations, keep them in your **personal tool config**, not in the repo. AIRIS lives here: <https://github.com/Sreddx/airis-mcp-gateway>. That setup happens **after** tool installation and outside this install layer.

## Support Matrix

| Tool | Windows | macOS | Linux | Rojas baseline compatibility | Local bootstrap status in this repo |
|---|---|---|---|---|---|
| Claude Code | Yes | Yes | Yes | Strong | First-class local bootstrap documented elsewhere |
| Cursor | Yes | Yes | Yes | Strong | First-class local bootstrap documented elsewhere |
| Codex | Yes | Yes | Yes | Baseline-compatible | No `bootstrap.sh` path yet |
| OpenCode | Yes | Yes | Yes | Strong | Local bootstrap exists, but remains separate from this install layer |

## What “ready to use” means here

After following the OS guide for your tool, you should have:

1. The tool installed from its official distribution channel
2. The tool starting successfully on your machine
3. Git available in your shell or terminal
4. Node.js available if your tool or workflow expects it
5. A clear understanding of what this repo supports for that tool

It does **not** mean advanced MCP features are configured.

## Choose your OS

- [Windows](./windows.md)
- [macOS](./macos.md)
- [Linux](./linux.md)

## Tool-specific expectations

### Claude Code
- Best documented and most complete fit for this standard
- Repo baseline compatibility uses `CLAUDE.md`, `AGENTS.md`, `.claude/skills/`, and `openspec/`
- Advanced local integrations exist, but are intentionally kept out of these install docs

### Cursor
- Baseline works through `AGENTS.md` and normal repo artifacts
- Cursor-specific local config is optional and separate

### Codex
- Baseline compatibility exists through repo artifacts and Codex detection in the installer
- This repo currently **does not** provide a `local-packs/bootstrap.sh --tool codex` flow
- Treat Codex local advanced setup as manual/future work, not part of this install layer

### OpenCode
- Baseline works through `AGENTS.md` and normal repo artifacts
- Local OpenCode wiring exists separately and is intentionally not mixed into these install docs

## Related docs

- [Main README](../../README.md)
- [Complete guide](../../GUIDE.md)
- [Tool compatibility](../TOOL-COMPATIBILITY.md)
- [Repo topologies](../REPO-TOPOLOGIES.md)
- [Local packs](../../local-packs/README.md) — separate, opt-in, MCP/local integration layer

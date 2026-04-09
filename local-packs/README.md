# Local Packs

Local packs are **developer-local, opt-in extensions** that enhance your personal experience with the SDD standard. They are **never synced to repos** by the baseline or any profile.

## What local packs are for

The SDD baseline installs a clean delivery contract into repos (skills, AGENTS.md, OpenSpec structure). But many powerful tools — advanced MCP servers, personal memory, experimental features — should not live in the repo. They depend on local services, personal credentials, or individual preferences.

Local packs solve this by providing bootstrappable configurations that install to your local tool config, not the repo.

If you only need tool installation and first-run readiness, use [docs/install/README.md](../docs/install/README.md) first. Keep that install step separate from the MCP/local-pack step.

## What's in this directory

| File | Purpose |
|---|---|
| `bootstrap.sh` | Main bootstrap script — installs a local pack to your tool config |
| `claude-code-advanced.md` | Advanced Claude Code MCP config reference (AIRIS, Playwright, Magic, Morphllm) |
| `templates/mcp/*.json` | Tool-specific MCP templates consumed by `bootstrap.sh` |

## Usage

```bash
# Bootstrap the Claude Code advanced pack
bash local-packs/bootstrap.sh --tool claude-code --airis-url http://localhost:9400/sse

# Bootstrap with a specific Morph API key
bash local-packs/bootstrap.sh --tool claude-code --airis-url http://localhost:9400/sse --morph-key sk-xxx

# Dry run — show what would be installed
bash local-packs/bootstrap.sh --tool claude-code --dry-run
```

Bootstrap installs to:
- Claude Code: `~/.claude/mcp.json` (global, not project-specific)
- Cursor: `~/.cursor/mcp.json`
- VS Code / GitHub Copilot: `~/.vscode/mcp.json`
- OpenCode: `.opencode/mcp.json` (project-scoped)

Supported `--tool` values today: `claude-code`, `cursor`, `copilot`, `opencode`.
`bootstrap.sh` does **not** currently support `codex` or `all`; Codex has a template in `templates/mcp/codex.toml`, but no local-pack bootstrap path yet.

If you want project-scoped MCP configs instead, bootstrap with `--scope project` and add the generated files to your `.gitignore`.

## .gitignore for local pack artifacts

Add these to your repo's `.gitignore` if you use local packs:

```gitignore
# Local developer MCP configs — never commit
.claude/mcp.json
.cursor/mcp.json
.vscode/mcp.json
.opencode/mcp.json
.codex/config.toml

# Agent memory and session state — local only
.agent/memory/
.serena/
.mindbase/
*.morph-key
```

## Important rules

1. **Never commit local pack artifacts to a repo.** If you want to share MCP config with your team, that belongs in a profile, not a local pack.
2. **Never put credentials in local pack config files.** Use environment variables. The bootstrap script accepts flags like `--morph-key` but uses them at install time, not stored in config files.
3. **Local packs can be used with any profile.** They are independent layers.
4. **Local pack versions are pinned in the bootstrap script.** To upgrade, re-run bootstrap.

## Relationship to profiles

| | Profile | Local pack |
|---|---|---|
| Committed to repo | Yes | No |
| Synced by central workflow | Yes | No |
| Requires team coordination | Yes | No |
| Developer-local | No | Yes |
| Carries credentials | No | Optionally (as env vars) |

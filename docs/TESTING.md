# Testing Strategy for the Standard Itself

The standard must be tested before it is deployed. This document defines the testing approach for `claude-dev-suit` before any broad rollout.

---

## Test Fixture Repos

Create and maintain these fixture repos in the org under `Sreddx/`:

| Fixture repo | Type | Purpose |
|---|---|---|
| `sdd-fixture-greenfield` | Empty repo | Tests first-ever install from scratch |
| `sdd-fixture-brownfield` | Repo with existing code, no SDD | Tests install into established codebases |
| `sdd-fixture-partial` | Repo with older SDD version | Tests version-aware upgrade behavior |
| `sdd-fixture-custom-agents` | Repo with hand-written AGENTS.md | Tests non-destructive merge with existing content |
| `sdd-fixture-multi-tool` | Repo with Claude Code + Cursor | Tests multi-tool MCP config merge |
| `sdd-fixture-protected` | Repo with branch protection on main | Tests PR flow vs direct push |
| `sdd-fixture-frontend` | React app repo | Tests frontend profile install |
| `sdd-fixture-high-risk` | Repo tagged for compliance | Tests high-risk profile and escalation guardrails |

Each fixture repo should have a `FIXTURE.md` that describes its starting state and expected post-sync state.

---

## Test Categories

### 1. Greenfield install tests

**What to verify:**
- `openspec/config.yaml` created with correct profile
- All 7 rojas:* skills + 3 community skills installed in `.claude/skills/` (each as `<name>/SKILL.md`)
- `rojas:kickstart` skill present alongside the 6 original rojas:* skills
- AGENTS.md created with all 4 rojas sections (including `rojas:kickstart` in the skills table)
- `CLAUDE.md` compatibility file created and points readers to `AGENTS.md`
- `.github/copilot-instructions.md` compatibility file created and points readers to `AGENTS.md`
- `schemas/` installed with task-format.md, approval-gates.md, spec-frontmatter.md
- `templates/openspec/progress.md` installed
- `scripts/sdd-preflight.sh` and `scripts/sdd-session-report.sh` installed
- No extra files created beyond the defined baseline

**Test script:**
```bash
# Run on sdd-fixture-greenfield
bash tests/verify-greenfield-install.sh
```

### 2. Brownfield install tests

**What to verify:**
- Existing source files untouched
- Existing AGENTS.md content preserved (unmarked sections not touched)
- Existing MCP config keys preserved after deep merge
- New rojas sections appended without disrupting existing content
- `openspec/` created without touching any existing code

### 3. Merge safety tests

**What to verify:**
- AGENTS.md section with same version: **skipped**
- AGENTS.md section with newer local version: **skipped** (repo is ahead)
- AGENTS.md section with older local version: **updated** (only the rojas markers)
- Content between custom markers: **never modified**
- Content before first rojas section: **preserved**
- Content after last rojas section: **preserved**

**Critical test case:** A repo that has manually added custom content inside an rojas-managed section (without proper markers). Expected behavior: the section update replaces only what is between the rojas markers. Custom content outside markers is safe.

### 4. Non-destructive update tests

**What to verify:**
- Re-running sync on an already-synced repo: produces no diff (idempotent)
- Upgrading from v1.0 to v1.1 of a skill: updates the skill file
- Downgrading attempt (repo has v1.2, template has v1.1): **skipped**

### 5. Profile install tests

For each profile (`frontend`, `backend-api`, `brownfield`, `high-risk`):
- Install baseline first, then profile: verifies no conflict
- Install profile on fresh repo: verifies baseline is also installed
- Install wrong profile for repo type: verifies warning is emitted but no error

### 6. Dry-run snapshot tests

Run dry-run on each fixture repo and snapshot the output. On any change to the installer, re-run dry-run and diff against snapshots.

```bash
# Generate snapshots
bash tests/snapshot-dry-run.sh > tests/snapshots/greenfield.txt
bash tests/snapshot-dry-run.sh sdd-fixture-brownfield > tests/snapshots/brownfield.txt
# etc.

# Verify against snapshots (CI)
bash tests/verify-snapshots.sh
```

### 7. MCP config merge tests

**What to verify:**
- JSON deep merge preserves existing keys at all nesting levels
- JSON deep merge adds new server keys from template
- JSON deep merge does not duplicate existing servers
- TOML merge appends new sections, does not duplicate or modify existing
- AIRIS URL substitution works correctly
- `context7_enabled=false` removes context7 from merged config

**Test inputs:** Fixture JSON files in `tests/fixtures/mcp/`.

### 8. Claude Code specific tests

- Verify `CLAUDE.md` compatibility file is created on greenfield
- Verify `CLAUDE.md` file is not overwritten when it already exists as a real file
- Verify skills are loadable as slash commands (naming convention check)
- Verify builder/verifier separation is documented in AGENTS.md sections
- Verify no local-only MCP configs are committed by the baseline sync

### 9. PR flow tests

- Baseline sync with `pr_enabled=true`: verify PR is created with correct title, body, labels
- Second sync run: verify stale PR is closed and new PR opened
- Dry run with `pr_enabled=true`: verify no PR is created, no branch pushed
- Missing `github_token` with `pr_enabled=true`: verify error is thrown, not silently ignored

### 10. User interaction gate tests

**What to verify:**
- Orchestrator detects greenfield correctly (no project-stack AND no source code dirs) and outputs the 📥 intake message
- Orchestrator detects brownfield correctly (existing code but no project-stack) and runs agent-prep instead
- Planner does not begin decomposition until orchestrator confirms PRD/backlog was received (greenfield)
- Agent-prep runs AFTER wave plan approval for greenfield, BEFORE planning for brownfield
- Every agent that writes a spec/proposal/tasks.md outputs the 📋 validation gate before proceeding
- Every agent outputs the ❓ clarification gate when encountering ambiguity (not for inferable information)
- Validator outputs the ✅ manual test checklist with at least 3 specific items after PASS
- Gate message formats match the standardized formats defined in `schemas/approval-gates.md`
- Task format matches `schemas/task-format.md`
- Spec frontmatter matches `schemas/spec-frontmatter.md`

### 11. Idempotency test (critical)

Run the full sync twice in sequence on the same repo. The second run must produce **zero changes**. Any diff on the second run is a bug.

```bash
bash tests/test-idempotency.sh sdd-fixture-greenfield
# Expected: "No changes to commit" on second run
```

---

## CI for the Standard Repo

Add a GitHub Actions workflow to `claude-dev-suit` itself that runs on every PR:

```yaml
# .github/workflows/test-installer.yml
on: [pull_request]

jobs:
  test-greenfield:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run on empty repo
        run: bash tests/run-installer-test.sh greenfield

  test-brownfield:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run on fixture brownfield repo
        run: bash tests/run-installer-test.sh brownfield

  test-idempotency:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run twice, verify second run produces no diff
        run: bash tests/test-idempotency.sh

  test-merge-safety:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Verify non-destructive merge behavior
        run: bash tests/test-merge-safety.sh
```

---

## Pre-Rollout Checklist

Before enabling the org-wide ruleset (`Active` enforcement):

- [ ] All 10 test categories pass in CI
- [ ] Dry-run snapshots verified on all 8 fixture repos
- [ ] At least 3 real repos successfully synced and reviewed by a human
- [ ] Pilot team reports no unexpected changes to existing files
- [ ] Rollback procedure tested and confirmed working
- [ ] No HIGH severity issues in verify step on pilot repos
- [ ] Governance doc reviewed and approved by engineering lead

---

## Test File Organization

```
tests/
  fixtures/
    mcp/
      existing-claude-mcp.json       # Existing config with custom keys
      expected-merged-claude-mcp.json
    agents/
      existing-with-custom-sections.md
      expected-merged-agents.md
    skills/
      old-version-rojas-explore.md
  snapshots/
    greenfield.txt
    brownfield.txt
    partial-upgrade.txt
    custom-agents.txt
  run-installer-test.sh
  test-idempotency.sh
  test-merge-safety.sh
  verify-snapshots.sh
  verify-greenfield-install.sh
  snapshot-dry-run.sh
```

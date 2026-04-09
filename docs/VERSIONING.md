# Versioning and Upgrade Strategy

---

## Versioning Scheme

### Baseline (Layer 2)

Skills and AGENTS.md sections use **semantic versioning** tracked in frontmatter/HTML markers:

```yaml
# skills/rojas-explore/SKILL.md
version: 1.2.0
```

```html
<!-- rojas:section:sdd-workflow:1.2.0 -->
```

Version bump rules:
- **PATCH** (1.1.0 → 1.1.1): Wording fixes, clarifications, typo corrections
- **MINOR** (1.1.0 → 1.2.0): New steps in a skill, new conventions, additive changes
- **MAJOR** (1.1.0 → 2.0.0): Breaking change to skill flow, removal of a skill, structural change to AGENTS.md sections

### Profiles (Layer 3)

Each profile has its own semantic version independent of the baseline:
```
profiles/frontend.md → version: 1.0.0
profiles/high-risk.md → version: 1.1.0
```

Profile versions are bumped separately from baseline. A baseline upgrade does not force a profile upgrade.

### Action version (sync mechanism)

The GitHub Action version is tracked via Git tags: `v1`, `v1.2`, `v20260301`.

Date-based versions (`YYYYMMDD`) are used as the default deploy tag since they are unambiguous and sortable.

### OpenSpec (Layer 1)

OpenSpec has its own independent release cycle. The pinned version used by the action is in `action.yml`:
```yaml
npx @fission-ai/openspec@latest init --yes
```

When promoting a specific OpenSpec version, replace `latest` with a pin:
```yaml
npx @fission-ai/openspec@1.4.0 init --yes
```

---

## Upgrade Process

### Baseline upgrade (skills + AGENTS.md sections)

1. Update the skill file or AGENTS.md template with a version bump
2. Open a PR to `claude-dev-suit` with the change
3. After merge, the next sync to any repo will apply the new version (if newer than what's installed)
4. Target repos with the old version see the update on their next PR (via ruleset) or manual sync

**No forced upgrades.** If a repo pins to a version, it stays pinned until explicitly re-synced.

### Profile upgrade

1. Update the profile file with a version bump and changelog note
2. Repos that have the profile installed will receive the update on next sync with the profile flag
3. Repos that don't use the profile: unaffected

### Breaking changes (MAJOR version)

For MAJOR version bumps to any skill or AGENTS.md section:
1. Bump version to `X.0.0` in the source
2. Add migration note in `docs/MIGRATION.md` (create if needed)
3. Run a targeted dry-run across all affected repos before enabling in ruleset
4. Announce via org engineering channel before enabling broad rollout
5. Keep a compatibility shim for one minor cycle, then remove

### OpenSpec version pin changes

When upgrading the OpenSpec pin in `action.yml`:
1. Test locally with `npx @fission-ai/openspec@<new-version>` in a fresh repo
2. Verify all `opsx:*` commands still work with the wrapped rojas:* skills
3. Update all skill files that reference specific opsx commands
4. Tag the release with the OpenSpec version in the release notes

---

## Dry-Run Diff Reports

Before any upgrade, preview what will change:

```bash
# Diff against a single repo
gh workflow run sdd-sync-targeted.yml \
  -R Sreddx/claude-dev-suit \
  -f repos="my-repo" \
  -f dry_run="true"

# Diff across all repos (audit mode)
gh workflow run sdd-sync-targeted.yml \
  -R Sreddx/claude-dev-suit \
  -f repos="all" \
  -f exclude="claude-dev-suit" \
  -f dry_run="true"
```

Dry-run output shows:
- Which AGENTS.md sections would be updated (old version → new version)
- Which skills would be installed or updated
- Which repos are already up to date
- Which repos have a newer semantic version (would be skipped; no downgrade)

---

## Rollback

### Option 1: Reject the PR (preferred)

Since the standard always creates a PR before merging, rejecting the PR is the primary rollback mechanism. Close the PR, and the repo remains on its previous version.

### Option 2: Revert the commit

If a sync was merged and needs to be reverted:
```bash
# Find the sync commit
git log --oneline | grep "chore(sdd)"

# Revert it
git revert <commit-sha>
git push
```

The sync commit message format `chore(sdd): sync claude-dev-suit v{VERSION}` makes it trivially identifiable.

### Option 3: Pin to a prior version

To lock a repo to a specific prior version:
```bash
gh workflow run sdd-sync-targeted.yml \
  -R Sreddx/claude-dev-suit \
  -f repos="my-repo" \
  -f version="20260101"
```

This re-syncs to the state of `claude-dev-suit` as of that date tag.

---

## Compatibility Matrix

| Baseline version | Compatible OpenSpec | Supported tools |
|---|---|---|
| v1.x | @latest | Claude Code, Cursor, Copilot, Codex, OpenCode |
| v2.x | @1.4+ | Claude Code, Cursor, Copilot, Codex, OpenCode, Gemini CLI |

Maintain this table in the repo as new versions are released.

---

## Version Audit

To audit which version each repo is running:

```bash
# Check a single repo's AGENTS.md sections
grep "rojas:section" target-repo/AGENTS.md

# Check a single repo's skill versions
grep "^version:" target-repo/.claude/skills/rojas-*/SKILL.md
```

A proper adoption dashboard (tracking all repos centrally) is on the roadmap.

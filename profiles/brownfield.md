---
name: brownfield
version: 1.0.0
description: Profile for repos with large existing codebases and no prior SDD artifacts
applies_to: Repos with significant existing code, technical debt, or no openspec/ structure
layer: 3
---

# Brownfield Profile

This profile activates enhanced context-building behavior for repos where the codebase predates SDD adoption. It makes the first SDD cycle safe, informed, and non-disruptive.

## Greenfield PRD gate — skipped for brownfield

The `rojas:kickstart` PRD/backlog intake gate is a **greenfield-only** gate. Brownfield repos skip it entirely — instead, `rojas:explore` serves as the planning input source. The existing codebase IS the context, and agent-prep scans it to generate project-stack before any planning begins.

## The brownfield problem

In greenfield repos, the spec is the source of truth. In brownfield repos, the code is the source of truth — and the spec must be derived from it. Brownfield repos have:
- Implicit conventions that are not written down
- Hidden dependencies between modules
- Accumulated technical debt that must not be inadvertently woken up
- Existing tests with possibly incomplete coverage

The SDD standard must respect this. A brownfield install must not pretend the codebase doesn't exist.

## What this profile adds

### Mandatory project memory initialization

On first `rojas:explore` in a brownfield repo, the skill is required (not optional) to:
1. Detect existing source code
2. Check serena for existing project memory
3. If no memory exists: scan key files and generate a project memory document before proceeding

This is enforced via the profile — in the baseline, project memory generation is prompted. With this profile, it is mandatory.

### Additional AGENTS.md section

```markdown
<!-- rojas:section:brownfield-conventions:1.0.0 -->
## Brownfield Conventions

### First-time setup (mandatory)
Before the first SDD cycle in this repo, project memory MUST be generated:
1. Run `rojas:explore` — it will detect the brownfield context
2. Approve the project memory scan when prompted
3. Review the generated memory at `.agent/memory/project-context.json`
4. Correct any inaccuracies before proceeding

### SDD in existing code
- Do NOT refactor existing code as part of a new feature spec
- Scope each change to the minimum necessary — preserve existing patterns
- If existing code contradicts the proposed spec, surface the conflict in the proposal, do not silently adapt
- All new code must follow the existing conventions documented in project memory

### Risk awareness
- Before any task that touches a core module, check project memory for `known_constraints`
- If project memory is stale (> 90 days), re-run `rojas:explore` to refresh it
- Flag any task that would require touching more than 2 legacy modules simultaneously

### What the project memory tracks
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
<!-- /rojas:section:brownfield-conventions -->
```

### Profile-specific skill behavior overrides

**`rojas:explore`** becomes mandatory-memory mode:
- Project memory generation is required, not prompted
- Reports stale memory (> 90 days old) as a warning

**`rojas:propose`** adds:
- Conflict check: does the proposal require changes that contradict project memory conventions?
- Scope limiter: flag if proposal touches > 2 existing core modules

**`rojas:implement`** adds:
- Pre-task check: reads relevant section of project memory before each task
- Does not generate new patterns if existing equivalent patterns exist in the codebase

## Installation

```bash
gh workflow run sdd-sync-targeted.yml \
  -R Sreddx/claude-dev-suite \
  -f repos="legacy-monolith" \
  -f profile="brownfield"
```

## Upgrade path

Once a brownfield repo has been fully onboarded (project memory exists, first SDD cycles completed successfully), consider removing this profile and switching to the baseline or a more specific profile.

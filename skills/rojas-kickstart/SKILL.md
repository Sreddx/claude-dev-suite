---
name: rojas:kickstart
version: 1.2.0
description: >
  Use when bootstrapping a new greenfield project or doing an initial full plan decomposition.
  Guides the agent through collecting PRD and backlog input from the user, parsing it into
  structured epics and user stories, generating the openspec decomposition, deriving a
  descriptive change name, and proposing implementation waves for approval before any files
  are written.
triggers: ["kickstart", "greenfield", "new project", "bootstrap project", "start from scratch"]
layer: 2
wraps: rojas:explore, rojas:propose
phase: explore → propose
applies-to: orchestrator, planner
mcp_dependencies: []
compatible_tools: [claude-code, cursor, opencode, codex, copilot]
---

# rojas:kickstart

## When to use
Invoke at the start of any greenfield project or when asked to create an initial plan from scratch.
Do NOT invoke for brownfield or incremental feature work.

## Scope check before bootstrap

If the PRD/backlog spans >1 epic or >8 stories, the orchestrator must decompose
into multiple changes BEFORE invoking kickstart for artifact generation.
kickstart generates artifacts for ONE change at a time.

Invoke the scope decomposition gate in orchestrator.md first. Present the decomposition to the user
and get approval. Only then invoke kickstart per-change sequentially.

## Step 1 — Detect project type
- If `project-stack` section is absent from AGENTS.md AND no source code directories exist → GREENFIELD
- If either condition is met → BROWNFIELD → skip to `rojas:explore`

## Step 2 — Request PRD and backlog (greenfield only)
Output the intake request message (see orchestrator.md). Wait for user input.
Do not proceed without it or explicit user override ("proceed without PRD").

```
---
📥 **Project input required before planning**

To kick off this greenfield project I need the following input. Please provide what you have — partial input is fine, I'll work with what's available:

### 1. PRD (Product Requirements Document)
A document describing what we're building. Can be a markdown doc, Notion export, Google Doc link, or paste the content directly.

Minimum useful content:
- Product vision / problem statement
- Target users / personas
- Key features and goals
- Non-functional requirements (performance, security, scale)
- Out of scope

### 2. Backlog (User Stories or Feature List)
A list of features, epics, or user stories. Preferred format:

| ID | Epic | User Story | Priority | Acceptance Criteria | Technical Notes |
|----|------|------------|----------|---------------------|-----------------|
| US-001-01 | EP-001 | As a [role], I want [goal], so that [reason] | Critical/High/Medium/Low | GIVEN/WHEN/THEN | stack notes |

Accepted formats: XLSX, CSV, Markdown table, Notion/Linear/Jira export, or plain list.

---
Once you provide these, I will:
1. Parse and summarize what I understood
2. Ask clarifying questions if anything is ambiguous
3. Propose a descriptive change name for your approval
4. Propose epics → openspec spec decomposition for your approval
5. Define implementation waves for your approval before any files are written

Reply with your PRD and/or backlog to continue.
---
```

## Step 3 — Parse input
From the provided PRD and/or backlog extract:
- Product vision, target users, key features, non-functional requirements, out of scope
- Epics, user stories, priorities, acceptance criteria, technical notes
- Output a structured summary table for user confirmation

Summary format:

```
### Parsed summary

| Metric | Value |
|--------|-------|
| Epics | N |
| User stories | N |
| Critical priority | N |
| High priority | N |
| Medium priority | N |
| Low priority | N |
| Total story points | N (if available) |

### Epics overview
| Epic ID | Name | Story count | Priority spread |
|---------|------|-------------|-----------------|
| EP-001 | ... | N | N critical, N high, ... |
```

## Step 4 — Ask clarifying questions
Using the ❓ clarification format, ask about genuine ambiguities only:
- Tech stack if not specified
- Deployment target if not specified
- Conflicting priorities or missing acceptance criteria
- Integration dependencies not mentioned

```
---
❓ **Clarification needed**

Before I continue, I need to clarify the following:

1. [Question 1]
2. [Question 2 — only if truly needed]

Please reply with your answers and I'll proceed.
---
```

## Step 5 — Propose openspec decomposition
Map epics to openspec spec files. Propose which epics become which specs under `openspec/specs/`.

For any spec that will be implemented across more than one wave, note that the spec file must
contain explicit `## Wave N — [scope]` sections so tasks can reference the specific slice.

Present for user approval using the 📋 format before creating any files.

```
---
📋 **Validation required before proceeding**

I've prepared the following openspec decomposition:

| Spec file | Classification | Covers epics | Stories | Multi-wave? |
|-----------|---------------|-------------|---------|-------------|
| `openspec/specs/auth.md` | capability | EP-001 | US-001-01, US-001-02 | No |
| `openspec/specs/dashboard.md` | capability | EP-002 | US-002-01–03 | No |
| `openspec/specs/stage2-project.md` | stage | EP-009–EP-015 | US-009-01–015-04 | Yes (Wave 3 + Wave 4) |
| ... | ... | ... | ... | ... |

Spec classifications: foundation · capability · stage · cross-cutting
(See `schemas/artifact-classification.md` for definitions.)

Please review and reply with one of:
- ✅ **Approved** — to proceed to change name proposal
- ✏️ **Feedback: [your notes]** — to request changes before I continue

I will not proceed until you approve.
---
```

## Step 5.5 — Derive and approve change name

**This step is mandatory. Do not create any folders before the change name is approved.**

Based on the PRD and the scope of this bootstrap, derive a descriptive kebab-case change name.

**Naming rules (enforced, not optional):**
- Format: `verb-scope-outcome`
- Must describe what this change accomplishes, derived from the PRD scope
- **Numeric IDs are strictly prohibited** — `1`, `change-1`, `update`, `misc`, or any pure number are all invalid
- If you cannot derive a name, ask the user — do not default to a number

Good examples:
- `bootstrap-client-portal-mvp`
- `introduce-auth-and-admin-core`
- `launch-proposal-stage`
- `add-notification-service`

Bad examples (never use):
- `1`, `2`, `change-1`, `update`, `misc`, `fix`

Present the proposed name for approval:

```
---
📋 **Validation required before proceeding**

Proposed change name for this bootstrap:

`openspec/changes/<proposed-change-name>/`

This name will be used for all planning artifacts, referenced in every commit message,
and passed to the OpenSpec engine (`opsx:propose` or `opsx:new`) to create the canonical change folder.

Please reply with:
- ✅ **Approved** — to proceed with wave planning
- ✏️ **Different name: [your name]** — I'll use yours instead (must be kebab-case verb-scope-outcome)
---
```

## Step 6 — Propose implementation waves
Based on dependencies and priorities, propose wave groupings.

For specs that span multiple waves, list them with explicit wave-slice labels so tasks can
reference the correct section of the spec:

| Wave | Specs / Wave slices | Dependencies | Rationale |
|------|---------------------|--------------|-----------|
| 0 | `foundation.md` | none | Foundation must exist first |
| 1 | `auth.md`, `admin-core.md` | Wave 0 | Auth gates every route |
| 3 | `stage2-project.md § Wave 3` | Wave 2 | Core day-to-day screens |
| 4 | `stage2-project.md § Wave 4` | Wave 3 | Completes Stage 2 |

Present for user approval using the 📋 format.
Do not call `opsx:new` or create any files until approved.

```
---
📋 **Validation required before proceeding**

I've prepared the implementation wave plan. Please review and reply with one of:
- ✅ **Approved** — to proceed with project bootstrap
- ✏️ **Feedback: [your notes]** — to request changes before I continue

I will not proceed until you approve.
---
```

## Step 7 — Bootstrap project artifacts (delegation required)

Only after the wave plan is approved. Execute in this exact order:

1. **Delegate to agent-prep** — scan and write the `project-stack` section to AGENTS.md
2. **Delegate to planner agent** with the following context:
   - Approved spec decomposition from Step 5
   - Approved wave plan from Step 6
   - Approved change name from Step 5.5
   - Tech stack decisions from Step 4
   - Parsed PRD/backlog summary from Step 3
   
   The planner will:
   a. Check openspec/config.yaml for the active profile
   b. Invoke the appropriate opsx commands (see rojas:propose)
   c. Write proposal.md, design.md, delta specs, and tasks.md
   d. Enrich tasks.md with rojas metadata (see `schemas/task-format.md`)
   e. Create handoff.md if multi-wave
   f. Present the 📋 approval gate

3. **Wait for planner to complete and report back**
4. **Verify artifacts exist** — check that all expected files are present in `openspec/changes/<change-name>/`
5. **Update progress** — create/update `openspec/changes/<change-name>/progress.md` (see `templates/openspec/progress.md`)

YOU (orchestrator) DO NOT WRITE ANY OF THESE FILES. The planner does.
If planner reports an error, ask the user for guidance. Do not attempt to write files as fallback.

### Post-generation validation

After planner completes, orchestrator MUST verify:
- [ ] All delta specs are in `openspec/changes/<change-name>/specs/` — NOT in `openspec/specs/`
- [ ] All spec files have frontmatter matching `schemas/spec-frontmatter.md`
- [ ] `tasks.md` uses opsx checkbox format (`- [ ] N.N`) with rojas sub-bullets per `schemas/task-format.md`
- [ ] No files were created directly in `openspec/specs/`
- [ ] Change folder name is kebab-case (verb-scope-outcome)

If any check fails, report to user and ask planner to fix before proceeding.

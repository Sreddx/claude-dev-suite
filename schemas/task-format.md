# Task format — opsx-compatible + rojas-enriched

OpenSpec's `opsx:apply` toggles `- [ ] N.N` checkboxes. `opsx:verify` reads completion from those lines.
The rojas orchestration layer reads indented sub-bullets for wave dispatch, profile assignment, and dependency analysis.

**Never replace the opsx checkbox line. Add rojas metadata as indented sub-bullets beneath it.**

## Required fields per task

- [ ] N.N Task title here
  - **Change:** <change-name>
  - **Spec:** `openspec/changes/<change-name>/specs/<capability>.md`
  - **Spec wave slice:** <`## Wave N — [scope]` section name, or `n/a`>
  - **Stories:** <US-XXX-YY, ...>
  - **Owner profile:** <frontend | backend | database | fullstack>
  - **Dependencies:** <N.N, N.M | none>
  - **Definition of done:** <what must be true>
  - **Verification gate:** <test command, Playwright check, or opsx:verify assertion>
  - **mockup_ref:** <Figma node URL, file path, or `n/a`>

## Rules

- `Owner profile` determines which implementer receives the task
- `Verification gate` is what `rojas:verify` checks for correctness
- `mockup_ref` is required on all frontend tasks
- For multi-repo: add `- **Repo:** <repo-key>` as a sub-bullet
- `Spec wave slice` is mandatory when a spec spans multiple waves
- Tasks that cannot satisfy these fields must be split or clarified before proceeding

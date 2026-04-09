---
name: frontend
version: 1.0.0
description: Profile for frontend-heavy repos (React, Vue, Angular, etc.)
applies_to: Repos where the primary output is UI components, pages, or browser-based apps
layer: 3
---

# Frontend Profile

This profile extends the SDD baseline for repos where frontend work is the primary concern.

## What this profile adds

### Additional AGENTS.md section

```markdown
<!-- rojas:section:frontend-conventions:1.0.0 -->
## Frontend Conventions

### UI implementation rules
- Every UI task must include at least one Playwright test verifying the rendered output
- UI components are generated via Magic (natural language → component) where possible
- All visual changes must be verified in a real browser, not just unit tests
- Accessibility: every interactive component must pass a basic a11y snapshot check

### Tool activation (auto-detect by rojas:implement)
- Task mentions UI / component / page / layout / CSS / form / button / modal → frontend profile active
- Active tools: Magic (component generation) + Playwright (browser testing) + context7 (framework docs)

### Playwright conventions
- Test file: `<component>.test.ts` co-located with the component
- Each test: navigate → snapshot → interact → assert
- Snapshot baseline stored in `tests/snapshots/`
- Browser: Chromium (default), add Firefox for critical flows

### Magic conventions
- Provide: component name, props interface, visual description, framework version
- Magic respects the repo's code style if a `.prettierrc` or `eslint.config.js` is present
- Always review generated component before accepting — do not auto-commit Magic output

### Context budgeting for frontend tasks
- Load: relevant component files, design system tokens (if any), framework docs from context7
- Do NOT load: backend service files, database schemas, or infrastructure configs
<!-- /rojas:section:frontend-conventions -->
```

### Profile-specific skill behavior overrides

When `profile=frontend` is active:

**`rojas:implement`** activates the frontend sub-profile:
- Prioritizes Magic for component generation
- Requires Playwright test for every UI-facing task
- context7 fetches React/Vue/Angular docs for the detected framework version
- WarpGrep (Morphllm) scans for existing component patterns before generating new ones

**`rojas:verify`** adds frontend-specific checks:
- Playwright snapshot test exists for each component
- No hardcoded colors or spacing (design system tokens preferred)
- Component props are typed (TypeScript) or documented (JSDoc)
- Accessibility: aria-labels on interactive elements

## Installation

This profile is installed alongside the baseline when `profile=frontend` is specified:

```bash
gh workflow run sdd-sync-targeted.yml \
  -R Sreddx/claude-dev-suit \
  -f repos="my-frontend-app" \
  -f profile="frontend"
```

## What stays local

Even with the frontend profile:
- Playwright and Magic MCP server configs are **local only** (local-packs)
- Storybook or design tool integrations are per-developer preference
- Browser credentials, screenshot baseline storage locations are never committed

## Animation skills (GSAP)

When the frontend profile is active and `gsap` is detected in package.json, the following skills are available to the frontend and tester-front agents:

Install: `npx skills add https://github.com/greensock/gsap-skills`

Skills provided:
| Skill | When to use |
|-------|-------------|
| gsap-core | Any GSAP tween: gsap.to(), .from(), .fromTo(), easing, stagger |
| gsap-timeline | Sequencing animations, position parameter, labels, nesting |
| gsap-scrolltrigger | Scroll-linked animations, pinning, scrub, trigger/end markers |
| gsap-plugins | Flip, Draggable, SplitText, MotionPath, ScrollSmoother |
| gsap-react | useGSAP hook, refs, gsap.context(), cleanup, SSR safety |
| gsap-performance | Transforms over layout props, will-change, batching, ScrollTrigger refresh |
| gsap-frameworks | Vue/Svelte lifecycle, scoping, cleanup on unmount |
| gsap-utils | clamp, mapRange, normalize, snap, toArray, pipe |

These skills prevent the most common GSAP mistakes agents make:
- Using gsap.context() instead of useGSAP hook in React
- Forgetting ScrollTrigger.refresh() after DOM changes
- Animating layout properties (width, height, top, left) instead of transforms
- Missing cleanup on component unmount causing memory leaks

## Upgrade path

Profile version bumps are independent of baseline. Re-run sync with `profile=frontend` to upgrade.

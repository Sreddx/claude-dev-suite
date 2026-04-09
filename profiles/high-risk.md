---
name: high-risk
version: 1.0.0
description: Profile for repos handling auth, payments, PII, or compliance requirements
applies_to: Repos tagged as critical; repos handling financial data, user credentials, or regulated PII
layer: 3
---

# High-Risk Profile

This profile activates mandatory human review gates, enhanced guardrails, and audit-trail requirements for repos where the cost of a mistake is high.

## Scope

Apply this profile to repos that:
- Handle user authentication, authorization, or session management
- Process payments, billing, or financial transactions
- Store or process PII (names, emails, health data, financial data)
- Are subject to compliance requirements (SOC2, PCI-DSS, HIPAA, GDPR)
- Are designated as "critical" by the engineering or security team

## What this profile adds

### Mandatory human review gates

All changes in a high-risk repo require:
1. **Spec review**: Proposal must be reviewed and approved by a human before implementation begins. `rojas:propose` outputs a checklist — it must be checked by a human, not just the spec-reviewer sub-agent.
2. **Security review**: Any spec touching auth, payments, or PII must be reviewed by a security-aware team member.
3. **PR second reviewer**: All PRs from SDD sync and all implementation PRs require 2 human approvers (not 1).

These are enforced at the skill level: skills will emit a `[GATE]` event and pause when a gate is reached.

### Additional AGENTS.md section

```markdown
<!-- rojas:section:high-risk-conventions:1.0.0 -->
## High-Risk Conventions

### Non-negotiable rules
- No auth, payments, or PII changes without prior spec approval by a human
- No credentials, tokens, or API keys in any spec file, task file, or agent output — ever
- No destructive database migrations (DROP, TRUNCATE, column removal) without a separate pre-migration review
- Every change to auth or payment flows requires a rollback plan in the spec

### Mandatory documentation in spec
All proposals for this repo must include:
- Threat model section: who can misuse this feature and how?
- Data classification: what data does this touch, at what sensitivity level?
- Rollback plan: how is this change reversed if it causes issues in production?
- Audit trail: does this change generate appropriate logs for compliance?

### Escalation (auto-escalate, do not proceed)
The SDD tooling will escalate to a human (not retry) when:
- A task touches > 1 auth/payment component simultaneously
- A sub-agent fails a task that involves credential handling
- The verify step finds any HIGH severity issue
- Implementation scope has grown beyond the approved spec

### Secret pattern check
Before any commit, the agent checks for secret patterns:
- API key patterns (sk-*, pk-*, AKIA*, etc.)
- Hardcoded passwords or tokens
- Connection strings with credentials embedded
Any match is treated as a BLOCKER — commit is halted, human review required.
<!-- /rojas:section:high-risk-conventions -->
```

### Profile-specific skill behavior overrides

**All skills** emit `[GATE: HIGH-RISK]` before each phase transition and pause for human acknowledgment when running interactively.

**`rojas:propose`** adds:
- Threat model template in the proposal scaffold
- Data classification checklist
- Mandatory rollback plan section
- Outputs a HUMAN REVIEW REQUIRED notice before proceeding

**`rojas:implement`** adds:
- Pre-commit secret pattern scan on all modified files
- Prohibits more than 1 auth/payment module modification per task
- Any task failure escalates immediately (no retry loop)

**`rojas:verify`** adds:
- Secret pattern scan on all spec artifacts (proposal, tasks, design)
- Authentication boundary check: new code paths that bypass auth are BLOCKERS
- Compliance annotation check: PII fields must be annotated or documented
- HIGH severity issues halt the verify flow — not reported as warnings

## Installation

```bash
gh workflow run sdd-sync-targeted.yml \
  -R Sreddx/claude-dev-suit \
  -f repos="payment-service,auth-service" \
  -f profile="high-risk"
```

## Important: this profile requires organizational setup

The human review gates in this profile require:
- Branch protection with `required_reviewers >= 2` configured on the target repo
- A designated security reviewer with write access

Without these configurations, the gate annotations are advisory only. The profile will warn if required settings are not detected.

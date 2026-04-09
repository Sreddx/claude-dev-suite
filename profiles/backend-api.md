---
name: backend-api
version: 1.0.0
description: Profile for REST/GraphQL API repos
applies_to: Repos that expose HTTP APIs, integrate with external services, or own data schemas
layer: 3
---

# Backend API Profile

This profile extends the SDD baseline for repos where the primary output is an API, service, or data layer.

## What this profile adds

### Additional AGENTS.md section

```markdown
<!-- rojas:section:backend-api-conventions:1.0.0 -->
## Backend/API Conventions

### Contract-first rules
- Every new or modified endpoint must have an OpenAPI spec entry before implementation begins
- Breaking API changes (removed fields, changed types, renamed endpoints) require a migration note in the spec
- gRPC: proto file changes are part of the spec, not an implementation detail

### Test requirements
- Every new endpoint: integration test (real DB or contract mock) + unit tests for business logic
- No mocking of the database in integration tests — use test containers or a real test DB
- Contract tests preferred over end-to-end tests for external API integrations

### Data schema changes
- Migrations must be: additive first (add nullable column), then backfill, then constrain
- No destructive migrations in the same PR as application changes
- Migration files are named: `YYYYMMDD_description.sql` (or framework equivalent)
- Verify step checks that migration is reversible before allowing archive

### Security defaults
- All new endpoints authenticated by default; unauthenticated is the opt-in exception (must be documented in spec)
- Input validation at the boundary (request body, query params) before any business logic
- Sensitive fields (passwords, tokens) never logged, never in response bodies

### Context budgeting for API tasks
- Load: relevant service files, schema files, OpenAPI spec, integration test fixtures
- Do NOT load: frontend files, UI components, or CSS
<!-- /rojas:section:backend-api-conventions -->
```

### Profile-specific skill behavior overrides

**`rojas:propose`** adds:
- OpenAPI spec validation step before finalizing proposal
- Checks for breaking change patterns and flags them explicitly

**`rojas:implement`** enforces:
- General profile (Morphllm FastApply + WarpGrep) — no frontend tools
- Integration test requirement for every new endpoint
- Migration safety check before any schema change task

**`rojas:verify`** adds:
- API contract check: does the implementation match the OpenAPI spec?
- Security check: are all new endpoints authenticated?
- Migration reversibility check

## Installation

```bash
gh workflow run sdd-sync-targeted.yml \
  -R Sreddx/claude-dev-suite \
  -f repos="my-api-service" \
  -f profile="backend-api"
```

## What stays local

- Database connection strings and test DB credentials
- External API keys for integration testing
- Load testing tool configurations

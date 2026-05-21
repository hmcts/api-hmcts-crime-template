# CLAUDE.md — HMCTS Crime API Template Repository

This is the **HMCTS Crime API template repository** for OpenAPI v3.x spec authoring.
It provides a standardised structure, naming conventions, and validation tooling for
building HMCTS Marketplace APIs on the Common Platform.

## Repository Structure

| Path | Purpose |
|------|---------|
| `src/main/resources/openapi/` | OpenAPI v3.x specification files (YAML) |
| `src/main/resources/openapi/schema/` | Shared JSON Schema `$ref` components |
| `.spectral.yml` | Spectral ruleset for automated linting in CI |
| `.claude/skills/` | Claude skill definitions for AI-assisted review |
| `docs/` | Supporting documentation (versioning, conventions, etc.) |

## Validation Layers

There are two complementary validation layers in this repository:

### 1. Spectral — Structural/Syntactic Linting (CI)

Spectral runs automatically in CI via GitHub Actions and checks the OpenAPI spec
for structural correctness, OAS3 rule compliance, and schema validity.
See `.spectral.yml` for the active ruleset.

### 2. Claude Skill — Policy-Aware Review

The `openapi-spec-reviewer` skill (`.claude/skills/openapi-spec-reviewer/SKILL.md`)
provides a complementary review layer that Spectral cannot perform. It applies
four policy lenses drawn from HMCTS knowledge documents:

- **Data Sharing Policy** — checks data classification, PII exposure, and consent
- **Infrastructure SLA** — validates response time targets, timeout declarations, and rate limits
- **HMCTS API Standards** — enforces naming conventions, versioning, and RESTful design rules
- **Security Standards** — reviews authentication, authorisation, transport security, and input validation

Invoke the skill by pasting your OpenAPI spec (YAML or JSON) into a Claude Code
session and running `/openapi-spec-reviewer`.

## Key Conventions

- OpenAPI version **3.x only** — v2 (Swagger) specs are not supported
- One API specification per repository
- Spec file: `src/main/resources/openapi/openapi-spec.yml`
- Repository naming follows `api-{source-system}-[case-type]-{business-domain}-{entity}`
- Do not use ambiguous names: `common`, `core`, `base`, `utils`, `helpers`, `misc`, `shared`

## Useful Links

- [HMCTS RESTful API Standards](https://hmcts.github.io/restful-api-standards/)
- [OpenAPI File Conventions](./docs/OPENAPI-FILE-CONVENTIONS.md)
- [API Versioning Strategy](./docs/API-VERSIONING-STRATEGY.md)
- [GitHub Actions Setup](./docs/GITHUB-ACTIONS.md)
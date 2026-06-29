# API Contract Rules & Guidelines

> **Purpose:** A single reference for designing, structuring and evolving HMCTS Common Platform API contracts (OpenAPI specifications). It captures the conventions already used across our `api-*` repositories so that every new API looks, behaves and versions consistently.
>
> **Authoritative external standard:** All API definitions should follow the [HMCTS RESTful API Standards](https://hmcts.github.io/restful-api-standards/). This page is the practical, opinionated companion to those standards.

The language below uses **MUST / SHOULD / MAY** (per RFC 2119). *MUST* rules are enforced by tooling or review; *SHOULD* rules are strong recommendations you can deviate from with a documented reason.

---

## 1. Core principles

- **One API spec per repository.** Each repo contains a *single* OpenAPI specification. This matches our build and publish workflows, which expect exactly one spec.
- **Contract first.** The OpenAPI spec is the source of truth. Server and client code are generated from it, not the other way around.
- **Design for evolution.** Additive, backwards-compatible change is the norm. Breaking change is a deliberate, versioned event (see [§6 Versioning](#6-versioning)).
- **Consistency over cleverness.** A consumer who has integrated with one of our APIs should find the next one familiar — same error shape, same auth, same naming.

---

## 2. Repository & file conventions

### 2.1 Repository naming

Repository names go from generic to specific:

```
api-{source-system}-[case-type]-{business-domain}-{name-of-entity}
```

| Segment | Meaning | Examples |
|---|---|---|
| `source-system` | Owning system | `cp` (Common Platform), `dcs` (Crown Court Digital Case System), `sscs` (Social Security & Child Support) |
| `case-type` *(optional)* | Jurisdiction | `civil`, `crime`, `family`, `tribunal` |
| `business-domain` | Product/domain | `caseingestion`, `casematerial`, `caseadmin`, `casehearing`, `schedulingandlisting` |
| `name-of-entity` | The thing the API is about | `courtschedule`, `case-urn-mapper`, `courthouses` |

**Reference-data APIs** use:

```
api-cp-refdata-{product-domain}-{name-of-entity}
```

> ⚠️ **Avoid** vague names like `common`, `core`, `base`, `utils`, `helpers`, `misc` or `shared`. They invite ambiguous ownership and become dumping grounds. `product-domain` is **required** even for reference data — global ownership tends to mean *no* ownership.

### 2.2 Spec file location & naming

- The OpenAPI file **MUST** end with `.openapi.yml` (e.g. `prosecutor.openapi.yml`, `case-admin-doc-knowledge-api.openapi.yml`).
- It **MUST** live in:
  ```
  /src/main/resources/openapi/
  ```
- Only the **first** file matching `src/main/resources/openapi/*.openapi.yml` is used by the build.

### 2.3 Schemas live in the spec

- Define all schemas inline under `components.schemas`.
- **Do NOT** `$ref` external JSON Schema files. Even where technically supported, they do not render correctly in Swagger UI / SwaggerHub, and they hurt portability.

---

## 3. Required document structure

Every spec **MUST** include a consistent `info` block, server entry and (where it has more than one logical grouping) tags.

```yaml
openapi: 3.0.3
servers:
  - description: APIHub API Auto Mocking
    url: https://virtserver.swaggerhub.com/HMCTS-DTS/api-cp-crime-<entity>/0.0.0

info:
  title: Common Platform API <Domain> <Entity>
  description: <One-line purpose of the API>
  version: 0.0.0            # placeholder — see §6.3
  contact:
    email: no-reply@hmcts.com
  license:
    name: MIT
    url: 'https://opensource.org/licenses/MIT'

tags:
  - name: Court House
    description: Operations related to court house
```

Rules:

- `info.version` **MUST** be the placeholder `0.0.0`. The real version is injected automatically at build time (see [§6.3](#63-spec-versioning-is-automated)).
- `info.contact.email` **MUST** be `no-reply@hmcts.com`.
- `license` **MUST** be MIT, as shown.
- `title` **SHOULD** follow `Common Platform API <Domain> <Entity>` (or the established title for that system).
- Group operations with `tags`, each with a human-readable `description`.

---

## 4. Paths, operations & parameters

### 4.1 Paths

- Path segments are **lowercase nouns**, plural for collections: `/courthouses`, `/urnmapper`, `/query-catalogue`.
- Use multi-word segments with hyphens (`/query-catalogue`) — not camelCase.
- Model hierarchy through nesting: `/courthouses/{court_id}/courtrooms/{court_room_id}`.
- Do **not** put version numbers in the path — versioning is via the `Accept` header (see [§6](#6-versioning)).

### 4.2 Path & query parameters

- Path parameter names use **snake_case**: `{case_urn}`, `{court_id}`, `{court_room_id}`.
- Every parameter **MUST** have `description` and a typed `schema`. Identifiers that are UUIDs **SHOULD** declare `format: uuid` and a realistic `example`.
- Mark path parameters `required: true`. Optional behaviour belongs in query parameters with `required: false`.

```yaml
parameters:
  - in: path
    name: court_id
    required: true
    description: Unique identifier for the court house
    schema:
      type: string
      format: uuid
    example: "57323172-1083-454d-8ab7-2455a8b993e7"
  - in: query
    name: refresh
    required: false
    description: Refresh flag for cache
    schema:
      type: boolean
```

### 4.3 operationId

- Every operation **MUST** have a unique `operationId` in **camelCase**, verb-led, describing the action and key parameters:
  - `getCourthouseByCourtIdAndCourtRoomId`
  - `getCaseIdByCaseUrn`
  - `listQueryCatalogue`
- Use `get` / `list` / `create` / `update` / `delete` prefixes consistently. `operationId` drives generated client/server method names, so keep it stable.

### 4.4 Descriptions

- Every operation **MUST** have a `description` (and **SHOULD** have a short `summary` where the spec uses them).
- Every schema property **SHOULD** have a `description`. This is what consumers read in Swagger UI.

---

## 5. Responses & errors

### 5.1 Standard responses

- A successful read returns `200` with a JSON body referencing a named response schema.
- Document `400` for bad input and `401` for auth failures at minimum; add `404`, `409` etc. where the operation can produce them.

```yaml
responses:
  '200':
    description: Court details found
    content:
      application/json:
        schema:
          $ref: "#/components/schemas/CourtHouseResponse"
  '400':
    description: Bad input parameter
    content:
      application/json:
        schema:
          $ref: "#/components/schemas/ErrorResponse"
  '401':
    description: Your JWT token failed validation
```

### 5.2 The standard `ErrorResponse`

Every API **MUST** define and use this canonical error shape. Do not invent per-endpoint error bodies.

```yaml
ErrorResponse:
  type: object
  properties:
    error:
      type: string
      description: Machine-readable error code
    message:
      type: string
      description: Human-readable error message
    details:
      type: object
      additionalProperties: true
      description: Additional error context
    timestamp:
      type: string
      format: date-time
    traceId:
      type: string
      description: Unique identifier for error tracing
```

- `error` is a stable machine code clients can branch on; `message` is for humans.
- `traceId` **MUST** be populated so support can correlate an error with logs/telemetry.

---

## 6. Versioning

### 6.1 Media-type versioning (the contract clients see)

We follow GitHub's approach: **version is carried in the HTTP `Accept` header, not the URL**, using a vendor media type and Semantic Versioning.

```
application/vnd.hmcts.cp.v<MAJOR>[.<MINOR>[.<PATCH>]]+json
```

| Accept header | Behaviour |
|---|---|
| `application/vnd.hmcts.cp.v1+json` | Latest compatible `v1.x.x` *(recommended for clients)* |
| `application/vnd.hmcts.cp.v1.2+json` | Latest patch within `v1.2.x` |
| `application/vnd.hmcts.cp.v1.2.3+json` | Exactly `v1.2.3` |

Example request / response:

```bash
curl -H "Accept: application/vnd.hmcts.cp.v1+json" https://api.hmcts.service.gov.uk/cases
```
```http
HTTP/1.1 200 OK
Content-Type: application/vnd.hmcts.cp.v1.4.2+json
Vary: Accept
```

- Clients **SHOULD** request the **MAJOR version only** unless they need strict pinning.
- Responses **MUST** include `Vary: Accept` so caches/CDNs treat different versions as distinct entries.
- If `Accept` omits a version, the API responds with the **latest stable MAJOR** — consumers relying on this may be broken by a future MAJOR.

### 6.2 What each SemVer bump means

| Change | Bump | Backwards compatible? |
|---|---|---|
| Backwards-compatible bug fix | **PATCH** | Yes |
| New optional field / new endpoint | **MINOR** | Yes |
| Removing/renaming a field, changing a type, tightening validation | **MAJOR** | **No — breaking** |

> All changes *within* a MAJOR version are guaranteed non-breaking. Consumers are only affected by breaking changes when they choose to move to a new MAJOR.

### 6.3 Spec versioning is automated

Do not hand-edit `info.version`. The publish pipeline sets it:

- **Draft** (every merge to `main`/`master`): published to SwaggerHub as `vX.Y.Z-<short-sha>` (defaults to `v0.0.0-<sha>`), `visibility: public`, `published: false`.
- **Release** (publishing a GitHub release with tag `vX.Y.Z`): published as `X.Y.Z`, `visibility: public`, `published: true`.

---

## 7. Security

- Protected APIs **MUST** declare a security scheme and apply it. The standard scheme is bearer JWT:

```yaml
components:
  securitySchemes:
    BearerAuth:
      description: Valid Bearer Token
      type: http
      scheme: bearer
```

- Document `401` ("Your JWT token failed validation") on protected operations.
- Never put secrets, tokens or real personal data in `example` values.

---

## 8. Schema design & reuse

- Define reusable building blocks once under `components.schemas` and `$ref` them. Common ones include constrained primitives:

```yaml
uuid:
  type: string
  pattern: ^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$
```

- Property names in payloads use **camelCase** (`caseId`, `courtHouseName`, `nextHearingDate`). *(Note: path parameters use snake_case — see §4.2.)*
- List the `required` properties explicitly on each object.
- Use `enum` for closed value sets, and `format` (`uuid`, `date-time`) wherever it applies.
- Set `additionalProperties: false` on objects that should be strict, to stop unexpected fields leaking in.
- Provide realistic `example` values (and named `examples` on responses) — they power Swagger UI and the auto-mock server.
- Arrays representing collections **SHOULD** use plural names and may set `minItems` where a minimum is meaningful.

```yaml
CaseMapperResponse:
  type: object
  required:
    - caseUrn
  properties:
    caseId:
      description: Case ID
      type: string
      example: "8a759185-73cc-479f-a420-38db2aa54cf2"
    caseUrn:
      description: Unique reference number for the case
      type: string
      example: "CIK1JQKECS"
```

---

## 9. Linting & validation

- Each repo **MUST** include a Spectral ruleset (`.spectral.yml`) and lint the spec in CI (`lint-openapi` workflow).
- The baseline ruleset extends Spectral's OpenAPI rules:

```yaml
extends: ["spectral:oas"]
rules:
  oas3-valid-media-example: off
  oas3-valid-schema-example: off
```

- A spec **MUST** lint clean before it can be published to APIHub/SwaggerHub.

---

## 10. Quick checklist (use this in PR review)

- [ ] One `*.openapi.yml` in `/src/main/resources/openapi/`
- [ ] `info.version` is `0.0.0`; contact `no-reply@hmcts.com`; MIT license
- [ ] Repo name follows the `api-{source-system}-...` convention
- [ ] Paths are lowercase plural nouns; no version in the path
- [ ] Path params are snake_case, typed, described, with examples
- [ ] Every operation has a unique camelCase `operationId` and a description
- [ ] `200` plus at least `400`/`401` documented
- [ ] Standard `ErrorResponse` schema used everywhere
- [ ] `BearerAuth` declared and applied on protected operations
- [ ] Schemas inline (no external `$ref`); camelCase properties; `required` listed; enums/formats/examples set
- [ ] Versioning via `Accept` media type; `Vary: Accept` returned
- [ ] Spectral lint passes in CI

---

### Further reading

- [HMCTS RESTful API Standards](https://hmcts.github.io/restful-api-standards/)
- [Semantic Versioning](https://semver.org)
- [GitHub API Media Types](https://docs.github.com/en/rest/overview/media-types)
- [RFC 6838 – Media Type Naming](https://datatracker.ietf.org/doc/html/rfc6838)
- [RFC 7231 – HTTP Content Negotiation](https://datatracker.ietf.org/doc/html/rfc7231)

*Examples on this page are drawn from existing Common Platform specs (e.g. `api-hmcts-crime-template`, `api-cp-caseadmin-case-urn-mapper`, `api-cp-refdata-courthearing-courthouses`, `api-cp-crime-caseingestion-prosecutor`, `api-cp-crime-caseadmin-case-document-knowledge`).*

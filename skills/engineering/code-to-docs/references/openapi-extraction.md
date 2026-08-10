# OpenAPI Extraction

Build the spec from route handlers, request and response types, and validation rules that exist in the code. Default to OpenAPI 3.1; use 3.0 when the toolchain the repo already uses requires it.

## Check for a generator first

Before writing YAML by hand, look for a spec the project already produces:

| Signal | Meaning |
| :--- | :--- |
| `springdoc-openapi`, `springfox` in `pom.xml` | Spec served at `/v3/api-docs` |
| FastAPI | Spec served at `/openapi.json` automatically |
| `@nestjs/swagger` | Spec built by `SwaggerModule` |
| `zod-to-openapi`, `@asteasolutions/zod-to-openapi` | Spec derived from Zod schemas |
| `drf-spectacular`, `drf-yasg` | Django REST Framework spec |
| An existing `openapi.yaml` or `swagger.json` | Verify against code rather than replacing |

If a generator exists, the job is usually to **fill the gaps** — descriptions, examples, error responses — not to author from scratch. Say so instead of producing a competing file.

## Route handler → spec

| Read from code | Becomes |
| :--- | :--- |
| HTTP verb and path on the handler | `paths./resource.get` |
| Path variables | `parameters` with `in: path`, `required: true` |
| Query parameters and their defaults | `parameters` with `in: query`, `schema.default` |
| Request body type or DTO | `requestBody.content.application/json.schema` |
| Return type | `responses.200.content` schema |
| Created-resource return | `responses.201` plus a `Location` header if set |
| Validation annotations or schema constraints | `minLength`, `maximum`, `pattern`, `format` |
| Enum types | `schema.enum` |
| Nullable fields | `nullable: true` (3.0) or a `null` union (3.1) |
| Thrown or mapped exceptions | `responses.4xx` / `5xx` with the error schema |
| Auth middleware or guard | `securitySchemes` plus per-operation `security` |
| Rate-limit middleware | Documented in the operation `description` and headers |

## Structure rules

- **One schema per domain type, referenced everywhere.** Define `Task` once under `components.schemas` and `$ref` it. Inline duplicates rot independently.
- **Separate request and response shapes.** `CreateTaskRequest` has no `id` or `createdAt`; `Task` does. Collapsing them into one schema misdescribes both.
- **Every operation lists its error responses.** At minimum the codes the code can actually return — a handler with no auth guard should not document a 401.
- **A single shared `Error` schema.** Match the field names the app actually emits, not a generic `{code, message}` invented for the spec.
- **`operationId` on every operation.** Client generators need it; make it a stable verb-noun such as `listTasks`.
- **Tag by resource**, and give each tag a description.

## Skeleton

```yaml
openapi: 3.1.0
info:
  title: Task API
  version: 1.4.0
  description: Task and project management for internal teams.
servers:
  - url: https://api.example.com/v1
    description: Production
tags:
  - name: tasks
    description: Create, list, and update tasks.
paths:
  /tasks:
    get:
      operationId: listTasks
      tags: [tasks]
      summary: List tasks
      parameters:
        - name: status
          in: query
          description: Filter by lifecycle state.
          schema:
            type: string
            enum: [pending, in_progress, completed]
        - name: limit
          in: query
          schema: { type: integer, default: 20, maximum: 100 }
      responses:
        "200":
          description: Matching tasks, newest first.
          content:
            application/json:
              schema:
                type: array
                items: { $ref: "#/components/schemas/Task" }
        "401": { $ref: "#/components/responses/Unauthorized" }
components:
  schemas:
    Task:
      type: object
      required: [id, title, status]
      properties:
        id: { type: string, format: uuid }
        title: { type: string, maxLength: 200 }
        status: { type: string, enum: [pending, in_progress, completed] }
        createdAt: { type: string, format: date-time }
  responses:
    Unauthorized:
      description: Missing or expired bearer token.
      content:
        application/json:
          schema: { $ref: "#/components/schemas/Error" }
  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
security:
  - BearerAuth: []
```

## Completeness checklist

- [ ] Server URLs for each environment that exists in config
- [ ] Auth scheme documented, including how a caller obtains a token
- [ ] Every route in the codebase present — reconcile the route list against the spec's `paths`
- [ ] Path, query, header, and body parameters, with required vs optional correct
- [ ] Request and response examples on the non-obvious operations
- [ ] Error responses matching what the handlers actually raise
- [ ] Pagination contract described where list endpoints support it
- [ ] Rate limits and their response headers, if middleware enforces them
- [ ] Deprecated operations marked `deprecated: true` rather than deleted
- [ ] Webhooks documented with payload schema and signature verification, if any

## Validate before handing over

Run whatever validator the repo already has. Otherwise a spec linter such as `npx @redocly/cli lint <spec>` or `npx @stoplight/spectral-cli lint <spec>` catches structural errors in seconds. Report the result — an unvalidated spec is a draft.

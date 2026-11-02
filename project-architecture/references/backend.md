# Profile: Back-end

Applies to a `backend` (HTTP / RPC API, worker, service) in `OPINIONATED` mode.

None of the front-end opinions apply: no Command Bus, no MobX stores, no Fragiola UI, no components.

## Opinion skills

| Skill | What it decides |
| --- | --- |
| `utils-implementation` | Pure helpers (TypeScript): which utils exist and how they are written |

There is no back-end architecture skill yet. Until one exists, follow these defaults and the framework's conventions.

## Defaults

* Organize by feature/module (routes, service, data access per module), following the chosen framework's recommended structure.
* Transport (routes / controllers) only parses and validates input and maps results to responses; business rules live in services; data access is isolated.
* Validate every external input at the boundary with a schema.
* Configuration from environment variables, validated at startup; no secrets in code.
* Consistent error handling and response format.
* Tests for services (unit) and routes (integration).

## Prerequisites

The framework, database and ORM are decisions of the plan. Take them from the request or the repository; when neither implies one, ask the user (a stop condition for `epic-implementer`). Versions verified with `epic-current-documentation`.

## Pre-approved dependencies

None beyond what the request names.

## Architecture Map (Issue template)

```markdown
## Architecture Map

- Routes / endpoints: method, path, input schema, response
- Services: business rules added or changed
- Data: schema / migration changes, repositories
- Config: environment variables
- Tests: what must be covered
```

## Validation

The project scripts: lint, typecheck, tests, build, and migrations applied cleanly when the schema changes.

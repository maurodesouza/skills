# Profile: Library

Applies to a `library` (a published package, including React component libraries) in `OPINIONATED` mode.

A library is consumed by other projects, so its architecture is about the public API, not about application state or screens. None of the React app opinions apply: no Command Bus, no MobX stores, no Fragiola UI, no app modal.

## Opinion skills

| Skill | What it decides |
| --- | --- |
| `utils-implementation` | Internal helpers (TypeScript): which utils exist and how they are written |

There is no library architecture skill yet. Until one exists, follow these defaults and the ecosystem's conventions.

## Defaults

* One explicit public entry (`src/index.ts`) that exports only the public API; everything else is internal.
* `exports` in `package.json` with types; ESM first.
* Framework packages (`react`, ...) as `peerDependencies`, never bundled.
* No global state and no side effects on import.
* Public API documented in the README with usage examples; breaking changes are explicit.
* Tests through the public API.

## Prerequisites

The build tool and the test runner the ecosystem currently recommends for libraries, verified with `epic-current-documentation`. Choosing them in an empty repository is a decision for the plan; ask the user when the request does not imply one.

## Pre-approved dependencies

None beyond what the request names.

## Architecture Map (Issue template)

```markdown
## Architecture Map

- Public API: exports added or changed (signatures)
- Internal modules: files and responsibilities
- Types: public types
- Tests: behavior covered through the public API
- Docs: README / changelog entries
```

## Validation

The project scripts: lint, typecheck, tests, build (and the package output check when the project has one).

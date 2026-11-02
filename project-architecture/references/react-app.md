# Profile: React app

Applies to a `react-app` in `OPINIONATED` mode, or in `EXISTING` mode when the project already uses these patterns (Command Bus in `src/lib/command/`, MobX stores, Fragiola registry in `components.json`).

## Opinion skills

| Skill | What it decides |
| --- | --- |
| `command-bus-architecture` | Every interaction is a Command Bus action; MobX stores hold state, plain setters and `$` derived values; logic lives in Handles; components only read and present; one app modal |
| `command-handle-implementation` | How Handles are written and registered |
| `setup-command-system` | Installs the Command Bus |
| `fragiola-ui` | Every interface is built with Fragiola UI, with headless / composition parts assembled explicitly by the caller |
| `utils-implementation` | Which utils exist and how they are written |

Read `command-bus-architecture` and `fragiola-ui` before planning.

## Prerequisites

The first step of the Epic, when missing:

* Command Bus not installed (`src/lib/command/`): `setup-command-system`.
* MobX not installed: `mobx`, `mobx-react-lite` and the decorator transform (`command-bus-architecture` section 11), versions verified with `epic-current-documentation`.
* Fragiola UI not set up (`components.json` without the `@fragiola` registry): `fragiola-ui`.

## Pre-approved dependencies

The Command Bus, MobX with its decorator transform (`@rolldown/plugin-babel` + `@babel/core` + `@babel/plugin-proposal-decorators`) and Fragiola UI.

## Architecture Map (Issue template)

```markdown
## Architecture Map

- Actions: `<domain>.<verb>` (`Action` | `ScopedAction`) in `<domain>-actions.ts` - flat domains, one actions file per domain
- Handles: `<domain>-handle.tsx` (one per domain) - what each handler does, including the utils it uses
- Stores: `store/store.ts` - fields, plain setters and `$` derived values (one `$<part>UI` per component); no add/remove/update methods
- Modal content: components sent with `modal.open` (no feature dialogs)
- Components: what each one presents and which actions it dispatches
- Fragiola UI: components used
- Tests: what must be covered
```

Omit lines that do not apply (e.g. no UI).

## Implementation order (per domain)

1. Declare the actions in `<domain>-actions.ts`.
2. Create or update the MobX store: fields, plain setters and every `$` derived value the UI needs (one `$<part>UI` per component). No other methods.
3. Create or update the Handle with `command-handle-implementation`; write helpers with `utils-implementation`.
4. Mount the Handle where it belongs.
5. Build or update components with `fragiola-ui`. They only read `$` values, present them and dispatch through `actions`.

## Validation

Besides the project scripts (lint, typecheck, tests, build):

```bash
node <command-bus-architecture>/scripts/check-architecture.mjs src
```

It must report no violations. The reviewer treats each violation as High.

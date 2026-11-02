---
name: command-bus-architecture
description: Opinionated architecture for React apps - every interaction is a Command Bus action, stores hold only state, setters and derived values, all logic lives in Handles, components only read and present, dialogs go through one app-wide modal. Use before planning, implementing or reviewing code in a React app that already uses the Command Bus (`src/lib/command/`), or in a new React app when `project-architecture` selects it. Never for libraries, back-ends or apps with another architecture.
---

# User Input

```text
$ARGUMENTS
```

# Objective

Define how application code is written in a React app that follows this architecture: a new app with no architecture of its own, or an app that already uses the Command Bus (decided by `project-architecture`). In any other project, follow the project's own architecture instead.

When it applies, this skill is the source of truth for architecture decisions made by `epic-plan-execution`, `epic-execution`, `command-handle-implementation`, `test-writer` and `reviewer`.

The Command Bus used is **V2** (installed by `setup-command-system`). Do not use V3.

# References

The rules below are short on purpose. The files in `references/` are the canonical examples: **read the matching reference before writing that layer, and imitate it.**

| Writing | Read |
| --- | --- |
| A MobX store | `references/store.md` |
| Actions and a Handle | `references/actions-and-handle.md` |
| A component | `references/component.md` |
| Anything that opens a dialog | `references/modal.md` |

# 1. Core Rules

1. **Everything is an event.** Every application interaction is an action dispatched through the Command Bus and handled by a Handle.
2. **Stores hold state, not logic.** A store has observable primitives, one plain setter per primitive and `$` derived values. Nothing else.
3. **Handles hold all logic.** Every decision, validation, calculation of the next state, side effect and orchestration lives in a Handle.
4. **Components only read and present.** Components read values already prepared by the store and dispatch actions.

| Layer | Responsible for |
| --- | --- |
| MobX Store | State, plain setters, `$` derived values that prepare what the UI presents (MobX 7 decorators) |
| Handle (Command Bus) | All logic: validation, next-state calculation, side effects, orchestration |
| Component | Reading `$` values and presenting them, dispatching actions |

# 2. What Goes Through the Command Bus

Absolutely everything: opening and closing the modal, notifications, navigation, form changes and submits, requests, toggles, drag-and-drop results.

If a component needs something to happen, it dispatches an action. It never does it itself.

# 3. Domains and Actions

Actions are organized in **flat domains**: one top-level domain per entity or app concern.

* Action path is always `<domain>.<verb>`: exactly two levels. `task.create`, `column.rename`, `column.editStart`, `filter.setSearch`, `modal.open`.
* One domain = one `<domain>-actions.ts` + one `<domain>-handle.tsx`, side by side. The Handle handles **every** action of its domain.
* The actions file declares the domain **once**, through module augmentation of `#/lib/command/global`:

```typescript
declare module "#/lib/command/global" {
    interface Actions {
        task: {
            create: Action<TaskCreatePayload, TaskResult>;
            delete: Action<{ taskId: string }>;
        };
    }
}
```

* `Action` for global actions, `ScopedAction` for instance-specific actions.

Forbidden:

* Nested domains (`kanban.task.create`) or a third path level.
* Declaring the same domain in more than one file, or helper interfaces augmented from several files.
* Handling one domain's actions in several Handles.
* Editing the global `Actions` interface directly.

Choosing the domain: name it after **what changes**, not after the screen. Column rename UI state belongs to `column` (`column.editStart`, `column.editCommit`); filters are `filter`; the dialog is `modal`. A Handle may dispatch actions of other domains through `actions`.

# 4. Store (MobX)

The store holds **state** and **derived values**. It holds **no logic**.

## Allowed

* State fields declared with `@observable accessor`.
* **Plain setters** decorated with `@action`: `setX(value)` assigns the whole value of one primitive. One primitive per setter, one statement per setter.
* `$` getters decorated with `@computed`, computing derived values (including all presentation values), using utils from `utils/` when they add something.

## Forbidden

* Any method that is not a plain setter: `addTask`, `removeTask`, `updateTask`, `moveTask`, `placeTask`, `toggleX`, `hydrate` that writes several primitives, `reset` that writes several primitives.
* Mutating inside a setter: `push`, `splice`, `delete`, `Object.assign`, `this.x[id] = ...`, nested property writes.
* Conditions, loops or calculations in setters.
* Async work, API calls, storage, timers, dispatching actions, calling other stores.

The Handle calculates the next value and calls the setter. Simple changes are written inline; a util is used only when it adds something (see `utils-implementation`):

```typescript
// ✅ Handle
store.setTasks([...store.tasks, created]);
store.setTasks(store.tasks.filter(task.filter.removeIds([taskId])));
store.setTasks(store.tasks.map(task.map.update(taskId, { priority })));

// ❌ Store
@action
addTask(task: Task) {
    this.tasks.push(task);
}
```

## Structure and naming

* Class regions in this order: `Primitives`, `Setters`, `Derived primitives`, `Data`, `UI`.
* MobX 7 decorators (2022.3 standard): `@observable accessor` fields, `@action` setters, `@computed` getters. No `makeObservable` / `makeAutoObservable`, no constructor for MobX.
* State that holds collections uses arrays of entities (`tasks: Task[]` with `task.columnId`), so Handles use `filter` / `map` / `find` with curried utils.
* Every derived value starts with `$` (`$isEmpty`, `$columnsUI`). Primitives and setters never do.
* One `$<part>UI` getter per component or part, returning everything that part presents (texts, labels, aria labels, flags, variants, formatted values).
* Global store: export one instance and a `use-<feature>.ts` hook. Scoped store: created once in the feature Provider and exposed through context.
* A domain without state has no store.

# 5. Handle

The Handle holds all logic. Implement it with `command-handle-implementation`.

* Validates and decides.
* Calculates the next state with utils and writes it through setters.
* Calls APIs and performs side effects (storage, DOM, timers).
* Dispatches other actions through `actions`.
* Turns failures into store state or another action, never into an exception thrown at the component.

Handles are mounted once, as high as their context requires (app root for shared domains, feature root for feature domains, inside the Provider for scoped domains).

# 6. Component

* Built with Fragiola UI (`fragiola-ui`), wrapped with `observer` when it reads a store.
* Reads `$<part>UI` (or a view model passed by a render prop) and renders the values as they are.
* Dispatches through `actions`.

Forbidden: calculations, formatting, filtering, sorting, mapping data into new values, conditionals that choose texts/labels/variants, template strings built from state, `useMemo`, store mutation, `useState` for application state (ephemeral visual state such as hover may stay local).

Conditional rendering is allowed only on a flag or status prepared by the store (`if (!ui.isVisible) return null`).

# 7. Modal

The modal is a feature of its own, `src/features/modal/`, so any part of the app can use it. Like any other domain, it is one actions file and one Handle:

```text
src/features/modal/components/handles/modal/
├── modal-actions.ts   # modal.open(Content), modal.close()
└── modal-handle.tsx   # ModalHandle: registers the actions and renders the dialog
```

`<ModalHandle />` is mounted once, at the app root. Every dialog (forms, confirmations) is content sent to it.

* Actions: `modal.open(Content)` and `modal.close()`. The payload is a `Renderable`: a component (`actions.modal.open(ShareModal)`) or an element (`actions.modal.open(<ColumnDeleteConfirm column={column} />)`).
* `ModalHandle` registers `modal.open` / `modal.close` and keeps the current content in its own `useState`. There is no modal store. It is the one Handle that renders UI: the dialog belongs to it.
* It renders the only `Dialog.Root` of the app, with `Dialog.Portal` and `Dialog.Backdrop`, and shows the content through `FlexibleRender`.
* The content renders its own `Dialog.Content` (so it controls its size) with `Dialog.Header`, `Dialog.Title`, `Dialog.Body`, `Dialog.Footer`.
* Opening with nothing to prepare: the component dispatches `modal.open` directly. Opening that needs preparation (prefill a form): the component dispatches a domain action; its Handle prepares the state and dispatches `modal.open`.
* Confirming: the content's confirm button dispatches the domain action (`column.delete`); that Handle performs it and dispatches `modal.close`.

Forbidden: any other `Dialog.Root` / `AlertDialog.Root`, dialog open flags in stores, one set of dialog actions per feature, a modal file outside `src/features/modal/`.

Any other app-wide overlay follows the same shape. A drawer would be `src/features/drawer/components/handles/drawer/` with `drawer-actions.ts` and `drawer-handle.tsx`, and `DrawerHandle` would render the `Drawer` component.

See `references/modal.md`.

# 8. File Structure

```text
src/
├── components/
│   ├── helpers/flexible-render/           # renders a Renderable (component or element)
│   └── handles/<domain>/                  # other shared domains: theme, notification
│       ├── <domain>-actions.ts
│       └── <domain>-handle.tsx
├── store/<domain>/store.ts                # shared domain stores
├── hooks/use-<domain>.ts
├── utils/<domain>/<domain>.ts             # generic utils (utils-implementation)
├── features/modal/components/handles/modal/ # modal-actions.ts + modal-handle.tsx (the single modal)
└── features/<feature>/
    ├── types.ts
    ├── store/store.ts + store.test.ts
    ├── hooks/use-<feature>.ts
    ├── utils/<domain>/<domain>.ts         # feature utils
    └── components/
        ├── handles/<domain>/              # one folder per flat domain: task, column, filter
        │   ├── <domain>-actions.ts
        │   └── <domain>-handle.tsx
        └── ...                            # observer components and headless parts
```

# 9. Loading State

* When the UI presents a loading state, the Handle sets a loading primitive and the store exposes it through `$<part>UI`.
* `useTransition` is only used where no store value is involved, e.g. disabling the button that dispatched the action.

# 10. Dispatching

* Use the `actions` proxy: `actions.task.create(payload)`.
* Scoped: `actions.domain.action(payload, { instanceId: store.id })`.
* `command.dispatch()` only for external triggers (realtime, WebSocket, server events, AI/tool triggers).

# 11. Prerequisites

* If `src/lib/command/` does not exist, run `setup-command-system` first.
* If `mobx` / `mobx-react-lite` are not installed, install them (verify versions with `epic-current-documentation`). MobX is part of this architecture and is pre-approved.
* MobX 7 decorators need a transform: Vite 8 / Vitest do not compile 2022.3 decorators on their own (tests fail with `SyntaxError: Invalid or unexpected token`). Install `@rolldown/plugin-babel`, `@babel/core` and `@babel/plugin-proposal-decorators` (pre-approved) and add this plugin first in both `vite.config.ts` and `vitest.config.ts`. Keep `experimentalDecorators` off in `tsconfig.json`.

```typescript
// decorators.ts
import babel from "@rolldown/plugin-babel";

/** Transforms MobX 2022.3 decorators (`@observable accessor`, `@action`, `@computed`). */
export function decorators() {
    return babel({
        presets: [
            {
                preset: () => ({
                    plugins: [["@babel/plugin-proposal-decorators", { version: "2023-11" }]],
                }),
                rolldown: { filter: { code: "@" } },
            },
        ],
    });
}
```

# 12. Automated Check

Run the checker before committing and before review. It must report no violations:

```bash
node <this-skill-dir>/scripts/check-architecture.mjs <project-root>/src
```

It flags store methods that are not plain setters, stores without MobX decorators, nested or duplicated action domains, `Dialog.Root`/`AlertDialog.Root` outside `ModalHandle`, and `useMemo`/`useState` in components. Fix the code, never the checker.

# 13. Checklist

* [ ] Every interaction is an action handled by a Handle.
* [ ] Actions are `<domain>.<verb>`, one actions file and one Handle per domain, no nesting.
* [ ] Stores only have `@observable accessor` fields, `@action` plain setters and `@computed` `$` getters.
* [ ] Every next-state calculation happens in a Handle.
* [ ] Every derived value starts with `$`; each component reads a prepared `$<part>UI`.
* [ ] Components do no calculation or value selection.
* [ ] Dialogs are content sent through `modal.open(Content)` to the single `ModalHandle`.
* [ ] Components reading stores are `observer`.
* [ ] Handles dispose every registration on unmount.
* [ ] `check-architecture.mjs` reports no violations.

---
name: command-handle-implementation
description: Implement command handles for the current feature, in projects that use the Command Bus (`command-bus-architecture`)
---

# Command Handle Implementation

## When to use

Use this skill whenever you need to create or modify a command Handle — the component responsible for registering `command.handle()` listeners.

This includes:

- Creating a new Handle.
- Adding an action to an existing Handle.
- Refactoring an existing Handle.

Do not use this skill for general command architecture questions or command dispatching. Follow the `command-bus-architecture` skill instead.

If `src/lib/command/` does not exist, invoke the `setup-command-system` skill before implementing the Handle.

## Before implementation

1. Identify the domain/feature that owns the Handle.
2. Confirm whether the action is `Action` or `ScopedAction`.
3. Check whether the action declaration already exists.
4. Check whether a Handle already exists for the domain.

Do not change the action scope or architecture merely to simplify the implementation.

## File structure

Shared application context:

```text
src/components/handles/<domain>/
├── <domain>-actions.ts
└── <domain>-handle.tsx
```

Feature context:

```text
src/features/<feature>/components/handles/<domain>/
├── <domain>-actions.ts
└── <domain>-handle.tsx
```

## Action declarations

Domains are flat (`command-bus-architecture` section 3): the path is always `<domain>.<verb>`, and one domain has exactly one `<domain>-actions.ts` and one `<domain>-handle.tsx`.

If the action is new:

* Add it to the domain's `<domain>-actions.ts`, inside the single `interface Actions { <domain>: { ... } }` declaration of that file.
* Extend `#/lib/command/global` through module augmentation. Never augment any other interface, never nest a third level.
* Register it in the domain's existing Handle. Do not create a second Handle for the same domain.
* Use `Action` for global actions.
* Use `ScopedAction` for instance-specific actions.
* Never modify the global `Actions` interface directly.

If the action already exists, reuse its existing declaration. Do not redeclare it.

## Handle implementation

Handler functions MUST:

* Be defined inside the component.
* Be defined outside `useEffect`.
* Contain the application/orchestration logic.
* Call store mutations when state needs to change.
* Call external APIs when required.
* Dispatch other commands when required.

Example:

```typescript
export function MyHandle() {
  async function handleDoThing(payload: Payload) {
    const result = await api.process(payload);

    myStore.setData(result);
  }

  useEffect(() => {
    const disposes = [
      command.handle("myDomain.doThing", handleDoThing),
    ];

    return () => {
      for (const dispose of disposes) dispose();
    };
  }, []);

  return null;
}
```

## Registration

`command.handle()` MUST:

* Be called inside `useEffect`.
* Receive handlers by reference.
* Receive `{ instanceId }` when registering a `ScopedAction`.
* Return a disposer that is cleaned up.

Do not put handler logic inline:

```typescript
// ❌ Wrong
command.handle("myDomain.doThing", async (payload) => {
  // logic
});
```

Use a named handler instead:

```typescript
// ✅ Correct
async function handleDoThing(payload: Payload) {
  // logic
}

command.handle("myDomain.doThing", handleDoThing);
```

## Cleanup

Store every disposer returned by `command.handle()`.

Dispose every handler when the Handle unmounts.

```typescript
useEffect(() => {
  const disposes = [
    command.handle("domain.action", handleAction),
    command.handle("domain.otherAction", handleOtherAction),
  ];

  return () => {
    for (const dispose of disposes) dispose();
  };
}, []);
```

## Dependencies

Use the correct `useEffect` dependencies.

If handlers close over a stable store reference and dependencies intentionally need to be omitted, use:

```typescript
// biome-ignore lint/correctness/useExhaustiveDependencies: handlers close over the stable store reference
```

Always provide a clear reason for the suppression.

## Store and Dispatching

Store rules, the Store/Handle split and dispatching rules are defined in `command-bus-architecture`. In a Handle:

* Compute the next value, then write it with the plain setter: `store.setTasks([...store.tasks, created])`, `store.setTasks(store.tasks.map(task.map.update(id, patch)))`. The store has no `add`/`remove`/`update` methods; use utils only where they add something (`utils-implementation`).
* Read derived values from the store (`store.$value`); never compute presentation values in the Handle.
* To show a dialog, prepare its state, then `actions.modal.open(Content)` (a component or an element); to finish, `actions.modal.close()`.

See `command-bus-architecture/references/actions-and-handle.md` for a complete Handle.
* Dispatch through the `actions` proxy; `command.dispatch()` only for external/realtime/AI triggers.

## Verification

Before finishing:

* [ ] Typecheck and lint pass (repository scripts from `epic-discover-repository`).
* [ ] Handlers are outside `useEffect`.
* [ ] `command.handle()` receives handlers by reference.
* [ ] All disposers are cleaned up.
* [ ] Scoped actions receive the correct `instanceId`.
* [ ] New actions use module augmentation.
* [ ] Existing actions are not redeclared.
* [ ] The action path is `<domain>.<verb>` and lives in the domain's only actions file and Handle.
* [ ] MobX store contains primitives, plain setters and `$` derived values only.
* [ ] `node <command-bus-architecture>/scripts/check-architecture.mjs src` reports no violations.
* [ ] The Handle computes no derived values.
* [ ] Normal dispatch uses the `actions` proxy.
* [ ] No unnecessary `command.dispatch()` is used.

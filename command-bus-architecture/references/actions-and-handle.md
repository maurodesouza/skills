# Actions and Handle reference

One flat domain = one actions file + one Handle, in the same folder.

```text
src/features/kanban/components/handles/
├── column/
│   ├── column-actions.ts
│   └── column-handle.tsx
├── task/
│   ├── task-actions.ts
│   └── task-handle.tsx
└── filter/
    ├── filter-actions.ts
    └── filter-handle.tsx
```

## Actions

```typescript
// src/features/kanban/components/handles/task/task-actions.ts
import type { Priority, TaskFields, TaskResult } from "#/features/kanban/types";
import type { Action } from "#/lib/command/types";

declare module "#/lib/command/global" {
    interface Actions {
        task: {
            create: Action<Partial<TaskFields> & { columnId: string }, TaskResult>;
            delete: Action<{ taskId: string }>;
            moveAdjacent: Action<{ taskId: string; direction: "left" | "right" }>;
            setPriority: Action<{ taskId: string; priority: Priority }>;
        };
    }
}
```

* The domain (`task`) is declared once, here, at the top level of `Actions`.
* Paths are `<domain>.<verb>`: `actions.task.create(...)`. Never `actions.kanban.task.create(...)`.
* Payloads are objects with named fields, so call sites read clearly.

## Handle

```typescript
// src/features/kanban/components/handles/task/task-handle.tsx
import { useEffect } from "react";
import { useKanban } from "#/features/kanban/hooks/use-kanban";
import type { Priority, Task, TaskFields, TaskResult } from "#/features/kanban/types";
import { column } from "#/features/kanban/utils/column/column";
import { task } from "#/features/kanban/utils/task/task";
import { command } from "#/lib/command";
import { random } from "#/utils/random/random";

type CreatePayload = Partial<TaskFields> & { columnId: string };

export function TaskHandle() {
    const store = useKanban();

    async function handleCreate(payload: CreatePayload): Promise<TaskResult> {
        const { columnId, ...input } = payload;
        const fields = { ...task.defaults(), ...input };
        const errors = task.validate(fields);

        if (Object.keys(errors).length > 0) return { ok: false, errors };

        const created: Task = { id: random.id(), columnId, ...fields };

        store.setTasks([...store.tasks, created]);

        return { ok: true, taskId: created.id };
    }

    async function handleDelete(payload: { taskId: string }) {
        store.setTasks(store.tasks.filter(task.filter.removeIds([payload.taskId])));
    }

    async function handleMoveAdjacent(payload: {
        taskId: string;
        direction: "left" | "right";
    }) {
        const current = store.tasks.find(task.find.byId(payload.taskId));

        if (!current) return;

        const target = column.neighbour(store.columns, current.columnId, payload.direction);

        if (!target) return;

        store.setTasks(
            store.tasks.map(task.map.update(current.id, { columnId: target.id })),
        );
    }

    async function handleSetPriority(payload: { taskId: string; priority: Priority }) {
        store.setTasks(
            store.tasks.map(task.map.update(payload.taskId, { priority: payload.priority })),
        );
    }

    // biome-ignore lint/correctness/useExhaustiveDependencies: handlers close over the stable store reference
    useEffect(() => {
        const disposes = [
            command.handle("task.create", handleCreate),
            command.handle("task.delete", handleDelete),
            command.handle("task.moveAdjacent", handleMoveAdjacent),
            command.handle("task.setPriority", handleSetPriority),
        ];

        return () => {
            for (const dispose of disposes) dispose();
        };
    }, []);

    return null;
}
```

* Every action of `task` is registered here, and only here.
* Each handler reads state, decides, computes the next value, then calls setters.
* Simple changes are inline: the new entity is an object literal and `[...store.tasks, created]` adds it. Utils appear where they add something: a named predicate for `filter`/`find`, an immutable updater for `map`, real logic (`task.validate`, `column.neighbour`).
* Handlers never compute presentation values; those are `$` getters in the store.

## Mounting

```tsx
// src/features/kanban/components/handles/kanban-handles.tsx
export function KanbanHandles() {
    return (
        <>
            <PersistenceHandle />
            <ColumnHandle />
            <TaskHandle />
            <FilterHandle />
        </>
    );
}
```

The route (or feature root) renders `<KanbanHandles />` once.

## Handle test

```tsx
import { render } from "@testing-library/react";
import { expect, it } from "vitest";
import { KanbanHandles } from "#/features/kanban/components/handles/kanban-handles";
import { kanbanStore } from "#/features/kanban/store/store";
import { actions } from "#/lib/command";

it("rejects an end date before the start date", async () => {
    render(<KanbanHandles />);

    const result = await actions.task.create({
        columnId: kanbanStore.columns[0].id,
        title: "Late",
        startDate: "2026-10-27",
        endDate: "2026-10-20",
    });

    expect(result).toMatchObject({ ok: false });
    expect(kanbanStore.tasks).toEqual([]);
});
```

Reset every field of a global store before each test through its setters, so state from one test never leaks into the next.

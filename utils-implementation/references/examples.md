# Utils examples

These examples follow the utils of the author's own projects: `calculation-pipeline` (`array`, `json`, `random`, `canvas`) and `fe-assignment-react` (`number`, `metrics`). Every member here has a reason to exist; the last section shows the kind of util that does not.

Call sites first, they are the point:

```typescript
const ids = array.toArray(payload.taskIds);
const current = store.tasks.find(task.find.byId(taskId));
store.setTasks(store.tasks.filter(task.filter.removeIds(ids)));
store.setTasks(store.tasks.map(task.map.update(taskId, { priority })));
store.setColumns(array.move(store.columns, from, to));
const stored = json.safeParser<BoardSnapshot>(raw, null);
const label = date.format.range(item.startDate, item.endDate);
```

## Generic: `src/utils/array/array.ts`

```typescript
import { number } from "#/utils/number/number";

function toArray<T>(value: T | T[]): T[] {
    return Array.isArray(value) ? value : [value];
}

/** Returns a new list with the item at `from` moved to `to` (clamped to the list bounds). */
function move<T>(list: readonly T[], from: number, to: number): T[] {
    const next = [...list];
    const [item] = next.splice(from, 1);

    if (item === undefined) return next;

    next.splice(number.clamp(to, 0, next.length), 0, item);

    return next;
}

export const array = {
    toArray,
    move,
};
```

* `toArray` lets one action accept one id or many (`task.delete({ taskIds: id })`) and normalizes it once.
* `move` hides index bookkeeping that is easy to get wrong (remove, clamp, insert).

## Generic: `src/utils/json/json.ts`

```typescript
const safeParser = <T>(value: string | null, fallback: T | null = null): T | null => {
    if (value === null) return fallback;

    try {
        return JSON.parse(value) as T;
    } catch {
        return fallback;
    }
};

export const json = {
    safeParser,
};
```

## Generic: `src/utils/number/number.ts`

```typescript
export const number = {
    clamp: (value: number, min: number, max: number): number =>
        Math.min(Math.max(value, min), max),

    format: (value: number, options?: Intl.NumberFormatOptions): string =>
        new Intl.NumberFormat("en-US", options).format(value),

    /** Formats an already scaled percentage value, e.g. `12.34` -> `"12.3%"`. */
    percent: (value: number, fractionDigits = 1): string =>
        `${number.format(value, {
            minimumFractionDigits: fractionDigits,
            maximumFractionDigits: fractionDigits,
        })}%`,
};
```

## Feature: `src/features/kanban/utils/task/task.ts`

```typescript
import type { Task, TaskErrors, TaskFields, TaskFilters } from "#/features/kanban/types";
import { date } from "#/features/kanban/utils/date/date";
import { priority } from "#/features/kanban/utils/priority/priority";

const EMPTY_FILTERS: TaskFilters = { search: "", dateFrom: "", dateTo: "", priority: "all" };

function validateTaskFields(fields: TaskFields): TaskErrors {
    const errors: TaskErrors = {};

    if (!fields.title.trim()) errors.title = "Title is required";

    if (fields.endDate < fields.startDate) {
        errors.endDate = "End date can't be before the start date";
    }

    return errors;
}

function matchesFilters(filters: TaskFilters) {
    const search = filters.search.trim().toLowerCase();

    return (item: Task): boolean => {
        if (filters.priority !== "all" && item.priority !== filters.priority) return false;

        if (!date.is.overlapping(item.startDate, item.endDate, filters.dateFrom, filters.dateTo)) {
            return false;
        }

        if (!search) return true;

        return (
            item.title.toLowerCase().includes(search) ||
            item.description.toLowerCase().includes(search)
        );
    };
}

export const task = {
    defaults: (): TaskFields => ({
        title: "",
        description: "",
        priority: priority.default,
        startDate: date.today(),
        endDate: date.today(),
    }),

    validate: validateTaskFields,

    find: {
        byId: (id: string) => (item: Task) => item.id === id,
    },

    filter: {
        byColumn: (columnId: string) => (item: Task) => item.columnId === columnId,
        byFilters: matchesFilters,
        removeIds: (ids: string[]) => (item: Task) => !ids.includes(item.id),
        removeColumnIds: (columnIds: string[]) => (item: Task) =>
            !columnIds.includes(item.columnId),
    },

    map: {
        update:
            (id: string, patch: Partial<Omit<Task, "id">>) =>
            (item: Task): Task => {
                if (item.id !== id) return item;

                return { ...item, ...patch };
            },
    },

    filters: {
        empty: EMPTY_FILTERS,
        isActive: (filters: TaskFilters): boolean =>
            Boolean(filters.search.trim() || filters.dateFrom || filters.dateTo) ||
            filters.priority !== "all",
    },
};
```

* `defaults` earns its place because the dates depend on today; creating the task itself is an object literal in the Handle (`{ id: random.id(), columnId, ...fields }`), so there is no `task.create`.
* `filter.byColumn` is the model to follow: one line, but it names a domain intention and is reused by the store getters and the Handles.
* `map.update` is the same idea as `canvas.nodes.map.updateData(id, data)`: one mapper that replaces only the matching entity, used with `store.tasks.map(...)`.
* `filter.removeIds` and `filter.removeColumnIds` mirror `canvas.nodes.filter.removeIds` / `canvas.edges.filter.removeFromIds`.

## Feature: `src/features/kanban/utils/column/column.ts`

```typescript
import type { Column } from "#/features/kanban/types";

export const column = {
    /** The column next to `columnId` in `direction`, or undefined at the edges. */
    neighbour: (columns: Column[], columnId: string, direction: "left" | "right") => {
        const index = columns.findIndex(column.find.byId(columnId));

        return columns[index + (direction === "left" ? -1 : 1)];
    },

    find: {
        byId: (id: string) => (item: Column) => item.id === id,
    },

    filter: {
        removeIds: (ids: string[]) => (item: Column) => !ids.includes(item.id),
    },

    map: {
        rename: (id: string, title: string) => (item: Column): Column =>
            item.id === id ? { ...item, title } : item,
    },
};
```

## Tests: `src/features/kanban/utils/task/task.test.ts`

Test the utils that hold logic. A one-line predicate is covered by the Handle tests that use it.

```typescript
import { describe, expect, it } from "vitest";
import { task } from "./task";

describe("task.validate", () => {
    it("rejects an end date before the start date", () => {
        const errors = task.validate({
            ...task.defaults(),
            title: "Ship",
            startDate: "2026-10-27",
            endDate: "2026-10-20",
        });

        expect(errors).toEqual({ endDate: "End date can't be before the start date" });
    });
});

describe("task.map.update", () => {
    it("replaces only the matching task, without mutating it", () => {
        const tasks = [
            { id: "a", columnId: "todo", ...task.defaults(), title: "A" },
            { id: "b", columnId: "todo", ...task.defaults(), title: "B" },
        ];

        const next = tasks.map(task.map.update("a", { priority: "high" }));

        expect(next[0].priority).toBe("high");
        expect(next[1]).toBe(tasks[1]);
        expect(tasks[0].priority).toBe("medium");
    });
});
```

## Wrong: utils that do not earn their existence

```typescript
// ❌ renames a single native operation
export const array = {
    without: <T>(list: T[], item: T) => list.filter((current) => current !== item),
    insert: <T>(list: T[], index: number, item: T) => [...list.slice(0, index), item, ...list.slice(index)],
};

// ❌ a "records" layer that only spreads or destructures objects
export const record = {
    add: (items, item) => ({ ...items, [item.id]: item }),
    remove: (items, id) => { const { [id]: _, ...rest } = items; return rest; },
};

// ❌ only returns an object literal: create it where it is needed (the Handle)
export const column = {
    create: (id: string, title: string): Column => ({ id, title }),
};

// ❌ wraps an expression that reads better inline
has: { errors: (errors: TaskErrors) => Object.keys(errors).length > 0 },

// ❌ a helper in the wrong domain (clamp is about numbers)
export const array = { math: { clamp: (value, min, max) => ... } };

// ❌ not a util: configuration or scripts
export const theme = { bootstrapScript: "(function(){...})()" };

// ❌ loose exports instead of one namespace
export function formatDate(value: string) {}
```

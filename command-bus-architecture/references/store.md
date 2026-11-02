# Store reference

A store is a box of state. It has three things: `@observable accessor` fields, `@action` plain setters, `@computed` `$` derived values. MobX 7 uses the 2022.3 standard decorators, so there is no `makeObservable` / `makeAutoObservable` and no constructor for MobX.

## Feature store

```typescript
// src/features/kanban/store/store.ts
import { action, computed, observable } from "mobx";
import type { Column, Task, TaskFilters } from "#/features/kanban/types";
import { date } from "#/features/kanban/utils/date/date";
import { priority } from "#/features/kanban/utils/priority/priority";
import { task } from "#/features/kanban/utils/task/task";

export class KanbanStore {
    // #region Primitives
    @observable accessor isHydrated = false;
    @observable accessor columns: Column[] = [];
    @observable accessor tasks: Task[] = [];
    @observable accessor editingColumnId: string | null = null;
    @observable accessor filters: TaskFilters = task.filters.empty;
    // #endregion

    // #region Setters
    @action
    setIsHydrated(isHydrated: boolean) {
        this.isHydrated = isHydrated;
    }

    @action
    setColumns(columns: Column[]) {
        this.columns = columns;
    }

    @action
    setTasks(tasks: Task[]) {
        this.tasks = tasks;
    }

    @action
    setEditingColumnId(editingColumnId: string | null) {
        this.editingColumnId = editingColumnId;
    }

    @action
    setFilters(filters: TaskFilters) {
        this.filters = filters;
    }
    // #endregion

    // #region Derived primitives
    @computed
    get $hasActiveFilters() {
        return task.filters.isActive(this.filters);
    }
    // #endregion

    // #region Data
    @computed
    get $visibleTasks(): Task[] {
        return this.tasks.filter(task.filter.byFilters(this.filters));
    }
    // #endregion

    // #region UI
    @computed
    get $columnsUI() {
        const lastIndex = this.columns.length - 1;

        return this.columns.map((column, index) => ({
            id: column.id,
            title: column.title,
            isEditing: this.editingColumnId === column.id,
            isMoveLeftDisabled: index === 0,
            isMoveRightDisabled: index === lastIndex,
            labels: {
                moveLeft: `Move column ${column.title} left`,
                moveRight: `Move column ${column.title} right`,
            },
            tasks: this.$visibleTasks
                .filter(task.filter.byColumn(column.id))
                .map((item) => ({
                    id: item.id,
                    title: item.title,
                    priorityLabel: priority.format.label(item.priority),
                    priorityPalette: priority.format.palette(item.priority),
                    dateRangeLabel: date.format.range(item.startDate, item.endDate),
                })),
        }));
    }
    // #endregion
}

export const kanbanStore = new KanbanStore();
```

* Collections are arrays of entities. Order is the array order; a task knows its `columnId`.
* Getters build presentation values. They use utils that add something (`task.filter.byFilters`, `date.format.range`) and plain code for the rest.

## What the Handle does instead of store methods

| ❌ Store method | ✅ Handle |
| --- | --- |
| `addTask(task)` | `store.setTasks([...store.tasks, created])` |
| `removeColumn(id)` | `store.setColumns(store.columns.filter(column.filter.removeIds([id])))` and `store.setTasks(store.tasks.filter(task.filter.removeColumnIds([id])))` |
| `updateTask(id, patch)` | `store.setTasks(store.tasks.map(task.map.update(id, patch)))` |
| `moveColumn(id, to)` | `store.setColumns(array.move(store.columns, from, to))` |
| `hydrate(snapshot)` | one setter call per field, in the persistence Handle |
| `resetFilters()` | `store.setFilters(task.filters.empty)` |
| `toggleTheme()` | `store.setTheme(store.$nextTheme)` |

## Wrong

```typescript
// ❌ makeAutoObservable / makeObservable: MobX 7 uses decorators
constructor() {
    makeAutoObservable(this, {}, { autoBind: true });
}

// ❌ logic in the store
moveTask(taskId: string, toColumnId: string) {
    const current = this.tasks.find((item) => item.id === taskId);
    if (current) current.columnId = toColumnId;
}

// ❌ a setter that writes several fields or mutates a nested value
setDialog(open: boolean, columnId: string | null) {
    this.open = open;
    this.columnId = columnId;
}

setColumnTitle(columnId: string, title: string) {
    this.columns.find((column) => column.id === columnId)!.title = title;
}
```

## Store test

Test `$` values by setting fields through setters.

```typescript
// src/features/kanban/store/store.test.ts
import { describe, expect, it } from "vitest";
import { KanbanStore } from "./store";

describe("KanbanStore", () => {
    it("disables moving the only column", () => {
        const store = new KanbanStore();

        store.setColumns([{ id: "a", title: "To Do" }]);

        expect(store.$columnsUI[0]).toMatchObject({
            title: "To Do",
            isMoveLeftDisabled: true,
            isMoveRightDisabled: true,
        });
    });
});
```

---
name: utils-implementation
description: Write and organize utils (pure helpers for formatting, mapping, filtering, math, parsing, ids, storage) as one namespace object per domain with clear, readable names. Use before creating or changing any util in TypeScript projects that have no utils convention of their own (`project-architecture` selects it); otherwise follow the project's existing helpers.
---

# User Input

```text
$ARGUMENTS
```

# Objective

Every util earns its existence and is easy to read: looking at the call site tells what it does.

Read `references/examples.md` before writing utils. It is based on the utils of the author's own projects (`calculation-pipeline` and `fe-assignment-react`) and shows what is worth a util and what is not.

# 1. A Util Must Earn Its Existence

Create a util only when it does one of these:

| Reason | Examples |
| --- | --- |
| Real logic: rules, parsing with a fallback, building a structure, calculations with edge cases | `task.validate(fields)`, `json.safeParser(raw, fallback)`, `canvas.chain.build(nodes, edges)`, `metrics.math.growth(first, last)` (null when `first` is 0) |
| Normalizing or reshaping data | `array.toArray(value)` (`T \| T[]` → `T[]`), `array.move(list, from, to)`, `metrics.aggregate.dailyTotals(points)` |
| Formatting with a fixed convention | `number.currency(value)`, `date.format.range(start, end)`, `priority.format.label(value)` |
| Building an entity whose shape needs logic (defaults that depend on a type, computed fields) | `task.defaults()` (dates default to today), `canvas.nodes.create(type, position)` (initial data depends on the node type) |
| A named, reusable callback for `find` / `filter` / `map` / `sort` that states a domain intention | `tasks.find(task.find.byId(id))`, `tasks.filter(task.filter.removeIds(ids))`, `nodes.map(canvas.nodes.map.updateData(id, data))` |

Do **not** create a util that only renames one native operation and reads the same inline:

```typescript
// ❌ wrappers with no utility
array.without(list, item)          // list.filter((current) => current !== item)
array.insert(list, index, item)    // [...list.slice(0, index), item, ...list.slice(index)]
record.add(items, item)            // { ...items, [item.id]: item }
record.remove(items, id)           // destructuring
task.has.errors(errors)            // Object.keys(errors).length > 0
column.create(id, title)           // { id, title }: write the object literal in the Handle
```

A plain object literal is never a util. The Handle that creates the entity writes it:

```typescript
async function handleCreate() {
    const created: Column = { id: random.id(), title: NEW_COLUMN_TITLE };

    store.setColumns([...store.columns, created]);

    return created.id;
}
```

Rule of thumb: if the body is one native call or one object literal, the util is used once, or the call site reads equally well without it, write the code inline.

Callbacks for array methods are the exception that proves the rule: `task.find.byId(id)` is one comparison, but it names the intention and is reused by Handles and stores, exactly like `canvas.nodes.find.byId` in the reference projects. A callback used once, with no domain meaning, stays inline.

# 2. Reuse First

Before writing a util, check the existing ones (`src/utils/`, `src/features/<feature>/utils/`). Extend a domain namespace that already exists instead of creating a new file or a duplicate function.

# 3. Location

```text
src/utils/<domain>/<domain>.ts                       # generic, used by any feature (array, json, number, random, storage, dev)
src/features/<feature>/utils/<domain>/<domain>.ts    # specific to one feature (board, card, canvas, metrics)
```

* `<domain>` is a singular noun in kebab-case: what the functions operate on.
* Tests live next to it: `<domain>.test.ts`.
* Import with the full path: `#/utils/number/number`. No `index.ts` barrel files.
* No `helpers.ts`, `common.ts`, `misc.ts` or flat `utils/<thing>.ts` files.

# 4. One Namespace per Domain

Each file exports **one object**, named after the domain in camelCase:

```typescript
export const board = { ... };
```

* No loose exported functions (`export function readJSON`).
* Types go to the feature `types`; constants used only by the util stay private at the top of the file (`const EMPTY_VALUE = "-"`).
* A constant other layers need is a member of the namespace (`priority.list`, `priority.default`), not a separate export.

# 5. Group by Intent

Inside the namespace, group members by what they do. The call site must read like a sentence:

| Group | Use | Call site |
| --- | --- | --- |
| `find` | predicates for `.find()` | `cards.find(board.cards.find.byId(id))` |
| `filter` | predicates for `.filter()` | `cards.filter(board.cards.filter.byColumn(columnId))` |
| `map` | transformers for `.map()` | `cards.map(board.cards.map.moveTo(columnId))` |
| `sort` | comparators for `.sort()` | `cards.sort(board.cards.sort.byPriority())` |
| `format` | values → display strings | `number.format.currency(value)` |
| `math` / `aggregate` | calculations | `metrics.math.average(total, days)` |
| `create` | build new entities | `board.cards.create(payload)` |
| `is` / `has` | boolean checks | `priority.is(value)` |
| `to<Thing>` | conversions | `metrics.chart.toSeries(measure)` |

Nest by entity when a domain has several (`canvas.nodes.find.byType`, `canvas.edges.filter.removeIds`).

# 6. Callbacks Are Curried

Predicates, mappers and comparators used in array methods take their arguments first and return the callback:

```typescript
find: {
  byId: (id: string) => (card: Card) => card.id === id,
},
```

```typescript
// ✅ Correct
const card = cards.find(board.cards.find.byId(id));

// ❌ Wrong
const card = cards.find((card) => card.id === id);
const card = findCardById(cards, id);
```

Comparators and mappers without arguments are still factories (`sort.byPriority()`, `map.toOption()`), so every call site has the same shape.

# 7. Naming

* Names describe the result, not the mechanics: `byColumn`, `currency`, `average`, `toSeries`.
* Predicates start with `by` (find/filter) or `is` / `has` (checks).
* No `get`, `handle`, `do`, `util`, `helper` prefixes; no abbreviations.
* The namespace path already gives context: `date.format.short`, not `date.formatDateShort`.

# 8. Function Bodies

* Short members are written inline in the namespace.
* A member longer than a few lines is a named function declared above the namespace and referenced from it:

```typescript
function buildChainFromCanvas(nodes: CanvasNode[], edges: Edge[]): CanvasOperationNode[] {
  // ...
}

export const canvas = {
  chain: {
    build: buildChainFromCanvas,
  },
};
```

* Members reuse each other through the namespace (`number.currency` calls `number.format`).
* Early returns over nested conditionals.
* Explicit return types on members whose result type is not obvious.

# 9. Immutable Updates in Handles

Stores only have plain setters (`command-bus-architecture`), so the Handle computes the next array and passes it to the setter. Use the array methods with the entity's callbacks, and plain code for the rest:

```typescript
store.setTasks([...store.tasks, created]);                                 // add: inline
store.setTasks(store.tasks.filter(task.filter.removeIds([taskId])));       // remove
store.setTasks(store.tasks.map(task.map.update(taskId, { priority })));    // update
store.setColumns(array.move(store.columns, from, to));                     // reorder
```

* `map.update(id, patch)` returns a mapper that replaces the matching entity with a new object and returns every other entity unchanged.
* Never mutate the store's arrays or entities.

# 10. Purity

Utils are pure: same input, same output.

* No store access, no React, no `actions` / `command`, no API calls.
* Platform wrappers (`storage`, `json`, `random`, `dev`) live only in `src/utils/`, swallow platform errors with a safe fallback, and are called from Handles, never from components.
* Utils are used by store `$` getters and by Handles. Components do not call utils; they read prepared `$` values (`command-bus-architecture`).

# 11. Example

```typescript
// src/features/kanban/utils/priority/priority.ts
import type { Priority } from "#/features/kanban/types";

const PRIORITIES: readonly Priority[] = ["low", "medium", "high"];

const META: Record<Priority, { label: string; palette: string }> = {
    low: { label: "Low", palette: "palette-green" },
    medium: { label: "Medium", palette: "palette-orange" },
    high: { label: "High", palette: "palette-danger" },
};

export const priority = {
    list: PRIORITIES,
    default: "medium" as Priority,

    is: (value: unknown): value is Priority =>
        PRIORITIES.includes(value as Priority),

    format: {
        label: (value: Priority): string => META[value].label,
        palette: (value: Priority): string => META[value].palette,
    },

    map: {
        toOption: () => (value: Priority) => ({
            value,
            label: META[value].label,
        }),
    },

    sort: {
        byWeight: () => (a: Priority, b: Priority): number =>
            PRIORITIES.indexOf(b) - PRIORITIES.indexOf(a),
    },
};
```

# 12. Final Output

Return:

* Utils created or extended (namespace path and members), each with the reason it earns its existence
* Existing utils reused

Return this output to the calling skill and continue its flow. Do not end the run here unless this skill was invoked directly by the user.

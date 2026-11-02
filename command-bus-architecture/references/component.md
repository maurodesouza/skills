# Component reference

Components read prepared values and dispatch actions. Headless parts are assembled explicitly by whoever uses them.

## A part reading the store

```tsx
// src/features/kanban/components/kanban/board.tsx
import { PlusIcon } from "lucide-react";
import { observer } from "mobx-react-lite";
import { Clickable } from "#/components/atoms/clickable";
import { useKanban } from "#/features/kanban/hooks/use-kanban";
import { actions } from "#/lib/command";

export const NewTaskAction = observer(() => {
    const store = useKanban();
    const { newTaskLabel } = store.$boardUI;

    return (
        <Clickable.Button
            className="palette-blue"
            onClick={() => actions.task.editStart({})}
        >
            <PlusIcon />
            {newTaskLabel}
        </Clickable.Button>
    );
});
```

## A part receiving its view model

Parts rendered inside a `render` prop receive the item view model (prepared by `$columnsUI`) and present it.

```tsx
// src/features/kanban/components/kanban/column.tsx
import { ArrowLeftIcon } from "lucide-react";
import { Clickable } from "#/components/atoms/clickable";
import type { ColumnUI } from "#/features/kanban/store/store";
import { actions } from "#/lib/command";

export function MoveLeftAction({ column }: { column: ColumnUI }) {
    return (
        <Clickable.Button
            variant="icon"
            shape="square"
            size="sm"
            aria-label={column.labels.moveLeft}
            disabled={column.isMoveLeftDisabled}
            onClick={() => actions.column.moveBy({ columnId: column.id, offset: -1 })}
        >
            <ArrowLeftIcon />
        </Clickable.Button>
    );
}
```

## Explicit assembly

```tsx
// src/routes/index.tsx
function renderColumn(column: ColumnUI) {
    return (
        <Kanban.Column.Container column={column}>
            <Kanban.Column.Header>
                <Kanban.Column.Title column={column} />
                <Kanban.Column.Actions>
                    <Kanban.Column.MoveLeftAction column={column} />
                    <Kanban.Column.MoveRightAction column={column} />
                </Kanban.Column.Actions>
            </Kanban.Column.Header>

            <Kanban.Column.Content>
                <Kanban.Tasks column={column} render={renderTask} />
            </Kanban.Column.Content>
        </Kanban.Column.Container>
    );
}
```

No part renders other Kanban parts on the consumer's behalf.

## Wrong

```tsx
// ❌ choosing a label from state
const label = store.isDark ? "Switch to light mode" : "Switch to dark mode";

// ❌ building a string from state
aria-label={`Move column ${column.title} left`}

// ❌ deriving data
const visible = tasks.filter((task) => task.priority === filter);

// ❌ a part that hides the composition
export function Column({ column }) {
    return (
        <Container>
            <Header><Title /><Actions /></Header>
            <Tasks />
        </Container>
    );
}
```

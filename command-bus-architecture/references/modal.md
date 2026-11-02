# Modal reference

The app has one modal, in its own feature (`src/features/modal/`), so any part of the app can use it. Feature code never renders `Dialog.Root` or `AlertDialog.Root`; it sends content to the modal with `actions.modal.open(Content)`.

## Renderable and FlexibleRender

```typescript
// src/types/renderable.ts
import type { JSX, ReactElement } from "react";

/** A component or an element: whatever `FlexibleRender` can render. */
export type Renderable<TProps = unknown> =
    | ((props?: TProps) => JSX.Element)
    | ReactElement;
```

```tsx
// src/components/helpers/flexible-render/flexible-render.tsx
import { isValidElement } from "react";
import type { Renderable } from "#/types/renderable";

type FlexibleRenderProps = {
    render?: Renderable;
};

/** Renders a Renderable, whether it is an element or a component. */
export function FlexibleRender({ render: Render }: FlexibleRenderProps) {
    if (!Render) return null;

    if (isValidElement(Render)) return Render;

    return <Render />;
}
```

## Actions

```typescript
// src/features/modal/components/handles/modal/modal-actions.ts
import type { Action } from "#/lib/command/types";
import type { Renderable } from "#/types/renderable";

declare module "#/lib/command/global" {
    interface Actions {
        modal: {
            open: Action<Renderable>;
            close: Action;
        };
    }
}
```

## ModalHandle (the modal Handle and the only Dialog.Root)

```tsx
// src/features/modal/components/handles/modal/modal-handle.tsx
import { useEffect, useState } from "react";
import { FlexibleRender } from "#/components/helpers/flexible-render/flexible-render";
import { Dialog } from "#/components/ui/dialog";
import { actions, command } from "#/lib/command";
import type { Renderable } from "#/types/renderable";

/**
 * The only dialog of the app. It handles the `modal` domain itself and renders
 * whatever content `actions.modal.open(Content)` sends. The content renders its
 * own `Dialog.Content`.
 */
export function ModalHandle() {
    const [content, setContent] = useState<Renderable>();

    async function handleOpen(modal: Renderable) {
        setContent(() => modal);
    }

    async function handleClose() {
        setContent(undefined);
    }

    // biome-ignore lint/correctness/useExhaustiveDependencies: handlers only call the stable state setter
    useEffect(() => {
        const disposes = [
            command.handle("modal.open", handleOpen),
            command.handle("modal.close", handleClose),
        ];

        return () => {
            for (const dispose of disposes) dispose();
        };
    }, []);

    return (
        <Dialog.Root
            open={Boolean(content)}
            onOpenChange={(open) => {
                if (!open) actions.modal.close();
            }}
        >
            <Dialog.Portal>
                <Dialog.Backdrop />
                <FlexibleRender render={content} />
            </Dialog.Portal>
        </Dialog.Root>
    );
}
```

* `setContent(() => modal)`: a component is a function, so it is wrapped to be stored, not called, by `useState`.
* Mount `<ModalHandle />` once, in the root route.
* A drawer would follow the same shape: `src/features/drawer/components/handles/drawer/` with `drawer-actions.ts` and `drawer-handle.tsx`, where `DrawerHandle` renders the `Drawer`.

## Content: a confirmation

The column view model already carries the texts the confirmation presents (prepared by `$columnsUI`), so the content only presents them. It renders its own `Dialog.Content`.

```typescript
// in KanbanStore.$columnsUI, per column
deleteConfirm: {
    title: `Delete "${column.title}"?`,
    description: taskCount > 0
        ? `This column and its ${tasksLabel} will be permanently deleted.`
        : "This column will be permanently deleted.",
    cancelLabel: "Cancel",
    confirmLabel: "Delete column",
},
```

```tsx
// src/features/kanban/components/column-delete-confirm/column-delete-confirm.tsx
import { Clickable } from "#/components/atoms/clickable";
import { Dialog } from "#/components/ui/dialog";
import type { ColumnUI } from "#/features/kanban/store/store";
import { actions } from "#/lib/command";

export function ColumnDeleteConfirm({ column }: { column: ColumnUI }) {
    const { title, description, cancelLabel, confirmLabel } = column.deleteConfirm;

    return (
        <Dialog.Content>
            <Dialog.Header>
                <Dialog.Title>{title}</Dialog.Title>
                <Dialog.Description>{description}</Dialog.Description>
            </Dialog.Header>
            <Dialog.Footer>
                <Clickable.Button variant="outline" onClick={() => actions.modal.close()}>
                    {cancelLabel}
                </Clickable.Button>
                <Clickable.Button
                    className="palette-danger"
                    onClick={() => actions.column.delete({ columnId: column.id })}
                >
                    {confirmLabel}
                </Clickable.Button>
            </Dialog.Footer>
        </Dialog.Content>
    );
}
```

The `column` Handle deletes the column (and its tasks), then calls `actions.modal.close()`.

Content that must react to state while open (a form showing validation errors) is an `observer` that reads its own `$<part>UI` getter, like any other component.

## Opening

```tsx
// nothing to prepare: open with an element (props) or a component (no props)
<DropdownMenu.Item
    onClick={() => actions.modal.open(<ColumnDeleteConfirm column={column} />)}
>
    Delete column
</DropdownMenu.Item>

<Clickable.Button onClick={() => actions.modal.open(ShareModal)}>Share</Clickable.Button>
```

```typescript
// something to prepare (prefill the form): a domain action, the Handle opens the modal
async function handleEditStart(payload: { taskId: string }) {
    const current = store.tasks.find(task.find.byId(payload.taskId));

    if (!current) return;

    formStore.setValues(task.form.fromTask(current));
    formStore.setErrors({});
    formStore.setTaskId(current.id);

    await actions.modal.open(TaskForm);
}
```

## Wrong

```tsx
// ❌ a dialog owned by a feature, with its own open flag and actions
<AlertDialog.Root open={store.$columnDeleteDialogUI.open} onOpenChange={...}>

// ❌ open flags or content in a store
columnDeleteDialog = { open: false, columnId: null };

// ❌ per-dialog actions
actions.kanban.columnDeleteDialog.open({ columnId });

// ❌ the modal outside its feature, or named as a plain component
src/components/modal/modal.tsx   // export function Modal()

// ❌ wrapping the payload: modal.open receives the Renderable itself
actions.modal.open({ content: <ColumnDeleteConfirm column={column} /> });
```

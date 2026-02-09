# Undo/redo architecture reference

## Coordinated layers

1. `redux-undo` in each undoable slice stores `past`, `present`, and `future`.
2. `historyEraser` in `src/app/store.ts` keeps cross-slice timelines consistent.
3. UI coordination in `src/features/ui/uiSlice.ts` records order in `undoStack` and `redoStack`.

## Timeline invalidation rule

When a new action occurs in one slice, clear `future` for other undoable slices with pending futures. This prevents invalid branches across slices.

## Store integration notes

- Configure each undoable slice with explicit `undoType` and `redoType`.
- Use a `filter` that excludes initialization and no-op transitions.
- Keep slice names consistent between reducer keys, middleware checks, and `UndoRedoType`.

## Adding a new undoable slice

1. Wrap reducer with `undoable(...)` and `historyEraser(...)` in `src/app/store.ts`.
2. Add the slice key to `UndoRedoType` in `src/features/ui/uiSlice.ts`.
3. Include slice namespace in `undoRedoActionIdMiddleware` dispatch conditions.
4. Exclude initialization actions in the undo filter.
5. Add or update tests covering:
- Same-slice undo/redo.
- Cross-slice future invalidation.
- Keyboard and UI trigger paths.

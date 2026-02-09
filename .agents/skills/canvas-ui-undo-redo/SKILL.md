---
name: canvas-ui-undo-redo
description: Analyze, debug, or modify Drupal Canvas UI undo/redo behavior across Redux slices. Use when work touches timeline history, redux-undo integration, historyEraser logic, uiSlice undoStack or redoStack, undo/redo middleware, or tests for cross-slice timeline consistency.
---

# Canvas UI undo/redo

Use this workflow for files under `web/modules/contrib/canvas/ui` that affect undo or redo behavior.

## Quick triage

1. Locate the changed layer:
- Slice history state (`past/present/future`) and `undoable(...)` setup in `src/app/store.ts`.
- Cross-slice timeline invalidation in `historyEraser` logic in `src/app/store.ts`.
- Undo/redo sequence coordination in `src/features/ui/uiSlice.ts`.
- Auto-tracking of undoable actions in `undoRedoActionIdMiddleware` in `src/app/store.ts`.
2. Identify whether the change is a new action, an undo/redo action, or stack bookkeeping.
3. Enforce linear timeline rules before implementing anything.

## Invariants to preserve

- Treat each undoable slice as an independent timeline managed by `redux-undo`.
- Keep global user experience linear by coordinating slice order through UI stacks.
- Clear `future` states on any new action that creates a branch.
- Preserve `future` states during undo/redo navigation.
- Never merge slice histories into one state object.

Read `references/architecture.md` when you need deeper details or when adding a new undoable slice.

## Change checklist

1. Update reducer wiring in `store.ts` if an undoable slice is added or changed.
2. Keep `UndoRedoType` in `uiSlice.ts` synchronized with participating slices.
3. Update middleware slice detection in `store.ts` when introducing new undoable slice namespaces.
4. Ensure any `filter` function excludes initialization actions and only tracks meaningful edits.
5. If preview updates must happen on historical states, enforce it with `historyEraser` overrides.

## Testing checklist

1. Run targeted Vitest tests for changed hooks, reducers, or utilities.
2. Run impacted Cypress component specs in `ui/tests/unit`, especially timeline scenarios.
3. Run relevant Playwright specs for keyboard shortcuts or end-to-end undo/redo flow.
4. Finish with full UI Vitest suite once targeted tests pass.

Read `references/tests.md` for command templates and selection guidance.

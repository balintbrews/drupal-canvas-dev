---
name: canvas-ui-code-editor
description:
  Analyze, debug, or modify the Drupal Canvas in-browser code editor. Use when
  work touches codeEditorSlice state, code editor lifecycle hooks, auto-save,
  source compilation, props or slots serialization, or editor-specific component
  and integration tests.
---

# Canvas UI code editor

Use this workflow for code editor changes in
`web/modules/contrib/canvas/ui/src/features/code-editor/**`.

## Quick triage

1. Classify the change as one of:

- State shape or actions in `codeEditorSlice.ts`.
- Lifecycle orchestration in `hooks/useCodeEditor.ts`.
- Debounced save logic in `hooks/useAutoSave.tsx`.
- Compilation behavior in `hooks/useSourceCode.ts`.
- Serialization or derivation utilities in code editor utils files.

2. Determine whether changes affect component source, global assets, or both.
3. Enumerate side effects on compilation status, save status, and unsaved-change
   flags.

## Invariants to preserve

- Keep `needsAutoSave` and `hasUnsavedChanges` transitions consistent with user
  edits.
- Avoid save loops by preserving debounced and ref-guarded auto-save behavior.
- Keep compilation error reporting explicit and user-visible.
- Keep component props and slots serialization backward compatible unless
  migration is planned.

Read `references/lifecycle.md` for detailed lifecycle and state guidance.

## High-risk touchpoints

- `initializeCodeEditor` and `resetCodeEditor` flow.
- `setCodeComponentProperty` and related state updates.
- `serializeProps()` and `deserializeProps()`.
- `derivedPropTypes` mappings.
- Import and dependency tracking from component source.

## Change checklist

1. Update TypeScript types first when prop or slot schema changes.
2. Update derivation and serialization together in the same patch.
3. Confirm state flags for compile/save transitions are still coherent.
4. Verify preview behavior when source code, CSS, or global CSS changes.
5. Ensure cleanup on unmount still prevents stale state.

## Testing checklist

1. Run targeted Vitest tests for updated hooks, reducers, and utilities.
2. Run impacted Cypress component specs in `ui/tests/unit`.
3. If behavior affects end-to-end editor flow, run targeted Playwright specs.
4. Finish with full UI Vitest suite once targeted tests pass.

Read `references/tests.md` for command templates and file-to-test mapping hints.

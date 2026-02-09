# Code editor lifecycle reference

## Core state responsibilities

`codeEditorSlice.ts` tracks:
- Editor status flags.
- Current code component data.
- Global asset library data.
- Compiled slot preview code.

## Typical data flow

1. Initialize editor state from URL and backend data.
2. Apply edits through state update actions.
3. Compile source and stylesheet changes.
4. Debounce save when autosave is needed.
5. Reset state during unmount or editor teardown.

## Prop and slot schema updates

When adding or changing a prop type:
1. Update shared types in `src/types/CodeComponent.ts`.
2. Update `derivedPropTypes` mappings.
3. Update serializer and deserializer logic.
4. Update form UI for editing the new type.
5. Update tests covering serialization and editor interactions.

## Common regression risks

- Autosave firing too often or not firing at all.
- Status flags out of sync with compile or save operations.
- Lost or incompatible serialized prop values.
- Preview and iframe rendering not reflecting updated source.

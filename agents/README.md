# Agents setup

This project uses two agent scopes so instructions stay focused on the task at
hand.

## Quick overview

- `agents/environment`: root-level environment and tooling work.
- `agents/canvas`: Canvas project code work.

Each scope has its own `AGENTS.md`, its own `skills/` directory, and separate
`SKILL.md` files inside each skill folder.

## Which workspace to open

- Open the root workspace for DDEV configuration and commands, recipe
  maintenance under `recipes/*`, root-level tooling and helper scripts, and
  infrastructure or agent setup files (for example, `agents/*`, `.ddev/*`, and
  repository-wide configuration).
- Open `web/modules/contrib/canvas` for Canvas code changes.

## How instructions are selected

`AGENTS.md` symlinks:

- `AGENTS.md -> agents/environment/AGENTS.md`
- `web/modules/contrib/canvas/AGENTS.md -> ../../../../agents/canvas/AGENTS.md`

When you open one of those workspaces, the matching scope is used automatically.

## Skills locations

Environment skills:

- `agents/environment/skills/canvas-dev-humanify-recipe-update/SKILL.md`

Canvas skills:

- `agents/canvas/skills/canvas-test-selector/SKILL.md`
- `agents/canvas/skills/canvas-ui-code-editor/SKILL.md`
- `agents/canvas/skills/canvas-ui-undo-redo/SKILL.md`

## Skills symlinks

- `.agents/skills -> ../agents/environment/skills`
- `web/modules/contrib/canvas/.agents/skills -> ../../../../../agents/canvas/skills`

## Local nested-repo excludes

The Canvas module is a separate Git repository at `web/modules/contrib/canvas`.

`ddev clone-repo` adds local-only exclude rules to
`web/modules/contrib/canvas/.git/info/exclude` for:

- `AGENTS.md`
- `.agents/`

This keeps those agent setup paths untracked in the nested repository without
editing the module repository's `.gitignore`.

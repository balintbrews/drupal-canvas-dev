## Scope and purpose

This file is for environment-level work in this repository root.

- Default focus in this scope: DDEV setup, repo tooling, scripts, recipes, and
  agent configuration.
- For Canvas module code work, use `web/modules/contrib/canvas/AGENTS.md` as the
  source of truth.

## Repo boundaries

- Do not modify files under `web/**` outside `web/modules/contrib/canvas`,
  unless explicitly requested.
- Do not make Canvas module code changes from root-level tasks unless the user
  asks for cross-repo coordination.

## Environment and command policy

- Use DDEV-wrapped commands in this workspace.
- Use `ddev composer` for Composer operations.
- Use `ddev drush` for Drush operations.
- Never run destructive Drush or site commands (for example, reinstall or
  DB-destructive operations) without explicit user approval.

## Writing and style

- Keep wording concise and concrete.
- Use sentence case for headings, labels, and documentation.
- Use Oxford commas.
- Follow AP Style for general writing conventions.
- Avoid marketing adjectives and hype language.
- Avoid emojis unless they materially improve clarity.
- In project docs and skills, use project-relative paths (for example,
  `recipes/...`), not absolute filesystem paths.

## Code comments

- Do not remove existing inline comments when editing nearby code.
- Add comments only when they explain non-obvious intent or tradeoffs.
- Write comment text as full sentences with ending punctuation.
- Prefer standalone comment lines above the code they explain.

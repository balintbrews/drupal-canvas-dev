## Project context

Drupal Canvas includes:

- Backend PHP module code in this repository root.
- React/TypeScript UI in `ui`.
- Monorepo packages (CLI, workbench, Vite plugin, extensions, and others) in
  `packages/*`.

## Environment and command policy

- Use DDEV-wrapped commands in this workspace.
- Use `ddev composer` for Composer operations.
- Use `ddev drush` for Drush operations.
- Never compare, diff, or validate work against the `7.x-1.x` branch.
- Never run destructive Drush or site commands (for example, reinstall or
  DB-destructive operations) without explicit user approval.

## Writing and style

- Keep wording concise and concrete.
- Use sentence case for headings, labels, and documentation.
- Use Oxford commas.
- Follow AP Style for general writing conventions.
- Avoid marketing adjectives and hype language.
- Avoid emojis unless they materially improve clarity.
- In project docs and skills, use project-relative paths, never absolute paths.

## Code comments

- Do not remove existing inline comments when editing nearby code.
- Add comments only when they explain non-obvious intent or tradeoffs.
- Write comment text as full sentences with ending punctuation.
- Prefer standalone comment lines above the code they explain.

## Validation and tests

When code changes are made, run targeted checks first, then broader checks where
appropriate.

### UI (`ui`)

- Run relevant Vitest files first: `ddev n run test -- <relative-test-path>`.
- After targeted Vitest passes, run the full Vitest suite: `ddev n run test`.
- If covered by Cypress component tests, run only impacted specs:
  `ddev cy --component --spec <relative-spec-path>`.
- Never run the full Cypress component test suite.
- Never run Cypress end-to-end tests.

### Playwright end-to-end (`tests`)

- If impacted, run targeted specs only:
  `ddev playwright --spec <relative-spec-path>`.

### Backend PHP (repository root)

- Run impacted PHPUnit tests: `ddev phpunit <relative-path>`.
- Run static analysis after backend changes: `ddev phpstan`.
- Run coding standards checks and fixes after backend changes: `ddev phpcs`
  (optionally scoped to a relative path).

### CLI package

- No standardized test workflow is documented yet.
- Do not guess broad test commands; ask or use only task-specific verified
  commands.

## Project context

Drupal Canvas includes:

- Backend PHP module code in this repository root.
- React/TypeScript UI in `ui`.
- Monorepo packages (CLI, workbench, Vite plugin, extensions, and others) in
  `packages/*`.

## Environment and command policy

- Use host machine commands by default for Node and npm workflows outside the UI
  package.
- Use DDEV-wrapped commands for Drupal environment workflows, and for UI package
  workflows in `web/modules/contrib/canvas/ui` when browser-served behavior is
  required.
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

After changes, run `npm run fix` from the repository root to apply ESLint and
Prettier fixes, then fix any remaining issues and re-run it.

### Packages (`packages/*`)

- Run package npm commands directly on the host machine.
- In this monorepo, type-checking is usually package-local via each workspace's
  `type-check` script.
- There is no single root type-check orchestrator for all packages, so run
  `npm run type-check` in each impacted package.
- If an impacted package defines a `test` script, run `npm run test` in that
  package.
- If no `test` script is defined, do not guess broad test commands; ask or use
  only task-specific verified commands.

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

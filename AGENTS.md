## Scope and repo boundaries

- Treat `web/modules/contrib/canvas` as the default work area.
- Do not modify files under `web/**` outside `web/modules/contrib/canvas`,
  unless explicitly requested.
- Only work in repo root (`.`) when the task is about environment tooling, AI
  agent config, or infrastructure.

## Project context

Drupal Canvas is a Drupal module with:

- Backend PHP module code in `web/modules/contrib/canvas`.
- React/TypeScript UI in `web/modules/contrib/canvas/ui`.
- Monorepo packages (CLI, workbench, Vite plugin, extensions, and others) in
  `web/modules/contrib/canvas/packages/*`.

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

## Code comments

- Do not remove existing inline comments when editing nearby code.
- Add comments only when they explain non-obvious intent or tradeoffs.
- Write comment text as full sentences with ending punctuation.
- Prefer standalone comment lines above the code they explain.

## Validation and tests

When code changes are made, run targeted checks first, then broader checks where
appropriate.

### UI (`web/modules/contrib/canvas/ui`)

- Run relevant Vitest files first: `ddev n run test -- <relative-test-path>`.
- After targeted Vitest passes, run the full Vitest suite: `ddev n run test`.
- If covered by Cypress component tests, run only impacted specs:
  `ddev cy --component --spec <relative-spec-path>`.
- Never run the full Cypress component test suite.
- Never run Cypress end-to-end tests.

### Playwright end-to-end (`web/modules/contrib/canvas/tests`)

- If impacted, run targeted specs only:
  `ddev playwright --spec <relative-spec-path>`.

### Backend PHP (`web/modules/contrib/canvas`)

- Run impacted PHPUnit tests: `ddev phpunit <relative-path>`.
- Run static analysis after backend changes: `ddev phpstan`.
- Run coding standards checks and fixes after backend changes: `ddev phpcs`
  (optionally scoped to a relative path).

### CLI package

- No standardized test workflow is documented yet.
- Do not guess broad test commands; ask or use only task-specific verified
  commands.

## Skills

Skill location policy:

- When asked to create or update skills for this project, create them in-repo
  under `.agents/skills`.
- Do not place project skills in home-directory skill folders unless explicitly
  requested.

Use these focused skills for deeper workflows:

- `canvas-ui-undo-redo` for multi-slice undo/redo architecture and safe change
  checklists.
- `canvas-ui-code-editor` for code editor lifecycle, state model, and high-risk
  touchpoints.
- `canvas-test-selector` for selecting the minimum safe test commands by changed
  paths.

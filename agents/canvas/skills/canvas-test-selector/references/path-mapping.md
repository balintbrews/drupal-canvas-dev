# Path mapping reference

## UI paths

- Prefix: `web/modules/contrib/canvas/ui/`
- Prefer co-located Vitest files ending in `.test.ts` or `.test.tsx`.
- Check `web/modules/contrib/canvas/ui/tests/unit/` for Cypress component
  coverage.

## Playwright paths

- Prefix: `web/modules/contrib/canvas/tests/`
- Run targeted specs with `ddev playwright --spec ...`.

## Backend paths

- Prefix: `web/modules/contrib/canvas/` excluding `ui/` and `tests/`.
- Prefer impacted PHPUnit path(s) plus `ddev phpstan` and `ddev phpcs`.

## CLI and packages paths

- Prefix: `web/modules/contrib/canvas/packages/`
- If no documented package-specific test command exists, avoid broad guesses and
  run only verified task-specific commands.

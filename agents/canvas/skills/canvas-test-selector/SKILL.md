---
name: canvas-test-selector
description:
  Select and run the minimum safe verification commands for Drupal Canvas
  changes. Use when determining which test, analysis, or lint commands to run
  based on changed files in UI, backend, Playwright tests, or related
  package paths.
---

# Canvas test selector

Use this skill after identifying changed files and before running broad
validation.

## Decision flow

1. Classify changed paths:

- UI app: `web/modules/contrib/canvas/ui/**`.
- Playwright tests or E2E-affecting code: `web/modules/contrib/canvas/tests/**`.
- Backend PHP: `web/modules/contrib/canvas/**` outside `ui/**` and `tests/**`.
- Other packages: `web/modules/contrib/canvas/packages/**`.

2. Run narrow, directly impacted tests first.
3. Run broader suite only where policy requires it.

## Command matrix

- UI package commands use DDEV wrappers.
- UI targeted Vitest: `ddev n run test -- <relative-test-path-from-ui-dir>`
- UI full Vitest after targeted pass: `ddev n run test`
- UI targeted Cypress component spec:
  `ddev cy --component --spec tests/unit/<spec-file>`
- Playwright targeted spec:
  `ddev playwright --spec tests/src/Playwright/<spec-file>`
- Backend targeted PHPUnit: `ddev phpunit <relative-path-from-canvas-root>`
- Backend static analysis: `ddev phpstan`
- Backend coding standards: `ddev phpcs [optional-relative-path]`
- Other non-UI package npm checks: run with host `npm` in the package
  directory.

## Guardrails

- Never run full Cypress component suite.
- Never run Cypress end-to-end tests.
- Do not wrap non-UI package npm commands in DDEV.
- Do not invent unverified broad test commands for CLI package paths.

## Output format

When asked to choose tests, return:

1. Exact commands in run order.
2. Why each command is included.
3. Explicit mention of what is intentionally skipped.

Read `references/path-mapping.md` when path classification is ambiguous.

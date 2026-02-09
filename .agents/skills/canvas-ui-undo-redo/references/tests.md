# Undo/redo test commands

## Vitest

- Targeted: `ddev n run test -- <relative-path-to-test-file>`
- Full suite after targeted pass: `ddev n run test`

## Cypress component

- Targeted only: `ddev cy --component --spec tests/unit/<spec-file>`
- Do not run entire component suite.

## Playwright

- Targeted only: `ddev playwright --spec tests/src/Playwright/<spec-file>`

## Selection hints

- State transition and reducer logic: prioritize Vitest.
- Timeline coordination and UI interactions: prioritize Cypress component tests.
- Keyboard shortcuts and integrated undo/redo navigation: prioritize Playwright.

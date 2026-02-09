# Code editor test commands

## Vitest

- Targeted: `ddev n run test -- <relative-path-to-test-file>`
- Full suite after targeted pass: `ddev n run test`

## Cypress component

- Targeted only: `ddev cy --component --spec tests/unit/<spec-file>`
- Do not run entire component suite.

## Playwright

- Targeted only: `ddev playwright --spec tests/src/Playwright/<spec-file>`

## Selection hints

- Hooks, reducers, and utility behavior: Vitest first.
- Editor interactions and prop management UI: Cypress component tests.
- Full page flows and keyboard behavior: Playwright targeted specs.

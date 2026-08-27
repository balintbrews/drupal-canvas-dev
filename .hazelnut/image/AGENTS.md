# Drupal Canvas development container

Drupal 11 environment for developing the Drupal Canvas module. PHP 8.3, Node.js
24, Composer 2, MariaDB (local socket, database `db`, user `db`, password `db`).

## Layout

- Canvas checkout (work here): `~/workspace/canvas`
- Drupal environment root: `~/workspace/drupal` (also `$CANVAS_ENV_ROOT`)
- The checkout is symlinked to `web/modules/contrib/canvas`; never edit files
  through the Drupal path.

## Setup and serving

Run once per session, from `$CANVAS_ENV_ROOT` (the default directory):

1. `composer install --no-interaction`
2. `site-install` (alias `si`) — installs Drupal plus Canvas.
   - default: sample content, builds the UI (first build is slow)
   - `--stark`: minimal theme content
   - `--ui`: skips the UI build and enables `canvas_vite`, which serves UI
     assets from the Vite dev server; then run `ui` to start it on :5173
   - `--mercury`: Mercury theme demo content
3. `canvas-env-start` — serves the site at http://127.0.0.1:8080 (run in the
   background). Credentials: `admin` / `admin`.

`canvas-env-start` also starts MariaDB and a virtual display with a VNC bridge.
Watch headed browser sessions at http://localhost:6080/vnc.html.

## Commands

All commands work from any directory.

- `phpunit [path]` — PHPUnit with Drupal core's config; paths are relative to
  the Canvas module, for example `phpunit tests/src/Unit`. Functional tests need
  `canvas-env-start` running.
- `cypress` (alias `cy`) — Cypress e2e run; `--component` for component tests,
  `--spec <spec>` to filter, `--open` for interactive mode via VNC.
- `playwright [args]` — `playwright test` in the Canvas root; all Playwright CLI
  arguments pass through.
- `phpcs [path]` / `phpstan [path]` — PHPCBF and PHPStan with Canvas's
  configuration.
- `ui` — builds the UI, enables `canvas_vite`, and starts the Vite dev server;
  `--skip-build` to skip the build.
- `drush`, `composer` — on PATH; Drush is preconfigured with the site URI.

The Cypress binary and Playwright's Chromium are baked into the image; no
browser installs are needed.

## npm and Turborepo

The Canvas repository is an npm workspaces monorepo built with Turborepo. Run
npm scripts from `~/workspace/canvas` (root `package.json`) or a workspace
directory. Builds cache under `.turbo/`; unchanged rebuilds are near-instant.
All workspaces require Node.js `>=22.19.0 <23 || >=24.5.0`; the image ships
24.x.

## Pitfalls

- The Canvas checkout physically lives at
  `~/workspace/drupal/web/modules/contrib/canvas`; `~/workspace/canvas` is a
  symlink to it. Keep it that way: Canvas tooling finds Drupal by walking up
  parent directories from the physical path.
- After enabling or disabling modules outside `site-install`, run
  `drush cache:rebuild` before using the Canvas editor.
- Environment variables for tests (`SIMPLETEST_*`, `DRUPAL_TEST_*`, `BASE_URL`,
  `DRUPAL_ROOT_CORE`) are preset; do not override them unless a test documents
  otherwise.

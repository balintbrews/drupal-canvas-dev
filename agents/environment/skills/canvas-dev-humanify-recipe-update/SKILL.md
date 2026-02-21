---
name: canvas-dev-humanify-recipe-update
description: Update the
`recipes/canvas_dev_humanify` recipe by exporting `js_component` config and
default content, normalizing exported content/config files, and verifying
install.
---

# Canvas Dev Humanify recipe update

Use this skill only when updating `recipes/canvas_dev_humanify` after content or
`js_component` changes.

## Scope

- Work in the project root (`.`).
- Primary targets:
  - `recipes/canvas_dev_humanify/config`
  - `recipes/canvas_dev_humanify/content`
- Use DDEV wrappers for Drupal and site commands in this workflow.
- Run repository npm formatting commands on the host machine.

## Workflow

1. Take a safety snapshot before destructive install checks.

- `ddev snapshot`

2. Export active config to a temporary directory and copy back only
   `canvas.js_component.*.yml` files used by Humanify.

- `ddev drush cex --destination=../<tmp_dir> -y`
- Copy `canvas.js_component.*.yml` from `<tmp_dir>` to
  `recipes/canvas_dev_humanify/config/`.

3. Export default content with references for the `canvas_page` entity included
   in `recipes/canvas_dev_humanify`.

- Get UUID from `recipes/canvas_dev_humanify/content/canvas_page/*.yml`.
- Resolve entity ID:
  - `ddev drush php:eval "\$e = \Drupal::service('entity.repository')->loadEntityByUuid('canvas_page', '<uuid>'); print \$e ? \$e->id() : '';"`
- Export:
  - `ddev drush dcer canvas_page <id> --folder=../recipes/canvas_dev_humanify/content -y`

4. Normalize exported `canvas_page` content to pass recipe import.

- File:
  - `recipes/canvas_dev_humanify/content/canvas_page/4fca895c-5da4-4fd5-86d1-c42788254bb6.yml`
- Required cleanup:
  - Convert root `parent_uuid: ''` to `parent_uuid: null`
  - Convert root `slot: ''` to `slot: null`
  - Remove empty `label: ''` rows

5. Remove unstable config metadata from `js_component` config entities in
   `recipes/canvas_dev_humanify`.

- Remove `uuid:` lines from all:
  - `recipes/canvas_dev_humanify/config/canvas.js_component*.yml`
- Remove `_core` blocks (including `default_config_hash`) from the same files.

6. Refresh `canvas.asset_library.global` values in
   `recipes/canvas_dev_humanify/recipe.yml`.

- Source of truth:
  - `ddev drush cex --destination=../<tmp_dir> -y`
  - `../<tmp_dir>/canvas.asset_library.global.yml`
- Do not use `ddev drush config:get ...` as the source for large payload updates
  to recipe `setMultiple` values. Its output can be hard to apply reliably for
  large `css`/`js` blocks.
- Update `config.actions.canvas.asset_library.global.setMultiple` in one pass
  using exported values:
  - `property_name: css` -> `value` from exported `css`
  - `property_name: js` -> `value` from exported `js`
- Keep both keys (`css` and `js`) synchronized together to avoid partial/stale
  recipe values.

7. Run formatting fixes from the project root.

- `npm run code:fix`
- This runs Prettier.

## Validation

Validate install flow:

1. `ddev si`
2. `ddev drush st`

If install fails:

1. Always rollback:

- `ddev snapshot restore <snapshot_name>`

2. Troubleshoot and fix the cause.
3. Retry install validation:

- `ddev si`
- `ddev drush st`

## Troubleshooting notes

- `ddev drush` command names here are from this repo's current Drush setup:
  - `config:export` (`cex`)
  - `default-content:export-references` (`dcer`)
- `ddev si` may show non-fatal schema warnings for `ai_agents_test` views.
- If `recipe.yml` asset library values look stale after an update, re-export with
  `cex` and replace both `css` and `js` entries in the same edit from
  `canvas.asset_library.global.yml`.
- If `dcer` fails due exporter/type compatibility errors, stop and escalate to a
  separate backend/PHP task instead of patching module PHP in this workflow.

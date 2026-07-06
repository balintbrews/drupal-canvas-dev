---
name: canvas-dev-humanify-recipe-update
description: Update the `recipes/canvas_dev_humanify` recipe by exporting
`js_component` config, asset library config, managed asset files, and default
content, then normalizing exports and verifying install.
---

# Canvas Dev Humanify recipe update

Use this skill only when updating `recipes/canvas_dev_humanify` after content,
asset library, managed asset file, or `js_component` changes.

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

3. Export default content for every active `canvas_page` entity included in the
   Humanify demo.

- Get UUIDs from active `canvas_page` entities or from
  `recipes/canvas_dev_humanify/content/canvas_page/*.yml`.
- Resolve each entity ID:
  - `ddev drush php:eval "\$e = \Drupal::service('entity.repository')->loadEntityByUuid('canvas_page', '<uuid>'); print \$e ? \$e->id() : '';"`
- Export each page:
  - `ddev drush dcer canvas_page <id> --folder=../recipes/canvas_dev_humanify/content -y`
- If new pages exist in the active site, add their exported files under:
  - `recipes/canvas_dev_humanify/content/canvas_page/`

4. Normalize exported `canvas_page` content to pass recipe import.

- Required cleanup:
  - Convert root `parent_uuid: ''` to `parent_uuid: null`
  - Convert root `slot: ''` to `slot: null`
  - Remove empty `label: ''` rows
  - Ensure each `components.*.inputs` value is structured YAML data, not an
    encoded JSON string.
  - For media-backed image props, prefer default-content reference syntax:
    - `target_uuid: <media_uuid>`
    - Do not use local-only `target_id` values.
- If a page depends on a media entity, add it to `_meta.depends`:
  - `<media_uuid>: media`

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
  - `property_name: assets` -> `value` from exported `assets`
- The `assets` property is the manifest-like list used by code component
  imports, for example:
  - `name: '@/lib/pricing-utils'`
  - `uri: 'public://canvas/assets/pricing-utils-D9e5kp05.js'`
- Keep all three keys (`css`, `js`, and `assets`) synchronized together to avoid
  partial/stale recipe values.

7. Export managed file entities referenced by `canvas.asset_library.global`
   assets.

- List active managed asset files:
  - `ddev drush php:eval "\$ids = \Drupal::entityQuery('file')->accessCheck(FALSE)->condition('uri', 'public://canvas/assets/%', 'LIKE')->execute(); foreach (\Drupal::entityTypeManager()->getStorage('file')->loadMultiple(\$ids) as \$file) { print \$file->id() . ' ' . \$file->uuid() . ' ' . \$file->getFileUri() . PHP_EOL; }"`
- Export a default-content `file/<uuid>.yml` for each managed file under:
  - `recipes/canvas_dev_humanify/content/file/`
- Copy each binary from:
  - `web/sites/default/files/canvas/assets/<filename>`
- To:
  - `recipes/canvas_dev_humanify/content/file/<filename>`
- Ensure each exported file entity preserves:
  - `uri.value: public://canvas/assets/<filename>`
  - `uri.url: /sites/default/files/canvas/assets/<filename>`

8. Export media/file content referenced by refreshed pages.

- If a page component input references media by `target_uuid`, make sure the
  corresponding media default-content file exists under:
  - `recipes/canvas_dev_humanify/content/media/<media_uuid>.yml`
- Make sure that media export depends on its file entity under:
  - `_meta.depends.<file_uuid>: file`
- Make sure the referenced file entity YAML and binary exist under:
  - `recipes/canvas_dev_humanify/content/file/`

9. Run formatting fixes from the project root.

- `npm run code:fix`
- This runs Prettier.
- If broad formatting causes unrelated docs/config churn, revert only those
  unrelated formatter side effects and keep Humanify recipe changes.

10. Clean up temporary export artifacts before finishing.

- Remove temporary config export directories created during this workflow:
  - `rm -rf <tmp_dir>`
  - Example names used in this repo include:
    - `asset_export_tmp`
    - `canvas_export_temp`
    - `canvas_export_new`
    - `config_sync_temp`
    - `humanify_asset_export_tmp`
    - `humanify_config_export_tmp`
- Remove accidental recipe export output under `web/recipes` if present:
  - `rm -rf web/recipes/canvas_dev_humanify`
- Verify cleanup:
  - No temporary directories remain in the repository root.
  - No `content_new` directories remain under `web/recipes`.
  - No `web/recipes/canvas_dev_humanify` directory remains.

## Validation

Validate install flow:

1. `ddev si`
2. `ddev drush st`
3. Verify imported Canvas asset library assets when assets changed:

- `ddev drush php:eval "\$asset = \Drupal::entityTypeManager()->getStorage('asset_library')->load('global'); print json_encode(\$asset->get('assets'), JSON_UNESCAPED_SLASHES) . PHP_EOL;"`

4. Verify imported managed asset file count when assets changed:

- `ddev drush php:eval "\$ids = \Drupal::entityQuery('file')->accessCheck(FALSE)->condition('uri', 'public://canvas/assets/%', 'LIKE')->execute(); print count(\$ids);"`

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
- If install fails with a component version error like:
  - `The requested version <old> is not available. Available versions: <new>`
    this means recipe content and component config are out of sync.
- Recovery workflow for version mismatch:
  1. Restore snapshot first.
  2. Import updated `canvas.js_component.*.yml` config into the current site
     (partial `cim` from a temp directory is fine).
  3. Re-export `canvas_page` default content with `dcer`.
  4. If needed, update `component_version` values in exported content to match
     the version listed as available in the install error.
  5. Re-run install validation (`ddev si`, `ddev drush st`).
- If `recipe.yml` asset library values look stale after an update, re-export
  with `cex` and replace `css`, `js`, and `assets` entries in the same edit from
  `canvas.asset_library.global.yml`.
- If asset imports fail after install, check that every URI listed in
  `canvas.asset_library.global.assets` has both:
  - A default-content file entity YAML under
    `recipes/canvas_dev_humanify/content/file/`
  - A copied binary under `recipes/canvas_dev_humanify/content/file/`
- If page import fails with an image prop error, check that media-backed image
  inputs use `target_uuid: <media_uuid>`, not `target_id` or a resolved image
  object.
- If you see unexpected files under `web/recipes`, treat them as export
  artifacts from a wrong path and clean them up before finalizing.
- If `dcer` fails due exporter/type compatibility errors involving
  `Drupal\canvas\Plugin\DataType\MaybeUrl`, do not patch module PHP in this
  workflow. Export the needed `canvas_page`, `media`, and `file` entities with a
  focused `ddev drush php:eval` script using `Symfony\Component\Yaml\Yaml`, then
  apply the normalization rules above and validate with `ddev si`.

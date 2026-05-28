---
name: canvas-package-version-bump
description:
  Use when bumping versions for Drupal Canvas npm workspace packages or updating
  internal workspace dependency ranges. Ensures all internal consumers are found
  and updated, package-lock.json is synced safely, and npm ci --dry-run is run to
  catch lockfile drift before CI.
---

# Canvas package version bump

Use this skill before changing package versions or internal dependency ranges in
Drupal Canvas npm workspaces.

## Process

1. Identify the package being released or dependency being updated.
2. Find all internal consumers before editing:

   ```bash
   rg -n '"<package-name>"\s*:' --glob package.json --glob '!node_modules/**' .
   ```

3. Update:

   - The package's own `version` field.
   - Every internal consumer dependency range that should accept the new version.
   - Related package versions requested by the task.

4. Sync `package-lock.json` from the repository root:

   ```bash
   npm install --package-lock-only --ignore-scripts
   ```

5. Check that no stale internal dependency ranges remain:

   ```bash
   rg -n '"<package-name>"\s*:\s*"\^<old-version-prefix>' --glob package.json --glob '!node_modules/**' . package-lock.json
   ```

6. Validate lockfile consistency:

   ```bash
   npm ci --dry-run
   ```

7. Review the diff. If `npm install --package-lock-only` introduces unrelated
   lockfile churn, reset `package-lock.json` and make only the minimal lockfile
   metadata edits needed, then rerun `npm ci --dry-run`.

## Notes

- Run npm commands on the host machine from the Canvas repository root.
- Do not rely on updating only the package named in the request. Internal
  workspaces may depend on it and can make `npm ci` fail if left on the old
  range.
- Keep version-only changes separate from unrelated dependency updates.

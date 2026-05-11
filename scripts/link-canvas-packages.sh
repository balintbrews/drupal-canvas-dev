#!/bin/bash

set -euo pipefail

usage() {
  echo "Usage: $0 <target-project-path>"
}

if [ "$#" -ne 1 ]; then
  usage
  exit 1
fi

TARGET_PROJECT="$1"

if [ ! -d "$TARGET_PROJECT" ]; then
  echo "Error: Target project does not exist: $TARGET_PROJECT"
  exit 1
fi

if [ ! -f "$TARGET_PROJECT/package.json" ]; then
  echo "Error: Target project does not contain package.json: $TARGET_PROJECT"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANVAS_REPO="$(cd "$SCRIPT_DIR/../web/modules/contrib/canvas" && pwd)"

PACKAGE_DIRS=(
  "packages/drupal-canvas"
  "packages/eslint-config"
  "packages/vite-plugin"
  "packages/workbench"
  "packages/cli"
)

PACKAGE_NAMES=(
  "drupal-canvas"
  "@drupal-canvas/eslint-config"
  "@drupal-canvas/vite-plugin"
  "@drupal-canvas/workbench"
  "@drupal-canvas/cli"
)

echo "Installing target project dependencies in $TARGET_PROJECT"
npm --prefix "$TARGET_PROJECT" install

echo
echo "Building local Canvas packages from $CANVAS_REPO"
for package_dir in "${PACKAGE_DIRS[@]}"; do
  echo "  npm --prefix $package_dir run build"
  npm --prefix "$CANVAS_REPO/$package_dir" run build
done

echo
echo "Linking packages into $TARGET_PROJECT"
(
  cd "$TARGET_PROJECT"
  npm link "${PACKAGE_DIRS[@]/#/$CANVAS_REPO/}"
)

echo
echo "Linked package targets:"
node - "$TARGET_PROJECT" "${PACKAGE_NAMES[@]}" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');

const [, , targetProject, ...packageNames] = process.argv;

for (const packageName of packageNames) {
  const packagePath = path.join(targetProject, 'node_modules', packageName);
  console.log(`${packageName} -> ${fs.realpathSync(packagePath)}`);
}
NODE

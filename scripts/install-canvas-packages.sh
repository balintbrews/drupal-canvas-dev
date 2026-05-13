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

PACK_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$PACK_DIR"
}
trap cleanup EXIT

PACKAGE_TARBALLS=()

echo
echo "Packing local Canvas packages"
for package_dir in "${PACKAGE_DIRS[@]}"; do
  echo "  npm pack $package_dir"
  pack_source="$CANVAS_REPO/$package_dir"

  if ! node -e "process.exit(require(process.argv[1]).version ? 0 : 1)" "$pack_source/package.json"; then
    pack_source="$PACK_DIR/$package_dir"
    mkdir -p "$(dirname "$pack_source")"
    cp -R "$CANVAS_REPO/$package_dir" "$pack_source"
    npm --prefix "$pack_source" pkg set version="0.0.0" >/dev/null
  fi

  pack_output="$(npm pack "$pack_source" --pack-destination "$PACK_DIR" --ignore-scripts --json)"
  tarball="$(node -e "const pack = JSON.parse(process.argv[1]); console.log(pack[0].filename);" "$pack_output")"
  PACKAGE_TARBALLS+=("$PACK_DIR/$tarball")
done

echo
echo "Installing local package tarballs into $TARGET_PROJECT"
npm --prefix "$TARGET_PROJECT" install "${PACKAGE_TARBALLS[@]}"

echo
echo "Installed package targets:"
node - "$TARGET_PROJECT" "${PACKAGE_NAMES[@]}" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');

const [, , targetProject, ...packageNames] = process.argv;

for (const packageName of packageNames) {
  const packagePath = path.join(targetProject, 'node_modules', packageName);
  console.log(`${packageName} -> ${fs.realpathSync(packagePath)}`);
}
NODE

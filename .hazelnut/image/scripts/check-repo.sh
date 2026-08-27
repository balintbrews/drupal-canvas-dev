#!/bin/bash

set -euo pipefail

WORKSPACE_ROOT="${HAZELNUT_WORKSPACE_DIR:-$HOME/workspace}"
ENV_ROOT="${CANVAS_ENV_ROOT:-$WORKSPACE_ROOT/drupal}"
TARGET_DIR="$ENV_ROOT/web/modules/contrib/canvas"

if [[ ! -d "$TARGET_DIR" || -z "$(find "$TARGET_DIR/" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  echo >&2
  echo "Error: Drupal Canvas is not available at $TARGET_DIR." >&2
  echo "Make the Canvas checkout available in the session workspace before running Composer." >&2
  echo >&2
  exit 1
fi

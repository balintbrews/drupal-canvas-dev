#!/bin/bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: open-in-chrome.sh <ddev-project-root>"
  exit 1
fi

DDEV_ROOT="$(cd "$1" && pwd -P)"
DDEV_URL="$(cd "$DDEV_ROOT" && ddev describe -j | jq -er '.raw.primary_url')"
printf '%s\n' "$DDEV_URL"

LOGIN_URL="$(cd "$DDEV_ROOT" && ddev drush --uri="$DDEV_URL" user:login --name=admin --no-browser)"
LOGIN_PATH="${LOGIN_URL#"$DDEV_URL"}?destination=canvas"
ENCODED_LOGIN_PATH="$(jq -rn --arg value "$LOGIN_PATH" '$value | @uri')"

# The reset route accepts both session states before redirecting to the anonymous-only login route.
OPEN_URL="${LOGIN_URL%/login}?destination=$ENCODED_LOGIN_PATH"
/usr/bin/open -a "Google Chrome" "$OPEN_URL"

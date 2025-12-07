#!/bin/bash

TARGET_DIR="web/themes/contrib/mercury"

if [ ! -d "$TARGET_DIR" ] || [ -z "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
    echo
    echo "Error: Mercury theme not found."
    echo "The $TARGET_DIR directory does not exist or is empty."
    echo
    echo "To fix this, run:"
    echo "  ddev clone-repo-mercury"
    echo
    echo "This will clone the Mercury theme repository to the correct location."
    echo "Then run \`composer install\` again."
    echo
    exit 1
fi

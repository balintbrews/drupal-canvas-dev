#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  destroy-worktree.sh [<branch>] [options]
  destroy-worktree.sh --canvas-worktree=<path> [options]

Tear down a Canvas worktree setup created by create-worktree.sh. This
deletes the DDEV project including its containers and database, then removes
the environment wrapper, the Mercury worktree, and the Canvas worktree.

The Canvas branch is kept by default so committed work stays available.

When run without a branch and fzf is installed, pick the worktree to destroy
from a list.

Examples:
  # Pick the worktree to destroy interactively (requires fzf).
  destroy-worktree.sh

  # Tear down the setup for a branch, keeping the branch itself.
  destroy-worktree.sh 880922-my-branch

  # Tear down everything, including the branch.
  destroy-worktree.sh 880922-my-branch --delete-branch

Options:
  --canvas-worktree=<path>  Explicit Canvas worktree path. Replaces the path
                            looked up from the branch name.
  --delete-branch           Also delete the Canvas branch. Unpushed commits on
                            the branch are lost.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ENV_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_CANVAS="$SOURCE_ENV_PATH/web/modules/contrib/canvas"

CANVAS_BRANCH=""
CANVAS_WORKTREE=""
DELETE_BRANCH=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --canvas-worktree=*)
      CANVAS_WORKTREE="${1#*=}"
      ;;
    --delete-branch)
      DELETE_BRANCH=true
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      echo "Error: Unknown option: $1"
      echo "Run with --help for usage."
      exit 1
      ;;
    *)
      if [ -n "$CANVAS_BRANCH" ]; then
        echo "Error: Unexpected argument: $1 (branch is already set to $CANVAS_BRANCH)."
        exit 1
      fi
      CANVAS_BRANCH="$1"
      ;;
  esac
  shift
done

if ! git -C "$SOURCE_CANVAS" rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "Error: Source Canvas repository is missing: $SOURCE_CANVAS"
  exit 1
fi

# Lists destroyable Canvas worktrees as "branch<TAB>path" lines, excluding the
# source checkout.
list_canvas_worktrees() {
  git -C "$SOURCE_CANVAS" worktree list --porcelain | awk -v skip="$SOURCE_CANVAS" '
    /^worktree / { worktree = substr($0, 10) }
    /^branch / && worktree != skip {
      branch = substr($0, 8)
      sub("refs/heads/", "", branch)
      printf "%s\t%s\n", branch, worktree
    }
    /^detached$/ && worktree != skip { printf "(detached)\t%s\n", worktree }
  '
}

if [ -z "$CANVAS_BRANCH" ] && [ -z "$CANVAS_WORKTREE" ]; then
  # Interactive selection needs fzf and a terminal; fzf hangs without one.
  if ! command -v fzf >/dev/null 2>&1 || [ ! -t 0 ] || [ ! -t 1 ]; then
    echo "Error: Pass a branch name, or --canvas-worktree for an existing worktree."
    echo "Run interactively with fzf installed to pick a worktree instead."
    echo "Run with --help for usage."
    exit 1
  fi

  git -C "$SOURCE_CANVAS" worktree prune
  CANDIDATES="$(list_canvas_worktrees)"
  if [ -z "$CANDIDATES" ]; then
    echo "No Canvas worktrees to destroy."
    exit 0
  fi

  SELECTION="$(printf "%s\n" "$CANDIDATES" \
    | fzf --prompt="Destroy Canvas worktree > " \
        --header="Select the Canvas worktree to destroy (Esc to cancel)." \
        --delimiter="\t" \
        --height=40% \
        --reverse)" || true
  if [ -z "$SELECTION" ]; then
    echo "No worktree selected."
    exit 0
  fi

  CANVAS_WORKTREE="${SELECTION#*$'\t'}"
fi

# Prints the existing worktree path for a branch, if any.
find_worktree_for_branch() {
  git -C "$SOURCE_CANVAS" worktree list --porcelain | awk -v ref="refs/heads/$1" '
    /^worktree / { worktree = substr($0, 10) }
    $1 == "branch" && $2 == ref { print worktree; exit }
  '
}

if [ -z "$CANVAS_WORKTREE" ]; then
  git -C "$SOURCE_CANVAS" worktree prune
  CANVAS_WORKTREE="$(find_worktree_for_branch "$CANVAS_BRANCH")"
  if [ -z "$CANVAS_WORKTREE" ]; then
    echo "No worktree found for branch $CANVAS_BRANCH."
    if [ "$DELETE_BRANCH" = true ] \
      && git -C "$SOURCE_CANVAS" show-ref --verify --quiet "refs/heads/$CANVAS_BRANCH"; then
      git -C "$SOURCE_CANVAS" branch -D "$CANVAS_BRANCH"
      echo "Deleted Canvas branch $CANVAS_BRANCH."
    fi
    exit 0
  fi
fi

if [[ "$CANVAS_WORKTREE" != /* ]]; then
  CANVAS_WORKTREE="$(pwd)/$CANVAS_WORKTREE"
fi

if [ "$CANVAS_WORKTREE" = "$SOURCE_CANVAS" ]; then
  echo "Error: Refusing to destroy the source Canvas checkout: $SOURCE_CANVAS"
  exit 1
fi

if [ ! -d "$CANVAS_WORKTREE" ]; then
  echo "Error: Canvas worktree does not exist: $CANVAS_WORKTREE"
  exit 1
fi

CANVAS_WORKTREE="$(cd "$CANVAS_WORKTREE" && pwd)"

# The wrap script records the environment wrapper as a .ddev-env symlink in
# the Canvas worktree. Prefer it, and fall back to the sibling convention.
ENV_WORKTREE=""
if [ -L "$CANVAS_WORKTREE/.ddev-env" ]; then
  ENV_WORKTREE="$(readlink "$CANVAS_WORKTREE/.ddev-env")"
fi
if [ -z "$ENV_WORKTREE" ] || [ ! -d "$ENV_WORKTREE" ]; then
  ENV_WORKTREE="$(dirname "$CANVAS_WORKTREE")/canvas-env"
fi

if [ -z "$CANVAS_BRANCH" ]; then
  CANVAS_BRANCH="$(git -C "$CANVAS_WORKTREE" branch --show-current 2>/dev/null || true)"
fi

if [ -d "$ENV_WORKTREE" ]; then
  if [ -d "$ENV_WORKTREE/.ddev" ] && command -v ddev >/dev/null 2>&1; then
    echo "Deleting DDEV project, containers, and database."
    (cd "$ENV_WORKTREE" && ddev delete --omit-snapshot --yes) \
      || echo "Warning: ddev delete failed; continuing with worktree removal."
  fi

  TARGET_MERCURY="$ENV_WORKTREE/web/themes/contrib/mercury"
  if [ -d "$TARGET_MERCURY" ]; then
    MERCURY_GIT_DIR="$(git -C "$TARGET_MERCURY" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [ -n "$MERCURY_GIT_DIR" ]; then
      echo "Removing Mercury worktree."
      git -C "$(dirname "$MERCURY_GIT_DIR")" worktree remove --force "$TARGET_MERCURY" \
        || echo "Warning: could not remove the Mercury worktree; continuing."
    fi
  fi

  echo "Removing environment worktree."
  git -C "$SOURCE_ENV_PATH" worktree remove --force "$ENV_WORKTREE" \
    || { echo "Error: Could not remove the environment worktree: $ENV_WORKTREE"; exit 1; }
else
  echo "No environment wrapper found next to the Canvas worktree; skipping DDEV cleanup."
fi

echo "Removing Canvas worktree."
git -C "$SOURCE_CANVAS" worktree remove --force "$CANVAS_WORKTREE"

# Remove the shared parent directory when nothing else is left in it.
rmdir "$(dirname "$CANVAS_WORKTREE")" 2>/dev/null || true

if [ -n "$CANVAS_BRANCH" ]; then
  if [ "$DELETE_BRANCH" = true ]; then
    git -C "$SOURCE_CANVAS" branch -D "$CANVAS_BRANCH"
    echo "Deleted Canvas branch $CANVAS_BRANCH."
  else
    echo "Kept Canvas branch $CANVAS_BRANCH. Delete it with:"
    echo "  git -C \"$SOURCE_CANVAS\" branch -D \"$CANVAS_BRANCH\""
  fi
fi

echo
echo "Destroyed Canvas worktree setup:"
echo "  Canvas: $CANVAS_WORKTREE"
echo "  Environment: $ENV_WORKTREE"

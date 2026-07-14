#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  create-worktree.sh <branch> [options]
  create-worktree.sh --canvas-worktree=<path> [options]

Work on a Canvas branch in its own worktree with one command. The script
creates the Canvas worktree when needed, wraps it with a sibling DDEV
environment worktree, then starts DDEV, installs Composer dependencies, and
installs Drupal.

Rerunning with the same branch reuses the existing worktree and environment,
so the same command works for creating, resuming, and repairing a setup. Note
that the Drupal site is reinstalled on every run.

Examples:
  # Start work on a new branch from origin/1.x. The worktree is created at
  # ../canvas-worktrees/880922-my-branch/canvas.
  create-worktree.sh 880922-my-branch

  # Also build the UI as part of the site install.
  create-worktree.sh 880922-my-branch --ui

  # Branch off a different base ref.
  create-worktree.sh 880922-my-branch --base-ref=origin/880923-other-branch

  # Create and wrap the worktree without running any DDEV commands.
  create-worktree.sh 880922-my-branch --skip-ddev

  # Wrap a Canvas worktree that another tool already created.
  create-worktree.sh --canvas-worktree=/path/to/canvas

Options:
  --base-ref=<ref>          Ref a new branch starts from. Ignored when the
                            branch already exists. Defaults to origin/1.x.
  --worktrees-root=<path>   Directory for derived worktrees. Defaults to
                            <repo-parent>/canvas-worktrees.
  --no-fetch                Skip git fetch before creating the worktree.
  --canvas-worktree=<path>  Explicit Canvas worktree path. Replaces the path
                            derived from the branch name.
  --ui                      Run ddev site-install with --ui.
  --skip-ddev               Create and wrap the worktree, but do not run any
                            DDEV commands.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ENV_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_CANVAS="$SOURCE_ENV_PATH/web/modules/contrib/canvas"

CANVAS_BRANCH=""
CANVAS_WORKTREE=""
BASE_REF="origin/1.x"
WORKTREES_ROOT=""
FETCH_CANVAS=true
RUN_DDEV_SETUP=true
INSTALL_UI=false
CREATED_CANVAS=false
CREATED_CANVAS_BRANCH=""
WRAP_COMPLETED=false

cleanup_on_error() {
  status=$?
  if [ "$status" -eq 0 ] || [ "$CREATED_CANVAS" != true ] || [ "$WRAP_COMPLETED" = true ]; then
    return
  fi

  echo
  echo "Canvas worktree setup failed. Cleaning up created Canvas worktree."
  git -C "$SOURCE_CANVAS" worktree remove --force "$CANVAS_WORKTREE" >/dev/null 2>&1 || true
  if [ -n "$CREATED_CANVAS_BRANCH" ]; then
    git -C "$SOURCE_CANVAS" branch -D "$CREATED_CANVAS_BRANCH" >/dev/null 2>&1 || true
  fi
}

trap cleanup_on_error EXIT

while [ "$#" -gt 0 ]; do
  case "$1" in
    --base-ref=*)
      BASE_REF="${1#*=}"
      ;;
    --worktrees-root=*)
      WORKTREES_ROOT="${1#*=}"
      ;;
    --no-fetch)
      FETCH_CANVAS=false
      ;;
    --canvas-worktree=*)
      CANVAS_WORKTREE="${1#*=}"
      ;;
    --ui)
      INSTALL_UI=true
      ;;
    --skip-ddev)
      RUN_DDEV_SETUP=false
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

if [ -z "$CANVAS_BRANCH" ] && [ -z "$CANVAS_WORKTREE" ]; then
  echo "Error: Pass a branch name, or --canvas-worktree for an existing worktree."
  echo "Run with --help for usage."
  exit 1
fi

if ! git -C "$SOURCE_CANVAS" rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "Error: Source Canvas repository is missing: $SOURCE_CANVAS"
  exit 1
fi

# Prints the existing worktree path for a branch, if any.
find_worktree_for_branch() {
  git -C "$SOURCE_CANVAS" worktree list --porcelain | awk -v ref="refs/heads/$1" '
    /^worktree / { worktree = substr($0, 10) }
    $1 == "branch" && $2 == ref { print worktree; exit }
  '
}

if [ -z "$CANVAS_WORKTREE" ]; then
  # Drop stale worktree registrations so deleted checkouts are not reused.
  git -C "$SOURCE_CANVAS" worktree prune
  EXISTING_WORKTREE="$(find_worktree_for_branch "$CANVAS_BRANCH")"
  if [ "$EXISTING_WORKTREE" = "$SOURCE_CANVAS" ]; then
    echo "Error: Branch $CANVAS_BRANCH is checked out in the source environment: $SOURCE_CANVAS"
    echo "Use a different branch, or switch the source checkout to another branch first."
    exit 1
  fi

  if [ -n "$EXISTING_WORKTREE" ]; then
    echo "Reusing existing worktree for branch $CANVAS_BRANCH: $EXISTING_WORKTREE"
    CANVAS_WORKTREE="$EXISTING_WORKTREE"
  else
    WORKTREES_ROOT="${WORKTREES_ROOT:-$(dirname "$SOURCE_ENV_PATH")/canvas-worktrees}"
    # Branch names can contain slashes; flatten them for the directory name.
    BRANCH_SLUG="$(printf "%s" "$CANVAS_BRANCH" | tr "/" "-")"
    CANVAS_WORKTREE="$WORKTREES_ROOT/$BRANCH_SLUG/canvas"
  fi
fi

if [[ "$CANVAS_WORKTREE" != /* ]]; then
  CANVAS_WORKTREE="$(pwd)/$CANVAS_WORKTREE"
fi

if [ ! -d "$CANVAS_WORKTREE" ]; then
  if [ -z "$CANVAS_BRANCH" ]; then
    echo "Error: Canvas worktree does not exist: $CANVAS_WORKTREE"
    echo "Pass a branch name so the worktree can be created."
    exit 1
  fi

  mkdir -p "$(dirname "$CANVAS_WORKTREE")"

  if [ "$FETCH_CANVAS" = true ]; then
    git -C "$SOURCE_CANVAS" fetch origin
  fi

  echo "Creating Canvas worktree at $CANVAS_WORKTREE."
  if git -C "$SOURCE_CANVAS" show-ref --verify --quiet "refs/heads/$CANVAS_BRANCH"; then
    echo "Checking out existing Canvas branch $CANVAS_BRANCH."
    git -C "$SOURCE_CANVAS" worktree add "$CANVAS_WORKTREE" "$CANVAS_BRANCH"
  else
    echo "Creating Canvas branch $CANVAS_BRANCH from $BASE_REF."
    git -C "$SOURCE_CANVAS" worktree add -b "$CANVAS_BRANCH" "$CANVAS_WORKTREE" "$BASE_REF"
    CREATED_CANVAS_BRANCH="$CANVAS_BRANCH"
  fi
  CREATED_CANVAS=true
fi

CANVAS_WORKTREE="$(cd "$CANVAS_WORKTREE" && pwd)"
ENV_WORKTREE="$(dirname "$CANVAS_WORKTREE")/canvas-env"

WRAP_SCRIPT="$SOURCE_ENV_PATH/scripts/wrap-canvas-worktree.sh"
if [ ! -x "$WRAP_SCRIPT" ]; then
  echo "Error: Wrapper script is not executable: $WRAP_SCRIPT"
  exit 1
fi

"$WRAP_SCRIPT" \
  "--source-env=$SOURCE_ENV_PATH" \
  "--canvas-worktree=$CANVAS_WORKTREE" \
  "--env-worktree=$ENV_WORKTREE"
WRAP_COMPLETED=true

PROJECT_NAME="$(sed -n "s/^name: //p" "$ENV_WORKTREE/.ddev/config.local.yaml" | head -1)"

print_summary() {
  echo
  echo "Canvas worktree ready:"
  echo "  Canvas: $CANVAS_WORKTREE"
  echo "  Environment: $ENV_WORKTREE"
  echo "  DDEV project: $PROJECT_NAME"
  echo "  Site: https://$PROJECT_NAME.ddev.site"
}

if [ "$RUN_DDEV_SETUP" != true ]; then
  echo
  echo "Skipped DDEV setup. Run from the environment wrapper when needed:"
  echo "  cd \"$ENV_WORKTREE\""
  echo "  ddev start"
  echo "  ddev composer install"
  echo "  ddev site-install"
  print_summary
  exit 0
fi

echo
echo "Running DDEV setup from $ENV_WORKTREE."
(
  cd "$ENV_WORKTREE"

  ddev start
  ddev composer install

  if [ "$INSTALL_UI" = true ]; then
    ddev site-install --ui
  else
    ddev site-install
  fi
)

print_summary

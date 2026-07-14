#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  create-worktree.sh <branch> [options]
  create-worktree.sh <merge-request-url> [options]
  create-worktree.sh --canvas-worktree=<path> [options]

Work on a Canvas branch in its own worktree with one command. The script
creates the Canvas worktree when needed, wraps it with a sibling DDEV
environment worktree, then starts DDEV, installs Composer dependencies, and
installs Drupal.

A Drupal.org merge request URL resolves to the issue-fork branch: the fork is
added as a Git remote named canvas-<issue-id> when needed, and the branch is
created tracking it. When the branch already exists locally, it is reused as
is. --base-ref does not apply to merge request URLs.

Rerunning with the same branch reuses the existing worktree and environment,
so the same command works for creating, resuming, and repairing a setup. Note
that the Drupal site is reinstalled on every run.

Existing branches configured to push to a remote URL instead of a named
remote are repaired when a remote with that URL exists, so that
git push --force-with-lease keeps working.

Examples:
  # Start work on a new branch from origin/1.x. The worktree is created at
  # ../canvas-worktrees/880922-my-branch/canvas.
  create-worktree.sh 880922-my-branch

  # Work on a Drupal.org merge request in its issue-fork branch.
  create-worktree.sh https://git.drupalcode.org/project/canvas/-/merge_requests/1353

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

MR_URL_PATTERN='^https://git\.drupalcode\.org/project/canvas/-/merge_requests/([0-9]+)/?$'
API_BASE="https://git.drupalcode.org/api/v4"

CANVAS_BRANCH=""
CANVAS_WORKTREE=""
MR_ID=""
MR_REMOTE_NAME=""
MR_REMOTE_URL=""
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
      if [ -n "$CANVAS_BRANCH" ] || [ -n "$MR_ID" ]; then
        echo "Error: Unexpected argument: $1 (a branch or merge request is already set)."
        exit 1
      fi
      if [[ "$1" =~ $MR_URL_PATTERN ]]; then
        MR_ID="${BASH_REMATCH[1]}"
      elif [[ "$1" == http://* || "$1" == https://* ]]; then
        echo "Error: Unsupported URL: $1"
        echo "Expected https://git.drupalcode.org/project/canvas/-/merge_requests/<id>"
        exit 1
      else
        CANVAS_BRANCH="$1"
      fi
      ;;
  esac
  shift
done

if [ -z "$CANVAS_BRANCH" ] && [ -z "$CANVAS_WORKTREE" ] && [ -z "$MR_ID" ]; then
  echo "Error: Pass a branch name, a merge request URL, or --canvas-worktree."
  echo "Run with --help for usage."
  exit 1
fi

if ! git -C "$SOURCE_CANVAS" rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "Error: Source Canvas repository is missing: $SOURCE_CANVAS"
  exit 1
fi

if [ -n "$MR_ID" ]; then
  for tool in curl jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "Error: Resolving a merge request URL requires $tool."
      exit 1
    fi
  done

  MR_JSON="$(curl -sf "$API_BASE/projects/project%2Fcanvas/merge_requests/$MR_ID")" || {
    echo "Error: Could not load merge request $MR_ID from git.drupalcode.org."
    exit 1
  }
  CANVAS_BRANCH="$(printf "%s" "$MR_JSON" | jq -r ".source_branch")"
  SOURCE_PROJECT_ID="$(printf "%s" "$MR_JSON" | jq -r ".source_project_id")"
  if [ -z "$CANVAS_BRANCH" ] || [ "$CANVAS_BRANCH" = "null" ] || [ "$SOURCE_PROJECT_ID" = "null" ]; then
    echo "Error: Could not read the source branch of merge request $MR_ID."
    exit 1
  fi

  PROJECT_JSON="$(curl -sf "$API_BASE/projects/$SOURCE_PROJECT_ID")" || {
    echo "Error: Could not load the source project of merge request $MR_ID."
    exit 1
  }
  MR_SOURCE_PATH="$(printf "%s" "$PROJECT_JSON" | jq -r ".path_with_namespace")"
  if [ "$MR_SOURCE_PATH" = "project/canvas" ]; then
    # The merge request comes from a branch in the project itself.
    MR_REMOTE_NAME="origin"
  else
    MR_REMOTE_NAME="$(printf "%s" "$PROJECT_JSON" | jq -r ".path")"
    MR_REMOTE_URL="$(printf "%s" "$PROJECT_JSON" | jq -r ".ssh_url_to_repo")"
  fi
  echo "Merge request $MR_ID uses branch $CANVAS_BRANCH from $MR_SOURCE_PATH."

  if [ "$MR_REMOTE_NAME" != "origin" ] \
    && ! git -C "$SOURCE_CANVAS" remote get-url "$MR_REMOTE_NAME" >/dev/null 2>&1; then
    echo "Adding Git remote $MR_REMOTE_NAME for the issue fork."
    git -C "$SOURCE_CANVAS" remote add "$MR_REMOTE_NAME" "$MR_REMOTE_URL"
  fi

  if [ "$FETCH_CANVAS" = true ]; then
    git -C "$SOURCE_CANVAS" fetch "$MR_REMOTE_NAME"
  fi
fi

# Repairs branch configuration that points at a remote URL instead of a named
# remote, which breaks --force-with-lease pushes. Covers both the remote and
# pushRemote keys, and only applies when a configured remote with that URL
# exists.
repair_branch_remote() {
  local branch key configured remote_name
  branch="$1"
  for key in remote pushRemote; do
    configured="$(git -C "$SOURCE_CANVAS" config "branch.$branch.$key" 2>/dev/null || true)"
    if [ -z "$configured" ] || git -C "$SOURCE_CANVAS" remote get-url "$configured" >/dev/null 2>&1; then
      continue
    fi
    remote_name="$(git -C "$SOURCE_CANVAS" remote -v \
      | awk -v url="$configured" '$2 == url && $3 == "(fetch)" { print $1; exit }')"
    if [ -n "$remote_name" ]; then
      echo "Repairing branch.$branch.$key to use remote $remote_name instead of its URL."
      git -C "$SOURCE_CANVAS" config "branch.$branch.$key" "$remote_name"
    fi
  done
}

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

  # In merge request mode, the fork remote was already fetched above.
  if [ -z "$MR_ID" ] && [ "$FETCH_CANVAS" = true ]; then
    git -C "$SOURCE_CANVAS" fetch origin
  fi

  echo "Creating Canvas worktree at $CANVAS_WORKTREE."
  if git -C "$SOURCE_CANVAS" show-ref --verify --quiet "refs/heads/$CANVAS_BRANCH"; then
    echo "Checking out existing Canvas branch $CANVAS_BRANCH."
    git -C "$SOURCE_CANVAS" worktree add "$CANVAS_WORKTREE" "$CANVAS_BRANCH"
  elif [ -n "$MR_ID" ]; then
    echo "Creating Canvas branch $CANVAS_BRANCH tracking $MR_REMOTE_NAME/$CANVAS_BRANCH."
    git -C "$SOURCE_CANVAS" worktree add --track -b "$CANVAS_BRANCH" \
      "$CANVAS_WORKTREE" "$MR_REMOTE_NAME/$CANVAS_BRANCH"
    CREATED_CANVAS_BRANCH="$CANVAS_BRANCH"
  else
    echo "Creating Canvas branch $CANVAS_BRANCH from $BASE_REF."
    git -C "$SOURCE_CANVAS" worktree add -b "$CANVAS_BRANCH" "$CANVAS_WORKTREE" "$BASE_REF"
    CREATED_CANVAS_BRANCH="$CANVAS_BRANCH"
  fi
  CREATED_CANVAS=true
fi

if [ -n "$CANVAS_BRANCH" ] \
  && git -C "$SOURCE_CANVAS" show-ref --verify --quiet "refs/heads/$CANVAS_BRANCH"; then
  repair_branch_remote "$CANVAS_BRANCH"
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

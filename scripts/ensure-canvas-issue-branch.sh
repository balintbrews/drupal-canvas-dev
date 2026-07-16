#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ensure-canvas-issue-branch.sh <merge-request-or-work-item-url>

Fetch only the source branch for a Canvas merge request or work item, then
create a local branch that tracks the issue-fork branch without checking it
out. The branch name is printed to stdout when setup succeeds.

Examples:
  ensure-canvas-issue-branch.sh \
    https://git.drupalcode.org/project/canvas/-/merge_requests/1378

  ensure-canvas-issue-branch.sh \
    https://git.drupalcode.org/project/canvas/-/work_items/3591834
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

log() {
  echo "$*" >&2
}

api_get() {
  local path
  path="$1"
  glab api --hostname "$GITLAB_HOST" "$path" \
    || die "Could not load $path from $GITLAB_HOST."
}

encode_uri_component() {
  jq -rn --arg value "$1" '$value | @uri'
}

normalize_remote_url() {
  printf '%s\n' "$1" | sed -E \
    -e 's#^git@[^:]+:##' \
    -e 's#^ssh://git@[^/]+/##' \
    -e 's#^https?://[^/]+/##' \
    -e 's#\.git/?$##' \
    -e 's#/$##'
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ENV_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_CANVAS="${CANVAS_REPO:-$SOURCE_ENV_PATH/web/modules/contrib/canvas}"
GITLAB_HOST="git.drupalcode.org"
URL_PATTERN='^https://git\.drupalcode\.org/project/(canvas)/-/(merge_requests|work_items)/([0-9]+)/?$'

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 1
fi

case "$1" in
  --help|-h)
    usage
    exit 0
    ;;
esac

for tool in git glab jq sed; do
  command -v "$tool" >/dev/null 2>&1 || die "Required command is missing: $tool"
done

glab auth status --hostname "$GITLAB_HOST" >/dev/null 2>&1 \
  || die "Authenticate first with: glab auth login --hostname $GITLAB_HOST"

git -C "$SOURCE_CANVAS" rev-parse --show-toplevel >/dev/null 2>&1 \
  || die "Canvas repository is missing: $SOURCE_CANVAS"

INPUT_URL="${1%%[?#]*}"
if [[ ! "$INPUT_URL" =~ $URL_PATTERN ]]; then
  die "Expected a git.drupalcode.org project merge request or work item URL."
fi

PROJECT_NAME="${BASH_REMATCH[1]}"
RESOURCE_TYPE="${BASH_REMATCH[2]}"
RESOURCE_IID="${BASH_REMATCH[3]}"
PROJECT_PATH="project/$PROJECT_NAME"
PROJECT_ID="$(encode_uri_component "$PROJECT_PATH")"
SOURCE_PROJECT_ID=""
BRANCH_NAME=""

if [ "$RESOURCE_TYPE" = "merge_requests" ]; then
  MR_JSON="$(api_get "projects/$PROJECT_ID/merge_requests/$RESOURCE_IID")"
  SOURCE_PROJECT_ID="$(printf '%s' "$MR_JSON" | jq -er '.source_project_id')" \
    || die "Merge request $RESOURCE_IID does not have a source project."
  BRANCH_NAME="$(printf '%s' "$MR_JSON" | jq -er '.source_branch | select(length > 0)')" \
    || die "Merge request $RESOURCE_IID does not have a source branch."
else
  ISSUE_JSON="$(api_get "projects/$PROJECT_ID/issues/$RESOURCE_IID")"
  ISSUE_IID="$(printf '%s' "$ISSUE_JSON" | jq -er '.iid')" \
    || die "Work item $RESOURCE_IID was not found."
  if [ "$ISSUE_IID" != "$RESOURCE_IID" ]; then
    die "Work item URL resolved to unexpected ID $ISSUE_IID."
  fi

  ISSUE_PROJECT_PATH="issue/$PROJECT_NAME-$RESOURCE_IID"
  ISSUE_PROJECT_ID="$(encode_uri_component "$ISSUE_PROJECT_PATH")"
  SOURCE_PROJECT_JSON="$(api_get "projects/$ISSUE_PROJECT_ID")" \
    || die "Issue fork $ISSUE_PROJECT_PATH was not found."
  SOURCE_PROJECT_ID="$(printf '%s' "$SOURCE_PROJECT_JSON" | jq -er '.id')" \
    || die "Issue fork $ISSUE_PROJECT_PATH does not have a project ID."

  RELATED_MRS="$(api_get "projects/$PROJECT_ID/issues/$RESOURCE_IID/related_merge_requests")"
  MATCHING_BRANCHES="$(printf '%s' "$RELATED_MRS" | jq -c \
    --argjson source_project_id "$SOURCE_PROJECT_ID" \
    '[.[] | select(.source_project_id == $source_project_id) | .source_branch]
      | unique')"

  if [ "$(printf '%s' "$MATCHING_BRANCHES" | jq 'length')" -eq 0 ]; then
    FORK_BRANCHES="$(api_get "projects/$SOURCE_PROJECT_ID/repository/branches?per_page=100")"
    MATCHING_BRANCHES="$(printf '%s' "$FORK_BRANCHES" | jq -c \
      --arg prefix "$RESOURCE_IID-" \
      '[.[].name | select(startswith($prefix))] | unique')"
  fi

  BRANCH_COUNT="$(printf '%s' "$MATCHING_BRANCHES" | jq 'length')"
  if [ "$BRANCH_COUNT" -eq 0 ]; then
    die "No branch for work item $RESOURCE_IID was found in $ISSUE_PROJECT_PATH."
  fi
  if [ "$BRANCH_COUNT" -gt 1 ]; then
    log "Branches found for work item $RESOURCE_IID:"
    printf '%s' "$MATCHING_BRANCHES" | jq -r '.[] | "  \(.)"' >&2
    die "More than one branch matches; use a merge request URL to select one."
  fi
  BRANCH_NAME="$(printf '%s' "$MATCHING_BRANCHES" | jq -r '.[0]')"
fi

SOURCE_PROJECT_JSON="$(api_get "projects/$SOURCE_PROJECT_ID")"
SOURCE_PROJECT_PATH="$(printf '%s' "$SOURCE_PROJECT_JSON" | jq -er \
  '.path_with_namespace | select(length > 0)')" \
  || die "Source project $SOURCE_PROJECT_ID does not have a path."
REMOTE_NAME="$(printf '%s' "$SOURCE_PROJECT_JSON" | jq -er '.path | select(length > 0)')" \
  || die "Source project $SOURCE_PROJECT_ID does not have a remote name."
REMOTE_URL="$(printf '%s' "$SOURCE_PROJECT_JSON" | jq -er '.ssh_url_to_repo | select(length > 0)')" \
  || die "Source project $SOURCE_PROJECT_ID does not have an SSH URL."

if [ "$SOURCE_PROJECT_PATH" = "$PROJECT_PATH" ]; then
  REMOTE_NAME="origin"
fi

if EXISTING_REMOTE_URL="$(git -C "$SOURCE_CANVAS" remote get-url "$REMOTE_NAME" 2>/dev/null)"; then
  EXPECTED_PROJECT="$(normalize_remote_url "$REMOTE_URL")"
  EXISTING_PROJECT="$(normalize_remote_url "$EXISTING_REMOTE_URL")"
  if [ "$EXISTING_PROJECT" != "$EXPECTED_PROJECT" ]; then
    die "Remote $REMOTE_NAME already points to $EXISTING_REMOTE_URL, not $REMOTE_URL."
  fi
  log "Using existing remote $REMOTE_NAME."
else
  log "Adding remote $REMOTE_NAME: $REMOTE_URL"
  git -C "$SOURCE_CANVAS" remote add "$REMOTE_NAME" "$REMOTE_URL"
fi

REMOTE_BRANCH="$REMOTE_NAME/$BRANCH_NAME"
log "Fetching $BRANCH_NAME from $REMOTE_NAME."
git -C "$SOURCE_CANVAS" fetch --no-tags "$REMOTE_NAME" \
  "+refs/heads/$BRANCH_NAME:refs/remotes/$REMOTE_BRANCH"

if ! git -C "$SOURCE_CANVAS" show-ref --verify --quiet \
  "refs/remotes/$REMOTE_BRANCH"; then
  die "Remote branch $REMOTE_BRANCH was not found after fetching."
fi

if git -C "$SOURCE_CANVAS" show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  CURRENT_UPSTREAM="$(git -C "$SOURCE_CANVAS" for-each-ref \
    --format='%(upstream:short)' "refs/heads/$BRANCH_NAME")"
  if [ "$CURRENT_UPSTREAM" != "$REMOTE_BRANCH" ]; then
    log "Setting $BRANCH_NAME to track $REMOTE_BRANCH."
    git -C "$SOURCE_CANVAS" branch --set-upstream-to="$REMOTE_BRANCH" \
      "$BRANCH_NAME" >&2
  else
    log "Local branch $BRANCH_NAME already tracks $REMOTE_BRANCH."
  fi
else
  log "Creating local branch $BRANCH_NAME tracking $REMOTE_BRANCH."
  git -C "$SOURCE_CANVAS" branch --track "$BRANCH_NAME" "$REMOTE_BRANCH" >&2
fi

printf '%s\n' "$BRANCH_NAME"

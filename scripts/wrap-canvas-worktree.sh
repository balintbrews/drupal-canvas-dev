#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: wrap-canvas-worktree.sh --source-env=<path> --canvas-worktree=<path> [options]

Options:
  --env-worktree=<path>      Environment worktree path.
                             Defaults to <canvas-worktree-parent>/canvas-env.
  --env-ref=<ref>            Environment ref to check out.
                             Defaults to the current source environment HEAD.
  --project-name=<name>      DDEV project name written to config.local.yaml.
                             Defaults to canvas-env-<canvas-worktree-parent>.

This wraps an existing Canvas Git worktree with a DDEV environment worktree.
It is intended for setups where an external tool owns the Canvas worktree.
EOF
}

SOURCE_ENV=""
CANVAS_WORKTREE=""
ENV_WORKTREE=""
ENV_REF="HEAD"
PROJECT_NAME=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source-env=*)
      SOURCE_ENV="${1#*=}"
      ;;
    --canvas-worktree=*)
      CANVAS_WORKTREE="${1#*=}"
      ;;
    --env-worktree=*)
      ENV_WORKTREE="${1#*=}"
      ;;
    --env-ref=*)
      ENV_REF="${1#*=}"
      ;;
    --project-name=*)
      PROJECT_NAME="${1#*=}"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

if [ -z "$SOURCE_ENV" ] || [ -z "$CANVAS_WORKTREE" ]; then
  echo "Error: --source-env and --canvas-worktree are required."
  usage
  exit 1
fi

SOURCE_ENV="$(cd "$SOURCE_ENV" && pwd)"
CANVAS_WORKTREE="$(cd "$CANVAS_WORKTREE" && pwd)"

if [ -z "$ENV_WORKTREE" ]; then
  ENV_WORKTREE="$(dirname "$CANVAS_WORKTREE")/canvas-env"
elif [[ "$ENV_WORKTREE" != /* ]]; then
  ENV_WORKTREE="$(pwd)/$ENV_WORKTREE"
fi

if [ -z "$PROJECT_NAME" ]; then
  parent_name="$(basename "$(dirname "$ENV_WORKTREE")")"
  PROJECT_NAME="canvas-env-$parent_name"
fi

# DDEV derives container hostnames from the project name, and Docker rejects
# hostnames longer than 64 characters, so cap the length.
sanitize_project_name() {
  local name
  name="$(printf "%s" "$1" \
    | tr "[:upper:]" "[:lower:]" \
    | sed -E "s/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g")"
  if [ "${#name}" -gt 50 ]; then
    name="${name:0:50}"
    # Truncate at a hyphen so the name does not end mid-word.
    case "$name" in
      *-*) name="${name%-*}" ;;
    esac
  fi
  printf "%s" "$name"
}

yaml_quote() {
  printf "'%s'" "$(printf "%s" "$1" | sed "s/'/''/g")"
}

PROJECT_NAME="$(sanitize_project_name "$PROJECT_NAME")"

if [ -z "$PROJECT_NAME" ]; then
  echo "Error: Project name is empty after sanitizing."
  exit 1
fi

if ! git -C "$SOURCE_ENV" rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "Error: Source environment is not a Git repository: $SOURCE_ENV"
  exit 1
fi

if ! git -C "$CANVAS_WORKTREE" rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "Error: Canvas worktree is not a Git repository: $CANVAS_WORKTREE"
  exit 1
fi

MERCURY_SOURCE="$SOURCE_ENV/web/themes/contrib/mercury"
if ! git -C "$MERCURY_SOURCE" rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "Error: Mercury source repository is missing: $MERCURY_SOURCE"
  echo "Run ddev clone-repo-mercury in the source environment first."
  exit 1
fi

CREATED_ENV=false
CREATED_MERCURY=false
TARGET_CANVAS="$ENV_WORKTREE/web/modules/contrib/canvas"
TARGET_MERCURY="$ENV_WORKTREE/web/themes/contrib/mercury"

cleanup_on_error() {
  status=$?
  if [ "$status" -eq 0 ]; then
    return
  fi

  if [ "$CREATED_ENV" != true ] && [ "$CREATED_MERCURY" != true ]; then
    return
  fi

  echo
  echo "Environment wrapping failed. Cleaning up created worktrees."

  if [ "$CREATED_MERCURY" = true ]; then
    git -C "$MERCURY_SOURCE" worktree remove --force "$TARGET_MERCURY" >/dev/null 2>&1 || true
  fi

  if [ "$CREATED_ENV" = true ]; then
    git -C "$SOURCE_ENV" worktree remove --force "$ENV_WORKTREE" >/dev/null 2>&1 || true
  fi
}

trap cleanup_on_error EXIT

if [ -e "$ENV_WORKTREE" ]; then
  if ! git -C "$ENV_WORKTREE" rev-parse --show-toplevel >/dev/null 2>&1; then
    echo "Error: Environment path exists but is not a Git worktree: $ENV_WORKTREE"
    exit 1
  fi
else
  echo "Creating environment worktree at $ENV_WORKTREE."
  git -C "$SOURCE_ENV" worktree add --detach "$ENV_WORKTREE" "$ENV_REF"
  CREATED_ENV=true
fi

mkdir -p "$ENV_WORKTREE/web/modules/contrib" "$ENV_WORKTREE/web/themes/contrib"

if [ -e "$TARGET_CANVAS" ] && [ ! -L "$TARGET_CANVAS" ]; then
  echo "Error: Canvas target already exists and is not a symlink: $TARGET_CANVAS"
  exit 1
fi

ln -sfn "$CANVAS_WORKTREE" "$TARGET_CANVAS"

if [ ! -e "$TARGET_MERCURY" ]; then
  MERCURY_REF="$(git -C "$MERCURY_SOURCE" rev-parse HEAD)"
  echo "Creating detached Mercury worktree at $TARGET_MERCURY."
  git -C "$MERCURY_SOURCE" worktree add --detach "$TARGET_MERCURY" "$MERCURY_REF"
  CREATED_MERCURY=true
elif ! git -C "$TARGET_MERCURY" rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "Error: Mercury target exists but is not a Git repository: $TARGET_MERCURY"
  exit 1
fi

cat > "$ENV_WORKTREE/.ddev/config.local.yaml" <<EOF
name: $PROJECT_NAME
EOF

if [ -f "$SOURCE_ENV/.ddev/.env" ] && [ ! -f "$ENV_WORKTREE/.ddev/.env" ]; then
  cp "$SOURCE_ENV/.ddev/.env" "$ENV_WORKTREE/.ddev/.env"
fi

# Git worktrees reference their source repository by absolute path, which does
# not exist inside the web container. Mount each source .git directory at its
# host path so git keeps working in the mounted worktrees.
CANVAS_GIT_DIR="$(git -C "$CANVAS_WORKTREE" rev-parse --path-format=absolute --git-common-dir)"
ENV_GIT_DIR="$(git -C "$ENV_WORKTREE" rev-parse --path-format=absolute --git-common-dir)"
MERCURY_GIT_DIR="$(git -C "$TARGET_MERCURY" rev-parse --path-format=absolute --git-common-dir)"

cat > "$ENV_WORKTREE/.ddev/docker-compose.canvas-worktree.yaml" <<EOF
services:
  web:
    volumes:
      - type: bind
        source: $(yaml_quote "$CANVAS_WORKTREE")
        target: /var/www/html/web/modules/contrib/canvas
      - type: bind
        source: $(yaml_quote "$CANVAS_GIT_DIR")
        target: $(yaml_quote "$CANVAS_GIT_DIR")
      - type: bind
        source: $(yaml_quote "$ENV_GIT_DIR")
        target: $(yaml_quote "$ENV_GIT_DIR")
      - type: bind
        source: $(yaml_quote "$MERCURY_GIT_DIR")
        target: $(yaml_quote "$MERCURY_GIT_DIR")
EOF

"$SOURCE_ENV/scripts/wire-canvas-agents.sh" \
  --env-root="$ENV_WORKTREE" \
  --absolute \
  "$CANVAS_WORKTREE"

CANVAS_EXCLUDE_FILE="$(git -C "$CANVAS_WORKTREE" rev-parse --path-format=absolute --git-path info/exclude)"
touch "$CANVAS_EXCLUDE_FILE"
if ! grep -qxF ".ddev-env" "$CANVAS_EXCLUDE_FILE"; then
  echo ".ddev-env" >> "$CANVAS_EXCLUDE_FILE"
fi
ln -sfn "$ENV_WORKTREE" "$CANVAS_WORKTREE/.ddev-env"

cat <<EOF

Wrapped Canvas worktree with DDEV environment:
  Canvas: $CANVAS_WORKTREE
  Environment: $ENV_WORKTREE
  DDEV project: $PROJECT_NAME

Run DDEV commands from the environment wrapper:
  cd "$ENV_WORKTREE"
  ddev start
  ddev composer install
  ddev site-install
  ddev ui --install

From the Canvas worktree, the environment wrapper is available at:
  .ddev-env
EOF

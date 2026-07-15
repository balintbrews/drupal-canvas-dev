#!/bin/bash

set -euo pipefail

usage() {
  echo "Usage: $0 [--env-root=<path>] [--absolute] [canvas-repo-path]"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR=""
LINK_MODE="relative"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --env-root=*)
      ENV_ROOT="${1#*=}"
      ;;
    --absolute)
      LINK_MODE="absolute"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      echo "Error: Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      if [ -n "$TARGET_DIR" ]; then
        echo "Error: Only one Canvas repository path can be provided."
        usage
        exit 1
      fi
      TARGET_DIR="$1"
      ;;
  esac
  shift
done

ENV_ROOT="$(cd "$ENV_ROOT" && pwd)"
TARGET_DIR="${TARGET_DIR:-$ENV_ROOT/web/modules/contrib/canvas}"

if [ ! -f "$ENV_ROOT/agents/canvas/AGENTS.md" ]; then
  echo "Error: Canvas agent instructions not found in environment root: $ENV_ROOT"
  exit 1
fi

if [ ! -f "$ENV_ROOT/agents/canvas/CLAUDE.md" ]; then
  echo "Error: Canvas Claude instructions not found in environment root: $ENV_ROOT"
  exit 1
fi

if [ ! -d "$ENV_ROOT/agents/canvas/skills" ]; then
  echo "Error: Canvas skills directory not found in environment root: $ENV_ROOT"
  exit 1
fi

if [ ! -d "$ENV_ROOT/codex" ]; then
  echo "Error: Codex configuration not found in environment root: $ENV_ROOT"
  exit 1
fi

if [ "$LINK_MODE" = "absolute" ]; then
  ROOT_AGENTS_MD="$ENV_ROOT/agents/canvas/AGENTS.md"
  ROOT_CLAUDE_MD="$ENV_ROOT/agents/canvas/CLAUDE.md"
  ROOT_SKILLS="$ENV_ROOT/agents/canvas/skills"
  ROOT_CODEX="$ENV_ROOT/codex"
else
  ROOT_AGENTS_MD="../../../../agents/canvas/AGENTS.md"
  ROOT_CLAUDE_MD="../../../../agents/canvas/CLAUDE.md"
  ROOT_SKILLS="../../../../../agents/canvas/skills"
  ROOT_CODEX="../../../../codex"
fi

if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: Canvas repository does not exist: $TARGET_DIR"
  exit 1
fi

if ! git -C "$TARGET_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: $TARGET_DIR is not a Git repository."
  exit 1
fi

EXCLUDE_FILE="$(git -C "$TARGET_DIR" rev-parse --path-format=absolute --git-path info/exclude)"
mkdir -p "$(dirname "$EXCLUDE_FILE")"
touch "$EXCLUDE_FILE"

if ! grep -qxF "AGENTS.md" "$EXCLUDE_FILE"; then
  echo "AGENTS.md" >> "$EXCLUDE_FILE"
fi

if ! grep -qxF "CLAUDE.md" "$EXCLUDE_FILE"; then
  echo "CLAUDE.md" >> "$EXCLUDE_FILE"
fi

if ! grep -qxF ".agents/" "$EXCLUDE_FILE"; then
  echo ".agents/" >> "$EXCLUDE_FILE"
fi

if ! grep -qxF ".claude/" "$EXCLUDE_FILE"; then
  echo ".claude/" >> "$EXCLUDE_FILE"
fi

if ! grep -qxF ".codex" "$EXCLUDE_FILE"; then
  echo ".codex" >> "$EXCLUDE_FILE"
fi

ln -sfn "$ROOT_AGENTS_MD" "$TARGET_DIR/AGENTS.md"
ln -sfn "$ROOT_CLAUDE_MD" "$TARGET_DIR/CLAUDE.md"

# Canvas tracks AGENTS.md and CLAUDE.md, but this environment uses local symlink overrides.
for tracked_file in AGENTS.md CLAUDE.md; do
  if ! git -C "$TARGET_DIR" ls-files --error-unmatch -- "$tracked_file" >/dev/null 2>&1; then
    continue
  fi

  if git -C "$TARGET_DIR" update-index --skip-worktree -- "$tracked_file"; then
    echo "Marked tracked $tracked_file as skip-worktree so the local override stays hidden from Git status."
  else
    echo "Error: Failed to mark $tracked_file as skip-worktree."
    exit 1
  fi
done

mkdir -p "$TARGET_DIR/.agents"
ln -sfn "$ROOT_SKILLS" "$TARGET_DIR/.agents/skills"
mkdir -p "$TARGET_DIR/.claude"
ln -sfn "$ROOT_SKILLS" "$TARGET_DIR/.claude/skills"
ln -sfn "$ROOT_CODEX" "$TARGET_DIR/.codex"

echo "Configured local excludes in $EXCLUDE_FILE: AGENTS.md, CLAUDE.md, .agents/, .claude/, .codex."
echo "Configured symlinks:"
echo "  $TARGET_DIR/AGENTS.md -> $ROOT_AGENTS_MD"
echo "  $TARGET_DIR/CLAUDE.md -> $ROOT_CLAUDE_MD"
echo "  $TARGET_DIR/.agents/skills -> $ROOT_SKILLS"
echo "  $TARGET_DIR/.claude/skills -> $ROOT_SKILLS"
echo "  $TARGET_DIR/.codex -> $ROOT_CODEX"

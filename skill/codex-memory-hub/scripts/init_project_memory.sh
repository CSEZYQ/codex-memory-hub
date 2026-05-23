#!/usr/bin/env sh
set -eu

FORCE=0
PROJECT_NAME=""
TARGET_PATH=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --force)
      FORCE=1
      shift
      ;;
    --project-name)
      PROJECT_NAME=${2:?--project-name requires a value}
      shift 2
      ;;
    --path)
      TARGET_PATH=${2:?--path requires a value}
      shift 2
      ;;
    *)
      if [ -z "$TARGET_PATH" ]; then
        TARGET_PATH=$1
        shift
      else
        echo "Unknown argument: $1" >&2
        exit 1
      fi
      ;;
  esac
done

if [ -z "$TARGET_PATH" ]; then
  echo "Usage: init_project_memory.sh --path <project-path> [--project-name <name>] [--force]" >&2
  exit 1
fi

mkdir -p "$TARGET_PATH"
PROJECT_ROOT=$(cd "$TARGET_PATH" && pwd)

if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(basename "$PROJECT_ROOT")
fi
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME="Project"
fi

MEMORY_ROOT="$PROJECT_ROOT/.codex-memory"
THREADS_ROOT="$MEMORY_ROOT/threads"
WORKSTREAMS_ROOT="$MEMORY_ROOT/workstreams"
ARCHIVE_ROOT="$MEMORY_ROOT/archive"
TODAY=$(date +%Y-%m-%d)

write_file_if_needed() {
  file_path=$1
  content=$2
  parent_dir=$(dirname "$file_path")
  mkdir -p "$parent_dir"

  if [ -e "$file_path" ] && [ "$FORCE" -ne 1 ]; then
    echo "skip existing: $file_path"
    return
  fi

  printf '%s\n' "$content" > "$file_path"
  echo "write: $file_path"
}

mkdir -p "$THREADS_ROOT" "$WORKSTREAMS_ROOT" "$ARCHIVE_ROOT"

AGENTS_CONTENT=$(cat <<EOF
# $PROJECT_NAME Agent Rules

This project uses Codex Memory Hub. Keep the project root clean: AGENTS.md is the entrypoint and .codex-memory/ contains all memory data.

## Startup

For non-trivial work:

1. Read .codex-memory/index.md.
2. Read .codex-memory/project.md if it exists.
3. List every file under .codex-memory/threads/.
4. List relevant workstreams under .codex-memory/workstreams/.
5. Ask the user whether to create a new thread memory file or reuse an existing one, unless the user already specified the thread or workstream.

If there is no thread memory file, create a new one. If the user explicitly names a thread memory file or a specific workstream, use that file directly.

For parallel Codex work, create separate thread memory files. Reuse an existing thread memory file only when continuing the same workstream serially.

## Thread Memory

Store thread memory under .codex-memory/threads/ with a unique filename:

YYYY-MM-DD-HHMM-<short-task>.md

Each thread memory file should include:

- thread name
- created time
- updated time
- status: active, done, or archived
- scope
- optional workstream id
- current context
- timeline
- outputs
- decisions
- problems
- next steps

## Workstreams

For related parallel threads, use .codex-memory/workstreams/<workstream-id>/.

- workstream.md records scope, goal, related files, and active threads.
- snapshot.md is a compact rebuildable summary.
- events/ contains short event files from individual threads.

Prefer unique event files over rewriting one shared live status file.

## Writeback

At the end of meaningful work, update the selected thread memory file.

If the work belongs to a workstream, also write a short event file under .codex-memory/workstreams/<workstream-id>/events/.

Do not automatically update legacy shared project status files such as current-status.md, next-actions.md, decisions.md, or session-log.md. Project-level files are optional stable background, not live truth.

Only update .codex-memory/project.md or create a project-level summary when the user explicitly asks to summarize, consolidate, or update project-level memory.

If the selected thread memory file changed while this thread was preparing to write, re-read it and append carefully. If a safe append is not possible, create a new sibling file with a -fork-<shortid> suffix and mark which file it forked from.
EOF
)

INDEX_CONTENT=$(cat <<EOF
# Codex Memory Index

- [project.md](./project.md)
- [threads/](./threads/)
- [workstreams/](./workstreams/)
- [archive/](./archive/)

Root policy: keep project memory inside .codex-memory/; keep only AGENTS.md in the project root.
EOF
)

PROJECT_CONTENT=$(cat <<EOF
---
title: Project Background
source: project
created: $TODAY
updated: $TODAY
status: optional
---

# $PROJECT_NAME Project Background

This file is optional stable background. It is not a live status tracker.

## Purpose

- TBD

## Stable Context

- TBD

## Notes

- Thread work logs live in .codex-memory/threads/.
- Shared workstream coordination lives in .codex-memory/workstreams/.
EOF
)

write_file_if_needed "$PROJECT_ROOT/AGENTS.md" "$AGENTS_CONTENT"
write_file_if_needed "$MEMORY_ROOT/index.md" "$INDEX_CONTENT"
write_file_if_needed "$MEMORY_ROOT/project.md" "$PROJECT_CONTENT"
write_file_if_needed "$THREADS_ROOT/.gitkeep" ""
write_file_if_needed "$WORKSTREAMS_ROOT/.gitkeep" ""
write_file_if_needed "$ARCHIVE_ROOT/.gitkeep" ""

echo ""
echo "Codex memory initialized:"
echo "- Project:     $PROJECT_ROOT"
echo "- Entry:       $PROJECT_ROOT/AGENTS.md"
echo "- Memory root: $MEMORY_ROOT"
echo "- Threads:     $THREADS_ROOT"
echo "- Workstreams: $WORKSTREAMS_ROOT"

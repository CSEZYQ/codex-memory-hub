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
LEGACY_WIKI_ROOT="$PROJECT_ROOT/docs/wiki"
DOCS_ROOT="$PROJECT_ROOT/docs"
TODAY=$(date +%Y-%m-%d)
NOW=$(date "+%Y-%m-%d %H:%M")
STAMP=$(date +%Y-%m-%d-%H%M%S)

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

unique_path() {
  desired_path=$1
  if [ ! -e "$desired_path" ]; then
    printf '%s\n' "$desired_path"
    return
  fi

  parent_dir=$(dirname "$desired_path")
  leaf=$(basename "$desired_path")
  suffix=$(date +%H%M%S)-$$

  case "$leaf" in
    *.*)
      base=${leaf%.*}
      ext=.${leaf##*.}
      printf '%s\n' "$parent_dir/$base-$suffix$ext"
      ;;
    *)
      printf '%s\n' "$parent_dir/$leaf-$suffix"
      ;;
  esac
}

ensure_local_memory_gitignore() {
  if [ ! -d "$PROJECT_ROOT/.git" ]; then
    return
  fi

  gitignore="$PROJECT_ROOT/.gitignore"
  entry=".codex-memory/"

  if [ -f "$gitignore" ] && grep -qxF "$entry" "$gitignore"; then
    return
  fi

  if [ -f "$gitignore" ] && [ -s "$gitignore" ]; then
    last_char=$(tail -c 1 "$gitignore" || true)
    if [ "$last_char" != "" ]; then
      printf '\n' >> "$gitignore"
    fi
    printf '\n# Local Codex Memory Hub state\n%s\n' "$entry" >> "$gitignore"
  else
    printf '# Local Codex Memory Hub state\n%s\n' "$entry" > "$gitignore"
  fi

  echo "write: $gitignore"
}

migrate_legacy_wiki_if_needed() {
  if [ ! -d "$LEGACY_WIKI_ROOT" ]; then
    return
  fi

  echo "legacy memory detected: $LEGACY_WIKI_ROOT"

  legacy_project="$LEGACY_WIKI_ROOT/project.md"
  project_memory="$MEMORY_ROOT/project.md"
  if [ -f "$legacy_project" ] && [ ! -e "$project_memory" ]; then
    {
      cat <<EOF
---
title: Project Background
source: legacy-migration
created: $TODAY
updated: $TODAY
status: optional
migrated_from: docs/wiki/project.md
---

# $PROJECT_NAME Project Background

This file was migrated from the legacy docs/wiki/project.md layout.

## Migrated Legacy Project Context

EOF
      cat "$legacy_project"
    } > "$project_memory"
    echo "write: $project_memory"
  fi

  legacy_thread_root="$LEGACY_WIKI_ROOT/thread-memory"
  if [ -d "$legacy_thread_root" ]; then
    for legacy_thread in "$legacy_thread_root"/*.md; do
      [ -e "$legacy_thread" ] || continue
      destination=$(unique_path "$THREADS_ROOT/$(basename "$legacy_thread")")
      cp "$legacy_thread" "$destination"
      echo "migrate thread: $destination"
    done
  fi

  legacy_workstream="$WORKSTREAMS_ROOT/legacy-migration"
  legacy_events="$legacy_workstream/events"
  mkdir -p "$legacy_events"

  write_file_if_needed "$legacy_workstream/workstream.md" "---
workstream: legacy-migration
created: $TODAY
updated: $TODAY
status: archived
---

# Legacy Migration

This workstream records automatic migration from the old docs/wiki/ layout to .codex-memory/."

  write_file_if_needed "$legacy_workstream/snapshot.md" "---
workstream: legacy-migration
updated: $NOW
status: archived
---

# Snapshot

- Migrated legacy docs/wiki/ memory into .codex-memory/.
- Thread memories were copied into .codex-memory/threads/ when present.
- The original legacy wiki folder was moved into .codex-memory/archive/."

  write_file_if_needed "$legacy_events/$STAMP-legacy-docs-wiki-migrated.md" "---
event: legacy-docs-wiki-migrated
created: $NOW
type: migration
source: init_project_memory.sh
---

# Legacy docs/wiki Migrated

- Source: docs/wiki/
- Active thread memories copied to .codex-memory/threads/.
- Original legacy folder moved to .codex-memory/archive/."

  archive_destination=$(unique_path "$ARCHIVE_ROOT/legacy-docs-wiki")
  mv "$LEGACY_WIKI_ROOT" "$archive_destination"
  echo "archive legacy wiki: $archive_destination"

  rmdir "$DOCS_ROOT" 2>/dev/null || true
}

mkdir -p "$THREADS_ROOT" "$WORKSTREAMS_ROOT" "$ARCHIVE_ROOT"
migrate_legacy_wiki_if_needed

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

If legacy docs/wiki/ memory exists, migrate it into .codex-memory/ automatically before normal work. Do not make the user manually reorganize old memory files.

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

Before creating a workstream, list existing workstreams and reuse a matching one. If a duplicate is discovered later, mark the duplicate as archived and add superseded_by instead of deleting it.

Prefer unique event files over rewriting one shared live status file.

## Privacy And Git

Do not write secrets, API keys, passwords, access tokens, private credentials, or sensitive raw source material into memory files. Record only the fact that such material exists and where the user-approved source lives.

In Git projects, .codex-memory/ is local by default and should stay in .gitignore unless the user explicitly wants to share memory through the repository.

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
ensure_local_memory_gitignore

echo ""
echo "Codex memory initialized:"
echo "- Project:     $PROJECT_ROOT"
echo "- Entry:       $PROJECT_ROOT/AGENTS.md"
echo "- Memory root: $MEMORY_ROOT"
echo "- Threads:     $THREADS_ROOT"
echo "- Workstreams: $WORKSTREAMS_ROOT"

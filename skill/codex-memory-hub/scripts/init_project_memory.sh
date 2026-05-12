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

WIKI_ROOT="$PROJECT_ROOT/docs/wiki"
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

mkdir -p "$WIKI_ROOT"

AGENTS_CONTENT=$(cat <<EOF
# $PROJECT_NAME Agent Rules

This project uses Codex project memory. Do not rely only on the current chat context.

## Startup

For non-trivial work, read these files before acting:

1. docs/wiki/index.md
2. docs/wiki/current-status.md
3. docs/wiki/next-actions.md
4. docs/wiki/decisions.md
5. docs/wiki/session-log.md

If a file is empty or incomplete, update it as the project becomes clearer.

## Writeback

After meaningful work, update project memory without waiting for the user to ask:

- Current state: docs/wiki/current-status.md
- Next steps: docs/wiki/next-actions.md
- Decisions: docs/wiki/decisions.md
- Session summary: docs/wiki/session-log.md
- Loose ideas: docs/wiki/ideas.md

Code changes without memory writeback are incomplete when the work affects future context.

Before the final response, check whether this turn changed project state, decisions, next steps, risks, or ideas. If yes, update the relevant memory files first, then answer the user.

Keep writebacks short and durable. Do not paste full chat transcripts.

## Memory Layers

- raw: original source material
- wiki: compiled project knowledge
- state: current status, decisions, next actions, session log
- code: implementation
EOF
)

INDEX_CONTENT=$(cat <<EOF
# Wiki Index

- [project-overview.md](./project-overview.md)
- [current-status.md](./current-status.md)
- [next-actions.md](./next-actions.md)
- [decisions.md](./decisions.md)
- [session-log.md](./session-log.md)
- [ideas.md](./ideas.md)
- [log.md](./log.md)
EOF
)

OVERVIEW_CONTENT=$(cat <<EOF
---
title: Project Overview
source: session
created: $TODAY
tags: [overview]
status: draft
---

# $PROJECT_NAME Project Overview

Purpose:

- TBD

Users / audience:

- TBD

Core workflows:

- TBD
EOF
)

CURRENT_CONTENT=$(cat <<EOF
---
title: Current Status
source: session
created: $TODAY
tags: [status]
status: current
---

# Current Status

## Working State

- Project memory initialized on $TODAY.

## Known Risks

- TBD
EOF
)

NEXT_CONTENT=$(cat <<EOF
---
title: Next Actions
source: session
created: $TODAY
tags: [next-actions]
status: current
---

# Next Actions

- Define the project goal.
- Record the current implementation state.
- Add the first real next step after the next Codex session.
EOF
)

DECISIONS_CONTENT=$(cat <<EOF
---
title: Decisions
source: session
created: $TODAY
tags: [decisions]
status: current
---

# Decisions

## $TODAY

- Initialized Codex project memory for $PROJECT_NAME.
EOF
)

SESSION_CONTENT=$(cat <<EOF
---
title: Session Log
source: session
created: $TODAY
tags: [session-log]
status: current
---

# Session Log

## $TODAY | Memory Initialized

- Created project memory files for $PROJECT_NAME.
- Future Codex sessions should read AGENTS.md and docs/wiki/index.md first.
EOF
)

IDEAS_CONTENT=$(cat <<EOF
---
title: Ideas
source: session
created: $TODAY
tags: [ideas]
status: current
---

# Ideas

## Inbox

- TBD
EOF
)

LOG_CONTENT=$(cat <<EOF
# Log

## $TODAY | Memory Initialized

- Added Codex project memory structure.
EOF
)

write_file_if_needed "$PROJECT_ROOT/AGENTS.md" "$AGENTS_CONTENT"
write_file_if_needed "$WIKI_ROOT/index.md" "$INDEX_CONTENT"
write_file_if_needed "$WIKI_ROOT/project-overview.md" "$OVERVIEW_CONTENT"
write_file_if_needed "$WIKI_ROOT/current-status.md" "$CURRENT_CONTENT"
write_file_if_needed "$WIKI_ROOT/next-actions.md" "$NEXT_CONTENT"
write_file_if_needed "$WIKI_ROOT/decisions.md" "$DECISIONS_CONTENT"
write_file_if_needed "$WIKI_ROOT/session-log.md" "$SESSION_CONTENT"
write_file_if_needed "$WIKI_ROOT/ideas.md" "$IDEAS_CONTENT"
write_file_if_needed "$WIKI_ROOT/log.md" "$LOG_CONTENT"

echo ""
echo "Codex memory initialized:"
echo "- Project: $PROJECT_ROOT"
echo "- Entry:   $PROJECT_ROOT/AGENTS.md"
echo "- Wiki:    $WIKI_ROOT"

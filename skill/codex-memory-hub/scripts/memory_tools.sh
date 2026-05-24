#!/usr/bin/env sh
set -eu

COMMAND="doctor"
TARGET_PATH="."

while [ "$#" -gt 0 ]; do
  case "$1" in
    --path)
      TARGET_PATH=${2:?--path requires a value}
      shift 2
      ;;
    --command)
      COMMAND=${2:?--command requires a value}
      shift 2
      ;;
    doctor|index|all)
      COMMAND=$1
      shift
      ;;
    *)
      if [ -z "$TARGET_PATH" ] || [ "$TARGET_PATH" = "." ]; then
        TARGET_PATH=$1
        shift
      else
        echo "Unknown argument: $1" >&2
        exit 1
      fi
      ;;
  esac
done

PROJECT_ROOT=$(cd "$TARGET_PATH" && pwd)
MEMORY_ROOT="$PROJECT_ROOT/.codex-memory"
THREADS_ROOT="$MEMORY_ROOT/threads"
WORKSTREAMS_ROOT="$MEMORY_ROOT/workstreams"
ARCHIVE_ROOT="$MEMORY_ROOT/archive"
SYSTEM_ROOT="$MEMORY_ROOT/system"

relative_path() {
  case "$1" in
    "$PROJECT_ROOT"/*)
      printf '%s\n' "${1#"$PROJECT_ROOT"/}"
      ;;
    *)
      printf '%s\n' "$1"
      ;;
  esac
}

trim_value() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//; s/^'\''//; s/'\''$//'
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

frontmatter_value() {
  file=$1
  key=$2
  if [ ! -f "$file" ]; then
    printf '\n'
    return
  fi
  awk -v key="$key" '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm {
      prefix = key ":"
      if (index($0, prefix) == 1) {
        value = substr($0, length(prefix) + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", value)
        gsub(/^"|"$/, "", value)
        gsub(/^'\''|'\''$/, "", value)
        print value
        exit
      }
    }
  ' "$file"
}

frontmatter_list() {
  file=$1
  key=$2
  if [ ! -f "$file" ]; then
    return
  fi
  awk -v key="$key" '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm {
      prefix = key ":"
      if (index($0, prefix) == 1) { capture = 1; next }
      if (capture && $0 ~ /^[ \t]*-[ \t]+/) {
        value = $0
        sub(/^[ \t]*-[ \t]+/, "", value)
        gsub(/^[ \t]+|[ \t]+$/, "", value)
        gsub(/^"|"$/, "", value)
        gsub(/^'\''|'\''$/, "", value)
        print value
        next
      }
      if (capture && $0 !~ /^[ \t]/) { exit }
    }
  ' "$file"
}

count_files() {
  root=$1
  pattern=$2
  if [ ! -d "$root" ]; then
    printf '0\n'
    return
  fi
  find "$root" -type f -name "$pattern" 2>/dev/null | wc -l | tr -d ' '
}

add_issue() {
  severity=$1
  code=$2
  issue_path=$3
  message=$4
  printf '[%s] %s %s - %s\n' "$(printf '%s' "$severity" | tr '[:lower:]' '[:upper:]')" "$code" "$issue_path" "$message" >> "$ISSUES_FILE"
}

workstream_referenced_by_thread() {
  workstream_id=$1
  if [ ! -d "$THREADS_ROOT" ]; then
    return 1
  fi
  if grep -R -F -q "workstream: $workstream_id" "$THREADS_ROOT" 2>/dev/null; then
    return 0
  fi
  return 1
}

run_doctor() {
  ISSUES_FILE=$(mktemp)
  trap 'rm -f "$ISSUES_FILE"' EXIT

  thread_count=$(count_files "$THREADS_ROOT" "*.md")
  workstream_count=0
  if [ -d "$WORKSTREAMS_ROOT" ]; then
    workstream_count=$(find "$WORKSTREAMS_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')
  fi

  if [ ! -d "$MEMORY_ROOT" ]; then
    add_issue error MEMORY_ROOT_MISSING ".codex-memory/" "Memory root does not exist. Run the initializer first."
  else
    for required_dir in "$THREADS_ROOT" "$WORKSTREAMS_ROOT" "$ARCHIVE_ROOT" "$SYSTEM_ROOT"; do
      if [ ! -d "$required_dir" ]; then
        add_issue error MEMORY_DIRECTORY_MISSING "$(relative_path "$required_dir")/" "Required memory directory is missing."
      fi
    done
    for required_file in "$MEMORY_ROOT/index.md" "$MEMORY_ROOT/project.md"; do
      if [ ! -f "$required_file" ]; then
        add_issue warning MEMORY_FILE_MISSING "$(relative_path "$required_file")" "Expected memory entry file is missing."
      fi
    done
  fi

  if [ -d "$PROJECT_ROOT/.git" ]; then
    if [ ! -f "$PROJECT_ROOT/.gitignore" ] || ! grep -qxF ".codex-memory/" "$PROJECT_ROOT/.gitignore"; then
      add_issue warning MEMORY_NOT_GITIGNORED ".gitignore" "Git repository does not ignore .codex-memory/."
    fi
  fi

  if [ -d "$PROJECT_ROOT/docs/wiki" ]; then
    add_issue warning LEGACY_MEMORY_PRESENT "docs/wiki/" "Legacy docs/wiki memory still exists. Run the initializer to migrate it into .codex-memory/."
  fi

  if [ -d "$THREADS_ROOT" ]; then
    thread_list=$(mktemp)
    find "$THREADS_ROOT" -type f -name "*.md" 2>/dev/null | sort > "$thread_list"
    while IFS= read -r thread_file; do
      [ -n "$thread_file" ] || continue
      thread_path=$(relative_path "$thread_file")
      thread_name=$(basename "$thread_file")
      case "$thread_name" in
        [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]-*.md) ;;
        *) add_issue warning NON_STANDARD_THREAD_FILENAME "$thread_path" "Thread filename should use YYYY-MM-DD-HHMMSS-<short-task>.md." ;;
      esac

      for key in thread created updated status scope; do
        value=$(frontmatter_value "$thread_file" "$key")
        if [ -z "$value" ]; then
          add_issue warning THREAD_METADATA_MISSING "$thread_path" "Thread metadata '$key' is missing."
        fi
      done

      status=$(frontmatter_value "$thread_file" status)
      if [ -n "$status" ] && [ "$status" != "active" ] && [ "$status" != "done" ] && [ "$status" != "archived" ]; then
        add_issue warning THREAD_STATUS_UNKNOWN "$thread_path" "Thread status should be active, done, or archived."
      fi

      workstream=$(frontmatter_value "$thread_file" workstream)
      if [ -n "$workstream" ] && [ ! -d "$WORKSTREAMS_ROOT/$workstream" ]; then
        add_issue warning BROKEN_WORKSTREAM_REFERENCE "$thread_path" "Thread references a missing workstream: $workstream"
      fi

      refs=$(frontmatter_list "$thread_file" continues_from || true)
      for ref in $refs; do
        if [ ! -e "$PROJECT_ROOT/$ref" ] && [ ! -e "$(dirname "$thread_file")/$ref" ]; then
          add_issue warning BROKEN_CONTINUES_FROM "$thread_path" "continues_from target does not exist: $ref"
        fi
      done
    done < "$thread_list"
    rm -f "$thread_list"
  fi

  if [ -d "$WORKSTREAMS_ROOT" ]; then
    workstream_list=$(mktemp)
    find "$WORKSTREAMS_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name '.*' 2>/dev/null | sort > "$workstream_list"
    while IFS= read -r workstream_dir; do
      [ -n "$workstream_dir" ] || continue
      workstream_path=$(relative_path "$workstream_dir")
      workstream_id=$(basename "$workstream_dir")
      workstream_file="$workstream_dir/workstream.md"
      snapshot_file="$workstream_dir/snapshot.md"
      events_dir="$workstream_dir/events"
      status=""
      if [ -f "$workstream_file" ]; then
        status=$(frontmatter_value "$workstream_file" status)
      fi

      if [ "$status" != "archived" ] && ! workstream_referenced_by_thread "$workstream_id"; then
        add_issue warning WORKSTREAM_ORPHANED "$workstream_path" "Active workstream has no thread references."
      fi

      event_count=$(count_files "$events_dir" "*.md")
      if [ "$event_count" -gt 0 ] && [ ! -f "$snapshot_file" ]; then
        add_issue warning WORKSTREAM_SNAPSHOT_MISSING "$workstream_path" "Workstream has events but no snapshot.md."
      fi
      if [ -f "$snapshot_file" ] && [ -d "$events_dir" ] && find "$events_dir" -type f -name "*.md" -newer "$snapshot_file" 2>/dev/null | grep -q .; then
        add_issue warning WORKSTREAM_SNAPSHOT_STALE "$workstream_path" "snapshot.md is older than the latest workstream event."
      fi
    done < "$workstream_list"
    rm -f "$workstream_list"
  fi

  if [ -d "$MEMORY_ROOT" ]; then
    memory_files=$(mktemp)
    find "$MEMORY_ROOT" -type f -name "*.md" 2>/dev/null | sort > "$memory_files"
    while IFS= read -r memory_file; do
      [ -n "$memory_file" ] || continue
      if grep -E -i -q "(api[_-]?key|access[_-]?token|auth[_-]?token|password|passwd|secret)[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,}|sk-[a-z0-9_-]{12,}|ghp_[a-z0-9_]{20,}|github_pat_[a-z0-9_]{20,}|AKIA[0-9A-Z]{16}|eyJ[a-z0-9_-]{10,}\.eyJ[a-z0-9_-]{10,}" "$memory_file"; then
        add_issue warning POSSIBLE_SECRET "$(relative_path "$memory_file")" "Memory file contains a key-like token."
      fi
    done < "$memory_files"
    rm -f "$memory_files"
  fi

  echo "Codex Memory Hub doctor"
  echo "Project: $PROJECT_ROOT"
  echo "Memory:  $MEMORY_ROOT"
  echo "Threads: $thread_count"
  echo "Workstreams: $workstream_count"
  echo ""

  if [ ! -s "$ISSUES_FILE" ]; then
    echo "No errors found."
    echo "No warnings found."
  else
    if ! grep -q '^\[ERROR\]' "$ISSUES_FILE"; then
      echo "No errors found."
    fi
    cat "$ISSUES_FILE"
  fi
}

write_thread_index() {
  mkdir -p "$SYSTEM_ROOT"
  output="$SYSTEM_ROOT/thread-index.json"
  generated_at=$(date "+%Y-%m-%d %H:%M:%S")
  thread_count=$(count_files "$THREADS_ROOT" "*.md")
  {
    printf '{\n'
    printf '  "schema": "codex-memory-hub.thread-index.v1",\n'
    printf '  "generated_at": "%s",\n' "$(json_escape "$generated_at")"
    printf '  "project_root": "%s",\n' "$(json_escape "$PROJECT_ROOT")"
    printf '  "memory_root": ".codex-memory",\n'
    printf '  "thread_count": %s,\n' "$thread_count"
    printf '  "threads": [\n'
    first=1
    if [ -d "$THREADS_ROOT" ]; then
      thread_list=$(mktemp)
      find "$THREADS_ROOT" -type f -name "*.md" 2>/dev/null | sort > "$thread_list"
      while IFS= read -r thread_file; do
        [ -n "$thread_file" ] || continue
        if [ "$first" -eq 0 ]; then
          printf ',\n'
        fi
        first=0
        printf '    {\n'
        printf '      "name": "%s",\n' "$(json_escape "$(basename "$thread_file")")"
        printf '      "path": "%s",\n' "$(json_escape "$(relative_path "$thread_file")")"
        printf '      "thread": "%s",\n' "$(json_escape "$(frontmatter_value "$thread_file" thread)")"
        printf '      "created": "%s",\n' "$(json_escape "$(frontmatter_value "$thread_file" created)")"
        printf '      "updated": "%s",\n' "$(json_escape "$(frontmatter_value "$thread_file" updated)")"
        printf '      "status": "%s",\n' "$(json_escape "$(frontmatter_value "$thread_file" status)")"
        printf '      "scope": "%s",\n' "$(json_escape "$(frontmatter_value "$thread_file" scope)")"
        printf '      "workstream": "%s",\n' "$(json_escape "$(frontmatter_value "$thread_file" workstream)")"
        printf '      "continues_from": ['
        ref_first=1
        refs=$(frontmatter_list "$thread_file" continues_from || true)
        for ref in $refs; do
          if [ "$ref_first" -eq 0 ]; then
            printf ', '
          fi
          ref_first=0
          printf '"%s"' "$(json_escape "$ref")"
        done
        printf ']\n'
        printf '    }'
      done < "$thread_list"
      rm -f "$thread_list"
    fi
    printf '\n  ]\n'
    printf '}\n'
  } > "$output"
}

write_workstream_index() {
  mkdir -p "$SYSTEM_ROOT"
  output="$SYSTEM_ROOT/workstream-index.json"
  generated_at=$(date "+%Y-%m-%d %H:%M:%S")
  workstream_count=0
  if [ -d "$WORKSTREAMS_ROOT" ]; then
    workstream_count=$(find "$WORKSTREAMS_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')
  fi
  {
    printf '{\n'
    printf '  "schema": "codex-memory-hub.workstream-index.v1",\n'
    printf '  "generated_at": "%s",\n' "$(json_escape "$generated_at")"
    printf '  "project_root": "%s",\n' "$(json_escape "$PROJECT_ROOT")"
    printf '  "memory_root": ".codex-memory",\n'
    printf '  "workstream_count": %s,\n' "$workstream_count"
    printf '  "workstreams": [\n'
    first=1
    if [ -d "$WORKSTREAMS_ROOT" ]; then
      workstream_list=$(mktemp)
      find "$WORKSTREAMS_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name '.*' 2>/dev/null | sort > "$workstream_list"
      while IFS= read -r workstream_dir; do
        [ -n "$workstream_dir" ] || continue
        if [ "$first" -eq 0 ]; then
          printf ',\n'
        fi
        first=0
        workstream_file="$workstream_dir/workstream.md"
        events_dir="$workstream_dir/events"
        event_count=$(count_files "$events_dir" "*.md")
        printf '    {\n'
        printf '      "id": "%s",\n' "$(json_escape "$(basename "$workstream_dir")")"
        printf '      "path": "%s",\n' "$(json_escape "$(relative_path "$workstream_dir")")"
        printf '      "workstream": "%s",\n' "$(json_escape "$(frontmatter_value "$workstream_file" workstream)")"
        printf '      "created": "%s",\n' "$(json_escape "$(frontmatter_value "$workstream_file" created)")"
        printf '      "updated": "%s",\n' "$(json_escape "$(frontmatter_value "$workstream_file" updated)")"
        printf '      "status": "%s",\n' "$(json_escape "$(frontmatter_value "$workstream_file" status)")"
        printf '      "event_count": %s\n' "$event_count"
        printf '    }'
      done < "$workstream_list"
      rm -f "$workstream_list"
    fi
    printf '\n  ]\n'
    printf '}\n'
  } > "$output"
}

run_index() {
  if [ ! -d "$MEMORY_ROOT" ]; then
    echo "Memory root does not exist: $MEMORY_ROOT" >&2
    exit 1
  fi

  write_thread_index
  write_workstream_index
  echo "Codex Memory Hub index"
  echo "Project: $PROJECT_ROOT"
  echo "Threads: $(count_files "$THREADS_ROOT" "*.md")"
  if [ -d "$WORKSTREAMS_ROOT" ]; then
    echo "Workstreams: $(find "$WORKSTREAMS_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name '.*' 2>/dev/null | wc -l | tr -d ' ')"
  else
    echo "Workstreams: 0"
  fi
  echo "write: .codex-memory/system/thread-index.json"
  echo "write: .codex-memory/system/workstream-index.json"
}

case "$COMMAND" in
  doctor)
    run_doctor
    ;;
  index)
    run_index
    ;;
  all)
    run_doctor
    echo ""
    run_index
    ;;
  *)
    echo "Usage: memory_tools.sh --path <project-path> [doctor|index|all]" >&2
    exit 1
    ;;
esac

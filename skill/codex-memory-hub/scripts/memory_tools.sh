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
  target=$1
  prefix=$PROJECT_ROOT/
  relative=${target#"$prefix"}
  if [ "$relative" != "$target" ]; then
    printf '%s\n' "$relative"
  else
    printf '%s\n' "$target"
  fi
}

json_escape() {
  printf '%s' "$1" | awk '
    BEGIN {
      first = 1
      tab = sprintf("%c", 9)
      cr = sprintf("%c", 13)
    }
    {
      if (!first) {
        printf "\\n"
      }
      first = 0
      line = $0
      gsub(/\\/, "\\\\", line)
      gsub(/"/, "\\\"", line)
      gsub(tab, "\\t", line)
      gsub(cr, "\\r", line)
      printf "%s", line
    }
  '
}

frontmatter_value() {
  file=$1
  key=$2
  if [ ! -f "$file" ]; then
    printf '\n'
    return
  fi
  awk -v key="$key" '
    NR == 1 { sub(/^\357\273\277/, "") }
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    block {
      if ($0 ~ /^[A-Za-z0-9_-]+:[ \t]*/) {
        print value
        block = 0
        printed = 1
        exit
      }
      line = $0
      sub(/^[ \t]+/, "", line)
      if (value == "") {
        value = line
      } else if (folded) {
        value = value " " line
      } else {
        value = value "\n" line
      }
      next
    }
    fm {
      prefix = key ":"
      if (index($0, prefix) == 1) {
        value = substr($0, length(prefix) + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", value)
        gsub(/^"|"$/, "", value)
        gsub(/^'\''|'\''$/, "", value)
        if (value == "|" || value == ">") {
          block = 1
          folded = (value == ">")
          value = ""
          next
        }
        print value
        exit
      }
    }
    END {
      if (block && !printed) {
        print value
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
    NR == 1 { sub(/^\357\273\277/, "") }
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

list_direct_files() {
  root=$1
  pattern=$2
  if [ ! -d "$root" ]; then
    return 0
  fi

  for item in "$root"/$pattern; do
    [ -f "$item" ] || continue
    printf '%s\n' "$item"
  done | sort
}

list_direct_dirs() {
  root=$1
  if [ ! -d "$root" ]; then
    return 0
  fi

  for item in "$root"/*; do
    [ -d "$item" ] || continue
    name=$(basename "$item")
    case "$name" in
      .*) continue ;;
    esac
    printf '%s\n' "$item"
  done | sort
}

count_files() {
  root=$1
  pattern=$2
  list_direct_files "$root" "$pattern" | wc -l | tr -d ' '
}

file_size_bytes() {
  if [ -f "$1" ]; then
    wc -c < "$1" | tr -d ' '
  else
    printf '0\n'
  fi
}

file_modified_at() {
  if [ ! -e "$1" ]; then
    printf '\n'
    return
  fi
  if date -r "$1" "+%Y-%m-%d %H:%M:%S" >/dev/null 2>&1; then
    date -r "$1" "+%Y-%m-%d %H:%M:%S"
  elif stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$1" >/dev/null 2>&1; then
    stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$1"
  else
    printf '\n'
  fi
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
  if [ -z "${THREAD_WORKSTREAMS_FILE:-}" ] || [ ! -f "$THREAD_WORKSTREAMS_FILE" ]; then
    return 1
  fi
  awk -v id="$workstream_id" 'BEGIN { FS = sprintf("%c", 9) } $1 == id { found = 1 } END { exit found ? 0 : 1 }' "$THREAD_WORKSTREAMS_FILE"
}

active_threads_json_for_workstream() {
  workstream_id=$1
  active_threads_file=$2
  first_active=1
  if [ ! -f "$active_threads_file" ]; then
    return
  fi
  tab=$(printf '\t')
  while IFS="$tab" read -r thread_workstream thread_path; do
    [ -n "$thread_workstream" ] || continue
    if [ "$thread_workstream" = "$workstream_id" ]; then
      if [ "$first_active" -eq 0 ]; then
        printf ', '
      fi
      first_active=0
      printf '"%s"' "$(json_escape "$thread_path")"
    fi
  done < "$active_threads_file"
}

latest_event_path() {
  events_dir=$1
  latest=$(list_direct_files "$events_dir" "*.md" | tail -n 1)
  if [ -n "$latest" ]; then
    relative_path "$latest"
  else
    printf '\n'
  fi
}

normalize_memory_timestamp() {
  value=$(printf '%s' "$1" | tr 'T' ' ')
  if [ -z "$value" ]; then
    printf '\n'
    return
  fi

  date_part=${value%% *}
  if [ "$date_part" = "$value" ]; then
    time_part="000000"
  else
    time_part=${value#* }
    time_part=${time_part%% *}
    time_part=$(printf '%s' "$time_part" | tr -d ':')
    if [ -z "$time_part" ]; then
      time_part="000000"
    elif [ "${#time_part}" -eq 4 ]; then
      time_part="${time_part}00"
    fi
  fi

  case "$date_part-$time_part" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9])
      printf '%s\n' "$date_part-$time_part"
      ;;
    *)
      printf '\n'
      ;;
  esac
}

event_timestamp_from_path() {
  name=$(basename "$1")
  case "$name" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]-*)
      printf '%s\n' "$(printf '%s' "$name" | cut -c 1-17)"
      ;;
    *)
      printf '\n'
      ;;
  esac
}

run_doctor() {
  ISSUES_FILE=$(mktemp)
  THREAD_WORKSTREAMS_FILE=$(mktemp)
  ACTIVE_CONTINUATIONS_FILE=$(mktemp)

  thread_count=$(count_files "$THREADS_ROOT" "*.md")
  workstream_count=0
  if [ -d "$WORKSTREAMS_ROOT" ]; then
    workstream_count=$(list_direct_dirs "$WORKSTREAMS_ROOT" | wc -l | tr -d ' ')
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
    list_direct_files "$THREADS_ROOT" "*.md" > "$thread_list"
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
      if [ -n "$workstream" ]; then
        printf '%s%s%s\n' "$workstream" "$(printf '\t')" "$thread_path" >> "$THREAD_WORKSTREAMS_FILE"
      fi
      if [ -n "$workstream" ] && [ ! -d "$WORKSTREAMS_ROOT/$workstream" ]; then
        add_issue warning BROKEN_WORKSTREAM_REFERENCE "$thread_path" "Thread references a missing workstream: $workstream"
      fi

      refs_file=$(mktemp)
      frontmatter_list "$thread_file" continues_from > "$refs_file" || true
      while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        if [ "$status" = "active" ]; then
          printf '%s%s%s\n' "$ref" "$(printf '\t')" "$thread_path" >> "$ACTIVE_CONTINUATIONS_FILE"
        fi
        if [ ! -e "$PROJECT_ROOT/$ref" ] && [ ! -e "$(dirname "$thread_file")/$ref" ]; then
          add_issue warning BROKEN_CONTINUES_FROM "$thread_path" "continues_from target does not exist: $ref"
        fi
      done < "$refs_file"
      rm -f "$refs_file"
    done < "$thread_list"
    rm -f "$thread_list"
  fi

  if [ -s "$ACTIVE_CONTINUATIONS_FILE" ]; then
    awk '
      BEGIN { FS = sprintf("%c", 9); OFS = FS }
      {
        count[$1] += 1
        if (paths[$1] == "") {
          paths[$1] = $2
        } else {
          paths[$1] = paths[$1] ", " $2
        }
      }
      END {
        for (ref in count) {
          if (count[ref] > 1) {
            print ref, paths[ref]
          }
        }
      }
    ' "$ACTIVE_CONTINUATIONS_FILE" | while IFS="$(printf '\t')" read -r ref paths; do
      [ -n "$ref" ] || continue
      add_issue warning POSSIBLE_CONTINUATION_FORK "$ref" "Multiple active threads continue from the same predecessor: $paths"
    done
  fi

  if [ -d "$WORKSTREAMS_ROOT" ]; then
    workstream_list=$(mktemp)
    list_direct_dirs "$WORKSTREAMS_ROOT" > "$workstream_list"
    while IFS= read -r workstream_dir; do
      [ -n "$workstream_dir" ] || continue
      workstream_path=$(relative_path "$workstream_dir")
      workstream_id=$(basename "$workstream_dir")
      workstream_file="$workstream_dir/workstream.md"
      snapshot_file="$workstream_dir/snapshot.md"
      events_dir="$workstream_dir/events"
      status=""
      if [ ! -f "$workstream_file" ]; then
        add_issue warning WORKSTREAM_FILE_MISSING "$workstream_path" "Workstream directory is missing workstream.md."
      else
        for key in workstream created updated status; do
          value=$(frontmatter_value "$workstream_file" "$key")
          if [ -z "$value" ]; then
            add_issue warning WORKSTREAM_METADATA_MISSING "$workstream_path" "Workstream metadata '$key' is missing."
          fi
        done
        declared_workstream=$(frontmatter_value "$workstream_file" workstream)
        if [ -n "$declared_workstream" ] && [ "$declared_workstream" != "$workstream_id" ]; then
          add_issue warning WORKSTREAM_ID_MISMATCH "$workstream_path" "workstream.md declares '$declared_workstream' but directory id is '$workstream_id'."
        fi
        status=$(frontmatter_value "$workstream_file" status)
        if [ -n "$status" ] && [ "$status" != "active" ] && [ "$status" != "done" ] && [ "$status" != "archived" ]; then
          add_issue warning WORKSTREAM_STATUS_UNKNOWN "$workstream_path" "Workstream status should be active, done, or archived."
        fi
      fi

      if [ "$status" != "archived" ] && ! workstream_referenced_by_thread "$workstream_id"; then
        add_issue warning WORKSTREAM_ORPHANED "$workstream_path" "Active workstream has no thread references."
      fi

      event_count=$(count_files "$events_dir" "*.md")
      if [ "$event_count" -gt 0 ] && [ ! -f "$snapshot_file" ]; then
        add_issue warning WORKSTREAM_SNAPSHOT_MISSING "$workstream_path" "Workstream has events but no snapshot.md."
      fi
      if [ -f "$snapshot_file" ] && [ -d "$events_dir" ]; then
        latest_event=$(latest_event_path "$events_dir")
        latest_event_timestamp=$(event_timestamp_from_path "$latest_event")
        snapshot_timestamp=$(normalize_memory_timestamp "$(frontmatter_value "$snapshot_file" updated)")
        if [ -n "$latest_event_timestamp" ] && [ -n "$snapshot_timestamp" ] && [ "$latest_event_timestamp" \> "$snapshot_timestamp" ]; then
          add_issue warning WORKSTREAM_SNAPSHOT_STALE "$workstream_path" "snapshot.md is older than the latest workstream event."
        fi
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

  if grep -q '^\[ERROR\]' "$ISSUES_FILE"; then
    rm -f "$ISSUES_FILE" "$THREAD_WORKSTREAMS_FILE" "$ACTIVE_CONTINUATIONS_FILE"
    return 1
  fi
  rm -f "$ISSUES_FILE" "$THREAD_WORKSTREAMS_FILE" "$ACTIVE_CONTINUATIONS_FILE"
  return 0
}

write_thread_index() {
  mkdir -p "$SYSTEM_ROOT"
  output="$SYSTEM_ROOT/thread-index.json"
  generated_at=$(date "+%Y-%m-%d %H:%M:%S")
  thread_count=0
  active_count=0
  done_count=0
  archived_count=0
  entries_file=$(mktemp)
  first=1
  if [ -d "$THREADS_ROOT" ]; then
    thread_list=$(mktemp)
    list_direct_files "$THREADS_ROOT" "*.md" > "$thread_list"
    while IFS= read -r thread_file; do
      [ -n "$thread_file" ] || continue
      thread_count=$((thread_count + 1))
      thread_status=$(frontmatter_value "$thread_file" status)
      case "$thread_status" in
        active) active_count=$((active_count + 1)) ;;
        done) done_count=$((done_count + 1)) ;;
        archived) archived_count=$((archived_count + 1)) ;;
      esac
      if [ "$first" -eq 0 ]; then
        printf ',\n' >> "$entries_file"
      fi
      first=0
      {
        printf '    {\n'
        printf '      "name": "%s",\n' "$(json_escape "$(basename "$thread_file")")"
        printf '      "path": "%s",\n' "$(json_escape "$(relative_path "$thread_file")")"
        printf '      "thread": "%s",\n' "$(json_escape "$(frontmatter_value "$thread_file" thread)")"
        printf '      "created": "%s",\n' "$(json_escape "$(frontmatter_value "$thread_file" created)")"
        printf '      "updated": "%s",\n' "$(json_escape "$(frontmatter_value "$thread_file" updated)")"
        printf '      "status": "%s",\n' "$(json_escape "$thread_status")"
        printf '      "scope": "%s",\n' "$(json_escape "$(frontmatter_value "$thread_file" scope)")"
        printf '      "workstream": "%s",\n' "$(json_escape "$(frontmatter_value "$thread_file" workstream)")"
        printf '      "continues_from": ['
        ref_first=1
        refs_file=$(mktemp)
        frontmatter_list "$thread_file" continues_from > "$refs_file" || true
        while IFS= read -r ref; do
          [ -n "$ref" ] || continue
          if [ "$ref_first" -eq 0 ]; then
            printf ', '
          fi
          ref_first=0
          printf '"%s"' "$(json_escape "$ref")"
        done < "$refs_file"
        rm -f "$refs_file"
        printf '],\n'
        printf '      "size_bytes": %s,\n' "$(file_size_bytes "$thread_file")"
        printf '      "modified_at": "%s"\n' "$(json_escape "$(file_modified_at "$thread_file")")"
        printf '    }'
      } >> "$entries_file"
    done < "$thread_list"
    rm -f "$thread_list"
  fi
  {
    printf '{\n'
    printf '  "schema": "codex-memory-hub.thread-index.v1",\n'
    printf '  "generated_at": "%s",\n' "$(json_escape "$generated_at")"
    printf '  "memory_root": ".codex-memory",\n'
    printf '  "thread_count": %s,\n' "$thread_count"
    printf '  "active_count": %s,\n' "$active_count"
    printf '  "done_count": %s,\n' "$done_count"
    printf '  "archived_count": %s,\n' "$archived_count"
    printf '  "threads": [\n'
    cat "$entries_file"
    printf '\n  ]\n'
    printf '}\n'
  } > "$output"
  rm -f "$entries_file"
}

write_workstream_index() {
  mkdir -p "$SYSTEM_ROOT"
  output="$SYSTEM_ROOT/workstream-index.json"
  generated_at=$(date "+%Y-%m-%d %H:%M:%S")
  workstream_count=0
  if [ -d "$WORKSTREAMS_ROOT" ]; then
    workstream_count=$(list_direct_dirs "$WORKSTREAMS_ROOT" | wc -l | tr -d ' ')
  fi
  active_threads_file=$(mktemp)
  if [ -d "$THREADS_ROOT" ]; then
    thread_list_for_workstreams=$(mktemp)
    list_direct_files "$THREADS_ROOT" "*.md" > "$thread_list_for_workstreams"
    while IFS= read -r thread_file; do
      [ -n "$thread_file" ] || continue
      thread_workstream=$(frontmatter_value "$thread_file" workstream)
      thread_status=$(frontmatter_value "$thread_file" status)
      if [ -n "$thread_workstream" ] && [ "$thread_status" = "active" ]; then
        printf '%s\t%s\n' "$thread_workstream" "$(relative_path "$thread_file")" >> "$active_threads_file"
      fi
    done < "$thread_list_for_workstreams"
    rm -f "$thread_list_for_workstreams"
  fi
  {
    printf '{\n'
    printf '  "schema": "codex-memory-hub.workstream-index.v1",\n'
    printf '  "generated_at": "%s",\n' "$(json_escape "$generated_at")"
    printf '  "memory_root": ".codex-memory",\n'
    printf '  "workstream_count": %s,\n' "$workstream_count"
    printf '  "workstreams": [\n'
    first=1
    if [ -d "$WORKSTREAMS_ROOT" ]; then
      workstream_list=$(mktemp)
      list_direct_dirs "$WORKSTREAMS_ROOT" > "$workstream_list"
      while IFS= read -r workstream_dir; do
        [ -n "$workstream_dir" ] || continue
        if [ "$first" -eq 0 ]; then
          printf ',\n'
        fi
        first=0
        workstream_file="$workstream_dir/workstream.md"
        snapshot_file="$workstream_dir/snapshot.md"
        events_dir="$workstream_dir/events"
        event_count=$(count_files "$events_dir" "*.md")
        if [ -f "$snapshot_file" ]; then
          snapshot_exists=true
        else
          snapshot_exists=false
        fi
        printf '    {\n'
        printf '      "id": "%s",\n' "$(json_escape "$(basename "$workstream_dir")")"
        printf '      "path": "%s",\n' "$(json_escape "$(relative_path "$workstream_dir")")"
        printf '      "workstream": "%s",\n' "$(json_escape "$(frontmatter_value "$workstream_file" workstream)")"
        printf '      "created": "%s",\n' "$(json_escape "$(frontmatter_value "$workstream_file" created)")"
        printf '      "updated": "%s",\n' "$(json_escape "$(frontmatter_value "$workstream_file" updated)")"
        printf '      "status": "%s",\n' "$(json_escape "$(frontmatter_value "$workstream_file" status)")"
        printf '      "event_count": %s,\n' "$event_count"
        printf '      "latest_event": "%s",\n' "$(json_escape "$(latest_event_path "$events_dir")")"
        printf '      "snapshot_exists": %s,\n' "$snapshot_exists"
        printf '      "active_threads": ['
        active_threads_json_for_workstream "$(basename "$workstream_dir")" "$active_threads_file"
        printf '],\n'
        printf '      "modified_at": "%s"\n' "$(json_escape "$(file_modified_at "$workstream_dir")")"
        printf '    }'
      done < "$workstream_list"
      rm -f "$workstream_list"
    fi
    printf '\n  ]\n'
    printf '}\n'
  } > "$output"
  rm -f "$active_threads_file"
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
    echo "Workstreams: $(list_direct_dirs "$WORKSTREAMS_ROOT" | wc -l | tr -d ' ')"
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
    doctor_code=0
    run_doctor || doctor_code=$?
    echo ""
    index_code=0
    run_index || index_code=$?
    if [ "$doctor_code" -ne 0 ]; then
      exit "$doctor_code"
    fi
    exit "$index_code"
    ;;
  *)
    echo "Usage: memory_tools.sh --path <project-path> [doctor|index|all]" >&2
    exit 1
    ;;
esac

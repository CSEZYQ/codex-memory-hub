---
name: codex-memory-hub
description: Use when the user creates a project, asks to set up Codex memory, wants context to survive restarted threads, wants clean per-thread memory for parallel Codex work, asks for Memory Hub, needs legacy docs/wiki memory migrated, or needs Codex to create, list, reuse, or write thread/workstream memory files.
---

# Codex Memory Hub

Use this skill to make Codex work restartable without cluttering the project root or forcing every thread to maintain shared project status files.

The root should stay clean:

- `AGENTS.md` is the lightweight Codex entrypoint.
- `.codex-memory/` contains all memory data.

## Initialize A Project

Use the bundled script whenever the target is a normal local project directory. Resolve the script path relative to this `SKILL.md`; do not assume the plugin was installed under a specific user home directory.

PowerShell, including Windows PowerShell or PowerShell Core:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "<this-skill-dir>/scripts/init_project_memory.ps1" -Path "<project-path>"
```

If `pwsh` is unavailable on Windows, use `powershell` with the same arguments.

POSIX shell, including macOS and Linux:

```sh
sh "<this-skill-dir>/scripts/init_project_memory.sh" --path "<project-path>"
```

The script creates:

- `AGENTS.md`
- `.codex-memory/index.md`
- `.codex-memory/project.md`
- `.codex-memory/threads/`
- `.codex-memory/workstreams/`
- `.codex-memory/archive/`

It skips existing files by default. Use `-Force` in PowerShell or `--force` in shell only when the user explicitly wants to overwrite an existing memory scaffold.

If a project already has legacy `docs/wiki/` memory, the initializer migrates it automatically:

- Copy legacy thread memories into `.codex-memory/threads/`.
- Preserve legacy files under `.codex-memory/archive/legacy-docs-wiki...`.
- Create a `legacy-migration` workstream event.
- Remove the empty legacy `docs/` folder when it is safe.
- In Git repositories, add `.codex-memory/` to `.gitignore` by default.

## Startup Protocol

When working in a project that has Codex Memory Hub files:

1. Read `AGENTS.md`.
2. Read `.codex-memory/index.md`.
3. Read `.codex-memory/project.md` if it exists.
4. Scan `.codex-memory/threads/*.md`.
5. Scan `.codex-memory/workstreams/*/workstream.md` and `.codex-memory/workstreams/*/snapshot.md` when present.
6. List every relevant thread memory for the user, including filename plus any visible `status`, `updated`, and `scope` metadata.
7. Ask the user to choose whether to create a new thread memory file or reuse an existing one, unless the user already specified the thread/workstream.

If no thread memory file exists, create one. If the user explicitly names a thread memory file or says to continue a specific workstream, use that file directly.

For legacy projects that still use `docs/wiki/`, migrate them into `.codex-memory/` automatically before normal work. Do not make the user manually reorganize old memory files. After migration, read legacy content from `.codex-memory/archive/` as historical context.

## Thread Memory Files

Create thread memory files under `.codex-memory/threads/` with unique names:

```text
YYYY-MM-DD-HHMM-<short-task>.md
```

Use this structure:

```markdown
---
thread: <short name>
created: <YYYY-MM-DD HH:mm>
updated: <YYYY-MM-DD HH:mm>
status: active
scope: <task scope>
workstream: <optional workstream id>
---

# <Thread Name>

## Current Context

- ...

## Timeline

- <timestamp> - ...

## Outputs

- ...

## Decisions

- ...

## Problems

- ...

## Next

- ...
```

Keep thread memory factual. It is a work log, not a final project truth.

## Workstream Memory

Use workstreams when several Codex threads collaborate on the same feature, deliverable, or discussion.

Workstream layout:

```text
.codex-memory/workstreams/<workstream-id>/
  workstream.md
  snapshot.md
  events/
```

- `workstream.md` defines scope, goal, related files, and active threads.
- `snapshot.md` is a compact, rebuildable summary for quick startup.
- `events/` stores append-only event files from individual threads.

Each thread may write its own event file under `events/` when it pauses, finishes, hits a blocker, or hands off important context. Prefer unique event files over rewriting a shared live status file.

Before creating a workstream, list existing workstreams and reuse a matching one. If a duplicate is discovered later, mark the duplicate as archived and add `superseded_by` instead of deleting it.

Use unique event filenames:

```text
YYYY-MM-DD-HHMMSS-<thread-or-task>-<event>.md
```

## Privacy And Git

Do not write secrets, API keys, passwords, access tokens, private credentials, or sensitive raw source material into memory files. Record only the fact that such material exists and where the user-approved source lives.

In Git projects, `.codex-memory/` is local by default and should stay in `.gitignore` unless the user explicitly wants to share memory through the repository.

If the user wants shared team memory, explain the tradeoff first: committing `.codex-memory/` improves team continuity but may expose private decisions, local paths, prompts, or sensitive project details.

## Writeback Protocol

At the end of meaningful work:

1. Update the selected thread memory file under `.codex-memory/threads/`.
2. If the work belongs to a workstream, write a short event file under `.codex-memory/workstreams/<workstream-id>/events/`.
3. Update `snapshot.md` only as a convenience summary. It must remain rebuildable from thread memories and events.

Do not automatically create or update legacy shared status files such as `current-status.md`, `next-actions.md`, `decisions.md`, or `session-log.md`.

Project-level files are optional stable background. Update `.codex-memory/project.md` only when the user explicitly asks to summarize, consolidate, or update project-level memory.

If the selected thread memory file changed while this thread was preparing to write, re-read the latest file and append carefully. If a safe append is not possible, create a new sibling thread memory file with a `-fork-<shortid>` suffix and clearly mark which file it forked from.

## Multi-Project Rule

Keep each project's memory inside that project. Do not mix multiple applications into one project page.

Use a central Memory Hub only for:

- Cross-project index
- Raw idea inbox
- Shared workflow notes
- Links to project-specific memory folders

## Answering The User

Be clear about the automation boundary:

- A skill can provide the reusable workflow and script.
- It can initialize files whenever Codex is asked to start or prepare a project.
- It cannot silently run for every new folder created by the operating system unless the user installs a separate watcher or always creates projects through a wrapper script.

Prefer the safe default: initialize on request or through a project-creation command, not a background filesystem watcher.

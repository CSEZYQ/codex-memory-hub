---
name: codex-memory-hub
description: Use when the user creates a project, asks to set up Codex memory, wants context to survive restarted threads, wants clean per-thread memory for parallel Codex work, asks for Memory Hub, needs legacy docs/wiki memory migrated, or needs Codex memory to infer the right thread/workstream for ongoing project work.
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
- `.codex-memory/system/`

It skips existing files by default. Use `-Force` in PowerShell or `--force` in shell only when the user explicitly wants to overwrite an existing memory scaffold.

If a project already has legacy `docs/wiki/` memory, the initializer migrates it automatically:

- Copy legacy thread memories into `.codex-memory/threads/`.
- Convert first public `project-overview.md` into `.codex-memory/project.md` when no legacy `project.md` exists.
- Convert first public status pages such as `current-status.md`, `next-actions.md`, `decisions.md`, `session-log.md`, `ideas.md`, and `log.md` into an active `.codex-memory/threads/*-legacy-project-memory.md` file.
- Preserve legacy files under `.codex-memory/archive/legacy-docs-wiki...`.
- Create a `legacy-migration` workstream event.
- Remove the empty legacy `docs/` folder when it is safe.
- In Git repositories, add `.codex-memory/` to `.gitignore` by default.

## Startup Protocol

When working in a project that has Codex Memory Hub files:

1. Read `AGENTS.md`.
2. Read `.codex-memory/index.md`.
3. Read `.codex-memory/project.md` if it exists.
4. Read `.codex-memory/system/thread-index.json` and `.codex-memory/system/workstream-index.json` when present.
5. Scan `.codex-memory/threads/*.md` only as needed after using the index map.
6. Scan `.codex-memory/workstreams/*/workstream.md` and `.codex-memory/workstreams/*/snapshot.md` when present.
7. Infer read context and write target separately from the user's request, current directory, recently changed files, Git branch when available, thread metadata, workstream scope, and recent snapshots.
8. Continue with the inferred targets without asking when confidence is high. A brief status note is fine; do not interrupt the user just to choose a thread or workstream.

If no thread memory file exists, create one. If no existing thread or workstream clearly matches the current task, create a new thread memory file and, when useful, a new workstream.

For every new Codex conversation, create a new thread memory file by default. Existing thread memory files are read-only context by default, even when the user says to continue previous work. If the new conversation continues previous work, read the relevant old thread memories and record them in the new thread's `continues_from` metadata. Link the new thread to the matching workstream when one exists.

Write to an existing thread memory only when the user explicitly names that thread file and clearly asks to reuse or continue writing that exact file.

Ask the user only when automation would be risky or genuinely ambiguous:

- Several plausible threads/workstreams match and choosing one would materially change the work.
- Existing memories contain conflicting conclusions that affect the current answer.
- The user may want to share `.codex-memory/` through Git or keep it private.
- A destructive action is involved, such as deleting, overwriting, or consolidating memory.

For legacy projects that still use `docs/wiki/`, migrate them into `.codex-memory/` automatically before normal work. Do not make the user manually reorganize old memory files. After migration, read legacy content from `.codex-memory/archive/` as historical context.

## Deterministic Maintenance

The skill is the workflow layer. The bundled maintenance script is the deterministic check/index layer.

PowerShell, including Windows PowerShell or PowerShell Core:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "<this-skill-dir>/scripts/memory_tools.ps1" -Path "<project-path>" -Command doctor
pwsh -NoProfile -ExecutionPolicy Bypass -File "<this-skill-dir>/scripts/memory_tools.ps1" -Path "<project-path>" -Command index
```

If `pwsh` is unavailable on Windows, use `powershell` with the same arguments.

Use `doctor` when memory looks inconsistent, after legacy migration, before sharing `.codex-memory/`, or when the user asks to audit/clean memory. It is read-only and reports:

- Missing memory structure.
- Missing Git privacy default for `.codex-memory/`.
- Legacy `docs/wiki/` that still needs migration.
- Broken `continues_from` links.
- Multiple active threads continuing from the same predecessor.
- Workstream snapshots that are missing or stale.
- Possible secret-like strings in memory files.

Use `index` to refresh:

- `.codex-memory/system/thread-index.json`
- `.codex-memory/system/workstream-index.json`

These indexes are generated maps, not source memory. Use them to reduce startup scanning, then open only the relevant thread/workstream files. They can be deleted and rebuilt at any time.

## Intent Detection

Treat workstreams as internal coordination, not something the user must name.

Infer read context, write target, and workstream separately:

- User wording, requested deliverable, and named files.
- Current Git branch and changed paths when available.
- `scope`, `updated`, `status`, and `workstream` metadata in thread memories.
- `workstream.md`, `snapshot.md`, and recent event filenames.

Read context is where Codex restores prior decisions, outputs, problems, and next steps. Write target is the current conversation's thread memory. Workstream is only the shared task grouping; it does not replace reading the old thread memory.

High-confidence examples:

- "Continue the PPT images" should read the relevant old PPT/image thread, create a new thread with `continues_from`, and attach it to the recent PPT/image workstream.
- "Audit this change" should create a new audit thread and attach it to the related feature workstream if one exists.
- "Let's discuss the design" should create a design/discussion thread and attach it to the matching feature or deliverable workstream when clear.

Low-confidence behavior:

- If the task is new or unrelated, create a new thread memory and, if useful, a new workstream with a short slug.
- If two matches are similarly plausible, ask one concise clarification instead of dumping every memory file.
- If the user explicitly names a thread file, honor it as read context by default; write to it only if the user clearly asks to reuse or continue writing that exact file.
- If the user explicitly names a workstream id, attach the current thread to that workstream.

## Thread Memory Files

Create thread memory files under `.codex-memory/threads/` with unique names:

```text
YYYY-MM-DD-HHMMSS-<short-task>.md
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
continues_from:
  - <optional prior thread memory path>
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

Use `continues_from` only when the current thread read one or more prior thread memories as direct context. Do not use `workstream` as a substitute for this; `workstream` groups related threads, while `continues_from` records the actual predecessor context.

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

Before creating a workstream, scan existing workstreams and reuse a high-confidence match automatically. If a duplicate is discovered later, mark the duplicate as archived and add `superseded_by` instead of deleting it.

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

1. Update the current conversation's thread memory file under `.codex-memory/threads/`.
2. If the work belongs to a workstream, write a short event file under `.codex-memory/workstreams/<workstream-id>/events/`.
3. Update `snapshot.md` only as a convenience summary. It must remain rebuildable from thread memories and events.

Do not write to thread memories listed in `continues_from`. They are source context for the current conversation, not write targets.

Do not automatically create or update legacy shared status files such as `current-status.md`, `next-actions.md`, `decisions.md`, or `session-log.md`.

Project-level files are optional stable background. Update `.codex-memory/project.md` only when the user explicitly asks to summarize, consolidate, or update project-level memory.

If the current thread memory file changed while this thread was preparing to write, re-read the latest file and append carefully. If a safe append is not possible, create a new sibling thread memory file with a `-fork-<shortid>` suffix and clearly mark which file it forked from.

Thread memories and workstream events are append-only by default. Do not delete or compact them automatically. When the user asks to clean up memory, archive obsolete threads/events under `.codex-memory/archive/` and rebuild any stale `snapshot.md` from the remaining thread memories and events.

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

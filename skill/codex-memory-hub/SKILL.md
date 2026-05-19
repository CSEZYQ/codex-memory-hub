---
name: codex-memory-hub
description: Use when the user creates a project, asks to set up Codex memory, wants context to survive restarted threads, wants per-thread memory for parallel Codex work, asks for Memory Hub, or needs Codex to create, list, reuse, or write thread memory files.
---

# Codex Memory Hub

Use this skill to make Codex work restartable without forcing every thread to maintain shared project status files. The default memory unit is one file per Codex thread.

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
- `docs/wiki/index.md`
- `docs/wiki/project.md`
- `docs/wiki/thread-memory/`

It skips existing files by default. Use `-Force` in PowerShell or `--force` in shell only when the user explicitly wants to overwrite an existing memory scaffold.

## Startup Protocol

When working in a project that has Codex Memory Hub files:

1. Read `AGENTS.md`.
2. Read `docs/wiki/index.md`.
3. Read `docs/wiki/project.md` if it exists.
4. Scan `docs/wiki/thread-memory/*.md`.
5. List every thread memory file for the user, including filename plus any visible `status`, `updated`, and `scope` metadata.
6. Ask the user to choose whether to create a new thread memory file or reuse an existing one.

If no thread memory file exists, create one. If the user explicitly names a thread memory file or says to continue a specific workstream, use that file directly.

For parallel Codex work, create separate thread memory files. Reuse a thread memory file only when continuing the same workstream serially.

## Thread Memory Files

Create thread memory files under `docs/wiki/thread-memory/` with unique names:

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

## Writeback Protocol

At the end of meaningful work, update the selected thread memory file. Record what changed, outputs, decisions, problems, and useful next steps.

Do not automatically update shared project summary files such as `current-status.md`, `next-actions.md`, `decisions.md`, or `session-log.md`. These files are not part of the default model anymore.

Project-level files are optional stable background. Update `docs/wiki/project.md` or create a project summary only when the user explicitly asks to summarize, consolidate, or update project-level memory.

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

---
name: codex-memory-hub
description: Use when the user creates a project, asks to set up Codex memory, wants context to survive restarted threads, asks for Memory Hub, or needs project startup/state files such as current-status, next-actions, decisions, session-log, and ideas.
---

# Codex Memory Hub

Use this skill to make a project restartable across Codex threads. It is cross-platform: Windows, macOS, and Linux should all use the same project memory layout.

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
- `docs/wiki/project-overview.md`
- `docs/wiki/current-status.md`
- `docs/wiki/next-actions.md`
- `docs/wiki/decisions.md`
- `docs/wiki/session-log.md`
- `docs/wiki/ideas.md`
- `docs/wiki/log.md`
- `docs/wiki/inbox/`

It skips existing files by default. Use `-Force` in PowerShell or `--force` in shell only when the user explicitly wants to overwrite an existing memory scaffold.

## Startup Protocol

When working in a project that has memory files, read these before acting on non-trivial work:

1. `AGENTS.md`
2. `docs/wiki/index.md`
3. `docs/wiki/current-status.md`
4. `docs/wiki/next-actions.md`
5. `docs/wiki/decisions.md`
6. `docs/wiki/session-log.md` or `docs/wiki/log.md`

If the user says "continue", "use project memory", "read project memory", or starts a task in a project with these files, use this protocol.

## Concurrent Work Protocol

Multiple Codex threads may read the same project memory, but shared memory files are single-writer by default.

When several threads are working in the same project:

- The coordinator or main thread owns shared memory writeback.
- Worker threads must not edit `AGENTS.md` or shared files such as `docs/wiki/current-status.md`, `docs/wiki/next-actions.md`, `docs/wiki/decisions.md`, `docs/wiki/session-log.md`, `docs/wiki/ideas.md`, or `docs/wiki/log.md`, unless the user explicitly assigns that thread as the memory owner.
- Worker threads should write deliverables to their assigned output directories.
- If a worker thread needs to leave durable context, write a unique handoff note under `docs/wiki/inbox/`, for example `docs/wiki/inbox/2026-05-19-ppt-images-thread-01.md`.
- The coordinator thread later reads those handoff notes and merges the useful facts into the shared memory files.

Do not solve normal parallel work by having every thread rewrite the same memory files. Prefer one shared-memory writer plus many read-only workers with unique handoff files.

## Writeback Protocol

After meaningful work, update memory without waiting for the user to ask:

- Current state: `docs/wiki/current-status.md`
- Next steps: `docs/wiki/next-actions.md`
- Important decisions: `docs/wiki/decisions.md`
- Session summary: `docs/wiki/session-log.md`
- Loose ideas: `docs/wiki/ideas.md`
- Chronological maintenance notes: `docs/wiki/log.md`

Only perform this shared writeback when this thread is the only active thread or is the coordinator/main thread. If this is a worker thread in a parallel task, use the Concurrent Work Protocol instead.

If code changed in a way that future sessions must know about, the task is not complete until the relevant memory files are updated.

Before the final response, do this quick check:

- Did project state change? Update `docs/wiki/current-status.md`.
- Did the next step change? Update `docs/wiki/next-actions.md`.
- Was a durable decision made? Update `docs/wiki/decisions.md`.
- Would a future thread need a summary? Append `docs/wiki/session-log.md`.
- Did the user express a loose idea? Update `docs/wiki/ideas.md`.

Keep writebacks concise. Record durable context, not full chat transcripts.

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

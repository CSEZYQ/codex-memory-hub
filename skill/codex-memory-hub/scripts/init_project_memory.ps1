param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$ProjectName = "",

    [switch]$Force
)

$ErrorActionPreference = "Stop"

if ([System.IO.Path]::IsPathRooted($Path)) {
    $ProjectRoot = [System.IO.Path]::GetFullPath($Path)
} else {
    $ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}
if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    $ProjectName = Split-Path -Leaf $ProjectRoot
}
if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    $ProjectName = "Project"
}

$MemoryRoot = Join-Path $ProjectRoot ".codex-memory"
$ThreadsRoot = Join-Path $MemoryRoot "threads"
$WorkstreamsRoot = Join-Path $MemoryRoot "workstreams"
$ArchiveRoot = Join-Path $MemoryRoot "archive"
$Today = Get-Date -Format "yyyy-MM-dd"

function Write-FileIfNeeded {
    param(
        [string]$FilePath,
        [string]$Content
    )

    $parent = Split-Path -Parent $FilePath
    New-Item -ItemType Directory -Force -Path $parent | Out-Null

    if ((Test-Path -LiteralPath $FilePath) -and -not $Force) {
        Write-Host "skip existing: $FilePath"
        return
    }

    Set-Content -LiteralPath $FilePath -Value $Content -Encoding UTF8
    Write-Host "write: $FilePath"
}

New-Item -ItemType Directory -Force -Path $ThreadsRoot, $WorkstreamsRoot, $ArchiveRoot | Out-Null

$agents = @"
# $ProjectName Agent Rules

This project uses Codex Memory Hub. Keep the project root clean: `AGENTS.md` is the entrypoint and `.codex-memory/` contains all memory data.

## Startup

For non-trivial work:

1. Read `.codex-memory/index.md`.
2. Read `.codex-memory/project.md` if it exists.
3. List every file under `.codex-memory/threads/`.
4. List relevant workstreams under `.codex-memory/workstreams/`.
5. Ask the user whether to create a new thread memory file or reuse an existing one, unless the user already specified the thread or workstream.

If there is no thread memory file, create a new one. If the user explicitly names a thread memory file or a specific workstream, use that file directly.

For parallel Codex work, create separate thread memory files. Reuse an existing thread memory file only when continuing the same workstream serially.

## Thread Memory

Store thread memory under `.codex-memory/threads/` with a unique filename:

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

For related parallel threads, use `.codex-memory/workstreams/<workstream-id>/`.

- `workstream.md` records scope, goal, related files, and active threads.
- `snapshot.md` is a compact rebuildable summary.
- `events/` contains short event files from individual threads.

Prefer unique event files over rewriting one shared live status file.

## Writeback

At the end of meaningful work, update the selected thread memory file.

If the work belongs to a workstream, also write a short event file under `.codex-memory/workstreams/<workstream-id>/events/`.

Do not automatically update legacy shared project status files such as `current-status.md`, `next-actions.md`, `decisions.md`, or `session-log.md`. Project-level files are optional stable background, not live truth.

Only update `.codex-memory/project.md` or create a project-level summary when the user explicitly asks to summarize, consolidate, or update project-level memory.

If the selected thread memory file changed while this thread was preparing to write, re-read it and append carefully. If a safe append is not possible, create a new sibling file with a -fork-<shortid> suffix and mark which file it forked from.
"@

$index = @"
# Codex Memory Index

- [project.md](./project.md)
- [threads/](./threads/)
- [workstreams/](./workstreams/)
- [archive/](./archive/)

Root policy: keep project memory inside `.codex-memory/`; keep only `AGENTS.md` in the project root.
"@

$project = @"
---
title: Project Background
source: project
created: $Today
updated: $Today
status: optional
---

# $ProjectName Project Background

This file is optional stable background. It is not a live status tracker.

## Purpose

- TBD

## Stable Context

- TBD

## Notes

- Thread work logs live in `.codex-memory/threads/`.
- Shared workstream coordination lives in `.codex-memory/workstreams/`.
"@

Write-FileIfNeeded (Join-Path $ProjectRoot "AGENTS.md") $agents
Write-FileIfNeeded (Join-Path $MemoryRoot "index.md") $index
Write-FileIfNeeded (Join-Path $MemoryRoot "project.md") $project
Write-FileIfNeeded (Join-Path $ThreadsRoot ".gitkeep") ""
Write-FileIfNeeded (Join-Path $WorkstreamsRoot ".gitkeep") ""
Write-FileIfNeeded (Join-Path $ArchiveRoot ".gitkeep") ""

Write-Host ""
Write-Host "Codex memory initialized:"
Write-Host "- Project:     $ProjectRoot"
Write-Host "- Entry:       $(Join-Path $ProjectRoot 'AGENTS.md')"
Write-Host "- Memory root: $MemoryRoot"
Write-Host "- Threads:     $ThreadsRoot"
Write-Host "- Workstreams: $WorkstreamsRoot"

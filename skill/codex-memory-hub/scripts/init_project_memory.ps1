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

$WikiRoot = Join-Path (Join-Path $ProjectRoot "docs") "wiki"
$ThreadMemoryRoot = Join-Path $WikiRoot "thread-memory"
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

New-Item -ItemType Directory -Force -Path $ThreadMemoryRoot | Out-Null

$agents = @"
# $ProjectName Agent Rules

This project uses Codex thread memory. Do not rely only on the current chat context, and do not force every thread to maintain shared project status files.

## Startup

For non-trivial work:

1. Read docs/wiki/index.md.
2. Read docs/wiki/project.md if it exists.
3. List every file under docs/wiki/thread-memory/.
4. Ask the user whether to create a new thread memory file or reuse an existing one.

If there is no thread memory file, create a new one. If the user explicitly names a thread memory file or a specific workstream, use that file directly.

For parallel Codex work, create separate thread memory files. Reuse an existing thread memory file only when continuing the same workstream serially.

## Thread Memory

Store thread memory under docs/wiki/thread-memory/ with a unique filename:

YYYY-MM-DD-HHMM-<short-task>.md

Each thread memory file should include:

- thread name
- created time
- updated time
- status: active, done, or archived
- scope
- current context
- timeline
- outputs
- decisions
- problems
- next steps

## Writeback

At the end of meaningful work, update only the selected thread memory file.

Do not automatically update shared project summary files such as current-status.md, next-actions.md, decisions.md, or session-log.md. Project-level files are optional stable background, not live truth.

Only update docs/wiki/project.md or create a project-level summary when the user explicitly asks to summarize, consolidate, or update project-level memory.

If the selected thread memory file changed while this thread was preparing to write, re-read it and append carefully. If a safe append is not possible, create a new sibling file with a -fork-<shortid> suffix and mark which file it forked from.
"@

$index = @"
# Wiki Index

- [project.md](./project.md)
- [thread-memory/](./thread-memory/)
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

- Thread work logs live in docs/wiki/thread-memory/.
"@

Write-FileIfNeeded (Join-Path $ProjectRoot "AGENTS.md") $agents
Write-FileIfNeeded (Join-Path $WikiRoot "index.md") $index
Write-FileIfNeeded (Join-Path $WikiRoot "project.md") $project
Write-FileIfNeeded (Join-Path $ThreadMemoryRoot ".gitkeep") ""

Write-Host ""
Write-Host "Codex thread memory initialized:"
Write-Host "- Project:       $ProjectRoot"
Write-Host "- Entry:         $(Join-Path $ProjectRoot 'AGENTS.md')"
Write-Host "- Wiki:          $WikiRoot"
Write-Host "- Thread memory: $ThreadMemoryRoot"

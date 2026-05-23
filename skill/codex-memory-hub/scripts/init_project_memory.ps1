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
$LegacyWikiRoot = Join-Path (Join-Path $ProjectRoot "docs") "wiki"
$DocsRoot = Join-Path $ProjectRoot "docs"
$Today = Get-Date -Format "yyyy-MM-dd"
$Now = Get-Date -Format "yyyy-MM-dd HH:mm"
$Stamp = Get-Date -Format "yyyy-MM-dd-HHmmss"

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

function Get-UniquePath {
    param([string]$DesiredPath)

    if (-not (Test-Path -LiteralPath $DesiredPath)) {
        return $DesiredPath
    }

    $parent = Split-Path -Parent $DesiredPath
    $leaf = Split-Path -Leaf $DesiredPath
    $base = [System.IO.Path]::GetFileNameWithoutExtension($leaf)
    $ext = [System.IO.Path]::GetExtension($leaf)
    $suffix = [guid]::NewGuid().ToString("N").Substring(0, 8)

    if ([string]::IsNullOrWhiteSpace($ext)) {
        return (Join-Path $parent "$leaf-$suffix")
    }
    return (Join-Path $parent "$base-$suffix$ext")
}

function Ensure-LocalMemoryGitignore {
    $gitDir = Join-Path $ProjectRoot ".git"
    if (-not (Test-Path -LiteralPath $gitDir)) {
        return
    }

    $gitignore = Join-Path $ProjectRoot ".gitignore"
    $entry = ".codex-memory/"

    if (Test-Path -LiteralPath $gitignore) {
        $content = Get-Content -Raw -LiteralPath $gitignore
        if ($content -match "(?m)^\.codex-memory/$") {
            return
        }
        $prefix = if ($content.EndsWith("`n")) { "" } else { "`n" }
        Add-Content -LiteralPath $gitignore -Value "$prefix# Local Codex Memory Hub state`n$entry" -Encoding UTF8
    } else {
        Set-Content -LiteralPath $gitignore -Value "# Local Codex Memory Hub state`n$entry" -Encoding UTF8
    }

    Write-Host "write: $gitignore"
}

function Migrate-LegacyWikiIfNeeded {
    if (-not (Test-Path -LiteralPath $LegacyWikiRoot)) {
        return
    }

    Write-Host "legacy memory detected: $LegacyWikiRoot"

    $legacyProject = Join-Path $LegacyWikiRoot "project.md"
    $projectMemory = Join-Path $MemoryRoot "project.md"
    if ((Test-Path -LiteralPath $legacyProject) -and (-not (Test-Path -LiteralPath $projectMemory))) {
        $legacyProjectContent = Get-Content -Raw -LiteralPath $legacyProject
        $migratedProject = @"
---
title: Project Background
source: legacy-migration
created: $Today
updated: $Today
status: optional
migrated_from: docs/wiki/project.md
---

# $ProjectName Project Background

This file was migrated from the legacy `docs/wiki/project.md` layout.

## Migrated Legacy Project Context

$legacyProjectContent
"@
        Write-FileIfNeeded $projectMemory $migratedProject
    }

    $legacyThreadRoot = Join-Path $LegacyWikiRoot "thread-memory"
    if (Test-Path -LiteralPath $legacyThreadRoot) {
        Get-ChildItem -File -LiteralPath $legacyThreadRoot -Filter "*.md" | ForEach-Object {
            $destination = Get-UniquePath (Join-Path $ThreadsRoot $_.Name)
            Copy-Item -LiteralPath $_.FullName -Destination $destination
            Write-Host "migrate thread: $destination"
        }
    }

    $legacyWorkstream = Join-Path $WorkstreamsRoot "legacy-migration"
    $legacyEvents = Join-Path $legacyWorkstream "events"
    New-Item -ItemType Directory -Force -Path $legacyEvents | Out-Null
    Write-FileIfNeeded (Join-Path $legacyWorkstream "workstream.md") @"
---
workstream: legacy-migration
created: $Today
updated: $Today
status: archived
---

# Legacy Migration

This workstream records automatic migration from the old `docs/wiki/` layout to `.codex-memory/`.
"@
    Write-FileIfNeeded (Join-Path $legacyWorkstream "snapshot.md") @"
---
workstream: legacy-migration
updated: $Now
status: archived
---

# Snapshot

- Migrated legacy `docs/wiki/` memory into `.codex-memory/`.
- Thread memories were copied into `.codex-memory/threads/` when present.
- The original legacy wiki folder was moved into `.codex-memory/archive/`.
"@
    Write-FileIfNeeded (Join-Path $legacyEvents "$Stamp-legacy-docs-wiki-migrated.md") @"
---
event: legacy-docs-wiki-migrated
created: $Now
type: migration
source: init_project_memory.ps1
---

# Legacy docs/wiki Migrated

- Source: `docs/wiki/`
- Active thread memories copied to `.codex-memory/threads/`.
- Original legacy folder moved to `.codex-memory/archive/`.
"@

    $archiveDestination = Get-UniquePath (Join-Path $ArchiveRoot "legacy-docs-wiki")
    Move-Item -LiteralPath $LegacyWikiRoot -Destination $archiveDestination
    Write-Host "archive legacy wiki: $archiveDestination"

    if ((Test-Path -LiteralPath $DocsRoot) -and -not (Get-ChildItem -Force -LiteralPath $DocsRoot)) {
        Remove-Item -LiteralPath $DocsRoot -Force
        Write-Host "remove empty: $DocsRoot"
    }
}

New-Item -ItemType Directory -Force -Path $ThreadsRoot, $WorkstreamsRoot, $ArchiveRoot | Out-Null
Migrate-LegacyWikiIfNeeded

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

If legacy `docs/wiki/` memory exists, migrate it into `.codex-memory/` automatically before normal work. Do not make the user manually reorganize old memory files.

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

Before creating a workstream, list existing workstreams and reuse a matching one. If a duplicate is discovered later, mark the duplicate as archived and add `superseded_by` instead of deleting it.

Prefer unique event files over rewriting one shared live status file.

## Privacy And Git

Do not write secrets, API keys, passwords, access tokens, private credentials, or sensitive raw source material into memory files. Record only the fact that such material exists and where the user-approved source lives.

In Git projects, `.codex-memory/` is local by default and should stay in `.gitignore` unless the user explicitly wants to share memory through the repository.

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
Ensure-LocalMemoryGitignore

Write-Host ""
Write-Host "Codex memory initialized:"
Write-Host "- Project:     $ProjectRoot"
Write-Host "- Entry:       $(Join-Path $ProjectRoot 'AGENTS.md')"
Write-Host "- Memory root: $MemoryRoot"
Write-Host "- Threads:     $ThreadsRoot"
Write-Host "- Workstreams: $WorkstreamsRoot"

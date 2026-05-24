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
$SystemRoot = Join-Path $MemoryRoot "system"
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
        if ($content -match "(?m)^\.codex-memory/\r?$") {
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
        return $false
    }

    Write-Host "legacy memory detected: $LegacyWikiRoot"

    $legacyProject = Join-Path $LegacyWikiRoot "project.md"
    $projectMemory = Join-Path $MemoryRoot "project.md"
    if (Test-Path -LiteralPath $legacyProject) {
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
    else {
        $legacyOverview = Join-Path $LegacyWikiRoot "project-overview.md"
        if (Test-Path -LiteralPath $legacyOverview) {
            $legacyOverviewContent = Get-Content -Raw -LiteralPath $legacyOverview
            $migratedProject = @"
---
title: Project Background
source: legacy-migration
created: $Today
updated: $Today
status: optional
migrated_from: docs/wiki/project-overview.md
---

# $ProjectName Project Background

This file was migrated from the first public `docs/wiki/project-overview.md` layout.

## Migrated Legacy Project Overview

$legacyOverviewContent
"@
            Write-FileIfNeeded $projectMemory $migratedProject
        }
    }

    $legacyProjectPages = @(
        "current-status.md",
        "next-actions.md",
        "decisions.md",
        "session-log.md",
        "ideas.md",
        "log.md"
    )
    $existingLegacyPages = @()
    foreach ($legacyPage in $legacyProjectPages) {
        $legacyPagePath = Join-Path $LegacyWikiRoot $legacyPage
        if (Test-Path -LiteralPath $legacyPagePath) {
            $existingLegacyPages += $legacyPagePath
        }
    }

    if ($existingLegacyPages.Count -gt 0) {
        $legacyThreadPath = Get-UniquePath (Join-Path $ThreadsRoot "$Stamp-legacy-project-memory.md")
        $legacyThread = @"
---
thread: legacy-project-memory
created: $Now
updated: $Now
status: active
scope: Migrated first public Codex Memory Hub project memory from docs/wiki status pages.
workstream: legacy-migration
migrated_from: docs/wiki
---

# Legacy Project Memory

This thread memory was created automatically from the first public Codex Memory Hub project-memory layout.

## Current Context

- Legacy project memory existed under `docs/wiki/`.
- The source files were preserved under `.codex-memory/archive/`.
- The content below was copied into active thread memory so future Codex threads can continue without manual cleanup.

## Timeline

- $Now - Migrated legacy project-memory pages into this thread memory.

"@
        foreach ($legacyPagePath in $existingLegacyPages) {
            $legacyName = Split-Path -Leaf $legacyPagePath
            $legacyContent = Get-Content -Raw -LiteralPath $legacyPagePath
            $legacyThread += @"
## Migrated $legacyName

$legacyContent

"@
        }
        $legacyThread += @"
## Next

- Continue from the migrated context above.
- Use `.codex-memory/threads/` and `.codex-memory/workstreams/` for new memory.
"@
        Set-Content -LiteralPath $legacyThreadPath -Value $legacyThread -Encoding UTF8
        Write-Host "migrate legacy project pages: $legacyThreadPath"
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

    return $true
}

New-Item -ItemType Directory -Force -Path $ThreadsRoot, $WorkstreamsRoot, $ArchiveRoot, $SystemRoot | Out-Null
$MigratedLegacyWiki = Migrate-LegacyWikiIfNeeded

$agents = @"
# $ProjectName Agent Rules

This project uses Codex Memory Hub. Keep the project root clean: `AGENTS.md` is the entrypoint and `.codex-memory/` contains all memory data.

## Startup

For non-trivial work:

1. Read `.codex-memory/index.md`.
2. Read `.codex-memory/project.md` if it exists.
3. Read `.codex-memory/system/thread-index.json` and `.codex-memory/system/workstream-index.json` if they exist.
4. Use the indexes as a quick map before opening full memory files.
5. Scan `.codex-memory/threads/` and `.codex-memory/workstreams/` only as needed for relevant thread memories, workstreams, and snapshots.
6. Infer read context and write target separately from the user request, current directory, changed files, Git branch when available, thread metadata, workstream scope, and recent snapshots.
7. Continue with the inferred targets without asking when confidence is high.

If legacy `docs/wiki/` memory exists, migrate it into `.codex-memory/` automatically before normal work. Do not make the user manually reorganize old memory files.

When the Codex Memory Hub skill is available, use its bundled `memory_tools.ps1` or `memory_tools.sh` for deterministic maintenance:

- `doctor` checks structure, broken `continues_from` links, missing or orphaned workstreams, invalid workstream snapshots/events, Git privacy defaults, and possible secrets.
- `index` refreshes `.codex-memory/system/thread-index.json` and `.codex-memory/system/workstream-index.json`.

If there is no thread memory file, create a new one. If no existing memory clearly matches the task, create a new thread memory file and, when useful, a new workstream.

For every new Codex conversation, create a new thread memory file by default. Existing thread memory files are read-only context by default, even when the user says to continue previous work. If the new conversation continues previous work, read the relevant old thread memories and record them in the new thread's `continues_from` metadata. Link the new thread to the matching workstream when one exists.

Write to an existing thread memory only when the user explicitly names that thread file and clearly asks to reuse or continue writing that exact file.

Ask the user only when several memories match equally well, memories conflict in a way that affects the work, `.codex-memory/` may be shared through Git, or a destructive memory action is involved.

## Thread Memory

Store thread memory under `.codex-memory/threads/` with a unique filename:

YYYY-MM-DD-HHMMSS-<short-task>.md

Each thread memory file should include:

- thread name
- created time
- updated time
- status: active, done, or archived
- scope
- optional workstream id
- optional continues_from list for prior thread memories used as direct context
- current context
- timeline
- outputs
- decisions
- problems
- next steps

## Workstreams

For related parallel threads, use `.codex-memory/workstreams/<workstream-id>/`. Workstreams are internal coordination; the user does not need to name one.

Workstreams group related threads. They do not replace reading the old thread memory; use `continues_from` on the new thread to record actual predecessor context.

- `workstream.md` records scope, goal, related files, and active threads.
- `snapshot.md` is a compact rebuildable summary.
- `events/` contains short event files from individual threads.

Before creating a workstream, scan existing workstreams and automatically reuse a high-confidence match. If a duplicate is discovered later, mark the duplicate as archived and add `superseded_by` instead of deleting it.

Prefer unique event files over rewriting one shared live status file.

## Privacy And Git

Do not write secrets, API keys, passwords, access tokens, private credentials, or sensitive raw source material into memory files. Record only the fact that such material exists and where the user-approved source lives.

In Git projects, `.codex-memory/` is local by default and should stay in `.gitignore` unless the user explicitly wants to share memory through the repository.

## Writeback

At the end of meaningful work, update the current conversation's thread memory file.

If the work belongs to a workstream, also write a short event file under `.codex-memory/workstreams/<workstream-id>/events/`.

Do not write to thread memories listed in `continues_from`. They are source context for the current conversation, not write targets.

Do not automatically update legacy shared project status files such as `current-status.md`, `next-actions.md`, `decisions.md`, or `session-log.md`. Project-level files are optional stable background, not live truth.

Only update `.codex-memory/project.md` or create a project-level summary when the user explicitly asks to summarize, consolidate, or update project-level memory.

If the current thread memory file changed while this thread was preparing to write, re-read it and append carefully. If a safe append is not possible, create a new sibling file with a -fork-<shortid> suffix and mark which file it forked from.
"@

$index = @"
# Codex Memory Index

- [project.md](./project.md)
- [threads/](./threads/)
- [workstreams/](./workstreams/)
- [archive/](./archive/)
- [system/](./system/)

Root policy: keep project memory inside `.codex-memory/`; keep only `AGENTS.md` in the project root.
Maintenance policy: generated indexes live under `.codex-memory/system/`.
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
$projectMemoryPath = Join-Path $MemoryRoot "project.md"
if ($MigratedLegacyWiki -and (Test-Path -LiteralPath $projectMemoryPath)) {
    Write-Host "preserve migrated project memory: $projectMemoryPath"
} else {
    Write-FileIfNeeded $projectMemoryPath $project
}
Ensure-LocalMemoryGitignore

Write-Host ""
Write-Host "Codex memory initialized:"
Write-Host "- Project:     $ProjectRoot"
Write-Host "- Entry:       $(Join-Path $ProjectRoot 'AGENTS.md')"
Write-Host "- Memory root: $MemoryRoot"
Write-Host "- Threads:     $ThreadsRoot"
Write-Host "- Workstreams: $WorkstreamsRoot"
Write-Host "- System:      $SystemRoot"

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
$InboxRoot = Join-Path $WikiRoot "inbox"
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

New-Item -ItemType Directory -Force -Path $InboxRoot | Out-Null

$agents = @"
# $ProjectName Agent Rules

This project uses Codex project memory. Do not rely only on the current chat context.

## Startup

For non-trivial work, read these files before acting:

1. `docs/wiki/index.md`
2. `docs/wiki/current-status.md`
3. `docs/wiki/next-actions.md`
4. `docs/wiki/decisions.md`
5. `docs/wiki/session-log.md`

If a file is empty or incomplete, update it as the project becomes clearer.

## Writeback

After meaningful work, update project memory without waiting for the user to ask:

- Current state: `docs/wiki/current-status.md`
- Next steps: `docs/wiki/next-actions.md`
- Decisions: `docs/wiki/decisions.md`
- Session summary: `docs/wiki/session-log.md`
- Loose ideas: `docs/wiki/ideas.md`

Code changes without memory writeback are incomplete when the work affects future context.

Before the final response, check whether this turn changed project state, decisions, next steps, risks, or ideas. If yes, update the relevant memory files first, then answer the user.

Keep writebacks short and durable. Do not paste full chat transcripts.

## Concurrent Work

If multiple Codex threads work in this project at the same time, shared memory files are single-writer.

- The coordinator or main thread updates docs/wiki/current-status.md, docs/wiki/next-actions.md, docs/wiki/decisions.md, docs/wiki/session-log.md, docs/wiki/ideas.md, and docs/wiki/log.md.
- Worker threads do not edit AGENTS.md or shared docs/wiki files unless the user explicitly assigns memory ownership to that thread.
- Worker threads write deliverables to their assigned output directories.
- If a worker thread needs to leave durable context, write a unique handoff note under docs/wiki/inbox/.
- The coordinator thread later merges useful handoff notes into the shared memory files.

## Memory Layers

- raw: original source material
- wiki: compiled project knowledge
- state: current status, decisions, next actions, session log
- code: implementation
"@

$index = @"
# Wiki Index

- [project-overview.md](./project-overview.md)
- [current-status.md](./current-status.md)
- [next-actions.md](./next-actions.md)
- [decisions.md](./decisions.md)
- [session-log.md](./session-log.md)
- [ideas.md](./ideas.md)
- [log.md](./log.md)
- [inbox/](./inbox/)
"@

$overview = @"
---
title: Project Overview
source: session
created: $Today
tags: [overview]
status: draft
---

# $ProjectName Project Overview

Purpose:

- TBD

Users / audience:

- TBD

Core workflows:

- TBD
"@

$current = @"
---
title: Current Status
source: session
created: $Today
tags: [status]
status: current
---

# Current Status

## Working State

- Project memory initialized on $Today.

## Known Risks

- TBD
"@

$next = @"
---
title: Next Actions
source: session
created: $Today
tags: [next-actions]
status: current
---

# Next Actions

- Define the project goal.
- Record the current implementation state.
- Add the first real next step after the next Codex session.
"@

$decisions = @"
---
title: Decisions
source: session
created: $Today
tags: [decisions]
status: current
---

# Decisions

## $Today

- Initialized Codex project memory for $ProjectName.
"@

$session = @"
---
title: Session Log
source: session
created: $Today
tags: [session-log]
status: current
---

# Session Log

## $Today | Memory Initialized

- Created project memory files for $ProjectName.
- Future Codex sessions should read `AGENTS.md` and `docs/wiki/index.md` first.
"@

$ideas = @"
---
title: Ideas
source: session
created: $Today
tags: [ideas]
status: current
---

# Ideas

## Inbox

- TBD
"@

$log = @"
# Log

## $Today | Memory Initialized

- Added Codex project memory structure.
"@

Write-FileIfNeeded (Join-Path $ProjectRoot "AGENTS.md") $agents
Write-FileIfNeeded (Join-Path $WikiRoot "index.md") $index
Write-FileIfNeeded (Join-Path $WikiRoot "project-overview.md") $overview
Write-FileIfNeeded (Join-Path $WikiRoot "current-status.md") $current
Write-FileIfNeeded (Join-Path $WikiRoot "next-actions.md") $next
Write-FileIfNeeded (Join-Path $WikiRoot "decisions.md") $decisions
Write-FileIfNeeded (Join-Path $WikiRoot "session-log.md") $session
Write-FileIfNeeded (Join-Path $WikiRoot "ideas.md") $ideas
Write-FileIfNeeded (Join-Path $WikiRoot "log.md") $log
Write-FileIfNeeded (Join-Path $InboxRoot ".gitkeep") ""

Write-Host ""
Write-Host "Codex memory initialized:"
Write-Host "- Project: $ProjectRoot"
Write-Host "- Entry:   $(Join-Path $ProjectRoot 'AGENTS.md')"
Write-Host "- Wiki:    $WikiRoot"

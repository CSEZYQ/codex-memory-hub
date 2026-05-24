param()

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$PsInit = Join-Path $RepoRoot "skill/codex-memory-hub/scripts/init_project_memory.ps1"
$PsMemoryTools = Join-Path $RepoRoot "skill/codex-memory-hub/scripts/memory_tools.ps1"
$ReadmePath = Join-Path $RepoRoot "README.md"
$ShellMemoryTools = Join-Path $RepoRoot "skill/codex-memory-hub/scripts/memory_tools.sh"
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-memory-hub-tests-" + [guid]::NewGuid().ToString("N"))
$bashCommand = Get-Command bash -ErrorAction SilentlyContinue

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Invoke-InitPowerShell {
    param(
        [string]$ProjectPath,
        [switch]$Force
    )

    $args = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $PsInit,
        "-Path",
        $ProjectPath
    )

    if ($Force) {
        $args += "-Force"
    }

    & powershell @args | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "PowerShell initializer failed for $ProjectPath"
    }
}

function Invoke-MemoryToolsPowerShell {
    param(
        [string]$ProjectPath,
        [string]$Command
    )

    $args = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $PsMemoryTools,
        "-Path",
        $ProjectPath,
        "-Command",
        $Command
    )

    $output = & powershell @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Memory tools command '$Command' failed for $ProjectPath`n$output"
    }
    return ($output -join "`n")
}

function Convert-ToBashPath {
    param([string]$InputPath)

    $fullPath = [System.IO.Path]::GetFullPath($InputPath) -replace "\\", "/"
    if ($fullPath -match "^([A-Za-z]):/(.*)$") {
        return "/mnt/$($matches[1].ToLowerInvariant())/$($matches[2])"
    }
    return $fullPath
}

try {
    New-Item -ItemType Directory -Path $TempRoot | Out-Null

    $readme = Get-Content -Raw -LiteralPath $ReadmePath
    $shellMaintenanceScript = Get-Content -Raw -LiteralPath $ShellMemoryTools
    Assert-True ($readme -match "-Command doctor") "README should show the real PowerShell doctor command"
    Assert-True ($readme -match "-Command index") "README should show the real PowerShell index command"
    Assert-True ($readme -notmatch "(?m)^memory_tools\.ps1 doctor$") "README should not imply that doctor is the first positional PowerShell argument"
    Assert-True ($readme -match "2026-05-24-090000-ppt-images\.md") "README continuation example should use second-precision thread filenames"
    Assert-True ($readme -notmatch "2026-05-24-0900-ppt-images\.md") "README should not keep minute-precision thread filename examples"
    Assert-True ($readme -match "导入|安装") "README should tell GitHub users to import or install the plugin first"
    Assert-True ($shellMaintenanceScript -notmatch "-mindepth|-maxdepth") "shell maintenance script should not use GNU-only find options"

    $cleanProject = Join-Path $TempRoot "clean"
    New-Item -ItemType Directory -Path $cleanProject | Out-Null
    git -C $cleanProject init | Out-Null
    Invoke-InitPowerShell $cleanProject

    Assert-True (Test-Path -LiteralPath (Join-Path $cleanProject "AGENTS.md")) "clean init did not create AGENTS.md"
    Assert-True (Test-Path -LiteralPath (Join-Path $cleanProject ".codex-memory/threads")) "clean init did not create threads directory"
    Assert-True (Test-Path -LiteralPath (Join-Path $cleanProject ".codex-memory/system")) "clean init did not create system directory"
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $cleanProject ".codex-memory/threads/.gitkeep"))) "clean init should not create ignored .gitkeep files"
    Assert-True ((Get-Content -Raw -LiteralPath (Join-Path $cleanProject ".gitignore")) -match "(?m)^\.codex-memory/\r?$") "clean init did not gitignore .codex-memory/"
    $cleanAgents = Get-Content -Raw -LiteralPath (Join-Path $cleanProject "AGENTS.md")
    Assert-True ($cleanAgents.IndexOf(".codex-memory/system/thread-index.json") -lt $cleanAgents.IndexOf("Scan .codex-memory/threads/")) "generated AGENTS.md should read system index before scanning threads"

    Invoke-MemoryToolsPowerShell $cleanProject "index" | Out-Null
    $threadIndexPath = Join-Path $cleanProject ".codex-memory/system/thread-index.json"
    $workstreamIndexPath = Join-Path $cleanProject ".codex-memory/system/workstream-index.json"
    Assert-True (Test-Path -LiteralPath $threadIndexPath) "index command did not create thread-index.json"
    Assert-True (Test-Path -LiteralPath $workstreamIndexPath) "index command did not create workstream-index.json"
    $threadIndex = Get-Content -Raw -LiteralPath $threadIndexPath | ConvertFrom-Json
    Assert-True ($threadIndex.threads.Count -eq 0) "clean thread index should contain no threads"

    $indexedProject = Join-Path $TempRoot "indexed"
    New-Item -ItemType Directory -Path $indexedProject | Out-Null
    Invoke-InitPowerShell $indexedProject
    $threadsPath = Join-Path $indexedProject ".codex-memory/threads"
    $oldThreadPath = Join-Path $threadsPath "2026-05-24-100000-ppt-images.md"
    $newThreadPath = Join-Path $threadsPath "2026-05-24-110000-continue-ppt-images.md"
    Set-Content -LiteralPath $oldThreadPath -Encoding UTF8 -Value @"
---
thread: ppt-images
created: 2026-05-24 10:00
updated: 2026-05-24 10:30
status: done
scope: Generate PPT images.
workstream: ppt-images
---

# PPT Images
"@
    Set-Content -LiteralPath $newThreadPath -Encoding UTF8 -Value @"
---
thread: continue-ppt-images
created: 2026-05-24 11:00
updated: 2026-05-24 11:20
status: active
scope: Continue PPT images.
workstream: ppt-images
continues_from:
  - .codex-memory/threads/2026-05-24-100000-ppt-images.md
---

# Continue PPT Images
"@
    New-Item -ItemType Directory -Path (Join-Path $indexedProject ".codex-memory/workstreams/ppt-images/events") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $indexedProject ".codex-memory/workstreams/ppt-images/workstream.md") -Encoding UTF8 -Value @"
---
workstream: ppt-images
created: 2026-05-24
updated: 2026-05-24
status: active
---

# PPT Images
"@
    Set-Content -LiteralPath (Join-Path $indexedProject ".codex-memory/workstreams/ppt-images/events/2026-05-24-112000-continue-ppt-images-progress.md") -Encoding UTF8 -Value @"
---
event: continue-ppt-images-progress
created: 2026-05-24 11:20
type: progress
thread: .codex-memory/threads/2026-05-24-110000-continue-ppt-images.md
---

# Progress
"@
    Invoke-MemoryToolsPowerShell $indexedProject "index" | Out-Null
    $indexedThreadRaw = Get-Content -Raw -LiteralPath (Join-Path $indexedProject ".codex-memory/system/thread-index.json")
    $indexedWorkstreamRaw = Get-Content -Raw -LiteralPath (Join-Path $indexedProject ".codex-memory/system/workstream-index.json")
    Assert-True ($indexedThreadRaw -notmatch '"project_root"') "thread index should not store absolute project_root paths"
    Assert-True ($indexedThreadRaw -notmatch [regex]::Escape($indexedProject)) "thread index should not leak the absolute project path"
    Assert-True ($indexedWorkstreamRaw -notmatch '"project_root"') "workstream index should not store absolute project_root paths"
    Assert-True ($indexedWorkstreamRaw -notmatch [regex]::Escape($indexedProject)) "workstream index should not leak the absolute project path"
    $indexedThreads = Get-Content -Raw -LiteralPath (Join-Path $indexedProject ".codex-memory/system/thread-index.json") | ConvertFrom-Json
    Assert-True ($indexedThreads.threads.Count -eq 2) "thread index should include both thread memories"
    Assert-True (($indexedThreads.threads | Where-Object { $_.name -eq "2026-05-24-110000-continue-ppt-images.md" }).continues_from.Count -eq 1) "thread index should preserve continues_from metadata"
    $indexedWorkstreams = Get-Content -Raw -LiteralPath (Join-Path $indexedProject ".codex-memory/system/workstream-index.json") | ConvertFrom-Json
    Assert-True ($indexedWorkstreams.workstreams.Count -eq 1) "workstream index should include one workstream"
    Assert-True ($indexedWorkstreams.workstreams[0].event_count -eq 1) "workstream index should count event files"

    $doctorOutput = Invoke-MemoryToolsPowerShell $indexedProject "doctor"
    Assert-True ($doctorOutput -match "No errors found") "doctor should report no errors for indexed sample project"

    if ($bashCommand) {
        $shellParityProject = Join-Path $RepoRoot ".codex-memory-hub-shell-parity"
        if (Test-Path -LiteralPath $shellParityProject) {
            Remove-Item -LiteralPath $shellParityProject -Recurse -Force
        }
        try {
        New-Item -ItemType Directory -Path $shellParityProject | Out-Null
        Invoke-InitPowerShell $shellParityProject
        New-Item -ItemType Directory -Path (Join-Path $shellParityProject ".codex-memory/workstreams/audit-stream/events") -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $shellParityProject ".codex-memory/threads/2026-05-24-130000-shell-json.md") -Encoding UTF8 -Value @"
---
thread: shell-json
created: 2026-05-24 13:00
updated: 2026-05-24 13:05
status: active
scope: |
  First line with "quotes"
  Note: colon line should stay inside scope
  Second line with \backslash
workstream: audit-stream
---

# Shell JSON
"@
        Set-Content -LiteralPath (Join-Path $shellParityProject ".codex-memory/workstreams/audit-stream/workstream.md") -Encoding UTF8 -Value @"
---
workstream: audit-stream
created: 2026-05-24
updated: 2026-05-24
status: active
---

# Audit Stream
"@
        Invoke-MemoryToolsPowerShell $shellParityProject "index" | Out-Null
        $psThreadIndex = Get-Content -Raw -LiteralPath (Join-Path $shellParityProject ".codex-memory/system/thread-index.json") | ConvertFrom-Json
        $psWorkstreamIndex = Get-Content -Raw -LiteralPath (Join-Path $shellParityProject ".codex-memory/system/workstream-index.json") | ConvertFrom-Json
        Push-Location $RepoRoot
        try {
            bash -c "sh skill/codex-memory-hub/scripts/memory_tools.sh --path .codex-memory-hub-shell-parity index >/dev/null"
            if ($LASTEXITCODE -ne 0) {
                throw "shell index failed for schema parity project"
            }
        } finally {
            Pop-Location
        }
        $shellThreadIndexRaw = Get-Content -Raw -LiteralPath (Join-Path $shellParityProject ".codex-memory/system/thread-index.json")
        Assert-True ($shellThreadIndexRaw -match 'First line with \\"quotes\\"\\nNote: colon line should stay inside scope\\nSecond line with \\\\backslash') "shell index should escape quotes, newlines, and backslashes in JSON strings"
        $shellThreadIndex = $shellThreadIndexRaw | ConvertFrom-Json
        $shellWorkstreamIndex = Get-Content -Raw -LiteralPath (Join-Path $shellParityProject ".codex-memory/system/workstream-index.json") | ConvertFrom-Json
        $expectedScope = "First line with `"quotes`"`nNote: colon line should stay inside scope`nSecond line with \backslash"
        Assert-True ($psThreadIndex.threads[0].scope -eq $expectedScope) "PowerShell index should parse literal block scalar scope"
        Assert-True ($shellThreadIndex.threads[0].scope -eq $expectedScope) "shell index should parse literal block scalar scope"
        $psThreadProps = @($psThreadIndex.threads[0].PSObject.Properties.Name | Sort-Object)
        $shellThreadProps = @($shellThreadIndex.threads[0].PSObject.Properties.Name | Sort-Object)
        $psWorkstreamProps = @($psWorkstreamIndex.workstreams[0].PSObject.Properties.Name | Sort-Object)
        $shellWorkstreamProps = @($shellWorkstreamIndex.workstreams[0].PSObject.Properties.Name | Sort-Object)
        Assert-True (($psThreadProps -join "|") -eq ($shellThreadProps -join "|")) "shell thread index schema should match PowerShell thread index schema"
        Assert-True (($psWorkstreamProps -join "|") -eq ($shellWorkstreamProps -join "|")) "shell workstream index schema should match PowerShell workstream index schema"
        Assert-True ($shellThreadIndex.active_count -eq $psThreadIndex.active_count) "shell thread index should include active_count"
        Assert-True ($shellWorkstreamIndex.workstreams[0].snapshot_exists -eq $psWorkstreamIndex.workstreams[0].snapshot_exists) "shell workstream index should include snapshot_exists"

        $olderNameLaterMtime = Join-Path $shellParityProject ".codex-memory/workstreams/audit-stream/events/2026-05-24-120000-older-name.md"
        $newerNameEarlierMtime = Join-Path $shellParityProject ".codex-memory/workstreams/audit-stream/events/2026-05-24-140000-newer-name.md"
        Set-Content -LiteralPath $newerNameEarlierMtime -Encoding UTF8 -Value "newer name, earlier mtime"
        Start-Sleep -Milliseconds 1100
        Set-Content -LiteralPath $olderNameLaterMtime -Encoding UTF8 -Value "older name, later mtime"
        Invoke-MemoryToolsPowerShell $shellParityProject "index" | Out-Null
        $psLatestByName = (Get-Content -Raw -LiteralPath (Join-Path $shellParityProject ".codex-memory/system/workstream-index.json") | ConvertFrom-Json).workstreams[0].latest_event
        Push-Location $RepoRoot
        try {
            bash -c "sh skill/codex-memory-hub/scripts/memory_tools.sh --path .codex-memory-hub-shell-parity index >/dev/null"
            if ($LASTEXITCODE -ne 0) {
                throw "shell index failed for latest-event parity project"
            }
        } finally {
            Pop-Location
        }
        $shellLatestByName = (Get-Content -Raw -LiteralPath (Join-Path $shellParityProject ".codex-memory/system/workstream-index.json") | ConvertFrom-Json).workstreams[0].latest_event
        Assert-True ($psLatestByName -eq ".codex-memory/workstreams/audit-stream/events/2026-05-24-140000-newer-name.md") "PowerShell latest_event should follow event filename order"
        Assert-True ($shellLatestByName -eq $psLatestByName) "shell latest_event should match PowerShell latest_event"
        } finally {
            if (Test-Path -LiteralPath $shellParityProject) {
                Remove-Item -LiteralPath $shellParityProject -Recurse -Force
            }
        }
    } else {
        Write-Host "skip shell parity tests: bash not found"
    }

    $brokenProject = Join-Path $TempRoot "broken"
    New-Item -ItemType Directory -Path $brokenProject | Out-Null
    Invoke-InitPowerShell $brokenProject
    Set-Content -LiteralPath (Join-Path $brokenProject ".codex-memory/threads/2026-05-24-120000-broken.md") -Encoding UTF8 -Value @"
---
thread: broken
created: 2026-05-24 12:00
updated: 2026-05-24 12:10
status: active
scope: Broken continuation.
workstream: missing-workstream
continues_from:
  - .codex-memory/threads/missing.md
---

# Broken

leaked token: ghp_1234567890abcdefghijklmnopqrstu

This body text mentions workstream: orphan-workstream but frontmatter does not reference it.
"@
    New-Item -ItemType Directory -Path (Join-Path $brokenProject ".codex-memory/workstreams/orphan-workstream") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $brokenProject ".codex-memory/workstreams/missing-file") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $brokenProject ".codex-memory/workstreams/mismatch/events") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $brokenProject ".codex-memory/workstreams/stale-stream/events") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $brokenProject ".codex-memory/workstreams/snapshot-no-updated/events") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $brokenProject ".codex-memory/workstreams/nonstandard-event/events") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $brokenProject ".codex-memory/threads/2026-05-24-121000-missing-workstream-file.md") -Encoding UTF8 -Value @"
---
thread: missing-workstream-file
created: 2026-05-24 12:10
updated: 2026-05-24 12:10
status: active
scope: References a workstream directory without workstream.md.
workstream: missing-file
---

# Missing Workstream File
"@
    Set-Content -LiteralPath (Join-Path $brokenProject ".codex-memory/threads/2026-05-24-122000-mismatched-workstream.md") -Encoding UTF8 -Value @"
---
thread: mismatched-workstream
created: 2026-05-24 12:20
updated: 2026-05-24 12:20
status: active
scope: References a workstream with mismatched metadata.
workstream: mismatch
---

# Mismatched Workstream
"@
    Set-Content -LiteralPath (Join-Path $brokenProject ".codex-memory/threads/2026-05-24-123000-stale-snapshot.md") -Encoding UTF8 -Value @"
---
thread: stale-snapshot
created: 2026-05-24 12:30
updated: 2026-05-24 12:30
status: active
scope: References a stale workstream snapshot.
workstream: stale-stream
---

# Stale Snapshot
"@
    Set-Content -LiteralPath (Join-Path $brokenProject ".codex-memory/workstreams/orphan-workstream/workstream.md") -Encoding UTF8 -Value @"
---
workstream: orphan-workstream
created: 2026-05-24
updated: 2026-05-24
status: active
---

# Orphan Workstream
"@
    Set-Content -LiteralPath (Join-Path $brokenProject ".codex-memory/workstreams/mismatch/workstream.md") -Encoding UTF8 -Value @"
---
workstream: other-workstream-id
created: 2026-05-24
updated: 2026-05-24
status: active
---

# Mismatch
"@
    $staleSnapshotPath = Join-Path $brokenProject ".codex-memory/workstreams/stale-stream/snapshot.md"
    $staleEventPath = Join-Path $brokenProject ".codex-memory/workstreams/stale-stream/events/2026-05-24-130000-later-event.md"
    Set-Content -LiteralPath (Join-Path $brokenProject ".codex-memory/workstreams/stale-stream/workstream.md") -Encoding UTF8 -Value @"
---
workstream: stale-stream
created: 2026-05-24
updated: 2026-05-24
status: active
---

# Stale Stream
"@
    Set-Content -LiteralPath $staleSnapshotPath -Encoding UTF8 -Value @"
---
workstream: stale-stream
updated: 2026-05-24 12:00
status: active
---

# Snapshot
"@
    Set-Content -LiteralPath $staleEventPath -Encoding UTF8 -Value "later event"
    (Get-Item -LiteralPath $staleSnapshotPath).LastWriteTime = Get-Date "2026-05-24 14:00"
    (Get-Item -LiteralPath $staleEventPath).LastWriteTime = Get-Date "2026-05-24 11:00"
    Set-Content -LiteralPath (Join-Path $brokenProject ".codex-memory/workstreams/snapshot-no-updated/workstream.md") -Encoding UTF8 -Value @"
---
workstream: snapshot-no-updated
created: 2026-05-24
updated: 2026-05-24
status: active
---

# Snapshot No Updated
"@
    Set-Content -LiteralPath (Join-Path $brokenProject ".codex-memory/workstreams/snapshot-no-updated/snapshot.md") -Encoding UTF8 -Value @"
---
workstream: snapshot-no-updated
status: active
---

# Snapshot Without Updated
"@
    Set-Content -LiteralPath (Join-Path $brokenProject ".codex-memory/workstreams/snapshot-no-updated/events/2026-05-24-131000-later-event.md") -Encoding UTF8 -Value "later event"
    Set-Content -LiteralPath (Join-Path $brokenProject ".codex-memory/workstreams/nonstandard-event/workstream.md") -Encoding UTF8 -Value @"
---
workstream: nonstandard-event
created: 2026-05-24
updated: 2026-05-24
status: active
---

# Nonstandard Event
"@
    Set-Content -LiteralPath (Join-Path $brokenProject ".codex-memory/workstreams/nonstandard-event/snapshot.md") -Encoding UTF8 -Value @"
---
workstream: nonstandard-event
updated: 2026-05-24 12:00
status: active
---

# Snapshot
"@
    Set-Content -LiteralPath (Join-Path $brokenProject ".codex-memory/workstreams/nonstandard-event/events/later-event.md") -Encoding UTF8 -Value "event without sortable timestamp"
    $brokenDoctorOutput = Invoke-MemoryToolsPowerShell $brokenProject "doctor"
    Assert-True ($brokenDoctorOutput -match "Threads: 4") "doctor should count direct thread files correctly"
    Assert-True ($brokenDoctorOutput -match "BROKEN_CONTINUES_FROM") "doctor should warn about missing continues_from target"
    Assert-True ($brokenDoctorOutput -match "BROKEN_WORKSTREAM_REFERENCE") "doctor should warn about missing thread workstream targets"
    Assert-True ($brokenDoctorOutput -match "WORKSTREAM_ORPHANED") "doctor should warn about active workstreams with no thread references"
    Assert-True ($brokenDoctorOutput -match "WORKSTREAM_FILE_MISSING") "doctor should warn about workstream directories missing workstream.md"
    Assert-True ($brokenDoctorOutput -match "WORKSTREAM_ID_MISMATCH") "doctor should warn when workstream frontmatter id differs from the directory id"
    Assert-True ($brokenDoctorOutput -match "WORKSTREAM_SNAPSHOT_STALE") "doctor should compare snapshot freshness by event timestamp, not filesystem mtime"
    Assert-True ($brokenDoctorOutput -match "WORKSTREAM_SNAPSHOT_METADATA_MISSING") "doctor should warn when snapshot.md has events but no usable updated timestamp"
    Assert-True ($brokenDoctorOutput -match "WORKSTREAM_EVENT_FILENAME_NON_STANDARD") "doctor should warn when workstream event filenames cannot be timestamped"
    Assert-True ($brokenDoctorOutput -match "POSSIBLE_SECRET") "doctor should warn about common hosted-service token patterns"
    Invoke-MemoryToolsPowerShell $brokenProject "index" | Out-Null
    $brokenWorkstreamIndex = Get-Content -Raw -LiteralPath (Join-Path $brokenProject ".codex-memory/system/workstream-index.json") | ConvertFrom-Json
    $missingWorkstreamRecord = @($brokenWorkstreamIndex.workstreams | Where-Object { $_.id -eq "missing-file" })[0]
    Assert-True ($missingWorkstreamRecord.workstream -eq "missing-file") "PowerShell workstream index should fall back to directory id when workstream.md is missing"

    $legacyFilenameProject = Join-Path $TempRoot "legacy-filenames"
    New-Item -ItemType Directory -Path $legacyFilenameProject | Out-Null
    Invoke-InitPowerShell $legacyFilenameProject
    New-Item -ItemType Directory -Path (Join-Path $legacyFilenameProject ".codex-memory/workstreams/legacy-minute/events") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $legacyFilenameProject ".codex-memory/threads/2026-05-24-1240-legacy-minute.md") -Encoding UTF8 -Value @"
---
thread: legacy-minute
created: 2026-05-24 12:40
updated: 2026-05-24 12:40
status: active
scope: Legacy minute-precision filename.
workstream: legacy-minute
---

# Legacy Minute Thread
"@
    Set-Content -LiteralPath (Join-Path $legacyFilenameProject ".codex-memory/workstreams/legacy-minute/workstream.md") -Encoding UTF8 -Value @"
---
workstream: legacy-minute
created: 2026-05-24
updated: 2026-05-24
status: active
---

# Legacy Minute Workstream
"@
    Set-Content -LiteralPath (Join-Path $legacyFilenameProject ".codex-memory/workstreams/legacy-minute/snapshot.md") -Encoding UTF8 -Value @"
---
workstream: legacy-minute
updated: 2026-05-24 12:41
status: active
---

# Snapshot
"@
    Set-Content -LiteralPath (Join-Path $legacyFilenameProject ".codex-memory/workstreams/legacy-minute/events/2026-05-24-1240-legacy-minute-event.md") -Encoding UTF8 -Value "legacy event"
    $legacyFilenameDoctorOutput = Invoke-MemoryToolsPowerShell $legacyFilenameProject "doctor"
    Assert-True ($legacyFilenameDoctorOutput -notmatch "NON_STANDARD_THREAD_FILENAME") "PowerShell doctor should accept legacy minute-precision thread filenames"
    Assert-True ($legacyFilenameDoctorOutput -notmatch "WORKSTREAM_EVENT_FILENAME_NON_STANDARD") "PowerShell doctor should accept legacy minute-precision event filenames"

    $missingSnapshotEventProject = Join-Path $TempRoot "missing-snapshot-event"
    New-Item -ItemType Directory -Path $missingSnapshotEventProject | Out-Null
    Invoke-InitPowerShell $missingSnapshotEventProject
    New-Item -ItemType Directory -Path (Join-Path $missingSnapshotEventProject ".codex-memory/workstreams/missing-snapshot/events") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $missingSnapshotEventProject ".codex-memory/threads/2026-05-24-125500-missing-snapshot.md") -Encoding UTF8 -Value @"
---
thread: missing-snapshot
created: 2026-05-24 12:55
updated: 2026-05-24 12:55
status: active
scope: Missing snapshot but invalid event filename.
workstream: missing-snapshot
---

# Missing Snapshot
"@
    Set-Content -LiteralPath (Join-Path $missingSnapshotEventProject ".codex-memory/workstreams/missing-snapshot/workstream.md") -Encoding UTF8 -Value @"
---
workstream: missing-snapshot
created: 2026-05-24
updated: 2026-05-24
status: active
---

# Missing Snapshot Workstream
"@
    Set-Content -LiteralPath (Join-Path $missingSnapshotEventProject ".codex-memory/workstreams/missing-snapshot/events/later-event.md") -Encoding UTF8 -Value "event without timestamp"
    $missingSnapshotEventDoctorOutput = Invoke-MemoryToolsPowerShell $missingSnapshotEventProject "doctor"
    Assert-True ($missingSnapshotEventDoctorOutput -match "WORKSTREAM_SNAPSHOT_MISSING") "PowerShell doctor should warn when events exist but snapshot.md is missing"
    Assert-True ($missingSnapshotEventDoctorOutput -match "WORKSTREAM_EVENT_FILENAME_NON_STANDARD") "PowerShell doctor should still check event filenames when snapshot.md is missing"

    $isoTimestampProject = Join-Path $TempRoot "iso-timestamp"
    New-Item -ItemType Directory -Path $isoTimestampProject | Out-Null
    Invoke-InitPowerShell $isoTimestampProject
    New-Item -ItemType Directory -Path (Join-Path $isoTimestampProject ".codex-memory/workstreams/iso-stream/events") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $isoTimestampProject ".codex-memory/threads/2026-05-24-130000-iso.md") -Encoding UTF8 -Value @"
---
thread: iso
created: 2026-05-24 13:00
updated: 2026-05-24 13:00
status: active
scope: ISO timestamp snapshot.
workstream: iso-stream
---

# ISO Timestamp
"@
    Set-Content -LiteralPath (Join-Path $isoTimestampProject ".codex-memory/workstreams/iso-stream/workstream.md") -Encoding UTF8 -Value @"
---
workstream: iso-stream
created: 2026-05-24
updated: 2026-05-24
status: active
---

# ISO Stream
"@
    Set-Content -LiteralPath (Join-Path $isoTimestampProject ".codex-memory/workstreams/iso-stream/snapshot.md") -Encoding UTF8 -Value @"
---
workstream: iso-stream
updated: 2026-05-24T13:10:00Z
status: active
---

# Snapshot
"@
    Set-Content -LiteralPath (Join-Path $isoTimestampProject ".codex-memory/workstreams/iso-stream/events/2026-05-24-130000-iso-event.md") -Encoding UTF8 -Value "iso event"
    $isoTimestampDoctorOutput = Invoke-MemoryToolsPowerShell $isoTimestampProject "doctor"
    Assert-True ($isoTimestampDoctorOutput -notmatch "WORKSTREAM_SNAPSHOT_METADATA_MISSING") "PowerShell doctor should parse ISO snapshot timestamps with Z suffix"
    Assert-True ($isoTimestampDoctorOutput -notmatch "WORKSTREAM_SNAPSHOT_STALE") "PowerShell doctor should not mark a newer ISO snapshot stale"

    $forkProject = Join-Path $TempRoot "fork"
    New-Item -ItemType Directory -Path $forkProject | Out-Null
    Invoke-InitPowerShell $forkProject
    Set-Content -LiteralPath (Join-Path $forkProject ".codex-memory/threads/2026-05-24-132000-base.md") -Encoding UTF8 -Value @"
---
thread: base
created: 2026-05-24 13:20
updated: 2026-05-24 13:20
status: done
scope: Base thread.
---

# Base
"@
    foreach ($fork in @(
        @{ Stamp = "132100"; Name = "fork-a" },
        @{ Stamp = "132101"; Name = "fork-b" }
    )) {
        Set-Content -LiteralPath (Join-Path $forkProject ".codex-memory/threads/2026-05-24-$($fork.Stamp)-$($fork.Name).md") -Encoding UTF8 -Value @"
---
thread: $($fork.Name)
created: 2026-05-24 13:21
updated: 2026-05-24 13:21
status: active
scope: Continuation fork.
continues_from:
  - .codex-memory/threads/2026-05-24-132000-base.md
---

# $($fork.Name)
"@
    }
    $forkDoctorOutput = Invoke-MemoryToolsPowerShell $forkProject "doctor"
    Assert-True ($forkDoctorOutput -match "POSSIBLE_CONTINUATION_FORK") "PowerShell doctor should warn when active threads share the same predecessor"
    if ($bashCommand) {
        Push-Location $RepoRoot
        try {
            $shellForkPath = Convert-ToBashPath $forkProject
            $shellForkOutput = bash -c "sh skill/codex-memory-hub/scripts/memory_tools.sh --path '$shellForkPath' doctor"
            if ($LASTEXITCODE -ne 0) {
                throw "shell doctor failed for continuation fork project"
            }
        } finally {
            Pop-Location
        }
        Assert-True (($shellForkOutput -join "`n") -match "POSSIBLE_CONTINUATION_FORK") "shell doctor should warn when active threads share the same predecessor"
    }

    $nestedProject = Join-Path $TempRoot "nested"
    New-Item -ItemType Directory -Path $nestedProject | Out-Null
    Invoke-InitPowerShell $nestedProject
    New-Item -ItemType Directory -Path (Join-Path $nestedProject ".codex-memory/threads/nested") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $nestedProject ".codex-memory/workstreams/nested-stream/events/nested") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $nestedProject ".codex-memory/threads/2026-05-24-133000-root.md") -Encoding UTF8 -Value @"
---
thread: root
created: 2026-05-24 13:30
updated: 2026-05-24 13:30
status: active
scope: Root thread.
workstream: nested-stream
---

# Root
"@
    Set-Content -LiteralPath (Join-Path $nestedProject ".codex-memory/threads/nested/2026-05-24-133100-nested.md") -Encoding UTF8 -Value @"
---
thread: nested
created: 2026-05-24 13:31
updated: 2026-05-24 13:31
status: active
scope: Nested thread should not be indexed.
---

# Nested
"@
    Set-Content -LiteralPath (Join-Path $nestedProject ".codex-memory/workstreams/nested-stream/workstream.md") -Encoding UTF8 -Value @"
---
workstream: nested-stream
created: 2026-05-24
updated: 2026-05-24
status: active
---

# Nested Stream
"@
    Set-Content -LiteralPath (Join-Path $nestedProject ".codex-memory/workstreams/nested-stream/events/2026-05-24-133200-root-event.md") -Encoding UTF8 -Value "root event"
    Set-Content -LiteralPath (Join-Path $nestedProject ".codex-memory/workstreams/nested-stream/events/nested/2026-05-24-133300-nested-event.md") -Encoding UTF8 -Value "nested event"
    Invoke-MemoryToolsPowerShell $nestedProject "index" | Out-Null
    $psNestedThreads = Get-Content -Raw -LiteralPath (Join-Path $nestedProject ".codex-memory/system/thread-index.json") | ConvertFrom-Json
    $psNestedWorkstreams = Get-Content -Raw -LiteralPath (Join-Path $nestedProject ".codex-memory/system/workstream-index.json") | ConvertFrom-Json
    Assert-True ($psNestedThreads.thread_count -eq 1) "PowerShell index should only count direct thread files"
    Assert-True ($psNestedWorkstreams.workstreams[0].event_count -eq 1) "PowerShell index should only count direct event files"
    if ($bashCommand) {
        Push-Location $RepoRoot
        try {
            $shellNestedPath = Convert-ToBashPath $nestedProject
            bash -c "sh skill/codex-memory-hub/scripts/memory_tools.sh --path '$shellNestedPath' index >/dev/null"
            if ($LASTEXITCODE -ne 0) {
                throw "shell index failed for nested layout project"
            }
        } finally {
            Pop-Location
        }
        $shellNestedThreads = Get-Content -Raw -LiteralPath (Join-Path $nestedProject ".codex-memory/system/thread-index.json") | ConvertFrom-Json
        $shellNestedWorkstreams = Get-Content -Raw -LiteralPath (Join-Path $nestedProject ".codex-memory/system/workstream-index.json") | ConvertFrom-Json
        Assert-True ($shellNestedThreads.thread_count -eq $psNestedThreads.thread_count) "shell index should match PowerShell direct thread scan behavior"
        Assert-True ($shellNestedWorkstreams.workstreams[0].event_count -eq $psNestedWorkstreams.workstreams[0].event_count) "shell index should match PowerShell direct event scan behavior"
    }

    $legacyOverviewProject = Join-Path $TempRoot "legacy-overview"
    New-Item -ItemType Directory -Path (Join-Path $legacyOverviewProject "docs/wiki") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $legacyOverviewProject "docs/wiki/project-overview.md") -Value "Overview only content" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $legacyOverviewProject "docs/wiki/current-status.md") -Value "Current status content" -Encoding UTF8
    Invoke-InitPowerShell $legacyOverviewProject

    $migratedProject = Get-Content -Raw -LiteralPath (Join-Path $legacyOverviewProject ".codex-memory/project.md")
    Assert-True ($migratedProject -match "Overview only content") "project-overview.md was not migrated into project.md"
    $legacyThread = Get-ChildItem -LiteralPath (Join-Path $legacyOverviewProject ".codex-memory/threads") -Filter "*legacy-project-memory.md" | Select-Object -First 1
    Assert-True ($null -ne $legacyThread) "legacy status pages did not create a legacy thread memory"
    $legacyThreadContent = Get-Content -Raw -LiteralPath $legacyThread.FullName
    Assert-True ($legacyThreadContent -match "current-status.md") "legacy thread memory did not include current-status.md"
    Assert-True ($legacyThreadContent -notmatch "project-overview.md") "project-overview.md should not be duplicated into legacy thread memory"

    $forceProject = Join-Path $TempRoot "force"
    New-Item -ItemType Directory -Path (Join-Path $forceProject "docs/wiki") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $forceProject ".codex-memory") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $forceProject ".codex-memory/project.md") -Value "Existing project memory" -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $forceProject "docs/wiki/project.md") -Value "Forced legacy project memory" -Encoding UTF8
    Invoke-InitPowerShell $forceProject -Force

    $forcedProjectContent = Get-Content -Raw -LiteralPath (Join-Path $forceProject ".codex-memory/project.md")
    Assert-True ($forcedProjectContent -match "Forced legacy project memory") "--force did not overwrite project.md with migrated legacy project memory"
    Assert-True ($forcedProjectContent -notmatch "Existing project memory") "--force preserved old project.md content unexpectedly"

    if ($bashCommand) {
        Push-Location $RepoRoot
        $shellRuntimePath = Join-Path $RepoRoot ".codex-memory-hub-test-runtime.sh"
        try {
            $shellRuntimeTests = @'
set -eu
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/no-memory"
if sh skill/codex-memory-hub/scripts/memory_tools.sh --path "$tmp/no-memory" doctor > "$tmp/no-memory-doctor.txt"; then
  echo "shell doctor should exit non-zero when memory root is missing" >&2
  exit 1
fi
grep -q "MEMORY_ROOT_MISSING" "$tmp/no-memory-doctor.txt"

mkdir -p "$tmp/legacy/docs/wiki"
printf '%s\n' "Overview only content" > "$tmp/legacy/docs/wiki/project-overview.md"
printf '%s\n' "Current status content" > "$tmp/legacy/docs/wiki/current-status.md"
sh skill/codex-memory-hub/scripts/init_project_memory.sh --path "$tmp/legacy" >/dev/null
test -d "$tmp/legacy/.codex-memory/threads"
test -d "$tmp/legacy/.codex-memory/system"
test ! -e "$tmp/legacy/.codex-memory/threads/.gitkeep"
grep -q "Overview only content" "$tmp/legacy/.codex-memory/project.md"
index_line=$(grep -n ".codex-memory/system/thread-index.json" "$tmp/legacy/AGENTS.md" | head -n 1 | cut -d: -f1)
thread_line=$(grep -n "Scan .codex-memory/threads/" "$tmp/legacy/AGENTS.md" | head -n 1 | cut -d: -f1)
if [ "$index_line" -ge "$thread_line" ]; then
  echo "shell AGENTS scans threads before reading system index" >&2
  exit 1
fi
legacy_thread=$(find "$tmp/legacy/.codex-memory/threads" -name '*legacy-project-memory.md' | head -n 1)
test -n "$legacy_thread"
grep -q "current-status.md" "$legacy_thread"
if grep -q "project-overview.md" "$legacy_thread"; then
  echo "project-overview.md duplicated into shell legacy thread" >&2
  exit 1
fi

mkdir -p "$tmp/force/docs/wiki" "$tmp/force/.codex-memory"
printf '%s\n' "Existing project memory" > "$tmp/force/.codex-memory/project.md"
printf '%s\n' "Forced legacy project memory" > "$tmp/force/docs/wiki/project.md"
sh skill/codex-memory-hub/scripts/init_project_memory.sh --path "$tmp/force" --force >/dev/null
grep -q "Forced legacy project memory" "$tmp/force/.codex-memory/project.md"
if grep -q "Existing project memory" "$tmp/force/.codex-memory/project.md"; then
  echo "--force preserved old shell project.md content unexpectedly" >&2
  exit 1
fi

sh skill/codex-memory-hub/scripts/memory_tools.sh --path "$tmp/legacy" index >/dev/null
test -f "$tmp/legacy/.codex-memory/system/thread-index.json"
test -f "$tmp/legacy/.codex-memory/system/workstream-index.json"

mkdir -p "$tmp/broken"
sh skill/codex-memory-hub/scripts/init_project_memory.sh --path "$tmp/broken" >/dev/null
mkdir -p "$tmp/broken/.codex-memory/workstreams/orphan-workstream"
cat > "$tmp/broken/.codex-memory/threads/2026-05-24-120000-broken.md" <<'EOF2'
---
thread: broken
created: 2026-05-24 12:00
updated: 2026-05-24 12:10
status: active
scope: Broken continuation.
workstream: missing-workstream
continues_from:
  - .codex-memory/threads/missing.md
---

# Broken

leaked token: ghp_1234567890abcdefghijklmnopqrstu

This body text mentions workstream: orphan-workstream but frontmatter does not reference it.
EOF2
cat > "$tmp/broken/.codex-memory/workstreams/orphan-workstream/workstream.md" <<'EOF2'
---
workstream: orphan-workstream
created: 2026-05-24
updated: 2026-05-24
status: active
---

# Orphan Workstream
EOF2
sh skill/codex-memory-hub/scripts/memory_tools.sh --path "$tmp/broken" doctor > "$tmp/broken-doctor.txt"
grep -q "BROKEN_CONTINUES_FROM" "$tmp/broken-doctor.txt"
grep -q "BROKEN_WORKSTREAM_REFERENCE" "$tmp/broken-doctor.txt"
grep -q "WORKSTREAM_ORPHANED" "$tmp/broken-doctor.txt"
grep -q "POSSIBLE_SECRET" "$tmp/broken-doctor.txt"

mkdir -p "$tmp/workstream-integrity/.codex-memory/threads" \
  "$tmp/workstream-integrity/.codex-memory/workstreams/missing-file" \
  "$tmp/workstream-integrity/.codex-memory/workstreams/mismatch/events" \
  "$tmp/workstream-integrity/.codex-memory/workstreams/stale-stream/events" \
  "$tmp/workstream-integrity/.codex-memory/workstreams/snapshot-no-updated/events" \
  "$tmp/workstream-integrity/.codex-memory/workstreams/nonstandard-event/events" \
  "$tmp/workstream-integrity/.codex-memory/archive" \
  "$tmp/workstream-integrity/.codex-memory/system"
printf '%s\n' "# Index" > "$tmp/workstream-integrity/.codex-memory/index.md"
printf '%s\n' "# Project" > "$tmp/workstream-integrity/.codex-memory/project.md"
cat > "$tmp/workstream-integrity/.codex-memory/threads/2026-05-24-130000-missing-file.md" <<'EOF2'
---
thread: missing-file
created: 2026-05-24 13:00
updated: 2026-05-24 13:00
status: active
scope: missing workstream file
workstream: missing-file
---
EOF2
cat > "$tmp/workstream-integrity/.codex-memory/threads/2026-05-24-131000-mismatch.md" <<'EOF2'
---
thread: mismatch
created: 2026-05-24 13:10
updated: 2026-05-24 13:10
status: active
scope: mismatched workstream id
workstream: mismatch
---
EOF2
cat > "$tmp/workstream-integrity/.codex-memory/workstreams/mismatch/workstream.md" <<'EOF2'
---
workstream: other-workstream-id
created: 2026-05-24
updated: 2026-05-24
status: active
---
EOF2
cat > "$tmp/workstream-integrity/.codex-memory/threads/2026-05-24-132000-stale.md" <<'EOF2'
---
thread: stale
created: 2026-05-24 13:20
updated: 2026-05-24 13:20
status: active
scope: stale snapshot
workstream: stale-stream
---
EOF2
cat > "$tmp/workstream-integrity/.codex-memory/workstreams/stale-stream/workstream.md" <<'EOF2'
---
workstream: stale-stream
created: 2026-05-24
updated: 2026-05-24
status: active
---
EOF2
cat > "$tmp/workstream-integrity/.codex-memory/workstreams/stale-stream/snapshot.md" <<'EOF2'
---
workstream: stale-stream
updated: 2026-05-24 12:00
status: active
---
EOF2
printf '%s\n' "later event" > "$tmp/workstream-integrity/.codex-memory/workstreams/stale-stream/events/2026-05-24-130000-later-event.md"
touch -t 202605241400 "$tmp/workstream-integrity/.codex-memory/workstreams/stale-stream/snapshot.md"
touch -t 202605241100 "$tmp/workstream-integrity/.codex-memory/workstreams/stale-stream/events/2026-05-24-130000-later-event.md"
cat > "$tmp/workstream-integrity/.codex-memory/workstreams/snapshot-no-updated/workstream.md" <<'EOF2'
---
workstream: snapshot-no-updated
created: 2026-05-24
updated: 2026-05-24
status: active
---
EOF2
cat > "$tmp/workstream-integrity/.codex-memory/workstreams/snapshot-no-updated/snapshot.md" <<'EOF2'
---
workstream: snapshot-no-updated
status: active
---
EOF2
printf '%s\n' "later event" > "$tmp/workstream-integrity/.codex-memory/workstreams/snapshot-no-updated/events/2026-05-24-131000-later-event.md"
cat > "$tmp/workstream-integrity/.codex-memory/workstreams/nonstandard-event/workstream.md" <<'EOF2'
---
workstream: nonstandard-event
created: 2026-05-24
updated: 2026-05-24
status: active
---
EOF2
cat > "$tmp/workstream-integrity/.codex-memory/workstreams/nonstandard-event/snapshot.md" <<'EOF2'
---
workstream: nonstandard-event
updated: 2026-05-24 12:00
status: active
---
EOF2
printf '%s\n' "event without sortable timestamp" > "$tmp/workstream-integrity/.codex-memory/workstreams/nonstandard-event/events/later-event.md"
sh skill/codex-memory-hub/scripts/memory_tools.sh --path "$tmp/workstream-integrity" doctor > "$tmp/workstream-integrity-doctor.txt"
grep -q "WORKSTREAM_FILE_MISSING" "$tmp/workstream-integrity-doctor.txt"
grep -q "WORKSTREAM_ID_MISMATCH" "$tmp/workstream-integrity-doctor.txt"
grep -q "WORKSTREAM_SNAPSHOT_STALE" "$tmp/workstream-integrity-doctor.txt"
grep -q "WORKSTREAM_SNAPSHOT_METADATA_MISSING" "$tmp/workstream-integrity-doctor.txt"
grep -q "WORKSTREAM_EVENT_FILENAME_NON_STANDARD" "$tmp/workstream-integrity-doctor.txt"

sh skill/codex-memory-hub/scripts/memory_tools.sh --path "$tmp/workstream-integrity" index >/dev/null
if grep -q '"project_root"' "$tmp/workstream-integrity/.codex-memory/system/thread-index.json"; then
  echo "shell thread index leaked project_root" >&2
  exit 1
fi
if grep -q '"project_root"' "$tmp/workstream-integrity/.codex-memory/system/workstream-index.json"; then
  echo "shell workstream index leaked project_root" >&2
  exit 1
fi
if ! grep -A3 '"id": "missing-file"' "$tmp/workstream-integrity/.codex-memory/system/workstream-index.json" | grep -q '"workstream": "missing-file"'; then
  echo "shell workstream index did not fall back to directory id" >&2
  exit 1
fi

mkdir -p "$tmp/legacy-filenames/.codex-memory/threads" \
  "$tmp/legacy-filenames/.codex-memory/workstreams/legacy-minute/events" \
  "$tmp/legacy-filenames/.codex-memory/archive" \
  "$tmp/legacy-filenames/.codex-memory/system"
printf '%s\n' "# Index" > "$tmp/legacy-filenames/.codex-memory/index.md"
printf '%s\n' "# Project" > "$tmp/legacy-filenames/.codex-memory/project.md"
cat > "$tmp/legacy-filenames/.codex-memory/threads/2026-05-24-1240-legacy-minute.md" <<'EOF2'
---
thread: legacy-minute
created: 2026-05-24 12:40
updated: 2026-05-24 12:40
status: active
scope: legacy minute filename
workstream: legacy-minute
---
EOF2
cat > "$tmp/legacy-filenames/.codex-memory/workstreams/legacy-minute/workstream.md" <<'EOF2'
---
workstream: legacy-minute
created: 2026-05-24
updated: 2026-05-24
status: active
---
EOF2
cat > "$tmp/legacy-filenames/.codex-memory/workstreams/legacy-minute/snapshot.md" <<'EOF2'
---
workstream: legacy-minute
updated: 2026-05-24 12:41
status: active
---
EOF2
printf '%s\n' "legacy event" > "$tmp/legacy-filenames/.codex-memory/workstreams/legacy-minute/events/2026-05-24-1240-legacy-minute-event.md"
sh skill/codex-memory-hub/scripts/memory_tools.sh --path "$tmp/legacy-filenames" doctor > "$tmp/legacy-filenames-doctor.txt"
if grep -q "NON_STANDARD_THREAD_FILENAME" "$tmp/legacy-filenames-doctor.txt"; then
  echo "shell doctor rejected legacy minute thread filename" >&2
  exit 1
fi
if grep -q "WORKSTREAM_EVENT_FILENAME_NON_STANDARD" "$tmp/legacy-filenames-doctor.txt"; then
  echo "shell doctor rejected legacy minute event filename" >&2
  exit 1
fi

mkdir -p "$tmp/missing-snapshot-event/.codex-memory/threads" \
  "$tmp/missing-snapshot-event/.codex-memory/workstreams/missing-snapshot/events" \
  "$tmp/missing-snapshot-event/.codex-memory/archive" \
  "$tmp/missing-snapshot-event/.codex-memory/system"
printf '%s\n' "# Index" > "$tmp/missing-snapshot-event/.codex-memory/index.md"
printf '%s\n' "# Project" > "$tmp/missing-snapshot-event/.codex-memory/project.md"
cat > "$tmp/missing-snapshot-event/.codex-memory/threads/2026-05-24-125500-missing-snapshot.md" <<'EOF2'
---
thread: missing-snapshot
created: 2026-05-24 12:55
updated: 2026-05-24 12:55
status: active
scope: missing snapshot invalid event
workstream: missing-snapshot
---
EOF2
cat > "$tmp/missing-snapshot-event/.codex-memory/workstreams/missing-snapshot/workstream.md" <<'EOF2'
---
workstream: missing-snapshot
created: 2026-05-24
updated: 2026-05-24
status: active
---
EOF2
printf '%s\n' "event without timestamp" > "$tmp/missing-snapshot-event/.codex-memory/workstreams/missing-snapshot/events/later-event.md"
sh skill/codex-memory-hub/scripts/memory_tools.sh --path "$tmp/missing-snapshot-event" doctor > "$tmp/missing-snapshot-event-doctor.txt"
grep -q "WORKSTREAM_SNAPSHOT_MISSING" "$tmp/missing-snapshot-event-doctor.txt"
grep -q "WORKSTREAM_EVENT_FILENAME_NON_STANDARD" "$tmp/missing-snapshot-event-doctor.txt"

mkdir -p "$tmp/iso-timestamp/.codex-memory/threads" \
  "$tmp/iso-timestamp/.codex-memory/workstreams/iso-stream/events" \
  "$tmp/iso-timestamp/.codex-memory/archive" \
  "$tmp/iso-timestamp/.codex-memory/system"
printf '%s\n' "# Index" > "$tmp/iso-timestamp/.codex-memory/index.md"
printf '%s\n' "# Project" > "$tmp/iso-timestamp/.codex-memory/project.md"
cat > "$tmp/iso-timestamp/.codex-memory/threads/2026-05-24-130000-iso.md" <<'EOF2'
---
thread: iso
created: 2026-05-24 13:00
updated: 2026-05-24 13:00
status: active
scope: iso timestamp
workstream: iso-stream
---
EOF2
cat > "$tmp/iso-timestamp/.codex-memory/workstreams/iso-stream/workstream.md" <<'EOF2'
---
workstream: iso-stream
created: 2026-05-24
updated: 2026-05-24
status: active
---
EOF2
cat > "$tmp/iso-timestamp/.codex-memory/workstreams/iso-stream/snapshot.md" <<'EOF2'
---
workstream: iso-stream
updated: 2026-05-24T13:10:00Z
status: active
---
EOF2
printf '%s\n' "iso event" > "$tmp/iso-timestamp/.codex-memory/workstreams/iso-stream/events/2026-05-24-130000-iso-event.md"
sh skill/codex-memory-hub/scripts/memory_tools.sh --path "$tmp/iso-timestamp" doctor > "$tmp/iso-timestamp-doctor.txt"
if grep -q "WORKSTREAM_SNAPSHOT_METADATA_MISSING" "$tmp/iso-timestamp-doctor.txt"; then
  echo "shell doctor did not parse ISO snapshot timestamp" >&2
  exit 1
fi
if grep -q "WORKSTREAM_SNAPSHOT_STALE" "$tmp/iso-timestamp-doctor.txt"; then
  echo "shell doctor marked newer ISO snapshot as stale" >&2
  exit 1
fi
'@ -replace "`r", ""
            [System.IO.File]::WriteAllText($shellRuntimePath, $shellRuntimeTests, [System.Text.UTF8Encoding]::new($false))
            bash ".codex-memory-hub-test-runtime.sh"
            if ($LASTEXITCODE -ne 0) {
                throw "shell runtime tests failed"
            }
        } finally {
            if (Test-Path -LiteralPath $shellRuntimePath) {
                Remove-Item -LiteralPath $shellRuntimePath -Force
            }
            Pop-Location
        }
    } else {
        Write-Host "skip shell runtime tests: bash not found"
    }

    Write-Host "All Codex Memory Hub tests passed."
} finally {
    if (Test-Path -LiteralPath $TempRoot) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force
    }
}

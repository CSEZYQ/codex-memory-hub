param(
    [string]$Path = ".",

    [ValidateSet("doctor", "index", "all")]
    [string]$Command = "doctor"
)

$ErrorActionPreference = "Stop"

function Resolve-FullPath {
    param([string]$InputPath)

    if ([System.IO.Path]::IsPathRooted($InputPath)) {
        return [System.IO.Path]::GetFullPath($InputPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $InputPath))
}

function Read-Utf8Text {
    param([string]$FilePath)

    return [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)
}

function Write-Utf8NoBom {
    param(
        [string]$FilePath,
        [string]$Content
    )

    $parent = Split-Path -Parent $FilePath
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    [System.IO.File]::WriteAllText($FilePath, $Content, [System.Text.UTF8Encoding]::new($false))
}

function ConvertTo-CleanJson {
    param(
        [object]$Value,
        [int]$Depth = 8
    )

    $json = $Value | ConvertTo-Json -Depth $Depth
    return (($json -replace "(\r?\n)+$", "") + "`n")
}

function ConvertTo-RelativeMemoryPath {
    param(
        [string]$Root,
        [string]$Target
    )

    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $targetFull = [System.IO.Path]::GetFullPath($Target)
    $rootUri = [System.Uri]::new($rootFull + [System.IO.Path]::DirectorySeparatorChar)
    $targetUri = [System.Uri]::new($targetFull)
    $relative = [System.Uri]::UnescapeDataString($rootUri.MakeRelativeUri($targetUri).ToString())
    return ($relative -replace "\\", "/")
}

function Normalize-MemoryReference {
    param([object]$Value)

    if ($null -eq $Value) {
        return ""
    }

    $text = [string]$Value
    $text = $text.Trim()
    if (($text.StartsWith("'") -and $text.EndsWith("'")) -or ($text.StartsWith('"') -and $text.EndsWith('"'))) {
        $text = $text.Substring(1, $text.Length - 2)
    }
    return $text.Trim()
}

function Get-MetadataValue {
    param(
        [System.Collections.Specialized.OrderedDictionary]$Metadata,
        [string]$Name,
        [object]$Default = ""
    )

    if ($Metadata.Contains($Name)) {
        return $Metadata[$Name]
    }
    return $Default
}

function Read-FrontMatter {
    param([string]$FilePath)

    $metadata = [ordered]@{}
    if (-not (Test-Path -LiteralPath $FilePath)) {
        return $metadata
    }

    $content = Read-Utf8Text $FilePath
    $match = [regex]::Match($content, "(?s)^---\r?\n(.*?)\r?\n---")
    if (-not $match.Success) {
        return $metadata
    }

    $currentListKey = $null
    $lines = @($match.Groups[1].Value -split "\r?\n")
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $keyMatch = [regex]::Match($line, "^\s{0,2}([A-Za-z0-9_-]+):\s*(.*)$")
        if ($keyMatch.Success) {
            $key = $keyMatch.Groups[1].Value
            $value = Normalize-MemoryReference $keyMatch.Groups[2].Value
            if ($value -eq "|" -or $value -eq ">") {
                $folded = ($value -eq ">")
                $blockLines = [System.Collections.Generic.List[string]]::new()
                $index++
                while ($index -lt $lines.Count) {
                    $blockLine = $lines[$index]
                    if ($blockLine -match "^[A-Za-z0-9_-]+:\s*") {
                        $index--
                        break
                    }
                    $blockLines.Add(($blockLine -replace "^\s+", "")) | Out-Null
                    $index++
                }
                if ($folded) {
                    $metadata[$key] = ((@($blockLines) | Where-Object { $_ -ne "" }) -join " ").Trim()
                } else {
                    $metadata[$key] = ((@($blockLines) -join "`n") -replace "(\r?\n)+$", "")
                }
                $currentListKey = $null
                continue
            }
            if ([string]::IsNullOrWhiteSpace($value)) {
                $metadata[$key] = @()
                $currentListKey = $key
            } else {
                $metadata[$key] = $value
                $currentListKey = $null
            }
            continue
        }

        $itemMatch = [regex]::Match($line, "^\s*-\s+(.+)$")
        if ($currentListKey -and $itemMatch.Success) {
            $items = @($metadata[$currentListKey])
            $items += (Normalize-MemoryReference $itemMatch.Groups[1].Value)
            $metadata[$currentListKey] = $items
        }
    }

    return $metadata
}

function Resolve-MemoryReferencePath {
    param(
        [string]$ProjectRoot,
        [string]$CurrentFile,
        [string]$Reference
    )

    $referenceText = Normalize-MemoryReference $Reference
    if ([string]::IsNullOrWhiteSpace($referenceText)) {
        return ""
    }

    $nativeReference = $referenceText -replace "/", [System.IO.Path]::DirectorySeparatorChar
    if ([System.IO.Path]::IsPathRooted($nativeReference)) {
        return [System.IO.Path]::GetFullPath($nativeReference)
    }

    $projectCandidate = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $nativeReference))
    if (Test-Path -LiteralPath $projectCandidate) {
        return $projectCandidate
    }

    $currentDirectory = Split-Path -Parent $CurrentFile
    $localCandidate = [System.IO.Path]::GetFullPath((Join-Path $currentDirectory $nativeReference))
    if (Test-Path -LiteralPath $localCandidate) {
        return $localCandidate
    }

    return $projectCandidate
}

function Get-ThreadRecords {
    param(
        [string]$ProjectRoot,
        [string]$MemoryRoot
    )

    $threadsRoot = Join-Path $MemoryRoot "threads"
    if (-not (Test-Path -LiteralPath $threadsRoot)) {
        return @()
    }

    $records = @()
    foreach ($file in (Get-ChildItem -LiteralPath $threadsRoot -File -Filter "*.md" | Sort-Object Name)) {
        $metadata = Read-FrontMatter $file.FullName
        $continuesFrom = @()
        if ($metadata.Contains("continues_from")) {
            $continuesFrom = @($metadata["continues_from"]) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        }

        $records += [pscustomobject]@{
            name           = $file.Name
            path           = ConvertTo-RelativeMemoryPath $ProjectRoot $file.FullName
            thread         = [string](Get-MetadataValue $metadata "thread")
            created        = [string](Get-MetadataValue $metadata "created")
            updated        = [string](Get-MetadataValue $metadata "updated")
            status         = [string](Get-MetadataValue $metadata "status")
            scope          = [string](Get-MetadataValue $metadata "scope")
            workstream     = [string](Get-MetadataValue $metadata "workstream")
            continues_from = @($continuesFrom)
            size_bytes     = $file.Length
            modified_at    = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
        }
    }

    return @($records)
}

function Get-WorkstreamRecords {
    param(
        [string]$ProjectRoot,
        [string]$MemoryRoot,
        [array]$ThreadRecords
    )

    $workstreamsRoot = Join-Path $MemoryRoot "workstreams"
    if (-not (Test-Path -LiteralPath $workstreamsRoot)) {
        return @()
    }

    $records = @()
    foreach ($directory in (Get-ChildItem -LiteralPath $workstreamsRoot -Directory | Where-Object { -not $_.Name.StartsWith(".") } | Sort-Object Name)) {
        $workstreamPath = Join-Path $directory.FullName "workstream.md"
        $snapshotPath = Join-Path $directory.FullName "snapshot.md"
        $eventsRoot = Join-Path $directory.FullName "events"
        $metadata = Read-FrontMatter $workstreamPath
        $events = @()
        if (Test-Path -LiteralPath $eventsRoot) {
            $events = @(Get-ChildItem -LiteralPath $eventsRoot -File -Filter "*.md" | Sort-Object Name)
        }

        $latestEvent = $null
        if ($events.Count -gt 0) {
            $latestEvent = ($events | Sort-Object Name -Descending | Select-Object -First 1)
        }

        $activeThreads = @(
            $ThreadRecords |
                Where-Object { $_.workstream -eq $directory.Name -and $_.status -eq "active" } |
                Select-Object -ExpandProperty path
        )

        $records += [pscustomobject]@{
            id              = $directory.Name
            path            = ConvertTo-RelativeMemoryPath $ProjectRoot $directory.FullName
            workstream      = [string](Get-MetadataValue $metadata "workstream" $directory.Name)
            created         = [string](Get-MetadataValue $metadata "created")
            updated         = [string](Get-MetadataValue $metadata "updated")
            status          = [string](Get-MetadataValue $metadata "status")
            event_count     = $events.Count
            latest_event    = if ($latestEvent) { ConvertTo-RelativeMemoryPath $ProjectRoot $latestEvent.FullName } else { "" }
            snapshot_exists = Test-Path -LiteralPath $snapshotPath
            active_threads  = @($activeThreads)
            modified_at     = $directory.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
        }
    }

    return @($records)
}

function Add-DoctorIssue {
    param(
        [System.Collections.Generic.List[object]]$Issues,
        [string]$Severity,
        [string]$Code,
        [string]$Path,
        [string]$Message
    )

    $Issues.Add([pscustomobject]@{
        severity = $Severity
        code     = $Code
        path     = $Path
        message  = $Message
    }) | Out-Null
}

function Test-MemoryHealth {
    param(
        [string]$ProjectRoot,
        [string]$MemoryRoot,
        [array]$ThreadRecords,
        [array]$WorkstreamRecords
    )

    $issues = [System.Collections.Generic.List[object]]::new()

    if (-not (Test-Path -LiteralPath $MemoryRoot)) {
        Add-DoctorIssue $issues "error" "MEMORY_ROOT_MISSING" ".codex-memory/" "Memory root does not exist. Run the initializer first."
        return $issues
    }

    foreach ($requiredDirectory in @("threads", "workstreams", "archive", "system")) {
        $directoryPath = Join-Path $MemoryRoot $requiredDirectory
        if (-not (Test-Path -LiteralPath $directoryPath)) {
            Add-DoctorIssue $issues "error" "MEMORY_DIRECTORY_MISSING" ".codex-memory/$requiredDirectory/" "Required memory directory is missing."
        }
    }

    foreach ($requiredFile in @("index.md", "project.md")) {
        $filePath = Join-Path $MemoryRoot $requiredFile
        if (-not (Test-Path -LiteralPath $filePath)) {
            Add-DoctorIssue $issues "warning" "MEMORY_FILE_MISSING" ".codex-memory/$requiredFile" "Expected memory entry file is missing."
        }
    }

    $gitDirectory = Join-Path $ProjectRoot ".git"
    if (Test-Path -LiteralPath $gitDirectory) {
        $gitignorePath = Join-Path $ProjectRoot ".gitignore"
        if (-not (Test-Path -LiteralPath $gitignorePath)) {
            Add-DoctorIssue $issues "warning" "MEMORY_NOT_GITIGNORED" ".gitignore" "Git repository has no .gitignore entry for .codex-memory/."
        } else {
            $gitignore = Read-Utf8Text $gitignorePath
            if ($gitignore -notmatch "(?m)^\.codex-memory/\r?$") {
                Add-DoctorIssue $issues "warning" "MEMORY_NOT_GITIGNORED" ".gitignore" "Git repository does not ignore .codex-memory/."
            }
        }
    }

    if (Test-Path -LiteralPath (Join-Path $ProjectRoot "docs/wiki")) {
        Add-DoctorIssue $issues "warning" "LEGACY_MEMORY_PRESENT" "docs/wiki/" "Legacy docs/wiki memory still exists. Run the initializer to migrate it into .codex-memory/."
    }

    foreach ($thread in $ThreadRecords) {
        if ($thread.name -notmatch "^\d{4}-\d{2}-\d{2}-\d{6}-.+\.md$") {
            Add-DoctorIssue $issues "warning" "NON_STANDARD_THREAD_FILENAME" $thread.path "Thread filename should use YYYY-MM-DD-HHMMSS-<short-task>.md."
        }

        foreach ($requiredMetadata in @("thread", "created", "updated", "status", "scope")) {
            if ([string]::IsNullOrWhiteSpace([string]$thread.$requiredMetadata)) {
                Add-DoctorIssue $issues "warning" "THREAD_METADATA_MISSING" $thread.path "Thread metadata '$requiredMetadata' is missing."
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($thread.status) -and $thread.status -notin @("active", "done", "archived")) {
            Add-DoctorIssue $issues "warning" "THREAD_STATUS_UNKNOWN" $thread.path "Thread status should be active, done, or archived."
        }

        if (-not [string]::IsNullOrWhiteSpace($thread.workstream)) {
            $workstreamDirectory = Join-Path (Join-Path $MemoryRoot "workstreams") $thread.workstream
            if (-not (Test-Path -LiteralPath $workstreamDirectory)) {
                Add-DoctorIssue $issues "warning" "BROKEN_WORKSTREAM_REFERENCE" $thread.path "Thread references a missing workstream: $($thread.workstream)"
            }
        }

        foreach ($reference in @($thread.continues_from)) {
            $resolved = Resolve-MemoryReferencePath $ProjectRoot (Join-Path $ProjectRoot ($thread.path -replace "/", [System.IO.Path]::DirectorySeparatorChar)) $reference
            if (-not (Test-Path -LiteralPath $resolved)) {
                Add-DoctorIssue $issues "warning" "BROKEN_CONTINUES_FROM" $thread.path "continues_from target does not exist: $reference"
            }
        }
    }

    $activeContinuationGroups = @{}
    foreach ($thread in ($ThreadRecords | Where-Object { $_.status -eq "active" })) {
        foreach ($reference in @($thread.continues_from)) {
            $key = Normalize-MemoryReference $reference
            if ([string]::IsNullOrWhiteSpace($key)) {
                continue
            }
            if (-not $activeContinuationGroups.ContainsKey($key)) {
                $activeContinuationGroups[$key] = @()
            }
            $activeContinuationGroups[$key] = @($activeContinuationGroups[$key]) + $thread.path
        }
    }
    foreach ($key in $activeContinuationGroups.Keys) {
        if (@($activeContinuationGroups[$key]).Count -gt 1) {
            Add-DoctorIssue $issues "warning" "POSSIBLE_CONTINUATION_FORK" $key "Multiple active threads continue from the same predecessor: $(@($activeContinuationGroups[$key]) -join ', ')"
        }
    }

    foreach ($workstream in $WorkstreamRecords) {
        $workstreamDirectory = Join-Path $ProjectRoot ($workstream.path -replace "/", [System.IO.Path]::DirectorySeparatorChar)
        $snapshotPath = Join-Path $workstreamDirectory "snapshot.md"
        $eventsRoot = Join-Path $workstreamDirectory "events"
        $referencedThreads = @($ThreadRecords | Where-Object { $_.workstream -eq $workstream.id })
        if ($referencedThreads.Count -eq 0 -and $workstream.status -ne "archived") {
            Add-DoctorIssue $issues "warning" "WORKSTREAM_ORPHANED" $workstream.path "Active workstream has no thread references."
        }
        if ($workstream.event_count -gt 0 -and -not (Test-Path -LiteralPath $snapshotPath)) {
            Add-DoctorIssue $issues "warning" "WORKSTREAM_SNAPSHOT_MISSING" $workstream.path "Workstream has events but no snapshot.md."
        }
        if ((Test-Path -LiteralPath $snapshotPath) -and (Test-Path -LiteralPath $eventsRoot)) {
            $latestEvent = Get-ChildItem -LiteralPath $eventsRoot -File -Filter "*.md" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($latestEvent -and $latestEvent.LastWriteTime -gt (Get-Item -LiteralPath $snapshotPath).LastWriteTime) {
                Add-DoctorIssue $issues "warning" "WORKSTREAM_SNAPSHOT_STALE" $workstream.path "snapshot.md is older than the latest workstream event."
            }
        }
    }

    $memoryMarkdownFiles = @(Get-ChildItem -LiteralPath $MemoryRoot -Recurse -File -Filter "*.md" -ErrorAction SilentlyContinue)
    foreach ($file in $memoryMarkdownFiles) {
        $content = Read-Utf8Text $file.FullName
        if ($content -match "(?i)\b(api[_-]?key|access[_-]?token|auth[_-]?token|password|passwd|secret)\b\s*[:=]\s*['""]?[^'""\s]{8,}") {
            Add-DoctorIssue $issues "warning" "POSSIBLE_SECRET" (ConvertTo-RelativeMemoryPath $ProjectRoot $file.FullName) "Memory file contains a credential-like assignment."
        } elseif ($content -match "(?i)(sk-[a-z0-9_-]{12,}|ghp_[a-z0-9_]{20,}|github_pat_[a-z0-9_]{20,}|AKIA[0-9A-Z]{16}|eyJ[a-z0-9_-]{10,}\.eyJ[a-z0-9_-]{10,})") {
            Add-DoctorIssue $issues "warning" "POSSIBLE_SECRET" (ConvertTo-RelativeMemoryPath $ProjectRoot $file.FullName) "Memory file contains a key-like token."
        }
    }

    $projectMemoryPath = Join-Path $MemoryRoot "project.md"
    if ((Test-Path -LiteralPath $projectMemoryPath) -and (Get-Item -LiteralPath $projectMemoryPath).Length -gt 50000) {
        Add-DoctorIssue $issues "info" "PROJECT_MEMORY_LARGE" ".codex-memory/project.md" "project.md is large; keep stable background here and move process history into threads."
    }

    return $issues
}

function Invoke-Doctor {
    param(
        [string]$ProjectRoot,
        [string]$MemoryRoot
    )

    $threadRecords = @(Get-ThreadRecords $ProjectRoot $MemoryRoot)
    $workstreamRecords = @(Get-WorkstreamRecords $ProjectRoot $MemoryRoot $threadRecords)
    $issues = Test-MemoryHealth $ProjectRoot $MemoryRoot $threadRecords $workstreamRecords

    Write-Host "Codex Memory Hub doctor"
    Write-Host "Project: $ProjectRoot"
    Write-Host "Memory:  $MemoryRoot"
    Write-Host "Threads: $($threadRecords.Count)"
    Write-Host "Workstreams: $($workstreamRecords.Count)"
    Write-Host ""

    if ($issues.Count -eq 0) {
        Write-Host "No errors found."
        Write-Host "No warnings found."
        return 0
    }

    $errors = @($issues | Where-Object { $_.severity -eq "error" })
    $warnings = @($issues | Where-Object { $_.severity -eq "warning" })
    $infos = @($issues | Where-Object { $_.severity -eq "info" })

    if ($errors.Count -eq 0) {
        Write-Host "No errors found."
    }

    foreach ($issue in $issues) {
        Write-Host ("[{0}] {1} {2} - {3}" -f $issue.severity.ToUpperInvariant(), $issue.code, $issue.path, $issue.message)
    }

    Write-Host ""
    Write-Host "Summary: $($errors.Count) error(s), $($warnings.Count) warning(s), $($infos.Count) info item(s)."

    if ($errors.Count -gt 0) {
        return 1
    }
    return 0
}

function Invoke-Index {
    param(
        [string]$ProjectRoot,
        [string]$MemoryRoot
    )

    if (-not (Test-Path -LiteralPath $MemoryRoot)) {
        Write-Error "Memory root does not exist: $MemoryRoot"
        return 1
    }

    $systemRoot = Join-Path $MemoryRoot "system"
    $generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $threadRecords = @(Get-ThreadRecords $ProjectRoot $MemoryRoot)
    $workstreamRecords = @(Get-WorkstreamRecords $ProjectRoot $MemoryRoot $threadRecords)

    $threadIndex = [pscustomobject]@{
        schema          = "codex-memory-hub.thread-index.v1"
        generated_at    = $generatedAt
        project_root    = $ProjectRoot
        memory_root     = ".codex-memory"
        thread_count    = $threadRecords.Count
        active_count    = @($threadRecords | Where-Object { $_.status -eq "active" }).Count
        done_count      = @($threadRecords | Where-Object { $_.status -eq "done" }).Count
        archived_count  = @($threadRecords | Where-Object { $_.status -eq "archived" }).Count
        threads         = @($threadRecords)
    }
    $workstreamIndex = [pscustomobject]@{
        schema           = "codex-memory-hub.workstream-index.v1"
        generated_at     = $generatedAt
        project_root     = $ProjectRoot
        memory_root      = ".codex-memory"
        workstream_count = $workstreamRecords.Count
        workstreams      = @($workstreamRecords)
    }

    $threadIndexPath = Join-Path $systemRoot "thread-index.json"
    $workstreamIndexPath = Join-Path $systemRoot "workstream-index.json"
    Write-Utf8NoBom $threadIndexPath (ConvertTo-CleanJson $threadIndex 8)
    Write-Utf8NoBom $workstreamIndexPath (ConvertTo-CleanJson $workstreamIndex 8)

    Write-Host "Codex Memory Hub index"
    Write-Host "Project: $ProjectRoot"
    Write-Host "Threads: $($threadRecords.Count)"
    Write-Host "Workstreams: $($workstreamRecords.Count)"
    Write-Host "write: $(ConvertTo-RelativeMemoryPath $ProjectRoot $threadIndexPath)"
    Write-Host "write: $(ConvertTo-RelativeMemoryPath $ProjectRoot $workstreamIndexPath)"
    return 0
}

$ProjectRoot = Resolve-FullPath $Path
$MemoryRoot = Join-Path $ProjectRoot ".codex-memory"
$exitCode = 0

switch ($Command.ToLowerInvariant()) {
    "doctor" {
        $exitCode = Invoke-Doctor $ProjectRoot $MemoryRoot
    }
    "index" {
        $exitCode = Invoke-Index $ProjectRoot $MemoryRoot
    }
    "all" {
        $doctorCode = Invoke-Doctor $ProjectRoot $MemoryRoot
        Write-Host ""
        $indexCode = Invoke-Index $ProjectRoot $MemoryRoot
        if ($doctorCode -ne 0) {
            $exitCode = $doctorCode
        } else {
            $exitCode = $indexCode
        }
    }
}

exit $exitCode

param()

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$PsInit = Join-Path $RepoRoot "skill/codex-memory-hub/scripts/init_project_memory.ps1"
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-memory-hub-tests-" + [guid]::NewGuid().ToString("N"))

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

try {
    New-Item -ItemType Directory -Path $TempRoot | Out-Null

    $cleanProject = Join-Path $TempRoot "clean"
    New-Item -ItemType Directory -Path $cleanProject | Out-Null
    git -C $cleanProject init | Out-Null
    Invoke-InitPowerShell $cleanProject

    Assert-True (Test-Path -LiteralPath (Join-Path $cleanProject "AGENTS.md")) "clean init did not create AGENTS.md"
    Assert-True (Test-Path -LiteralPath (Join-Path $cleanProject ".codex-memory/threads")) "clean init did not create threads directory"
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $cleanProject ".codex-memory/threads/.gitkeep"))) "clean init should not create ignored .gitkeep files"
    Assert-True ((Get-Content -Raw -LiteralPath (Join-Path $cleanProject ".gitignore")) -match "(?m)^\.codex-memory/\r?$") "clean init did not gitignore .codex-memory/"

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

    $bashCommand = Get-Command bash -ErrorAction SilentlyContinue
    if ($bashCommand) {
        Push-Location $RepoRoot
        $shellRuntimePath = Join-Path $RepoRoot ".codex-memory-hub-test-runtime.sh"
        try {
            $shellRuntimeTests = @'
set -eu
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/legacy/docs/wiki"
printf '%s\n' "Overview only content" > "$tmp/legacy/docs/wiki/project-overview.md"
printf '%s\n' "Current status content" > "$tmp/legacy/docs/wiki/current-status.md"
sh skill/codex-memory-hub/scripts/init_project_memory.sh --path "$tmp/legacy" >/dev/null
test -d "$tmp/legacy/.codex-memory/threads"
test ! -e "$tmp/legacy/.codex-memory/threads/.gitkeep"
grep -q "Overview only content" "$tmp/legacy/.codex-memory/project.md"
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

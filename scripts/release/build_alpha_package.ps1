[CmdletBinding()]
param(
    [string]$Version = "0.1.4-alpha",
    [string]$GodotPath = "C:\Program Files\Godot\Godot_v4.3-stable_win64\Godot_v4.3-stable_win64.exe",
    [string]$RcEditPath = "C:\Tools\rcedit-x64.exe",
    [string]$CompanyName = "Open Game Stack",
    [string]$ProductName = "OGS Launcher",
    [string]$FileDescription = "Open Game Stack Launcher",
    [string]$InternalName = "OGS-Launcher.exe",
    [string]$OriginalFilename = "OGS-Launcher.exe",
    [string]$LegalCopyright = "Copyright (c) Open Game Stack",
    [switch]$SkipTests,
    [switch]$SkipZip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-GodotCommand {
    <#
    .SYNOPSIS
    Executes a Godot CLI command while preserving stderr output without
    triggering PowerShell native-command exceptions.
    .DESCRIPTION
    Godot tests intentionally emit parser errors to stderr for negative test
    coverage. This wrapper runs Godot through Start-Process with redirected
    stdout/stderr files so PowerShell does not treat expected stderr lines as
    terminating errors. Pass/fail is determined by process exit code.
    #>
    param(
        [string[]]$Arguments,
        [int]$TailLines = 0
    )

    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()
    $argumentString = ($Arguments | ForEach-Object {
        if ($_ -match '[\s"]') {
            '"' + ($_ -replace '"', '\"') + '"'
        }
        else {
            $_
        }
    }) -join ' '

    try {
        $process = Start-Process -FilePath $GodotPath -ArgumentList $argumentString -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath

        $allLines = @()
        if (Test-Path $stdoutPath) {
            $allLines += Get-Content -Path $stdoutPath
        }
        if (Test-Path $stderrPath) {
            $allLines += Get-Content -Path $stderrPath
        }

        if ($TailLines -gt 0) {
            $allLines | Select-Object -Last $TailLines | ForEach-Object { Write-Host $_ }
        }
        else {
            $allLines | ForEach-Object { Write-Host $_ }
        }

        return $process.ExitCode
    }
    finally {
        if (Test-Path $stdoutPath) {
            Remove-Item -Path $stdoutPath -Force
        }
        if (Test-Path $stderrPath) {
            Remove-Item -Path $stderrPath -Force
        }
    }
}

function Write-Step {
    <#
    .SYNOPSIS
    Writes a consistent progress line for OGS alpha packaging lifecycle steps.
    .DESCRIPTION
    OGS uses explicit lifecycle steps (test, export, package) so maintainers can
    verify the launcher artifact was built in a deterministic order.
    #>
    param([string]$Message)

    Write-Host "[OGS Alpha Build] $Message" -ForegroundColor Cyan
}

function Convert-ToWindowsVersion {
    <#
    .SYNOPSIS
    Converts a semantic-like version label into Windows file version format.
    .DESCRIPTION
    Windows file metadata expects 4 numeric parts. This function extracts up to
    the first 4 numeric components from labels such as 0.1.4-alpha and pads
    missing parts with zeros.
    #>
    param([string]$VersionLabel)

    $parts = [regex]::Matches($VersionLabel, "\d+") | ForEach-Object { $_.Value }
    if ($parts.Count -eq 0) {
        return "0.0.0.0"
    }

    $windowsParts = @($parts | Select-Object -First 4)
    while ($windowsParts.Count -lt 4) {
        $windowsParts += "0"
    }

    return ($windowsParts -join ".")
}

function Invoke-RcEditCommand {
    <#
    .SYNOPSIS
    Runs rcedit with explicit exit-code validation.
    .DESCRIPTION
    Centralizes error handling for executable resource updates so packaging
    fails fast if icon or metadata patching does not succeed.
    #>
    param([string[]]$Arguments)

    & $RcEditPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "rcedit failed with exit code $LASTEXITCODE for arguments: $($Arguments -join ' ')"
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$exportPresetPath = Join-Path $repoRoot "export_presets.cfg"
$artifactRoot = Join-Path $repoRoot "artifacts\alpha"
$stagingDir = Join-Path $artifactRoot ("OGS-Launcher-alpha-win64-" + $Version)
$zipPath = Join-Path $artifactRoot ("OGS-Launcher-alpha-win64-" + $Version + ".zip")

Write-Step "Repository root: $repoRoot"

if (-not (Test-Path $GodotPath)) {
    throw "Godot executable not found at: $GodotPath"
}

if (-not (Test-Path $RcEditPath)) {
    throw "rcedit executable not found at: $RcEditPath"
}

if (-not (Test-Path $exportPresetPath)) {
    throw "Missing export_presets.cfg at repo root. Open the project in Godot and create a Windows Desktop export preset named 'Windows Desktop'."
}

New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
if (Test-Path $stagingDir) {
    Remove-Item -Path $stagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

if (-not $SkipTests) {
    Write-Step "Running manifest test suite before packaging"
    $start = Get-Date
    $testExitCode = Invoke-GodotCommand -Arguments @("--headless", "--path", $repoRoot, "--script", "res://tests/test_runner.gd") -TailLines 12
    $elapsed = ((Get-Date) - $start).TotalSeconds

    if ($testExitCode -ne 0) {
        throw "Test suite failed with exit code $testExitCode after $elapsed seconds. Packaging aborted."
    }

    Write-Step ("Tests passed in " + [Math]::Round($elapsed, 2) + " seconds")
}
else {
    Write-Step "Skipping tests (requested)"
}

Write-Step "Exporting launcher executable"
$exportPath = Join-Path $stagingDir "OGS-Launcher.exe"
$exportExitCode = Invoke-GodotCommand -Arguments @("--headless", "--path", $repoRoot, "--export-release", "Windows Desktop", $exportPath)

if ($exportExitCode -ne 0) {
    throw "Godot export failed with exit code $exportExitCode"
}

if (-not (Test-Path $exportPath)) {
    throw "Export did not produce OGS-Launcher.exe in staging directory"
}

$iconPath = Join-Path $repoRoot "Images\logo.ico"
if (-not (Test-Path $iconPath)) {
    throw "Missing icon file required for Windows metadata patching: $iconPath"
}

$windowsVersion = Convert-ToWindowsVersion -VersionLabel $Version
Write-Step "Stamping executable icon and Windows metadata via rcedit"
Invoke-RcEditCommand -Arguments @($exportPath, "--set-icon", $iconPath)
Invoke-RcEditCommand -Arguments @($exportPath, "--set-file-version", $windowsVersion)
Invoke-RcEditCommand -Arguments @($exportPath, "--set-product-version", $windowsVersion)
Invoke-RcEditCommand -Arguments @($exportPath, "--set-version-string", "CompanyName", $CompanyName)
Invoke-RcEditCommand -Arguments @($exportPath, "--set-version-string", "ProductName", $ProductName)
Invoke-RcEditCommand -Arguments @($exportPath, "--set-version-string", "FileDescription", $FileDescription)
Invoke-RcEditCommand -Arguments @($exportPath, "--set-version-string", "InternalName", $InternalName)
Invoke-RcEditCommand -Arguments @($exportPath, "--set-version-string", "LegalCopyright", $LegalCopyright)
Invoke-RcEditCommand -Arguments @($exportPath, "--set-version-string", "FileVersion", $Version)
Invoke-RcEditCommand -Arguments @($exportPath, "--set-version-string", "ProductVersion", $Version)

$alphaReadme = @"
OGS Launcher Alpha Package
==========================

Version: $Version
Build Date (UTC): $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Quick Start:
1. Keep OGS-Launcher.exe and OGS-Launcher.pck in the same folder.
2. Run OGS-Launcher.exe.
3. Add or create a project with stack.json and ogs_config.json.

Notes:
- This is an alpha build intended for validation and feedback.
- Tools are managed through the launcher using OGS manifests.
"@

$alphaReadmePath = Join-Path $stagingDir "README_ALPHA.txt"
Set-Content -Path $alphaReadmePath -Value $alphaReadme -Encoding ASCII

if (-not $SkipZip) {
    Write-Step "Creating distributable zip"
    if (Test-Path $zipPath) {
        Remove-Item -Path $zipPath -Force
    }

    Compress-Archive -Path (Join-Path $stagingDir "*") -DestinationPath $zipPath -CompressionLevel Optimal

    if (-not (Test-Path $zipPath)) {
        throw "Zip creation failed: $zipPath"
    }

    Write-Step "Alpha package ready: $zipPath"
}
else {
    Write-Step "Skipping zip creation (requested)"
}

Write-Step "Build complete"
Write-Host "Staging directory: $stagingDir"
if (Test-Path $zipPath) {
    Write-Host "Zip artifact: $zipPath"
}

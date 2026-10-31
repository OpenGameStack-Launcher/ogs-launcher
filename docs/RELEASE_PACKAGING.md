# Release Packaging Guide (Windows)

This guide defines the repeatable process to produce downloadable OGS Launcher release packages and orchestrate releases via GitHub Actions.

## Goal

Produce a standalone ZIP package containing the launcher executable, bundled PCK, and support files for Windows x64 distribution, accompanied by an authenticating SHA-256 checksum file.

## Versioning Standard

OGS Launcher follows semantic versioning (`X.Y.Z`, such as `0.1.6` or `0.2.0`):
- Release tags follow the pattern `v<version>` (e.g., `v0.1.6`).
- Standard releases are published as "Latest" on GitHub Releases (dropping previous alpha designations and prerelease flags).
- Version strings are strictly verified to ensure clean semver syntax (`^[0-9]+\.[0-9]+\.[0-9]+$`).

## Prerequisites

- Windows 10/11 x64
- Godot 4.7.2 Stable executable installed at:
  - `C:\Program Files\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe` (or `Godot_v4.7.2-stable_win64.exe`)
- Godot 4.7.2 export templates installed in `$env:APPDATA\Godot\export_templates\4.7.2.stable\`
- Passing launcher test suite (`tests/test_runner.gd`)
- `rcedit-x64.exe` available locally (default path: `C:\Tools\rcedit-x64.exe`)
- Multi-size Windows icon file at `Images/logo.ico`

### Windows Icon and Metadata Stamping

The release packaging script performs deterministic post-export EXE patching with `rcedit`:
- Application icon (`Images/logo.ico`)
- Numeric 4-part Windows file and product version
- Version metadata strings (CompanyName, ProductName, FileDescription, InternalName, LegalCopyright, FileVersion, ProductVersion)

If `rcedit` or `Images/logo.ico` is missing, packaging aborts immediately by design.

## Source Control Policy for `export_presets.cfg`

`export_presets.cfg` is tracked in git because it defines build-critical export configuration:
- Preset name: exactly `Windows Desktop`
- Default export path: `artifacts/release/OGS-Launcher-win64/OGS-Launcher.exe`
- Icon wiring and binary formatting options
- Zero machine-specific paths, private keys, or credentials committed to source control

## Automated Workflows (GitHub Actions)

### 1. Continuous Integration (`.github/workflows/ci.yml`)

Runs automatically on every pull request targeting `main` and on push to `main` on `windows-latest`:
- Caches Godot 4.7.2 Stable, Windows export templates, and `rcedit-x64.exe`.
- Performs headless editor import (`godot --headless --editor --quit`).
- Runs full test suite (`godot --headless -s res://tests/test_runner.gd`).
- Runs packaging smoke check (`build_release_package.ps1 -Version 0.0.0-ci -SkipTests -SkipZip`).
- Validates executable export and metadata stamping.

### 2. Automated Release Publishing (`.github/workflows/release.yml`)

Triggered via `workflow_dispatch` on `main`:
1. Validates the semantic version input parameter and ensures git tag `v<version>` does not exist.
2. Runs the full test suite and builds the Windows package (`scripts/release/build_release_package.ps1 -Version <version>`).
3. Verifies `OGS-Launcher.exe` metadata, ZIP package integrity, and SHA-256 hash.
4. Uploads build artifacts.
5. In the gated publication step, creates and pushes git tag `v<version>`.
6. Publishes the Latest GitHub Release with attached `.zip` and `.zip.sha256` assets and release notes.

## Manual Local Build Command

Maintainers and developers can also build release packages locally from the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release\build_release_package.ps1 -Version 0.1.6
```

### Optional Flags

- Skip tests during local development:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release\build_release_package.ps1 -Version 0.1.6 -SkipTests
```

- Skip zip packaging (staging only):
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release\build_release_package.ps1 -Version 0.1.6 -SkipZip
```

- Explicit tool paths:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release\build_release_package.ps1 -Version 0.1.6 -GodotPath "C:\Custom\godot.exe" -RcEditPath "C:\Custom\rcedit-x64.exe"
```

## Package Outputs

Artifacts are output under `artifacts/release/`:
- Staging folder: `artifacts/release/OGS-Launcher-win64-<version>/`
- ZIP package: `artifacts/release/OGS-Launcher-win64-<version>.zip`
- Checksum file: `artifacts/release/OGS-Launcher-win64-<version>.zip.sha256`

Files included in the distribution:
- `OGS-Launcher.exe` (stamped with icon and version info)
- `OGS-Launcher.pck` (game package sidecar)
- `README.txt` (quick start instructions and repo reference)

## Metadata Verification

Verify executable metadata from PowerShell:

```powershell
$exe = "artifacts\release\OGS-Launcher-win64-<version>\OGS-Launcher.exe"
$v = (Get-Item $exe).VersionInfo
[PSCustomObject]@{
  FileVersion     = $v.FileVersion
  ProductVersion  = $v.ProductVersion
  CompanyName     = $v.CompanyName
  ProductName     = $v.ProductName
  FileDescription = $v.FileDescription
} | Format-List
```

## Checksum Verification

Verify the SHA-256 checksum of the package:

```powershell
$zip = "artifacts\release\OGS-Launcher-win64-<version>.zip"
(Get-FileHash -Path $zip -Algorithm SHA256).Hash.ToLower()
Get-Content "artifacts\release\OGS-Launcher-win64-<version>.zip.sha256"
```

## Release History

| Version | Tag | Date | Distribution |
|---------|-----|------|--------------|
| 0.1.0-alpha | v0.1.0-alpha | 2026-03-13 | Pre-release |
| 0.1.1-alpha | v0.1.1-alpha | 2026-03-20 | Pre-release |
| 0.1.2-alpha | v0.1.2-alpha | 2026-03-27 | Pre-release |
| 0.1.3-alpha | v0.1.3-alpha | 2026-04-03 | Pre-release |
| 0.1.4-alpha | v0.1.4-alpha | 2026-04-10 | Pre-release |
| 0.1.5-alpha | v0.1.5-alpha | 2026-04-17 | Pre-release |
| 0.1.6 | v0.1.6 | TBD | Latest (Full Release) |

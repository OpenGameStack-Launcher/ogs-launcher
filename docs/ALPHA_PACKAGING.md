# Alpha Packaging Guide (Windows)

This guide defines the simplest repeatable process to produce a downloadable OGS Launcher alpha package.

## Goal

Produce a single ZIP artifact containing the launcher executable and support files for alpha distribution.

## Prerequisites

- Windows 10/11 x64
- Godot 4.7.2 Stable executable installed at:
  - `C:\Program Files\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64.exe`
- Godot 4.7.2 export templates installed (Editor -> Manage Export Templates)
- Existing launcher test suite passing
- `rcedit-x64.exe` available locally (default script path: `C:\Tools\rcedit-x64.exe`)
- Multi-size Windows icon file at `Images/logo.ico`

### Windows Icon and Metadata Stamping

The packaging script now performs explicit post-export EXE patching with `rcedit`, including:

- EXE icon (`Images/logo.ico`)
- Numeric Windows file/product version
- Version strings (company, product, description, and release labels)

If `rcedit` or `Images/logo.ico` is missing, the build fails fast by design.

Note: Godot may still show an Export-panel warning if Editor Settings do not have `Export -> Windows -> rcedit` configured. The script-level stamping is the authoritative build step used for alpha packaging.

## One-Time Setup: Export Preset

Godot export requires a local `export_presets.cfg` file in the repo root.

### Source Control Policy

`export_presets.cfg` is tracked in git because it defines build-critical export behavior (preset name, export options, icon wiring, and compatibility flags) that must remain consistent across machines.

Keep local-only values out of committed presets whenever possible:

- Do not commit machine-specific tool paths, signing identities, or personal metadata.
- Keep optional signing fields empty in the shared preset unless the team adopts a shared signing workflow.
- If a local machine needs temporary tweaks, revert those local-only values before committing.

1. Open `project.godot` in Godot 4.7.2.
2. Open **Project -> Export**.
3. Add preset: **Windows Desktop**.
4. Keep preset name exactly: `Windows Desktop`.
5. Choose output executable name: `OGS-Launcher.exe` (path is overridden by script).
6. Save export presets.

## Build Command

From repo root (`ogs-launcher`):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release\build_alpha_package.ps1 -Version 0.1.4-alpha
```

### Optional Flags

- Skip tests:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release\build_alpha_package.ps1 -Version 0.1.4-alpha -SkipTests
```

- Skip zip (staging only):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release\build_alpha_package.ps1 -Version 0.1.4-alpha -SkipZip
```

## Outputs

Artifacts are generated under:

- Staging folder: `artifacts/alpha/OGS-Launcher-alpha-win64-<version>/`
- ZIP package: `artifacts/alpha/OGS-Launcher-alpha-win64-<version>.zip`

Expected files include:

- `OGS-Launcher.exe`
- `OGS-Launcher.pck` (if exported as sidecar PCK by Godot preset)
- `README_ALPHA.txt`

## Metadata Verification

After building, verify EXE metadata from PowerShell:

```powershell
$exe = "C:\Projects\ogs-launcher\artifacts\alpha\OGS-Launcher-alpha-win64-<version>\OGS-Launcher.exe"
$v = (Get-Item $exe).VersionInfo
[PSCustomObject]@{
  FileVersion     = $v.FileVersion
  ProductVersion  = $v.ProductVersion
  CompanyName     = $v.CompanyName
  ProductName     = $v.ProductName
  FileDescription = $v.FileDescription
} | Format-List
```

If Explorer still shows the old icon after a successful build, test with the new versioned artifact path first and then refresh icon cache (unpin/re-pin shortcuts or restart Explorer).

## Release Checklist (Minimal Alpha)

1. Run package script with a new version string.
2. Smoke test launch from staging folder.
3. Create the GitHub Release and upload the ZIP using the GitHub CLI (`gh`):

```powershell
gh release create v<version> `
  "artifacts\alpha\OGS-Launcher-alpha-win64-<version>.zip" `
  --repo OpenGameStack-Launcher/ogs-launcher `
  --title "OGS Launcher v<version>" `
  --notes "Release notes here..." `
  --prerelease
```

If `gh` is not installed: `winget install --id GitHub.cli`
Authenticate before first use: `gh auth login`

4. Update website download links to point to the new release tag URL:
  - `https://github.com/OpenGameStack-Launcher/ogs-launcher/releases/tag/v<version>`
   - Note: Pre-releases are **not** returned by `/releases/latest` — always use the explicit tag URL.

## Published Releases

| Version | Date | Status |
|---------|------|--------|
| v0.1.0-alpha | 2026-03-13 | Pre-release ✅ |

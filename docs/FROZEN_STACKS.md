# OGS Tool Catalog

## Overview

This document records the **Tool Catalog** - the authoritative list of tools available for download through the OGS Launcher. The catalog is hosted in the [ogs-frozen-stacks](https://github.com/OpenGameStack-Launcher/ogs-frozen-stacks) GitHub repository and distributed via a `repository.json` manifest.

**Important Terminology:**
- **Tool Catalog** = The remote `repository.json` listing available tools (what this document describes)
- **Frozen Stack** = A per-project `ogs_stack.json` specifying version-pinned tools (see [Design_Doc.md](Design_Doc.md#terminology--architecture))

## Tool Catalog Contents

The catalog lists every tool **version** available for download; a project's
`ogs_stack.json` pins exactly one version per tool. The catalog currently offers:

- **Godot Engine:** 4.3 (v1.0, stable, hardened build), 4.7.2 (v2.0, stable, hardened build)
- **Blender:** 4.5.7 (v1.0, stable), 5.2 (v2.0, stable)
- **Krita:** 5.2.15 (v1.0, stable), 5.3.3 (v2.0, stable)
- **Audacity:** 3.7.7 (v1.0, stable), 3.7.8 (v2.0, stable)
- **GIMP:** 3.2.4 (v2.0, stable) - added in the v2.0 catalog update
- **PortableGit:** 2.56.0.4 (v3.0, stable) - added in the v3.0 catalog update under the "Code" category
- **VSCodium:** 1.143.17232 (v3.0, stable) - added in the v3.0 catalog update under the "Code" category

> The **OGS Launcher application itself** is built with Godot 4.7.2 - see
> [copilot-instructions.md](../.github/copilot-instructions.md). That is
> independent of which Godot version(s) a *project* chooses to freeze via
> `ogs_stack.json`; both 4.3 and 4.7.2 remain available to end users.

## Remote Repository

- **Repository:** https://github.com/OpenGameStack-Launcher/ogs-frozen-stacks
- **Release Tags:** v1.0 (original four tools), v2.0 (adds GIMP and newer tool versions), v3.0 (adds PortableGit and VSCodium in the Code category)
- **Manifest URL:** https://raw.githubusercontent.com/OpenGameStack-Launcher/ogs-frozen-stacks/main/repository.json

## Code Tool Integration and Portable Wiring

In Frozen Stacks v3.0, code editing and version control tools operate with specialized portable semantics:
- **Project-Rooted Git Bash:** Launching Git automatically specifies `--cd=<project_dir>` so the terminal opens directly at the project root directory.
- **Workspace-Rooted VSCodium:** Launching VSCodium passes the project directory as the workspace folder, with optional target file support.
- **Automatic Portable Git Detection in VSCodium:** When a project includes both VSCodium and Git in `ogs_stack.json`, launching VSCodium checks for the presence of portable Git in the Central Library. If found, the launcher automatically injects or updates `git.path` (`<git_tool_dir>/cmd/git.exe`) and `git.enabled: true` in `<project_dir>/.vscode/settings.json`, preserving existing user settings.
- **Air-Gap Telemetry Suppression:** When offline enforcement is active, launching VSCodium automatically appends `--disable-telemetry` to suppress outbound telemetry.
- **Scaffolding Semantics:** Code category tools operate directly on project code and root directories, skipping the creation of empty `assets/Code/` folders during tool addition.

## How It Works

1. **Discovery:** The Launcher fetches `repository.json` from the remote URL on startup (with offline fallback).
2. **Hydration:** When a user downloads a tool, the Launcher:
   - Downloads the archive from the GitHub Release URL specified in the manifest
   - Verifies the SHA-256 hash matches the manifest entry
   - Extracts the tool to the Central Library (`%LOCALAPPDATA%/OGS/Library/[tool_id]/[version]/`)
3. **Project Usage:** Projects reference these tools via their `ogs_stack.json` manifests, creating a "frozen stack" for that specific project.

## Maintenance Notes

- Tool versions are pinned to ensure reproducibility in air-gapped environments.
- Updates to the catalog should be reviewed and tested before publishing a new `repository.json`.
- Each tool entry must include a SHA-256 hash for integrity verification.
- For local/offline distribution, the same `repository.json` schema is used with local mirror paths.

## See Also

- [MIRROR_SCHEMA.md](MIRROR_SCHEMA.md) - Schema documentation for `repository.json`
- [Design_Doc.md](Design_Doc.md#terminology--architecture) - Full architecture explanation

Last updated: October 30, 2026

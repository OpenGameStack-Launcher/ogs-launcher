# OGS Tool Catalog

## Overview

This document records the **Tool Catalog**—the authoritative list of tools available for download through the OGS Launcher. The catalog is hosted in the [ogs-frozen-stacks](https://github.com/OpenGameStack-Launcher/ogs-frozen-stacks) GitHub repository and distributed via a `repository.json` manifest.

**Important Terminology:**
- **Tool Catalog** = The remote `repository.json` listing available tools (what this document describes)
- **Frozen Stack** = A per-project `stack.json` specifying version-pinned tools (see [Design_Doc.md](Design_Doc.md#terminology--architecture))

## Standard Profile (v1.0)

The following tools are currently available in the OGS Tool Catalog:

- **Godot Engine:** 4.3 (stable, hardened build)
- **Blender:** 4.5.7 (stable)
- **Krita:** 5.2.15 (stable)
- **Audacity:** 3.7.7 (stable)

## Remote Repository

- **Repository:** https://github.com/OpenGameStack-Launcher/ogs-frozen-stacks
- **Release Tag:** v1.0
- **Manifest URL:** https://raw.githubusercontent.com/OpenGameStack-Launcher/ogs-frozen-stacks/main/repository.json

## How It Works

1. **Discovery:** The Launcher fetches `repository.json` from the remote URL on startup (with offline fallback).
2. **Hydration:** When a user downloads a tool, the Launcher:
   - Downloads the archive from the GitHub Release URL specified in the manifest
   - Verifies the SHA-256 hash matches the manifest entry
   - Extracts the tool to the Central Library (`%LOCALAPPDATA%/OGS/Library/[tool_id]/[version]/`)
3. **Project Usage:** Projects reference these tools via their `stack.json` manifests, creating a "frozen stack" for that specific project.

## Maintenance Notes

- Tool versions are pinned to ensure reproducibility in air-gapped environments.
- Updates to the catalog should be reviewed and tested before publishing a new `repository.json`.
- Each tool entry must include a SHA-256 hash for integrity verification.
- For local/offline distribution, the same `repository.json` schema is used with local mirror paths.

## See Also

- [MIRROR_SCHEMA.md](MIRROR_SCHEMA.md) — Schema documentation for `repository.json`
- [Design_Doc.md](Design_Doc.md#terminology--architecture) — Full architecture explanation

Last updated: March 13, 2026

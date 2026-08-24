# Mirror Repository Schema

## Overview

A mirror is a portable bundle of tool archives. The launcher reads a `repository.json` file to discover which tools and versions are available.

This schema supports both air-gapped local mirrors (archive paths) and remote repositories (archive URLs).

## File Location

```
mirror_root/
├── repository.json
└── tools/
    ├── godot/4.7.2/godot_4.7.2_win64.zip
    ├── blender/4.2/blender_4.2_win64.zip
    ├── krita/5.2/krita_5.2_win64.zip
    └── audacity/3.7/audacity_3.7_win64.zip
```

## Default Mirror Root

- Windows: `%LOCALAPPDATA%/OGS/Mirror`
- Linux/macOS: `~/.config/ogs-launcher/mirror`

## Schema Definition

### Root Fields

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `schema_version` | Integer | Yes | Must be `1`. Future versions may extend this schema. |
| `mirror_name` | String | Yes | Human-readable mirror name (e.g., "OGS Standard Profile"). |
| `tools` | Array | Yes | Array of tool entries. Must contain at least one entry. |

### Tool Entry Fields

| Field | Type | Required | Description |
|------|------|----------|-------------|
| `id` | String | Yes | Tool identifier (e.g., `"godot"`, `"blender"`). |
| `version` | String | Yes | Tool version (e.g., `"4.7.2"`). |
| `category` | String | No | Tool category for UI organization (e.g., `"Engine"`, `"2D"`, `"3D"`, `"Audio"`). Launcher provides fallback mapping if omitted. |
| `archive_path` | String | Conditional | Relative path to the tool archive inside a local mirror. Required if `archive_url` is not provided. |
| `archive_url` | String | Conditional | Full URL to a remote archive. Required if `archive_path` is not provided. |
| `info_url` | String | No | Optional website URL describing the tool or version, such as a release page. |
| `sha256` | String | Yes | SHA-256 checksum (64 lowercase hex). Required for all tool archives. |
| `size` | Integer | No | Archive size in bytes (legacy field). |
| `size_bytes` | Integer | No | Archive size in bytes (preferred). |

## Example

```json
{
  "schema_version": 1,
  "mirror_name": "OGS Standard Profile",
  "tools": [
    {
      "id": "godot",
      "version": "4.7.2",
      "category": "Engine",
      "archive_path": "tools/godot/4.7.2/godot_4.7.2_win64.zip",
      "info_url": "https://godotengine.org/releases/4.7.2/",
      "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
      "size_bytes": 123456789
    },
    {
      "id": "blender",
      "version": "4.2",
      "category": "3D",
      "archive_path": "tools/blender/4.2/blender_4.2_win64.zip",
      "sha256": "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789",
      "size_bytes": 987654321
    }
  ]
}
```

### Remote Repository Example

```json
{
  "schema_version": 1,
  "mirror_name": "OGS Tool Catalog",
  "tools": [
    {
      "id": "godot",
      "version": "4.7.2",
      "category": "Engine",
      "archive_url": "https://github.com/OpenGameStack-Launcher/ogs-frozen-stacks/releases/download/v1.0/godot-4.7.2-win64.zip",
      "info_url": "https://godotengine.org/releases/4.7.2/",
      "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
      "size_bytes": 123456789
    }
  ]
}
```

## Validation Rules

1. `schema_version` must be integer `1`.
2. `mirror_name` must be a non-empty string.
3. `tools` must be a non-empty array of objects.
4. Each tool entry must include `id`, `version`, and one of `archive_path` or `archive_url`.
5. `category` is optional. If provided, it must be a non-empty string.
6. `info_url` is optional. If provided, it must be a non-empty string.
7. `archive_path` must be a relative path inside the mirror root (no absolute paths or `..`).
8. `sha256` is required and must be 64 lowercase hex characters.
9. If `size` or `size_bytes` is provided, it must be an integer greater than `0`.

## Tool Categories

The launcher organizes tools by category for UI presentation. Supported categories:

- **Engine**: Game engines and runtime environments (e.g., Godot)
- **2D**: 2D art, texture, and UI tools (e.g., Krita)
- **3D**: 3D modeling and animation tools (e.g., Blender)
- **Audio**: Audio editing and processing tools (e.g., Audacity)

If the `category` field is omitted, the launcher provides fallback mappings:

| Tool ID | Default Category |
|---------|------------------|
| `godot` | Engine |
| `blender` | 3D |
| `krita` | 2D |
| `audacity` | Audio |

New tools without a category field will display as "Unknown" in the UI.

## Operational Behavior

- The launcher reads `repository.json` from a local mirror root or remote repository URL.
- Tool archives are verified by `sha256` when present.
- Archives are extracted into the central library at `%LOCALAPPDATA%/OGS/Library/` (Windows) or `~/.config/ogs-launcher/library` (Linux/macOS).
- Remote repositories require network access and are blocked in offline mode.

---

Last updated: February 20, 2026

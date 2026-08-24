# Stack Manifest Schema

## Overview

A `stack.json` file defines the exact versions and paths of the tools required to build and run an OGS project. It is the "environment artifact"—the single source of truth for reproducibility across different machines, teams, and time.

## File Location

Every OGS project has a `stack.json` at its repository root:

```
my-game/
├── stack.json          <- Defines the frozen stack
├── game/
│   ├── project.godot
│   └── scenes/
└── tools/              <- Portable copies of tool binaries (optional in Provisioning Mode)
    ├── godot/
    ├── blender/
    ├── krita/
    └── audacity/
```

## Schema Definition

### Root Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schema_version` | Integer | Yes | Must be `1`. Increments for breaking changes to the manifest format. |
| `stack_name` | String | Yes | Human-readable name (e.g., "OGS Standard Profile"). Non-empty. |
| `tools` | Array | Yes | Array of tool objects. Must have at least one tool. |

### Tool Object Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | String | Yes | Unique tool identifier (e.g., `"godot"`, `"blender"`). Used in logs and UI. |
| `version` | String | Yes | Version string (e.g., `"4.7.2"`, `"4.2"`). No whitespace. |
| `path` | String | **No** | **(Optional)** Relative path from project root (e.g., `"tools/godot/Godot.exe"`). If omitted, launcher resolves executable from central library at `[LIBRARY_ROOT]/[id]/[version]/`. |
| `sha256` | String | No | SHA-256 checksum (lowercase hex, 64 chars). Used in Sovereign Mode to verify binary integrity. |

## Example

```json
{
  "schema_version": 1,
  "stack_name": "OGS Standard Profile",
  "tools": [
    {
      "id": "godot",
      "version": "4.7.2"
    },
    {
      "id": "blender",
      "version": "4.2"
    },
    {
      "id": "krita",
      "version": "5.2"
    },
    {
      "id": "audacity",
      "version": "3.7"
    }
  ]
}
```

**Note:** The `path` field is optional. When omitted, the launcher resolves tool executables from the central library directory (`%LOCALAPPDATA%\OGS\Library\[tool_id]\[version]\`). This is the recommended approach for most projects.

### Legacy Format (Project-Relative Paths)

For projects that bundle tools within their repository:

```json
{
  "schema_version": 1,
  "stack_name": "Self-Contained Project",
  "tools": [
    {
      "id": "godot",
      "version": "4.7.2",
      "path": "tools/godot/Godot_v4.7.2-stable_win64.exe",
      "sha256": "abc123...xyz789"
    },
    {
      "id": "blender",
      "version": "4.2",
      "path": "tools/blender/blender.exe",
      "sha256": "def456...uvw012"
    }
  ]
}
```

## Validation Rules

The OGS Launcher enforces the following:

1. **Schema Version Must Match**: Only `schema_version: 1` is currently supported. Future versions may add new fields.
2. **No Missing Required Fields**: `schema_version`, `stack_name`, `tools` are mandatory.
3. **No Empty Arrays**: The `tools` array must contain at least one tool.
4. **All Tools Must Be Valid**: Each tool entry must have `id` and `version` (non-empty). The `path` field is optional.
5. **SHA-256 Format** (if present): Must be exactly 64 lowercase hex characters.
6. **Path Format** (if present): If provided, `path` must be non-empty and project-relative (not absolute).

### Validation Error Codes

When a manifest fails validation, the launcher reports specific error codes:

| Error Code | Meaning |
|-----------|---------|
| `schema_version_missing` | Field not present |
| `schema_version_not_int` | Field is not an integer |
| `schema_version_unsupported` | Version number is not 1 |
| `stack_name_missing` | Field not present |
| `stack_name_not_string` | Field is not a string |
| `stack_name_empty` | String is blank after trimming |
| `tools_missing` | Field not present |
| `tools_not_array` | Field is not an array |
| `tools_empty` | Array has no entries |
| `tool_not_object:INDEX` | Entry at INDEX is not a dictionary |
| `tool_id_missing:INDEX` | ID missing at INDEX |
| `tool_id_invalid:INDEX` | ID is empty or not a string at INDEX |
| `tool_version_missing:INDEX` | Version missing at INDEX |
| `tool_version_invalid:INDEX` | Version is empty or not a string at INDEX |
| `tool_path_invalid:INDEX` | Path provided but empty or not a string at INDEX |
| `tool_sha256_invalid:INDEX` | SHA-256 format invalid at INDEX |

## Operational Modes

### Provisioning Mode (NIPR / Connected)

The launcher detects missing tools in the `tools/` directory and fetches binaries from mirrors or package repositories. The contractor updates `stack.json` and commits it to version control alongside binaries (or via Git LFS).

### Sovereign Mode (SIPR / Air-Gapped)

The launcher verifies that tool binaries in `tools/` match the SHA-256 checksums in `stack.json`. If offline_mode is enforced, the launcher blocks external network access and launches tools from the frozen stack only.

## Best Practices

1. **Version Consistency**: Use stable, long-term support versions (e.g., Blender 4.2 LTS).
2. **Relative Paths Only**: Ensure paths work on Windows and Unix by using forward slashes and relative notation.
3. **Commit the Manifest**: Always include `stack.json` in version control.
4. **Compute Checksums**: Use standard SHA-256 tools to verify binaries before adding checksums.
5. **Document Custom Tools**: If adding tools beyond the standard profile, document the reasoning and maintenance plan.

## Generation

Use `StackGenerator` to create new manifests programmatically:

```gdscript
var manifest = StackGenerator.create_default()
StackGenerator.save_to_file(manifest, "res://stack.json")
```

Or load and inspect existing manifests:

```gdscript
var manifest = StackManifest.load_from_file("res://stack.json")
if manifest.is_valid():
    for tool in manifest.tools:
        print("%s v%s" % [tool["id"], tool["version"]])
```

## Migration Notes

### Path Field Now Optional (February 2026)

Starting with this release, the `path` field in tool entries is **optional**. When omitted, the launcher automatically resolves tool executables from the central library directory (`%LOCALAPPDATA%\OGS\Library\[tool_id]\[version]\`).

**Benefits:**
- Simpler `stack.json` files (just `id` and `version`)
- No need to maintain project-relative paths
- Tools are shared across all projects via the central library
- Hydration workflow (Repair Environment) automatically populates the library

**Migration:**
- Existing `stack.json` files with `path` fields continue to work (backward compatible)
- New projects generated by `StackGenerator` omit the `path` field by default
- To migrate existing projects, simply remove the `path` field from each tool entry

**Example migration:**

Before:
```json
{
  "id": "godot",
  "version": "4.7.2",
  "path": "tools/godot/Godot_v4.7.2-stable_win64.exe"
}
```

After:
```json
{
  "id": "godot",
  "version": "4.7.2"
}
```


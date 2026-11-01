# OGS Config Schema

## Overview

An `ogs_config.json` file controls launcher behavior, especially air-gap enforcement and offline mode. This is the user/system configuration file, separate from the project manifest (`ogs_stack.json`).

## File Location

Typically located at the project root or in a user config directory:

```
my-game/
├── ogs_stack.json     <- Project manifest (frozen stack definition)
├── ogs_config.json     <- Launcher config (air-gap flags, user preferences)
└── game/
```

Alternatively, for system-wide configuration:
```
~/.config/ogs/ogs_config.json    (Linux)
%APPDATA%\ogs\ogs_config.json    (Windows)
```

## Schema Definition

### Root Fields

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `schema_version` | Integer | 1 | No | Must be `1` if present. |
| `offline_mode` | Boolean | `false` | No | User-triggered air-gap activation. When true, disables network features. |
| `force_offline` | Boolean | `false` | No | Immutable flag set during "Seal for Delivery". When true, enforces offline mode. |
| `allowed_hosts` | Array[String] | `[]` | No | Optional host allowlist applied by launcher socket policy. Empty+no ports falls back to secure localhost defaults. |
| `allowed_ports` | Array[Integer] | `[]` | No | Optional port allowlist (`1..65535`) applied by launcher socket policy. |

## Example

### Minimal Config (Development)
```json
{
  "schema_version": 1,
  "offline_mode": false,
  "force_offline": false,
  "allowed_hosts": ["github.com", "objects.githubusercontent.com"],
  "allowed_ports": [443]
}
```

### Offline Mode (User Preference)
```json
{
  "schema_version": 1,
  "offline_mode": true,
  "force_offline": false
}
```

### Sealed for Government (Immutable)
```json
{
  "schema_version": 1,
  "offline_mode": false,
  "force_offline": true
}
```

## Validation Rules

1. **All fields are optional** - Missing config file returns defaults with no error
2. **Boolean-only for flags** - `offline_mode` and `force_offline` must be booleans if present
3. **Allowlist host format** - `allowed_hosts` must be an array of strings if present
4. **Allowlist port format** - `allowed_ports` must be an array of integers if present
5. **Allowlist port range** - each `allowed_ports` entry must be between `1` and `65535`
6. **Schema version** - Only `1` is supported currently

### Validation Error Codes

| Error Code | Meaning |
|-----------|---------|
| `config_file_unreadable` | File I/O failed (file exists but cannot be read) |
| `config_json_invalid` | JSON parsing failed |
| `config_root_not_object` | Root must be a dictionary |
| `schema_version_not_int` | schema_version is not an integer |
| `schema_version_unsupported` | schema_version is not 1 |
| `offline_mode_not_bool` | offline_mode is not a boolean |
| `force_offline_not_bool` | force_offline is not a boolean |
| `allowed_hosts_not_array` | allowed_hosts is not an array |
| `allowed_hosts_contains_non_string` | allowed_hosts has non-string entries |
| `allowed_ports_not_array` | allowed_ports is not an array |
| `allowed_ports_contains_non_int` | allowed_ports has non-integer entries |
| `allowed_ports_out_of_range` | allowed_ports contains values outside 1..65535 |

## Operational Semantics

### Default Behavior (No Config File)

```gdscript
var config = OgsConfig.load_from_file("res://ogs_config.json")
# Result: offline_mode=false, force_offline=false, no errors
```

When importing an existing project via **Add Local Project** or selecting a tracked project that only contains `ogs_stack.json`, the launcher automatically writes a default `ogs_config.json` to the project root with standard settings (`offline_mode=false`, `force_offline=false`). This allows developers to clone repositories without local configuration files and begin development immediately.

### User-Triggered Air-Gap

The user enables offline mode through the launcher UI (in the Project Details tab under Project Offline Policy for the active project):

```json
{
  "offline_mode": true
}
```

The launcher then:
- Disables Asset Library and Extensions UI
- Blocks all external network sockets
- Injects tool configs to disable their network features

**Scope Note:** Offline enforcement targets the launcher and editor tooling only. It does not modify project runtime networking, so exported applications can still use internal network features when required.

### Sealed Project (Government Deployment)

During "Seal for Delivery," the contractor's launcher writes:

```json
{
  "force_offline": true
}
```

When the government receives the project, the launcher detects `force_offline=true` and **immediately enforces offline mode**, regardless of the physical network status.

## Best Practices

1. **Commit ogs_config.json if using force_offline** - Ensures sealed projects stay sealed across deployments
2. **Do not hardcode network URLs in tools** - Launcher overrides tool configs to enforce offline mode
3. **Test with offline mode enabled** - Verify your project works in air-gapped environments before release
4. **Document deployment mode** - Clearly indicate whether a project is development or sealed/sovereign

## Detection & Enforcement

The launcher determines operational mode by checking:

```gdscript
if config.is_offline():  # offline_mode OR force_offline
    # Enforce Sovereign Mode
    disable_network_ui()
    block_external_sockets()
    inject_tool_configs()

```

## Logging

The launcher writes structured JSON logs to:

- `user://logs/ogs_launcher.log`

Rotation:
- Size-based rotation at ~1 MB
- Up to 3 backup files (`ogs_launcher.log.1` to `.3`)

Logs are intended for operational events and avoid sensitive data such as full filesystem paths.

## Launcher Global Settings (ogs_launcher_settings.json)

In addition to per-project configuration (`ogs_config.json`), the launcher persists global user settings in `ogs_launcher_settings.json` under `OS.get_user_data_dir()`.

**Note on Scope:** Project-specific offline policy flags (`offline_mode` and `force_offline`) reside strictly within each project's local `ogs_config.json` and are configured through the **Project Details** tab on the Projects page. The global Settings page (`PageSettings`) manages launcher-wide system defaults.

### Settings Fields

| Field | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `projects_root` | String | `""` | No | Custom primary directory where new project scaffolds are created. When empty, resolves to `%USERPROFILE%\OGS_Projects` or `$HOME/OGS_Projects`. |
| `mirror_root` | String | `""` | No | Optional local filesystem mirror root containing pre-downloaded tool archives. |
| `remote_repository_url` | String | Standard catalog URL | No | Remote URL pointing to the master `repository.json` catalog. |
| `timestamp` | Integer | System ticks | No | Millisecond timestamp recording when settings were last saved. |

### Example ogs_launcher_settings.json

```json
{
  "projects_root": "D:/GameProjects",
  "mirror_root": "E:/OGS_Mirror",
  "remote_repository_url": "https://raw.githubusercontent.com/OpenGameStack-Launcher/ogs-frozen-stacks/main/repository.json",
  "timestamp": 1740924000000
}
```

## Future Extensions (Phase 2+)

Future versions may add:
- `cache_dir` - Custom cache location for offline downloads
- `log_file` - Path to persistent logs for debugging
- `tool_config_overrides` - Per-tool environment variable injection

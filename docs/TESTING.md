# Testing Guide

## Overview

The OGS Launcher uses a comprehensive test suite to ensure reliability and maintainability. Tests are categorized into **unit tests** (pure logic, no UI) and **scene tests** (integration tests with UI nodes).

For **manual user-facing tests** (UI workflows with sample projects), see [MANUAL_TESTING.md](MANUAL_TESTING.md).

## Running Tests

Execute the full test suite in headless mode:

**PowerShell (Windows) - Recommended:**
```powershell
$start = Get-Date; & "C:\Program Files\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64.exe" --headless --script res://tests/test_runner.gd 2>&1 | Select-Object -Last 10; $elapsed = ((Get-Date) - $start).TotalSeconds; Write-Host "Exit code: $LASTEXITCODE (execution time: $elapsed seconds)"
```

This command:
- Captures stdout and stderr with `2>&1`
- Pipes output to force proper handling
- Measures and displays execution time
- Shows the last 10 lines of output plus exit code

**Bash (Linux/macOS):**
```bash
godot --headless --script res://tests/test_runner.gd
```

Expected output:
```
TestRunner: Test library isolated to C:\Users\[user]\AppData\Local/OGS_TEST/Library
tests passed: 327
tests failed: 0
TestRunner: Cleaned up test library at C:\Users\[user]\AppData\Local/OGS_TEST/Library
```

The test runner automatically exits when complete (~3.4-4.6 seconds) without requiring manual termination.

**Notes:**
- You may see `ERROR: Parse JSON failed` messages during test runs. These are expected from tests that validate invalid JSON handling.
- The test runner uses `_process()` callback to ensure proper scene tree initialization before calling `quit()`, allowing clean process termination on all platforms.

## Test Library Isolation

**Important:** Tests use a completely isolated library directory to prevent any conflicts with production data or other running instances of OGS Launcher.

### How It Works

1. **test_runner.gd** automatically sets environment variable `OGS_LIBRARY_ROOT` to an isolated test path before running any tests
2. **PathResolver.get_library_root()** checks for this environment variable first:
   - If `OGS_LIBRARY_ROOT` is set → all tests use that path
   - If not set → falls back to normal production paths
3. All tests operate within this isolated directory (typically `LOCALAPPDATA/OGS_TEST/Library` on Windows)
4. After all tests complete, **test_runner.gd automatically cleans up** the entire test library directory

### Production Safety

✅ **Your production `LOCALAPPDATA/OGS/Library` is never touched by tests**
✅ **Can safely run tests while the real OGS Launcher is running**
✅ **No resource conflicts or data loss risk**
✅ **Each test run starts with a clean slate and leaves no residue**

### Custom Test Library Path

For advanced scenarios, you can override the test library path with your own:

**PowerShell:**
```powershell
$env:OGS_LIBRARY_ROOT = "C:\MyTestLibrary"
& "C:\Program Files\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64.exe" --headless --script res://tests/test_runner.gd
```

**Bash:**
```bash
export OGS_LIBRARY_ROOT=/tmp/ogs_test_lib
godot --headless --script res://tests/test_runner.gd
```

The test runner will clean up this custom path after tests complete.

## Test Categories

### Unit Tests (Fast, No Scene)

Unit tests validate pure logic without instantiating UI nodes. These run quickly and focus on data validation, parsing, and business logic.

**Current unit test suites (23 total, 205 tests):**

- **[tests/stack_manifest_tests.gd](tests/stack_manifest_tests.gd)** — Validates `stack.json` loading, schema compliance, and error codes.
  - Valid manifests pass
  - Required fields enforced (schema_version, stack_name, tools)
  - Float schema_version handling (1.0 accepted, 1.5 rejected)
  - Invalid JSON/types rejected
  - SHA-256 checksum validation
  - Tool entry validation

- **[tests/ogs_config_tests.gd](tests/ogs_config_tests.gd)** — Validates `ogs_config.json` loading and offline mode detection.
  - Valid configs load correctly
  - Missing files return defaults (no error)
  - Float schema_version handling
  - Invalid JSON rejected
  - Boolean type enforcement for offline flags
  - Allowlist parsing and validation (`allowed_hosts`, `allowed_ports`)

- **[tests/stack_generator_tests.gd](tests/stack_generator_tests.gd)** — Validates manifest generation and serialization.
  - Default manifest contains standard tools
  - JSON pretty-printing (newlines, tabs)
  - JSON compact mode (no whitespace)
  - save_to_file() writes and returns true

- **[tests/tool_launcher_tests.gd](tests/tool_launcher_tests.gd)** — Validates tool process spawning logic.
  - Missing/empty path fields rejected
  - Invalid project directory rejected
  - Nonexistent tool executable rejected
  - Tool-specific arguments built correctly (Godot, Blender, unknown)
  - Absolute paths used as-is (no project directory joining)
  - Relative paths joined with project directory

- **[tests/offline_enforcer_tests.gd](tests/offline_enforcer_tests.gd)** — Validates offline enforcement state and network guard behavior.
  - Null config resets enforcement
  - offline_mode and force_offline enable enforcement
  - Disabled config keeps enforcement off
  - Guard allows when online and blocks when offline
  - Config-driven allowlist application and secure default fallback

- **[tests/tool_downloader_tests.gd](tests/tool_downloader_tests.gd)** — Validates that download attempts are blocked in offline mode and library integration.
  - Downloader initialization with mirror URL
  - Offline mode blocks download attempts
  - Mirror configuration validation
  - Result structure validation
  - Existing tool detection (early return without network access)

- **[tests/tool_config_injector_tests.gd](tests/tool_config_injector_tests.gd)** — Validates tool-specific offline config injection.
  - Blender launch args include python override
  - Godot project-local override.cfg is written under the launched project and cleaned up
  - Krita and Audacity placeholder overrides are written

- **[tests/socket_blocker_tests.gd](tests/socket_blocker_tests.gd)** — Validates socket blocking behavior.
  - Offline blocks socket creation
  - Online creates sockets without connecting (when allowlisted)
  - Online blocks hosts not on the allowlist

- **[tests/logger_tests.gd](tests/logger_tests.gd)** — Validates structured logging behavior.
  - Writes JSON logs
  - Enforces level filtering

- **[tests/path_resolver_tests.gd](tests/path_resolver_tests.gd)** — Validates cross-platform path resolution for the library system.
  - Library root path resolution (Windows %LOCALAPPDATA%, Unix ~/.config)
  - Environment variable override (`OGS_LIBRARY_ROOT` for test isolation)
  - Tool path construction
  - Path normalization (backslash handling)
  - Tool existence checking
  - Available tools discovery
  - Available versions discovery

- **[tests/library_manager_tests.gd](tests/library_manager_tests.gd)** — Validates central library management operations.
  - Tool discovery and querying
  - Version enumeration
  - Tool existence validation
  - Tool metadata retrieval (path, size, modification time)
  - Tool validation with integrity checks
  - Library summary generation

- **[tests/tool_extractor_tests.gd](tests/tool_extractor_tests.gd)** — Validates tool archive extraction and library integration.
  - Archive validation and structure checking
  - Extraction to library with proper directory structure
  - File count tracking during extraction
  - Error handling for missing archives
  - Parameter validation
  - Nested archive structure handling

- **[tests/project_environment_validator_tests.gd](tests/project_environment_validator_tests.gd)** — Validates project environment readiness for launching.
  - Environment validation against library state
  - Missing tool detection from stack.json
  - Library accessibility checking
  - Download list generation for hydration
  - Error reporting and validation structure

- **[tests/library_hydrator_tests.gd](tests/library_hydrator_tests.gd)** — Validates library hydration workflow for missing tools.
  - Tool missing detection and batch processing
  - Download list generation from environment validator
  - Error handling for offline mode
  - Empty library handling
  - Hydration workflow integration

- **[tests/project_sealer_tests.gd](tests/project_sealer_tests.gd)** — Validates "Seal for Delivery" workflow.
  - Seal project rejects missing stack.json
  - Seal project rejects missing tools in library
  - Seal project rejects invalid manifest
  - Seal project validates against library state
  - Offline config generation with force_offline flag
  - Tools copied from library to project
  - Real zip archive is created on successful seal
  - Sealed zip contains expected project/config/tool files
  - Packaging lifecycle log events are emitted
  - Sealed zip path returned in result
  - Path handling with and without trailing slashes
  - Result structure validation (success, errors, sealed_zip, tools_copied, project_size_mb)

- **[tests/mirror_repository_tests.gd](tests/mirror_repository_tests.gd)** — Validates local mirror repository.json loading and schema.
  - Valid manifests load correctly
  - Schema version enforcement (must be 1)
  - Mirror name validation (required, non-empty)
  - Tools array validation (required, non-empty)
  - Tool entry validation (id, version, archive_path or archive_url required)
  - SHA-256 checksum required and format validation (64 lowercase hex chars)
  - Tool size validation (positive integer)
  - Error code generation for invalid schemas

- **[tests/mirror_path_resolver_tests.gd](tests/mirror_path_resolver_tests.gd)** — Validates safe path resolution for mirrors.
  - Default mirror root paths (Windows: %LOCALAPPDATA%/OGS/Mirror, Unix: ~/.config/ogs-launcher/mirror)
  - Path safety checks (rejects .. and absolute paths)
  - Case-insensitive path containment validation
  - Archive path resolution and validation
  - Security: prevents directory traversal attacks

- **[tests/mirror_hydrator_tests.gd](tests/mirror_hydrator_tests.gd)** — Validates offline mirror tool installation.
  - Mirror repository loading and validation
  - Archive existence checking
  - SHA-256 hash verification
  - ZIP extraction with safe path handling
  - Common-root prefix stripping for nested archives
  - Tool installation signals (started, completed)
  - Hydration lifecycle status updates

- **[tests/remote_mirror_hydrator_tests.gd](tests/remote_mirror_hydrator_tests.gd)** — Validates remote mirror hydration behavior.
  - Missing repository URL is rejected
  - Invalid repository JSON fails validation
  - Missing archive file reports failures

- **[tests/tools_controller_tests.gd](tests/tools_controller_tests.gd)** — Validates Tools page controller tracking.
  - Download tracking state (active/inactive)
  - Missing tool download rejection
  - Duplicate download suppression
  - Repository data availability flag

### Scene Tests (Integration with UI)

Scene tests instantiate UI nodes and verify controller behaviors. These are similar to Unity's "Play Mode tests" but run headlessly in Godot.

**Current scene test suites:**

- **[tests/projects_controller_scene_tests.gd](tests/projects_controller_scene_tests.gd)** — Validates Projects page controller logic.
  - Add Project requires both `stack.json` and `ogs_config.json`
  - Valid sample project adds to persistent Projects list and auto-selects
  - New Project creates scaffold under OGS/Projects and auto-adds to library
  - Persisted project index reloads on next setup
  - Remove Project updates list and persisted index immediately
  - Add Tool and Remove Tool update project `stack.json` and refresh the tools list
  - Add Tool dialog uses list-based selection and preserves action button state
  - Add Tool candidates include fallback local sources when remote catalog data is unavailable
  - Launch button disabled initially
  - Launch button enabled after valid project selection
  - Launch with no selection → error message

- **[tests/projects_page_indicators_tests.gd](tests/projects_page_indicators_tests.gd)** — Tests tool availability indicators in Projects page.
  - Tool items populated with ID and version
  - Tool availability tracking (_tool_availability dictionary)
  - Visual indicators for missing vs available tools
  - Click-through signal emission for tool navigation
  - Signal integration with ToolsController for availability checking

- **[tests/main_scene_tests.gd](tests/main_scene_tests.gd)** — Smoke tests for the main launcher scene.
  - main.tscn loads without errors
  - All page nodes exist (Projects, Engine, Tools, Settings)
  - Add Project / New Project buttons and Projects list exist
  - Tool action rows include Add Tool, Remove Tool, Launch Selected Tool, Remove Project, and Seal for Delivery

- **[tests/tools_page_scene_tests.gd](tests/tools_page_scene_tests.gd)** — Scene tests for Tools page UI.
  - Tools/Download tab nodes exist
  - Online/offline status label updates
  - Download button disablement during active download

### Startup Tests (Initialization Verification)

- **[tests/startup_tests.gd](tests/startup_tests.gd)** — Verifies launcher initialization without errors (3 tests).
  - Main scene loads and instantiates successfully
  - All required UI nodes exist and are accessible (13 critical nodes)
  - Script validation: main.gd is properly formed and instantiable

## Test Structure

Each test suite:
1. Extends `RefCounted`
2. Has a `class_name` for registration
3. Implements `run() -> Dictionary` returning `{"passed": int, "failed": int, "failures": Array[String]}`
4. Uses `_expect(condition, message, results)` helper for assertions

### Example Unit Test

```gdscript
extends RefCounted
class_name MyFeatureTests

func run() -> Dictionary:
    var results := {"passed": 0, "failed": 0, "failures": []}
    _test_valid_input(results)
    _test_invalid_input(results)
    return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
    if condition:
        results["passed"] += 1
    else:
        results["failed"] += 1
        results["failures"].append(message)

func _test_valid_input(results: Dictionary) -> void:
    var config = MyFeature.load("valid_data")
    _expect(config.is_valid(), "valid data should pass", results)
```

### Example Scene Test

```gdscript
extends RefCounted
class_name MyControllerSceneTests

func run() -> Dictionary:
    var results := {"passed": 0, "failed": 0, "failures": []}
    _test_ui_interaction(results)
    return results

func _test_ui_interaction(results: Dictionary) -> void:
    var controller = MyController.new()
    var label = Label.new()
    controller.setup(label)
    controller.do_something()
    _expect(label.text == "Expected", "label should update", results)
    label.free()  # Clean up to avoid leaks
```

## Adding New Tests

### 1. Create Test File

Create a new test file in `tests/` with `class_name`:

```gdscript
extends RefCounted
class_name MyNewTests
```

### 2. Register in Test Runner

Add to [tests/test_runner.gd](tests/test_runner.gd):

```gdscript
var my_new_tests = load("res://tests/my_new_tests.gd")
if my_new_tests:
    test_suites.append(my_new_tests.new())
```

### 3. Run and Verify

```bash
godot --headless --script res://tests/test_runner.gd
```

## Best Practices

### General
- Write tests alongside new features (don't defer testing)
- Keep tests focused: one assertion per test method when possible
- Use descriptive test method names (`_test_empty_path_shows_error` over `_test_1`)

### Unit Tests
- Test both valid and invalid inputs
- Verify error codes/messages explicitly
- Avoid file I/O when possible (use in-memory data)

### Scene Tests
- Always free created UI nodes to avoid resource leaks
- Test user-facing behaviors, not internal implementation
- Use sample data from `samples/` when testing file loading

### Cleanup
- Free all created nodes in scene tests
- Delete temporary files created during tests
- Avoid leaving state that could affect subsequent tests

## Continuous Integration

All pull requests must pass the test suite. The CI pipeline runs:

```powershell
& "C:\Program Files\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64.exe" --headless --script res://tests/test_runner.gd
```

Exit code 0 = all tests passed; exit code 1 = failures detected.

## Troubleshooting

### Tests Hang or Don't Complete

- Check for infinite loops in test logic
- Ensure all UI nodes are freed (resource leaks can cause hangs)
- Run with `--verbose` to see detailed output

### "Class not found" Errors

- Ensure `class_name` is declared in the source file
- Add preload statements in `test_runner.gd` if needed
- Open the project in Godot editor once to register classes

### Resource Leak Warnings

Scene tests must free all created nodes:

```gdscript
func _test_something(results: Dictionary) -> void:
    var label = Label.new()
    # ... test logic ...
    label.free()  # Critical: always free
```

## Coverage Goals

Target coverage for all new features:
- **Business logic** → 100% unit test coverage
- **UI controllers** → Scene tests for critical user flows
- **Utilities** → Unit tests for edge cases and error handling

---

Last updated: **February 20, 2026**

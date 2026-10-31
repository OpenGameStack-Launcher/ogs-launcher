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
tests passed: 1358
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

**Current unit test suites (29 total, 35 suites across all categories):**

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

- **[tests/tool_launcher_tests.gd](tests/tool_launcher_tests.gd)** - Validates tool process spawning logic.
  - Missing/empty path fields rejected
  - Invalid project directory rejected
  - Nonexistent tool executable rejected
  - Tool-specific arguments built correctly (Godot, Git, VSCodium, Blender, unknown)
  - Git launch arguments include `--cd=<project_dir>`
  - VSCodium launch arguments include workspace project path and optional target file
  - Fallback executable discovery for Git (`git-bash.exe`, `cmd/git.exe`, `bin/git.exe`) and VSCodium (`VSCodium.exe`, `codium`, `bin/codium`)
  - Automatic detection and injection of portable Git (`git.path` and `git.enabled`) into `.vscode/settings.json` when Git is pinned in `stack.json`
  - Absolute paths used as-is (no project directory joining)
  - Relative paths joined with project directory

- **[tests/offline_enforcer_tests.gd](tests/offline_enforcer_tests.gd)** - Validates offline enforcement state and network guard behavior.
  - Null config resets enforcement
  - offline_mode and force_offline enable enforcement
  - Disabled config keeps enforcement off
  - Guard allows when online and blocks when offline
  - Config-driven allowlist application and secure default fallback

- **[tests/tool_downloader_tests.gd](tests/tool_downloader_tests.gd)** - Validates that download attempts are blocked in offline mode and library integration.
  - Downloader initialization with mirror URL
  - Offline mode blocks download attempts
  - Mirror configuration validation
  - Result structure validation
  - Existing tool detection (early return without network access)

- **[tests/tool_config_injector_tests.gd](tests/tool_config_injector_tests.gd)** - Validates tool-specific offline config injection.
  - Blender launch args include python override
  - Godot cache-backed editor settings and offline feature profile are written under `user://ogs_offline_godot/` and cleaned up
  - Krita and Audacity placeholder overrides are written
  - VSCodium launch args include `--disable-telemetry` when offline enforcement is active

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

- **[tests/remote_mirror_hydrator_tests.gd](tests/remote_mirror_hydrator_tests.gd)** - Validates remote mirror hydration behavior.
  - Missing repository URL is rejected
  - Invalid repository JSON fails validation
  - Missing archive file reports failures
  - Loopback HTTP integration test validates remote download to file, SHA-256 verification, library extraction, and progress reporting

- **[tests/progress_controller_tests.gd](tests/progress_controller_tests.gd)** - Validates download and installation progress tracking and UI updates.
  - Inline progress registration and tracking state
  - Basic progress updates and percentage calculations
  - Indeterminate progress and formatting for unknown or zero total bytes
  - Automatic transition to installation phase upon download completion
  - Manual phase transitions and signal emission (completed, cancelled)
  - Concurrent multi-tool tracking isolation

- **[tests/tool_category_mapper_tests.gd](tests/tool_category_mapper_tests.gd)** - Validates tool category classification and display names.
  - Supports "Code" category across category validation and `get_all_categories()`
  - Fallback mappings for `git` -> `Code` and `vscodium` -> `Code`
  - Canonical tool display name formatting via `get_display_name()` (e.g., "Git", "VSCodium", "GIMP")

- **[tests/tools_controller_tests.gd](tests/tools_controller_tests.gd)** - Validates Tools page controller tracking and categorization.
  - Download tracking state (active/inactive)
  - Missing tool download rejection
  - Duplicate download suppression
  - Repository data availability flag
  - Tool categorization for "Code" category tools
  - Defensive dynamic bucket creation for unknown or future categories

- **[tests/onboarding_wizard_tests.gd](tests/onboarding_wizard_tests.gd)** - Validates first-run detection behavior for onboarding wizard.
  - Returns false when library has visible entries
  - Returns true when library only contains hidden or empty directories

- **[tests/seal_controller_tests.gd](tests/seal_controller_tests.gd)** - Validates SealController thread lifecycle and safety.
  - Thread joined cleanly when controller freed during active execution
  - Predelete handler safe when no thread is active
  - Thread start failure clears state and emits failure

- **[tests/tools_page_controller_tests.gd](tests/tools_page_controller_tests.gd)** - Validates ToolsPageController thread lifecycle and cleanup.
  - Predelete joins active tool removal thread
  - Cleanup safe when removal thread is null
  - Main scene pre-quit cleanup triggers controller cleanup

- **[tests/file_type_mapper_tests.gd](tests/file_type_mapper_tests.gd)** - Validates FileTypeMapper extension mapping and exclusions.
  - VSCodium supported extensions recognized (gd, cs, gdshader, shader, txt, md, csv, json, yaml, yml, toml) in lowercase and uppercase
  - Non-text extensions (png, exe, tscn, tres) rejected
  - Internal metadata files (stack.json, ogs_config.json, ogs_metadata.json) and extensions (.import, .uid, .cfg, .tres, .tscn) excluded
  - Direct query maps text/script extensions to vscodium, project.godot to godot, and asset files to binary tools
  - Stack-aware tool queries require vscodium presence in active tools for text/script mapping while Godot-only stacks return empty string
  - Tool to extension mapping returns txt for vscodium (case-insensitive) and empty string for godot

- **[tests/release_packaging_tests.gd](tests/release_packaging_tests.gd)** - Validates release packaging contract, export presets, semantic version rules, and workflow files.
  - Windows Desktop preset defined in `export_presets.cfg` without hardcoded machine paths or private keys
  - Strict semantic version validation (`X.Y.Z`) accepting clean numbers and rejecting `v` prefix or `-alpha` suffix
  - `build_release_package.ps1` parameterization (`-Version`, `-GodotPath`, `-RcEditPath`, `-SkipTests`, `-SkipZip`) and artifact naming
  - Clean `README.txt` generation and retirement of `README_ALPHA.txt` and `build_alpha_package.ps1`
  - Valid multi-size Windows icon file presence at `Images/logo.ico`
  - Canonical `docs/RELEASE_PACKAGING.md` presence and retirement of `docs/ALPHA_PACKAGING.md`
  - GitHub Actions CI (`.github/workflows/ci.yml`) and Release (`.github/workflows/release.yml`) configuration contracts

- **[tests/remote_project_cloner_tests.gd](tests/remote_project_cloner_tests.gd)** - Validates RemoteProjectCloner service and PortableGit resolution (17 tests).
  - Valid remote URLs accepted across https://, http:// (local LAN mirrors), ssh://, and SCP-style syntax
  - Disallowed URLs rejected: empty strings, argument injection (- prefix), local paths, traversal sequences, file://, ext::, and shell metacharacters
  - Repo slug extraction and sanitization across various URL formats and trailing slashes
  - Folder collision resolution: incremental folder name suggestion (slug, slug-1, slug-2)
  - Target path boundary validation: ensures targets stay strictly within destination root
  - PortableGit executable resolution in Central Library and semantic version comparison
  - Air-gap blocking: OfflineEnforcer.is_offline() blocks clone operations immediately with error code offline
  - Two-phase clone flow with mocked commands: verifying phase, show HEAD:stack.json, and checkout phase
  - Fallback from blobless clone (--filter=blob:none) to standard no-checkout clone
  - Missing or invalid root stack.json manifests rejected before checkout and target directory purged safely
  - Working tree checkout failure handling and cancellation teardown killing child process
  - Target directory pre-existence rejection and defensive directory deletion bounded by destination root

- **[tests/remote_project_dialog_tests.gd](tests/remote_project_dialog_tests.gd)** - Validates RemoteProjectDialogController UI flow and modal lifecycle (12 tests).
  - Dialog hierarchy instantiation: modal ConfirmationDialog (exclusive, unresizable), MarginContainers, LineEdits, Browse button, status label, progress bar, missing-Git prompt, and collision dialog
  - Autowrap mode (AUTOWRAP_WORD_SMART) and explicit horizontal minimum size constraints (480px, 440px) on labels to prevent vertical and horizontal layout inflation
  - MarginContainer padding (10px on all sides) around clone dialog and collision dialog internal controls
  - Bounded dialog opening dimensions (540x280 and 480x160 targets) and visible, accessible action buttons (OK/Continue, Cancel)
  - URL input validation and Clone button state transitions (disabled for empty/whitespace, enabled for valid URL)
  - Destination folder pre-filling with configured Primary Projects Folder and manual override via browse dialog
  - Subfolder collision detection and incremental folder name suggestion (slug-1, slug-2)
  - Validation failure keeps dialog open with intact URL input
  - Manifest failure preserves entered URL and re-enables inputs
  - Cancellation during active clone invokes cloner cancel and restores idle controls
  - Successful clone closes modal dialog and emits clone_completed signal
  - Missing-Git guided dialog emits tool_view_requested upon "Go to Tools" confirmation
  - OfflineEnforcer active state blocks opening clone dialogs

### Scene Tests (Integration with UI)

Scene tests instantiate UI nodes and verify controller behaviors. These are similar to Unity's "Play Mode tests" but run headlessly in Godot.

**Current scene test suites:**

- **[tests/projects_controller_scene_tests.gd](tests/projects_controller_scene_tests.gd)** - Validates Projects page controller logic.
  - Add Local Project requires stack.json (auto-generates missing ogs_config.json on disk with default offline policies)
  - Missing stack.json or empty folder rejected with appropriate status
  - Valid sample project adds to persistent Projects list and auto-selects
  - New Project creates scaffold under resolved Primary Projects Folder and auto-adds to library
  - Creating a new project honors configured Primary Projects Folder while test root override takes precedence
  - Persisted project index reloads on next setup
  - Remove Project updates list and persisted index immediately
  - Add Tool and Remove Tool update project `stack.json` and refresh the tools list
  - Add Tool dialog uses list-based selection and preserves action button state
  - Add Tool candidates include fallback local sources when remote catalog data is unavailable
  - Code category tools (`git`, `vscodium`) bypass creating empty `assets/Code/*` directories
  - Launch button disabled initially
  - Launch button enabled after valid project selection
  - Launch with no selection -> error message
  - Tool selection in `project_tools_list` sets active launch tool ID, clears explorer target path, and deselects the project explorer tree
  - Direct launch from `project_tools_list` runs installed tools at the project root without requiring explorer file selection
  - Double-click item activation launches the selected tool immediately at the project root
  - Project switching, list repopulation, and launch button disable handlers reset launch tool ID and launch target path to prevent state leakage
  - Bidirectional mutual deselection synchronizes selection states between `project_tools_list` and `explorer_tree`
  - Double-click file activation in project explorer triggers launch targeting the activated file
  - New file creation in projects with VSCodium creates empty files on disk and defaults extensionless files to .txt with VSCodium launch state
  - Three-button toolbar layout (Add Local Project, Add Remote Project, New Project) with equal size flags and 16px separation
  - Missing-Git detection opens guided dialog and "Go to Tools" emits navigation hook
  - Offline mode disabling and descriptive tooltip enforcement on AddRemoteProjectButton
  - Single-clicking a missing tool row in `project_tools_list` selects it and enables Remove Tool and Change Version without emitting `tool_view_requested` or navigating away
  - Double-clicking (`item_activated`) a missing tool row in `project_tools_list` emits `tool_view_requested` to navigate to the Tools page
  - Clicking "Launch Selected Tool" with a missing tool selected emits `tool_view_requested` to guide the user to download it, updating the status label rather than attempting execution
  - Single-clicking a project in `projects_list` selects the project, updates Tab 1 title to the stack name, enables action buttons, and keeps `current_tab == 0` (Project Library)
  - Double-clicking (`item_activated`) a project in `projects_list` selects the project and switches `current_tab` to 1 (Project Details)
  - Clicking "Open Project" button switches `current_tab` to 1 (Project Details)
  - Open Project, Remove Project, and Seal buttons are disabled initially when library is empty, enabled on project addition, and disabled when library becomes empty
  - `CustomItemList` emits `item_selected` on single-click and `item_activated` on double-click

- **[tests/projects_page_indicators_tests.gd](tests/projects_page_indicators_tests.gd)** - Tests tool availability indicators in Projects page.
  - Tool items populated with ID and version
  - Tool availability tracking (_tool_availability dictionary)
  - Visual indicators for missing vs available tools
  - Double-click and launch signal emission for tool navigation on missing tools
  - Signal integration with ToolsController for availability checking

- **[tests/main_scene_tests.gd](tests/main_scene_tests.gd)** - Smoke tests for the main launcher scene.
  - main.tscn loads without errors
  - All page nodes exist (Projects, Engine, Tools, Settings)
  - Add Local Project / Add Remote Project / New Project buttons and Projects list exist
  - Settings page Projects folder controls (label, path line edit, browse button, reset button) exist and wire properly
  - Primary projects root browse dialog is queued for free when closed or canceled without selection
  - Tool action rows include Add Tool, Remove Tool, Launch Selected Tool, Remove Project, and Seal for Delivery
  - OpenProjectButton exists with minimum size Vector2(140, 32), starts disabled, and wires properly in UIDeps
  - `installed_code_tools` and `download_code_tools` node bindings are wired
  - AddRemoteProjectButton wired to UIDeps and toggles disabled state and descriptive tooltip on offline state change

- **[tests/tools_page_scene_tests.gd](tests/tools_page_scene_tests.gd)** - Scene tests for Tools page UI.
  - Tools/Download tab nodes exist
  - CodeSection and CodeTools containers exist in both Installed and Download tabs
  - Online/offline status label updates
  - Download button disablement during active download

- **[tests/project_explorer_tests.gd](tests/project_explorer_tests.gd)** - Validates ProjectExplorer directory filtering, pruning, selection, tool icon rendering, stack-aware VSCodium mappings, and double-click activation (916 total passed tests across runner suites).
  - Non-relevant and empty folders excluded from tree
  - Direct tool folders (gimp, blender, krita, audacity, godot, game) and ancestor folders retained even when empty
  - Launchable files displayed while non-launchable files (.png, etc.) omitted
  - Dot-prefixed directories (.git, .godot, .worktrees, .github) skipped during traversal
  - Projects with zero launchable files and zero tool folders display root item only
  - TreeItem selection signals, folder/file tool inference, and context menu initialization
  - Launchable files (project.godot, .xcf, .blend, .kra, .aup3) receive corresponding tool icons with max width 20px
  - Direct tool folders (gimp, blender, krita, audacity, godot, game) receive corresponding tool icons with max width 20px
  - Container folders (project root, intermediate folders like assets, 2D, 3D, Audio, and nested subfolders) maintain null icons
  - Icon caching in ProjectExplorer verifies texture instance reuse and missing tool handling
  - Stack-aware text and script file display: when VSCodium is in the stack, all mapped extensions (gd, cs, gdshader, shader, txt, md, csv, json, yaml, yml, toml) appear with the VSCodium icon and emit vscodium on selection
  - Strict metadata exclusion: internal launcher and engine metadata files (stack.json, ogs_config.json, ogs_metadata.json, .import, .uid, .cfg, .tres, .tscn) remain hidden even when .json is supported
  - Godot-only pruning: text and script files are pruned when VSCodium is not in the project stack
  - Double-click activation: double-clicking a file emits file_activated signal while double-clicking a folder toggles collapse
  - Stack fallback: when active tool IDs are omitted in load_project, reads tool IDs from project stack.json

### Startup Tests (Initialization Verification)

- **[tests/startup_tests.gd](tests/startup_tests.gd)** - Verifies launcher initialization without errors (5 tests).
  - Main scene loads and instantiates successfully
  - All required UI nodes exist and are accessible (23 critical nodes including Projects toolbar AddRemoteProjectButton and Settings page Projects folder controls)
  - Controller classes (`ProjectsController`, `SealController`, `LayoutController`, `OnboardingWizard`) instantiate cleanly
  - Script validation: `main.gd` is properly formed and instantiable
  - `McpInteractionServer` autoload registration in `project.godot`, `autoloads/mcp_interaction_server.gd` instantiation, and `mcp_client.py` presence

### Agentic Visual QA (MCP Bridge)

In addition to headless unit and scene tests, OGS Launcher includes a debug-only runtime inspection bridge (`McpInteractionServer` at [`autoloads/mcp_interaction_server.gd`](../autoloads/mcp_interaction_server.gd) and [`mcp_client.py`](../mcp_client.py)) listening on `127.0.0.1:9090` (configurable via `GODOT_MCP_PORT`). It is automatically disabled in non-debug release exports and headless test runs.

Whenever modifying UI scenes (`main.tscn`, `scenes/*.tscn`), layouts, dialogs, icons, or visual controllers, use the MCP bridge (via `mcp_client.py` or the `godot-bridge` MCP server tools; see [`.agents/skills/mcp-visual-qa/SKILL.md`](../.agents/skills/mcp-visual-qa/SKILL.md)) to verify the application is visually working right:

```powershell
# 1. Stop any stale Godot processes holding port 9090
Stop-Process -Name "Godot*" -Force -ErrorAction SilentlyContinue

# 2. Launch OGS Launcher in the background (e.g. godot or godot --path .worktrees/issue-<number>)

# 3. Query and capture screenshots via mcp_client.py
python mcp_client.py ping
python mcp_client.py screenshot
python mcp_client.py get_ui_elements
python mcp_client.py get_scene_tree

# 4. Inspect screenshot.png to confirm clean layout without clipping or overlap

# 5. Terminate the background Godot process to release port 9090 and Windows file locks, and clean up temporary screenshots
Stop-Process -Name "Godot*" -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path screenshot*, agent_screenshot* -ErrorAction SilentlyContinue | Remove-Item -Force
```

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

All pull requests and pushes to `main` must pass continuous integration on GitHub Actions (`.github/workflows/ci.yml`).

The CI workflow executes on `windows-latest` and performs the following verification gates:
1. **Tooling Cache & Installation:** Installs and caches Godot 4.7.2 Stable (`Godot_v4.7.2-stable_win64_console.exe`), Windows export templates, and `rcedit-x64.exe` (v2.0.0).
2. **Headless Editor Import:** Executes `godot --headless --editor --quit` to register class names, resources, and UID metadata.
3. **Headless Test Suite:** Runs the full 35-suite headless test runner:
   ```powershell
   godot --headless -s res://tests/test_runner.gd
   ```
   Exit code 0 = all tests passed; exit code 1 = failures detected.
4. **Packaging Smoke Check:** Runs `build_release_package.ps1` with `-Version 0.0.0-ci -SkipTests -SkipZip` to verify that Windows executable export and deterministic `rcedit` icon/metadata stamping succeed.
5. **Metadata Verification:** Inspects exported `OGS-Launcher.exe` file version info (`FileVersion`, `ProductVersion`, `CompanyName`, `ProductName`, `FileDescription`) using PowerShell `(Get-Item $exe).VersionInfo` to catch export regressions before merge.

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

Last updated: **October 31, 2026**

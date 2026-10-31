---
name: code-review
description: >-
  Use when reviewing pull requests or diffs that touch Godot 4.7.2 GDScript (.gd), scenes (.tscn), resources (.tres), or project.godot files in the OGS Launcher. Performs a structured code review against Godot 4.7.2 syntax, OGS architectural rules (air-gap-first, zero dependencies, MOSA modularity), OgsLogger conventions, and the repository test requirements.
---

# Godot 4.7.2 Code Review (OGS Launcher)

Structured review procedure for changes to GDScript, scenes, and resources in this repository. Apply this on pull requests, diffs, or any request to review Godot code.

## Review Checklist

Walk the diff against each section below. Focus comments on lines that are part of the diff (changed or added), unless a change clearly breaks surrounding code.

### 1. Godot 4.7.2 Syntax & Static Typing
- Flag Godot 3.x-era APIs: `instance()` (must be `instantiate()`), `onready` without `@` (must be `@onready`), `export` without `@` (must be `@export`), `tool` without `@` (must be `@tool`), old signal `connect("sig", self, "method")` (must be `signal.connect(callable)`), `yield()` (must be `await`).
- Confirm static typing is used across both `scripts/` and `tests/`: typed vars (`var x: int`), typed function params/returns (`func foo(x: int) -> bool:`), and explicit casts on dynamic node lookups (`get_node_or_null(...) as Control`).
- Confirm `class_name` and `extends` declarations are valid and not duplicated, and `.uid` files for new scripts are included.

### 2. OGS Architectural Rules
- **Air-gap first:** Reject any new `HTTPRequest`, socket, or telemetry that is not part of the explicit tool-download flow (`scripts/network/`, `scripts/mirror/`). All network checks must respect `OfflineEnforcer` and `SocketBlocker`.
- **Zero dependencies:** No external installers, registry keys, or direct `%APPDATA%` usage. Library paths must resolve via `PathResolver` (`scripts/library/path_resolver.gd`) so `OGS_LIBRARY_ROOT` test isolation works properly.
- **Modularity (MOSA):** New logic should live in an appropriately scoped script or helper module rather than bloating orchestrator controllers (`main.gd`, `projects_controller.gd`, `tools_controller.gd`).

### 3. Testing Requirements (`tests/test_runner.gd`)
- Every new function with non-trivial logic needs a `##` docstring explaining its purpose in the OGS lifecycle.
- New behavior requires corresponding tests under `tests/`:
  - Unit and scene test scripts must `extends RefCounted`, declare `class_name`, and implement `run() -> Dictionary`.
  - **CRITICAL:** Confirm any new `class_name` script and any new `tests/*_tests.gd` file are registered in `tests/test_runner.gd` (preloaded and appended to `test_files`).
  - Scene tests must call `.free()` on all created UI nodes to prevent leaks.
  - Any spawned `Thread` must be joined (`wait_to_finish()`) on cleanup/exit.
- Confirm [docs/TESTING.md](../../../docs/TESTING.md) is updated when new test suites or categories are added.

### 4. Error Handling & Logging (`OgsLogger`)
- File operations (`FileAccess`, `DirAccess`), network calls, and JSON parsing must handle failure paths gracefully and close file handles.
- Operational events must go through `OgsLogger` (`const OgsLogger = preload("res://scripts/logging/logger.gd")`) with component/project/tool context.
- Flag raw `print()` or `push_error()` used for operational events, flag aliasing `logger.gd` as `Logger` (which collides with Godot 4.7.2's built-in `Logger` class), and flag any sensitive data (paths with usernames, tokens) being logged.

### 5. Security (Desktop & Supply-Chain Hardening)
- Path handling: Reject unsanitized use of untrusted strings in filesystem paths (path traversal via `../` in tool IDs, versions, or archive entries).
- Archive extraction (`tool_extractor.gd` and mirror hydrators): Confirm zip-slip protections and SHA-256 verification are preserved.
- No hardcoded secrets, tokens, or machine-specific signing paths in `export_presets.cfg`.

### 6. Scenes, Resources & Visual QA (`.tscn` / `.tres` / MCP Bridge)
- Confirm node paths referenced in scripts (`$NodePath`, `%UniqueName`, `get_node_or_null()`) match the scene tree structure in the diff.
- Confirm freed or removed nodes do not leave dangling signal connections.
- When UI layouts, scenes, dialogs, or icons are modified, verify via the MCP visual QA bridge (`McpInteractionServer` on `127.0.0.1:9090` + `python mcp_client.py screenshot` / `get_ui_elements`, see [`.agents/skills/mcp-visual-qa/SKILL.md`](../mcp-visual-qa/SKILL.md)) that the app renders cleanly without clipping, overlapping controls, or broken layout.

## Output Format

Report findings grouped by severity:

- **Blocking:** Godot 3.x syntax, air-gap violations, path traversal risks, unjoined threads/leaks, missing tests or missing registration in `tests/test_runner.gd`.
- **Should Fix:** Missing docstrings, `OgsLogger` gaps, weak error handling, missing documentation updates.
- **Nit:** Style, naming, or minor readability suggestions.

For each finding, reference the file and line, explain the issue, and suggest the concrete fix. If the diff is clean, state that explicitly.

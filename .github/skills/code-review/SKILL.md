---
name: code-review
description: 'Use when reviewing pull requests or diffs that touch Godot 4.7.2 GDScript (.gd), scenes (.tscn), resources (.tres), or project.godot files in the OGS Launcher. Performs a structured code review against Godot 4.7.2 syntax, OGS architectural rules (air-gap-first, zero dependencies, MOSA modularity), OgsLogger conventions, and the repository test requirements. Triggers: "review this PR", "code review", "review my changes", automated review of a GDScript/.tscn diff.'
---

# Godot 4.7.2 Code Review (OGS Launcher)

Structured review procedure for changes to GDScript, scenes, and resources in this repository. Apply this on pull requests, diffs, or any request to review Godot code.

## Review Checklist

Walk the diff against each section below. Only comment on lines that are part of the diff (changed/added), unless a change clearly breaks surrounding code.

### 1. Godot 4.7.2 Syntax & Static Typing
- Flag Godot 3.x-era APIs: `instance()` (must be `instantiate()`), `onready` without `@` (must be `@onready`), `export` without `@` (must be `@export`), `tool` without `@` (must be `@tool`), old signal `connect("sig", self, "method")` (must be `signal.connect(callable)`), `yield()` (must be `await`).
- Confirm typed GDScript is used across `scripts/` and `tests/`: typed vars (`var x: int`), typed function params/returns (`func foo(x: int) -> bool:`), and explicit casts on node lookups.
- Confirm `class_name` and `extends` declarations are correct and not duplicated, and `.uid` files for new scripts are included.

### 2. OGS Architectural Rules
- **Air-gap first:** Reject any new `HTTPRequest`, socket, or telemetry that is not part of the explicit tool-download flow (`scripts/network/`, `scripts/mirror/`). All network checks must respect `OfflineEnforcer` and `SocketBlocker`.
- **Zero dependencies:** No external installers, registry keys, or direct `%APPDATA%` usage. Paths must stay portable/relative to the launcher folder or the documented Library root (`%LOCALAPPDATA%/OGS/Library` equivalent via `PathResolver`).
- **Modularity (MOSA):** New logic should live in an appropriately scoped script/module rather than bolted onto unrelated controllers; flag God-object growth in files like `tools_controller.gd` or `main.gd`.

### 3. Testing Requirements (`tests/test_runner.gd`)
- Every new function with non-trivial logic needs a `##` docstring explaining its purpose in the OGS lifecycle.
- New behavior requires corresponding tests under `tests/`:
  - Unit and scene test scripts must `extends RefCounted`, declare `class_name`, and implement `run() -> Dictionary`.
  - **CRITICAL:** Confirm any new `class_name` script and any new `tests/*_tests.gd` file are registered in `tests/test_runner.gd` (preloaded and appended to `test_files`).
  - Scene tests must call `.free()` on all created UI nodes.
  - Any spawned `Thread` must be joined (`wait_to_finish()`) on exit.
- If a PR changes logic without a matching test update, call it out explicitly.
- Confirm [docs/TESTING.md](../../../docs/TESTING.md) is updated when test categories or suites change.

### 4. Error Handling & Logging (`OgsLogger`)
- File operations, network calls, and JSON parsing must handle failure paths without crashing and close open `FileAccess` handles.
- Operational events should go through `OgsLogger` (`const OgsLogger = preload("res://scripts/logging/logger.gd")`) with component/project/tool context. Flag raw `print()`/`push_error()` used for operational events, flag aliasing `logger.gd` as `Logger` (which collides with Godot 4.7.2's built-in `Logger` class), and flag any sensitive data (paths with usernames, tokens) being logged.

### 5. Security (OWASP-relevant for a local desktop tool)
- Path handling: Reject unsanitized use of user-supplied strings in filesystem paths (path traversal via `../` in tool IDs/versions/zip entries).
- Archive extraction (`tool_extractor.gd` and similar): Confirm zip-slip protections and SHA-256 verification are preserved when touching extraction logic.
- No hardcoded secrets, tokens, or credentials.

### 6. Scenes & Resources (`.tscn` / `.tres`)
- Confirm node paths referenced in scripts (`$NodePath`, `%UniqueName`) still match the scene tree structure in the diff.
- Confirm freed/removed nodes do not leave dangling signal connections.

## Output Format

Report findings grouped by severity:

- **Blocking:** Godot 3.x syntax, air-gap violations, path traversal risks, unjoined threads/leaks, missing tests or missing registration in `tests/test_runner.gd`.
- **Should Fix:** Missing docstrings, logging gaps, weak error handling.
- **Nit:** Style/naming/consistency suggestions.

For each finding, reference the file and line, explain the issue, and suggest the concrete fix (code snippet when helpful). If the diff is clean, say so explicitly rather than inventing issues.

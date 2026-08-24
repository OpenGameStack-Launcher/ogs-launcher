---
name: godot-code-review
description: 'Use when reviewing pull requests or diffs that touch Godot 4.7.2 GDScript (.gd), scenes (.tscn), resources (.tres), or project.godot files in the OGS Launcher. Performs a structured code review against Godot 4.7.2 syntax, OGS architectural rules (air-gap-first, zero dependencies, MOSA modularity), Logger conventions, and the repository test requirements. Triggers: "review this PR", "code review", "review my changes", automated review of a GDScript/.tscn diff.'
---

# Godot 4.7.2 Code Review (OGS Launcher)

Structured review procedure for changes to GDScript, scenes, and resources in this
repository. Apply this on pull requests, diffs, or any request to review Godot code.

## Review Checklist

Walk the diff against each section below. Only comment on lines that are part of
the diff (changed/added), unless a change clearly breaks surrounding code.

### 1. Godot 4.7.2 Syntax Correctness
- Flag Godot 3.x-era APIs: `instance()` (must be `instantiate()`), `onready` without
  `@` (must be `@onready`), `export` without `@` (must be `@export`), `tool` without
  `@` (must be `@tool`), old signal `connect("sig", self, "method")` (must be
  `signal.connect(callable)`), `yield()` (must be `await`).
- Confirm typed GDScript is used where practical: typed vars (`var x: int`), typed
  function params/returns (`func foo(x: int) -> bool:`).
- Confirm `class_name` and `extends` declarations are correct and not duplicated.

### 2. OGS Architectural Rules
- **Air-gap first:** reject any new `HTTPRequest`, socket, or "phone home"
  telemetry that isn't part of the existing, explicit tool-download flow
  (`scripts/network/`). No analytics, no silent network calls.
- **Zero dependencies:** no external installers, registry keys, or `%APPDATA%`
  usage. Paths must stay portable/relative to the launcher folder or the
  documented Library root (`%LOCALAPPDATA%/OGS/Library` equivalent via
  `PathResolver`).
- **Modularity (MOSA):** new logic should live in an appropriately scoped
  script/module rather than bolted onto unrelated controllers; flag God-object
  growth in files like `tools_controller.gd`.

### 3. Testing Requirements
- Every new function with non-trivial logic needs a docstring explaining its
  purpose in the OGS lifecycle (see existing `##` doc comments in `scripts/`).
- New behavior requires corresponding tests under `tests/`:
  - Unit test scripts must `extends RefCounted`, declare `class_name`, and
    implement `run() -> Dictionary`.
  - Scene tests must free all created UI nodes.
- If a PR changes logic without a matching test update, call it out explicitly.
- Confirm [docs/TESTING.md](../../../docs/TESTING.md) is updated when test
  categories or patterns change.

### 4. Error Handling & Logging
- File operations, network calls, and JSON parsing must handle failure paths
  without crashing (return `Dictionary`/`bool` result patterns already used in
  this codebase, e.g. `library_manager.gd`, `tool_extractor.gd`).
- Operational events should go through `Logger`
  (`scripts/logging/logger.gd`) with component/project/tool context — flag raw
  `print()`/`push_error()` used for things that should be logged, and flag any
  sensitive data (paths with usernames, tokens) being logged.

### 5. Security (OWASP-relevant for a local desktop tool)
- Path handling: reject unsanitized use of user-supplied strings in file
  system paths (path traversal via `../` in tool IDs/versions/zip entries).
- Archive extraction (`tool_extractor.gd` and similar): confirm zip-slip
  protections are preserved when touching extraction logic.
- No hardcoded secrets, tokens, or credentials.

### 6. Scenes & Resources (.tscn / .tres)
- Confirm node paths referenced in scripts (`$NodePath`, `%UniqueName`) still
  match the scene tree structure in the diff.
- Confirm freed/removed nodes don't leave dangling signal connections.

## Output Format

Report findings grouped by severity:

- **Blocking** — Godot 3.x syntax, air-gap violations, path traversal risks,
  missing tests for new logic.
- **Should Fix** — missing docstrings, logging gaps, weak error handling.
- **Nit** — style/naming/consistency suggestions.

For each finding, reference the file and line, explain the issue, and suggest
the concrete fix (code snippet when helpful). If the diff is clean, say so
explicitly rather than inventing issues.

---
description: "Godot 4.7.2 GDScript, scene, and resource review rules for the OGS Launcher. Applies to .gd, .tscn, .tres, and project.godot changes."
applyTo: "**/*.gd,**/*.tscn,**/*.tres,project.godot"
---

# Godot 4.7.2 Review Rules

These rules apply to any change touching GDScript, scenes, resources, or
`project.godot` in this repository. See the full procedure in
[.github/skills/code-review/SKILL.md](../skills/code-review/SKILL.md).

- Target engine is **Godot 4.7.2 (Stable)**. Reject Godot 3.x syntax:
  `instance()` → `instantiate()`, bare `onready`/`export`/`tool` → `@onready`/
  `@export`/`@tool`, old-style `connect()` → `Callable`-based `connect()`,
  `yield()` → `await`.
- Prefer typed GDScript (typed vars, typed params/returns) where practical.
- No network calls outside the existing, explicit tool-download flow in
  `scripts/network/` — this project is air-gap-first with zero telemetry.
- File/archive operations must guard against path traversal (`../`) and
  zip-slip when extracting or resolving tool paths.
- Use `Logger` (`scripts/logging/logger.gd`) for operational events instead of
  raw `print()`; never log secrets, tokens, or user-identifying paths.
- New functions need a short docstring describing their role in the OGS
  lifecycle; new behavior needs a matching test in `tests/` (unit tests
  `extends RefCounted`, declare `class_name`, implement `run() -> Dictionary`;
  scene tests must free all created nodes).

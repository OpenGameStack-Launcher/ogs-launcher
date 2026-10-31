---
description: "Godot 4.7.2 GDScript, scene, and resource review rules for the OGS Launcher. Applies to .gd, .tscn, .tres, and project.godot changes."
applyTo: "**/*.gd,**/*.tscn,**/*.tres,project.godot"
---

# Godot 4.7.2 Review Rules

These rules apply to any change touching GDScript, scenes, resources, or `project.godot` in this repository. See the full procedure in [.agents/skills/code-review/SKILL.md](../../.agents/skills/code-review/SKILL.md) and [.github/skills/code-review/SKILL.md](../skills/code-review/SKILL.md).

- Target engine is **Godot 4.7.2 (Stable)**. Reject Godot 3.x syntax:
  `instance()` -> `instantiate()`, bare `onready`/`export`/`tool` -> `@onready`/`@export`/`@tool`, old-style `connect()` -> `Callable`-based `connect()`, `yield()` -> `await`.
- Use static typing (typed vars, typed params/returns, explicit node lookup casts) across both `scripts/` and `tests/`.
- No network calls outside the existing, explicit tool-download flow in `scripts/network/` and `scripts/mirror/`. This project is air-gap-first with zero telemetry.
- File and archive operations must guard against path traversal (`../`) and zip-slip when extracting or resolving tool paths.
- Use `OgsLogger` (`const OgsLogger = preload("res://scripts/logging/logger.gd")`) for operational events instead of raw `print()` (never alias as `Logger`, which collides with Godot 4.7.2's built-in `Logger` class); never log secrets, tokens, or user-identifying paths.
- New functions need a short `##` docstring describing their role in the OGS lifecycle; new behavior needs a matching test in `tests/` (`extends RefCounted`, declares `class_name`, implements `run() -> Dictionary`, registered in `tests/test_runner.gd`; scene tests must `.free()` all created nodes).
- Changes touching UI scenes (`main.tscn`, `scenes/*.tscn`), layouts, dialogs, or icons should be visually verified via the MCP bridge (`McpInteractionServer` on `127.0.0.1:9090` + `python mcp_client.py screenshot` / `get_ui_elements`, see [.agents/skills/mcp-visual-qa/SKILL.md](../../.agents/skills/mcp-visual-qa/SKILL.md)) to confirm the application is visually working right.

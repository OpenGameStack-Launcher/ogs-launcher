---
name: Godot CLI Usage
description: Guidelines for running Godot 4.7.2 CLI commands (imports, syntax checks, and headless tests) safely on Windows.
trigger: always_on
---

# Godot CLI Usage Rules

When executing the Godot 4.7.2 engine from the terminal (`godot` in `PATH`, which invokes `C:\Program Files\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`), strictly adhere to the following rules to prevent the application from hanging in the background:

1. **Syntax Checking**:
   - **NEVER** run `--check-only` without specifying a script. Doing so will boot the entire Godot main scene invisibly and hang the task runner indefinitely.
   - **ALWAYS** append `--script <path_to_script.gd>` or `-s <path_to_script.gd>` when using `--check-only`.

2. **Headless Class & Asset Registration**:
   - When adding a new `.gd` script with a `class_name`, a new `.tscn` scene, or new assets, run a one-shot headless editor import pass first so Godot registers the resources and `.uid` files:
     ```powershell
     godot --headless --editor --quit
     ```

3. **Running the Automated Test Suite**:
   - Run the headless test runner from the repository or worktree root:
     ```powershell
     godot --headless -s res://tests/test_runner.gd
     ```
   - Remember that `tests/test_runner.gd` does **not** auto-discover test files on disk. Any new `class_name` script must be preloaded in `tests/test_runner.gd`, and any new `tests/*_tests.gd` file must be added to the `test_files` array in `tests/test_runner.gd`.

4. **Runtime Visual QA via MCP Bridge (`McpInteractionServer` & `mcp_client.py`)**:
   - When verifying UI layout, scenes, dialogs, icons, or visual behavior (see `.agents/skills/mcp-visual-qa/SKILL.md`), stop any stale Godot processes first (`Stop-Process -Name "Godot*" -Force -ErrorAction SilentlyContinue`), then launch OGS Launcher in the background (`godot` or `godot --path .worktrees/issue-<number>`).
   - Query and inspect the live application over `127.0.0.1:9090` using `python mcp_client.py ping`, `python mcp_client.py screenshot`, `python mcp_client.py get_ui_elements`, `python mcp_client.py get_scene_tree`, `python mcp_client.py click <x> <y>` (or the `godot-bridge` MCP server tools), and view `screenshot.png` with `read_file` to ensure the app is visually working right.

5. **Lingering Process Cleanup**:
   - Remember that running Godot with `--headless` does not automatically exit unless `--quit` is passed or the script calls `quit()`.
   - Whenever a background Godot instance is started for visual QA or by mistake, immediately terminate it via `manage_task` (`kill`) or `Stop-Process -Name "Godot*" -Force -ErrorAction SilentlyContinue` once finished so it releases port `9090` and does not lock worktree files on Windows.

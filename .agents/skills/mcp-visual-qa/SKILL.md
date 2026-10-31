---
name: mcp-visual-qa
description: >-
  Use this skill when visually inspecting the running OGS Launcher, verifying UI layout changes, capturing screenshots, inspecting the live SceneTree, simulating input (clicks or key presses), or executing runtime GDScript via the MCP bridge to ensure the application is visually working right.
---

# MCP Visual QA & Runtime Inspection (OGS Launcher)

This skill defines the standard procedure for launching OGS Launcher in the background and interacting with its `McpInteractionServer` AutoLoad (`res://autoloads/mcp_interaction_server.gd`) over TCP port `9090` (or the port configured in `GODOT_MCP_PORT`) using `mcp_client.py` or the `godot-bridge` MCP server tools.

## When to Use
- After modifying `main.tscn`, any `.tscn` scene in `scenes/`, `Control` layouts, dialogs, icons, or UI controllers (`scripts/launcher/`, `scripts/projects/`, `scripts/tools/`, `scripts/onboarding/`).
- During `issue_resolver` or `pr_reviewer` verification to confirm the app is visually working right and meets all UI acceptance criteria.
- When debugging runtime node hierarchies, signal wiring, dialog popups, or layout rect allocation.

## Step-by-Step Procedure

### 1. Ensure No Stale Godot Instance Holds Port 9090
Before starting a visual QA session, stop any lingering Godot background instances so your new session runs the latest code and binds port `9090` cleanly:
```powershell
Stop-Process -Name "Godot*" -Force -ErrorAction SilentlyContinue
```

### 2. Import Assets & Launch OGS Launcher in the Background
First run a fast headless import pass if any new resources or scripts were added:
```powershell
godot --headless --editor --quit
```
*(Or against an active worktree: `godot --headless --editor --quit --path .worktrees/issue-<number>`).*

Next, launch the windowed application in the background using `run_command` with `WaitMsBeforeAsync: 2000` (optionally setting `$env:OGS_LIBRARY_ROOT` if you want an isolated test library directory):
```powershell
godot
```
*(Or against an active worktree: `godot --path .worktrees/issue-<number>`).*

### 3. Verify Bridge Readiness (`ping`)
Check that `McpInteractionServer` is listening on `127.0.0.1:9090`:
```powershell
python mcp_client.py ping
```
If the launcher is still booting, wait a moment and retry `python mcp_client.py ping` until it returns `{"status": "ok"}`.

### 4. Inspect UI, SceneTree, and Screenshots
Use `mcp_client.py` (or the `godot-bridge` MCP server tools such as `game_screenshot`, `game_get_ui`, `game_get_scene_tree`, `game_click`, `game_eval`) to inspect and interact with the running application:
```powershell
# Capture a screenshot to screenshot.png (and res://agent_screenshot.png)
python mcp_client.py screenshot

# Dump the full SceneTree hierarchy as formatted JSON
python mcp_client.py get_scene_tree

# List all visible Control nodes with their global positions, sizes, and text
python mcp_client.py get_ui_elements

# Inspect properties, signals, methods, and children of a specific node
python mcp_client.py get_node_info /root/Main

# Read or modify a specific node property
python mcp_client.py get_property /root/Main/AppLayout/Content/PageProjects visible
python mcp_client.py set_property /root/Main/AppLayout/Content/PageProjects visible true

# Simulate user input (mouse click at x, y or keyboard key/action press)
python mcp_client.py click 120 180
python mcp_client.py key_press ENTER

# Advance a specific number of frames
python mcp_client.py wait 5

# Check FPS, frame times, and orphan node counts
python mcp_client.py get_performance

# Execute runtime GDScript snippets
python mcp_client.py eval "return get_viewport().get_visible_rect().size"
```
After running `python mcp_client.py screenshot`, use the `read_file` tool on `screenshot.png` to visually inspect the rendered frame and confirm the application is visually working right (no text clipping, overlapping controls, broken icons, or misaligned dialogs).

### 5. Mandatory Cleanup (Release Windows File Locks)
**CRITICAL:** As soon as visual QA is complete, you **must** terminate the background Godot process so it releases port `9090` and unlocks `.godot/` and `.import/` files on Windows (otherwise `git worktree remove` or branch switches will fail):
```powershell
Stop-Process -Name "Godot*" -Force -ErrorAction SilentlyContinue
```
Remove any temporary screenshot files if needed, though `screenshot.png` and `agent_screenshot.png` are gitignored.

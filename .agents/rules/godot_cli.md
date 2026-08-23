---
name: Godot CLI Usage
description: Guidelines for running Godot CLI commands (like syntax checks and tests) safely.
trigger: always_on
---

# Godot CLI Usage Rules

When executing Godot engine from the terminal (e.g., Godot_v4.7.2-stable_win64_console.exe), strictly adhere to the following rules to prevent the application from hanging in the background:

1. **Syntax Checking**: 
   - **NEVER** run --check-only without specifying a script. Doing so will boot the entire Godot main scene invisibly and hang the agent's task runner indefinitely.
   - **ALWAYS** append --script <path_to_script.gd> or -s <path_to_script.gd> when using --check-only.

2. **Headless Execution**:
   - Remember that running Godot with --headless does not automatically make it exit when it finishes an action unless you explicitly run a script that calls quit().
   - If you start a long-running Godot process by mistake, immediately use your manage_task tool to kill the process so it does not consume system resources.

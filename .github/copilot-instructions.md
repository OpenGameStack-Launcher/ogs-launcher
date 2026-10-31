## **Project Mission: Open Game Stack (OGS)**

**Vision:** "Sovereignty Over Subscription." OGS is a portable, pre-configured development environment that bundles open-source tools into version-controlled **"Frozen Stacks."**

For full agent rules, skills, and workflow pipelines, see [AGENTS.md](../AGENTS.md).

### **1. Core Architectural Rules**

* **Version Control Everything:** The environment is the artifact. Tools are bundled and version-controlled.
* **Air-Gap First:** All features must function in a strictly offline, air-gapped environment. No external network sockets or telemetry outside the explicit download flows in `scripts/network/` and `scripts/mirror/`.
* **MOSA & RMF Compliance:** Follow Modular Open Systems Approach (MOSA) objectives. Code should be modular, portable, and meet defense simulation standards.
* **Zero Dependencies:** Avoid external installers, registry keys, or direct `%APPDATA%` usage. Resolve Central Library paths through `PathResolver` (`scripts/library/path_resolver.gd`).

### **2. Tech Stack & Syntax Preferences**

* **Primary Engine:** **Godot 4.7.2 (Stable)**. Strictly use Godot 4.7.2 GDScript syntax (`instantiate()`, `@onready`, `@export`, `Callable` signal connections, `await`) and static typing across both `scripts/` and `tests/`.
* **Godot Executable (Windows):** `godot` in `PATH` (`C:\Program Files\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`) or `C:\Program Files\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64.exe`
* **Frozen Stack Tools:** Target compatibility for Blender (4.5.7, 5.2), Krita (5.2.15, 5.3.3), Audacity (3.7.7, 3.7.8), and GIMP (3.2.4). The Tool Catalog also offers Godot 4.3 alongside 4.7.2 for projects that pin the older version; see [docs/FROZEN_STACKS.md](../docs/FROZEN_STACKS.md).
* **Implementation Language:** Primarily GDScript for the launcher; PowerShell for release and tool management scripts.

### **3. Coding Standards**

* **Documentation:** Every new function must include a clear `##` docstring explaining its purpose in the context of the OGS lifecycle.
* **Project Vision Reference:** Always refer to [docs/Design_Doc.md](../docs/Design_Doc.md) for the overarching architectural vision before proposing structural changes.
* **Privacy & Security:** Do not suggest libraries that require cloud-based authentication or proprietary license validation. Guard all file/archive operations against path traversal (`../`) and zip-slip.
* **Modularity:** Propose modular code structures that allow for easy swapping of tools or components in the future.
* **Testing & Validation:**
  - Write tests alongside new features (unit tests for logic, scene tests for UI interactions).
  - All unit and scene tests in `tests/*_tests.gd` must extend `RefCounted`, declare `class_name`, and implement `run() -> Dictionary`.
  - **CRITICAL:** Register any new `class_name` script and any new `tests/*_tests.gd` file inside `tests/test_runner.gd` (preload the class and append the test file path to `test_files`).
  - Scene tests must `.free()` all created UI nodes to avoid resource leaks, and any spawned `Thread` must be joined (`wait_to_finish()`) on exit.
  - **Visual QA (MCP Bridge):** When modifying UI scenes (`main.tscn`, `scenes/*.tscn`), layouts, dialogs, or icons, launch the application in debug mode and use `McpInteractionServer` (`res://autoloads/mcp_interaction_server.gd` on `127.0.0.1:9090`) with `python mcp_client.py screenshot` and `python mcp_client.py get_ui_elements` (or `godot-bridge` MCP tools; see [`.agents/skills/mcp-visual-qa/SKILL.md`](../.agents/skills/mcp-visual-qa/SKILL.md)) to visually verify that the application is working right. Stop the background Godot instance (`Stop-Process -Name "Godot*" -Force -ErrorAction SilentlyContinue`) when done.
  - Update [docs/TESTING.md](../docs/TESTING.md) when adding new test suites or changing test patterns.
* **Performance:** Optimize for minimal resource usage, especially in offline mode. Avoid unnecessary background processes or network calls.
* **Error Handling:** Implement robust error handling that provides clear feedback to the user without crashing the application, especially in air-gapped environments.
* **Logging:** Use `OgsLogger` (`const OgsLogger = preload("res://scripts/logging/logger.gd")`) for operational events; avoid raw `print()` and never name the constant `Logger` (which collides with Godot 4's built-in `Logger` class). Include context (component, project, tool) and avoid sensitive data. Logs live under `user://logs/ogs_launcher.log` with rotation.
* **Session Continuity (Local Notes):** To preserve context across long chats, periodically save short handoff summaries to `notes/` (local-only, ignored by git). Use `notes/tools/save_session_note.ps1` and append to the daily note file.

### **4. Git, Issue & PR Workflow**

* **Never commit directly to `main`.** Always work inside an isolated Git worktree under `.worktrees/` (e.g., `git worktree add .worktrees/issue-<number> -b fix/issue-<number>-<short-description> origin/main`).
* Follow the canonical workflow guides:
  - **Creating Issues:** [docs/CREATING_ISSUES.md](../docs/CREATING_ISSUES.md)
  - **Resolving Issues:** [docs/RESOLVING_ISSUES.md](../docs/RESOLVING_ISSUES.md)
  - **Reviewing & Merging PRs:** [docs/REVIEWING_AND_MERGING_PRS.md](../docs/REVIEWING_AND_MERGING_PRS.md)
* Always stage and commit generated `.uid` files alongside new or moved scripts and scenes.

### **5. Development Tracking & Test Execution**

* See [docs/The_Plan.md](../docs/The_Plan.md) for the MVP definition, current progress, and development roadmap.
* All pull requests must pass the headless test suite:
  - **Windows (PowerShell):**
    ```powershell
    godot --headless --editor --quit
    godot --headless -s res://tests/test_runner.gd
    ```
  - **Linux/macOS:** `godot --headless --script res://tests/test_runner.gd`

### **6. Session Handoff Practice**

* For long sessions, create a short handoff note at logical milestones (feature completion, blocker discovery, or before context gets crowded).
* Use the VS Code task **"Notes: Save Session Snapshot"** or run:
  - `powershell -ExecutionPolicy Bypass -File .\notes\tools\save_session_note.ps1 -AppendToDaily -Title "<milestone title>"`
* Keep each snapshot brief: what changed, key decisions, next step, open items.
* In a new session, read `notes/*.md` first to regain context quickly.

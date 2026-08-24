## **Project Mission: Open Game Stack (OGS)**

**Vision:** "Sovereignty Over Subscription." OGS is a portable, pre-configured development environment that bundles open-source tools into version-controlled **"Frozen Stacks."**

### **1. Core Architectural Rules**

* **Version Control Everything:** The environment is the artifact. Tools are bundled and version-controlled.
* **Air-Gap First:** All features must function in a strictly offline, air-gapped environment. No external network sockets or "phone home" telemetry.
* **MOSA & RMF Compliance:** Follow Modular Open Systems Approach (MOSA) objectives. Code should be modular, portable, and meet defense simulation standards.
* **Zero Dependencies:** Avoid external installers, registry keys, or `%APPDATA%` usage. Everything must run from a single, portable folder.

### **2. Tech Stack & Syntax Preferences**

* **Primary Engine:** **Godot 4.7.2 (Stable)**. Strictly use Godot 4.7.2 GDScript syntax (e.g., use `instantiate()` instead of `instance()`, and new `@export` annotations).
* **Godot Executable (Windows):** `C:\Program Files\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64.exe`
* **Frozen Stack Tools:** Target compatibility for Blender 4.5.7, Krita 5.2.15, and Audacity 3.7.7.
* **Implementation Language:** Primarily GDScript for the launcher; Bash/PowerShell for tool management scripts.

### **3. Coding Standards for Copilot**

* **Documentation:** Every new function must include a clear docstring explaining its purpose in the context of the OGS lifecycle.
* **Project Vision Reference:** Always refer to `design_doc.md` for the overarching architectural vision before proposing structural changes.
* **Privacy & Security:** Do not suggest libraries that require cloud-based authentication or proprietary license validation.
* **Modularity:** Propose modular code structures that allow for easy swapping of tools or components in the future.
* **Testing & Validation:** 
  - Write tests alongside new features (unit tests for logic, scene tests for UI interactions).
  - All unit tests must extend `RefCounted`, declare `class_name`, and implement `run() -> Dictionary`.
  - Scene tests must free all created UI nodes to avoid resource leaks.
  - Update [docs/TESTING.md](../docs/TESTING.md) when adding new test categories or changing test patterns.
  - New features require tests before merging; existing tests must continue to pass.
* **Performance:** Optimize for minimal resource usage, especially in offline mode. Avoid unnecessary background processes or network calls.
* **Error Handling:** Implement robust error handling that provides clear feedback to the user without crashing the application, especially in air-gapped environments.
* **Logging:** Use the `Logger` in `scripts/logging/logger.gd` for operational events; avoid raw prints. Include context (component, project, tool) and avoid sensitive data. Logs live under user:// with rotation.
* **User Experience:** Prioritize a simple, intuitive user interface for the OGS Launcher that abstracts away complexity while providing necessary controls for both indie developers and enterprise users.
* **Security Best Practices:** Ensure that all code adheres to security best practices, especially when handling file operations or user input, to prevent vulnerabilities in the launcher or tool management scripts.
* **Session Continuity (Local Notes):** To preserve context across long chats, periodically save short handoff summaries to `notes/` (local-only, ignored by git). Use `notes/tools/save_session_note.ps1` and append to the daily note file.

### **4. Development Tracking**

* See [docs/The_Plan.md](../docs/The_Plan.md) for the MVP definition, current progress, and development roadmap.
* Tasks are marked as completed (✅) and in-progress (🔄) as work advances.
* The plan ties directly to [docs/Design_Doc.md](../docs/Design_Doc.md) for architectural vision.
* All pull requests must pass the manifest test suite:
  - **Windows:** `$start = Get-Date; & "C:\Program Files\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64.exe" --headless --script res://tests/test_runner.gd 2>&1 | Select-Object -Last 10; $elapsed = ((Get-Date) - $start).TotalSeconds; Write-Host "Exit code: $LASTEXITCODE (execution time: $elapsed seconds)"`
  - **Linux/macOS:** `godot --headless --script res://tests/test_runner.gd`
  - Note: The Windows command includes output piping (`2>&1 | Select-Object`) to ensure proper stdout/stderr handling and prevent terminal hangs.

### **5. Session Handoff Practice (Copilot Workflow)**

* For long sessions, create a short handoff note at logical milestones (feature completion, blocker discovery, or before context gets crowded).
* Use the VS Code task **"Notes: Save Session Snapshot"** or run:
  - `powershell -ExecutionPolicy Bypass -File .\notes\tools\save_session_note.ps1 -AppendToDaily -Title "<milestone title>"`
* Keep each snapshot brief: what changed, key decisions, next step, open items.
* In a new session, read `notes/*.md` first to regain context quickly.

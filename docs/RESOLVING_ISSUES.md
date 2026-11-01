# Issue Resolution Workflow & Standards

This document establishes the official standards, Git worktree workflow, and coding guidelines for anyone resolving issues in the **Open Game Stack (OGS) Launcher** repository, whether human contributor or autonomous agent.

---

## 0. Operational Rules
* **PowerShell Chaining:** When executing shell commands on Windows, NEVER use `&&` to chain commands together (it fails in Windows PowerShell 5.1). Instead, use `;` or execute commands sequentially in separate tool calls.
* **File Generation Encoding:** Generating text files via PowerShell pipes (e.g., `>` or `Set-Content` without explicit UTF-8 encoding) often creates UTF-16 LE encoding errors or adds a UTF-8 BOM (Byte Order Mark). Godot will fail to parse `.tscn` or `.gd` files that contain a BOM (`Parse Error: Expected '['`). ALWAYS use your native agent file-writing and editing tools (`write_file` / `edit_file`) to generate or edit text, scene, or script files.
* **Documentation Redundancy:** Before requesting the PR Reviewer to document a feature or testing steps, always verify whether the documentation already exists in `docs/The_Plan.md`, `docs/TESTING.md`, or `docs/MANUAL_TESTING.md`. Do not duplicate existing specification notes.

---

## 1. Role Overview & Core Boundaries

The **Issue Resolver** is responsible for taking an open issue from conception to an unmerged, thoroughly tested, and well-documented Pull Request.

### Primary Responsibilities
1. **Triage & Select:** Identify the next unblocked issue based on dependencies, priority, and issue number.
2. **Worktree Isolation:** Create and work within an isolated Git worktree under `.worktrees/`.
3. **Implement:** Write clean, modular, air-gap-safe, and statically typed GDScript code meeting all acceptance criteria.
4. **Test:** Run the automated test suite (`tests/test_runner.gd`), add new unit or scene tests in `tests/`, register new suites in `tests/test_runner.gd`, and perform visual QA via the MCP bridge (`McpInteractionServer` and `mcp_client.py`) if UI changes are involved.
5. **Detailed Pull Request:** Push the branch and submit a detailed PR against `main`.

### Explicit Boundaries (What the Issue Resolver Does NOT Do)
* **DO NOT merge into `main`:** The Issue Resolver must never merge the PR or push directly to `main`.
* **DO NOT update project documentation:** Updating `docs/The_Plan.md`, `docs/TESTING.md`, `docs/MANUAL_TESTING.md`, schema docs, or `README.md` is handled by the **PR Reviewer & Documentation Agent** (unless the issue itself is specifically a documentation-only issue). The resolver provides the necessary handoff details in the PR body so the reviewing agent can update documentation accurately on the branch prior to merge.

---

## 2. Issue Discovery & Triage Protocol

When tasked with resolving an issue, follow this triage procedure:

### 1. Inspect Open Issues
List open issues via the GitHub CLI:
```powershell
gh issue list --state open --limit 50 --json number,title,labels,body
```

> [!WARNING]
> **NEVER run a bare `gh issue view <id>` command.** Repository token configurations can trigger a `read:project` scope error for bare view commands. You must ALWAYS pass the `--json` flag:

```powershell
gh issue view <issue_number> --json number,title,body,state,labels,assignees
```

### 2. Dependency Checking (`Depends on #X`)
* Read the issue description carefully.
* If the issue header or body contains **`Depends on #<number>`**, check the status of the dependency:
  ```powershell
  gh issue view <dependency_number> --json state
  ```
* If the dependency issue is still `OPEN`, **do not begin work on this issue**. Move to the next unblocked issue or report the blocker.
* Only begin work if all dependencies are `CLOSED` and their pull requests are merged into `main`.

### 3. Issue Selection Strategy
Unless instructed to work on a specific issue:
1. Prioritize unblocked issues by severity (`severity: critical`, `severity: high`) and foundational dependencies (`scripts/config`, `scripts/manifest`, `scripts/library`, `scripts/network`) before localized UI tweaks.
2. Within the same priority tier, select the lowest-numbered open issue.

---

## 3. Git Worktree & Branching Workflow

All work must occur inside an isolated worktree under `.worktrees/` to keep the primary working tree clean.

### 1. Fetch Latest Remote Changes
```powershell
git fetch origin
```

### 2. Create the Worktree
Create a new branch based on `origin/main` inside `.worktrees/issue-<number>`:
```powershell
git worktree add .worktrees/issue-<number> -b fix/issue-<number>-<short-description> origin/main
```
*(Use `feature/issue-<number>-<short-description>` for new features or enhancements, or `fix-issue-<number>` for simple bug fixes).*

*Example:*
```powershell
git worktree add .worktrees/issue-42 -b fix/issue-42-editor-settings-isolation origin/main
```

Run all commands, tests, and commits inside `.worktrees/issue-<number>`.

### 3. Commit Guidelines & Clean Working Tree Check
* Use clear commit messages referencing the issue or [Conventional Commits](https://www.conventionalcommits.org/):
  * `fix: <description> (Fixes #<number>)` or `Fix #<number>: <description>`
  * `feat: <description> (Resolves #<number>)`
  * `test: <description>`
  * `refactor: <description>`
* **CRITICAL:** After committing and BEFORE pushing or opening a PR, run `git status` inside the worktree. Ensure there are **no modified files** and **no untracked files** (such as `.uid` files generated by Godot or temporary `pr_body.md` files). Stage and commit any legitimate `.uid` files, and delete any temporary scratch files.

---

## 4. Coding & Architecture Standards

### 1. OGS Core Architectural Rules
* **Air-Gap First:** Never introduce external network calls, telemetry, or sockets outside the explicit download flows in `scripts/network/` and `scripts/mirror/`. All network access must obey `OfflineEnforcer` and `SocketBlocker`.
* **Zero Dependencies & Portable Paths:** Never use external installers or registry keys. Resolve Central Library paths exclusively through `PathResolver` (`scripts/library/path_resolver.gd`) so `OGS_LIBRARY_ROOT` test isolation is respected.
* **Security & Input Validation:** Treat `ogs_stack.json`, `ogs_config.json`, `repository.json`, and ZIP archives as untrusted input. Validate SHA-256 hashes where required and guard against path traversal (`../`) and zip-slip attacks.

### 2. Godot 4.7.2 & GDScript Standards
1. **Godot 4.7.2 Syntax:** Strictly use Godot 4.7.2 syntax (`instantiate()`, `@onready`, `@export`, `Callable`-based `connect()`, `await`).
2. **Static Typing Everywhere:**
   * Always annotate variable types, function parameters, and return types across both `scripts/` and `tests/`.
   * Dynamic node lookups (`get_node()`, `get_node_or_null()`) must include explicit type annotations and casting:
     ```gdscript
     var my_label: Label = get_node_or_null("Header/Title") as Label
     ```
3. **Metadata Files (`.uid`):**
   * Godot 4.7.2 generates `.uid` metadata files alongside `.gd` scripts, scenes, and assets. Always stage and commit these `.uid` files alongside your changes.
4. **Naming Conventions:**
   * **Classes & Nodes:** `PascalCase` (e.g., `ProjectsController`, `StackManifest`)
   * **Variables & Functions:** `snake_case` (e.g., `library_root`, `_on_add_project_pressed()`)
   * **Constants:** `UPPER_SNAKE_CASE` (e.g., `DEFAULT_SCHEMA_VERSION`, `MAX_BYTES`)
   * **Signals:** `snake_case` in past tense or action-oriented (e.g., `tool_list_updated`, `hydration_completed`)
5. **Docstrings & Comments:**
   * Every new function must include a `##` docstring explaining its purpose in the context of the OGS lifecycle.
   * Document the *why* and non-obvious invariants rather than restating obvious syntax.

---

## 5. Logging Standards (`OgsLogger`)

Avoid raw `print()` statements in production code. Use the structured logger in `scripts/logging/logger.gd`:
* **CRITICAL NAMING RULE:** Always preload `res://scripts/logging/logger.gd` as `OgsLogger`. Do **not** name the constant `Logger`, because `Logger` is a built-in engine class in Godot 4.7.2:
  ```gdscript
  const OgsLogger = preload("res://scripts/logging/logger.gd")
  ```
* Use appropriate severity levels with structured context dictionaries:
  * `OgsLogger.debug("Message", {"component": "my_component"})`
  * `OgsLogger.info("Message", {"component": "my_component", "tool": tool_id})`
  * `OgsLogger.warn("Message", {"component": "my_component", "error_code": code})`
  * `OgsLogger.error("Message", {"component": "my_component", "error_code": code})`
* Never log raw user-identifying filesystem paths, tokens, or secrets (`system_path`, `absolute_path`, and `local_path` keys are redacted by `OgsLogger`).

---

## 6. Automated Testing Standards

Every feature, bug fix, or refactoring change must be backed by automated tests in `tests/`.

### Test Architecture in OGS Launcher
* All test files live in `tests/*_tests.gd`.
* Each test suite:
  1. Extends `RefCounted`
  2. Declares a `class_name` (e.g., `class_name MyFeatureTests`)
  3. Implements `func run() -> Dictionary` (may be synchronous or `async` using `await`) returning:
     ```gdscript
     {"passed": int, "failed": int, "failures": Array}
     ```
  4. Uses the `_expect(condition: bool, message: String, results: Dictionary) -> void` helper pattern.
* **CRITICAL: Mandatory Registration in `tests/test_runner.gd`:**
  Unlike runners that auto-scan directories, `tests/test_runner.gd` explicitly preloads scripts and lists test files:
  1. If you created a new script in `scripts/` with a `class_name`, add `load("res://scripts/<domain>/<file>.gd")` to the preload block in `tests/test_runner.gd`.
  2. If you created a new test suite file in `tests/`, append `"res://tests/<your_suite>_tests.gd"` to the `test_files` array in `tests/test_runner.gd`.
* **CRITICAL: Resource Cleanup in Scene & Thread Tests:**
  * Scene tests that instantiate UI controls or scenes (`Label.new()`, `main_scene.instantiate()`, etc.) must call `.free()` (not `.queue_free()`) on all created root nodes before returning so no orphan nodes leak at process exit.
  * Any test or controller that spawns a `Thread` must join it (`wait_to_finish()`) during cleanup.
* **Test Library Isolation:**
  * `tests/test_runner.gd` automatically sets `OGS_LIBRARY_ROOT` to `%LOCALAPPDATA%\OGS_TEST\Library` and cleans it up on completion, ensuring production `%LOCALAPPDATA%\OGS\Library` is never touched.

### Running Automated Tests
From inside your worktree directory (`.worktrees/issue-<number>`), first run a headless editor import pass if you added new files or `class_name` declarations, then execute the test runner:

```powershell
godot --headless --editor --quit
godot --headless -s res://tests/test_runner.gd
```

*(Note: `godot` in `PATH` invokes `C:\Program Files\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`. Never pass `--check-only` without `-s <script.gd>`).*

### Verification Gate
* **Zero Failures:** All existing and newly added tests must pass (`tests passed: X`, `tests failed: 0`, exit code `0`).
* Note: `ERROR: Parse JSON failed` lines printed during negative JSON validation tests are expected; pass/fail is determined by `tests failed: 0` and `exiting with code 0`.

### Agentic Visual QA (MCP Bridge)
If your issue involves UI layout, scenes (`main.tscn`, `scenes/*.tscn`), dialogs, icons, or visual polish, you must visually verify your changes using the MCP bridge before submitting the PR (see [`.agents/skills/mcp-visual-qa/SKILL.md`](../.agents/skills/mcp-visual-qa/SKILL.md)):
1. Stop any lingering Godot instances: `Stop-Process -Name "Godot*" -Force -ErrorAction SilentlyContinue`.
2. Start a fresh instance of the worktree application in the background: `godot --path .worktrees/issue-<number>`.
3. In debug mode, this automatically starts the `McpInteractionServer` AutoLoad (`res://autoloads/mcp_interaction_server.gd`) on `127.0.0.1:9090`.
4. Run `python mcp_client.py ping`, `python mcp_client.py screenshot`, and `python mcp_client.py get_ui_elements` (or use the `godot-bridge` MCP server tools) to capture `screenshot.png` and inspect the live SceneTree and Control bounds.
5. View `screenshot.png` with `read_file` to verify that the application is visually working right and has no clipping, overlap, or broken layout.
6. **CRITICAL:** Once visual QA is complete, terminate the background Godot process (`Stop-Process -Name "Godot*" -Force -ErrorAction SilentlyContinue`) to close the window and release Windows file locks and port `9090`.

---

## 7. Submitting the Pull Request

Once the fix is implemented, tested, and committed with a clean working tree:

### 1. Push Feature Branch
```powershell
git push -u origin HEAD
```

### 2. Create the Pull Request
Submit the PR targeting `main` using the GitHub CLI. Write the PR description to a temporary file outside git tracking (or remove `pr_body.md` immediately after creating the PR) and pass `--body-file` to avoid PowerShell string-escaping issues:

```powershell
gh pr create --title "<type>: <concise description> (Resolves #<number>)" --body-file pr_body.md --base main
Remove-Item -Path pr_body.md -Force -ErrorAction SilentlyContinue
```

### Required PR Body Structure
Every PR submitted by an Issue Resolver must follow `.github/pull_request_template.md` and include:
1. **Closes / Resolves Link:** `Resolves #<number>`
2. **Summary & Context:** Summary of the issue being addressed and root cause or design rationale.
3. **Key Changes & Technical Scope:** Detailed breakdown of modified, added, or deleted files.
4. **Automated Testing & Verification:** Confirmation of test execution (`tests passed: X`, `tests failed: 0`) and summary of new test cases added.
5. **Handoff for PR Reviewer & Documentation Agent:**
   * Specific recommendations on whether `docs/The_Plan.md` or `docs/Design_Doc.md` need updates.
   * Specific updates needed for `docs/TESTING.md`, `docs/MANUAL_TESTING.md`, or schema docs (`docs/*_SCHEMA.md`).
   * Any `README.md` updates if user-facing UI or workflows changed.

### 3. Stop and Stand Down
After opening the PR:
* **Do not merge the pull request.**
* **Do not delete the worktree yet** (the PR Reviewer agent will reuse `.worktrees/issue-<number>` to run verification tests and commit documentation updates, and will remove the worktree upon merge).
* Report the PR URL and summary back to the orchestrator or user.

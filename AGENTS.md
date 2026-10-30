# AI Agent Guidelines for OGS Launcher

Welcome to the **Open Game Stack (OGS) Launcher** repository. This file is the primary entry point for AI coding agents working in this workspace.

## 1. Project Mission & Core Architecture

**Vision:** "Sovereignty Over Subscription." OGS Launcher is a portable, pre-configured desktop application built in **Godot 4.7.2 (Stable)** that manages open-source game development tools into version-controlled **"Frozen Stacks."**

All code changes must strictly preserve these four architectural pillars:
1. **Air-Gap First:** Every feature must function in a strictly offline, air-gapped environment. No external network calls, analytics, or telemetry outside the explicit tool-download flows in `scripts/network/` and `scripts/mirror/`. All socket operations must respect `OfflineEnforcer` and `SocketBlocker`.
2. **Zero External Dependencies:** Avoid external installers, Windows registry dependencies, or unapproved system modifications. Central Library paths must be resolved through `PathResolver` (`scripts/library/path_resolver.gd`), which supports environment-variable isolation (`OGS_LIBRARY_ROOT`) for testing.
3. **MOSA Modularity:** Keep UI orchestration, domain logic, manifest parsing, and file operations cleanly separated across `scripts/` submodules. Avoid growing God classes in `main.gd` or page controllers.
4. **Defensive Security:** Treat `stack.json`, `ogs_config.json`, `repository.json`, and downloaded ZIP archives as untrusted input. Enforce SHA-256 verification and guard all file/archive paths against directory traversal (`../`) and zip-slip attacks. See `docs/SECURITY_CONSIDERATIONS.md`.

---

## 2. Environment & Shell Rules

- **Operating System:** Windows 11 with **PowerShell**.
- **PowerShell Syntax:** Never use Linux shell commands (`grep`, `ls`, `cat`, `sed`, `awk`) or bash command chaining (`&&` in Windows PowerShell 5.1). Use `;` or separate tool calls, and prefer built-in agent file/search tools over shell commands.
- **UTF-8 File Encoding:** Never generate `.gd`, `.tscn`, `.tres`, or markdown files using PowerShell redirection (`>` or `Set-Content` without UTF-8 encoding), as UTF-16 LE or UTF-8 BOMs will cause Godot scene/script parser errors (`Parse Error: Expected '['`). Always use your native file-writing tools.
- **GitHub CLI (`gh`) Token Scope Guardrail:** Never run bare `gh issue view <id>` or `gh pr view <id>` commands, as they can fail with `read:project` token scope errors. Always pass explicit `--json` fields:
  - `gh issue view <id> --json number,title,body,state,labels,assignees`
  - `gh pr view <id> --json number,title,body,state,baseRefName,headRefName,commits,files`

---

## 3. Tech Stack, Logging & Testing Conventions

- **Engine Version:** Godot 4.7.2 (Stable). Strictly use Godot 4.x GDScript syntax (`instantiate()`, `@onready`, `@export`, `Callable` signal connections, `await`) and **static typing** for all variables, parameters, and return types across both `scripts/` and `tests/`.
- **Godot CLI Executable:**
  - Global command in `PATH`: `godot` (wraps `C:\Program Files\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe`)
  - Never run `--check-only` without `-s <script.gd>`.
- **Structured Logging (`OgsLogger`):**
  - Never use raw `print()` for operational events in production code.
  - Always preload and reference `scripts/logging/logger.gd` as `OgsLogger` (do **not** name the constant `Logger`, which collides with Godot 4's built-in `Logger` class):
    ```gdscript
    const OgsLogger = preload("res://scripts/logging/logger.gd")
    ```
  - Never log sensitive user paths, credentials, or tokens (`system_path`, `absolute_path`, and `local_path` keys are automatically redacted).
- **Automated Test Suite (`tests/test_runner.gd`):**
  - All unit and scene test suites live in `tests/*_tests.gd`, extend `RefCounted`, declare a `class_name`, and implement `func run() -> Dictionary` returning `{"passed": int, "failed": int, "failures": Array}`.
  - **CRITICAL REGISTRATION STEP:** `tests/test_runner.gd` does **not** auto-discover test files on disk. Whenever you add a new script with a `class_name` or a new test suite file, you **MUST** register it in `tests/test_runner.gd` (add `load("res://scripts/...")` in the preload section and append `"res://tests/<your_test>_tests.gd"` to `test_files`).
  - Scene tests must explicitly `.free()` all instantiated UI nodes before returning to prevent ObjectDB leaks.
  - Run the test suite headlessly:
    ```powershell
    godot --headless --editor --quit
    godot --headless -s res://tests/test_runner.gd
    ```
- **Godot `.uid` Files:** Always stage and commit generated `.uid` metadata files alongside any new or moved `.gd` scripts or resources.

---

## 4. Workflows, Skills & Canonical Documentation

This project uses a structured multi-agent workflow for issue creation, resolution, PR review, and release management:

### Agent Skills (`.agents/skills/`)
- **Issue Orchestration (`.agents/skills/issue-orchestration/SKILL.md`):** Defines how the primary orchestrator spawns and manages single-task `issue_creator`, `issue_resolver`, and `pr_reviewer` subagents sequentially with 10-minute liveness timers and strict user authorization gates.
- **Release Management (`.agents/skills/release-management/SKILL.md`):** Defines the `release_manager` subagent pipeline for building, stamping, verifying, and publishing Windows alpha release packages (`scripts/release/build_alpha_package.ps1`).
- **Code Review (`.agents/skills/code-review/SKILL.md`):** Structured checklist for reviewing GDScript, `.tscn`, `.tres`, and `project.godot` diffs against Godot 4.7.2 and OGS standards.

### Canonical Workflow Guides (`docs/`)
- **Creating Issues:** [docs/CREATING_ISSUES.md](docs/CREATING_ISSUES.md)
- **Resolving Issues:** [docs/RESOLVING_ISSUES.md](docs/RESOLVING_ISSUES.md)
- **Reviewing & Merging PRs:** [docs/REVIEWING_AND_MERGING_PRS.md](docs/REVIEWING_AND_MERGING_PRS.md)
- **Automated Testing Guide:** [docs/TESTING.md](docs/TESTING.md)
- **Manual Testing Guide:** [docs/MANUAL_TESTING.md](docs/MANUAL_TESTING.md)
- **Project Architecture & Roadmap:** [docs/Design_Doc.md](docs/Design_Doc.md) and [docs/The_Plan.md](docs/The_Plan.md)
- **Alpha Packaging Guide:** [docs/ALPHA_PACKAGING.md](docs/ALPHA_PACKAGING.md)

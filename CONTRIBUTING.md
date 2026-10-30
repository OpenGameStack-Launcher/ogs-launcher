# Contributing to Open Game Stack

First off, thank you for considering contributing to Open Game Stack (OGS)! It is contributors like you that make this tool "Standard Issue" for both indie devs and defense engineers.

## 🔰 The "Prime Directive"
**OGS is a Sovereign Tool.**
Every feature you add must adhere to one core rule: **It must work offline.**
* ❌ **Bad:** Adding a "News Feed" that crashes if the internet is down.
* ✅ **Good:** Adding a "News Feed" that gracefully hides itself when offline.
* ❌ **Bad:** Adding a dependency on a proprietary library (e.g., FMOD, Wwise) that requires a license server.
* ✅ **Good:** Integrating a new Open Source tool (e.g., Material Maker) that runs from a portable folder.

## 🛠️ Getting Started

### Prerequisites
* **Godot 4.7.2 (Stable):** We use the standard stable release. Please do not use betas or nightly builds for PRs unless specified.
* **Git:** You should be comfortable with branching, worktrees, and pull requests.

### Setup
1.  **Fork or Clone** the repository on GitHub:
    ```powershell
    git clone https://github.com/OpenGameStack-Launcher/ogs-launcher.git
    ```
2.  **Import** the `project.godot` file into the Godot 4.7.2 Editor.
3.  **Run** the project (F5) to verify the Launcher starts.

## 💻 Development & Agent Workflow

Our repository uses a structured workflow for both human contributors and autonomous AI agents. Before creating issues, implementing fixes, or reviewing Pull Requests, review our canonical workflow guides:
* **[AGENTS.md](AGENTS.md):** Overview of agent rules, skills, and architectural invariants.
* **[Creating Issues](docs/CREATING_ISSUES.md):** Issue templates, labeling conventions, and acceptance criteria checklists.
* **[Resolving Issues](docs/RESOLVING_ISSUES.md):** Git worktree isolation, coding standards, test suite registration, and PR handoff format.
* **[Reviewing & Merging PRs](docs/REVIEWING_AND_MERGING_PRS.md):** Code review checklist, documentation stewardship, merge commit standards, and worktree cleanup.

### Quick Summary
1.  **Create an Isolated Worktree Branch:**
    ```powershell
    git fetch origin
    git worktree add .worktrees/issue-42 -b fix/issue-42-short-description origin/main
    ```
2.  **Code:** Write statically typed Godot 4.7.2 GDScript.
    * Follow the [official GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).
    * Use `snake_case` for variables, functions, and signals; `PascalCase` for classes and nodes; `UPPER_SNAKE_CASE` for constants.
    * Use `OgsLogger` (`const OgsLogger = preload("res://scripts/logging/logger.gd")`) for structured logging (avoid raw `print()` and never log sensitive user paths).
3.  **Test:** Ensure your changes preserve "Sovereign Mode" and pass all headless tests:
    * Add unit or scene tests in `tests/*_tests.gd` and register new suites in `tests/test_runner.gd`.
    * Run `godot --headless -s res://tests/test_runner.gd` and confirm `tests failed: 0`.
    * Review [docs/SECURITY_CONSIDERATIONS.md](docs/SECURITY_CONSIDERATIONS.md) for common security pitfalls.
4.  **Commit & Push:**
    * Stage all modified files including generated `.uid` files (`git status` must be clean).
    * Push your branch and open a Pull Request against `main` using `.github/pull_request_template.md`.

## 📝 Reporting Bugs & Requesting Features
Please open an Issue using the predefined templates in `.github/ISSUE_TEMPLATE/` (`bug_report.md` or `feature_request.md`) and follow [docs/CREATING_ISSUES.md](docs/CREATING_ISSUES.md).

## 📜 License
By contributing to Open Game Stack, you agree that your contributions will be licensed under its **MIT License**.

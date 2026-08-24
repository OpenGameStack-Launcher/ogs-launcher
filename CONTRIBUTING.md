# Contributing to Open Game Stack

First off, thank you for considering contributing to Open Game Stack (OGS)! It's people like you that make this tool "Standard Issue" for both indie devs and defense engineers.

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
* **Git:** You should be comfortable with branching and merging.

### Setup
1.  **Fork** the repository on GitHub.
2.  **Clone** your fork locally:
    ```bash
    git clone [https://github.com/YOUR_USERNAME/open-game-stack.git](https://github.com/YOUR_USERNAME/open-game-stack.git)
    ```
3.  **Import** the `project.godot` file into the Godot Editor.
4.  **Run** the project (F5) to verify the Launcher starts.

## 💻 Development Workflow

1.  **Create a Branch:**
    ```bash
    git checkout -b feature/my-new-feature
    # or
    git checkout -b fix/issue-number
    ```
2.  **Code:** Write your GDScript.
    * We follow the [official GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).
    * Use `snake_case` for variables and functions.
    * Use `PascalCase` for classes and nodes.
3.  **Test:** Ensure your changes don't break the "Sovereign Mode" (try turning off your wifi and running the launcher!).
    * Review [docs/SECURITY_CONSIDERATIONS.md](docs/SECURITY_CONSIDERATIONS.md) for common security pitfalls.
    * Use the `Logger` utility in `scripts/logging/logger.gd` for structured logging (avoid raw prints and sensitive paths).
4.  **Commit:**
    ```bash
    git commit -m "feat: Add support for Material Maker in stack.json"
    ```
5.  **Push & PR:** Push to your fork and open a Pull Request against our `main` branch.

## 📝 Reporting Bugs
If you find a bug, please open an Issue using the following template:
* **OS:** (e.g., Windows 11, Ubuntu 22.04)
* **Godot Version:** (e.g., 4.7.2 Stable)
* **What happened:**
* **What you expected to happen:**
* **Steps to reproduce:**

## 📜 License
By contributing to Open Game Stack, you agree that your contributions will be licensed under its **MIT License**.
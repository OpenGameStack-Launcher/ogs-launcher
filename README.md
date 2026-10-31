# Open Game Stack (OGS)

![Engine](https://img.shields.io/badge/Godot-4.7.2-blue)
![License](https://img.shields.io/badge/License-MIT-green)
[![CI](https://github.com/OpenGameStack-Launcher/ogs-launcher/actions/workflows/ci.yml/badge.svg)](https://github.com/OpenGameStack-Launcher/ogs-launcher/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/OpenGameStack-Launcher/ogs-launcher)](https://github.com/OpenGameStack-Launcher/ogs-launcher/releases/latest)

> **The "Studio-in-a-Box" for Sovereign Game Development.**

## 🎮 What is Open Game Stack?
Open Game Stack (OGS) is a **portable, pre-configured development environment** that bundles the best open-source tools into a single, version-controlled workflow.

Instead of installing Godot, Blender, Krita, Audacity, Git, and VSCodium separately (and hoping their versions match your team's), OGS gives you a **"Frozen Stack."** 

### One Download. Zero Install.
* **The Engine:** Godot 4.7.2 (Stable / Hardened) - the version the Launcher itself is built with; the Tool Catalog also offers Godot 4.3 for projects that pin it
* **The Pipeline:** Blender, Krita, Audacity, GIMP, Git, VSCodium
* **The Promise:** Everything runs from a single folder. No registry keys, no `%APPDATA%`, no installers.

---

## 🚀 Why Use OGS?

### For Indie Devs & Studios: "It Just Works"
* **Onboarding in Seconds:** Clone the repo, click "Launch," and you have the exact same tools as the rest of your team.
* **USB Portable:** Run your entire studio from a flash drive. Move between Windows and Linux without breaking your project.
* **No "Update Shock":** We freeze the tool versions. Your project won't break because Blender auto-updated overnight.

### For Enterprise & Defense: "Sovereign Simulation"
* **Air-Gap Native:** Designed for secure environments. The OGS Launcher can enforce a strict **Offline Mode**, disabling all network sockets and "phone home" telemetry.
* **Environment as the Artifact:** Don't just archive your source code; archive the *factory* that built it. Ensure you can rebuild your project in 20 years, even if the vendors disappear.
* **Supply Chain Security:** Eliminate reliance on subscription servers and proprietary license validation.

---

## 🛠️ The OGS Launcher
The heart of the stack is the **OGS Launcher**, a custom application (built in Godot!) that manages your development environment.



### Core Features
* **Manifest System (`stack.json`):** A simple text file that defines exactly which version of Godot or Blender your project requires.
* **Dual-Mode Operation:**
    * **Provisioning Mode:** For connected workstations. Downloads and sets up tools automatically.
    * **Sovereign Mode:** For secure labs. Locks the environment to "Read-Only" and blocks internet access.
* **Project "Sealing":** An automated workflow to clean, sanitize, and lock a project for delivery or long-term archival.
* **Remote Project Git Cloning:** Clone remote OGS projects directly from Git URLs with automatic pre-checkout manifest verification, PortableGit resolution, and subfolder collision handling.

---

## 📂 Documentation
* **[Technical Design Document](docs/Design_Doc.md):** Deep dive into the "Frozen Stack" architecture, directory structure, and `stack.json` schema.
* **[Release Packaging Guide](docs/RELEASE_PACKAGING.md):** Build and publish Windows release ZIP packages for distribution.
* **[Testing Guide](docs/TESTING.md):** How to run the automated test suite and what each test covers.
* **[Manual Testing Guide](docs/MANUAL_TESTING.md):** Step-by-step user-facing test scenarios for both editor and installed-build modes.
* **[Sample Projects](samples/README.txt):** Quick launcher test inputs for both development/linked mode and sealed-style mode.

## ⬇️ Download

A pre-built Windows binary is available for testing:

**[Download OGS Launcher (Latest Windows x64 Release)](https://github.com/OpenGameStack-Launcher/ogs-launcher/releases/latest)**

Extract the ZIP, keep `OGS-Launcher.exe` and `OGS-Launcher.pck` together, and run. No installation required.

---

## 🏁 Getting Started

### Prerequisites
* Windows 10/11 or Linux (Ubuntu 22.04+)
* [Godot 4.7.2](https://godotengine.org) (To run the Launcher source)

### Quick Start
1.  **Clone the Repo:**
    ```bash
    git clone https://github.com/OpenGameStack-Launcher/ogs-launcher.git
    ```
2.  **Open in Godot:** Import the `project.godot` file into the Godot Editor.
3.  **Run:** Press F5 to start the OGS Launcher.
4.  **Create, Clone, or Add a Project:** Use **New Project** to scaffold an OGS project under your configured Primary Projects Folder (defaults to `~/OGS_Projects` or `%USERPROFILE%\OGS_Projects`, configurable in Settings), **Add Remote Project** to clone an OGS project directly from a remote Git repository with pre-checkout `stack.json` verification and folder collision resolution, or **Add Local Project** to register an existing project that has `stack.json` (auto-generating `ogs_config.json` if missing). In the Project Library, filter projects instantly by name, path, or tool via the search bar, explore empty-state onboarding guidance when no projects are tracked, or single-click to select a project and enable action buttons (Open Project, Remove Project, Seal for Delivery); double-click or clicking Open Project navigates to Project Details.
5.  **Manage Project Tools:** In the **Project Details** tab under the **Stack Toolchain** header, inspect installed and missing tools with crisp tool icons, explicit status labels (`✓ Installed`, `⚠️ Missing (Available in Tools)`, `❌ Unavailable in Repository`), and informative status tooltips. Use **Add Tool** / **Remove Tool** on the Projects page to update the project `stack.json`, then use the Tools page to download missing tool versions. The Tools page dynamically hides empty categories and provides an empty-state view with direct download navigation when no tools are installed.
6.  **Project Explorer & Tool Launching:** Browse launchable files (`.blend`, `.xcf`, `.kra`, `.aup3`, `project.godot`), stack-aware VSCodium text and script files, and tool directories in the resizable split Project Details view, double-click files to launch tools directly, or select pinned tools to launch at the project root with contextual action buttons.
7.  **Configure Project Offline Policy:** In the **Project Details** tab under **Project Offline Policy**, configure per-project network blocking (**Offline mode**) or strict local air-gap isolation (**Force offline**) with in-context helper descriptions. Policies persist directly to the project's `ogs_config.json`.

---

## 🤝 Contributing
We are building the standard for open, portable, and sovereign game development. 
Whether you are an indie dev fixing a UI bug or a systems engineer hardening the build pipeline, we want your help.

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---
**Open Game Stack** | *Owned by the Community. Sustained by the Code.*
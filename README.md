# Open Game Stack (OGS)

![Status](https://img.shields.io/badge/Status-Alpha-orange)
![Engine](https://img.shields.io/badge/Godot-4.7.2-blue)
![License](https://img.shields.io/badge/License-MIT-green)
[![Download Alpha](https://img.shields.io/badge/Download-v0.1.4--alpha-brightgreen)](https://github.com/OpenGameStack-Launcher/ogs-launcher/releases/tag/v0.1.4-alpha)

> **The "Studio-in-a-Box" for Sovereign Game Development.**

## 🎮 What is Open Game Stack?
Open Game Stack (OGS) is a **portable, pre-configured development environment** that bundles the best open-source tools into a single, version-controlled workflow.

Instead of installing Godot, Blender, Krita, and Audacity separately—and hoping their versions match your team's—OGS gives you a **"Frozen Stack."** 

### One Download. Zero Install.
* **The Engine:** Godot 4.7.2 (Stable / Hardened) — the version the Launcher itself is built with; the Tool Catalog also offers Godot 4.3 for projects that pin it
* **The Pipeline:** Blender, Krita, Audacity, GIMP
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

---

## 📂 Documentation
* **[Technical Design Document](docs/Design_Doc.md):** Deep dive into the "Frozen Stack" architecture, directory structure, and `stack.json` schema.
* **[Alpha Packaging Guide](docs/ALPHA_PACKAGING.md):** Build a Windows alpha ZIP package for distribution.
* **[Testing Guide](docs/TESTING.md):** How to run the automated test suite and what each test covers.
* **[Manual Testing Guide](docs/MANUAL_TESTING.md):** Step-by-step user-facing test scenarios for both editor and installed-build modes.
* **[Sample Projects](samples/README.txt):** Quick launcher test inputs for both development/linked mode and sealed-style mode.

## ⬇️ Download

A pre-built Windows binary is available for testing:

**[Download OGS Launcher v0.1.4-alpha (Windows x64)](https://github.com/OpenGameStack-Launcher/ogs-launcher/releases/tag/v0.1.4-alpha)**

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
4.  **Create or Add a Project:** Use **New Project** to scaffold an OGS project under your user home directory (e.g., `~/OGS_Projects`), or **Add Project** to register an existing project that already has `stack.json` and `ogs_config.json`.
5.  **Manage Project Tools:** Use **Add Tool** / **Remove Tool** on the Projects page to update the project `stack.json`, then use the Tools page to download missing tool versions.

---

## 🤝 Contributing
We are building the standard for open, portable, and sovereign game development. 
Whether you are an indie dev fixing a UI bug or a systems engineer hardening the build pipeline, we want your help.

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---
**Open Game Stack** | *Owned by the Community. Sustained by the Code.*
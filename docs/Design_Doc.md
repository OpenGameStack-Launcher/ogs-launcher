# OGS-Launcher: Technical Design Document

## 1. Executive Summary
The **Open Game Stack (OGS) Launcher** is a standalone application designed to bridge the gap between rapid commercial development and secure government sustainment. Unlike commercial launchers (Epic, Unity Hub), OGS operates on a **"Hub & Spoke"** architecture: it serves as a **Central Library Manager** during development (saving disk space and bandwidth) but enables the creation of **"Sealed Artifacts"**—self-contained, air-gapped simulations—for delivery. Its primary mandate is to prioritize project sovereignty over ecosystem connectivity.

---

## 1.5. Terminology & Architecture
To avoid confusion, the OGS ecosystem operates on a three-tier architecture:

### 1.5.1 Tool Catalog (Remote)
*   **What:** The [ogs-frozen-stacks](https://github.com/OpenGameStack-Launcher/ogs-frozen-stacks) GitHub repository.
*   **Contains:** A `repository.json` manifest listing available tool versions with download URLs, SHA-256 hashes, and metadata.
*   **Purpose:** Acts as the **authoritative source** for tool discovery. The Launcher fetches this manifest to show users what tools are available for download.
*   **Analogy:** Like a package registry (npm, PyPI) but for pre-validated simulation tools.

### 1.5.2 Central Library (Local)
*   **What:** A machine-wide tool storage directory managed by the Launcher.
*   **Location:** `%LOCALAPPDATA%/OGS/Library` (Windows) or `~/.config/ogs-launcher/library` (Unix).
*   **Contains:** Extracted tool binaries organized by `[tool_id]/[version]/` (e.g., `Library/godot/4.7.2/`).
*   **Purpose:** Shared storage for tool installations. Multiple projects can reference the same Godot 4.7.2 installation without duplicating gigabytes of binaries.
*   **Analogy:** Like `~/.nvm` (Node Version Manager) or Unity Hub's installation directory.

### 1.5.3 Frozen Stack (Per-Project)
*   **What:** A **version-pinned toolchain specification** defined in each project's `stack.json`.
*   **Contains:** Exact tool IDs and versions required to build/run that specific project (e.g., `"godot": "4.7.2"`, `"blender": "4.5.7"`).
*   **Purpose:** Guarantees reproducibility. A project's stack is "frozen" in time—tools never auto-update unless the developer explicitly modifies `stack.json`.
*   **Two Forms:**
    *   **Linked (Development):** `stack.json` references tools in the Central Library. The `./tools/` folder is empty.
    *   **Sealed (Delivery):** `stack.json` + embedded binaries in `./tools/`. Fully self-contained for air-gapped deployment.
*   **Analogy:** Like `package-lock.json` (npm) or `Pipfile.lock` (Python) but for simulation toolchains.

### 1.5.4 Mirror (Optional Offline Distribution)
*   **What:** A portable directory containing tool archives (`.zip` files) and a `repository.json` manifest.
*   **Location:** User-configurable local path (e.g., USB drive, network share).
*   **Purpose:** Enables tool installation in disconnected environments. Instead of downloading from GitHub, the Launcher can hydrate the Central Library from a local mirror.
*   **Analogy:** Like an offline Debian repository mirror or a vendored `node_modules` folder.

**Key Distinction:** The **ogs-frozen-stacks repository** is the **Tool Catalog** (what's available), while a project's **Frozen Stack** is a **version-locked subset** of those tools (what this project uses).

---

## 2. Core Philosophy: The Two States of a Simulation
To support both modern CI/CD workflows and long-term archiving, OGS defines two distinct states for a simulation project:

### 2.1 State 1: The "Linked" Project (Development)
*   **Context:** Connected Developer Workstation.
*   **Structure:** A lightweight root folder containing a `stack.json` manifest and the source assets.
*   **Binaries:** The project does *not* contain heavy tool binaries. Instead, it "links" to a **Central Tool Library** managed by the Launcher (located in `%LOCALAPPDATA%/OGS/Library` on Windows, or `~/.config/ogs-launcher/library` on Unix).
*   **Efficiency:** Multiple projects using "Godot 4.7.2" share the same single installation, mimicking the efficiency of Unity Hub or NVM.
*   **Testing Note:** For automated testing, this path can be overridden via the `OGS_LIBRARY_ROOT` environment variable to isolate tests from production data. See [TESTING.md](TESTING.md#test-library-isolation).

### 2.2 State 2: The "Sealed" Artifact (Delivery)
*   **Context:** Air-Gapped / Sovereign Sustainment.
*   **Structure:** A heavy, portable directory where the specific tool binaries have been physically **embedded** into the project structure.
*   **Sovereignty:** The artifact has zero external dependencies. It can run directly from optical media or a read-only network share in 2040 without installation.

### 2.3 The Project Wrapper
Every OGS project enforces a specific directory hierarchy to ensure "Seal" compatibility:
```text
My_Simulation_Project/
├── stack.json          # The Environment Manifest (Managed by Launcher)
├── .gitignore          # Excludes /tools/ and temporary builds
├── tools/              # (Empty in State 1; Populated in State 2)
└── project_source/     # The actual Godot Project & Assets
    ├── project.godot
    └── ...
```

### 2.4 Project Discovery & Workspace Management
The launcher manages projects through a local project registry (`ogs_projects_index.json`):
*   **Primary Projects Folder:** Scaffolding new projects creates project directories inside a configurable Primary Projects Folder. By default, this resolves to `%USERPROFILE%/OGS_Projects` on Windows or `$HOME/OGS_Projects` on Unix. Users can customize this location on the Settings page or reset it back to default at any time. Settings are persisted in `ogs_launcher_settings.json`.
*   **Add Local Project:** Adding an existing project folder requires only `stack.json`. If `ogs_config.json` is missing (as when cloning repositories that omit local environment configuration), the launcher automatically creates a default `ogs_config.json` with standard offline policies (`offline_mode: false`, `force_offline: false`).

### 2.5 Remote Project Git Cloner Service
To enable seamless collaboration and distribution of frozen stacks across development teams without compromising air-gap safety, the launcher includes an asynchronous headless cloner service (`RemoteProjectCloner`):
*   **Zero Dependency PortableGit Discovery:** Locates PortableGit within the Central Library (`cmd/git.exe` on Windows, `bin/git` on Unix/macOS) via `LibraryManager`, selecting the highest installed semantic version without requiring system-level Git installations.
*   **Air-Gap and Security Gating:** Verifies `OfflineEnforcer.is_offline()` before initiating any network operation; immediately rejects clone requests when offline mode is active.
*   **Remote URL Security Validation:** Validates URLs against argument injection (rejecting leading dashes or hyphens), disallowed protocols (`file://`, `ext::`), local filesystem paths, traversal sequences, and shell metacharacters, while supporting `https://`, `http://` (for local LAN mirrors), `ssh://`, and SCP-style syntax (`git@host:repo.git`).
*   **Two-Phase Manifest Verification:**
    1.  *Phase A (Blobless Pre-Checkout):* Executes `git clone --filter=blob:none --no-checkout` (with fallback to `--no-checkout`) and queries `git show HEAD:stack.json` to validate the root manifest before checking out heavy game assets. If the manifest is missing or invalid, the partial clone is immediately purged.
    2.  *Phase B (Checkout & Auto-Config):* Populates the working tree with `git checkout --progress HEAD` and automatically generates a default `ogs_config.json` if missing.
*   **Defensive Process and Path Management:** Hardens all Git executions with `-c protocol.ext.allow=never -c protocol.file.allow=never -c core.symlinks=false -c core.fsmonitor=false`. Streams progress via non-blocking pipes, supports thread-safe cancellation killing child PIDs, and bounds all directory deletions strictly within destination roots via `PathUtils.is_path_under_root`.

### 2.6 Remote Project UI & Cloning Workflow (`RemoteProjectDialogController`)
The user-facing remote project clone workflow on the Projects page is managed by `RemoteProjectDialogController`:
*   **Three-Button Projects Toolbar:** Integrates "Add Remote Project" between "Add Local Project" and "New Project" in `ProjectsControls`, configured with equal horizontal expansion (`size_flags_horizontal = 3`) and 16px separation.
*   **Air-Gap UI Enforcement:** Marks `AddRemoteProjectButton` with `metadata/network_ui = true`, automatically disabling the button with tooltip `"Disabled because OGS Launcher is currently in offline mode."` when offline mode is active.
*   **Guided Missing-Git Workflow:** When PortableGit is not installed, clicking "Add Remote Project" opens an exclusive modal dialog prompting the user to install Git, with a "Go to Tools" button that navigates directly to the Tools page.
*   **Exclusive Modal Clone Dialog:** Encapsulates repository URL validation, destination folder pre-filling with the configured Primary Projects Folder, and a "Browse..." directory picker.
*   **Destination Subfolder Collision Handling:** Detects collisions if the repository slug already exists in the destination folder, presenting a collision prompt with suggested incremental folder naming (`slug-1`, `slug-2`).
*   **Async Progress, Cancellation, and Error Recovery:** Observes `RemoteProjectCloner` signals (`phase_changed`, `progress_updated`, `clone_failed`, `clone_completed`), displays real-time progress, supports non-blocking cancellation with process termination, and preserves entered URLs while re-enabling input controls if manifest verification fails.
*   **Automatic Registration and Selection:** On clone completion, registers the project directory into the launcher registry via `ProjectsController.add_project_from_path(cloned_dir)` and auto-selects the project in the Project Library.

### 2.7 Application Shell and Sidebar Navigation Architecture (`LayoutController`)
The primary desktop shell (`main.tscn`) uses an `AppLayout` HBoxContainer dividing the application window into a persistent navigation sidebar (`AppLayout/Sidebar`) and a content area (`AppLayout/Content`):
*   **Dedicated Dark Surface Styling:** The sidebar uses a `PanelContainer` styled with `StyleBoxFlat` featuring a dark background (`Color(0.09, 0.10, 0.13)`), a 1px right border (`Color(0.22, 0.25, 0.30)`) providing clean visual separation without artificial gutter gaps, and 12px horizontal / 16px vertical internal padding.
*   **Brand Header:** Located at the top of the sidebar, integrating the 32x32 OGS logo (`res://Images/logo.png`), a 16px high-contrast title label ("OGS Launcher"), and an `HSeparator` divider.
*   **Active Page Highlight Pattern:** Navigation buttons (`BtnProjects`, `BtnTools`, `BtnSettings`) are managed by `LayoutController`. When a page is active, the corresponding button receives an elevated dark stylebox (`Color(0.18, 0.22, 0.28)`) with a 3px primary blue accent left border (`Color(0.35, 0.68, 0.95)`), 4px corner radiuses, and bright white font styling. Inactive buttons are styled with flat dark backgrounds (`Color(0.12, 0.14, 0.18)`), 0px left borders, and muted typography (`Color(0.70, 0.75, 0.82)`).
*   **Sidebar Footer:** Below navigation buttons, an expanding vertical spacer (`SidebarSpacer`) anchors a persistent footer container (`SidebarFooter`) displaying an `HSeparator`, a global connectivity indicator (`SidebarStatusLabel` showing "● Online" in green or "● Offline" in amber synchronized with `OfflineEnforcer` and `ToolsController`), and the launcher version label (`SidebarVersionLabel` showing "v0.1.0" derived from `ProjectSettings` `application/config/version`).

### 2.8 Semantic Button Theming and CheckButton Control Styling
To provide clear visual hierarchy and guard against accidental destructive actions, the application theme in `main.gd` registers semantic `Button` theme type variations and dedicated `CheckButton` styling on `global_theme`:
*   **PrimaryButton (Call to Action):** Used for primary workflows and principal actions (`New Project`, `Launch Selected Tool`, `Seal for Delivery`, and dynamic tool `Download` buttons). Styled with a vibrant brand-blue background (`Color(0.20, 0.48, 0.78)` normal, `Color(0.26, 0.56, 0.88)` hover, `Color(0.15, 0.38, 0.65)` pressed, `Color(0.20, 0.30, 0.40, 0.5)` disabled) and a high-contrast cyan focus ring (`Color(0.45, 0.80, 1.0, 0.8)`).
*   **SecondaryButton (Utility and Neutral Actions):** Used for auxiliary actions (`Add Local Project`, `Add Remote Project`, `Add Tool`, `Change Version`, `New Folder`, `New File`, `Refresh`, folder `Browse` and `Reset to Default` buttons, `Check for Updates`, and download `Cancel` buttons). Styled with a dark slate surface (`Color(0.18, 0.21, 0.26)`) bounded by a subtle 1px border (`Color(0.30, 0.35, 0.42)` normal, `Color(0.38, 0.45, 0.54)` hover).
*   **DangerButton (Destructive Actions):** Used for permanent deletion actions (`Remove Project`, `Remove Tool`, and installed tool `Remove` buttons). Styled with a dark background (`Color(0.18, 0.14, 0.15)`) bordered by a muted crimson accent (`Color(0.65, 0.22, 0.25)` normal, `Color(0.78, 0.28, 0.32)` hover) and an eye-catching crimson hover fill (`Color(0.65, 0.22, 0.25)`).
*   **CheckButton Toggle Styling:** Overrides the default Button stylebox inheritance on `CheckButton` using `StyleBoxEmpty` with 6px horizontal / 4px vertical margins for normal, pressed, and disabled states, a subtle translucent highlight (`Color(1.0, 1.0, 1.0, 0.04)`) with 4px corner radiuses for hover, and a subtle focus outline. This renders settings switches (`Offline mode`, `Force offline`) as clean, lightweight toggle rows rather than solid rectangular button bars.

### 2.9 Path Normalization and UI Presentation Architecture (`PathUtils`)
When paths are constructed on Windows by combining environment variables (`LOCALAPPDATA`, `USERPROFILE`) containing backslashes (`\`) with Godot engine path utilities (`String.path_join()`) which emit forward slashes (`/`), raw paths contain mixed path separators.
To prevent inconsistent path presentation across desktop platforms, the application routes all user-facing path strings through `PathUtils.format_for_display(path: String) -> String` (`scripts/utils/path_utils.gd`):
*   **Uniform Separator Normalization:** Trims leading/trailing whitespace, converts all Windows backslashes (`\`) to Unix forward slashes (`/`), and collapses redundant and trailing slashes via `String.simplify_path()`.
*   **UI Surface Enforcement:** Applied across the Project Library item labels and item tooltips, Project Explorer title header, New Project creation dialog target path instructions, Settings Primary Projects Folder placeholder text, and Settings project offline status label.
*   **Security Boundary Preservation:** `PathUtils.is_path_under_root(full_path: String, root_dir: String) -> bool` guarantees path containment within designated workspace boundaries, preventing directory traversal and zip-slip attacks during cloning, extraction, and sealing.

### 2.10 Compact Projects Status Bar and Semantic Pill Badges
To replace unstyled full-width console-style text lines and provide instantaneous visual feedback on environment readiness, the Projects page wraps status indicators inside a compact horizontal status bar (`ProjectsStatusBar` `PanelContainer` with an inner `HBoxContainer`) positioned directly between `ProjectsControls` and `ProjectsTabs`:
*   **ProjectsStatusBar Layout:** Styled with a dark elevated panel background (`Color(0.12, 0.14, 0.18, 0.8)`), subtle 1px border (`Color(0.20, 0.24, 0.30, 0.8)`), 6px rounded corners, and 12px horizontal / 6px vertical margins.
*   **Semantic Status Font Modulation (`ProjectsStatusLabel`):** Dynamically modulated in `ProjectsController._update_status()` based on message severity classification (`_classify_status_severity()`):
    *   *Ready / Success:* Green accent (`Color(0.35, 0.85, 0.55)`) when environment is ready or tools are launched.
    *   *Warning / Incomplete:* Amber accent (`Color(0.95, 0.75, 0.25)`) when tools are missing or offline mode blocks downloads.
    *   *Error / Failure:* Danger red accent (`Color(0.95, 0.40, 0.40)`) for manifest parse errors or launch failures.
    *   *Neutral / Idle:* Muted text color (`Color(0.65, 0.70, 0.78)`) for initial waiting and selection prompts.
*   **Offline Mode Pill Badges (`OfflineStatusLabel`):** Rendered as rounded pill badges (`StyleBoxFlat` with 10px corner radius, 10px horizontal padding, 3px vertical padding) in `ProjectsController._update_offline_status()`:
    *   *Online (Disabled):* Subtle dark slate pill (`Color(0.18, 0.22, 0.28, 0.7)`) with slate border (`Color(0.28, 0.35, 0.45, 0.8)`).
    *   *Offline Mode Enabled:* Amber pill (`Color(0.35, 0.25, 0.08, 0.8)`) with vibrant amber border (`Color(0.85, 0.65, 0.20, 0.9)`) and text (`Color(1.0, 0.85, 0.40)`).
    *   *Forced Offline:* High-contrast crimson danger pill (`Color(0.38, 0.12, 0.14, 0.85)`) with bright red border (`Color(0.90, 0.30, 0.32, 0.95)`) and text (`Color(1.0, 0.65, 0.65)`).
    *   *Unknown:* Muted slate pill (`Color(0.16, 0.18, 0.22, 0.6)`) with muted border and text.

### 2.11 Structured Project Cards and Tool Badges (`CustomItemList`)
In the Project Library (Tab 0 of the Projects page), registered projects are rendered using `CustomItemList` as dedicated, structured project cards rather than generic buttons:
*   **Dedicated Card Surfaces:** Each entry is rendered with a dark card background (`Color(0.14, 0.16, 0.20)`), 1px border (`Color(0.22, 0.26, 0.32)`), and 6px rounded corners, cleanly differentiating project items from clickable action buttons (`Add Local Project`, `New Project`, `Remove Project`, `Seal for Delivery`).
*   **Prominent Selection State:** When selected, the active card displays an elevated dark background (`Color(0.18, 0.22, 0.28)`) and a prominent 2px cyan accent border (`Color(0.35, 0.68, 0.95)`), providing clear focus feedback.
*   **Visual Hierarchy and Pill Badges:** Each card organizes project data into a clear hierarchy:
    *   *Title:* 16px high-contrast project title label (`Color(0.95, 0.96, 0.98)`).
    *   *Tool Badges:* Styled rounded pill badges aligned to the right displaying canonical tool names via `ToolCategoryMapper.get_display_name()` (e.g. `Godot 4.7.2`, `GIMP 3.2.4`, `VSCodium 1.143.17232`), with clean overflow pills (e.g. `+1 more`, `+2 more`) when more than two tools are present. If a project has no tools, a subtle `No tools` badge is displayed.
    *   *Path:* 12px secondary path text (`Color(0.65, 0.70, 0.75)`) normalized via `PathUtils.format_for_display()`.
*   **API Backward Compatibility:** `CustomItemList` preserves complete API parity with previous string-based implementations (`add_item()`, `clear()`, `select()`, `item_count`, `set_item_tooltip()`, `set_item_disabled()`, and signals `item_selected` on single-click / `item_activated` on double-click).

### 2.12 Project Library Search Filtering and Empty-State Views
In the Project Library (Tab 0 of the Projects page), users can quickly search and filter registered projects as well as receive actionable empty-state guidance:
*   **Search Filter Bar (`ProjectSearchLineEdit`):** Located at the top of the Project Library container with placeholder text `"Filter projects by name, path, or tool..."` and clear button enabled.
*   **Case-Insensitive Multi-Attribute Filtering:** Projects are filtered across three distinct attributes:
    *   *Stack Name:* Matches project display name (case-insensitive substring).
    *   *Project Path:* Matches file path in both raw format and normalized display format (`PathUtils.format_for_display()`).
    *   *Configured Tools:* Matches tool IDs, canonical display names (e.g. `GIMP`, `Godot`), tool versions, and combined tool-version queries.
*   **Filtered Index Mapping:** `ProjectsController` maintains `_filtered_indices: Array[int]` to map UI card positions back to original `registry_manager.tracked_projects` indices, ensuring selection, tab renaming, and double-click activation remain accurate when filtered.
*   **Guided Empty-State View (`EmptyLibraryState`):** Centered view providing contextual feedback and action triggers:
    *   *Zero Projects Tracked:* When the library contains no registered projects, displays `"No Projects Tracked"` along with onboarding action buttons (`New Project`, `Add Local Project`, `Add Remote Project` respecting offline mode enforcement).
    *   *Zero Filter Matches:* When projects are tracked but the active search query yields no matches, displays `"No Projects Match Filter"` and provides a `"Clear Filter"` button that clears the search bar and restores all projects.

### 2.13 Resizable Split Layout and Contextual Launch Button (Project Details)
In the Project Details tab (Tab 1 of the Projects page), the interface adapts dynamically to user focus and provides proportional layout adjustments:
*   **Draggable Vertical Splitter (`VSplitContainer`):** Wraps the Toolchain Section (`ToolchainHeaderLabel`, `ProjectToolsList`, `ToolActionRow`) and the Explorer Section (`ExplorerToolbar`, `ProjectExplorerTree`) within a draggable `VSplitContainer` with `split_offset = 120`. Both sections enforce minimum dimensions (`ToolchainSection` custom minimum height 120px; `ExplorerSection` custom minimum height 140px) to prevent controls from collapsing.
*   **Ellipsis Path Truncation (`ExplorerLabel`):** The Project Explorer header label configures `clip_text = true` and `text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS`, preventing long filesystem paths from pushing the toolbar action buttons ("New Folder", "New File") off-screen. Full paths remain accessible via hover tooltip (`lbl_tools_for_project.tooltip_text`).
*   **Contextual Launch Action Button (`LaunchButton`):** Rather than remaining enabled with static text, the launch button provides explicit state-aware messaging and enablement:
    *   *Idle / Prompt State:* When no tool or launchable file is selected, the button is disabled and displays `"Select a Tool to Launch"`.
    *   *Toolchain Selection:* When a tool row is selected in `ProjectToolsList`, the button enables and displays `"Launch <Tool Name> <Version>"` (e.g., `"Launch Godot v4.7.2"` or `"Launch VSCodium v1.85.1"`).
    *   *Explorer Selection:* When a recognized file or direct tool folder is selected in `ProjectExplorerTree`, the button enables and displays `"Open <filename> in <Tool Name>"` (e.g., `"Open main.gd in VSCodium"`).
*   **Clean Deselection Handlers:** Clicking empty space in either `ProjectToolsList` (`empty_clicked`) or `ProjectExplorerTree` (`nothing_selected`) deselects active items and cleanly reverts the launch button to its disabled prompt state.

### 2.14 Per-Project Offline Policy Configuration (Project Details)
Rather than managing project-specific offline toggles inside global launcher settings, per-project offline policies are configured directly in the **Project Details** tab (`PageProjects/ProjectsTabs/Project Details`):
*   **Project Offline Policy Section:** Located beneath the Project Explorer pane, featuring a normalized project path indicator ("Selected: ...") and two dedicated checkbutton toggles with contextual helper descriptions:
    *   *Offline mode (`offline_mode`):* Blocks outbound network activity while the project is active, allowing tool launches from the Central Library or local project stack.
    *   *Force offline (`force_offline`):* Enforces strict air-gap isolation, requiring and launching tools exclusively from the project's sealed local `tools/` directory.
*   **Decoupled State Persistence:** Toggling either policy setting immediately persists changes to the project's local `ogs_config.json`, triggers `OfflineEnforcer.apply_config()`, emits `offline_state_changed` to update status indicators and pill badge styling, and re-validates the project environment.
*   **Global Settings Separation:** The Settings page (`PageSettings`) remains dedicated strictly to machine-wide configurations (Primary Projects Folder, Network update checks, Mirror settings).

### 2.15 Tools Page Card Layout, Scrollbar Margins, and Tab Count Badges (`ToolsPageController`)
On the Tools page (`PageTools` in `main.tscn`), managed by `ToolsPageController` (`scripts/tools/tools_page_controller.gd`), tool card presentation, action geometry, and tab headers are structured for visual polish and operational clarity:
*   **Compact Card Geometry & Centering:** Each `ToolCard` (`PanelContainer`) defines a default minimum height of 68px (`custom_minimum_size = Vector2(0, 68)`), eliminating empty vertical dead space while allowing smooth expansion if an error label becomes visible. The inner `HBoxContainer` enforces a 14px horizontal separation override, and child controls (42x42 tool icon, label vertical container, and action buttons) are vertically centered via `Control.SIZE_SHRINK_CENTER`.
*   **Standardized Button Dimensions:** Action buttons standardize to 115x36 (`custom_minimum_size = Vector2(115, 36)`) across all states ("Download", "Remove", "Installed [check]", and "Cancel"), ensuring uniform button geometry across cards.
*   **Scrollbar Collision Prevention:** Inside `ToolsTabs/Installed` and `ToolsTabs/Download` (`ScrollContainer` nodes), `InstalledContent` and `DownloadContent` are wrapped in `MarginContainer` elements with `margin_right = 14`. This ensures vertical scrollbars have clear operating margins and do not collide with or overlap the right borders of tool card panels.
*   **Dynamic Tab Title Count Badges:** `populate_tools_ui()` calculates the total installed tools count (`installed_count`) and total available catalog tools count (`available_count`), dynamically updating the tab headers via `set_tab_title(0, "Installed (%d)" % installed_count)` and `set_tab_title(1, "Download (%d)" % available_count)` upon page load, tool installation, removal, or catalog refresh.

### 2.16 Dynamic Category Collapse and Installed Empty-State View (`ToolsPageController`)
To prevent visual clutter on the Tools page (`PageTools`), `ToolsPageController` dynamically manages section visibility and empty-state guidance across both `Installed` and `Download` tabs:
*   **Dynamic Category Collapse:** Rather than rendering all five category sections (`Engine`, `2D Tools`, `3D Tools`, `Audio Tools`, `Code Tools`) unconditionally, `_update_category_sections_and_dividers()` inspects each category container and hides any section containing zero tool cards.
*   **Divider Normalization:** Category divider lines (`HSeparator`) are dynamically updated to render strictly between visible category sections. Leading, trailing, and consecutive dividers are suppressed, preventing unsightly stacked lines when multiple consecutive categories contain no tools.
*   **Installed Tab Empty-State View (`InstalledEmptyState`):** When zero tools are installed in the Central Library, collapsing empty category sections leaves the Installed tab empty. An `InstalledEmptyState` container (`VBoxContainer`) is displayed in place of `InstalledContent`:
    *   *Accent Header:* Prominent title (`InstalledEmptyTitle`: `"No Tools Installed Yet"`) styled with global theme accent coloring.
    *   *Descriptive Guidance:* Secondary label (`InstalledEmptyDescription`: `"Downloaded tools are stored in the Central Library for offline use across projects."`) styled with secondary neutral coloring and centered autowrapping.
    *   *Call-to-Action Button:* A `"Browse Available Tools"` button (`PrimaryButton` variation) wired via `_on_browse_available_tools_pressed()` to switch directly to the Download tab (`current_tab = 1`).
    *   *State Transition:* Upon installing a tool or populating tools where `installed_count > 0`, `InstalledEmptyState` is automatically hidden and `InstalledContent` is displayed with only the populated category sections and dividers.

---

## 3. Operational Modes & User Stories

### 3.1 Mode A: Provisioning & Development (NIPR / Commercial)
*   **Target User:** DoD Contractors, Indie Developers.
*   **Context:** Unclassified environment with internet access.
*   **Workflow:**
    1.  **Hydration (Link):** When a user opens a project, the Launcher reads `stack.json`.
        *   *Check:* Is "Godot 4.7.2 (Hardened)" present in the Central Library?
        *   *Action:* If no, download from the OGS Mirror. If yes, launch the project using the central binary.
    2.  **Strict Pinning:** Updates are never automatic. If the user wants to upgrade to "Godot 4.4", they must explicitly click "Upgrade Project Stack" in the Launcher UI, which updates `stack.json`.
    3.  **Source Control:** The developer commits `stack.json` and `project_source/`. The `tools/` folder is ignored via `.gitignore`, keeping the repo lightweight.

### 3.2 Mode B: Sovereign Sustainment (SIPR / Air-Gapped)
*   **Target User:** Government Program Offices, Classified Labs.
*   **Context:** Secure environment receiving the "Sealed" deliverable.
*   **Workflow:**
    1.  **Reception:** The Government receives a "Sealed Artifact" (Zip or HDD).
    2.  **Verification:** The Launcher validates that the tools inside the local `./tools/` directory match the hashes in `stack.json`.
    3.  **Isolation:** The Launcher detects the `force_offline=true` flag in the project config and disables all "Check for Updates" or "Asset Library" features.

---

## 4. The Validated Toolchain (Standard Profile)
The OGS-Launcher manages a "Standard OGS Profile" of tools known to be compliant with the "Hardened" spec. The Tool Catalog (`repository.json`) offers multiple pre-validated versions per tool; a project pins exactly one version of each via its `stack.json`. The OGS Launcher **application itself** is built with Godot 4.7.2.

| Tool | Versions (Catalog) | License | Role |
| :--- | :--- | :--- | :--- |
| **Godot Engine** | 4.3 (Hardened), 4.7.2 (Hardened) | MIT | Simulation Core & Runtime |
| **Blender** | 4.5.7, 5.2 | GPL | 3D Modeling & Animation |
| **Krita** | 5.2.15, 5.3.3 | GPL | 2D Texture & UI Asset Creation |
| **Audacity** | 3.7.7, 3.7.8 | GPL | Audio Processing |
| **GIMP** | 3.2.4 | GPL | 2D Raster Editing |

*Note: The Launcher enforces "White Box" security by only downloading these tools from the official OGS Mirror (local or remote), where they have been pre-validated and hashed. See [FROZEN_STACKS.md](FROZEN_STACKS.md) for the authoritative, up-to-date catalog contents.*

---

## 5. Governance & Configuration
To guarantee "Zero Connectivity," the Launcher actively manages the configuration files of child processes.

### 5.1 Global Flag: `offline_mode=true`
When this flag is active (auto-detected in Mode B):
1.  **UI Modification:** Hides "Asset Library," "Extension Store," and "Update Available" UI elements.
2.  **Socket Lock:** Network requests from the Launcher are blocked at the application logic level.

### 5.2 Tool-Specific Overrides
Upon launching a tool, the Launcher injects configuration overrides to ensure the child process respects the air-gap:
*   **Godot (`editor_settings.tres`):**
    *   `asset_library/use_threads = false`
    *   `network/debug/bandwidth_limiter = 0`
    *   Removes HTTP Proxy settings.
*   **Blender (`userpref.blend` python override):**
    *   Executes `bpy.context.preferences.system.use_online_access = False` on startup.
    *   Disables "Check for Updates" and "Extensions" repositories.

---

## 6. The "Seal for Delivery" Protocol (Export)
This is the critical utility that converts a **State 1 (Linked)** project into a **State 2 (Sealed)** artifact.

**The "Seal" Workflow:**
1.  **Inventory Scan:** The Launcher parses `stack.json` to identify all required tools.
2.  **Binary Embedding:** The Launcher physically copies the specific tool binaries from the **Central Library** into the project's local `./tools/` directory.
3.  **Config Injection (`ogs_config.json`):**
    *   Generates a local config file in the project root.
    *   Sets `"force_offline": true`.
    *   Sets `"sealed_date": "YYYY-MM-DD"`.
4.  **Sanitization:**
    *   Removes contractor-specific user preferences and temporary build caches (`.godot`).
    *   Removes `.gitignore` (or modifies it) so the tools are now seen as part of the directory.
5.  **Packaging:** Zips the entire folder structure into a timestamped artifact (e.g., `Project_Name_Sealed_20251101.zip`).

---

## 7. Source Hardening & Build Specifications
For high-security deployments, the OGS-Launcher is paired with a **"Hardened Build"** of the Godot Engine.

### 7.1 Compilation Flags (SCons)
When compiling the **Hardened Build** of Godot 4.7.2 for Sovereign Mode:
*   `module_upnp_enabled=no` (Disables Universal Plug and Play)
*   `module_webrtc_enabled=no` (Disables WebRTC)
*   `module_websocket_enabled=no` (Disables WebSocket)

### 7.2 Source Code Stripping
*   **HTTP Requests:** The `HTTPRequest` node class is disabled/removed to prevent logic-level internet access.
*   **Asset Library:** The `editor/editor_asset_installer` module is excluded to remove the internal Asset Library tab entirely.
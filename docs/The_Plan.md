# OGS Launcher: Minimum Viable Product & Development Plan

## Vision Alignment
This plan realizes the core vision from `docs/Design_Doc.md`: **"Sovereignty Over Subscription."** The MoSCoW method ensures we deliver the critical path to air-gap functionality and manifest-driven toolchain management without overscoping.

---

## MVP Definition: The "I/ITSEC Showcase" Build
**Target Date:** November 1, 2026 (Ready for Conference)
**Target Platform:** Windows 10/11 (x64)
**Distribution Model:** "Hub" installer (for devs) to "Sealed" artifact (for delivery)

### Primary Goals (Phase 1.5: Showcase Readiness)
1.  **Central Library Manager (Mode A)** — Launcher manages a shared pool of tools in `%LOCALAPPDATA%` to save disk space.
2.  **Project "Hydration"** — Opening a project automatically links it to the correct version in the Library (or triggers a download).
3.  **The "Seal" Protocol (Mode B)** — A working button that physically copies tools from the Library into the project and zips it up.
4.  **Offline Demo Bundle** — A pre-sealed project on a USB stick to guarantee a working demo regardless of conference Wi-Fi.

### Success Criteria
*   User runs `OGS_Setup.exe` to install the Launcher.
*   Launcher detects missing tools in `stack.json` and downloads them to `%LOCALAPPDATA%/OGS/Library/`.
*   User can have 3 projects using "Godot 4.7.2" while only having one copy of Godot on disk.
*   User clicks **"Seal for Delivery,"** and the Launcher produces a standalone `.zip` file containing the project AND the embedded tools.
*   That `.zip` file can be moved to a disconnected PC and run immediately.

### Demo Walkthrough (MVP Completion Gate)
The MVP is not complete until this full sequence works end to end:
1.  On a connected laptop, download and install the Launcher.
2.  Import an existing Godot project and generate `stack.json` (convert to OGS project).
3.  Use the Launcher to hydrate tools into the Central Library.
4.  Click **"Seal for Delivery"** to export a sealed `.zip` with embedded tools and Launcher.
5.  Transfer the `.zip` to an air-gapped PC, unzip, and run the Launcher from inside the sealed folder.
6.  Launch Godot (and the sample project) successfully with no network access.

---

## Phases & Progress

### Phase 1: Foundation (Internal Logic)
**Status:** 100% Complete ✅
*   (See previous logs for Manifest, Config, and Offline Enforcement completion)

---

### Phase 1.5: The Showcase MVP (Windows)
**Status:** **100% Complete** ✅
*Focus: The "Hub" Logic, Library Management, and The Seal.*

#### 📋 Critical Tasks (Must-Have for Showcase)
*   [x] **Central Library Manager (The Hub)** — 100% Complete ✅
    *   *Pathing:* Logic to manage tools in `%LOCALAPPDATA%/OGS/Library/[Tool]/[Version]/`.
    *   *Tool Discovery:* PathResolver queries available tools and versions.
    *   *Library Validation:* LibraryManager validates tools exist and retrieves metadata.
    *   *Extraction:* ToolExtractor unzips archives into library structure (Phase 2: actual unzipping).
    *   *Tests:* Unit tests validating all library operations.
*   [x] **Project Manager & Environment Validation** — 100% Complete ✅
    *   *Discovery:* ProjectsController loads and validates `stack.json`.
    *   *Validation:* ProjectEnvironmentValidator checks tools against library.
    *   *UI Integration:* Environment incomplete → shows "Repair Environment" button.
    *   *Repair Workflow:* LibraryHydrator orchestrates batch downloads (Phase 2: actual HTTP).
    *   *Tests:* Unit + scene tests covering validation and repair flow.
*   [x] **The "Seal for Delivery" Utility (Export)** — 100% Complete ✅
    *   *ProjectSealer Class:* `seal_project(project_path)` implements full workflow.
    *   *Validation:* Validates manifest and checks tool availability.
    *   *Copy Logic:* Recursively copies tool binaries from library → `./tools/`.
    *   *Config Creation:* Writes `ogs_config.json` with `force_offline=true`.
    *   *Archive Packaging:* Creates a real `.zip` artifact using Godot `ZIPPacker`.
    *   *Packaging Logs:* Logs packaging start, file count, and completion/failure events.
    *   *Tests:* Unit tests covering validation, copying, archive contents, and logging.
*   [x] **UI Integration: "Seal for Delivery" Button** - 100% Complete ✅
    *   *Scene Changes:* Added "Seal for Delivery" button to Projects page + SealDialog.
    *   *Wiring:* Connected button to ProjectSealer call in main.gd.
    *   *Progress Feedback:* Indeterminate `SealProgressBar` active during background packaging thread execution.
    *   *Close Button State:* Modal Close button automatically disabled during active background sealing to prevent premature dismissal, and re-enabled upon completion or failure.
    *   *Typography Hierarchy:* Corrected inverted hierarchy in `SealDialog` so `StatusLabel` serves as the primary headline at 18px (with `#F3F4F6` progress, `#22C55E` success, `#EF4444` error semantic colors) and `OutputLabel` renders at 14px with `#9CA3AF` muted styling.
    *   *Canonical Tool Display Naming:* `ToolCategoryMapper.get_display_name()` maps raw tool IDs to clean, capitalized display names (e.g., "• Godot v4.7.2", "• Blender v4.2") in the completion summary.
    *   *Result Display:* Shows seal status, zip path, size, and tools copied in dialog.
    *   *Open Folder:* "Open Sealed Folder" button to navigate to result on success.
    *   *Error Handling:* Clear error messages if project not loaded or seal fails.
*   [x] **Controller Refactoring** — 100% Complete ✅
    *   *LayoutController:* Extracted page navigation logic from main.gd (85 lines).
    *   *SealController:* Extracted seal dialog management from main.gd (120 lines).
    *   *main.gd:* Reduced from 220 → 197 lines (pure orchestration).
    *   *Code Quality:* Fixed all GDScript language server warnings (shadowed globals, unused params, static calls).
    *   *Tests:* Comprehensive coverage with zero warnings.
*   [x] **Mirror Infrastructure (Client)** — 100% Complete ✅
    *   *MirrorRepository:* Loads and validates repository.json manifests
    *   *MirrorPathResolver:* Safe path resolution with security checks
    *   *MirrorHydrator:* Offline tool installation from local archives
    *   *Settings UI:* Mirror root configuration with real-time status indicator
    *   *Onboarding Wizard:* First-run default stack bootstrap
    *   *Tests:* Comprehensive test coverage for all mirror functionality
    *   *Remote Repo Support:* Optional GitHub Releases repository.json support
    *   *Note:* Server infrastructure scale-out is post-MVP backlog
*   [x] **Onboarding Wizard** - 100% Complete ✅
    *   *First Run Detection:* Checks if wizard has been completed and library is empty
    *   *Brand Visuals & Preview Card:* Welcoming dialog header with 48x48 OGS logo and starter stack card showcasing 6 core tools (Godot, Blender, GIMP, Audacity, Krita, VSCodium) with icons and descriptions
    *   *Unified Action Buttons:* Single horizontal footer action row with 130x36 PrimaryButton ("Start") and SecondaryButton ("Skip for Now"), hiding default AcceptDialog OK button
    *   *Default Stack Bootstrap:* Creates library directory structure for default tools (Godot 4.7.2 + Blender 4.2 LTS)
    *   *Skip Option:* Users can skip wizard and configure manually, persisting completion flag
    *   *Completion Flag:* Persists to disk so wizard only shows once
*   [x] **Mirror Root Settings** — 100% Complete ✅
    *   *Settings Page UI:* Mirror root configuration field with Browse and Reset buttons
    *   *Status Indicator:* Real-time badge showing mirror configuration status (gray/green/yellow/red)
    *   *Persistence:* Mirror settings saved to `ogs_launcher_settings.json` and restored on startup
    *   *Dynamic Updates:* Mirror root changes immediately affect repair workflow
    *   *Remote Repo URL:* Optional remote repository.json configuration
*   [x] **Manual Testing Guide** — 100% Complete ✅
    *   *7 Test Scenarios:* Load sample projects, verify UI state, test seal button, configure mirror, test repair, verify status updates, remote repo config
    *   *Mirror Workflow Tests:* Settings configuration, repair with mirror, status badge updates
    *   *Prerequisites & Setup:* Clear instructions for test environment setup
    *   *Results Tracking Table:* Template for recording test outcomes

---

### Phase 2: Offline Mirror Infrastructure
**Status:** 100% Complete ✅ (Mirror Client + Initial Server Done)
*   [x] **Mirror Client Implementation** — 100% Complete ✅
    *   *MirrorRepository:* Loads and validates repository.json manifests
    *   *MirrorPathResolver:* Safe path resolution for Windows/Unix with security checks
    *   *MirrorHydrator:* Offline tool installation from local archives
    *   *RemoteMirrorHydrator:* Remote HTTP/HTTPS mirror hydration with indeterminate progress support for unknown or redirected downloads and end-to-end loopback integration test coverage
    *   *ToolExtractor:* Real ZIP extraction with common-root stripping and path safety
    *   *LibraryHydrationController Integration:* Wired mirror hydration into repair workflow
    *   *Tests:* Comprehensive test coverage (schema validation, path safety, hydration, UI integration)
*   [x] **Mirror Server Infrastructure (Initial)** — GitHub Releases (v1.0)
    *   *Hosting:* GitHub Releases for "White Box" binaries
    *   *Master Manifest:* repository.json for the Tool Catalog (standard profile)
    *   *Repo:* OpenGameStack-Launcher/ogs-frozen-stacks
*   [x] **Hash Verification** — 100% Complete ✅
    *   *Manifest Enforcement:* `sha256` is required for each tool entry in `repository.json`
    *   *Hydration Validation:* Local and remote mirror hydration verify archive SHA-256 before extraction
    *   *Failure Handling:* Hash mismatch blocks installation with explicit status/logging
*   [x] **Allowlist Policy** — 100% Complete ✅
    *   *Config Support:* `ogs_config.json` accepts `allowed_hosts` and `allowed_ports`
    *   *Enforcement Wiring:* `OfflineEnforcer` applies config allowlists to `SocketBlocker`
    *   *Secure Defaults:* Empty allowlist falls back to localhost-only policy

---

### Phase 2.5: UX Refinement - Per-Tool Download Workflow
**Status:** ✅ Complete (Tools + Projects UX complete Mar 4, 2026)
*Focus: Replace batch "Repair Environment" with granular per-tool discovery and download.*

#### 📋 Short-Term Tasks (Current Sprint)
Granular, actionable items for the Tools/Projects page redesign:

**Schema & Data Layer:**
*   [x] Add `category` field to repository.json schema (values: "Engine", "2D", "3D", "Audio") — 100% Complete ✅
*   [x] Update MirrorRepository.validate_data() to accept optional category field — 100% Complete ✅
*   [x] Add hardcoded category fallback in launcher (godot→Engine, blender→3D, krita→2D, audacity→Audio) — 100% Complete ✅
*   [x] Update MIRROR_SCHEMA.md documentation for category field — 100% Complete ✅
*   [x] Add unit tests for category validation and fallback logic — 100% Complete ✅

**Tools Page Redesign (UI):**
*   [x] Create new Tools page scene structure — 100% Complete ✅
    *   [x] "Installed" tab with category grouping (Engine/2D/3D/Audio)
    *   [x] "Download" tab with category grouping + Download buttons
    *   [x] Offline fallback message ("⚠️ Offline Mode: Connect online or visit GitHub to download tools")
*   [x] Build ToolsController class — 100% Complete ✅
    *   [x] Fetch remote repository.json on startup (with offline fallback)
    *   [x] Cross-reference remote tools with library to determine installed vs available
    *   [x] Categorize and sort tools by category + version
    *   [x] Handle individual tool download button clicks
    *   [x] Add "Refresh" button to manually re-fetch repository.json
    *   [x] Connectivity status checking (Online ✓ / Offline ⚠️)
    *   [x] Download tracking and queuing (prevent simultaneous downloads)
    *   [x] Progress bar with download % and install phase indication
*   [x] Wire ToolsController to existing MirrorHydrator/RemoteMirrorHydrator for downloads — 100% Complete ✅
*   [x] Download button disablement during active downloads — 100% Complete ✅
*   [x] Comprehensive unit tests for ToolsController — 240+ tests passing ✅
*   [x] Scene tests for Tools page UI (node structure, status updates, button state) — 257 total tests passing ✅

**Projects Page Updates:**
*   [x] Add visual indicators to project tool list — 100% Complete ✅
    *   [x] ⚠️ Yellow warning triangle: tool not installed but available in repository
    *   [x] ❌ Red X: tool not installed and not available
    *   [x] Tooltip on hover: "Tool not installed. Click to download."
*   [x] Missing tool download navigation: double-clicking or launching a missing tool navigates to Tools page while single-clicking selects to enable Remove Tool and Change Version - 100% Complete ✅
*   [x] Remove "Repair Environment" button from Projects page — 100% Complete ✅ (hidden by default)
*   [x] Remove LibraryHydrationController integration from Projects page — Partial ✅ (wiring still in place for backward compat)
*   [x] Add tests for tool availability indicators — 3 scene tests + 9 total tests passing ✅
*   [x] Unity-Hub-style Project Library workflow - 100% Complete ✅
    *   [x] Persistent project registry (`user://ogs_projects_index.json`)
    *   [x] Add Local Project requires only `stack.json` (auto-generates missing `ogs_config.json` with default offline policy)
    *   [x] Remove Project with confirmation dialog
    *   [x] New Project scaffolding under configurable Primary Projects Folder (defaults to `%USERPROFILE%/OGS_Projects` or `$HOME/OGS_Projects`)
    *   [x] Primary Projects Folder setting in PageSettings with Browse and Reset to Default buttons, persisted in `ogs_launcher_settings.json`
    *   [x] Decoupled project library selection from immediate tab navigation: single-clicking selects entry, enables library actions (Open Project, Remove Project, Seal for Delivery), and updates Tab 1 title without leaving Tab 0; double-clicking or clicking Open Project navigates to Tab 1 (Project Details)
*   [x] Remote Project Clone Workflow and Three-Button Toolbar - 100% Complete ✅
    *   [x] Three-button Projects toolbar (Add Local Project, Add Remote Project, New Project) with equal width and 16px separation
    *   [x] Offline mode enforcement disabling Add Remote Project with descriptive tooltip
    *   [x] Guided missing-Git prompt navigating to Tools page if PortableGit is not installed
    *   [x] Modal dialog with URL input validation, primary folder pre-fill, and Browse folder picker
    *   [x] Bounded dialog sizing (540x280 and 480x160 targets), smart text autowrapping, and MarginContainer padding
    *   [x] Subfolder collision detection with automatic incremental slug suggestions (slug-1, slug-2)
    *   [x] Real-time progress updates, non-blocking cancellation, and URL preservation on manifest failure
    *   [x] Automatic project registration and Project Library selection upon successful clone
*   [x] Project Tool Management controls — 100% Complete ✅
    *   [x] Two-row action layout (Add/Remove/Launch tool + Remove/Seal project)
    *   [x] Add Tool dialog refactored from dropdown to list selection
    *   [x] Add Tool candidate fallback sources (catalog + library + tracked projects)
    *   [x] Remove Tool writes `stack.json` and refreshes UI immediately
*   [x] Project Tools List Selection and Launch - 100% Complete ✅
    *   [x] Pinned tools in stack.json selectable in ProjectToolsList as launch targets
    *   [x] Direct launch at project root without requiring explorer tree file selection
    *   [x] Single-clicking missing tools in ProjectToolsList selects row and enables Remove Tool and Change Version without navigating away
    *   [x] Double-click item activation launches installed tools immediately at project root, or navigates to Tools page if uninstalled
    *   [x] Launch button guides users to download uninstalled tools on Tools page instead of attempting execution
    *   [x] Bidirectional mutual deselection between ProjectToolsList and ProjectExplorerTree
    *   [x] Clean launch state resets on project switching, list population, and launch disablement
*   [x] Project Explorer File Tree and Directory Pruning - 100% Complete ✅
    *   [x] Skip all dot-prefixed directories during traversal (.git, .godot, .worktrees, .github, .vscode)
    *   [x] Preserve recognized direct tool folders (gimp, blender, krita, audacity, godot, game) and their ancestor folders even when empty
    *   [x] Display only launchable files recognized by FileTypeMapper (project.godot, .xcf, .blend, .kra, .aup3)
    *   [x] Prune non-relevant folders containing neither launchable files nor direct tool folders
    *   [x] Root-only display when project contains zero launchable files and zero direct tool folders
*   [x] Project Explorer Tool Icons Display - 100% Complete ✅
    *   [x] Display 20px application icons next to launchable files (project.godot, .xcf, .blend, .kra, .aup3)
    *   [x] Display 20px application icons next to direct tool folders (gimp, blender, krita, audacity, godot, game)
    *   [x] Maintain null icons for root, intermediate container folders (assets, 2D, 3D, Audio), and nested subfolders
    *   [x] Texture caching for tool icons in ProjectExplorer
*   [x] Semantic Button Theme Variations and CheckButton Styling (Issue #127) - 100% Complete ✅
    *   [x] Registered PrimaryButton, SecondaryButton, and DangerButton theme variations on global_theme in main.gd
    *   [x] Replaced solid rectangular CheckButton styling with empty panel styleboxes and subtle hover highlight
    *   [x] Assigned semantic button variations across Projects, Tools, and Settings pages in main.tscn and ToolsPageController
    *   [x] Added comprehensive scene tests in tests/main_scene_tests.gd and tests/tools_page_scene_tests.gd (1555 tests passing)
*   [x] Compact Projects Status Bar and Semantic Pill Badges (Issue #129) - 100% Complete ✅
    *   [x] Wrapped ProjectsStatusLabel and OfflineStatusLabel in a compact ProjectsStatusBar PanelContainer with inner HBoxContainer between ProjectsControls and ProjectsTabs
    *   [x] Added semantic font color modulation in ProjectsController._update_status(): green for ready/success, amber for warnings/missing tools, red for errors/failures, and muted neutral for idle prompts
    *   [x] Added rounded pill badge styling (StyleBoxFlat with 10px corner radius) in ProjectsController._update_offline_status(): neutral for online, amber for offline mode, and high-contrast red for forced offline
    *   [x] Added comprehensive scene tests in tests/main_scene_tests.gd, tests/projects_controller_scene_tests.gd, and tests/projects_page_indicators_tests.gd (1651 tests passing)
*   [x] Structured Project Cards and Tool Badges (Issue #130) - 100% Complete ✅
    *   [x] Refactored CustomItemList entries into dedicated structured project cards with distinct dark card backgrounds (`Color(0.14, 0.16, 0.20)`) and 1px borders (`Color(0.22, 0.26, 0.32)`), distinct from adjacent action buttons
    *   [x] Elevated selected card surface (`Color(0.18, 0.22, 0.28)`) with a prominent 2px cyan accent border (`Color(0.35, 0.68, 0.95)`)
    *   [x] Visual hierarchy: 16px high-contrast title, canonical tool badge pills with overflow (+N more), and normalized secondary path text (`Color(0.65, 0.70, 0.75)`)
    *   [x] Canonical tool naming via `ToolCategoryMapper.get_display_name()` (e.g. Godot 4.7.2, GIMP 3.2.4, VSCodium)
    *   [x] Preserved full API backward compatibility for `add_item(text)`, `item_count`, `select(index)`, tooltips, and click/double-click signals
    *   [x] Added dedicated test suite in tests/custom_item_list_tests.gd and scene tests in tests/projects_controller_scene_tests.gd (1734 tests passing)
*   [x] Project Library Search Filter Bar and Empty-State View (Issue #131) - 100% Complete ✅
    *   [x] Added `ProjectSearchLineEdit` (`LineEdit`) at the top of Project Library with placeholder text `"Filter projects by name, path, or tool..."` and clear button enabled
    *   [x] Case-insensitive multi-attribute filtering across stack name, project directory path (both raw and display formatting), and tool IDs, display names, and versions
    *   [x] Accurate index mapping (`_filtered_indices: Array[int]`) mapping card list indices to `registry_manager.tracked_projects` on selection and double-click activation
    *   [x] Added `EmptyLibraryState` (`CenterContainer`) providing guided quick-actions (New Project, Add Local Project, Add Remote Project with offline enforcement) when zero projects are tracked
    *   [x] Added clear-query trigger (`Clear Filter` button) and contextual messaging (`No Projects Match Filter`) when search filter yields zero matching projects
    *   [x] Automatic search query reset upon project addition so new projects are immediately visible and selected
    *   [x] Added comprehensive scene tests in `tests/projects_controller_scene_tests.gd` and smoke tests in `tests/main_scene_tests.gd` (1789 tests passing)
*   [x] Contextual Launch Button and Resizable Split Layout (Issue #133) - 100% Complete ✅
    *   [x] Divided Project Details into resizable Stack Toolchain and Project Explorer panes via a vertical `VSplitContainer` with minimum dimension constraints
    *   [x] Configured `ExplorerLabel` with ellipsis text overrun truncation (`TextServer.OVERRUN_TRIM_ELLIPSIS`) and clipping (`clip_text = true`) to prevent toolbar distortion on long project directory paths
    *   [x] Implemented contextual enablement and dynamic action labels on `LaunchButton`:
        *   Prompt state: `"Select a Tool to Launch"` (disabled) when no tool or launchable file is selected
        *   Toolchain selection: `"Launch <Tool Name> <Version>"` (enabled) when a tool is selected in `ProjectToolsList`
        *   File explorer selection: `"Open <filename> in <Tool Name>"` (enabled) when a recognized file or folder is selected in `ProjectExplorerTree`
    *   [x] Added empty-area deselection handlers (`empty_clicked` / `nothing_selected`) restoring disabled prompt state
    *   [x] Added comprehensive scene tests in `tests/projects_controller_scene_tests.gd`, `tests/main_scene_tests.gd`, and `tests/projects_page_indicators_tests.gd` (38 test suites passing, 1892 total tests with zero failures)
*   [x] Relocate Project Offline Policy Toggles to Project Details (Issue #134) - 100% Complete ✅
    *   [x] Relocated per-project offline policy toggles (Offline mode and Force offline) from global Settings (PageSettings) directly to Project Details in PageProjects
    *   [x] Equipped both toggles with explicit in-context helper descriptions differentiating network blocking from strict local tools/ air-gap isolation
    *   [x] Refactored SettingsController to focus purely on global settings and transferred project offline policy handling directly to ProjectsController
    *   [x] Dynamic status updates syncing normalized project path and persisting changes to ogs_config.json on disk
    *   [x] Added comprehensive scene tests in `tests/projects_controller_scene_tests.gd`, `tests/main_scene_tests.gd`, and `tests/startup_tests.gd` (1930 tests passing)
*   [x] Tool Card Layout Polish, Scrollbar Margins, and Tab Count Badges (Issue #135) - 100% Complete ✅
    *   [x] Reduced default tool card minimum height from 94px to 68px, eliminating dead bottom space
    *   [x] Configured 14px horizontal separation and vertical centering (`Control.SIZE_SHRINK_CENTER`) across icon, label container, and action buttons
    *   [x] Standardized action button dimensions to 115x36 across states (Download, Remove, Installed check, Cancel)
    *   [x] Added MarginContainer with 14px right margin inside ToolsTabs/Installed and ToolsTabs/Download, preventing vertical scrollbar overlap on card panels
    *   [x] Implemented dynamic tab title count badges (`Installed (X)` and `Download (Y)`) updating on UI population, install, removal, and refresh
    *   [x] Added unit tests in `tests/tools_page_controller_tests.gd` and scene assertions in `tests/tools_page_scene_tests.gd` (1955 tests passing across 38 test suites with zero failures)
*   [x] Hide Empty Tool Category Sections and Add Installed Tab Empty-State View (Issue #136) - 100% Complete ✅
    *   [x] Dynamically collapsed empty tool category sections (Engine, 2D Tools, 3D Tools, Audio Tools, Code Tools) in both Installed and Download tabs when containing zero tool cards
    *   [x] Dynamically suppressed category dividers (HSeparator) to display strictly between visible sections, eliminating leading, trailing, and consecutive dividers
    *   [x] Added InstalledEmptyState container (VBoxContainer) under ToolsTabs/Installed with high-contrast accent title ("No Tools Installed Yet"), descriptive guidance explaining Central Library offline storage, and a "Browse Available Tools" button (PrimaryButton)
    *   [x] Wired "Browse Available Tools" button to switch directly to Download tab (current_tab = 1)
    *   [x] Added unit tests in tests/tools_page_controller_tests.gd and scene tests in tests/tools_page_scene_tests.gd (2010 tests passing across 38 test suites with zero failures)
*   [x] Redesign Global Settings Page with Section Cards and Aligned Form Inputs (Issue #137) - 100% Complete ✅
    *   [x] Grouped global settings into two styled `PanelContainer` section cards (`ProjectsCard` and `MirrorCard`) with `StyleBoxFlat_settings_card`, 6px corner radii, and 16px internal padding
    *   [x] Added 18px cyan accent headers ("Projects Directory", "Mirror & Offline Repository") and 13px muted helper descriptions
    *   [x] Removed unwired dead `CheckUpdatesButton` and orphaned `NetworkLabel`
    *   [x] Enforced uniform minimum width of 195px (`custom_minimum_size = Vector2(195, 0)`) on `ProjectsRootLabel`, `MirrorRootLabel`, and `MirrorRepoLabel` for uniform horizontal alignment of all text inputs
    *   [x] Enabled clear buttons (`clear_button_enabled = true`) across `ProjectsRootPath`, `MirrorRootPath`, and `MirrorRepoPath` LineEdit controls
    *   [x] Updated tests in `tests/main_scene_tests.gd`, `tests/startup_tests.gd`, and registered `settings_controller.gd` in `tests/test_runner.gd` (2027 tests passing across 38 test suites with zero failures)

**Progress Dialog Modularity:**
*   [x] Refactor progress dialog to support:
    *   [x] Single download (current requirement) — 100% Complete ✅
    *   [x] Extensible architecture for future batch/queue operations — 100% Complete ✅  
    *   [x] Reusable component design (can be called from Tools or Projects page) — 100% Complete ✅

**Testing & Documentation:**
*   [x] Update unit tests: remove repair workflow tests, add per-tool download tests — 100% Complete ✅
*   [x] Update scene tests: new Tools page structure and Projects page indicators — 100% Complete ✅
*   [x] Rewrite MANUAL_TESTING.md: replace repair scenario with per-tool download workflow — 100% Complete ✅
*   [x] Update TESTING.md: remove obsolete library_hydration_controller_tests.gd reference — 100% Complete ✅
*   [x] Migration note: document deprecation of batch repair in favor of per-tool downloads — 100% Complete ✅ (see below)

**Migration Notes (Deprecated Features):**
- **"Repair Environment" Button (Deprecated Feb 23, 2026):** The batch repair workflow has been replaced with per-tool downloads from the Tools page. Users now navigate to Tools → Download tab and click individual "Download" buttons for each tool.
- **LibraryHydrationController Class (Removed Feb 23, 2026):** UI controller for batch repair dialog removed from codebase. Functionality replaced by ToolsController for granular downloads.
- **Projects Page Tool Indicators:** Missing tools now show visual indicators (⚠️ yellow for available, ❌ red for unavailable) with click-through navigation to Tools page.
- **Automatic State Sync:** Projects page automatically refreshes when tools are downloaded from Tools page, removing need for manual reload.

---

### Phase 3: Mid-Term Enhancements (March-May 2026)
**Status:** Planned
*Focus: Multi-tool operations, advanced UI, and performance optimization.*

**Multi-Tool Operations:**
*   Multi-select downloads (select multiple tools in Available section, "Download All Selected" button)
*   "Download All for Project" button on Projects page (one-click install all missing tools)
*   Download queue management (queue multiple tools, download sequentially with unified progress)

**Advanced UI:**
*   Collapsible category/tool/version sections (avoid overwhelming UI as repository grows)
*   Version filtering (show only latest, show all, show only versions needed by projects)
*   Tool search and filtering (find tools by name, category, or version)

**Library Management:**
*   Tool uninstall capability (remove unused tools from library to reclaim disk space)
*   Library disk usage analytics (show space used per tool, total library size)
*   Cleanup recommendations (identify unused tools across all projects)

**Performance & Caching:**
*   Cache remote repository.json locally (reduce network calls, faster startup)
*   Lazy-load tool metadata (only fetch details when user expands category)
*   Background refresh (check for repository updates without blocking UI)

---

### Phase 4: Long-Term Vision (Post-Showcase/Backlog)
**Status:** Future
*Focus: Advanced workflows, compliance, and ecosystem expansion.*

*   **Git LFS Integration** — Advanced workflow for Git-based teams to version-control tool binaries
*   **Custom Repository Support** — Allow users to configure additional tool sources beyond GitHub Releases
*   **Tool Update Notifications** — Alert users when newer versions of installed tools are available
*   **Godot Hardened Build** — Source stripping and security hardening for defense simulation environments
*   **RMF Evidence Generation** — Automated compliance reporting for defense/simulation standards
*   **Multi-Platform Support** — Expand beyond Windows to Linux and macOS builds
*   **Plugin System** — Allow community-contributed tool integrations and custom workflows

---

## Progress Tracking
*   **Foundation (Phase 1):** Completed Feb 15, 2026
*   **Showcase MVP (Phase 1.5):** Central Library, Hydration, and Seal for Delivery complete Feb 18, 2026
*   **Mirror Infrastructure (Phase 2):** Mirror client + GitHub Releases complete Feb 20, 2026
*   **Path Field Refactor:** Made optional in stack.json, library-based resolution complete Feb 22, 2026
*   **Tools Page Redesign (Phase 2.5):** Complete Feb 22, 2026
    *   Installed/Download tabs with category grouping
    *   ToolsController with download tracking and progress indication
    *   Remote repository.json fetching with offline fallback
    *   Connectivity status (Online/Offline)
    *   Per-tool download buttons with Cancel support
    *   Progress bar showing download % and install phase
*   **Projects Page UX Expansion (Phase 2.5):** Complete Mar 4, 2026
    *   Project Library persistence, Add/Remove/New Project workflows, and tool-management controls
    *   Add Tool dialog switched to list UI with offline-safe candidate fallback logic
*   **Remote Project Cloner Backend (Phase 2.5):** Complete Oct 31, 2026
    *   Hardened RemoteProjectCloner headless service with two-phase clone verification (Issue #117)
    *   PortableGit CLI discovery in LibraryManager with semantic version comparison
    *   Air-gap gating, URL validation (HTTP/HTTPS/SSH/SCP), anti-injection flags, and safe path bounds
    *   34 test suites passing (1189 total tests) with zero failures
*   **Semantic Button Theming & CheckButton Styling (Phase 2.5):** Complete Oct 31, 2026
    *   Semantic button theme variations (PrimaryButton, SecondaryButton, DangerButton) establishing clear visual hierarchy
    *   CheckButton toggle rows styled with empty panel styleboxes replacing solid rectangular button bars
    *   Scene test coverage in main_scene_tests.gd and tools_page_scene_tests.gd (1555 tests passing across 36 test suites)
*   **Project Details Stack Toolchain Header & Tool Icons (Phase 2.5):** Complete Oct 31, 2026
    *   Added "Stack Toolchain" section header label (ToolchainHeaderLabel) directly above ProjectToolsList matching 18px cyan accent styling (Issue #132)
    *   Uniform 20x20 tool icon rendering with asset mapping from res://Images/tools/ and case-insensitive fallback
    *   Explicit status labels (✓ Installed, ⚠️ Missing (Available in Tools), ❌ Unavailable in Repository) and detailed status tooltips
    *   Comprehensive test coverage in projects_page_indicators_tests.gd and projects_controller_scene_tests.gd (1836 tests passing across 38 test suites)
*   **Test Suite:** 1955 tests passing across 38 test suites (~3-5 sec execution), comprehensive coverage across all components
    *   ToolsController unit tests: download tracking, duplicate suppression, repository validation
    *   Tools page scene tests: node existence, status updates, button state management
    *   ProgressController unit tests: inline tracking, phase transitions, signal emission
*   **Refactoring:** Controller pattern established (Projects, Layout, Seal, Tools, Progress)
*   **Manual Testing:** Split into two tiers: Editor-mode (9 tests) and Installed-Build (7 tests). See [MANUAL_TESTING.md](MANUAL_TESTING.md).
*   **Seal UX Hardening (Mar 13, 2026):** Seal for Delivery async refactor + Open Sealed Folder fix
*   **Alpha Distribution (Mar 13, 2026):** GitHub Release v0.1.0-alpha published, website live with download links

## Summary: Phase 1.5 + Phase 2 + Phase 2.5 Complete

**Tools Page Redesign (Phase 2.5) Completed Feb 22, 2026:**
- Two-tab design: Installed (already-downloaded) and Download (available from catalog)
- Category grouping: Engine, 2D, 3D, Audio with collapsible sections
- ToolsController class for managing tool discovery and downloads
- Remote repository.json fetching on Tools page load with offline fallback
- Connectivity checking: HEAD request to GitHub gives Online/Offline status
- Per-tool download tracking with button state management (Download → Cancel during active download)
- Progress bars showing download % and "Installing…" phase after completion
- All other download buttons disabled while one download is active
- 11 comprehensive tests added (ToolsController unit tests + Tools page scene tests)
- 257 total tests passing with zero failures

**Mirror Infrastructure (Phase 2) Completed Feb 20, 2026:**
- Mirror client implementation (MirrorRepository, MirrorPathResolver, MirrorHydrator)
- Settings UI for mirror root configuration with real-time status indicator
- Remote repository.json support (GitHub Releases)
- Onboarding wizard for first-run default stack bootstrap
- Allowlist policy (config-driven socket filtering for network security)
- Comprehensive test coverage (246 unit + scene tests before Tools page work)
- Full offline-only (air-gap safe) architecture

**Projects Page Updates (Phase 2.5) Completed Mar 4, 2026:**
- Visual indicators: ⚠️ yellow for available tools, ❌ red for unavailable tools
- Click-through navigation from Projects tool list to Tools page with tool focus
- Removed "Repair Environment" button and legacy repair UI
- Automatic Projects/Tools state synchronization (downloads trigger refresh)
- Tool indicators check repository availability before showing status
- Project Library flow: Add Project, New Project scaffold, Remove Project with confirmation
- Tool-management controls: Add Tool list dialog, Remove Tool, Launch Selected Tool
- Add Tool candidate sourcing supports offline/local fallback (catalog + library + tracked projects)
- 327 comprehensive tests passing with zero failures

**Testing & Documentation Cleanup (Phase 2.5) Completed Feb 23, 2026:**
- Removed obsolete LibraryHydrationController class and tests
- Updated MANUAL_TESTING.md with per-tool download workflow (replaced batch repair)
- Updated TESTING.md documentation to remove obsolete references
- Added migration notes to The_Plan.md documenting deprecated features
- Test suite evolved from 259 to 327 passing tests as Projects/Tools coverage expanded

**Path Field Made Optional (Feb 22, 2026):**
- stack.json `path` field is now optional (library-based resolution by default)
- ToolLauncher resolves executables from central library when path omitted
- Backward compatible: existing manifests with paths still work
- Migration notes added to MANIFEST_SCHEMA.md

**Seal UX Hardening (Mar 13, 2026):**
- `SealController.seal_for_delivery()` refactored from synchronous (main-thread blocking) to async `Thread`-based execution
- Live elapsed-time + phase hint status updates every 0.25s while seal runs (no more "Window Not Responding")
- `_on_open_folder_pressed()` path fix: was using `get_basename().get_basename()` which double-stripped extensions; now uses `get_base_dir()` with `DirAccess.dir_exists_absolute()` guard
- Guard against duplicate concurrent seal attempts (`_seal_in_progress` flag)

**Alpha Distribution (Mar 13, 2026):**
- Alpha packaging pipeline created (`scripts/release/build_alpha_package.ps1`): runs tests, exports via Godot CLI, produces ZIP
- Packaging script uses `Start-Process` with redirected stdout/stderr to avoid PowerShell `NativeCommandError` on Godot's expected test stderr
- `artifacts/` added to `.gitignore`
- GitHub CLI (`gh`) used to publish: `gh release create v0.1.0-alpha ... --prerelease`
- **v0.1.0-alpha released**: https://github.com/OpenGameStack-Launcher/ogs-launcher/releases/tag/v0.1.0-alpha
- Website (`OpenGameStack-Launcher.github.io`) updated with alpha download section and direct tag URL links

**Frozen Stacks v3.0 Tool Catalog Expansion and Code Category Integration (Oct 30, 2026):**
- Introduced "Code" category across ToolCategoryMapper, ToolsController, ToolsPageController, and ProjectExplorer
- Added catalog support and transparent tool icons for PortableGit (2.56.0.4) and VSCodium (1.143.17232)
- Added dynamic, defensive category initialization in ToolsController to guard against unlisted categories
- Scaffolding adaptation in ProjectToolManager: skips creating empty assets/Code/* directories for Code tools
- Project-rooted Git Bash launches with `--cd=<project_dir>`
- Workspace-rooted VSCodium launches with `<project_dir>` and target file arguments
- Automatic detection and injection of portable Git (`git.path` and `git.enabled`) into `<project_dir>/.vscode/settings.json` when both tools are present
- Air-gap telemetry suppression: injected `--disable-telemetry` for VSCodium when offline enforcement is active
- Clean display name formatting (`ToolCategoryMapper.get_display_name()`) across UI surfaces (VSCodium, Git, GIMP)
- 31 test suites passing (631 total tests) with zero failures

**Stack-Aware Project Explorer VSCodium Mappings and Double-Click Launch (Oct 31, 2026):**
- Expanded FileTypeMapper with VSCodium supported extensions: gd, cs, gdshader, shader, txt, md, csv, json, yaml, yml, toml
- Implemented explicit metadata file and extension exclusions (stack.json, ogs_config.json, ogs_metadata.json, .import, .uid, .cfg, .tres, .tscn) to keep launcher and engine internals hidden
- Stack awareness in ProjectExplorer: when VSCodium is in project's pinned tools, surfaces text, script, shader, and data files with the VSCodium icon (20px width)
- Preserved clean directory pruning for Godot-only projects: script and text files remain pruned when VSCodium is not in the project's pinned stack
- Added double-click file activation (file_activated signal) in ProjectExplorer to trigger immediate tool launch targeting the activated file
- Enhanced new file creation flow: supports all text extensions, creates empty files on disk, and defaults extensionless files to .txt with VSCodium when VSCodium is in the stack
- 32 test suites passing (916 total tests) with zero failures

**Automated CI Testing, Release Packaging, and GitHub Release Publishing (Oct 31, 2026):**
- Automated CI Workflow (`.github/workflows/ci.yml`): Runs on all pull requests and pushes to `main` on `windows-latest` with Godot 4.7.2, Windows export templates, and rcedit caching, headless editor import, full 33-suite headless test runner execution, and packaging smoke checks.
- Build-First Automated Release Workflow (`.github/workflows/release.yml`): Triggered via `workflow_dispatch` on `main` with strict semantic version validation (`^[0-9]+\.[0-9]+\.[0-9]+$`), executing full test suite and release build, verifying EXE metadata and SHA-256 checksums, pushing git tag `v<version>`, and publishing a standard Latest GitHub Release.
- Parameterized Windows Release Packaging Script (`scripts/release/build_release_package.ps1`): Replaces retired `build_alpha_package.ps1`, supporting `-Version`, `-GodotPath`, `-RcEditPath`, `-SkipTests`, and `-SkipZip`, generating deterministic staging artifacts, ZIP distribution, and companion `.sha256` checksum file.
- Updated `export_presets.cfg`: Default export path transitioned from alpha to `artifacts/release/OGS-Launcher-win64/OGS-Launcher.exe`.
- Retired `docs/ALPHA_PACKAGING.md` and created canonical `docs/RELEASE_PACKAGING.md`.
- Updated `.agents/skills/release-management/SKILL.md` for remote GitHub Actions dispatch, liveness monitoring, and curated release note drafting.
- Added offline test suite `tests/release_packaging_tests.gd` covering export preset invariants, strict semver regex, packaging script contract, logo icon asset, and workflow configurations (33 test suites passing, 969 total tests with zero failures).

**Godot MCP Visual QA Bridge and Agentic UI Testing (Oct 31, 2026):**
- Implemented debug-only `McpInteractionServer` autoload (`autoloads/mcp_interaction_server.gd`) listening on loopback `127.0.0.1:9090` (configurable via `GODOT_MCP_PORT`), inert in release builds and auto-disabled in headless mode.
- Created zero-dependency Python CLI helper (`mcp_client.py`) for scene tree inspection, UI control bounding rect queries, input simulation, and viewport screenshot capture (`screenshot.png`).
- Added autonomous visual QA skill (`.agents/skills/mcp-visual-qa/SKILL.md`) and updated agent workflows across issues, PR review, and code review.
- Added startup test suite coverage in `tests/startup_tests.gd` (33 test suites passing, 975 total tests with zero failures).

**Remote Project Cloner Backend and PortableGit Resolver (Oct 31, 2026):**
- Headless `RemoteProjectCloner` service (`scripts/projects/remote_project_cloner.gd`) managing asynchronous Git cloning and validation.
- PortableGit executable resolution in `LibraryManager` (`resolve_git_executable`): locates `cmd/git.exe` on Windows and `bin/git` on Unix/macOS, selecting the highest installed version.
- Strict URL validation rejecting empty strings, argument injection (`-` prefix), disallowed protocols (`file://`, `ext::`), directory traversal, and shell metacharacters while supporting `https://`, `http://` (local LAN mirrors), `ssh://`, and SCP-style syntax (`git@host:repo.git`).
- Two-phase clone verification: blobless clone (`--filter=blob:none --no-checkout`) with fallback to standard `--no-checkout`, followed by `HEAD:stack.json` inspection prior to checking out heavy game assets.
- Hardened Git security flags (`protocol.ext.allow=never`, `protocol.file.allow=never`, `core.symlinks=false`, `core.fsmonitor=false`).
- Threaded execution with non-blocking pipe streaming, live percentage/phase signals, thread-safe cancellation, and safe cleanup bounded by destination root (`PathUtils.is_path_under_root`).
- 34 test suites passing (1189 total tests) with zero failures.

**Shell Content Margins and Typography Scale Standardization (Oct 31, 2026):**
- Added theme margin overrides to `AppLayout/Content` in `main.tscn` (margin_left = 20, margin_right = 20, margin_top = 16, margin_bottom = 16), ensuring page titles, controls, scrollbars, and bottom action buttons do not touch or clip against the outer window borders.
- Standardized typography scale across main views: 24px page titles (Projects, Tools, Settings), 18px section headers with cyan accent styling (`Color(0.45, 0.8, 1.0)`), 16px form controls and body text, and 13px secondary status and metadata labels with muted styling (`Color(0.65, 0.70, 0.78)`).
- Coordinated runtime overrides in `_apply_global_theme()` in `main.gd` while preserving custom tool category colors on `PageTools` (Engine, 2D, 3D, Audio, Code).
- Added comprehensive automated scene tests in `tests/main_scene_tests.gd` covering content margins, typographic scale, and runtime theme persistence.
- 35 test suites passing (1405 total tests) with zero failures.

**Sidebar Redesign with Brand Header, Active Page Highlight, and Connectivity Footer (Oct 31, 2026):**
- Redesigned `AppLayout/Sidebar` in `main.tscn` with dedicated dark surface styling (`Color(0.09, 0.10, 0.13)`), 1px right border (`Color(0.22, 0.25, 0.30)`), and 12px horizontal / 16px vertical padding.
- Added persistent Brand Header featuring 32x32 OGS logo (`res://Images/logo.png`), "OGS Launcher" title (16px), and separator divider.
- Implemented active page highlight styling in `LayoutController`: elevated dark stylebox (`Color(0.18, 0.22, 0.28)`) with 3px primary blue accent left border (`Color(0.35, 0.68, 0.95)`), 4px rounded right corners, and bright font color on the active page button, while reverting inactive buttons to flat normal styling.
- Added expanding vertical spacer and compact Sidebar Footer with global online/offline status indicator synchronized with `OfflineEnforcer` / `ToolsController` and launcher version label backed by `ProjectSettings` (`application/config/version`).
- Added unit tests in `tests/layout_controller_tests.gd` and scene tests in `tests/main_scene_tests.gd` (36 test suites passing, 1473 total tests with zero failures).

**Path Separator Normalization for User-Facing Labels and Placeholders (Oct 31, 2026):**
- Implemented static helper `PathUtils.format_for_display(path: String) -> String` (`scripts/utils/path_utils.gd`) to unify mixed Windows backslashes and Unix forward slashes into consistent forward-slash presentation, strip whitespace, and simplify redundant slashes.
- Applied display normalization across user-facing surfaces: Project Library list items and tooltips, Project Explorer title header, New Project creation dialog target path instructions, Settings Primary Projects Folder placeholder text, and Settings project offline status label.
- Added comprehensive unit test suite in `tests/path_utils_tests.gd` and scene assertions in `tests/projects_controller_scene_tests.gd` and `tests/main_scene_tests.gd` (37 test suites passing, 1591 total tests with zero failures).

**Project Details Resizable Split Layout and Contextual Tool Launch (Oct 31, 2026):**
- Converted Project Details tab into a resizable vertical split layout (`VSplitContainer` with `split_offset = 120`), dividing `ToolchainSection` (minimum height 120px) and `ExplorerSection` (minimum height 140px).
- Enabled ellipsis text overrun trimming (`TextServer.OVERRUN_TRIM_ELLIPSIS`) and clipping on `ExplorerLabel` to maintain clean toolbar proportions on deep file paths.
- Replaced static launch button behavior with contextual enablement and dynamic action labels:
  - `"Select a Tool to Launch"` (disabled) when no tool or launchable file is selected.
  - `"Launch <Tool Name> <Version>"` (enabled) upon tool selection in `ProjectToolsList`.
  - `"Open <filename> in <Tool Name>"` (enabled) upon launchable file/folder selection in `ProjectExplorerTree`.
- Added empty-space deselection listeners on both list and tree controls to cleanly revert launch state to prompt mode.
- Added comprehensive scene tests in `tests/projects_controller_scene_tests.gd` asserting split container hierarchy, minimum constraints, ellipsis properties, and contextual label transitions (38 test suites passing, 1892 total tests with zero failures).

**Tools Page Tool Card Polish, Scrollbar Margins, and Tab Count Badges (Oct 31, 2026):**
- Reduced default tool card custom minimum height from 94px to 68px in `ToolsPageController._create_tool_card()`, maintaining compact rows while allowing natural expansion for error messages.
- Added 14px horizontal separation override to card HBoxContainer and configured vertical centering (`Control.SIZE_SHRINK_CENTER`) on tool icons, label vertical containers, and action buttons.
- Standardized action button dimensions to 115x36 across Download, Remove, Installed check, and Cancel button states.
- Wrapped InstalledContent and DownloadContent inside MarginContainers with 14px right margins in `main.tscn`, providing clean clearance that prevents vertical scrollbar overlap.
- Dynamically formatted ToolsTabs titles with count badges (`Installed (X)` and `Download (Y)`) calculated in `populate_tools_ui()` and refreshed on installation, removal, or catalog updates.
- Added badge formatting unit tests in `tests/tools_page_controller_tests.gd` and layout/margin assertions in `tests/tools_page_scene_tests.gd` (38 test suites passing, 1955 total tests with zero failures).

**Settings Page Card Layout, Form Input Alignment, and Dead Control Clean Up (Oct 31, 2026):**
- Restructured `PageSettings` into two clear `PanelContainer` section cards (`ProjectsCard` and `MirrorCard`) styled with dark panel backgrounds (`Color(0.12, 0.14, 0.18, 0.8)`), subtle 1px border (`Color(0.2, 0.24, 0.3, 0.8)`), 6px corner radii, and 16px internal padding.
- Added 18px cyan accent headers ("Projects Directory" and "Mirror & Offline Repository") with 13px muted helper text providing contextual guidance for project paths and mirror/offline repository usage.
- Removed unwired dead `CheckUpdatesButton` and orphaned `NetworkLabel`.
- Set `custom_minimum_size = Vector2(195, 0)` across form labels (`ProjectsRootLabel`, `MirrorRootLabel`, and `MirrorRepoLabel`), aligning all input text boxes on the same horizontal axis.
- Enabled `clear_button_enabled = true` on `ProjectsRootPath`, `MirrorRootPath`, and `MirrorRepoPath` LineEdit controls.
- Added comprehensive assertions in `tests/main_scene_tests.gd` and updated `tests/startup_tests.gd` (38 test suites passing, 2027 total tests with zero failures).

**Compact Confirmation Dialog Sizing and New File Input Validation (Oct 31, 2026):**
- Standardized modal confirmation and creation dialogs (NewProjectDialog, RemoveProjectDialog, RemoveToolDialog, and NewFileDialog) with compact, content-fitted dimensions (420x150px) and 16px horizontal / 12px vertical internal content margins.
- Cleaned up RemoveToolDialog: status label and progress bar default to hidden upon dialog open and reveal only while tool removal is actively underway or upon removal failure.
- Enhanced NewFileDialog: connected input validation disabling the confirm button on empty or whitespace input, and dynamically updated instruction label to preview target subdirectories and inferred file extensions based on active explorer selection or project toolchain.
- Enhanced NewProjectDialog: disabled confirm button on empty input and added empty-input guard in confirmation handler.
- Added automated scene test coverage in `tests/projects_controller_scene_tests.gd` and `tests/tools_page_scene_tests.gd` (38 test suites passing, 2076 total tests with zero failures).

**Add Tool Dialog Tool Icons, Installation Status Tags, and Balanced Button Sizing (Oct 31, 2026):**
- Enhanced `AddToolDialog` (`ToolOptionList`) in `ProjectToolManager` (`scripts/projects/project_tool_manager.gd`) and `main.tscn` with uniform 20x20 toolchain icons (`Audacity.png`, `Blender.png`, `GIMP.png`, `Git.png`, `Godot.png`, `Krita.png`, `VSCodium.png`) attached to candidate tool versions.
- Added library installation status tags (`✓ Installed` vs `⬇ Available for Download`) checked against Central Library presence via `LibraryManager.tool_exists()`, accompanied by descriptive tooltips.
- Implemented graceful fallback for missing icons or unrecognized tool IDs with null icon and clean text-only rendering.
- Replaced oversized confirmation button minimum width (`Vector2(350, 40)`) with balanced button proportions: `Vector2(180, 36)` for OK/confirmation action button and `Vector2(100, 36)` for Cancel button across both Add Tool and Change Version flows.
- Added comprehensive scene test coverage in `tests/projects_controller_scene_tests.gd` covering icon loading, badge formatting, tooltips, unknown tool fallback, selection/activation handler compatibility, and button sizing (38 test suites passing, 2079 total tests with zero failures).

**Next: Mid-Term Enhancements (Phase 3 - March-May 2026)**
- Multi-select downloads and download queue management
- Collapsible UI sections for scalability
- Tool uninstall and library cleanup capabilities
- Performance optimizations and caching

**Post-Showcase: Long-Term Vision (Phase 4)**
- Git LFS integration for team workflows
- Custom repository support beyond GitHub Releases
- Tool update notifications and version management
- Godot hardened build with source stripping
- RMF evidence generation for defense simulation compliance
- Multi-platform support (Linux, macOS)

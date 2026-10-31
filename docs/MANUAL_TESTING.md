# Manual Testing Guide

## Overview

This guide documents comprehensive manual testing of the OGS Launcher across two deployment scenarios:
1. **Editor-Mode Testing** — Testing within the Godot editor (main.tscn) for rapid feedback
2. **Installed-Build Testing** — Testing an exported OGS Launcher binary to verify production packaging

These tests verify user-facing functionality that complements the automated test suite and uncover issues that only occur in real execution environments.

## Test Philosophy

- **Editor Mode:** Rapid iteration, quick hypothesis testing, component isolation
- **Installed Mode:** Real-world usage patterns, packaging validation, user experience verification
- **Progressive Disclosure:** Each test builds on previous findings; report blockers immediately before proceeding to the next test

## Sample Projects

Two sample projects are provided in `samples/` for testing:

| Sample | Purpose | Config | Structure |
|--------|---------|--------|-----------|
| **sample_project** | Development/linked-mode testing | force_offline=false | Tools expected in library (missing state) |
| **sample_project_sealed** | Sealed/air-gapped project testing | force_offline=true | Tools physically embedded in project |

Both samples include a `stack.json` manifest; see each sample’s `stack.json` for the exact pinned tool versions used in that scenario.

---

# PART A: EDITOR-MODE TESTING

## Prerequisites (Editor Mode)

- OGS Launcher running in Godot editor (F5 or Run Scene on main.tscn)
- Two sample projects available in `samples/` directory
- Output console visible for error messages
- Fresh state: clean library directory for consistent results

### Achieving Fresh State (Before Starting Tests)

To ensure a clean slate for testing, delete all persistent launcher data:

**IMPORTANT:** Back up any existing projects, tools, or settings you want to keep before deleting data. Fresh-state cleanup is destructive and cannot be undone.

**NOTE ON AUTOMATED TESTS:** The automated test suite uses a completely isolated test library (`%LOCALAPPDATA%\OGS_TEST\Library`) and does not affect your production data at `%LOCALAPPDATA%\OGS`. You can safely run automated tests at any time without impacting manual testing data. See [TESTING.md](TESTING.md#test-library-isolation) for details.

**Option A: Using PowerShell (Recommended)**
```powershell
# Remove all OGS launcher data
Remove-Item -Path "$env:LOCALAPPDATA\OGS" -Recurse -Force -ErrorAction SilentlyContinue

# Verify deletion
if (-not (Test-Path "$env:LOCALAPPDATA\OGS")) {
    Write-Host "✓ Fresh state achieved: OGS directory removed"
} else {
    Write-Host "✗ Failed to remove OGS directory"
}
```

**Option B: Using File Explorer (Manual)**
1. Open File Explorer
2. Press Ctrl+L and paste: `%LOCALAPPDATA%\OGS`
3. If the `OGS` folder exists, delete it entirely
4. Close File Explorer

**Option C: Inside Godot Editor**
1. In Godot, open the Output panel for logs
2. Use PowerShell or File Explorer to delete `%LOCALAPPDATA%\OGS`
3. Confirm the onboarding wizard appears on next launch

### Verifying Fresh State

After cleanup, verify the fresh state is achieved:

**In PowerShell:**
```powershell
# Confirm directories don't exist
$ogsPath = "$env:LOCALAPPDATA\OGS"
if (Test-Path $ogsPath) {
    Write-Host "OGS directory still exists (not clean)"
} else {
    Write-Host "✓ Clean: No OGS directory"
}
```

**In Godot Editor:**
- Press F5 to start the launcher
- Onboarding wizard **must** appear (indicates first-run detection working)
- If no wizard appears, fresh state was not achieved

**After First Launch:**
```powershell
# Check that launcher created default structure
dir "$env:LOCALAPPDATA\OGS\"
# Should show: Library, logs, ogs_launcher_settings.json, ogs_wizard_complete.txt
```

### Editor Test 1: Launcher Startup & Onboarding

**Objective:** Verify that the launcher starts without errors and displays the onboarding wizard on first run.

**Steps:**
1. Delete `%LOCALAPPDATA%\OGS` (to simulate first run)
2. Press F5 or click Run Scene on main.tscn
3. Observe the launcher window and any dialogs
4. In the onboarding wizard, click **Start**
5. Wait for the wizard to close and the main window to remain open
6. Verify `%LOCALAPPDATA%\OGS` exists and contains `Library` and `ogs_wizard_complete.txt`

**Expected Results:**
- ✅ Launcher window appears without errors
- ✅ Scene tree loads with no "Parse Error" or compilation failures
- ✅ Sidebar panel displays dedicated dark surface styling with a 1px right border separating navigation from page content
- ✅ Brand header displays 32x32 OGS logo and "OGS Launcher" title separated from navigation buttons by an HSeparator
- ✅ Navigation buttons (Projects, Tools, Settings) visible with Projects highlighted as active (elevated background with 3px primary blue accent border)
- ✅ Projects page is default/active
- ✅ Sidebar footer displays global connectivity status indicator ("● Online" / "● Offline") and launcher version label ("v0.1.0")
- ✅ Onboarding wizard appears (welcome dialog with default stack info)
- ✅ Clicking **Start** completes onboarding and closes the dialog
- ✅ `%LOCALAPPDATA%\OGS\Library` exists after onboarding completes
- ✅ `%LOCALAPPDATA%\OGS\ogs_wizard_complete.txt` exists after onboarding completes
- ✅ Output console shows no SCRIPT ERROR messages

**Pass Criteria:**
- Launcher starts cleanly
- UI is responsive and no error dialogs block the main window
- Onboarding wizard appears and completes when **Start** is clicked
- OGS data folder is created with expected files

**If test fails:**
- Check Godot Output panel for parser/script errors
- Verify all required nodes exist in main.tscn
- Confirm ogs_config.json and stack.json schemas in samples are valid

---

### Editor Test 2: Projects Page - Add sample_project (Development)

**Objective:** Verify that adding a development project to the Project Library shows missing tools with visual indicators and click-through navigation.

**Steps:**
1. Close onboarding wizard (if still visible)
2. On Projects page, click **"Add Local Project"**
3. In folder picker, navigate to `samples/sample_project/`
4. Click **"Add Project"** in the picker
5. Observe tools list, visual indicators, button states, and status labels

**Expected Results:**
- ✅ Tools list populates with two entries: "godot v4.7.2" and "blender v4.5.7"
- ✅ Missing tools show **⚠️ yellow warning triangle** indicator (available but not installed)
- ✅ Hovering over missing tool shows tooltip: "Tool not installed. Click to download."
- ✅ "Seal for Delivery" button appears but is **disabled** (with reason: missing tools)
- ✅ Status label shows: "Manifest loaded. 2 tool(s) missing — visit Tools page to download."
- ✅ "Offline" label shows: "Offline Mode: Disabled" (since force_offline=false in config)
- ✅ No errors in Output console

**Pass Criteria:**
- Project is added to Project Library and selected automatically
- Visual indicators correctly show missing tool status
- Seal button disabled due to missing tools
- Offline status correctly reflects config state

**If test fails:**
- Verify sample_project/stack.json is valid JSON
- Check if sample_project/ogs_config.json exists; if not, confirm defaults apply
- Look for path resolution errors in console
- Verify ToolsController has loaded repository.json successfully

---

### Editor Test 3: Projects Page - Add sample_project_sealed (Sealed/Air-Gapped)

**Objective:** Verify that sealed projects display offline enforcement and expected UI state even with missing tools.

**Steps:**
1. On Projects page, click **"Add Local Project"**
2. In folder picker, navigate to `samples/sample_project_sealed/`
3. Click **"Add Project"** in the picker
4. Observe offline status, tool indicators, and button states

**Expected Results:**
- ✅ Tools list populates with "godot v4.7.2" and "blender v4.5.7"
- ✅ Missing tools show **❌ red X** indicator (unavailable due to offline mode)
- ✅ Hovering over missing tool shows tooltip: "Tool not available in offline mode."
- ✅ "Seal for Delivery" button remains **disabled** (tools missing from library)
- ✅ Status label shows: "Manifest loaded. 2 tool(s) missing — offline mode prevents downloads."
- ✅ "Offline" label shows: **"Offline Mode: Forced (force_offline=true)"** in distinctive color (red text)
- ✅ No online-only features in UI (if any implemented)

**Pass Criteria:**
- Sealed project config properly read and enforced
- Offline status clearly indicates force_offline state
- Tool indicators correctly show unavailable state (red X) in offline mode

---

### Editor Test 3.1: Projects Page — Add Tool / Remove Tool Flow

**Objective:** Verify tool-management controls update `stack.json` reliably using the Add Tool list dialog.

**Steps:**
1. Select a project in Project Library (for example `samples/sample_project`)
2. Click **"Add Tool"**
3. Confirm dialog opens with a selectable list of tool/version entries (not a dropdown)
4. Select one tool and click **"Add Tool"**
5. Verify tools list refreshes immediately and includes the new entry
6. Repeat Add Tool for one more entry
7. Select one tool in project tools list, then click **"Remove Tool"**
8. Verify tools list refreshes immediately and removed entry is gone

**Expected Results:**
- ✅ Add Tool dialog opens consistently across repeated opens
- ✅ Add Tool uses a list-style selector and supports single selection
- ✅ Added tools persist to the project manifest and remain after app restart
- ✅ Remove Tool updates the project manifest and UI immediately
- ✅ Status label reflects success/failure states clearly

**Pass Criteria:**
- Add Tool and Remove Tool workflows are stable across multiple operations
- Project tools list and `stack.json` stay in sync after each action

**If test fails:**
- Check sample_project_sealed/ogs_config.json has force_offline=true
- Verify OfflineEnforcer.apply_config() is called during project load
- Confirm offline status label is wired to display force_offline state
- Verify tool indicators check offline state before showing availability

---

### Editor Test 3.2: Projects Page - Project Explorer Folder Pruning and Launchable File Tree

**Objective:** Verify that Project Explorer prunes non-relevant directories and displays only direct tool folders and launchable files.

**Steps:**
1. Select a project in the Project Library (e.g. `samples/sample_project`).
2. Inspect the Project Explorer tree view on the right side of the Projects page.
3. Verify that dot-prefixed directories (e.g. `.git`, `.godot`, `.worktrees`, `.github`, `.vscode`) do not appear in the tree.
4. Verify that non-relevant folders (such as `docs`, `scripts`, or empty custom folders) containing no launchable files are excluded from the tree.
5. Verify that direct tool folders (`gimp`, `blender`, `krita`, `audacity`, `godot`, `game`) and their ancestor directories (e.g. `assets`, `2D`, `3D`, `Audio`) remain visible even when empty.
6. Verify that files recognized by FileTypeMapper (`project.godot`, `.xcf`, `.blend`, `.kra`, `.aup3`) are visible and selectable in the tree.
7. Right-click a folder or file to confirm the context menu ("Open in File Explorer") appears.
8. Click "Open in File Explorer" and verify the target path opens in your desktop file manager.

**Expected Results:**
- [x] Dot-prefixed directories are skipped and never rendered in the tree.
- [x] Non-relevant folders containing only source files (.gd), documentation (.md), or empty directories are pruned.
- [x] Direct tool folders and their ancestors remain visible even when empty.
- [x] Only launchable files recognized by FileTypeMapper appear in the explorer.
- [x] Right-click context menu opens cleanly and launches the file manager at the selected path.

**Pass Criteria:**
- Project Explorer shows a clean, pruned tree without non-relevant folders or dot directories.
- Direct tool folders and launchable files are accessible and selectable.
- Context menu operates properly.

**If test fails:**
- Verify `scripts/projects/project_explorer.gd` filtering methods (`_has_relevant_content`, `_is_launchable_file`).
- Check Godot Output panel for errors during directory traversal.

---

### Editor Test 3.3: Projects Page - Project Explorer Tool Icons Display

**Objective:** Verify that Project Explorer displays 20px tool icons beside launchable files and direct tool folders, while keeping container folders icon-free.

**Steps:**
1. Select a project in the Project Library (e.g. `samples/sample_project`).
2. Inspect the Project Explorer tree view on the right side of the Projects page.
3. Observe direct tool folders (such as `blender`, `gimp`, `krita`, `audacity`, `godot`, or `game`).
4. Observe launchable files (such as `project.godot`, `.blend`, `.xcf`, `.kra`, or `.aup3`).
5. Observe container folders (the root folder, `assets`, `2D`, `3D`, `Audio`, or subfolders inside a tool folder).
6. Verify that launchable files display the corresponding tool icon (`res://Images/tools/`) scaled to a max width of 20 pixels.
7. Verify that direct tool folders display the corresponding tool icon scaled to a max width of 20 pixels.
8. Verify that container folders and subfolders display no application icon (null icon).

**Expected Results:**
- [x] Launchable files display appropriate tool icons (Godot, Blender, Krita, Audacity, GIMP) at 20px width.
- [x] Direct tool folders display appropriate tool icons at 20px width.
- [x] Root project folder, intermediate folders (assets, 2D, 3D, Audio), and nested subfolders display no tool icon.
- [x] Icons are crisp and properly proportioned without disrupting row heights.

**Pass Criteria:**
- Tool icons render beside recognized launchable files and direct tool folders.
- Container folders have no icon.
- Tree layout remains neat and fully usable.

**If test fails:**
- Verify `scripts/projects/project_explorer.gd` icon mapping (`TOOL_ICON_PATHS`), sizing (`ICON_MAX_WIDTH`), and `_get_tool_icon()`.
- Ensure tool icon PNG files in `res://Images/tools/` are present and valid textures.

---

### Editor Test 3.4: Projects Page - Selecting and Removing Missing Tools in Project Details

**Objective:** Verify that single-clicking an uninstalled or missing tool in Project Details selects the row and enables "Remove Tool" and "Change Version" without navigating away from the Projects page, while double-clicking or launching triggers download navigation to the Tools page.

**Steps:**
1. Select a project in Project Library that has at least one missing tool indicated by a warning triangle (e.g. `Blender v4.2 ⚠️`) or red X.
2. Under the Project Details tab, locate the tools list (`ProjectToolsList`).
3. Single-click the missing tool row.
4. Verify that the tool row becomes selected (highlighted) and the active view remains on the Projects page without switching to the Tools page.
5. Verify that both the "Remove Tool" and "Change Version" buttons become enabled.
6. Verify that any previous selection in the Project Explorer tree is cleared (mutual deselection).
7. Click the "Launch Selected Tool" button with the missing tool still selected.
8. Verify that the status label updates to indicate the tool is not installed, and the view navigates to the Tools page to download it.
9. Return to the Projects page, single-click the missing tool row again, then click "Remove Tool".
10. Confirm that the tool is removed from the project manifest and the tools list refreshes immediately.

**Expected Results:**
- [x] Single-clicking a missing tool row selects the item without triggering navigation to the Tools page.
- [x] "Remove Tool" and "Change Version" action buttons are enabled when the missing tool row is selected.
- [x] Mutual deselection clears the Project Explorer selection when a tool row is clicked.
- [x] Clicking "Launch Selected Tool" on a missing tool updates the status message and navigates to the Tools page.
- [x] Double-clicking an uninstalled tool row directly navigates to the Tools page.
- [x] "Remove Tool" successfully removes the selected missing tool from `stack.json`.

**Pass Criteria:**
- Missing tools can be selected, reconfigured, or removed directly from Project Details without unintended view switching.
- Double-clicking or launch actions guide the user cleanly to the Tools page.

**If test fails:**
- Verify `ProjectsController._on_tool_item_clicked()` calls `_on_tool_item_selected()` and does not emit `tool_view_requested`.
- Verify `ProjectsController._update_tool_action_buttons()` checks valid `_selected_tool_index` regardless of installation status.
- Verify `ProjectsController._on_launch_tool_pressed()` checks `_is_tool_installed()` and emits `_emit_tool_view_request()`.

---

### Editor Test 3.5: Projects Page - Decoupled Project Library Selection and Navigation

**Objective:** Verify that single-clicking a project in the Project Library selects the project and enables library action buttons without navigating away from Tab 0 (Project Library), while double-clicking or clicking "Open Project" navigates to Tab 1 (Project Details).

**Steps:**
1. Navigate to the Projects page and ensure at least one project is registered in the Project Library (e.g. `samples/sample_project`).
2. Verify that Tab 0 ("Project Library") is the active tab.
3. Single-click a project entry in the project list.
4. Verify that the project entry is highlighted, the title of Tab 1 updates to the project's stack name, and the active view remains on Tab 0 ("Project Library").
5. Verify that "Open Project", "Remove Project", and "Seal for Delivery" buttons in the action row are enabled.
6. Click the "Open Project" button.
7. Verify that the view navigates to Tab 1 ("Project Details").
8. Switch back to Tab 0 ("Project Library").
9. Double-click the project entry in the project list.
10. Verify that the view navigates directly to Tab 1 ("Project Details").
11. Switch back to Tab 0 ("Project Library"), click "Remove Project", and confirm removal until all projects are removed from the library.
12. Verify that "Open Project", "Remove Project", and "Seal for Delivery" buttons are disabled when the library is empty.

**Expected Results:**
- [x] Single-clicking a project selects it without switching away from Tab 0.
- [x] Tab 1 header updates to reflect the selected project's stack name.
- [x] "Open Project", "Remove Project", and "Seal for Delivery" action buttons are enabled upon project selection.
- [x] Clicking "Open Project" navigates to Tab 1 ("Project Details").
- [x] Double-clicking a project in the list navigates to Tab 1 ("Project Details").
- [x] Action row buttons are disabled when no project is selected or when the library is empty.

**Pass Criteria:**
- Project selection and tab navigation are cleanly decoupled.
- Users can access Remove Project and Seal for Delivery directly from Tab 0 without premature navigation.

**If test fails:**
- Verify `ProjectsController._select_project()` does not alter `projects_tabs.current_tab`.
- Verify `ProjectsController._on_open_project_pressed()` and `_on_project_activated()` call `_open_selected_project_tab()`.
- Verify `_enable_project_action_buttons()` and `_disable_project_action_buttons()` update button states properly.

---

### Editor Test 3.6: Projects Page - Compact Status Bar and Pill Badges

**Objective:** Verify that the Projects page displays a compact horizontal status bar with semantic color modulation and styled pill badges for offline status.

**Steps:**
1. Launch the launcher and navigate to the Projects page.
2. Inspect the region between the project action buttons ("Add Local Project", "Add Remote Project", "New Project") and the Projects tabs.
3. Confirm `ProjectsStatusBar` is rendered as a compact horizontal panel container (`PanelContainer`) with an inner `HBoxContainer`.
4. Note the initial idle/waiting status message ("Status: Waiting for project selection.") and verify it renders in muted neutral text (`Color(0.65, 0.70, 0.78)`).
5. Check the initial offline pill badge: verify it renders as a rounded pill badge with 10px corner radius showing "Offline Mode: Unknown" (or configured state).
6. Add a project with missing tools (e.g. `samples/sample_project` with online config):
   - Verify status message modulates to warning amber (`Color(0.95, 0.75, 0.25)`): "Status: Manifest loaded (2 tool(s) missing - use Tools page to download)."
   - Verify offline status badge updates to a subtle online/disabled pill badge: "Offline Mode: Disabled" with dark slate background and border.
7. Add or select a sealed project (e.g. `samples/sample_project_sealed` with `force_offline=true`):
   - Verify status message displays in warning amber (`Color(0.95, 0.75, 0.25)`): "Status: Manifest loaded (2 tool(s) missing - offline mode prevents downloads)."
   - Verify offline status badge updates to a high-contrast danger red pill badge: "Offline Mode: Forced (force_offline=true)" with dark crimson background, bright red border, and high-contrast text.
8. Navigate to Settings, enable "Offline mode" (with `force_offline=false`), and return to Projects:
   - Verify offline status badge updates to an amber pill badge: "Offline Mode: Enabled (offline_mode=true)" with dark amber background, amber border, and amber text.
9. Select a ready project where all tools are installed in the library (or launch a tool):
   - Verify status message displays with green accent (`Color(0.35, 0.85, 0.55)`): "Status: Environment ready - all tools in library."
10. Trigger an error condition (such as selecting a project missing `stack.json` or a failed launch):
   - Verify status message displays in danger red (`Color(0.95, 0.40, 0.40)`).

**Expected Results:**
- [x] Compact status bar occupies minimal vertical height and prevents visual clutter.
- [x] ProjectsStatusLabel expands horizontally on the left with vertical centering.
- [x] OfflineStatusLabel renders on the right as a rounded pill badge with 10px corner radius and state-specific styling.
- [x] Semantic status colors distinguish Ready (green), Warning (amber), Error (red), and Neutral (muted) clearly.
- [x] Offline pill badges clearly indicate Disabled (neutral/slate), Enabled (amber), and Forced (high-contrast red).

**Pass Criteria:**
- Status bar and badges render cleanly without clipping or text overflow.
- Visual colors and styling accurately communicate environment readiness and offline policy.

**If test fails:**
- Verify `ProjectsStatusBar` panel container and `HBoxContainer` hierarchy in `main.tscn`.
- Check `ProjectsController._classify_status_severity()` keyword matching and color modulation.
- Verify `ProjectsController._update_offline_status()` pill `StyleBoxFlat` creation and color assignment.

---

### Editor Test 4: Settings Page — Mirror Configuration

**Objective:** Verify mirror root can be configured and status indicator updates correctly.

**Steps:**
1. Click "Settings" button in sidebar to navigate to Settings page
2. In "Mirror Settings" section, observe the "Mirror Root:" field
3. Note current status in "Mirror status:" label (should say "Remote repository configured" unless the remote URL was cleared)
4. Click "Reset to Default" button
5. Observe status changes; field should clear or show default path

**Expected Results:**
- ✅ Settings page loads without errors
- ✅ "Mirror Root:" field is visible and editable
- ✅ "Reset to Default" button sets field to default/empty
- ✅ "Mirror status:" label updates to:
  - **"Mirror status: Remote repository configured"** if the default remote URL is present
  - **"Mirror status: Using default location"** if the remote URL is cleared
- ✅ Changes persist if you close and reopen the launcher (check settings later)

**Pass Criteria:**
- Settings page UI is functional
- Mirror configuration controls respond to user input
- Status indicator reflects current mirror state

**If test fails:**
- Verify PageSettings scene exists with MirrorRootContainer nodes
- Check mirror_root_path TextEdit node is properly wired in main.gd
- Confirm _load_mirror_settings() loads defaults correctly

---

### Editor Test 5: Settings Page — Remote Repository URL Configuration

**Objective:** Verify remote repository URL can be set and status shows configuration state.

**Steps:**
1. Stay on Settings page
2. In "Remote Repo URL:" field, paste (or type a test URL):
   ```
   https://raw.githubusercontent.com/OpenGameStack-Launcher/ogs-frozen-stacks/main/repository.json
   ```
3. Observe the "Mirror status:" label

**Expected Results:**
- ✅ "Remote Repo URL:" field accepts text input
- ✅ "Mirror status:" label updates to show: **"Mirror status: Remote repository configured"** (blue or distinct color)
- ✅ URL persists after closing/reopening launcher
- ✅ Clicking **"Reset to Default"** restores the default repository URL

**Pass Criteria:**
- Remote repository field is wired and functional
- Status indicator correctly recognizes remote URL configuration

**If test fails:**
- Verify mirror_repo_path TextEdit exists and is wired in main.gd
- Check _load_mirror_settings() loads repository URL from disk
- Confirm _update_mirror_status() checks for remote URL presence

---

### Editor Test 6: Seal Button State Transitions

**Objective:** Verify that "Seal for Delivery" button correctly transitions between enabled/disabled based on environment readiness.

**Steps:**
1. Load sample_project (development) — should show seal button disabled
2. Observe seal button and its tooltip
3. Load sample_project_sealed — should still show seal button disabled (tools missing from library)
4. Switch back to sample_project
5. Verify seal button is still disabled (no library tools present)

**Expected Results:**
- ✅ Seal button is **disabled** when environment is incomplete (tools missing from library)
- ✅ Seal button tooltip says: **"Download required tools from Tools page first."**
- ✅ Loading different projects updates button state dynamically
- ✅ Seal button would become **enabled** (green) if all tools were somehow present in library (not testable without actual library)

**Pass Criteria:**
- Seal button state properly reflects environment readiness
- Tooltip provides clear guidance to user
- State synchronizes across project switches

**If test fails:**
- Check ProjectsController._update_seal_button_state() logic
- Verify btn_seal_for_delivery.disabled is properly set
- Confirm environment_ready/incomplete signals are emitted correctly

---

### Editor Test 7: Per-Tool Download Workflow — Real Tool Installation

**Objective:** Perform a real tool download by using the Tools page and verify the process completes successfully.

**Prerequisites (IMPORTANT — Check Before Starting):**
1. Verify tool archives are available via **EITHER**:
   - **Local Mirror:** Tool ZIP files exist in `%LOCALAPPDATA%\OGS\Mirror\` with correct structure:
     ```
     %LOCALAPPDATA%\OGS\Mirror\
     ├── godot/4.7.2/godot_4.7.2.zip
     └── blender/4.5.7/blender_4.5.7.zip
     ```
   - **Remote Repository:** Remote URL is configured in Settings and points to a valid `repository.json` with downloadable tool links
   - **Check Settings page:** Mirror status should show "Local mirror ready" OR "Remote repository configured"
2. If neither is available, SKIP to Test 9 (offline enforcement); Test 7 requires actual tool archives

**Steps:**
1. Navigate to **Tools** page (click "Tools" button in sidebar)
2. Click **"Download"** tab to view available tools
3. Observe connectivity status indicator (should show "Online ✓" if network available)
4. Locate "godot v4.7.2" in the tools list (under "Engine" category)
5. Click the **"Download"** button next to godot v4.7.2
6. Watch progress bar as tool downloads/installs to `%LOCALAPPDATA%\OGS\Library\`. Observe progress behavior:
   - For standard downloads with known size, progress bar shows percentage and label formats as `X.X / Y.Y MB`.
   - For remote downloads without Content-Length (such as HTTP redirects or chunked streams), progress bar remains in indeterminate mode displaying `X.X MB downloaded` without prematurely jumping to "Installing...".
7. Wait for completion (may take 30+ seconds depending on archive size)
8. Observe final status when complete
9. Switch to **"Installed"** tab and verify godot v4.7.2 now appears there
10. Return to **Projects** page and reload sample_project
11. Verify godot v4.7.2 no longer shows ⚠️ warning indicator

**Expected Results:**
- ✅ Tools page loads without errors
- ✅ Download tab shows available tools with "Download" buttons
- ✅ Connectivity status shows "Online ✓" (if network available)
- ✅ Clicking "Download" button starts the download
- ✅ Progress bar appears showing download percentage (or indeterminate mode with `X.X MB downloaded` when Content-Length is unavailable)
- ✅ Auto-transition to "Installing..." occurs only after the download payload is completely received
- ✅ All other download buttons become disabled during active download
- ✅ "Cancel" button appears (optional: click it and verify download stops)
- ✅ Download progresses without crashes (status updates during process)
- ✅ Tool is extracted to `%LOCALAPPDATA%\OGS\Library\godot\4.7.2\` correctly
- ✅ Download completes and button changes to show "Installed" or disappears from Download tab
- ✅ Installed tab now lists godot v4.7.2
- ✅ Projects page updates to reflect tool availability (indicator removed)

**Pass Criteria:**
- Download workflow executes without crashes
- Tool is properly downloaded/installed to library
- Progress is visible during operation
- Projects page automatically syncs with library state

**If test fails:**
- Check that tool archives exist in expected location
- Verify Settings shows "Local mirror ready" or "Remote repository configured"
- Check console for extraction/download errors
- Verify write permissions to `%LOCALAPPDATA%\OGS\Library\`
- If using remote, confirm network is accessible
- Check download status label output for specific error messages
- Verify ToolsController is wired to trigger Projects page refresh

---

### Editor Test 8: Seal Button Enabled & Real Seal Operation

**Objective:** Verify seal button enables after successful tool downloads and perform a real seal operation.

**Prerequisites:**
- Editor Test 7 completed successfully (godot v4.7.2 now present in library)
- sample_project still loaded from Test 7

**Steps:**
1. On Projects page, verify the "Seal for Delivery" button is now **enabled** (green, no longer grayed out)
2. Verify seal button tooltip is cleared (should not say "Download required tools...")
3. Click "Seal for Delivery" button
5. Observe seal dialog that opens
6. Monitor seal progress through stages:
   - "Validating project..."
   - "Copying tools..."
   - "Creating archive..."
   - Final status
7. When complete, note the sealed archive location and filename
8. (Optional) Click "Open Sealed Folder" to verify archive was created
9. Close seal dialog

**Expected Results:**
- ✅ Seal button transitions from disabled → enabled (green color)
- ✅ Seal button tooltip is empty or cleared
- ✅ Clicking seal button opens seal dialog without errors
- ✅ Seal dialog displays:
  - Title: "Seal for Delivery"
  - Status label progressing through stages
  - Output/log area showing operations
- ✅ Seal process completes without crashes
- ✅ Final status shows: **"✓ Sealed successfully!"** (or similar success message)
- ✅ Sealed .zip archive is created with substantial size (>5 MB, confirming tools embedded)
- ✅ Archive filename includes timestamp or project name (e.g., `sample_project_sealed_20260221.zip`)
- ✅ Dialog closes cleanly

**Pass Criteria:**
- Seal button correctly transitions to enabled state
- Seal dialog renders and responds without errors
- Seal operation completes successfully
- Archive is created and accessible

**If test fails:**
- Verify `%LOCALAPPDATA%\OGS\Library\godot\4.7.2\` and `%LOCALAPPDATA%\OGS\Library\blender\4.5.7\` contain files
- Check console for seal operation errors
- Confirm write permissions to output directory (typically user's home)
- Verify SealController.seal_for_delivery() logic
- Check seal_dialog scene structure in main.tscn

---

### Editor Test 9: Offline Mode Enforcement — Launch Tool with Offline Active

**Objective:** Verify that launching a tool when offline is prevented with clear error messaging.

**Steps:**
1. Load sample_project_sealed (which has force_offline=true)
2. Tools list shows "godot v4.7.2" and "blender v4.5.7"
3. Select "godot v4.7.2" from tools list
4. Try to click "Launch" button (or observe if it's disabled)
5. If button is enabled, click it; if disabled, note the state

**Expected Results:**
- ✅ "Launch" button is either:
  - **Disabled** when offline mode is active (preferred UX), OR
  - **Enabled** but clicking shows error dialog: "Launching tools offline is not permitted — tools not found in local library."
- ✅ No external network calls are attempted
- ✅ Output console shows no socket-related errors

**Pass Criteria:**
- Tool launch is prevented in offline mode by design
- User receives clear feedback (disabled button or error message)

**If test fails:**
- Check OfflineEnforcer.is_offline() is called before launch
- Verify ToolLauncher throws appropriate error when offline
- Confirm error dialog or button disabling is implemented

---

### Editor Test 10: Code Category and Tooling Verification (Git and VSCodium)

**Objective:** Verify that "Code Tools" section renders under both Installed and Download tabs with official icons, adding code tools skips asset folder creation, and launch behaviors operate with portable settings injection and offline telemetry suppression.

**Steps:**
1. Navigate to the **Tools** page and inspect both the **Installed** and **Download** tabs.
2. Confirm that a dedicated "Code Tools" section appears beneath "Audio Tools" with headers and container layout matching other categories.
3. Verify that Git and VSCodium display their official transparent icons (`Images/tools/Git.png` and `Images/tools/VSCodium.png`) and clean display names ("Git" and "VSCodium").
4. Return to the **Projects** page and select a project (or create a new test project).
5. Click **"Add Tool"** and select **"git"**; then repeat and add **"vscodium"**.
6. Inspect the project directory structure on disk: confirm that no `assets/Code/` or `assets/Code/git` / `assets/Code/vscodium` folders were created.
7. Select **"git"** in the project tools list and click **"Launch"**:
   - Verify Git Bash opens with the project root directory as its working directory (`--cd=<project_dir>`).
8. Select **"vscodium"** in the project tools list and click **"Launch"**:
   - Verify VSCodium opens with the project root as the workspace folder.
   - Inspect `<project_dir>/.vscode/settings.json` and confirm that `"git.path"` points to `<git_tool_dir>/cmd/git.exe` and `"git.enabled": true`, while preserving any existing settings.
9. Load an offline project (with `force_offline=true` in `ogs_config.json`) and launch VSCodium:
   - Check the console logs to confirm `--disable-telemetry` was passed in the launch arguments.

**Expected Results:**
- ✅ "Code Tools" section renders under both Installed and Download tabs with proper visual hierarchy.
- ✅ Official Git and VSCodium icons render crisply with clean display names.
- ✅ Adding Git or VSCodium skips creating empty `assets/Code/*` folders.
- ✅ Git Bash launches directly into the project directory root.
- ✅ VSCodium launches workspace at project root and auto-configures portable Git in `.vscode/settings.json`.
- ✅ VSCodium receives `--disable-telemetry` when offline mode is active.

**Pass Criteria:**
- Code category tools integrate cleanly across Tools and Projects pages.
- Git and VSCodium launch with proper arguments and automatic configuration.
- Air-gap telemetry suppression is enforced.

---

### Editor Test 11: Project Tools List Selection and Launch Verification

**Objective:** Verify that selecting or double-clicking any tool in the Project Tools List sets it as the active launch tool at the project root, clears any selection in the Project Explorer tree, and properly resets launch state across project switches.

**Steps:**
1. Select a project with installed tools (such as `sample_project` or any project containing Godot, VSCodium, or Git).
2. Click on a file or folder in the Project Explorer tree to select it (verify it highlights).
3. In the **Project Tools** list on the right, click on a tool (e.g. VSCodium or Git):
   - Verify the tool is highlighted in the tools list.
   - Verify that the selection in the Project Explorer tree is immediately cleared.
   - Verify the "Launch Selected Tool" button is enabled.
4. Click **"Launch Selected Tool"**:
   - Verify the selected tool launches at the project root directory.
   - Verify that no "No tool selected or no known tool associated with this file/folder" warning is shown.
5. In the **Project Tools** list, double-click an installed tool:
   - Verify that double-clicking directly triggers tool launch at the project root directory.
6. Click on a file or folder in the Project Explorer tree again:
   - Verify that the selected tool in the Project Tools list is immediately deselected.
7. Switch to another project in the Projects list:
   - Verify that previous launch tool selections and paths are reset completely.

**Expected Results:**
- Clicking a tool in the Project Tools list designates it as the active launch target and clears Project Explorer tree selections.
- Clicking "Launch Selected Tool" or double-clicking launches the selected tool at the project root directory.
- Selecting items in Project Explorer deselects the Project Tools list.
- Switching projects clears previous launch state without leaking across projects.

**Pass Criteria:**
- Project Tools list and Project Explorer maintain mutual deselection.
- Single-click launch and double-click activation both succeed at project root.
- Launch state is cleared upon project switching or launch button disablement.

---

### Editor Test 12: Stack-Aware Project Explorer VSCodium Mappings and Double-Click Launch

**Objective:** Verify that Project Explorer is stack-aware: displaying developer script, shader, text, and structured data files with the VSCodium icon when VSCodium is pinned, pruning text/script files in Godot-only stacks, suppressing internal engine and launcher metadata files, launching files immediately on double-click, and creating default text files when VSCodium is present.

**Steps:**
1. Select or create a project with VSCodium pinned in its stack (e.g. Godot + VSCodium).
2. Inspect the Project Explorer tree view on the right:
   - Confirm non-excluded text, script, shader, and data files (`.gd`, `.cs`, `.gdshader`, `.shader`, `.txt`, `.md`, `.csv`, `.json`, `.yaml`, `.yml`, `.toml`) appear in the tree.
   - Confirm each recognized file displays the official VSCodium icon (`Images/tools/VSCodium.png`) at a max width of 20px.
   - Confirm internal launcher and engine metadata files (`stack.json`, `ogs_config.json`, `ogs_metadata.json`, `.import`, `.uid`, `.cfg`, `.tres`, `.tscn`) remain strictly hidden.
3. Double-click any recognized text or script file (e.g. `main.gd` or `notes.txt`) in the Project Explorer:
   - Confirm the file is activated and VSCodium launches targeting that file.
4. Switch to a Godot-only project (a project without VSCodium in its stack):
   - Confirm that `.gd`, `.txt`, `.md`, and `.json` files are pruned from the tree.
   - Confirm only `project.godot` and binary asset tool files/folders appear in the tree.
5. In a project with VSCodium, click "New File" and enter a name with no extension (e.g. `todo_notes`):
   - Confirm `.txt` is automatically appended to the filename.
   - Confirm an empty file is created on disk at the target folder.
   - Confirm VSCodium launches targeting the newly created file.

**Expected Results:**
- [x] Text, script, shader, and data files display with the VSCodium icon when VSCodium is in the stack.
- [x] Internal launcher and engine metadata files remain hidden even when `.json` is supported.
- [x] Godot-only projects prune text and script files to prevent unsupported tool associations.
- [x] Double-clicking any launchable file in Project Explorer immediately triggers tool launch targeting that file.
- [x] Creating a new file without an extension in a VSCodium stack defaults to `.txt` and launches VSCodium.

**Pass Criteria:**
- Project Explorer accurately reflects stack capabilities.
- Double-click file activation triggers tool launch.
- Metadata files are never surfaced.
- Text file creation defaults to `.txt` with VSCodium.

**If test fails:**
- Check `scripts/tools/file_type_mapper.gd` for `VSCODIUM_EXTENSIONS`, `EXCLUDED_FILENAMES`, and `EXCLUDED_EXTENSIONS`.
- Verify `scripts/projects/project_explorer.gd` signal `file_activated` emission in `_on_item_activated()`.
- Check `scripts/projects/projects_controller.gd` connection `_on_explorer_file_activated()` and `_on_new_file_confirmed()`.

---

### Editor Test 13: Debug MCP Visual QA Bridge Verification

**Objective:** Verify that `McpInteractionServer` runs during debug execution, binds to `127.0.0.1:9090`, allows scene tree and UI element inspection, captures viewport screenshots via `mcp_client.py`, and cleans up properly.

**Steps:**
1. Start OGS Launcher in debug mode (press F5 in Godot or run `godot` in terminal).
2. Open PowerShell and run:
   ```powershell
   python mcp_client.py ping
   ```
3. Capture a viewport screenshot:
   ```powershell
   python mcp_client.py screenshot
   ```
4. Query UI elements:
   ```powershell
   python mcp_client.py get_ui_elements
   ```
5. Terminate the debug launcher and clean up screenshots:
   ```powershell
   Stop-Process -Name "Godot*" -Force -ErrorAction SilentlyContinue
   Get-ChildItem -Path screenshot*, agent_screenshot* -ErrorAction SilentlyContinue | Remove-Item -Force
   ```

**Expected Results:**
- ✅ `python mcp_client.py ping` returns JSON with `status: ok` and OS details.
- ✅ `python mcp_client.py screenshot` generates `screenshot.png` matching launcher window dimensions (1024x700).
- ✅ `python mcp_client.py get_ui_elements` returns JSON list of all active Control nodes with positions and sizes.
- ✅ Background process terminates cleanly and releases port `9090`.

**Pass Criteria:**
- Bridge responds reliably on localhost port 9090 in debug mode.
- Screenshot captures rendered viewport.
- Cleanup releases file locks and network port.

**If test fails:**
- Confirm `project.godot` registers `McpInteractionServer` under `[autoload]`.
- Check if port 9090 is in use (`Get-NetTCPConnection -LocalPort 9090`).
- Ensure launcher is running in debug mode (`OS.is_debug_build() == true`).

---

### Editor Test 14: Primary Projects Folder Configuration and Auto-Generated ogs_config.json

**Objective:** Verify that the Primary Projects Folder setting in PageSettings allows configuring and resetting the project directory, affects New Project creation, and verify that importing a project containing only `stack.json` auto-generates a valid `ogs_config.json`.

**Steps:**
1. Navigate to the **Settings** page (click "Settings" in sidebar).
2. Locate the **Projects** section at the top of the Settings page.
3. Verify that the **Primary Projects Folder** input displays the default path hint pointing to `%USERPROFILE%\OGS_Projects` (or `$HOME/OGS_Projects`).
4. Click **"Browse"** next to Primary Projects Folder:
   - Select a custom folder (such as a temporary folder `user://custom_projects` or `C:\Temp\Custom_OGS_Projects`).
   - Confirm the input field updates to the selected folder path.
5. Navigate to the **Projects** page and click **"New Project"**:
   - Inspect the instructions label inside the New Project dialog.
   - Confirm the instructions label states that the folder will be created under the custom folder path.
   - Enter `Manual_Test_Project` and click **OK**.
   - Verify that the new project directory `Manual_Test_Project` is created inside the custom folder on disk.
6. Return to the **Settings** page and click **"Reset to Default"** next to Primary Projects Folder:
   - Verify the input field clears and placeholder text returns to the default user directory.
   - Return to Projects page, click "New Project", and confirm the instructions label points back to the default OGS Projects directory.
7. Prepare a test folder containing ONLY `stack.json` (no `ogs_config.json`):
   - In a temporary folder, create `stack.json` with a valid stack payload (`{"schema_version": 1, "stack_name": "Stack Only Test", "tools": []}`).
   - Ensure no `ogs_config.json` exists in that directory.
8. On the Projects page, click **"Add Local Project"**:
   - In the folder picker, select the temporary folder.
   - Confirm the "Add Project" button in the picker is enabled.
   - Click "Add Project" in the picker dialog.
   - Verify the project is added to the Project Library and selected.
   - Inspect the folder on disk: verify `ogs_config.json` has been auto-generated with default offline settings (`offline_mode: false`, `force_offline: false`).

**Expected Results:**
- [x] Primary Projects Folder controls render cleanly at the top of the Settings page.
- [x] Browse button opens directory dialog and updates path.
- [x] New Project dialog instructions label reflects active primary folder.
- [x] Project scaffolding is created in the configured folder.
- [x] Reset to Default reverts the primary folder to the standard default path.
- [x] Projects with only `stack.json` are accepted by Add Local Project.
- [x] Missing `ogs_config.json` is auto-generated on disk with valid default settings.

**Pass Criteria:**
- Custom projects folder persists and redirects project creation.
- Reset to Default restores standard directory.
- Projects containing only stack.json import successfully with auto-generated configuration.

---

### Editor Test 15: Remote Project Git Cloner Backend and URL Security Validation

**Objective:** Verify that `RemoteProjectCloner` accurately resolves PortableGit from the Central Library, validates and sanitizes remote Git URLs according to strict air-gap and injection-hardening rules, extracts clean slugs, suggests collision-free folder names, and enforces two-phase manifest verification.

**Steps:**
1. Verify PortableGit discovery in Central Library:
   - Run a test script or evaluate in headless runner: `RemoteProjectCloner.is_git_installed()`.
   - Confirm it returns `true` when Git is extracted at `%LOCALAPPDATA%\OGS\Library\git\<version>\cmd\git.exe` (Windows) or `bin/git` (Unix/macOS).
   - Confirm `RemoteProjectCloner.resolve_git_executable()` returns the absolute path to the binary with the highest installed semantic version.
2. Verify remote repository URL security validation:
   - Test valid URLs: `https://github.com/org/repo.git`, `http://localhost:3000/repo.git` (local LAN mirror), `ssh://git@github.com/org/repo.git`, and `git@github.com:org/repo.git`.
   - Confirm all valid URLs return `valid: true`.
   - Test disallowed URLs:
     - Argument injection: `-u https://...` or `--upload-pack=calc.exe` (fails with `argument_injection`).
     - Disallowed protocols: `file:///C:/path` and `ext::sh -c evil` (fails with `disallowed_protocol`).
     - Local paths: `C:\Projects\repo`, `/var/repos/repo`, `./repo`, `../repo` (fails with `local_path`).
     - Shell metacharacters: `https://github.com/org/repo;rm -rf /`, `https://... & echo hacked` (fails with `shell_metacharacters`).
     - Illegal characters and control codes (fails with `illegal_characters`).
3. Verify slug extraction and folder collision naming:
   - Extract slug from `https://github.com/org/my-game-repo.git/` -> `my-game-repo`.
   - Call `suggest_next_available_folder_name(dest_root, "my-game-repo")` when `my-game-repo` already exists: verify it suggests `my-game-repo-1`, then `my-game-repo-2`.
4. Verify air-gap enforcement:
   - Enable offline mode (`OfflineEnforcer.set_offline(true)`).
   - Call `cloner.clone_project_async("https://github.com/org/repo.git", "repo", dest_root)`.
   - Verify `clone_failed` signal emits with error code `offline` without spawning child processes.
5. Verify two-phase manifest verification:
   - When cloning a repository lacking `stack.json` at root: verify `clone_failed` emits `missing_stack_json` and the target directory is deleted safely within destination bounds.

**Expected Results:**
- [x] PortableGit executable resolves accurately to the highest installed semantic version.
- [x] Allowed URL schemes (https, http, ssh, scp) pass validation.
- [x] Injection attacks, disallowed protocols (file, ext), local paths, and shell metacharacters are rejected.
- [x] Slugs and collision avoidance names generate deterministically.
- [x] Offline mode immediately blocks clone requests without spawning network processes.
- [x] Two-phase manifest check deletes incomplete directories when stack.json is missing or invalid.

**Pass Criteria:**
- RemoteProjectCloner passes all validation and lifecycle checks.
- Git arguments include hardened configuration flags.
- Cleanup never deletes outside destination root.

---

### Editor Test 16: Add Remote Project Button and Modal Cloning Workflow

**Objective:** Verify that the 3-button Projects toolbar renders with equal width and 16px separation, missing PortableGit triggers a guided navigation prompt to the Tools page, the modal dialog handles URL entry and destination overrides, folder collisions offer auto-incremented naming suggestions, active clones can be cancelled cleanly, and offline mode disables the button with a descriptive tooltip.

**Steps:**
1. Inspect the Projects page top toolbar:
   - Verify three buttons are displayed in order: "Add Local Project", "Add Remote Project", and "New Project".
   - Confirm all three buttons have equal horizontal expansion (`size_flags_horizontal = 3`) and are separated by 16px horizontal spacing.
2. Missing-Git guided prompt verification:
   - Temporarily rename or move any extracted Git folder in the Central Library (`%LOCALAPPDATA%\OGS\Library\git`).
   - Click **"Add Remote Project"**.
   - Confirm an exclusive modal dialog titled "Git Required" appears stating that PortableGit must be installed.
   - Click **"Go to Tools"** and verify the launcher automatically switches to the Tools page with the Download tab focused.
   - Restore the Git folder in the Central Library.
3. Clone dialog, sizing, and URL validation:
   - Click **"Add Remote Project"**.
   - Verify an exclusive modal dialog titled "Add Remote Project" opens with focus on the repository URL input field.
   - Verify the dialog renders with compact, bounded dimensions (approx. 540x280 to 540x320px) with 10px MarginContainer padding on all sides, the header text wraps smoothly across lines without vertical ballooning, and both Clone and Cancel buttons remain visible within view.
   - Confirm the Destination Folder field is pre-filled with the active Primary Projects Folder.
   - Confirm the "Clone" button is initially disabled.
   - Type whitespace into the URL field: confirm "Clone" remains disabled.
   - Enter a valid repository URL (e.g. `https://github.com/OpenGameStack/sample-project.git`): confirm "Clone" becomes enabled.
   - Click **"Browse..."** next to Destination Folder: select an alternate directory in the folder picker and confirm the destination updates.
4. Folder collision resolution and sizing:
   - In your destination folder, create a test directory named `sample-project`.
   - Enter `https://github.com/OpenGameStack/sample-project.git` in the URL field and click **"Clone"**.
   - Confirm an exclusive modal dialog titled "Folder Name Collision" appears.
   - Verify the collision dialog renders with bounded dimensions (approx. 480x160 to 480x260px) with 10px MarginContainer padding on all sides, the warning text and any collision error labels wrap cleanly across lines without stretching the window horizontally, and Continue and Cancel buttons remain visible and centered.
   - Confirm the suggested folder name is auto-incremented to `sample-project-1`.
   - Click **"Cancel"** on the collision dialog and remove the temporary test directory.
5. In-progress cancellation:
   - Enter a valid URL for a repository and click **"Clone"**.
   - While the status label displays cloning activity, click **"Cancel"**.
   - Confirm the Cancel button text immediately changes to "Cancelling..." and disables.
   - Confirm the clone process is terminated and the dialog resets to its idle input state.
6. Offline mode enforcement:
   - Enable offline mode in Settings.
   - Return to the Projects page: verify **"Add Remote Project"** is disabled.
   - Hover over the button: verify the tooltip reads: `"Disabled because OGS Launcher is currently in offline mode."`
   - Disable offline mode in Settings: verify the button re-enables and the tooltip clears.

**Expected Results:**
- [x] Three-button toolbar layout renders with equal button widths and 16px separation.
- [x] Missing PortableGit opens guided dialog and "Go to Tools" navigates to Tools page.
- [x] Modal clone dialog renders at compact, bounded dimensions (~540x280 to 540x320px) with 10px MarginContainer padding and word-wrapped header/status labels without vertical ballooning.
- [x] Modal dialog pre-fills primary folder and enables Clone button only when non-empty URL is provided.
- [x] Folder collision dialog renders at compact, bounded dimensions (~480x160 to 480x260px) with 10px MarginContainer padding and word-wrapped warning/error text without horizontal stretching.
- [x] Folder collision dialog suggests auto-incremented folder names (slug-1, slug-2).
- [x] Cancellation terminates child processes and resets the dialog cleanly.
- [x] Offline mode disables Add Remote Project with descriptive tooltip.

**Pass Criteria:**
- User-facing remote project clone workflow functions reliably.
- Modals are exclusive and unresizable.
- Offline mode and missing-Git guidance protect air-gap and user experience.

---

### Editor Test 17: Shell Content Margins and Standard Typographic Scale

**Objective:** Verify that `AppLayout/Content` enforces standard 20px horizontal and 16px vertical margins, preventing content from sitting flush against the window borders, and verify that the typographic hierarchy across page titles (24px), section headers (18px cyan accent), form labels/body (16px), and secondary/metadata labels (13px muted) renders legibly without clipping.

**Steps:**
1. Launch OGS Launcher in editor mode or standalone.
2. Projects page inspection:
   - Verify 20px left margin between the sidebar panel and page content.
   - Verify 20px right margin between project cards/scrollbars and the right window edge.
   - Verify 16px top margin above the "Projects" title.
   - Verify 16px bottom margin below the action row buttons ("Open Project", "Remove Project", "Seal for Delivery") so buttons do not sit directly on the bottom window edge.
   - Verify "Projects" page title renders with prominent 24px font size.
   - Verify "Project Explorer" header renders with 18px font size and cyan accent color (`Color(0.45, 0.8, 1.0)`).
   - Verify status labels ("Status: ...", "Offline Mode: ...") render with compact 13px font size and muted slate styling (`Color(0.65, 0.70, 0.78)`).
3. Tools page inspection:
   - Click **"Tools"** in the sidebar.
   - Verify "Tools" page title renders at 24px.
   - Verify "Refresh" button maintains 20px clearance from right window edge.
   - Verify category headers ("Engine", "2D Tools", "3D Tools", "Audio", "Code") preserve their distinct category colors.
   - Verify "Status: Online" or offline messages render at 13px font size.
4. Settings page inspection:
   - Click **"Settings"** in the sidebar.
   - Verify "Settings" page title renders at 24px.
   - Verify section headers ("Projects", "Network", "Selected Project Offline Policy", "Mirror Settings") render at 18px with cyan accent color.
   - Verify form row labels ("Primary Projects Folder:", "Mirror Root:", "Remote Repo URL:") render at standard 16px body font size.
   - Verify secondary metadata labels ("Selected: ...", "Mirror status: ...") render at 13px muted color.

**Expected Results:**
- [x] Uniform 20px horizontal and 16px vertical content margins across Projects, Tools, and Settings pages.
- [x] Bottom action buttons and right scrollbars do not touch or clip against the outer window borders.
- [x] Page titles render at 24px font size.
- [x] Section headers render at 18px font size with high-contrast cyan accent styling.
- [x] Secondary status and metadata labels render at 13px font size with muted slate styling.
- [x] Custom tool category colors in Tools page remain distinct and intact.

**Pass Criteria:**
- Main layout content does not collide with window borders.
- Typographic scale clearly separates page titles, section headers, form controls, and secondary status labels across all views.

---

### Editor Test 18: Sidebar Brand Header, Active Page Highlight, and Connectivity Footer

**Objective:** Verify that the redesigned sidebar features the persistent brand header (32x32 logo and title), active page highlight styling with accent border on the active navigation button, and footer connectivity indicator and launcher version.

**Steps:**
1. Launch OGS Launcher in editor mode or standalone.
2. Brand Header Inspection:
   - Verify 32x32 OGS logo (`res://Images/logo.png`) renders crisply at the top left.
   - Verify "OGS Launcher" title renders in 16px font next to the logo.
   - Verify horizontal separator line below the brand header divides branding from navigation buttons.
3. Active Page Highlight Inspection (Startup):
   - Verify "Projects" button is highlighted as active with an elevated dark background (`Color(0.18, 0.22, 0.28)`), bright white font color, and a 3px primary blue left border (`Color(0.35, 0.68, 0.95)`).
   - Verify "Tools" and "Settings" buttons display flat normal styling with no left border and muted text color (`Color(0.70, 0.75, 0.82)`).
4. Page Navigation Switching:
   - Click "Tools" in the sidebar.
   - Verify the "Tools" button transitions to active styling with the 3px blue left border and bright font color.
   - Verify the "Projects" button restores normal flat styling with 0px left border.
   - Click "Settings" in the sidebar.
   - Verify the "Settings" button transitions to active styling and "Tools" restores normal flat styling.
5. Sidebar Footer Inspection:
   - Verify the expanding spacer pushes the footer container cleanly to the bottom of the sidebar.
   - Verify the footer separator line.
   - Verify the connectivity status label displays "● Offline" (in amber) or "● Online" (in green) depending on repository connectivity.
   - Verify the version label displays the launcher version (e.g. "v0.1.0").
6. Connectivity State Synchronization:
   - Navigate to Settings and toggle "Force offline" (or "Offline mode") to ON.
   - Verify the sidebar footer status label immediately updates to "● Offline" in amber with descriptive tooltip ("Offline Mode (enforced: force_offline)").
   - Toggle offline mode OFF (when connected to the internet) and click "Check for Updates" or refresh on Tools page.
   - Verify the sidebar footer status label updates to "● Online" in green with tooltip ("Online: Connected to repository").

**Expected Results:**
- [x] Persistent brand header displays 32x32 logo, "OGS Launcher" title, and divider.
- [x] Active page highlight clearly identifies the active view with an elevated background and 3px blue left accent border.
- [x] Inactive navigation buttons display muted flat styling.
- [x] Navigation clicks cleanly transfer the active highlight to the selected page.
- [x] Sidebar footer displays global connectivity state and launcher version.
- [x] Toggling offline mode immediately updates the footer status indicator between green Online and amber Offline.

**Pass Criteria:**
- Sidebar branding and active highlights render cleanly without visual glitches.
- Active highlight transfers seamlessly on page switching.
- Global connectivity indicator accurately reflects OfflineEnforcer and ToolsController state.

---

### Editor Test 19: Semantic Button Variations and CheckButton Toggle Styling

**Objective:** Verify that primary calls to action, secondary neutral/utility actions, and destructive actions have distinct visual styling via Button theme type variations, and verify that CheckButton toggles render as clean rows without solid rectangular button bars.

**Steps:**
1. Launch OGS Launcher in editor mode or standalone.
2. Projects Page - Action Buttons and Visual Hierarchy:
   - Verify "New Project" renders with vibrant brand-blue background (`Color(0.20, 0.48, 0.78)`), brighter hover state (`Color(0.26, 0.56, 0.88)`), and high-contrast cyan focus ring (`PrimaryButton`).
   - Verify "Add Local Project" and "Add Remote Project" render with dark slate background (`Color(0.18, 0.21, 0.26)`) and 1px border (`SecondaryButton`).
   - Select a project in the Project Library.
   - Verify "Seal for Delivery" renders in vibrant brand blue (`PrimaryButton`).
   - Verify "Remove Project" renders with dark surface and muted crimson border (`Color(0.65, 0.22, 0.25)`), transitioning to crimson hover fill (`DangerButton`).
   - Verify "Open Project" renders with standard default button styling.
   - Navigate to the Project Details tab.
   - Verify "Launch Selected Tool" displays vibrant brand blue (`PrimaryButton`).
   - Verify "Add Tool", "Change Version", "New Folder", and "New File" buttons display dark slate with subtle borders (`SecondaryButton`).
   - Verify "Remove Tool" displays dark surface with muted crimson border and crimson hover (`DangerButton`).
3. Tools Page - Dynamic Tool Card Buttons:
   - Click "Tools" in the sidebar.
   - Switch to the "Download" tab.
   - Verify uninstalled tool "Download" buttons render with vibrant brand blue (`PrimaryButton`).
   - If an active download is running, verify the "Cancel" button displays secondary styling (`SecondaryButton`).
   - Switch to the "Installed" tab.
   - Verify installed tool "Remove" buttons display danger styling with crimson border and hover (`DangerButton`).
   - Verify the top-right "Refresh" button displays secondary styling (`SecondaryButton`).
4. Settings Page - CheckButton Toggles and Utility Buttons:
   - Click "Settings" in the sidebar.
   - Inspect "Offline mode" and "Force offline" toggle controls.
   - Verify they render as clean, lightweight toggle switch rows using empty background styleboxes (`StyleBoxEmpty`) without solid rectangular action button backgrounds.
   - Hover over the switches and verify a subtle translucent hover highlight (`Color(1.0, 1.0, 1.0, 0.04)`) with 4px rounded corners.
   - Verify directory "Browse", "Reset to Default", and "Check for Updates" buttons render as secondary buttons with slate background and subtle borders (`SecondaryButton`).

**Expected Results:**
- [x] Primary calls to action ("New Project", "Launch Selected Tool", "Seal for Delivery", "Download") prominently stand out in vibrant brand blue.
- [x] Secondary utility actions ("Add Local Project", "Add Remote Project", "Add Tool", "Change Version", "Browse", "Reset to Default", "Refresh") display dark slate surfaces with subtle borders.
- [x] Destructive actions ("Remove Project", "Remove Tool", installed tool "Remove") feature warning crimson borders and hover fills.
- [x] CheckButton controls render as clean toggle rows without solid button bars.

**Pass Criteria:**
- Visual hierarchy clearly distinguishes primary, secondary, and danger button actions across all three views.
- CheckButton toggles appear as lightweight rows rather than rectangular buttons.
- Hover, focus, and disabled states function properly for all theme type variations.

---

### Editor Test 20: Normalized Path Separators in User-Facing Labels and Placeholders

**Objective:** Verify that filesystem and project paths displayed in UI labels, list items, tooltips, placeholders, and dialogs consistently display uniform forward slashes without mixed Windows backslashes.

**Steps:**
1. Launch OGS Launcher in editor mode or standalone on Windows.
2. Projects Page - Project Library Path Normalization:
   - Check the project list entries in the Project Library list.
   - Verify that the path line beneath each project title displays forward slashes (e.g., `C:/Users/.../OGS_Projects/...` or `C:/Users/.../AppData/Local/OGS/Projects/...`) without mixed backslashes (`\`).
   - Hover over each project list item to display its tooltip.
   - Verify that the tooltip path string matches the normalized forward-slash display path without backslashes.
3. Projects Page - Project Explorer Header Normalization:
   - Select or open a project in the Project Library.
   - Inspect the Project Explorer title label above the file tree.
   - Verify that the header reads `Project Explorer - C:/Users/...` using clean forward slashes.
4. Projects Page - New Project Dialog Target Path:
   - Click "New Project" in the Projects page toolbar.
   - Inspect the instructions label inside the New Project modal dialog.
   - Verify the target creation folder path preview displays forward slashes without mixed backslashes.
   - Close or cancel the New Project dialog.
5. Settings Page - Primary Projects Folder and Offline Status:
   - Navigate to the Settings page (click "Settings" in the sidebar).
   - Inspect the "Primary Projects Folder" LineEdit placeholder text.
   - Verify that the default placeholder path displays forward slashes (e.g., `C:/Users/.../OGS_Projects`).
   - Inspect the "Selected Project Offline Policy" section label ("Selected: ...").
   - Verify that the selected project path displays uniform forward slashes without backslashes.

**Expected Results:**
- [x] Project list item paths and item tooltips render with uniform forward slashes.
- [x] Project Explorer title label displays clean forward-slash path formatting.
- [x] New Project dialog instruction label path preview displays forward slashes.
- [x] Settings page Primary Projects Folder placeholder text and Selected Project path label display forward slashes.

**Pass Criteria:**
- No mixed Windows backslashes and Unix forward slashes appear in any user-facing path labels, tooltips, or placeholders.
- Path presentation is consistent across Projects and Settings pages.

---

## Summary: Editor Testing Checklist

After completing Editor Tests 1-20, fill in this table:

| Test | Status | Notes | Blockers |
|------|--------|-------|----------|
| 1: Startup & Onboarding | ✅/⚠️/❌ | | |
| 2: Load sample_project | ✅/⚠️/❌ | | |
| 3: Load sample_project_sealed | ✅/⚠️/❌ | | |
| 3.1: Add / Remove Tool Flow | ✅/⚠️/❌ | | |
| 3.2: Project Explorer Pruning | ✅/⚠️/❌ | | |
| 4: Mirror Config UI | ✅/⚠️/❌ | | |
| 5: Remote Repo Config | ✅/⚠️/❌ | | |
| 6: Seal Button States | ✅/⚠️/❌ | | |
| 7: Per-Tool Download Workflow | ✅/⚠️/❌ | | |
| 8: Seal Button & Real Seal | ✅/⚠️/❌ | | |
| 9: Offline Tool Launch | ✅/⚠️/❌ | | |
| 10: Code Tooling & Launch | ✅/⚠️/❌ | | |
| 11: Project Tools List Launch | ✅/⚠️/❌ | | |
| 12: Stack-Aware Explorer & Double-Click | ✅/⚠️/❌ | | |
| 13: Debug MCP Visual QA Bridge | ✅/⚠️/❌ | | |
| 14: Primary Projects Folder & Auto-Config | ✅/⚠️/❌ | | |
| 15: Remote Git Cloner & URL Validation | ✅/⚠️/❌ | | |
| 16: Remote Project Toolbar & Modal Clone | ✅/⚠️/❌ | | |
| 17: Shell Margins & Typography Scale | ✅/⚠️/❌ | | |
| 18: Sidebar Redesign & Footer Sync | ✅/⚠️/❌ | | |
| 19: Semantic Buttons & CheckButton | ✅/⚠️/❌ | | |
| 20: Normalized Path Display | ✅/⚠️/❌ | | |

---

# PART B: INSTALLED-BUILD TESTING

## Prerequisites (Installed Build)

- OGS Launcher exported as a Windows binary (ogs_launcher.exe or similar)
- Export includes all necessary DLLs, assets, and scripts
- Two sample projects available in `samples/` directory (relative to launcher or absolute path)
- Fresh state: launcher run with clean %LOCALAPPDATA%/OGS directory (simulate first user)
- Administrator access NOT required (launcher is portable)

### Achieving Fresh State for Installed Tests

Before running Installed Tests, clean up any previous launcher data to simulate a first-time user:

**IMPORTANT:** Back up any existing projects, tools, or settings you want to keep before deleting data. Fresh-state cleanup is destructive and cannot be undone.

**PowerShell One-Liner:**
```powershell
Remove-Item -Path "$env:LOCALAPPDATA\OGS" -Recurse -Force -ErrorAction SilentlyContinue; Write-Host "✓ Fresh state ready"
```

**Verification After Export:**
1. Double-click `ogs_launcher.exe` to launch the exported binary
2. The **Onboarding wizard must appear** (confirms first-run detection)
3. Check that `%LOCALAPPDATA%/OGS/` directory was created
4. Confirm `%LOCALAPPDATA%/OGS/Library/` is empty (no pre-populated tools)

If onboarding wizard does NOT appear, fresh state was not achieved. Repeat the cleanup and relaunch.

### Installed Test 1: Launcher Export & First Launch

**Objective:** Verify that the exported launcher binary starts correctly and detects first-run state.

**Steps:**
1. Build/export OGS Launcher as a standalone Windows executable
2. Place the executable and all supporting files in a clean directory
3. Ensure %LOCALAPPDATA%/OGS directory does NOT exist (simulating first user)
4. Launch the executable by double-clicking it
5. Observe window appearance and any dialogs

**Expected Results:**
- ✅ Launcher window opens without errors or crashes
- ✅ Window title bar shows "OGS Launcher" or similar
- ✅ All UI elements (sidebar buttons, page content) render correctly
- ✅ Projects page is default/active
- ✅ Onboarding wizard appears (welcome dialog)
- ✅ %LOCALAPPDATA%/OGS/Library directory is created automatically

**Pass Criteria:**
- Launcher binary is portable and runs without external dependencies
- First-run detection works (onboarding appears)
- Launcher creates required directories

**If test fails:**
- Check that all required DLLs are included in export
- Verify launcher binary is 64-bit (matches system architecture)
- Confirm %LOCALAPPDATA% path is correctly resolved on user's system

---

### Installed Test 2: Add sample_project (Development Mode)

**Objective:** Verify the same project-add behavior as Editor Test 2, but in installed context.

**Steps:**
1. Close onboarding wizard
2. Click **"Add Project"**
3. Navigate to `samples/sample_project` (adjust path if samples are in a different location)
4. Click **"Add Project"** in the folder picker
6. Observe state

**Expected Results:**
- ✅ Project loads without errors
- ✅ Tools list shows "godot v4.7.2" and "blender v4.5.7"
- ✅ Missing tools show **⚠️ yellow warning triangle** indicators
- ✅ "Seal for Delivery" button is disabled
- ✅ Status reflects missing tools: "Manifest loaded. 2 tool(s) missing..."
- ✅ Offline status shows: "Offline Mode: Disabled"

**Pass Criteria:**
- Same results as Editor Test 2, confirming editor and installed behavior are consistent
- Reproducible across multiple launches

**If test fails:**
- Compare results to Editor Test 2
- Check samples/sample_project/ paths are correctly resolved
- Verify file I/O works in installed context

---

### Installed Test 3: Settings Persistence Across Launches

**Objective:** Verify that launcher settings (mirror root, remote repo URL) persist between sessions.

**Steps:**
1. From Installed Test 1 (fresh launcher), navigate to Settings page
2. In "Mirror Root:" field, type or browse to a custom path (e.g., `C:\MyOGSMirror\`)
3. In "Remote Repo URL:" field, paste a test URL
4. Close the launcher completely
5. Wait a few seconds
6. Relaunch the launcher (double-click executable again)
7. Navigate back to Settings page
8. Check if your custom path and URL are still there

**Expected Results:**
- ✅ Custom mirror root path is preserved in "Mirror Root:" field
- ✅ Custom remote repo URL is preserved in "Remote Repo URL:" field
- ✅ Settings file (ogs_launcher_settings.json) exists in %LOCALAPPDATA%/OGS/
- ✅ Launcher starts reliably after settings are saved

**Pass Criteria:**
- Settings persist across launcher sessions
- No data corruption or loss of settings
- Launcher remains stable with custom settings

**If test fails:**
- Check that ogs_launcher_settings.json is created in user data directory
- Verify JSON serialization/deserialization works in installed context
- Confirm write permissions to %LOCALAPPDATA%

---

### Installed Test 4: Per-Tool Download — Real Tool Installation (Installed Binary)

**Objective:** Verify per-tool download workflow in exported binary when tool archives are available.

**Prerequisite:**
- Obtain tool archives (from official OGS mirror or create test archives)
- **Option A (Local Mirror):** Place them in %LOCALAPPDATA%/OGS/Mirror/ in the correct directory structure:
  ```
  %LOCALAPPDATA%/OGS/Mirror/
  ├── godot/
  │   └── 4.7.2/
  │       └── godot_4.7.2.zip
  └── blender/
      └── 4.5.7/
          └── blender_4.5.7.zip
  ```
- **Option B (Remote Repository):** Configure remote repository URL in Settings pointing to valid repository.json
- Ensure repository.json exists with matching tool entries

**Steps:**
1. Load sample_project on Projects page (should show tools with ⚠️ indicators)
2. Navigate to **Tools** page (click "Tools" button in sidebar)
3. Click **"Download"** tab
4. Observe available tools list (should show godot v4.7.2 and blender v4.5.7)
5. Click **"Download"** button next to godot v4.7.2
6. Watch progress bar as tool downloads/installs to %LOCALAPPDATA%/OGS/Library/
7. Allow process to complete
8. Switch to **"Installed"** tab and verify godot v4.7.2 appears there
9. Return to **Projects** page
10. Reload sample_project and verify godot v4.7.2 no longer shows ⚠️ indicator

**Expected Results:**
- ✅ Tools page loads and shows available tools in Download tab
- ✅ "Download" button is visible and enabled for each available tool
- ✅ Clicking "Download" starts the installation process
- ✅ Progress bar displays download/install percentage
- ✅ Other download buttons are disabled during active download
- ✅ Tool is extracted to %LOCALAPPDATA%/OGS/Library/godot/4.7.2/ correctly
- ✅ After completion, tool appears in "Installed" tab
- ✅ Projects page automatically updates to reflect tool availability
- ✅ No unhandled exceptions or crashes during download

**Pass Criteria:**
- Download workflow completes without intervention
- Tool is properly extracted and verified
- Projects page reflects updated library state

**If test fails:**
- Check that tool archives exist in expected mirror location
- Verify SHA-256 hashes in repository.json match actual archive files
- Confirm extraction/unzip logic works in installed context
- Check permissions for writing to %LOCALAPPDATA%
- Verify ToolsController.tool_list_updated signal triggers Projects refresh

---

### Installed Test 5: Seal for Delivery — Export Project

**Objective:** Verify the "Seal for Delivery" workflow creates a valid, portable archive.

**Prerequisite:**
- Completed Installed Test 4 (tools are in library)
- sample_project loaded with "Seal for Delivery" button enabled

**Steps:**
1. Click "Seal for Delivery" button
2. Observe seal dialog that appears
3. Monitor status as sealing progresses:
   - "Validating project..."
   - "Copying tools..."
   - "Creating archive..."
   - "Seal complete!"
4. When complete, note the sealing output summary:
   - Tools copied count
   - Project size
   - Sealed archive path
5. Click "Open Sealed Folder" button to navigate to the result
6. Verify the sealed .zip file exists with a reasonable size (>100 MB likely)

**Expected Results:**
- ✅ Seal dialog progresses through stages without errors
- ✅ Final status shows: "✓ Sealed successfully!"
- ✅ Output shows tools copied (e.g., "Tools copied: 2")
- ✅ Sealed .zip file is created in a user-visible location (e.g., user's Documents or Downloads)
- ✅ Sealed archive filename includes timestamp or project name (e.g., `sample_project_sealed_20260221.zip`)
- ✅ Archive size is substantial (confirms tools are embedded)
- ✅ File explorer opens to sealed archive location when "Open Sealed Folder" clicked

**Pass Criteria:**
- Seal workflow executes completely without crashes
- Sealed archive is created and is non-empty
- User can easily locate the sealed artifact

**If test fails:**
- Check for file system errors in console
- Verify write permissions to output directory
- Confirm ZIPPacker functionality works in installed context
- Check disk space availability

---

### Installed Test 6: Sealed Archive Portability — Extract & Launch

**Objective:** Verify that a sealed archive can be extracted on a different machine/path and launcher still works.

**Prerequisite:**
- Completed Installed Test 5 (sealed archive ready)

**Steps:**
1. Extract the sealed .zip file to a temporary directory (e.g., `C:\TestSealed\sample_project_sealed\`)
2. Inside the extracted folder, locate the OGS Launcher executable (should be at root or in a launcher subfolder)
3. Alternatively, if launcher is not included, use the same launcher executable from Installed Test 1
4. Launch the launcher from (or pointing to) the sealed project directory
5. Navigate to Projects page
6. Browse to the extracted sealed project folder
7. Click "Load"
8. Observe project state

**Expected Results:**
- ✅ Sealed project loads successfully
- ✅ Tools list shows embedded tools (godot, blender)
- ✅ Tool indicators show no warnings (⚠️ or ❌) since tools are present locally
- ✅ "Seal for Delivery" button is **disabled** (already sealed, no reason to reseal)
- ✅ Offline status shows: **"Offline Mode: Forced (force_offline=true)"** (from sealed config)
- ✅ Tools are shown as "available in library" (found in local ./tools/ directory)
- ✅ No network requests are made (launcher respects force_offline)

**Pass Criteria:**
- Sealed archive is portable and functional across different paths
- Offline enforcement is maintained
- No assumption about external resources

**If test fails:**
- Check that tool paths in sealed archive are correctly resolved
- Verify ogs_config.json with force_offline=true was copied into sealed archive
- Confirm path resolution works with relative paths in sealed context

---

### Installed Test 7: Network Isolation Verification (Optional Advanced)

**Objective:** Verify that no external network calls are made when offline mode is active (requires network monitoring).

**Prerequisite:**
- Network monitoring tool available (e.g., Wireshark, ProcessMonitor, or router logs)
- Sealed project loaded (with force_offline=true)

**Steps:**
1. Start network monitor to capture outbound connections from launcher
2. With sealed project loaded and force_offline=true:
   - Click "Launch" to attempt launching a tool (should be prevented)
   - Try to click any online-only button (if exists)
   - Navigate to Tools page and verify download buttons are disabled
3. Check network monitor for any external connections initiated by launcher

**Expected Results:**
- ✅ No outbound network connections are initiated by launcher.exe
- ✅ All network-dependent features are disabled or error gracefully
- ✅ No DNS lookups to external hosts

**Pass Criteria:**
- Launcher successfully enforces air-gap at network level
- Complies with sovereign/SIPR environment requirements

**If test fails:**
- Check OfflineEnforcer._set_offline() properly sets OGS_OFFLINE environment variable
- Verify SocketBlocker.open_tcp_client() denies all non-localhost connections
- Ensure no hardcoded HTTP requests are being made without offline check

---

## Summary: Installed-Build Testing Checklist

After completing Installed Tests 1-7, fill in this table:

| Test | Status | Notes | Blockers |
|------|--------|-------|----------|
| 1: Export & First Launch | ✅/⚠️/❌ | | |
| 2: Load sample_project | ✅/⚠️/❌ | | |
| 3: Settings Persistence | ✅/⚠️/❌ | | |
| 4: Per-Tool Download | ✅/⚠️/❌ | | |
| 5: Seal for Delivery | ✅/⚠️/❌ | | |
| 6: Sealed Archive Portability | ✅/⚠️/❌ | | |
| 7: Network Isolation | ✅/⚠️/❌ | Optional | |

---

### Console Debugging (Both Modes)

**In Editor Mode:**
- Check Godot Output panel (View → Output in editor)
- Look for SCRIPT ERROR, Parse Error, or Compile Error messages
- Expected (ignore): "ERROR: Parse JSON failed" during validation tests

**In Installed Mode:**
- Launcher writes logs to: `%LOCALAPPDATA%/OGS/logs/ogs_launcher.log`
- Check this file for structured JSON logs after each test
- Look for error entries with "error_code" or "error_message" fields

**Common Diagnostic Checks:**
```
# Check if library directories exist:
dir %LOCALAPPDATA%\OGS\Library\

# Check if settings persisted:
type %LOCALAPPDATA%\OGS\ogs_launcher_settings.json

# Check latest logs:
type %LOCALAPPDATA%\OGS\logs\ogs_launcher.log | findstr "error\|ERROR"
```

---

## Reporting Test Results

After each editor test, provide:
1. **Test number and name**
2. **Pass/Fail/Partial** status
3. **Observations** — what actually happened
4. **Blockers** — did this prevent the next test?
5. **Console output** — any errors seen

Example:
```
**Editor Test 2: Load sample_project — PASS ✅**

Observations:
- Project loaded successfully
- Tools list shows godot and blender correctly
- Missing tools show ⚠️ yellow warning indicators
- Seal button disabled with correct tooltip

Blockers: None
Console: No errors
```

After completing all editor tests, move to installed-build testing with same reporting format.

---

# PART C: RELEASE & CI WORKFLOW TESTING

## Release Test 1: Local Release Packaging & Smoke Check

**Objective:** Verify that the release packaging script runs deterministically locally, produces the expected directory structure, stamps Windows executable metadata, and calculates valid SHA-256 checksums.

**Prerequisites:**
- Godot 4.7.2 executable available in PATH or default install path
- `rcedit-x64.exe` available at `C:\Tools\rcedit-x64.exe`
- Passing test suite

**Steps:**
1. Open PowerShell at the repository root
2. Run packaging smoke check:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\release\build_release_package.ps1 -Version 0.0.0-smoke -SkipTests -SkipZip
   ```
3. Inspect the staging directory at `artifacts/release/OGS-Launcher-win64-0.0.0-smoke/`
4. Verify executable metadata:
   ```powershell
   $exe = "artifacts/release/OGS-Launcher-win64-0.0.0-smoke/OGS-Launcher.exe"
   (Get-Item $exe).VersionInfo | Format-List FileVersion, ProductVersion, CompanyName, ProductName, FileDescription
   ```
5. Run full packaging with ZIP and checksum generation:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\release\build_release_package.ps1 -Version 0.0.0-smoke -SkipTests
   ```
6. Verify checksum calculation:
   ```powershell
   $zip = "artifacts/release/OGS-Launcher-win64-0.0.0-smoke.zip"
   $sha = "artifacts/release/OGS-Launcher-win64-0.0.0-smoke.zip.sha256"
   $calcHash = (Get-FileHash -Path $zip -Algorithm SHA256).Hash.ToLower()
   $savedHash = (Get-Content $sha -Raw).Trim()
   Write-Host "Calculated: $calcHash"
   Write-Host "Saved:      $savedHash"
   ```

**Expected Results:**
- ✅ Script exits with exit code 0
- ✅ Staging directory contains `OGS-Launcher.exe`, `OGS-Launcher.pck`, and `README.txt`
- ✅ FileVersion is stamped as `0.0.0-smoke` and CompanyName as `Open Game Stack`
- ✅ Stamped `Images/logo.ico` icon is embedded in `OGS-Launcher.exe`
- ✅ Checksum file contains the exact lowercase SHA-256 hash matching the ZIP file

---

## Release Test 2: GitHub Actions Automated Release Dispatch

**Objective:** Verify that `.github/workflows/release.yml` triggers via workflow_dispatch, validates input, executes build and tests, tags the commit, and publishes the release.

**Prerequisites:**
- Remote `main` branch clean and passing CI
- GitHub CLI (`gh`) authenticated with repository write access
- Target semantic version (e.g., `0.1.6`) does not match an existing tag

**Steps:**
1. Ensure working directory is clean and up to date with `origin/main`
2. Verify latest CI run on `main` passed:
   ```powershell
   gh run list --workflow=ci.yml --branch=main --limit=1
   ```
3. Dispatch the release workflow:
   ```powershell
   gh workflow run release.yml -f version=<version> --ref main
   ```
4. Monitor the workflow execution:
   ```powershell
   gh run list --workflow=release.yml --limit=1
   gh run watch <run_id>
   ```
5. When complete, inspect the published release:
   ```powershell
   gh release view v<version> --json tagName,name,isPrerelease,assets
   ```

**Expected Results:**
- ✅ `build-win64` job succeeds: executes headless tests, exports release binary, patches metadata, and uploads artifacts
- ✅ `publish-release` job succeeds: tags `v<version>`, creates standard Latest release (not prerelease), attaches ZIP and SHA-256 assets, and includes SHA-256 checksum in release description
- ✅ No duplicate releases or orphan tags created on build failure

---

## Future Enhancement Areas (Not Tested Yet)

- Integration with Git LFS for tool distribution
- Hardened Godot build verification
- RMF evidence generation and audit logs
- Multi-project library management (when multiple projects use same tools)
- Custom tool addition (beyond standard profile)
- Tool version upgrade workflows

---

Last updated: **October 31, 2026** (Added CI and automated release packaging verification scenarios)

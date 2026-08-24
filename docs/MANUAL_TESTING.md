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
- ✅ All page buttons visible in sidebar (Projects, Engine, Tools, Settings)
- ✅ Projects page is default/active
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

### Editor Test 2: Projects Page — Add sample_project (Development)

**Objective:** Verify that adding a development project to the Project Library shows missing tools with visual indicators and click-through navigation.

**Steps:**
1. Close onboarding wizard (if still visible)
2. On Projects page, click **"Add Project"**
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

### Editor Test 3: Projects Page — Add sample_project_sealed (Sealed/Air-Gapped)

**Objective:** Verify that sealed projects display offline enforcement and expected UI state even with missing tools.

**Steps:**
1. On Projects page, click **"Add Project"**
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
6. Watch progress bar as tool downloads/installs to `%LOCALAPPDATA%\OGS\Library\`
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
- ✅ Progress bar appears showing download percentage
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

## Summary: Editor Testing Checklist

After completing Editor Tests 1-8, fill in this table:

| Test | Status | Notes | Blockers |
|------|--------|-------|----------|
| 1: Startup & Onboarding | ✅/⚠️/❌ | | |
| 2: Load sample_project | ✅/⚠️/❌ | | |
| 3: Load sample_project_sealed | ✅/⚠️/❌ | | |
| 4: Mirror Config UI | ✅/⚠️/❌ | | |
| 5: Remote Repo Config | ✅/⚠️/❌ | | |
| 6: Seal Button States | ✅/⚠️/❌ | | |
| 7: Per-Tool Download Workflow | ✅/⚠️/❌ | | |
| 8: Seal Button & Real Seal | ✅/⚠️/❌ | | |
| 9: Offline Tool Launch | ✅/⚠️/❌ | | |

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

## Future Enhancement Areas (Not Tested Yet)

- Integration with Git LFS for tool distribution
- Hardened Godot build verification
- RMF evidence generation and audit logs
- Multi-project library management (when multiple projects use same tools)
- Custom tool addition (beyond standard profile)
- Tool version upgrade workflows

---

Last updated: **February 21, 2026** (Complete restructure: editor vs. installed testing, comprehensive scenarios)

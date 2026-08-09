extends Control

const MirrorPathResolverScript = preload("res://scripts/mirror/mirror_path_resolver.gd")
const DEFAULT_REMOTE_REPO_URL := "https://raw.githubusercontent.com/OpenGameStack-Launcher/ogs-frozen-stacks/main/repository.json"
const LayoutControllerScript = preload("res://scripts/launcher/layout_controller.gd")
const ProjectsControllerScript = preload("res://scripts/projects/projects_controller.gd")
const SealControllerScript = preload("res://scripts/launcher/seal_controller.gd")
const ToolsControllerScript = preload("res://scripts/tools/tools_controller.gd")
const ProgressControllerScript = preload("res://scripts/tools/progress_controller.gd")
const OnboardingWizardScript = preload("res://scripts/onboarding/onboarding_wizard.gd")


# -- PRELOAD REFERENCES --
# These allow us to talk to the nodes we created in the editor
@onready var page_projects = $AppLayout/Content/PageProjects
@onready var page_tools = $AppLayout/Content/PageTools
@onready var page_settings = $AppLayout/Content/PageSettings

@onready var btn_projects = $AppLayout/Sidebar/VBoxContainer/BtnProjects
@onready var btn_tools = $AppLayout/Sidebar/VBoxContainer/BtnTools
@onready var btn_settings = $AppLayout/Sidebar/VBoxContainer/BtnSettings

# Tools page UI nodes
@onready var tools_toolbar = $AppLayout/Content/PageTools/ToolsToolbar
@onready var tools_refresh_button = $AppLayout/Content/PageTools/ToolsToolbar/RefreshButton
@onready var tools_status_label = $AppLayout/Content/PageTools/ToolsStatusLabel
@onready var tools_offline_message = $AppLayout/Content/PageTools/OfflineMessage
@onready var tools_tabs = $AppLayout/Content/PageTools/ToolsTabs

# Installed tab containers
@onready var installed_engine_tools = $AppLayout/Content/PageTools/ToolsTabs/Installed/InstalledContent/EngineSection/EngineTools
@onready var installed_2d_tools = $AppLayout/Content/PageTools/ToolsTabs/Installed/InstalledContent/"2DSection"/"2DTools"
@onready var installed_3d_tools = $AppLayout/Content/PageTools/ToolsTabs/Installed/InstalledContent/"3DSection"/"3DTools"
@onready var installed_audio_tools = $AppLayout/Content/PageTools/ToolsTabs/Installed/InstalledContent/AudioSection/AudioTools

# Download tab containers
@onready var download_engine_tools = $AppLayout/Content/PageTools/ToolsTabs/Download/DownloadContent/EngineSection/EngineTools
@onready var download_2d_tools = $AppLayout/Content/PageTools/ToolsTabs/Download/DownloadContent/"2DSection"/"2DTools"
@onready var download_3d_tools = $AppLayout/Content/PageTools/ToolsTabs/Download/DownloadContent/"3DSection"/"3DTools"
@onready var download_audio_tools = $AppLayout/Content/PageTools/ToolsTabs/Download/DownloadContent/AudioSection/AudioTools

@onready var btn_add_project = $AppLayout/Content/PageProjects/ProjectsControls/AddButton
@onready var btn_new_project = $AppLayout/Content/PageProjects/ProjectsControls/NewProjectButton
@onready var projects_list = $AppLayout/Content/PageProjects/ProjectsList
@onready var lbl_project_status = $AppLayout/Content/PageProjects/ProjectsStatusLabel
@onready var lbl_offline_status = $AppLayout/Content/PageProjects/OfflineStatusLabel
@onready var tools_list = $AppLayout/Content/PageProjects/ToolsList
@onready var btn_add_tool = $AppLayout/Content/PageProjects/ToolControlsContainer/ToolActionRow/AddToolButton
@onready var btn_remove_tool = $AppLayout/Content/PageProjects/ToolControlsContainer/ToolActionRow/RemoveToolButton
@onready var btn_launch_tool = $AppLayout/Content/PageProjects/ToolControlsContainer/ToolActionRow/LaunchButton
@onready var btn_remove_project = $AppLayout/Content/PageProjects/ToolControlsContainer/ProjectActionRow/RemoveButton
@onready var btn_seal_for_delivery = $AppLayout/Content/PageProjects/ToolControlsContainer/ProjectActionRow/SealButton
@onready var project_dir_dialog = $ProjectDirDialog
@onready var remove_project_dialog = $RemoveProjectDialog
@onready var new_project_dialog = $NewProjectDialog
@onready var new_project_name_line_edit = $NewProjectDialog/VBoxContainer/ProjectNameLineEdit
@onready var add_tool_dialog = $AddToolDialog
@onready var add_tool_option_list = $AddToolDialog/VBoxContainer/ToolOptionList

# Onboarding dialog
@onready var onboarding_dialog = $OnboardingWizardDialog

# Seal dialog nodes
@onready var seal_dialog = $SealDialog
@onready var seal_status_label = $SealDialog/VBoxContainer/StatusLabel
@onready var seal_output_label = $SealDialog/VBoxContainer/OutputLabel
@onready var seal_open_folder_button = $SealDialog/VBoxContainer/OpenFolderButton

# Settings nodes
@onready var mirror_root_path = $AppLayout/Content/PageSettings/MirrorRootContainer/MirrorRootPath
@onready var mirror_root_browse_button = $AppLayout/Content/PageSettings/MirrorRootContainer/MirrorRootBrowseButton
@onready var mirror_root_reset_button = $AppLayout/Content/PageSettings/MirrorRootContainer/MirrorRootResetButton
@onready var mirror_repo_path = $AppLayout/Content/PageSettings/MirrorRepoContainer/MirrorRepoPath
@onready var mirror_repo_clear_button = $AppLayout/Content/PageSettings/MirrorRepoContainer/MirrorRepoClearButton
@onready var mirror_status_label = $AppLayout/Content/PageSettings/MirrorStatusLabel

var network_ui_nodes: Array = []

var projects_controller
var layout_controller: LayoutController
var seal_controller: SealController
var tools_controller: ToolsController
var progress_controller: ProgressController
var onboarding_wizard: OnboardingWizard
var mirror_root_override: String = ""
var mirror_repository_url: String = ""
var settings_file_path: String = ""
var tool_cards: Dictionary = {}  # {"tool_id_version": {panel, button, progress_bar}}
var requested_tool_key: String = ""

## Resolves the base OGS data directory.
func _resolve_ogs_root_path() -> String:
	"""Returns the OGS root path, preferring LOCALAPPDATA on Windows."""
	var local_app_data = OS.get_environment("LOCALAPPDATA")
	if not local_app_data.is_empty():
		return local_app_data.path_join("OGS")
	return OS.get_user_data_dir().path_join("OGS")

func _ready():
	Logger.enable_console(true)
	Logger.set_level(Logger.Level.DEBUG)
	Logger.info("launcher_started", {"component": "app"})
	
	# Set up onboarding wizard for first-run experience
	var ogs_root_path = _resolve_ogs_root_path()
	var library_root_path = ogs_root_path.path_join("Library")
	onboarding_wizard = OnboardingWizardScript.new()
	onboarding_wizard.setup(get_tree(), library_root_path, onboarding_dialog, ogs_root_path)
	onboarding_wizard.wizard_completed.connect(_on_wizard_completed)
	
	# Show wizard on first run
	var should_show = onboarding_wizard.should_show_wizard()
	Logger.debug("onboarding_check", {"component": "onboarding", "should_show": should_show})
	if should_show:
		onboarding_wizard.show_wizard()
	
	# Set up layout controller for page navigation
	layout_controller = LayoutControllerScript.new()
	layout_controller.setup(
		btn_projects,
		btn_tools,
		btn_settings,
		page_projects,
		page_tools,
		page_settings
	)
	layout_controller.page_changed.connect(_on_page_changed)

	# Load mirror settings BEFORE setting up controllers
	# so that remote repository URL is available
	settings_file_path = OS.get_user_data_dir().path_join("ogs_launcher_settings.json")
	_load_mirror_settings()

	# Set up tools controller FIRST (needed by ProjectsController)
	var repo_url = mirror_repository_url if not mirror_repository_url.is_empty() else DEFAULT_REMOTE_REPO_URL
	tools_controller = ToolsControllerScript.new(get_tree(), repo_url)
	tools_controller.tool_list_updated.connect(_on_tools_list_updated)
	tools_controller.tool_list_refresh_failed.connect(_on_tools_refresh_failed)
	tools_controller.tool_download_started.connect(_on_tool_download_started)
	tools_controller.tool_download_complete.connect(_on_tool_download_complete)
	tools_controller.tool_download_progress.connect(_on_tool_download_progress)
	tools_controller.connectivity_checked.connect(_on_connectivity_checked)
	tools_refresh_button.pressed.connect(_on_tools_refresh_pressed)
	
	# Set up progress controller for download tracking
	progress_controller = ProgressControllerScript.new()
	progress_controller.progress_completed.connect(_on_progress_completed)
	progress_controller.progress_cancelled.connect(_on_progress_cancelled)

	# Projects page controller (now ToolsController is available to pass)
	projects_controller = ProjectsControllerScript.new()
	projects_controller.setup(
		btn_add_project,
		btn_new_project,
		projects_list,
		lbl_project_status,
		lbl_offline_status,
		tools_list,
		btn_add_tool,
		btn_remove_tool,
		btn_remove_project,
		btn_launch_tool,
		project_dir_dialog,
		remove_project_dialog,
		new_project_dialog,
		new_project_name_line_edit,
		add_tool_dialog,
		add_tool_option_list,
		tools_controller
	)
	projects_controller.offline_state_changed.connect(_on_offline_state_changed)
	projects_controller.tool_view_requested.connect(_on_tool_view_requested)
	projects_controller.environment_incomplete.connect(_on_environment_incomplete)
	projects_controller.environment_ready.connect(_on_environment_ready)
	
	# Set up seal controller for seal dialog
	seal_controller = SealControllerScript.new()
	seal_controller.setup(
		seal_dialog,
		seal_status_label,
		seal_output_label,
		seal_open_folder_button
	)
	seal_controller.seal_completed.connect(_on_seal_completed)
	
	# Wire seal button
	btn_seal_for_delivery.pressed.connect(_on_seal_button_pressed)

	# Wire settings UI controls for mirror configuration
	mirror_root_path.text_changed.connect(_on_mirror_root_text_changed)
	mirror_root_browse_button.pressed.connect(_on_mirror_root_browse_pressed)
	mirror_root_reset_button.pressed.connect(_on_mirror_root_reset_pressed)
	mirror_repo_path.text_changed.connect(_on_mirror_repo_text_changed)
	mirror_repo_clear_button.pressed.connect(_on_mirror_repo_clear_pressed)
	_update_mirror_status()
	
	# Initial tools refresh will happen when user navigates to tools page
	layout_controller.page_changed.connect(_on_layout_page_changed)

	_collect_network_ui_nodes()
	_apply_offline_ui(false)
	_on_environment_ready()
	
	# Start on the Projects page
	layout_controller.navigate_to("projects")
	
	# Show onboarding wizard if first run
	if onboarding_wizard.should_show_wizard():
		onboarding_wizard.show_wizard()

func _on_page_changed(page_name: String) -> void:
	"""Called when LayoutController changes pages."""
	_on_layout_page_changed(page_name)

func _collect_network_ui_nodes() -> void:
	"""Collects all UI nodes tagged as network-related."""
	var found: Array = []
	if is_inside_tree():
		found = get_tree().get_nodes_in_group("network_ui")
	# Fallback to metadata scan to catch nodes without group tags.
	var meta_found = _collect_network_ui_nodes_from(self)
	for node in meta_found:
		if not found.has(node):
			found.append(node)
	network_ui_nodes = found

func _collect_network_ui_nodes_from(root: Node) -> Array:
	"""Collects tagged nodes when the scene is not in a tree."""
	var found: Array = []
	if root.has_meta("network_ui") and root.get_meta("network_ui") == true:
		found.append(root)
	for child in root.get_children():
		found.append_array(_collect_network_ui_nodes_from(child))
	return found

func _on_offline_state_changed(active: bool, _reason: String) -> void:
	"""Disables network-related UI when offline is active."""
	_apply_offline_ui(active)

func _apply_offline_ui(active: bool) -> void:
	"""Applies offline UI state to tagged controls."""
	for node in network_ui_nodes:
		if node is BaseButton:
			var button := node as BaseButton
			button.disabled = active
			button.tooltip_text = "Disabled in offline mode." if active else ""

## Signal handler: environment is incomplete.
func _on_environment_incomplete(_missing_tools: Array) -> void:
	"""Disables seal when required tools are missing."""
	btn_seal_for_delivery.disabled = true
	btn_seal_for_delivery.tooltip_text = "Install missing tools from the Tools page before sealing."

## Signal handler: environment is complete.
func _on_environment_ready() -> void:
	"""Re-enables seal when all required tools are available."""
	btn_seal_for_delivery.disabled = false
	btn_seal_for_delivery.tooltip_text = ""

## Signal handler: seal for delivery button pressed.
func _on_seal_button_pressed() -> void:
	"""User clicked the 'Seal for Delivery' button."""
	var current_project_path = projects_controller.current_project_dir
	seal_controller.seal_for_delivery(current_project_path)

## Signal handler: seal operation completed.
func _on_seal_completed(_success: bool, _zip_path: String) -> void:
	"""Seal controller finished sealing project."""
	# SealController handles all UI updates
	# This is just a notification point for future extensions
	pass

## Signal handler: user clicked a tool in Projects page that needs downloading.
func _on_tool_view_requested(tool_id: String, tool_version: String) -> void:
	"""Navigate to Tools page and focus requested tool in Download tab."""
	requested_tool_key = "%s_%s" % [tool_id, tool_version]
	layout_controller.navigate_to("tools")
	if tools_tabs != null:
		tools_tabs.current_tab = 1
	_focus_requested_tool_card()
	Logger.info("tool_view_requested", {
		"component": "projects",
		"tool_id": tool_id,
		"version": tool_version
	})

## Focuses requested tool card on the Tools page when available.
func _focus_requested_tool_card() -> void:
	"""Attempts to focus the requested tool's action button in Download tab."""
	if requested_tool_key.is_empty():
		return

	var card_data = tool_cards.get(requested_tool_key)
	if card_data == null:
		return

	if tools_tabs != null:
		tools_tabs.current_tab = 1

	var button = card_data.get("button")
	if button != null:
		button.grab_focus()

	requested_tool_key = ""

## Settings Methods

## Loads the mirror root setting from disk.
func _load_mirror_settings() -> void:
	"""Loads saved mirror settings from the settings file."""
	if FileAccess.file_exists(settings_file_path):
		var file = FileAccess.open(settings_file_path, FileAccess.READ)
		if file != null:
			var json_text = file.get_as_text()
			if not json_text.strip_edges().is_empty():
				var parser = JSON.new()
				var parse_err = parser.parse(json_text)
				var data = parser.data
				if parse_err == OK and typeof(data) == TYPE_DICTIONARY:
					mirror_root_override = String(data.get("mirror_root", ""))
					if data.has("remote_repository_url"):
						mirror_repository_url = String(data.get("remote_repository_url", ""))
					else:
						mirror_repository_url = DEFAULT_REMOTE_REPO_URL
					mirror_root_path.text = mirror_root_override
					mirror_repo_path.text = mirror_repository_url
					return
	# No saved setting found, use defaults
	mirror_root_override = ""
	mirror_repository_url = DEFAULT_REMOTE_REPO_URL
	mirror_root_path.text = ""
	mirror_repo_path.text = mirror_repository_url

## Saves the mirror root setting to disk.
func _save_mirror_settings() -> void:
	"""Saves the current mirror settings to disk."""
	var data = {
		"mirror_root": mirror_root_override,
		"remote_repository_url": mirror_repository_url,
		"timestamp": Time.get_ticks_msec()
	}
	var json_text = JSON.stringify(data)
	var file = FileAccess.open(settings_file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(json_text)
		Logger.info("mirror_settings_saved", {"component": "settings"})

## Called when mirror root text changes.
func _on_mirror_root_text_changed(new_text: String) -> void:
	"""Updates mirror root override when text changes."""
	mirror_root_override = new_text
	_save_mirror_settings()
	_update_mirror_status()

## Called when browse button is pressed.
func _on_mirror_root_browse_pressed() -> void:
	"""Opens file dialog to select mirror root directory."""
	var dialog = FileDialog.new()
	dialog.title = "Select Mirror Root Directory"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.dir_selected.connect(func(path: String):
		mirror_root_override = path
		mirror_root_path.text = path
		_save_mirror_settings()
		_update_mirror_status()
	)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)

## Called when reset button is pressed.
func _on_mirror_root_reset_pressed() -> void:
	"""Resets mirror root to default."""
	mirror_root_override = ""
	mirror_root_path.text = ""
	_save_mirror_settings()
	_update_mirror_status()

## Called when mirror repository URL text changes.
func _on_mirror_repo_text_changed(new_text: String) -> void:
	"""Updates remote repository URL when text changes."""
	mirror_repository_url = new_text.strip_edges()
	_save_mirror_settings()
	_update_mirror_status()

## Called when mirror repository URL reset button is pressed.
func _on_mirror_repo_clear_pressed() -> void:
	"""Resets the remote repository URL setting to the default."""
	mirror_repository_url = DEFAULT_REMOTE_REPO_URL
	mirror_repo_path.text = mirror_repository_url
	_save_mirror_settings()
	_update_mirror_status()

## Updates the mirror status indicator.
func _update_mirror_status() -> void:
	"""Updates the mirror status label based on current settings."""
	var resolver = MirrorPathResolverScript.new()
	var effective_root = mirror_root_override if not mirror_root_override.is_empty() else resolver.get_mirror_root()
	var has_local_repo = false
	if not effective_root.is_empty() and DirAccess.dir_exists_absolute(effective_root):
		var repo_path = effective_root.path_join("repository.json")
		has_local_repo = FileAccess.file_exists(repo_path)

	if has_local_repo:
		mirror_status_label.text = "Mirror status: Local mirror ready"
		mirror_status_label.modulate = Color.GREEN
		return

	if not mirror_repository_url.is_empty():
		mirror_status_label.text = "Mirror status: Remote repository configured"
		mirror_status_label.modulate = Color(0.3, 0.6, 1.0, 1.0)
		return

	if mirror_root_override.is_empty():
		mirror_status_label.text = "Mirror status: Using default location"
		mirror_status_label.modulate = Color.GRAY
		return

	if DirAccess.dir_exists_absolute(mirror_root_override):
		mirror_status_label.text = "Mirror status: Directory exists, but repository.json not found"
		mirror_status_label.modulate = Color.YELLOW
		return

	mirror_status_label.text = "Mirror status: Directory does not exist"
	mirror_status_label.modulate = Color.RED

## Signal handler: onboarding wizard completed.
func _on_wizard_completed(success: bool, message: String) -> void:
	"""Called when onboarding wizard completes."""
	if success:
		Logger.info("wizard_startup_complete", {"component": "onboarding", "message": message})
	else:
		Logger.warn("wizard_startup_failed", {"component": "onboarding", "message": message})

##============================================================
## TOOLS PAGE HANDLERS
##============================================================

## Signal handler: page navigation changed.
func _on_layout_page_changed(page_name: String) -> void:
	"""Refreshes tools list when navigating to tools page."""
	if page_name == "tools" and tools_controller != null:
		# Check connectivity first
		tools_controller.check_connectivity()
		
		if not tools_controller.has_repository_data():
			tools_controller.refresh_tool_list()

## Signal handler: connectivity check completed.
func _on_connectivity_checked(is_online: bool) -> void:
	"""Updates status label based on connectivity."""
	_update_tools_connectivity_status(is_online)

## Updates Tools status label to Online/Offline only.
func _update_tools_connectivity_status(is_online: bool) -> void:
	"""Updates connection status display and visibility of offline messaging.
	
	Changes status label text, color, and offline warning visibility based on
	current connectivity state. Logs when status changes to aid in debugging
	connectivity issues.
	"""
	if is_online:
		tools_status_label.text = "Status: Online ✓"
		tools_status_label.modulate = Color.GREEN
		tools_offline_message.visible = false
		Logger.debug("tools_connectivity_status_updated", {
			"component": "tools",
			"is_online": true
		})
	else:
		tools_status_label.text = "Status: Offline ⚠️"
		tools_status_label.modulate = Color(1, 0.6, 0.2, 1)
		tools_offline_message.visible = true
		Logger.info("tools_connectivity_status_updated", {
			"component": "tools",
			"is_online": false
		})

## Signal handler: tools refresh button pressed.
func _on_tools_refresh_pressed() -> void:
	"""Manually refreshes the tools list."""
	if tools_controller != null:
		tools_controller.refresh_tool_list()

## Signal handler: tools list updated successfully.
func _on_tools_list_updated() -> void:
	"""Repopulates UI when tools data is refreshed."""
	Logger.info("tools_list_refresh_completed", {
		"component": "tools"
	})
	_update_tools_connectivity_status(tools_controller.is_online())
	_populate_tools_ui()
	if projects_controller != null:
		projects_controller.refresh_project_tools_state()

## Signal handler: tools refresh failed.
func _on_tools_refresh_failed(_error_message: String) -> void:
	"""Handles refresh failure and updates status display."""
	Logger.warn("tools_list_refresh_failed", {
		"component": "tools",
		"error": _error_message
	})
	_update_tools_connectivity_status(tools_controller.is_online())
	# Keep offline message synced with connectivity only

## Signal handler: tool download completed.
func _on_tool_download_complete(tool_id: String, version: String, success: bool) -> void:
	"""Refreshes UI after tool download and completes progress tracking."""
	if success:
		Logger.info("tool_download_complete_ui", {
			"component": "tools",
			"tool_id": tool_id,
			"version": version
		})
		# Complete progress tracking
		if progress_controller != null:
			progress_controller.complete_progress(tool_id, version)
		
		_populate_tools_ui()  # Refresh to move tool from Download to Installed
		if projects_controller != null:
			projects_controller.refresh_project_tools_state()
	else:
		# On failure, cancel progress tracking
		if progress_controller != null:
			progress_controller.cancel_progress(tool_id, version)
	
	_update_tools_connectivity_status(tools_controller.is_online())
	_update_download_button_states()

## Signal handler: tool install started (after download).
func _on_tool_download_started(tool_id: String, version: String) -> void:
	"""Transitions progress to install phase.
	
	Delegates to ProgressController to show indeterminate progress
	while installation proceeds. This occurs after download completes but
	before installation finishes.
	"""
	if progress_controller != null:
		progress_controller.set_install_phase(tool_id, version)
		
	Logger.info("tool_install_phase_started", {
		"component": "tools",
		"tool_id": tool_id,
		"version": version
	})

## Signal handler: tool download progress updated.
func _on_tool_download_progress(tool_id: String, version: String, bytes_downloaded: int, total_bytes: int) -> void:
	"""Delegates progress updates to ProgressController."""
	if progress_controller != null:
		progress_controller.update_progress(tool_id, version, bytes_downloaded, total_bytes)

## Populates the tools UI with categorized tools.
func _populate_tools_ui() -> void:
	"""Refreshes tool card UI from controller data.
	Builds cards for installed and available tools, organized by category.
	Clears existing cards, recategorizes tools, and updates button states.
	"""
	if tools_controller == null:
		return
	
	# Clear existing tool cards and tracking
	tool_cards.clear()
	_clear_tool_containers()
	
	var categorized_tools = tools_controller.get_categorized_tools()
	var total_installed = 0
	var total_available = 0
	
	# Populate each category
	for category in categorized_tools.keys():
		var tools = categorized_tools[category]
		if tools.is_empty():
			continue
		
		for tool in tools:
			if tool["installed"]:
				total_installed += 1
				_add_tool_card_to_category(category, tool, true)
			else:
				total_available += 1
				_add_tool_card_to_category(category, tool, false)

	_update_download_button_states()
	_focus_requested_tool_card()
	
	Logger.info("tools_ui_populated", {
		"component": "tools",
		"total_installed": total_installed,
		"total_available": total_available,
		"categories": categorized_tools.keys().size()
	})

## Clears all tool card containers.
func _clear_tool_containers() -> void:
	"""Removes all existing tool cards from UI containers.
	Queues each container's children for deletion to reset tool display.
	"""
	var cleared_count = 0
	for container in [
		installed_engine_tools, installed_2d_tools, installed_3d_tools, installed_audio_tools,
		download_engine_tools, download_2d_tools, download_3d_tools, download_audio_tools
	]:
		if container != null:
			var children_count = container.get_children().size()
			cleared_count += children_count
			for child in container.get_children():
				child.queue_free()
	
	if cleared_count > 0:
		Logger.debug("tool_containers_cleared", {
			"component": "tools",
			"cleared_cards": cleared_count
		})

## Adds a tool card to the appropriate category container.
func _add_tool_card_to_category(category: String, tool: Dictionary, is_installed: bool) -> void:
	"""Creates and adds a tool card to a category section.
	
	Parameters:
	  category (String): "Engine", "2D", "3D", or "Audio"
	  tool (Dictionary): Tool data from controller containing id, version, size_bytes
	  is_installed (bool): True for installed section, False for available/download section
	"""
	var container: VBoxContainer = null
	
	# Determine which container to use
	if is_installed:
		match category:
			"Engine": container = installed_engine_tools
			"2D": container = installed_2d_tools
			"3D": container = installed_3d_tools
			"Audio": container = installed_audio_tools
	else:
		match category:
			"Engine": container = download_engine_tools
			"2D": container = download_2d_tools
			"3D": container = download_3d_tools
			"Audio": container = download_audio_tools
	
	if container == null:
		return
	
	# Create tool card
	var card = _create_tool_card(tool, is_installed)
	container.add_child(card)
	
	Logger.debug("tool_card_added", {
		"component": "tools",
		"tool_id": tool.get("id", "unknown"),
		"category": category,
		"section": "installed" if is_installed else "available"
	})

## Creates a tool card UI element.
func _create_tool_card(tool: Dictionary, is_installed: bool) -> PanelContainer:
	"""Builds a tool card panel with metadata, action button, and progress tracking.
	
	Constructs a PanelContainer containing tool name/version/size info on top,
	with an action button (Download/Cancel/Installed) and optional progress bar.
	Progress bars are only added for non-installed tools and tracked for updates.
	
	Parameters:
	  tool (Dictionary): Tool data with id, version, size_bytes, installed flag
	  is_installed (bool): True for installed tools, False for available tools
	  
	Returns:
	  PanelContainer: The tool card UI element with embedded button and progress tracking
	"""
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 80)
	
	var main_vbox = VBoxContainer.new()
	card.add_child(main_vbox)
	
	# Top row: Tool info and button
	var hbox = HBoxContainer.new()
	main_vbox.add_child(hbox)
	
	# Tool info section
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	# Tool name and version
	var name_label = Label.new()
	name_label.text = "%s %s" % [tool["id"].capitalize(), tool["version"]]
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)
	
	# Size info
	var size_label = Label.new()
	if tool.get("size_bytes", 0) > 0:
		var size_mb = tool["size_bytes"] / (1024.0 * 1024.0)
		size_label.text = "Size: %.1f MB" % size_mb
		size_label.modulate = Color(0.7, 0.7, 0.7, 1.0)
	vbox.add_child(size_label)
	
	# Action button
	var button = Button.new()
	if is_installed:
		button.text = "Installed ✓"
		button.disabled = true
	else:
		# Check if currently downloading
		var is_downloading = tools_controller.is_downloading(tool["id"], tool["version"])
		if is_downloading:
			button.text = "Cancel"
			button.pressed.connect(_on_cancel_tool_download.bind(tool["id"], tool["version"]))
		else:
			button.text = "Download"
			button.pressed.connect(_on_download_tool_pressed.bind(tool["id"], tool["version"]))
	
	hbox.add_child(button)
	
	# Progress bar (initially hidden, shown during download)
	var progress_container = HBoxContainer.new()
	progress_container.visible = false
	main_vbox.add_child(progress_container)
	
	var tool_progress_bar = ProgressBar.new()
	tool_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tool_progress_bar.show_percentage = false
	progress_container.add_child(tool_progress_bar)
	
	var progress_label = Label.new()
	progress_label.text = "0 / 0 MB"
	progress_label.custom_minimum_size = Vector2(100, 0)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_container.add_child(progress_label)
	
	# Store card references for progress updates
	if not is_installed:
		var key = "%s_%s" % [tool["id"], tool["version"]]
		tool_cards[key] = {
			"panel": card,
			"button": button,
			"tool_id": tool["id"],
			"version": tool["version"],
			"progress_bar": tool_progress_bar,
			"progress_label": progress_label,
			"progress_container": progress_container,
			"phase": "download"
		}
		
		# Register progress tracking with ProgressController
		if progress_controller != null:
			progress_controller.track_inline_progress(
				tool["id"],
				tool["version"],
				tool_progress_bar,
				progress_label,
				progress_container
			)
		
		# Show progress if already downloading
		var is_downloading = tools_controller.is_downloading(tool["id"], tool["version"])
		if is_downloading:
			progress_container.visible = true
			Logger.debug("tool_card_created_with_download", {
				"component": "tools",
				"tool_id": tool["id"],
				"version": tool["version"],
				"size_mb": tool.get("size_bytes", 0) / (1024.0 * 1024.0)
			})
		else:
			Logger.debug("tool_card_created", {
				"component": "tools",
				"tool_id": tool["id"],
				"version": tool["version"],
				"size_mb": tool.get("size_bytes", 0) / (1024.0 * 1024.0)
			})
	else:
		Logger.debug("tool_card_created_installed", {
			"component": "tools",
			"tool_id": tool["id"],
			"version": tool["version"]
		})
	
	return card

## Signal handler: download tool button pressed.
func _on_download_tool_pressed(tool_id: String, version: String) -> void:
	"""Initiates tool download."""
	Logger.info("tool_download_initiated", {
		"component": "tools",
		"tool_id": tool_id,
		"version": version
	})
	
	if tools_controller != null:
		tools_controller.download_tool(tool_id, version)
		_update_tools_connectivity_status(tools_controller.is_online())
		_update_download_button_states()
		
		# Update the button to Cancel and show progress bar
		var key = "%s_%s" % [tool_id, version]
		var card_data = tool_cards.get(key)
		if card_data != null:
			var button = card_data.get("button")
			var progress_container = card_data.get("progress_container")
			
			if button != null:
				button.text = "Cancel"
				# Disconnect old signal and connect cancel handler
				for connection in button.pressed.get_connections():
					button.pressed.disconnect(connection["callable"])
				button.pressed.connect(_on_cancel_tool_download.bind(tool_id, version))
			
			if progress_container != null:
				progress_container.visible = true

## Signal handler: cancel tool download button pressed.
func _on_cancel_tool_download(tool_id: String, version: String) -> void:
	"""Cancels an ongoing tool download."""
	Logger.info("tool_download_cancel_requested", {
		"component": "tools",
		"tool_id": tool_id,
		"version": version
	})
	
	if tools_controller != null:
		tools_controller.cancel_download(tool_id, version)
		_update_tools_connectivity_status(tools_controller.is_online())
		
		# Cancel progress tracking
		if progress_controller != null:
			progress_controller.cancel_progress(tool_id, version)
		
		# Refresh UI to reset button state
		_populate_tools_ui()

## Signal handler: progress completed.
func _on_progress_completed(tool_id: String, version: String) -> void:
	"""Called when ProgressController marks operation as complete."""
	Logger.debug("progress_completed", {
		"component": "tools",
		"tool_id": tool_id,
		"version": version
	})

## Signal handler: progress cancelled.
func _on_progress_cancelled(tool_id: String, version: String) -> void:
	"""Called when ProgressController cancels operation."""
	Logger.debug("progress_cancelled", {
		"component": "tools",
		"tool_id": tool_id,
		"version": version
	})

## Updates download button states based on active downloads.
func _update_download_button_states() -> void:
	"""Manages button states during concurrent operations.
	
	Disables all non-active download buttons while a tool is downloading,
	and updates button text/tooltips to reflect download/cancel states.
	Ensures only one tool can download at a time.
	"""
	if tools_controller == null:
		return
	
	var any_active = tools_controller.has_active_downloads()
	var updated_count = 0
	
	for card_data in tool_cards.values():
		var button = card_data.get("button")
		if button == null:
			continue
		
		var tool_id = card_data.get("tool_id", "")
		var version = card_data.get("version", "")
		var is_active = tools_controller.is_downloading(tool_id, version)
		
		if is_active:
			button.disabled = false
			button.tooltip_text = ""
			button.text = "Cancel"
			updated_count += 1
		else:
			button.text = "Download"
			button.disabled = any_active
			button.tooltip_text = "Wait for the current download to finish." if any_active else ""
			if button.disabled:
				updated_count += 1
	
	if updated_count > 0:
		Logger.debug("download_button_states_updated", {
			"component": "tools",
			"buttons_updated": updated_count,
			"any_active_downloads": any_active
		})

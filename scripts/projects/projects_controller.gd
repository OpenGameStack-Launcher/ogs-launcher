## ProjectsController: Unity-Hub-style project library coordinator.
##
## Manages a persistent list of OGS projects, supports Add Project selection
## through FileDialog, and loads the selected project's stack/config for tool
## indicators, launch flow, and environment validation.
##
## Project Library Lifecycle:
## 1. Load persisted project index from disk on startup
## 2. Add project only when ogs_stack.json + ogs_config.json exist
## 3. Select a project from the library list to activate it
## 4. Render tool availability indicators and launch/seal readiness

extends RefCounted
class_name ProjectsController

const OgsLogger = preload("res://scripts/logging/logger.gd")
const ToolCategoryMapper = preload("res://scripts/tools/tool_category_mapper.gd")
const FileTypeMapper = preload("res://scripts/tools/file_type_mapper.gd")
const PathUtils = preload("res://scripts/utils/path_utils.gd")

## Emitted when offline state changes after loading a project or config.
signal offline_state_changed(active: bool, reason: String)

## Emitted when tools are missing from the library.
## UI can guide users to the Tools page for downloads.
signal environment_incomplete(missing_tools: Array)

## Emitted when environment is complete and ready for launch.
signal environment_ready

## Emitted when user clicks a tool to view it in Tools page.
signal tool_view_requested(tool_id: String, tool_version: String)

## Emitted when the selected project's offline policy changes.
signal project_selection_changed(project_dir: String, offline_mode: bool, force_offline: bool)

const DEFAULT_PROJECTS_INDEX_PATH := "user://ogs_projects_index.json"
const PICKER_ACTION_ADD_PROJECT := "add_project"

const TOOL_ICON_PATHS := {
	"audacity": "res://Images/tools/Audacity.png",
	"blender": "res://Images/tools/Blender.png",
	"gimp": "res://Images/tools/GIMP.png",
	"git": "res://Images/tools/Git.png",
	"godot": "res://Images/tools/Godot.png",
	"krita": "res://Images/tools/Krita.png",
	"vscodium": "res://Images/tools/VSCodium.png"
}
const TOOL_ICON_SIZE := Vector2i(20, 20)

# Semantic status colors
const COLOR_STATUS_READY := Color(0.35, 0.85, 0.55, 1.0)
const COLOR_STATUS_WARNING := Color(0.95, 0.75, 0.25, 1.0)
const COLOR_STATUS_ERROR := Color(0.95, 0.40, 0.40, 1.0)
const COLOR_STATUS_NEUTRAL := Color(0.65, 0.70, 0.78, 1.0)

# Offline pill badge colors
const COLOR_OFFLINE_ONLINE_TEXT := Color(0.70, 0.78, 0.88, 1.0)
const COLOR_OFFLINE_ONLINE_BG := Color(0.18, 0.22, 0.28, 0.7)
const COLOR_OFFLINE_ONLINE_BORDER := Color(0.28, 0.35, 0.45, 0.8)

const COLOR_OFFLINE_ENABLED_TEXT := Color(1.0, 0.85, 0.40, 1.0)
const COLOR_OFFLINE_ENABLED_BG := Color(0.35, 0.25, 0.08, 0.8)
const COLOR_OFFLINE_ENABLED_BORDER := Color(0.85, 0.65, 0.20, 0.9)

const COLOR_OFFLINE_FORCED_TEXT := Color(1.0, 0.65, 0.65, 1.0)
const COLOR_OFFLINE_FORCED_BG := Color(0.38, 0.12, 0.14, 0.85)
const COLOR_OFFLINE_FORCED_BORDER := Color(0.90, 0.30, 0.32, 0.95)

const COLOR_OFFLINE_UNKNOWN_TEXT := Color(0.60, 0.65, 0.72, 1.0)
const COLOR_OFFLINE_UNKNOWN_BG := Color(0.16, 0.18, 0.22, 0.6)
const COLOR_OFFLINE_UNKNOWN_BORDER := Color(0.26, 0.30, 0.36, 0.7)

const ProjectRegistryManagerScript = preload("res://scripts/projects/project_registry_manager.gd")
const ProjectToolManagerScript = preload("res://scripts/projects/project_tool_manager.gd")
const ProjectCreationDialogControllerScript = preload("res://scripts/projects/project_creation_dialog.gd")
const RemoteProjectDialogControllerScript = preload("res://scripts/projects/remote_project_dialog.gd")

var registry_manager: ProjectRegistryManager
var tool_manager: ProjectToolManager
var creation_dialog: ProjectCreationDialogController
var remote_dialog: RemoteProjectDialogController

func _init() -> void:
	registry_manager = ProjectRegistryManagerScript.new()
	tool_manager = ProjectToolManagerScript.new()
	creation_dialog = ProjectCreationDialogControllerScript.new()
	remote_dialog = RemoteProjectDialogControllerScript.new()

var btn_add_project: Button
var btn_add_remote_project: Button
var btn_new_project: Button
var projects_list: Control
var project_search_line_edit: LineEdit = null
var empty_library_state: Control = null
var empty_title_label: Label = null
var empty_message_label: Label = null
var empty_new_project_button: Button = null
var empty_add_local_button: Button = null
var empty_add_remote_button: Button = null
var empty_clear_filter_button: Button = null
var lbl_project_status: Label
var lbl_offline_status: Label
var lbl_tools_for_project: Label
var explorer_tree: Tree
var btn_new_folder: Button
var btn_new_file: Button
var new_file_dialog: ConfirmationDialog
var new_file_name_edit: LineEdit
var btn_add_tool: Button
var btn_remove_tool: Button
var btn_open_project: Button = null
var btn_remove_project: Button
var btn_seal_project: Button = null
var btn_launch_tool: Button
var project_dir_dialog: FileDialog
var remove_project_dialog: ConfirmationDialog
var new_project_dialog: ConfirmationDialog
var new_project_name_line_edit: LineEdit
var add_tool_dialog: ConfirmationDialog
var add_tool_option_list: ItemList
var project_picker_add_button: Button

var current_project_dir := ""
var current_manifest: StackManifest = null
var current_project_config: OgsConfig = null
var environment_validator: ProjectEnvironmentValidator
var tools_controller: ToolsController
var projects_tabs: TabContainer
var project_details_tabs: TabContainer = null
var toolchain_header_label: Label = null
var project_tools_list: ItemList
var btn_change_version: Button
var btn_explorer_launch_tool: Button = null
var project_offline_mode_check_button: CheckButton = null
var project_force_offline_check_button: CheckButton = null
var project_offline_status_label: Label = null
var project_offline_mode_helper_label: Label = null
var project_force_offline_helper_label: Label = null
var _tool_availability: Dictionary = {}  # Maps {tool_id: {version: {available: bool}}}
var _icon_cache: Dictionary = {}
var _library_manager: LibraryManager = null
var _last_selected_project_path: String = ""
var _selected_project_index: int = -1
var _selected_tool_index: int = -1
var _selected_launch_target_path: String = ""
var _selected_launch_tool_id: String = ""
var _picker_state_monitoring := false
var _add_tool_candidates: Array = []
var _current_status_severity: String = "neutral"
var _current_offline_state: String = "unknown"
var _search_query: String = ""
var _filtered_indices: Array[int] = []

class UIDeps extends RefCounted:
	var btn_add_project: Button
	var btn_add_remote_project: Button = null
	var btn_new_project: Button
	var projects_list: Control
	var project_search_line_edit: LineEdit = null
	var empty_library_state: Control = null
	var empty_title_label: Label = null
	var empty_message_label: Label = null
	var empty_new_project_button: Button = null
	var empty_add_local_button: Button = null
	var empty_add_remote_button: Button = null
	var empty_clear_filter_button: Button = null
	var lbl_project_status: Label
	var lbl_offline_status: Label
	var lbl_tools_for_project: Label
	var explorer_tree: Tree
	var btn_new_folder: Button
	var btn_new_file: Button
	var new_file_dialog: ConfirmationDialog
	var new_file_name_edit: LineEdit
	var btn_add_tool: Button
	var btn_remove_tool: Button
	var btn_open_project: Button = null
	var btn_remove_project: Button
	var btn_seal_project: Button = null
	var btn_seal_for_delivery: Button = null
	var btn_launch_tool: Button
	var project_dir_dialog: FileDialog
	var remove_project_dialog: ConfirmationDialog
	var new_project_dialog: ConfirmationDialog
	var new_project_name_line_edit: LineEdit
	var add_tool_dialog: ConfirmationDialog
	var add_tool_option_list: ItemList
	var projects_tabs: TabContainer
	var project_details_tabs: TabContainer = null
	var toolchain_header_label: Label = null
	var project_tools_list: ItemList
	var btn_change_version: Button
	var btn_explorer_launch_tool: Button = null
	var btn_explorer_launch: Button = null
	var explorer_launch_button: Button = null
	var project_offline_mode_check_button: CheckButton = null
	var project_force_offline_check_button: CheckButton = null
	var project_offline_status_label: Label = null
	var project_offline_mode_helper_label: Label = null
	var project_force_offline_helper_label: Label = null
	var app_node: Node = null

func setup(deps: UIDeps, tools_ctrl: ToolsController = null) -> void:
	registry_manager.setup(self)
	tool_manager.setup(self, deps)
	creation_dialog.setup(self, deps)
	assert(deps != null, "ProjectsController.setup: deps is required")
	for dep_name in [
		"btn_add_project", "btn_new_project", "projects_list", "lbl_project_status", "lbl_offline_status",
		"btn_add_tool", "btn_remove_tool", "btn_remove_project", "btn_launch_tool",
		"project_dir_dialog", "remove_project_dialog", "new_project_dialog", "new_project_name_line_edit",
		"add_tool_dialog", "add_tool_option_list"
	]:
		assert(deps.get(dep_name) != null, "ProjectsController.setup: deps.%s is required" % dep_name)
	btn_add_project = deps.btn_add_project
	btn_add_remote_project = deps.btn_add_remote_project
	btn_new_project = deps.btn_new_project
	projects_list = deps.projects_list
	lbl_project_status = deps.lbl_project_status
	lbl_offline_status = deps.lbl_offline_status
	
	explorer_tree = deps.explorer_tree
	lbl_tools_for_project = deps.lbl_tools_for_project
	btn_new_folder = deps.btn_new_folder
	btn_new_file = deps.btn_new_file
	new_file_dialog = deps.new_file_dialog
	new_file_name_edit = deps.new_file_name_edit
	
	btn_add_tool = deps.btn_add_tool
	btn_remove_tool = deps.btn_remove_tool
	btn_open_project = deps.btn_open_project
	btn_remove_project = deps.btn_remove_project
	if deps.btn_seal_project != null:
		btn_seal_project = deps.btn_seal_project
	elif deps.btn_seal_for_delivery != null:
		btn_seal_project = deps.btn_seal_for_delivery
	btn_launch_tool = deps.btn_launch_tool
	if deps.btn_explorer_launch_tool != null:
		btn_explorer_launch_tool = deps.btn_explorer_launch_tool
	elif deps.btn_explorer_launch != null:
		btn_explorer_launch_tool = deps.btn_explorer_launch
	elif deps.explorer_launch_button != null:
		btn_explorer_launch_tool = deps.explorer_launch_button
	project_dir_dialog = deps.project_dir_dialog
	remove_project_dialog = deps.remove_project_dialog
	new_project_dialog = deps.new_project_dialog
	new_project_name_line_edit = deps.new_project_name_line_edit
	add_tool_dialog = deps.add_tool_dialog
	add_tool_option_list = deps.add_tool_option_list
	projects_tabs = deps.projects_tabs
	project_details_tabs = deps.project_details_tabs
	toolchain_header_label = deps.toolchain_header_label
	project_tools_list = deps.project_tools_list
	btn_change_version = deps.btn_change_version
	project_offline_mode_check_button = deps.project_offline_mode_check_button
	project_force_offline_check_button = deps.project_force_offline_check_button
	project_offline_status_label = deps.project_offline_status_label
	project_offline_mode_helper_label = deps.project_offline_mode_helper_label
	project_force_offline_helper_label = deps.project_force_offline_helper_label
	
	if project_offline_mode_check_button != null:
		project_offline_mode_check_button.toggled.connect(_on_project_offline_setting_toggled)
	if project_force_offline_check_button != null:
		project_force_offline_check_button.toggled.connect(_on_project_offline_setting_toggled)
	
	project_search_line_edit = deps.project_search_line_edit
	empty_library_state = deps.empty_library_state
	if empty_library_state != null:
		empty_title_label = deps.empty_title_label if deps.empty_title_label != null else empty_library_state.find_child("EmptyTitleLabel", true, false) as Label
		empty_message_label = deps.empty_message_label if deps.empty_message_label != null else empty_library_state.find_child("EmptyMessageLabel", true, false) as Label
		empty_new_project_button = deps.empty_new_project_button if deps.empty_new_project_button != null else empty_library_state.find_child("EmptyNewProjectButton", true, false) as Button
		empty_add_local_button = deps.empty_add_local_button if deps.empty_add_local_button != null else empty_library_state.find_child("EmptyAddLocalButton", true, false) as Button
		empty_add_remote_button = deps.empty_add_remote_button if deps.empty_add_remote_button != null else empty_library_state.find_child("EmptyAddRemoteButton", true, false) as Button
		empty_clear_filter_button = deps.empty_clear_filter_button if deps.empty_clear_filter_button != null else empty_library_state.find_child("EmptyClearFilterButton", true, false) as Button

	tools_controller = tools_ctrl
	if project_search_line_edit != null:
		project_search_line_edit.text_changed.connect(_on_search_text_changed)
	if empty_new_project_button != null:
		empty_new_project_button.pressed.connect(_on_new_project_pressed)
	if empty_add_local_button != null:
		empty_add_local_button.pressed.connect(_on_add_project_pressed)
	if empty_add_remote_button != null:
		empty_add_remote_button.pressed.connect(_on_add_remote_project_pressed)
	if empty_clear_filter_button != null:
		empty_clear_filter_button.pressed.connect(_on_clear_filter_pressed)
	btn_add_project.pressed.connect(_on_add_project_pressed)
	if btn_add_remote_project != null:
		btn_add_remote_project.pressed.connect(_on_add_remote_project_pressed)
	btn_new_project.pressed.connect(_on_new_project_pressed)
	btn_add_tool.pressed.connect(_on_add_tool_pressed)
	btn_remove_tool.pressed.connect(_on_remove_tool_pressed)
	if btn_change_version != null:
		btn_change_version.pressed.connect(_on_change_version_pressed)
	if btn_open_project != null:
		btn_open_project.pressed.connect(_on_open_project_pressed)
	projects_list.item_selected.connect(_on_project_selected)
	if projects_list.has_signal("item_activated"):
		projects_list.item_activated.connect(_on_project_activated)
	if project_tools_list != null:
		project_tools_list.item_selected.connect(_on_tool_item_selected)
		project_tools_list.item_activated.connect(_on_tool_item_activated)
		project_tools_list.item_clicked.connect(_on_tool_item_clicked)
		if project_tools_list.has_signal("empty_clicked"):
			project_tools_list.empty_clicked.connect(_on_tools_list_empty_clicked)
	btn_remove_project.pressed.connect(_on_remove_project_pressed)
	btn_launch_tool.pressed.connect(_on_launch_tool_pressed)
	if btn_explorer_launch_tool != null:
		btn_explorer_launch_tool.pressed.connect(_on_launch_tool_pressed)
	if project_details_tabs != null:
		project_details_tabs.tab_changed.connect(_on_project_details_tab_changed)
	remove_project_dialog.confirmed.connect(_on_remove_project_confirmed)
	new_project_dialog.confirmed.connect(_on_new_project_confirmed)
	add_tool_dialog.confirmed.connect(_on_add_tool_confirmed)
	add_tool_option_list.item_selected.connect(_on_add_tool_item_selected)
	add_tool_option_list.item_activated.connect(_on_add_tool_item_activated)
	new_project_name_line_edit.text_changed.connect(_on_new_project_name_changed)
	new_project_name_line_edit.text_submitted.connect(func(_text: String):
		_on_new_project_confirmed()
	)
	project_dir_dialog.dir_selected.connect(_on_project_dir_selected)
	project_dir_dialog.custom_action.connect(_on_project_dialog_custom_action)
	if project_dir_dialog.has_signal("selected_files_changed"):
		project_dir_dialog.connect("selected_files_changed", Callable(self, "_on_project_picker_selection_changed"))
	if project_dir_dialog.has_signal("visibility_changed"):
		project_dir_dialog.connect("visibility_changed", Callable(self, "_on_project_picker_visibility_changed"))

	project_picker_add_button = project_dir_dialog.add_button("Add Local Project", false, PICKER_ACTION_ADD_PROJECT)
	project_picker_add_button.disabled = true
	var dialog_open_button = project_dir_dialog.get_ok_button()
	if dialog_open_button != null:
		dialog_open_button.visible = false
		dialog_open_button.disabled = true
		dialog_open_button.focus_mode = Control.FOCUS_NONE
	var create_button = new_project_dialog.get_ok_button()
	if create_button != null:
		create_button.disabled = true
	project_dir_dialog.ok_button_text = "Open"
	
	# Initialize ProjectExplorer wrapper
	if explorer_tree != null:
		# Since ProjectExplorer is a new script, we can just instantiate it.
		# Note: we haven't loaded ProjectExplorer explicitly, so we use load()
		var explorer_script = load("res://scripts/projects/project_explorer.gd")
		if explorer_script != null:
			# We attach it as a property to keep it alive
			self.set_meta("project_explorer_instance", explorer_script.new(explorer_tree))
			var explorer = self.get_meta("project_explorer_instance")
			explorer.file_selected.connect(_on_explorer_file_selected)
			explorer.folder_selected.connect(_on_explorer_folder_selected)
			explorer.file_activated.connect(_on_explorer_file_activated)
		if explorer_tree.has_signal("nothing_selected"):
			explorer_tree.nothing_selected.connect(_on_explorer_nothing_selected)
			
	if btn_new_folder != null:
		btn_new_folder.pressed.connect(_on_new_folder_pressed)
	if btn_new_file != null:
		btn_new_file.pressed.connect(_on_new_file_pressed)
	if new_file_name_edit != null:
		new_file_name_edit.text_changed.connect(_on_new_file_name_changed)
		new_file_name_edit.text_submitted.connect(func(_t): _on_new_file_confirmed())
	if new_file_dialog != null:
		new_file_dialog.confirmed.connect(_on_new_file_confirmed)
		var ok_btn = new_file_dialog.get_ok_button()
		if ok_btn != null:
			ok_btn.disabled = true
	
	environment_validator = ProjectEnvironmentValidator.new()
	_library_manager = LibraryManager.new()
	
	var parent_node: Node = null
	if deps.app_node != null:
		parent_node = deps.app_node
	elif btn_add_remote_project != null and btn_add_remote_project.get_parent() != null:
		parent_node = btn_add_remote_project.get_parent()
	elif btn_add_project != null and btn_add_project.get_parent() != null:
		parent_node = btn_add_project.get_parent()
	
	if remote_dialog == null:
		remote_dialog = RemoteProjectDialogControllerScript.new()
	remote_dialog.setup(parent_node, _library_manager)
	if not remote_dialog.clone_completed.is_connected(_on_remote_clone_completed):
		remote_dialog.clone_completed.connect(_on_remote_clone_completed)
	if not remote_dialog.tool_view_requested.is_connected(_on_remote_tool_view_requested):
		remote_dialog.tool_view_requested.connect(_on_remote_tool_view_requested)
	
	_apply_offline_config(null)
	_update_offline_status(null)
	_sync_project_offline_toggles(null)

	# Initially disable launch button until a project is selected
	btn_launch_tool.disabled = true
	btn_launch_tool.text = "Select a Tool to Launch"
	btn_add_tool.disabled = true
	btn_remove_tool.disabled = true
	_disable_remove_button()

	_load_project_registry()
	_refresh_projects_list()
	
	var restored_project = false
	if not registry_manager.tracked_projects.is_empty():
		if not _last_selected_project_path.is_empty():
			var index = _find_project_index_by_path(_last_selected_project_path)
			if index != -1:
				_select_project(index)
				restored_project = true
				
	if not restored_project:
		if projects_tabs != null:
			projects_tabs.current_tab = 0 # Default to Project Library tab
		_disable_remove_button()
		if registry_manager.tracked_projects.is_empty():
			_update_status("Status: No projects added yet. Click Add Local Project to register an OGS project.")
		else:
			_update_status("Status: Select a project from the library.")

func _on_new_project_pressed():
	creation_dialog._on_new_project_pressed()
func _on_new_project_name_changed(t: String):
	creation_dialog._on_new_project_name_changed(t)
func _on_new_project_confirmed():
	creation_dialog._on_new_project_confirmed()
func _on_change_version_pressed():
	tool_manager._on_change_version_pressed()

func _on_add_remote_project_pressed() -> void:
	## Handles Add Remote Project button press.
	if OfflineEnforcer.is_offline():
		_update_status("Status: Remote project operations are blocked in offline mode.")
		return
	var primary_root: String = ""
	if registry_manager != null:
		primary_root = registry_manager.get_primary_projects_folder()
	if remote_dialog != null:
		remote_dialog.open(primary_root)

func _on_remote_clone_completed(cloned_dir: String) -> void:
	## Registers newly cloned repository into project library and selects it.
	add_project_from_path(cloned_dir)

func _on_remote_tool_view_requested(tool_id: String, tool_version: String) -> void:
	## Forwards tool view navigation request to main application.
	tool_view_requested.emit(tool_id, tool_version)

func cleanup() -> void:
	## Cleans up active child processes, dialogs, and worker threads on application shutdown.
	if remote_dialog != null:
		remote_dialog.free_nodes()
func _on_add_tool_pressed(title_override: String = "Add Tool"):
	tool_manager._on_add_tool_pressed(title_override)
func _on_add_tool_item_selected(index: int):
	tool_manager._on_add_tool_item_selected(index)
func _on_add_tool_item_activated(index: int):
	tool_manager._on_add_tool_item_activated(index)
func _on_add_tool_confirmed():
	tool_manager._on_add_tool_confirmed()
func add_tool_to_current_project(tool_id: String, version: String) -> bool:
	return tool_manager.add_tool_to_current_project(tool_id, version)
func _on_remove_tool_pressed():
	tool_manager._on_remove_tool_pressed()
func remove_tool_at_index(index: int) -> bool:
	return tool_manager.remove_tool_at_index(index)
func _on_remove_project_pressed() -> void:
	## Shows confirmation dialog before removing selected project from library.
	if _selected_project_index < 0 or _selected_project_index >= registry_manager.tracked_projects.size():
		_update_status("Status: Select a project before removing.")
		_disable_remove_button()
		return

	var entry: Dictionary = registry_manager.tracked_projects[_selected_project_index]
	var stack_name = String(entry.get("stack_name", "Unnamed Stack"))
	remove_project_dialog.dialog_text = "Remove '%s' from the Project Library?\nThis does not delete project files from disk." % stack_name
	if remove_project_dialog.is_inside_tree():
		remove_project_dialog.size = Vector2i(420, 150)
		remove_project_dialog.popup_centered(Vector2i(420, 150))

func _on_remove_project_confirmed() -> void:
	## Removes selected project after user confirms removal intent.
	_remove_project_at_index(_selected_project_index)

func _remove_project_at_index(index: int) -> void:
	## Removes a tracked project entry and persists updated project registry.
## 
## Parameters:
## index (int): Index in tracked projects to remove
## 
	if index < 0 or index >= registry_manager.tracked_projects.size():
		return

	var removed_entry: Dictionary = registry_manager.tracked_projects[index]
	var removed_name = String(removed_entry.get("stack_name", "Unnamed Stack"))
	var removed_path = String(removed_entry.get("path", ""))
	
	if _last_selected_project_path == removed_path:
		_last_selected_project_path = ""
		
	registry_manager.tracked_projects.remove_at(index)
	_save_project_registry()
	_refresh_projects_list()

	if registry_manager.tracked_projects.is_empty():
		if lbl_tools_for_project:
			lbl_tools_for_project.text = "Project Explorer"
			lbl_tools_for_project.tooltip_text = ""
		if projects_tabs != null:
			projects_tabs.set_tab_title(1, "Project Details")
		current_project_dir = ""
		_disable_launch_button()
		_disable_remove_button()
		_apply_offline_config(null)
		_update_offline_status(null)
		_update_status("Status: Removed '%s'. Project Library is now empty." % removed_name)
		OgsLogger.info("project_removed", {
			"component": "projects",
			"stack_name": removed_name,
			"remaining_projects": 0
		})
		return

	if not _filtered_indices.is_empty():
		var next_orig_index: int = _filtered_indices[0]
		for f_idx in _filtered_indices:
			if f_idx >= index:
				next_orig_index = f_idx
				break
		_select_project(next_orig_index)
	else:
		_selected_project_index = -1
		_disable_remove_button()

	_update_status("Status: Removed '%s' from Project Library." % removed_name)
	OgsLogger.info("project_removed", {
		"component": "projects",
		"stack_name": removed_name,
		"remaining_projects": registry_manager.tracked_projects.size()
	})

func set_projects_index_path_for_tests(p: String):
	registry_manager.set_projects_index_path_for_tests(p)
func set_projects_root_path_for_tests(p: String):
	registry_manager.set_projects_root_path_for_tests(p)
func get_primary_projects_folder() -> String:
	## Returns active primary projects folder.
	return registry_manager.get_primary_projects_folder()
func set_settings_controller(settings_ctrl: SettingsController) -> void:
	## Links SettingsController with project registry manager.
	registry_manager.set_settings_controller(settings_ctrl)
func _create_new_project_from_name(project_name: String) -> bool:
	if creation_dialog != null:
		return creation_dialog._create_new_project_from_name(project_name)
	return false
func _on_add_project_pressed() -> void:
	## Opens folder picker and primes Add Project button state.
	project_dir_dialog.popup_centered_ratio(0.65)
	_update_add_project_button_state(_get_picker_selected_dir())
	_start_project_picker_state_monitoring()

func _on_project_dir_selected(dir_path: String) -> void:
	## Refreshes picker Add Project enablement when folder context changes.
	_update_add_project_button_state(dir_path)

func _on_project_picker_selection_changed() -> void:
	## Updates Add Project button after folder-picker selection changes.
	_update_add_project_button_state(_get_picker_selected_dir())

func _on_project_picker_visibility_changed() -> void:
	## Re-evaluates picker action buttons whenever dialog visibility toggles.
	if project_dir_dialog.visible:
		_update_add_project_button_state(_get_picker_selected_dir())
		_start_project_picker_state_monitoring()

func _start_project_picker_state_monitoring() -> void:
	## Starts lightweight polling while picker is visible to keep button state accurate.
## 
## Godot FileDialog does not emit a reliable signal for every directory navigation
## event in open-dir mode. Polling current_dir while visible ensures Add Project
## reflects the active folder immediately.
## 
	if _picker_state_monitoring:
		return
	_picker_state_monitoring = true
	_monitor_project_picker_state()

func _monitor_project_picker_state() -> void:
	## Polls FileDialog current folder while visible and refreshes Add Project state.
	while project_dir_dialog != null and project_dir_dialog.visible:
		_update_add_project_button_state(_get_picker_selected_dir())
		var tree = project_dir_dialog.get_tree()
		if tree == null:
			break
		await tree.create_timer(0.12).timeout
	_picker_state_monitoring = false

func _on_project_dialog_custom_action(action: String) -> void:
	## Handles custom FileDialog actions, including Add Project registration.
## 
## Parameters:
## action (String): Custom action key emitted by FileDialog
## 
	if action != PICKER_ACTION_ADD_PROJECT:
		return

	var selected_dir = _get_picker_selected_dir()
	if not _is_addable_project_dir(selected_dir):
		_update_status("Status: Add Local Project requires ogs_stack.json in the selected folder.")
		OgsLogger.warn("project_add_rejected", {
			"component": "projects",
			"reason": "missing_required_files"
		})
		_update_add_project_button_state(selected_dir)
		return

	add_project_from_path(selected_dir)
	project_dir_dialog.hide()

func add_project_from_path(project_dir: String) -> bool:
	## Adds a project directory to the persistent project library.
## 
## Parameters:
## project_dir (String): Candidate project root directory
## 
## Returns:
## bool: True if project was added (or selected if duplicate), false otherwise
## 
	var normalized_dir = project_dir.strip_edges()
	if normalized_dir.is_empty():
		_update_status("Status: Select a project folder before adding.")
		OgsLogger.warn("project_add_failed", {"component": "projects", "reason": "empty_path"})
		return false

	if not _is_addable_project_dir(normalized_dir):
		_update_status("Status: Missing required file (ogs_stack.json).")
		OgsLogger.warn("project_add_failed", {
			"component": "projects",
			"reason": "missing_required_files"
		})
		return false

	var existing_index = _find_project_index_by_path(normalized_dir)
	if existing_index != -1:
		_select_project(existing_index)
		_update_status("Status: Project is already in the list. Selected existing entry.")
		OgsLogger.info("project_add_duplicate_selected", {
			"component": "projects",
			"project": normalized_dir
		})
		return true

	var manifest = _load_manifest_from_project(normalized_dir)
	if manifest == null:
		return false

	var config_path = normalized_dir.path_join("ogs_config.json")
	if not FileAccess.file_exists(config_path):
		var default_config_dict = OgsConfig.new().to_dict()
		if not registry_manager._save_json_file(config_path, default_config_dict):
			_update_status("Status: Failed to create default ogs_config.json.")
			OgsLogger.warn("project_add_failed", {
				"component": "projects",
				"reason": "config_create_failed"
			})
			return false
		OgsLogger.info("project_config_auto_generated", {
			"component": "projects"
		})

	var project_entry = {
		"path": normalized_dir,
		"stack_name": manifest.stack_name,
		"tools": manifest.tools,
		"added_at": Time.get_unix_time_from_system()
	}
	registry_manager.tracked_projects.append(project_entry)
	_save_project_registry()
	if project_search_line_edit != null and not project_search_line_edit.text.is_empty():
		project_search_line_edit.text = ""
	_search_query = ""
	_refresh_projects_list()
	_select_project(registry_manager.tracked_projects.size() - 1)

	OgsLogger.info("project_added_to_library", {
		"component": "projects",
		"stack_name": manifest.stack_name,
		"tool_count": manifest.tools.size()
	})
	return true

func _is_addable_project_dir(project_dir: String) -> bool:
	## Checks whether folder is addable by required OGS project files.
## 
## Parameters:
## project_dir (String): Directory to validate
## 
## Returns:
## bool: True when ogs_stack.json exists
## 
	if project_dir.is_empty():
		return false
	var stack_path = project_dir.path_join("ogs_stack.json")
	return FileAccess.file_exists(stack_path)

func _get_picker_selected_dir() -> String:
	## Returns current directory context from FileDialog picker safely.
	if project_dir_dialog == null:
		return ""
	return String(project_dir_dialog.current_dir)

func _update_add_project_button_state(project_dir: String) -> void:
	## Enables/disables picker Add Project action based on required files.
## 
## Parameters:
## project_dir (String): Folder currently selected in picker
## 
	if project_picker_add_button == null:
		return
	project_picker_add_button.disabled = not _is_addable_project_dir(project_dir)

func _find_project_index_by_path(path: String) -> int:
	return registry_manager.find_project_index_by_path(path)
func _load_manifest_from_project(project_dir: String) -> StackManifest:
	## Loads and validates stack manifest for a candidate project directory.
## 
## Parameters:
## project_dir (String): Project root containing ogs_stack.json
## 
## Returns:
## StackManifest: Valid manifest or null on parse/validation failure
## 
	var stack_path = project_dir.path_join("ogs_stack.json")
	var manifest = StackManifest.load_from_file(stack_path)
	if not manifest.is_valid():
		if not _is_manifest_acceptable_for_project_library(manifest):
			_update_status("Status: Cannot add project. ogs_stack.json invalid: %s" % ", ".join(manifest.errors))
			OgsLogger.warn("project_add_failed", {
				"component": "projects",
				"reason": "invalid_manifest",
				"errors": manifest.errors
			})
			return null
	if String(manifest.stack_name).strip_edges().is_empty():
		_update_status("Status: Cannot add project. ogs_stack.json missing stack_name.")
		OgsLogger.warn("project_add_failed", {
			"component": "projects",
			"reason": "missing_stack_name"
		})
		return null
	return manifest

func _is_manifest_acceptable_for_project_library(manifest: StackManifest) -> bool:
	## Determines whether manifest is acceptable for Projects Library add/select flows.
## 
## Allows one controlled exception: `tools_empty` is accepted so newly-created
## projects can start with no tools and be managed later from the Projects page.
## 
## Parameters:
## manifest (StackManifest): Parsed manifest to evaluate
## 
## Returns:
## bool: True if manifest is valid or has only tools_empty warning
## 
	if manifest.is_valid():
		return true
	return manifest.errors.size() == 1 and manifest.errors[0] == "tools_empty"

func get_filtered_indices() -> Array[int]:
	## Returns the list of tracked project indices matching current search filter.
	return _filtered_indices

func get_search_query() -> String:
	## Returns the active search filter query.
	return _search_query

func _on_search_text_changed(new_text: String) -> void:
	## Handles search query changes to filter project library entries.
	_search_query = new_text
	_refresh_projects_list()

func _on_clear_filter_pressed() -> void:
	## Clears the search filter bar and restores all tracked projects.
	if project_search_line_edit != null:
		project_search_line_edit.text = ""
	_on_search_text_changed("")

func _matches_search_filter(entry: Dictionary, query: String) -> bool:
	## Case-insensitively tests whether project matches query by stack_name, path, or tool.
	if query.is_empty():
		return true

	# Match stack / project display name
	var stack_name: String = String(entry.get("stack_name", "")).to_lower()
	if stack_name.contains(query):
		return true

	# Match file path (both raw and display format)
	var path_str: String = String(entry.get("path", "")).to_lower()
	var disp_path: String = PathUtils.format_for_display(path_str).to_lower()
	if path_str.contains(query) or disp_path.contains(query):
		return true
	if path_str.replace("\\", "/").contains(query) or path_str.replace("/", "\\").contains(query):
		return true

	# Match configured tools (tool ID or version)
	var tools: Array = entry.get("tools", [])
	for tool in tools:
		if tool is Dictionary:
			var t_dict: Dictionary = tool as Dictionary
			var tool_id: String = String(t_dict.get("id", "")).to_lower()
			var tool_ver: String = String(t_dict.get("version", "")).to_lower()
			var disp_name: String = ToolCategoryMapper.get_display_name(tool_id).to_lower()
			if tool_id.contains(query) or tool_ver.contains(query) or disp_name.contains(query):
				return true
			var combined := "%s %s" % [tool_id, tool_ver]
			var combined_disp := "%s %s" % [disp_name, tool_ver]
			if combined.contains(query) or combined_disp.contains(query):
				return true
			if ("v" + tool_ver).contains(query):
				return true

	return false

func _refresh_projects_list() -> void:
	## Rebuilds Projects list UI from persisted tracked project entries matching active search filter.
	_filtered_indices.clear()
	var query := _search_query.strip_edges().to_lower()
	for i in range(registry_manager.tracked_projects.size()):
		var entry: Dictionary = registry_manager.tracked_projects[i]
		if _matches_search_filter(entry, query):
			_filtered_indices.append(i)

	if registry_manager.tracked_projects.is_empty():
		if projects_list != null:
			projects_list.clear()
			projects_list.visible = false
		if empty_library_state != null:
			empty_library_state.visible = true
			if empty_title_label != null:
				empty_title_label.text = "No Projects Tracked"
			if empty_message_label != null:
				empty_message_label.text = "Get started by creating a new project, adding an existing local stack, or cloning a remote repository."
			if empty_new_project_button != null:
				empty_new_project_button.visible = true
			if empty_add_local_button != null:
				empty_add_local_button.visible = true
			if empty_add_remote_button != null:
				empty_add_remote_button.visible = true
			if empty_clear_filter_button != null:
				empty_clear_filter_button.visible = false
		_disable_project_action_buttons()
		return

	if _filtered_indices.is_empty():
		if projects_list != null:
			projects_list.clear()
			projects_list.visible = false
		if empty_library_state != null:
			empty_library_state.visible = true
			if empty_title_label != null:
				empty_title_label.text = "No Projects Match Filter"
			if empty_message_label != null:
				empty_message_label.text = "No projects match your filter \"%s\". Clear your search query to see all projects." % _search_query
			if empty_new_project_button != null:
				empty_new_project_button.visible = false
			if empty_add_local_button != null:
				empty_add_local_button.visible = false
			if empty_add_remote_button != null:
				empty_add_remote_button.visible = false
			if empty_clear_filter_button != null:
				empty_clear_filter_button.visible = true
		_disable_project_action_buttons()
		_update_status("Status: No projects match your filter.")
		return

	if empty_library_state != null:
		empty_library_state.visible = false
	if projects_list != null:
		projects_list.visible = true
		projects_list.clear()
		for list_idx in range(_filtered_indices.size()):
			var original_idx: int = _filtered_indices[list_idx]
			var entry: Dictionary = registry_manager.tracked_projects[original_idx]
			var display_name = String(entry.get("stack_name", "Unnamed Stack"))
			var tools: Array = entry.get("tools", [])
			var summary = _summarize_tools(tools)
			var project_path = String(entry.get("path", ""))
			var display_path: String = PathUtils.format_for_display(project_path)
			var label = "%s - %s\n%s" % [display_name, summary, display_path]
			if projects_list.has_method("add_project_card"):
				projects_list.add_project_card(display_name, summary, display_path, tools)
			else:
				projects_list.add_item(label)
			projects_list.set_item_tooltip(list_idx, display_path)

		if _selected_project_index >= 0:
			var ui_idx: int = _filtered_indices.find(_selected_project_index)
			if ui_idx != -1:
				projects_list.select(ui_idx)
				_enable_project_action_buttons()
			else:
				projects_list.deselect_all()
				_disable_project_action_buttons()
		else:
			projects_list.deselect_all()
			_disable_project_action_buttons()

func _summarize_tools(tools: Array) -> String:
	## Builds compact tool summary text for project list entries.
## 
## Parameters:
## tools (Array): Manifest tool dictionaries
## 
## Returns:
## String: Compact summary with up to two tools and total count
## 
	if tools.is_empty():
		return "No tools"

	var labels: Array[String] = []
	for tool in tools:
		if labels.size() >= 2:
			break
		var tool_id: String = String(tool.get("id", "unknown")).strip_edges()
		var tool_version: String = String(tool.get("version", "?")).strip_edges()
		var display_name: String = ToolCategoryMapper.get_display_name(tool_id)
		if tool_version.is_empty() or tool_version == "?":
			labels.append(display_name)
		else:
			labels.append("%s %s" % [display_name, tool_version])

	if tools.size() > 2:
		return "%s (+%d more)" % [", ".join(labels), tools.size() - 2]
	return ", ".join(labels)

func _on_project_selected(index: int) -> void:
	## Activates selected project entry and loads runtime state.
## 
## Parameters:
## index (int): Selected index in projects list UI
## 
	var original_index := index
	if index >= 0 and index < _filtered_indices.size():
		original_index = _filtered_indices[index]
	_select_project(original_index)

func _select_project(index: int) -> void:
	## Selects a project from tracked entries and loads its manifest/config.
## 
## Parameters:
## index (int): Index in tracked projects list
## 
	if index < 0 or index >= registry_manager.tracked_projects.size():
		return

	_selected_project_index = index
	_selected_tool_index = -1
	_selected_launch_tool_id = ""
	_selected_launch_target_path = ""
	var ui_idx: int = _filtered_indices.find(index)
	if ui_idx != -1 and projects_list != null:
		projects_list.select(ui_idx)
	elif projects_list != null:
		projects_list.deselect_all()
	_enable_remove_button()
	_update_tool_action_buttons()

	var entry: Dictionary = registry_manager.tracked_projects[index]
	var stack_name = String(entry.get("stack_name", "Selected Project"))
	
	if projects_tabs != null:
		projects_tabs.set_tab_title(1, stack_name)
		
	var project_dir = String(entry.get("path", ""))
	
	if _last_selected_project_path != project_dir:
		_last_selected_project_path = project_dir
		_save_project_registry()
	
	if lbl_tools_for_project != null:
		var display_path: String = PathUtils.format_for_display(project_dir)
		lbl_tools_for_project.text = "Project Explorer - " + display_path
		lbl_tools_for_project.tooltip_text = display_path
		
	if project_dir.is_empty():
		_update_status("Status: Selected project entry is invalid.")
		_disable_launch_for_selected_project()
		return

	if not _is_addable_project_dir(project_dir):
		current_project_config = null
		project_selection_changed.emit("", false, false)
		_update_status("Status: Selected project is missing ogs_stack.json.")
		_apply_offline_config(null)
		_update_offline_status(null)
		_sync_project_offline_toggles(null)
		_disable_launch_for_selected_project()
		OgsLogger.warn("project_select_failed", {
			"component": "projects",
			"reason": "missing_required_files"
		})
		return

	var manifest = _load_manifest_from_project(project_dir)
	if manifest == null:
		current_project_config = null
		project_selection_changed.emit("", false, false)
		_apply_offline_config(null)
		_update_offline_status(null)
		_sync_project_offline_toggles(null)
		_disable_launch_for_selected_project()
		return

	# Keep persisted entry aligned with latest manifest metadata.
	entry["stack_name"] = manifest.stack_name
	entry["tools"] = manifest.tools
	registry_manager.tracked_projects[index] = entry
	_save_project_registry()
	_refresh_projects_list()
	var ui_idx_after: int = _filtered_indices.find(index)
	if ui_idx_after != -1 and projects_list != null:
		projects_list.select(ui_idx_after)
	elif projects_list != null:
		projects_list.deselect_all()

	current_project_dir = project_dir
	current_manifest = manifest
	_populate_tools_list(manifest.tools)

	var config_path = project_dir.path_join("ogs_config.json")
	if not FileAccess.file_exists(config_path):
		var default_config_dict = OgsConfig.new().to_dict()
		if registry_manager._save_json_file(config_path, default_config_dict):
			OgsLogger.info("project_config_auto_generated", {
				"component": "projects"
			})
	var config = _load_config_if_present(config_path)
	current_project_config = config
	_apply_offline_config(config)
	_update_offline_status(config)
	_sync_project_offline_toggles(config)
	project_selection_changed.emit(project_dir, config.offline_mode, config.force_offline)

	var use_project_tools = config != null and config.force_offline
	_validate_and_report_environment(project_dir, use_project_tools)

	OgsLogger.info("project_selected", {
		"component": "projects",
		"stack_name": manifest.stack_name,
		"tool_count": manifest.tools.size()
	})

func update_current_project_offline_settings(offline_mode: bool, force_offline: bool) -> bool:
	## Persists and applies offline policy changes for the selected OGS project.
	if current_project_dir.is_empty():
		return false

	var config = _load_config_if_present(current_project_dir.path_join("ogs_config.json"))
	config.offline_mode = offline_mode
	config.force_offline = force_offline
	var file = FileAccess.open(current_project_dir.path_join("ogs_config.json"), FileAccess.WRITE)
	if file == null:
		OgsLogger.warn("project_config_write_failed", {"component": "projects"})
		return false
	file.store_string(JSON.stringify(config.to_dict()))
	file.close()

	current_project_config = config

	# Manage ogs_tools/ lifecycle based on force_offline state
	if force_offline:
		if current_manifest != null and not current_project_dir.is_empty():
			ProjectSealToolCopier.copy_tools_to_project(current_manifest, current_project_dir, _library_manager)
	else:
		if not current_project_dir.is_empty():
			var ogs_tools_dir = current_project_dir.path_join("ogs_tools")
			if DirAccess.dir_exists_absolute(ogs_tools_dir) and PathUtils.is_path_under_root(ogs_tools_dir, current_project_dir):
				_remove_dir_recursive(ogs_tools_dir)
				OgsLogger.info("ogs_tools_cleaned_up_on_force_offline_disable", {
					"component": "projects",
					"project": current_project_dir.get_file()
				})

	_apply_offline_config(config)
	_update_offline_status(config)
	_sync_project_offline_toggles(config)

	# Refresh tools list and project explorer so UI immediately reflects updated ogs_tools state
	if current_manifest != null:
		_populate_tools_list(current_manifest.tools)
	elif self.has_meta("project_explorer_instance"):
		var explorer = self.get_meta("project_explorer_instance")
		explorer.load_project(current_project_dir)

	var use_project_tools = config != null and config.force_offline
	_validate_and_report_environment(current_project_dir, use_project_tools)
	project_selection_changed.emit(current_project_dir, config.offline_mode, config.force_offline)
	OgsLogger.info("project_offline_settings_updated", {
		"component": "projects",
		"offline_mode": offline_mode,
		"force_offline": force_offline
	})
	return true

func delete_current_project_files() -> bool:
	## Safely deletes all files in the currently selected project folder from disk,
	## ensuring the path is valid and within tracked projects, and cleans up registry.
	if current_project_dir.is_empty() or _selected_project_index < 0:
		return false
	if not DirAccess.dir_exists_absolute(current_project_dir):
		return false
	_remove_dir_recursive(current_project_dir)
	_remove_project_at_index(_selected_project_index)
	return true

## Recursively deletes directory contents and directory itself.
static func _remove_dir_recursive(path: String) -> void:
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var item_path = path.path_join(name)
			if dir.current_is_dir():
				_remove_dir_recursive(item_path)
			else:
				DirAccess.remove_absolute(item_path)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)

func _on_project_offline_setting_toggled(_enabled: bool) -> void:
	## Handles user toggling either project offline policy CheckButton.
	if current_project_dir.is_empty():
		return
	var offline_val: bool = project_offline_mode_check_button.button_pressed if project_offline_mode_check_button != null else false
	var force_val: bool = project_force_offline_check_button.button_pressed if project_force_offline_check_button != null else false
	update_current_project_offline_settings(offline_val, force_val)

func _sync_project_offline_toggles(config: OgsConfig) -> void:
	## Updates the offline policy check buttons and status label from the active project config.
	var has_project: bool = not current_project_dir.is_empty() and config != null
	if project_offline_mode_check_button != null:
		project_offline_mode_check_button.disabled = not has_project
		project_offline_mode_check_button.set_pressed_no_signal(config.offline_mode if has_project else false)
	if project_force_offline_check_button != null:
		project_force_offline_check_button.disabled = not has_project
		project_force_offline_check_button.set_pressed_no_signal(config.force_offline if has_project else false)
	if project_offline_status_label != null:
		if has_project:
			project_offline_status_label.text = "Selected: %s" % PathUtils.format_for_display(current_project_dir)
		else:
			project_offline_status_label.text = "No project selected"

func _load_project_registry():
	registry_manager.load_project_registry()
func _save_project_registry():
	registry_manager.save_project_registry()
func _load_config_if_present(config_path: String) -> OgsConfig:
	## Loads ogs_config.json if present; returns a default config otherwise.
	if not FileAccess.file_exists(config_path):
		return OgsConfig.new()
	return OgsConfig.load_from_file(config_path)

## Returns the cached Texture2D icon for a tool ID, or null if not found.
func get_tool_icon(tool_id: String) -> Texture2D:
	return _get_tool_icon(tool_id)

func _get_tool_icon(tool_id: String) -> Texture2D:
	if tool_id.is_empty():
		return null
	var lower_id: String = tool_id.to_lower()
	if _icon_cache.has(lower_id):
		return _icon_cache[lower_id] as Texture2D
	if TOOL_ICON_PATHS.has(lower_id):
		var icon_path: String = TOOL_ICON_PATHS[lower_id]
		if ResourceLoader.exists(icon_path):
			var res: Resource = load(icon_path)
			if res is Texture2D:
				var tex: Texture2D = res as Texture2D
				_icon_cache[lower_id] = tex
				return tex
	_icon_cache[lower_id] = null
	return null

func _populate_tools_list(tools: Array) -> void:
	## Populates the tools list UI from the manifest tool entries.
	##
	## Adds visual icons, tooltips, and explicit status indicators:
	## - ✓ Installed: tool is installed in the local library
	## - ⚠️ Missing (Available in Tools): tool not installed but downloadable
	## - ❌ Unavailable in Repository: tool not installed and not in repository
	##
	## Updates the _tool_availability dictionary with status for each tool,
	## enabling double-click or launch navigation to download missing tools.
	##
	## Parameters:
	## tools (Array): Array of tool entries from ogs_stack.json
	_tool_availability.clear()
	_selected_tool_index = -1
	_selected_launch_tool_id = ""
	_selected_launch_target_path = ""
	_update_tool_action_buttons()
	
	var active_tool_ids: Array[String] = []
	for tool_entry: Variant in tools:
		if tool_entry is Dictionary and (tool_entry as Dictionary).has("id"):
			active_tool_ids.append(String((tool_entry as Dictionary)["id"]).to_lower())

	if explorer_tree != null and self.has_meta("project_explorer_instance"):
		var explorer = self.get_meta("project_explorer_instance")
		explorer.load_project(current_project_dir, active_tool_ids)
	
	# Build availability map from ToolsController
	var available_tools = _get_available_tools()
	var repository_known = tools_controller != null and tools_controller.has_repository_data()
	
	var missing_count = 0
	var available_count = 0
	var unknown_count = 0
	var installed_count = 0
	
	if project_tools_list != null:
		project_tools_list.clear()
		if project_tools_list.fixed_icon_size == Vector2i.ZERO:
			project_tools_list.fixed_icon_size = TOOL_ICON_SIZE

	for tool_entry in tools:
		var tool_id = String(tool_entry.get("id", "unknown"))
		var tool_version = String(tool_entry.get("version", "?"))
		var tool_path = String(tool_entry.get("path", ""))
		var display_name: String = ToolCategoryMapper.get_display_name(tool_id)
		
		# Check if tool is installed
		var is_installed: bool = _is_tool_installed(tool_entry)
		
		var availability = {"available": false, "installed": is_installed}
		
		var status_text := ""
		var tooltip_text := ""
		
		if not is_installed:
			missing_count += 1
			# Check if available in repository (only when repository data is loaded)
			if current_project_config != null and current_project_config.force_offline:
				status_text = "⚠️ Missing from ogs_tools"
				tooltip_text = "%s v%s is missing from project ogs_tools/ (force_offline enabled)." % [display_name, tool_version]
				availability["available"] = false
			elif repository_known and available_tools.has(tool_id) and available_tools[tool_id].has(tool_version):
				status_text = "⚠️ Missing (Available in Tools)"
				tooltip_text = "%s v%s is not installed. This tool can be downloaded from the Tools page." % [display_name, tool_version]
				availability["available"] = true
				available_count += 1
			elif repository_known:
				status_text = "❌ Unavailable in Repository"
				tooltip_text = "%s v%s is not installed and is not available in the active repository." % [display_name, tool_version]
				availability["available"] = false
			else:
				# Repository availability unknown yet; do not show false unavailability.
				status_text = "⚠️ Missing (Available in Tools)"
				tooltip_text = "%s v%s is not installed. This tool can be downloaded from the Tools page." % [display_name, tool_version]
				availability["available"] = true
				unknown_count += 1
		else:
			installed_count += 1
			status_text = "✓ Installed"
			if not tool_path.is_empty():
				tooltip_text = "%s v%s is installed and ready to launch.\nPath: %s" % [display_name, tool_version, tool_path]
			elif current_project_config != null and current_project_config.force_offline:
				tooltip_text = "%s v%s is installed in project ogs_tools/ (force_offline enabled)." % [display_name, tool_version]
			else:
				tooltip_text = "%s v%s is installed and ready to launch." % [display_name, tool_version]
		
		_tool_availability["%s_%s" % [tool_id, tool_version]] = availability
		
		# Build label with status indicator
		var label = "%s v%s" % [display_name, tool_version]
		if not tool_path.is_empty():
			label = "%s - %s - %s" % [label, tool_path, status_text]
		else:
			label = "%s - %s" % [label, status_text]
			
		var icon: Texture2D = _get_tool_icon(tool_id)
		if project_tools_list != null:
			var item_idx: int = project_tools_list.add_item(label, icon)
			if not tooltip_text.is_empty():
				project_tools_list.set_item_tooltip(item_idx, tooltip_text)
	
	OgsLogger.info("project_tools_list_populated", {
		"component": "projects",
		"total_tools": tools.size(),
		"installed": installed_count,
		"missing_available": available_count,
		"missing_unavailable": missing_count - available_count - unknown_count,
		"missing_unknown": unknown_count,
		"repository_known": repository_known
	})

func _get_available_tools() -> Dictionary:
	## Returns a dictionary of available (not yet installed) tools from the remote repository.
## 
## Builds a map of tools that exist in the remote ToolsController but are not
## yet installed in the local library. This is used to determine which tools
## can be downloaded vs which are completely unavailable.
## 
## Returns:
## Dictionary: {tool_id: {version: {tool_data}}, ...}
## Empty dict if ToolsController is not available
## 
	if tools_controller == null:
		OgsLogger.debug("get_available_tools_no_controller", {
			"component": "projects",
			"reason": "ToolsController not initialized"
		})
		return {}
	
	var categorized = tools_controller.get_categorized_tools()
	var available = {}
	var available_count = 0
	
	for category in categorized.keys():
		for tool in categorized[category]:
			if not tool.get("installed", false):
				var tool_id = String(tool.get("id", ""))
				var version = String(tool.get("version", ""))
				if not tool_id.is_empty() and not version.is_empty():
					if not available.has(tool_id):
						available[tool_id] = {}
					available[tool_id][version] = tool
					available_count += 1
	
	OgsLogger.debug("available_tools_scanned", {
		"component": "projects",
		"available_count": available_count,
		"unique_tools": available.size()
	})
	
	return available

func _on_tool_item_clicked(index: int, _at_position: Vector2 = Vector2.ZERO, _mouse_button_index: int = 1) -> void:
	## Handles click on a tool in the list to select it without navigating away.
	## 
	## Parameters:
	## index (int): Index in the tools list ItemList
	## _at_position (Vector2): Position of mouse click
	## _mouse_button_index (int): Mouse button index
	_on_tool_item_selected(index)

func _on_tool_item_selected(index: int) -> void:
	## Tracks selected tool index, updates action button states, and deselects explorer.
	## 
	## Parameters:
	## index (int): Selected index in tools list
	_selected_tool_index = index
	if project_tools_list != null and index >= 0 and index < project_tools_list.item_count:
		if not project_tools_list.is_selected(index):
			project_tools_list.select(index)
	if explorer_tree != null:
		explorer_tree.deselect_all()
	if current_manifest != null and index >= 0 and index < current_manifest.tools.size():
		var tool_entry: Dictionary = current_manifest.tools[index]
		_selected_launch_tool_id = String(tool_entry.get("id", ""))
		_selected_launch_target_path = ""
	else:
		_selected_launch_tool_id = ""
		_selected_launch_target_path = ""
	_update_tool_action_buttons()

func _on_tool_item_activated(index: int) -> void:
	## Handles double-click activation on a tool item in ProjectToolsList.
	## If the tool is not installed, emits tool_view_requested to navigate to the Tools page.
	## If the tool is installed, launches it.
	## 
	## Parameters:
	## index (int): Activated (double-clicked) tool index
	_on_tool_item_selected(index)
	if current_manifest != null and index >= 0 and index < current_manifest.tools.size():
		var tool_entry: Dictionary = current_manifest.tools[index]
		var tool_id = String(tool_entry.get("id", "unknown"))
		var tool_version = String(tool_entry.get("version", "?"))
		if not _is_tool_installed(tool_entry):
			if current_project_config != null and current_project_config.force_offline:
				_update_status("Status: Tool '%s' is missing from project ogs_tools/ (force_offline active)." % tool_id)
			else:
				_update_status("Status: Tool '%s' is not installed. Opening Tools page to download." % tool_id)
				_emit_tool_view_request(tool_id, tool_version)
			return
	_on_launch_tool_pressed()

func _is_tool_installed(tool_id_or_entry: Variant, tool_version: String = "") -> bool:
	## Checks whether the specified tool is installed locally (in ogs_tools/ or explicit path)
	## or in the Central Library, taking into account project force_offline enforcement.
	var tool_id := ""
	var version := ""
	var tool_path := ""

	if tool_id_or_entry is Dictionary:
		var entry: Dictionary = tool_id_or_entry as Dictionary
		tool_id = String(entry.get("id", "unknown")).strip_edges()
		version = String(entry.get("version", "?")).strip_edges()
		tool_path = String(entry.get("path", "")).strip_edges()
	else:
		tool_id = String(tool_id_or_entry).strip_edges()
		version = tool_version.strip_edges()

	var clean_version = "" if (version == "?" or version == "unknown") else version
	var is_force_offline = current_project_config != null and current_project_config.force_offline

	# If we have an active project, check local resolution first
	if not current_project_dir.is_empty():
		if not tool_path.is_empty():
			var full_path = current_project_dir.path_join(tool_path) if not tool_path.is_absolute_path() else tool_path
			if FileAccess.file_exists(full_path):
				return true
		else:
			var local_res = ToolLauncher.resolve_local_ogs_tool(current_project_dir, tool_id, clean_version)
			if local_res.get("available", false):
				return true

		# If force_offline is active, Central Library fallback is strictly blocked
		if is_force_offline:
			return false

	# Central Library check
	if _library_manager != null and _library_manager.tool_exists(tool_id, clean_version):
		return true

	var availability_key = "%s_%s" % [tool_id, version]
	if availability_key in _tool_availability:
		return bool(_tool_availability[availability_key].get("installed", false))

	return false

func _emit_tool_view_request(tool_id: String, tool_version: String) -> void:
	## Logs and emits tool_view_requested for an uninstalled tool.
	var availability_key = "%s_%s" % [tool_id, tool_version]
	var available_in_repo = false
	if availability_key in _tool_availability:
		available_in_repo = bool(_tool_availability[availability_key].get("available", false))
	OgsLogger.info("tool_view_requested_from_projects", {
		"component": "projects",
		"tool_id": tool_id,
		"version": tool_version,
		"available_in_repo": available_in_repo
	})
	tool_view_requested.emit(tool_id, tool_version)
	

func get_current_status_severity() -> String:
	## Returns the classified severity of the current status message ("ready", "warning", "error", "neutral").
	return _current_status_severity

func get_current_offline_state() -> String:
	## Returns the current offline state ("unknown", "disabled", "enabled", "forced").
	return _current_offline_state

static func _classify_status_severity(message: String) -> String:
	## Classifies a status message into a semantic severity level.
	var lower: String = message.to_lower()
	
	# Neutral / guidance prompts take precedence over generic word matches
	if lower.contains("waiting for project") or lower.contains("select a project") \
		or lower.contains("select a tool") or lower.contains("no projects added") \
		or lower.contains("enter a valid") or lower.contains("already in the list"):
		return "neutral"
		
	# Error conditions
	if lower.contains("error") or lower.contains("failed") or lower.contains("failure") \
		or lower.contains("invalid") or lower.contains("missing required") \
		or lower.contains("missing ogs_stack.json") or lower.contains("missing stack_name") \
		or lower.contains("cannot add") or lower.contains("cannot launch") \
		or lower.contains("unable to"):
		return "error"
		
	# Warning / Incomplete conditions
	if lower.contains("missing") or lower.contains("incomplete") \
		or lower.contains("not installed") or lower.contains("not in this project's stack") \
		or lower.contains("offline mode prevents") or lower.contains("no known tool") \
		or lower.contains("blocked in offline") or lower.contains("no additional tools"):
		return "warning"
		
	# Ready / Success conditions
	if lower.contains("environment ready") or lower.contains("all tools in library") \
		or lower.contains("launched ") or lower.contains("created project") \
		or lower.contains("to project stack") or lower.contains("from project library") \
		or lower.contains("library is now empty") or lower.contains("updated "):
		return "ready"
		
	return "neutral"

func _update_status(message: String, explicit_severity: String = "") -> void:
	## Updates the projects status label with semantic color modulation and severity tracking.
	if lbl_project_status == null:
		return
	lbl_project_status.text = message
	var severity: String = explicit_severity if not explicit_severity.is_empty() else _classify_status_severity(message)
	_current_status_severity = severity
	var color: Color = COLOR_STATUS_NEUTRAL
	match severity:
		"ready", "success":
			color = COLOR_STATUS_READY
		"warning", "incomplete":
			color = COLOR_STATUS_WARNING
		"error", "failure":
			color = COLOR_STATUS_ERROR
		_:
			color = COLOR_STATUS_NEUTRAL
	lbl_project_status.add_theme_color_override("font_color", color)

func _update_offline_status(config: OgsConfig) -> void:
	## Updates the offline status label based on config state, applying compact pill badge styling.
	if lbl_offline_status == null:
		return
	var text: String = ""
	var state: String = "unknown"
	var text_color: Color = COLOR_OFFLINE_UNKNOWN_TEXT
	var bg_color: Color = COLOR_OFFLINE_UNKNOWN_BG
	var border_color: Color = COLOR_OFFLINE_UNKNOWN_BORDER

	if config == null:
		text = "Offline Mode: Unknown"
		state = "unknown"
	elif config.force_offline:
		text = "Offline Mode: Forced (force_offline=true)"
		state = "forced"
		text_color = COLOR_OFFLINE_FORCED_TEXT
		bg_color = COLOR_OFFLINE_FORCED_BG
		border_color = COLOR_OFFLINE_FORCED_BORDER
	elif config.offline_mode:
		text = "Offline Mode: Enabled (offline_mode=true)"
		state = "enabled"
		text_color = COLOR_OFFLINE_ENABLED_TEXT
		bg_color = COLOR_OFFLINE_ENABLED_BG
		border_color = COLOR_OFFLINE_ENABLED_BORDER
	else:
		text = "Offline Mode: Disabled"
		state = "disabled"
		text_color = COLOR_OFFLINE_ONLINE_TEXT
		bg_color = COLOR_OFFLINE_ONLINE_BG
		border_color = COLOR_OFFLINE_ONLINE_BORDER

	_current_offline_state = state
	lbl_offline_status.text = text
	lbl_offline_status.add_theme_color_override("font_color", text_color)

	var pill: StyleBoxFlat = StyleBoxFlat.new()
	pill.bg_color = bg_color
	pill.border_color = border_color
	pill.border_width_left = 1
	pill.border_width_top = 1
	pill.border_width_right = 1
	pill.border_width_bottom = 1
	pill.corner_radius_top_left = 10
	pill.corner_radius_top_right = 10
	pill.corner_radius_bottom_left = 10
	pill.corner_radius_bottom_right = 10
	pill.content_margin_left = 10.0
	pill.content_margin_right = 10.0
	pill.content_margin_top = 3.0
	pill.content_margin_bottom = 3.0
	lbl_offline_status.add_theme_stylebox_override("normal", pill)

func _apply_offline_config(config: OgsConfig) -> void:
	## Applies offline configuration and notifies listeners.
	OfflineEnforcer.apply_config(config)
	offline_state_changed.emit(OfflineEnforcer.is_offline(), OfflineEnforcer.get_reason())

## Re-evaluates tools availability and environment for the currently loaded project.
func refresh_project_tools_state() -> void:
	## Refreshes Projects page tool indicators and readiness state.
## 
## Use this after Tools page repository updates or completed downloads so
## the Projects list indicators, status label, and seal readiness reflect
## the current library and repository state without requiring manual reload.
## 
	if current_project_dir.is_empty() or current_manifest == null:
		return
	if _selected_project_index >= 0:
		_select_project(_selected_project_index)

	OgsLogger.info("project_tools_state_refreshed", {
		"component": "projects",
		"project": current_project_dir,
		"tool_count": current_manifest.tools.size()
	})

func _on_explorer_file_selected(file_path: String, tool_id: String) -> void:
	_selected_launch_target_path = file_path
	_selected_launch_tool_id = tool_id
	if project_tools_list != null:
		project_tools_list.deselect_all()
	_selected_tool_index = -1
	btn_remove_tool.disabled = true
	_update_tool_action_buttons()

func _on_explorer_file_activated(file_path: String, tool_id: String) -> void:
	## Handles double-click activation of a file in the project explorer to launch its tool.
	_selected_launch_target_path = file_path
	_selected_launch_tool_id = tool_id
	if project_tools_list != null:
		project_tools_list.deselect_all()
	_selected_tool_index = -1
	btn_remove_tool.disabled = true
	_update_tool_action_buttons()
	_on_launch_tool_pressed()

func _on_explorer_folder_selected(folder_path: String, tool_id: String) -> void:
	_selected_launch_target_path = folder_path
	_selected_launch_tool_id = tool_id
	if project_tools_list != null:
		project_tools_list.deselect_all()
	_selected_tool_index = -1
	btn_remove_tool.disabled = true
	_update_tool_action_buttons()
	
func _on_new_folder_pressed() -> void:
	if not self.has_meta("project_explorer_instance"): return
	var explorer = self.get_meta("project_explorer_instance")
	var selected_path = explorer.get_selected_path()
	var new_dir = selected_path.path_join("New Folder")
	var count = 1
	while DirAccess.dir_exists_absolute(new_dir):
		new_dir = selected_path.path_join("New Folder (%d)" % count)
		count += 1
	DirAccess.make_dir_recursive_absolute(new_dir)
	explorer.refresh()

func _on_new_file_name_changed(new_text: String) -> void:
	## Enables create button in NewFileDialog only when file name is non-empty.
	if new_file_dialog == null:
		return
	var ok_button: Button = new_file_dialog.get_ok_button()
	if ok_button == null:
		return
	ok_button.disabled = new_text.strip_edges().is_empty()

func _is_tool_in_manifest(tool_id: String) -> bool:
	if current_manifest != null and current_manifest.tools != null:
		var lower_id = tool_id.to_lower()
		for t: Variant in current_manifest.tools:
			if t is Dictionary and String((t as Dictionary).get("id", "")).to_lower() == lower_id:
				return true
	return false

func _on_new_file_pressed() -> void:
	if new_file_name_edit != null:
		new_file_name_edit.text = ""
		_on_new_file_name_changed("")
		
		var target_subfolder := ""
		var tool_id := ""
		var inferred_ext := ""
		
		if self.has_meta("project_explorer_instance"):
			var explorer = self.get_meta("project_explorer_instance")
			var selected_path: String = explorer.get_selected_path()
			var folder_path: String = selected_path if DirAccess.dir_exists_absolute(selected_path) else selected_path.get_base_dir()
			
			if not current_project_dir.is_empty() and folder_path.begins_with(current_project_dir):
				var rel: String = folder_path.substr(current_project_dir.length()).replace("\\", "/")
				if rel.begins_with("/"):
					rel = rel.substr(1)
				if not rel.is_empty():
					if not rel.ends_with("/"):
						rel += "/"
					target_subfolder = rel
			elif not folder_path.is_empty() and folder_path != current_project_dir:
				var file_name: String = folder_path.get_file()
				if not file_name.is_empty():
					target_subfolder = file_name + "/"
			
			tool_id = explorer._infer_tool_from_folder(folder_path)
			if tool_id.is_empty():
				var check_path: String = folder_path
				while not check_path.is_empty() and check_path != current_project_dir:
					var folder_name: String = check_path.get_file().to_lower()
					if folder_name in ["models", "3d", "mesh", "meshes"]:
						tool_id = "blender"
						break
					if folder_name in ["audio", "sound", "sounds", "music"]:
						tool_id = "audacity"
						break
					if folder_name in ["textures", "sprites", "images", "2d"]:
						tool_id = "krita" if _is_tool_in_manifest("krita") else "gimp"
						break
					if folder_name in ["scripts", "src", "code"]:
						tool_id = "vscodium"
						break
					if folder_name == "game":
						tool_id = "godot"
						break
					var parent: String = check_path.get_base_dir()
					if parent == check_path:
						break
					check_path = parent
		
		if tool_id.is_empty() and not _selected_launch_tool_id.is_empty():
			tool_id = _selected_launch_tool_id
			
		var stack_has_vscodium := _is_tool_in_manifest("vscodium")
		if tool_id.is_empty() and stack_has_vscodium:
			tool_id = "vscodium"
			
		if not tool_id.is_empty():
			inferred_ext = "gd" if tool_id == "godot" else FileTypeMapper.get_extension_for_tool(tool_id)
			
		var label: Label = null
		if new_file_dialog != null:
			label = new_file_dialog.get_node_or_null("VBoxContainer/InstructionsLabel") as Label
			if label == null:
				label = new_file_dialog.find_child("InstructionsLabel", true, false) as Label
				
		if label != null:
			if not target_subfolder.is_empty() and not inferred_ext.is_empty():
				label.text = "Enter a file name (will be created as <name>.%s in %s):" % [inferred_ext, target_subfolder]
			elif not inferred_ext.is_empty():
				label.text = "Enter a file name (will be created as <name>.%s):" % inferred_ext
			elif not target_subfolder.is_empty():
				label.text = "Enter a file name (will be created in %s):" % target_subfolder
			else:
				label.text = "Enter file name. Extension will be added automatically."
				
		if new_file_dialog != null and new_file_dialog.is_inside_tree():
			new_file_dialog.size = Vector2i(420, 150)
			new_file_dialog.popup_centered(Vector2i(420, 150))
		new_file_name_edit.grab_focus()

func _on_new_file_confirmed() -> void:
	if not self.has_meta("project_explorer_instance") or new_file_name_edit == null: return
	var explorer = self.get_meta("project_explorer_instance")
	var selected_path = explorer.get_selected_path()
	var folder_path = selected_path if DirAccess.dir_exists_absolute(selected_path) else selected_path.get_base_dir()
	
	var file_name = new_file_name_edit.text.strip_edges()
	if file_name.is_empty(): return
	
	var tool_id = explorer._infer_tool_from_folder(folder_path)
	var stack_has_vscodium = false
	if current_manifest != null and current_manifest.tools != null:
		for t: Variant in current_manifest.tools:
			if t is Dictionary and String((t as Dictionary).get("id", "")).to_lower() == "vscodium":
				stack_has_vscodium = true
				break

	if tool_id.is_empty() and stack_has_vscodium:
		var file_ext = file_name.get_extension().to_lower()
		if file_ext.is_empty():
			file_name += ".txt"
			file_ext = "txt"
			tool_id = "vscodium"
		elif FileTypeMapper.is_vscodium_extension(file_ext):
			tool_id = "vscodium"
		else:
			tool_id = FileTypeMapper.get_tool_for_file(file_name)
	else:
		if tool_id.is_empty():
			var check_path: String = folder_path
			while not check_path.is_empty() and check_path != current_project_dir:
				var folder_name: String = check_path.get_file().to_lower()
				if folder_name in ["models", "3d", "mesh", "meshes"]:
					tool_id = "blender"
					break
				if folder_name in ["audio", "sound", "sounds", "music"]:
					tool_id = "audacity"
					break
				if folder_name in ["textures", "sprites", "images", "2d"]:
					tool_id = "krita" if _is_tool_in_manifest("krita") else "gimp"
					break
				if folder_name in ["scripts", "src", "code"]:
					tool_id = "vscodium"
					break
				if folder_name == "game":
					tool_id = "godot"
					break
				var parent: String = check_path.get_base_dir()
				if parent == check_path:
					break
				check_path = parent
		if not tool_id.is_empty():
			var ext = "gd" if tool_id == "godot" else FileTypeMapper.get_extension_for_tool(tool_id)
			if not ext.is_empty() and not file_name.to_lower().ends_with("." + ext):
				file_name += "." + ext
		
	var new_file_path = folder_path.path_join(file_name)
	var final_ext = file_name.get_extension().to_lower()
	var is_text = FileTypeMapper.is_vscodium_extension(final_ext)
	
	if is_text or final_ext.is_empty():
		var file = FileAccess.open(new_file_path, FileAccess.WRITE)
		if file != null:
			file.store_string("")
			file.close()
		_selected_launch_target_path = new_file_path
	else:
		# Binary tools like GIMP and Blender crash when given 0-byte files.
		# Don't pass the non-existent file path, just launch the tool empty
		_selected_launch_target_path = ""
		
	explorer.refresh()
	new_file_dialog.hide()
	
	# Launch automatically
	_selected_launch_tool_id = tool_id
	_update_tool_action_buttons()
	if not tool_id.is_empty():
		_on_launch_tool_pressed()

func _on_launch_tool_pressed() -> void:
	## Launches the currently selected tool and file from the project explorer.
	if current_manifest == null:
		_update_status("Status: No project loaded. Cannot launch tool.")
		return
	
	if _selected_launch_tool_id.is_empty():
		_update_status("Status: No tool selected or no known tool associated with this file/folder.")
		return
		
	var tool_entry = null
	var selected_index = -1
	if _selected_tool_index >= 0 and _selected_tool_index < current_manifest.tools.size():
		var candidate = current_manifest.tools[_selected_tool_index]
		if candidate.get("id") == _selected_launch_tool_id:
			tool_entry = candidate
			selected_index = _selected_tool_index
	if tool_entry == null:
		for i in range(current_manifest.tools.size()):
			if current_manifest.tools[i].get("id") == _selected_launch_tool_id:
				tool_entry = current_manifest.tools[i]
				selected_index = i
				break
			
	if tool_entry == null:
		_update_status("Status: Tool '%s' is not in this project's stack. Please add it first." % _selected_launch_tool_id)
		return

	var tool_id = String(tool_entry.get("id", "unknown"))
	var tool_version = String(tool_entry.get("version", "?"))
	if not _is_tool_installed(tool_entry):
		if current_project_config != null and current_project_config.force_offline:
			_update_status("Status: Tool '%s' is missing from project ogs_tools/ (force_offline active)." % tool_id)
		else:
			_update_status("Status: Tool '%s' is not installed. Opening Tools page to download." % tool_id)
			_emit_tool_view_request(tool_id, tool_version)
		return

	# If the target is a directory, don't pass it as a file argument. 
	# If the tool is Godot, we let ToolLauncher handle finding the project.godot
	var target_file = _selected_launch_target_path
	if DirAccess.dir_exists_absolute(target_file):
		target_file = ""

	var result = ToolLauncher.launch(tool_entry, current_project_dir, target_file)
	
	if result["success"]:
		_update_status("Status: Launched %s (PID: %d)" % [_selected_launch_tool_id, result["pid"]])
	else:
		_update_status("Status: Launch failed - %s" % result["error_message"])

func _enable_launch_button() -> void:
	## Refreshes launch button and tool action button states when a project environment is validated.
	_update_launch_button_state()
	_update_tool_action_buttons()

func _disable_launch_button() -> void:
	## Disables the launch button when no valid project is loaded.
	current_project_dir = ""
	current_manifest = null
	_selected_project_index = -1
	_selected_tool_index = -1
	_selected_launch_tool_id = ""
	_selected_launch_target_path = ""
	_update_launch_button_state()
	
	if explorer_tree != null and self.has_meta("project_explorer_instance"):
		var explorer = self.get_meta("project_explorer_instance")
		explorer.load_project("")
		
	btn_add_tool.disabled = true
	btn_remove_tool.disabled = true
	_disable_remove_button()
	_sync_project_offline_toggles(null)

func _disable_launch_for_selected_project() -> void:
	## Disables launch state while preserving selected project for safe removal.
	current_project_dir = ""
	current_manifest = null
	_selected_tool_index = -1
	_selected_launch_tool_id = ""
	_selected_launch_target_path = ""
	_update_launch_button_state()
	
	if explorer_tree != null and self.has_meta("project_explorer_instance"):
		var explorer = self.get_meta("project_explorer_instance")
		explorer.load_project("")
		
	btn_add_tool.disabled = true
	btn_remove_tool.disabled = true
	_sync_project_offline_toggles(null)
	if btn_remove_project != null:
		btn_remove_project.disabled = false
	if btn_open_project != null:
		btn_open_project.disabled = true
	if btn_seal_project != null:
		btn_seal_project.disabled = true

func _update_tool_action_buttons() -> void:
	## Updates Add/Remove Tool button enabled states for current selection context.
	var has_project = current_manifest != null and not current_project_dir.is_empty()
	if btn_add_tool != null:
		btn_add_tool.disabled = not has_project
	if btn_remove_tool != null:
		var can_remove = has_project and _selected_tool_index >= 0 and _selected_tool_index < current_manifest.tools.size()
		btn_remove_tool.disabled = not can_remove
	if btn_change_version != null:
		var can_change = has_project and _selected_tool_index >= 0 and _selected_tool_index < current_manifest.tools.size()
		btn_change_version.disabled = not can_change
	_update_launch_button_state()

func _on_project_details_tab_changed(tab_idx: int) -> void:
	## Synchronizes launch button state and active launch context when switching sub-tabs.
	if current_manifest == null or current_project_dir.is_empty():
		_selected_tool_index = -1
		_selected_launch_tool_id = ""
		_selected_launch_target_path = ""
		_update_launch_button_state()
		return

	match tab_idx:
		0:
			# Toolchain sub-tab
			var selected_items: PackedInt32Array = project_tools_list.get_selected_items() if project_tools_list != null else PackedInt32Array()
			if selected_items.size() > 0 and selected_items[0] >= 0 and selected_items[0] < current_manifest.tools.size():
				_selected_tool_index = selected_items[0]
				var tool_entry: Dictionary = current_manifest.tools[_selected_tool_index]
				_selected_launch_tool_id = String(tool_entry.get("id", ""))
				_selected_launch_target_path = ""
			else:
				_selected_tool_index = -1
				_selected_launch_tool_id = ""
				_selected_launch_target_path = ""
			_update_tool_action_buttons()
		1:
			# Explorer sub-tab
			if explorer_tree != null and explorer_tree.get_selected() != null:
				var item: TreeItem = explorer_tree.get_selected()
				var meta: Variant = item.get_metadata(0)
				if meta is Dictionary and meta.has("path"):
					var path: String = String(meta["path"])
					var is_dir: bool = bool(meta.get("is_dir", false))
					if is_dir:
						if self.has_meta("project_explorer_instance"):
							var explorer = self.get_meta("project_explorer_instance")
							_selected_launch_tool_id = explorer._infer_tool_from_folder(path)
						else:
							_selected_launch_tool_id = ""
					else:
						if self.has_meta("project_explorer_instance"):
							var explorer = self.get_meta("project_explorer_instance")
							_selected_launch_tool_id = explorer._get_tool_for_file(path)
						else:
							_selected_launch_tool_id = ""
					_selected_launch_target_path = path
				else:
					_selected_launch_tool_id = ""
					_selected_launch_target_path = ""
			else:
				_selected_launch_tool_id = ""
				_selected_launch_target_path = ""
			_update_tool_action_buttons()
		2:
			# Policy sub-tab
			_update_tool_action_buttons()

func _update_launch_button_state() -> void:
	## Updates btn_launch_tool and btn_explorer_launch_tool text and disabled state based on active selection context.
	var buttons: Array[Button] = []
	if btn_launch_tool != null:
		buttons.append(btn_launch_tool)
	if btn_explorer_launch_tool != null and btn_explorer_launch_tool != btn_launch_tool:
		buttons.append(btn_explorer_launch_tool)

	if buttons.is_empty():
		return

	if current_manifest == null or current_project_dir.is_empty() or _selected_launch_tool_id.is_empty():
		for b in buttons:
			b.text = "Select a Tool to Launch"
			b.disabled = true
		return

	if not _selected_launch_target_path.is_empty():
		var filename: String = _selected_launch_target_path.get_file()
		var tool_name: String = ToolCategoryMapper.get_display_name(_selected_launch_tool_id)
		var text: String = "Open %s in %s" % [filename, tool_name]
		for b in buttons:
			b.text = text
			b.disabled = false
	else:
		var tool_name: String = ToolCategoryMapper.get_display_name(_selected_launch_tool_id)
		var tool_version: String = ""
		if _selected_tool_index >= 0 and _selected_tool_index < current_manifest.tools.size():
			var candidate: Dictionary = current_manifest.tools[_selected_tool_index]
			if String(candidate.get("id", "")) == _selected_launch_tool_id:
				tool_version = String(candidate.get("version", "")).strip_edges()
		if tool_version.is_empty():
			for t: Variant in current_manifest.tools:
				if t is Dictionary and String((t as Dictionary).get("id", "")) == _selected_launch_tool_id:
					tool_version = String((t as Dictionary).get("version", "")).strip_edges()
					break
		var tool_display := tool_name
		if not tool_version.is_empty() and tool_version != "?":
			var v_str := tool_version if (tool_version.begins_with("v") or tool_version.begins_with("V")) else ("v" + tool_version)
			tool_display = "%s %s" % [tool_name, v_str]
		var text: String = "Launch %s" % tool_display
		for b in buttons:
			b.text = text
			b.disabled = false

func deselect_launch_target() -> void:
	## Clears active tool and file launch selections and reverts launch button to disabled.
	_selected_tool_index = -1
	_selected_launch_tool_id = ""
	_selected_launch_target_path = ""
	if project_tools_list != null:
		project_tools_list.deselect_all()
	if explorer_tree != null:
		explorer_tree.deselect_all()
	_update_tool_action_buttons()

func _on_tools_list_empty_clicked(_at_position: Vector2 = Vector2.ZERO, _mouse_button_index: int = 1) -> void:
	## Deselects any tool when clicking empty area in ProjectToolsList.
	deselect_launch_target()

func _on_explorer_nothing_selected() -> void:
	## Deselects explorer launch target when clicking empty area in ProjectExplorerTree.
	deselect_launch_target()

func _enable_project_action_buttons() -> void:
	## Enables library action buttons (Open Project, Remove Project, Seal for Delivery)
	## when a valid project entry is selected.
	if btn_open_project != null:
		btn_open_project.disabled = false
	if btn_remove_project != null:
		btn_remove_project.disabled = false
	if btn_seal_project != null:
		btn_seal_project.disabled = false

func _disable_project_action_buttons() -> void:
	## Disables library action buttons (Open Project, Remove Project, Seal for Delivery)
	## when no project is selected or the library is empty.
	if btn_open_project != null:
		btn_open_project.disabled = true
	if btn_remove_project != null:
		btn_remove_project.disabled = true
	if btn_seal_project != null:
		btn_seal_project.disabled = true

func _enable_remove_button() -> void:
	## Enables Remove Project and action buttons when a project is currently selected.
	_enable_project_action_buttons()

func _disable_remove_button() -> void:
	## Disables Remove Project and action buttons when no removable project is selected.
	_disable_project_action_buttons()

func _on_open_project_pressed() -> void:
	## Switches to Tab 1 (Project Details) when Open Project button is clicked.
	_open_selected_project_tab()

func _on_project_activated(index: int) -> void:
	## Activates a project entry on double-click, ensuring it is selected and switching to Tab 1 (Project Details).
	var original_index := index
	if index >= 0 and index < _filtered_indices.size():
		original_index = _filtered_indices[index]
	_select_project(original_index)
	_open_selected_project_tab()

func _open_selected_project_tab() -> void:
	## Switches the current tab to Tab 1 (Project Details) if a valid project is selected.
	if _selected_project_index >= 0 and _selected_project_index < registry_manager.tracked_projects.size():
		if projects_tabs != null:
			projects_tabs.current_tab = 1
		if project_details_tabs != null:
			project_details_tabs.current_tab = 0
## Validates the project environment and signals if tools are missing.
func _validate_and_report_environment(project_dir: String, use_project_tools: bool = false) -> void:
	## Checks if all required tools are available in the library.
## 
## Note: Validation is non-blocking. Launch is allowed even with missing tools,
## but a signal is emitted so UI can direct users to the Tools page.
## 
	var validation = environment_validator.validate_project(project_dir, use_project_tools)
	
	if not validation["valid"]:
		# Validation error - append to existing status
		var error_msg = ", ".join(validation["errors"])
		_update_status("Status: Manifest loaded (Environment error: %s)" % error_msg)
		OgsLogger.warn("environment_validation_error", {
			"component": "projects",
			"project": project_dir,
			"errors": validation["errors"]
		})
		_enable_launch_button()
		return
	
	# Validation successful - check if tools are ready
	if validation["ready"]:
		# Environment complete - all tools available
		_update_status("Status: Manifest loaded. Environment ready - all tools in library.")
		_enable_launch_button()
		environment_ready.emit()
		OgsLogger.info("environment_ready", {
			"component": "projects",
			"project": project_dir
		})
	else:
		# Tools are missing - but still allow launch with warning
		var tool_count = validation["missing_tools"].size()
		if OfflineEnforcer.is_offline():
			_update_status("Status: Manifest loaded (%d tool(s) missing - offline mode prevents downloads)." % tool_count)
		else:
			_update_status("Status: Manifest loaded (%d tool(s) missing - use Tools page to download)." % tool_count)
		_enable_launch_button()
		environment_incomplete.emit(validation["missing_tools"])
		OgsLogger.warn("environment_incomplete", {
			"component": "projects",
			"project": project_dir,
			"missing_count": tool_count
		})
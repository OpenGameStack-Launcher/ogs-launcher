## ProjectsController: Unity-Hub-style project library coordinator.
##
## Manages a persistent list of OGS projects, supports Add Project selection
## through FileDialog, and loads the selected project's stack/config for tool
## indicators, launch flow, and environment validation.
##
## Project Library Lifecycle:
## 1. Load persisted project index from disk on startup
## 2. Add project only when stack.json + ogs_config.json exist
## 3. Select a project from the library list to activate it
## 4. Render tool availability indicators and launch/seal readiness

extends RefCounted
class_name ProjectsController

const OgsLogger = preload("res://scripts/logging/logger.gd")

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

const ProjectRegistryManagerScript = preload("res://scripts/projects/project_registry_manager.gd")
const ProjectToolManagerScript = preload("res://scripts/projects/project_tool_manager.gd")
const ProjectCreationDialogControllerScript = preload("res://scripts/projects/project_creation_dialog.gd")

var registry_manager
var tool_manager
var creation_dialog

func _init() -> void:
	registry_manager = ProjectRegistryManagerScript.new()
	tool_manager = ProjectToolManagerScript.new()
	creation_dialog = ProjectCreationDialogControllerScript.new()

var btn_add_project: Button
var btn_new_project: Button
var projects_list: Control
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
var btn_remove_project: Button
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
var tools_controller
var projects_tabs: TabContainer
var project_tools_list: ItemList
var btn_change_version: Button
var _tool_availability: Dictionary = {}  # Maps {tool_id: {version: {available: bool}}}
var _library_manager: LibraryManager = null
var _last_selected_project_path: String = ""
var _selected_project_index: int = -1
var _selected_tool_index: int = -1
var _picker_state_monitoring := false
var _add_tool_candidates: Array = []

class UIDeps extends RefCounted:
	var btn_add_project: Button
	var btn_new_project: Button
	var projects_list: Control
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
	var btn_remove_project: Button
	var btn_launch_tool: Button
	var project_dir_dialog: FileDialog
	var remove_project_dialog: ConfirmationDialog
	var new_project_dialog: ConfirmationDialog
	var new_project_name_line_edit: LineEdit
	var add_tool_dialog: ConfirmationDialog
	var add_tool_option_list: ItemList
	var projects_tabs: TabContainer
	var project_tools_list: ItemList
	var btn_change_version: Button

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
	btn_remove_project = deps.btn_remove_project
	btn_launch_tool = deps.btn_launch_tool
	project_dir_dialog = deps.project_dir_dialog
	remove_project_dialog = deps.remove_project_dialog
	new_project_dialog = deps.new_project_dialog
	new_project_name_line_edit = deps.new_project_name_line_edit
	add_tool_dialog = deps.add_tool_dialog
	add_tool_option_list = deps.add_tool_option_list
	projects_tabs = deps.projects_tabs
	project_tools_list = deps.project_tools_list
	btn_change_version = deps.btn_change_version
	
	tools_controller = tools_ctrl
	btn_add_project.pressed.connect(_on_add_project_pressed)
	btn_new_project.pressed.connect(_on_new_project_pressed)
	btn_add_tool.pressed.connect(_on_add_tool_pressed)
	btn_remove_tool.pressed.connect(_on_remove_tool_pressed)
	if btn_change_version != null:
		btn_change_version.pressed.connect(_on_change_version_pressed)
	projects_list.item_selected.connect(_on_project_selected)
	if project_tools_list != null:
		project_tools_list.item_selected.connect(_on_tool_item_selected)
		project_tools_list.item_activated.connect(_on_tool_item_activated)
	btn_remove_project.pressed.connect(_on_remove_project_pressed)
	btn_launch_tool.pressed.connect(_on_launch_tool_pressed)
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

	project_picker_add_button = project_dir_dialog.add_button("Add Project", false, PICKER_ACTION_ADD_PROJECT)
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
			
	if btn_new_folder != null:
		btn_new_folder.pressed.connect(_on_new_folder_pressed)
	if btn_new_file != null:
		btn_new_file.pressed.connect(_on_new_file_pressed)
	if new_file_name_edit != null:
		new_file_name_edit.text_submitted.connect(func(_t): _on_new_file_confirmed())
	if new_file_dialog != null:
		new_file_dialog.confirmed.connect(_on_new_file_confirmed)
	
	environment_validator = ProjectEnvironmentValidator.new()
	_library_manager = LibraryManager.new()
	
	_apply_offline_config(null)
	_update_offline_status(null)

	# Initially disable launch button until a project is selected
	btn_launch_tool.disabled = true
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
			_update_status("Status: No projects added yet. Click Add to register an OGS project.")
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
	remove_project_dialog.popup_centered_ratio(0.4)

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

	var next_index = min(index, registry_manager.tracked_projects.size() - 1)
	_select_project(next_index)
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
		_update_status("Status: Add Project requires stack.json and ogs_config.json in the selected folder.")
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
		_update_status("Status: Missing required files (stack.json and ogs_config.json).")
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

	var project_entry = {
		"path": normalized_dir,
		"stack_name": manifest.stack_name,
		"tools": manifest.tools,
		"added_at": Time.get_unix_time_from_system()
	}
	registry_manager.tracked_projects.append(project_entry)
	_save_project_registry()
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
## bool: True when both stack.json and ogs_config.json exist
## 
	if project_dir.is_empty():
		return false
	var stack_path = project_dir.path_join("stack.json")
	var config_path = project_dir.path_join("ogs_config.json")
	return FileAccess.file_exists(stack_path) and FileAccess.file_exists(config_path)

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
## project_dir (String): Project root containing stack.json
## 
## Returns:
## StackManifest: Valid manifest or null on parse/validation failure
## 
	var stack_path = project_dir.path_join("stack.json")
	var manifest = StackManifest.load_from_file(stack_path)
	if not manifest.is_valid():
		if not _is_manifest_acceptable_for_project_library(manifest):
			_update_status("Status: Cannot add project. stack.json invalid: %s" % ", ".join(manifest.errors))
			OgsLogger.warn("project_add_failed", {
				"component": "projects",
				"reason": "invalid_manifest",
				"errors": manifest.errors
			})
			return null
	if String(manifest.stack_name).strip_edges().is_empty():
		_update_status("Status: Cannot add project. stack.json missing stack_name.")
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

func _refresh_projects_list() -> void:
	## Rebuilds Projects list UI from persisted tracked project entries.
	projects_list.clear()
	for index in range(registry_manager.tracked_projects.size()):
		var entry: Dictionary = registry_manager.tracked_projects[index]
		var display_name = String(entry.get("stack_name", "Unnamed Stack"))
		var tools: Array = entry.get("tools", [])
		var summary = _summarize_tools(tools)
		var project_path = String(entry.get("path", ""))
		var label = "%s — %s\n%s" % [display_name, summary, project_path]
		projects_list.add_item(label)
		projects_list.set_item_tooltip(index, project_path)

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
		var tool_id = String(tool.get("id", "unknown"))
		var tool_version = String(tool.get("version", "?"))
		labels.append("%s %s" % [tool_id, tool_version])

	if tools.size() > 2:
		return "%s (+%d more)" % [", ".join(labels), tools.size() - 2]
	return ", ".join(labels)

func _on_project_selected(index: int) -> void:
	## Activates selected project entry and loads runtime state.
## 
## Parameters:
## index (int): Selected index in projects list
## 
	_select_project(index)

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
	projects_list.select(index)
	_enable_remove_button()
	_update_tool_action_buttons()

	var entry: Dictionary = registry_manager.tracked_projects[index]
	var stack_name = String(entry.get("stack_name", "Selected Project"))
	
	if projects_tabs != null:
		projects_tabs.set_tab_title(1, stack_name)
		projects_tabs.current_tab = 1
		
	var project_dir = String(entry.get("path", ""))
	
	if _last_selected_project_path != project_dir:
		_last_selected_project_path = project_dir
		_save_project_registry()
	
	if lbl_tools_for_project != null:
		lbl_tools_for_project.text = "Project Explorer - " + project_dir
		
	if project_dir.is_empty():
		_update_status("Status: Selected project entry is invalid.")
		_disable_launch_for_selected_project()
		return

	if not _is_addable_project_dir(project_dir):
		current_project_config = null
		project_selection_changed.emit("", false, false)
		_update_status("Status: Selected project is missing stack.json or ogs_config.json.")
		_apply_offline_config(null)
		_update_offline_status(null)
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
		_disable_launch_for_selected_project()
		return

	# Keep persisted entry aligned with latest manifest metadata.
	entry["stack_name"] = manifest.stack_name
	entry["tools"] = manifest.tools
	registry_manager.tracked_projects[index] = entry
	_save_project_registry()
	_refresh_projects_list()
	projects_list.select(index)

	current_project_dir = project_dir
	current_manifest = manifest
	_populate_tools_list(manifest.tools)

	var config_path = project_dir.path_join("ogs_config.json")
	var config = _load_config_if_present(config_path)
	current_project_config = config
	_apply_offline_config(config)
	_update_offline_status(config)
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
	_apply_offline_config(config)
	_update_offline_status(config)
	project_selection_changed.emit(current_project_dir, config.offline_mode, config.force_offline)
	OgsLogger.info("project_offline_settings_updated", {
		"component": "projects",
		"offline_mode": offline_mode,
		"force_offline": force_offline
	})
	return true

func _load_project_registry():
	registry_manager.load_project_registry()
func _save_project_registry():
	registry_manager.save_project_registry()
func _load_config_if_present(config_path: String) -> OgsConfig:
	## Loads ogs_config.json if present; returns a default config otherwise.
	if not FileAccess.file_exists(config_path):
		return OgsConfig.new()
	return OgsConfig.load_from_file(config_path)

func _populate_tools_list(tools: Array) -> void:
	## Populates the tools list UI from the manifest tool entries.
## 
## Adds visual indicators to show tool availability status:
## - ⚠️ Yellow indicator: tool not installed but available in remote repository
## - ❌ Red indicator: tool not installed and not available anywhere
## - No indicator: tool is already installed in the library
## 
## Updates the _tool_availability dictionary with status for each tool,
## enabling click-through navigation to download missing tools.
## 
## Parameters:
## tools (Array): Array of tool entries from stack.json
## 
	_tool_availability.clear()
	_selected_tool_index = -1
	_update_tool_action_buttons()
	
	if explorer_tree != null and self.has_meta("project_explorer_instance"):
		var explorer = self.get_meta("project_explorer_instance")
		explorer.load_project(current_project_dir)
	
	# Build availability map from ToolsController
	var available_tools = _get_available_tools()
	var repository_known = tools_controller != null and tools_controller.has_repository_data()
	
	var missing_count = 0
	var available_count = 0
	var unknown_count = 0
	var installed_count = 0
	
	if project_tools_list != null:
		project_tools_list.clear()

	for tool_entry in tools:
		var tool_id = String(tool_entry.get("id", "unknown"))
		var tool_version = String(tool_entry.get("version", "?"))
		var tool_path = String(tool_entry.get("path", ""))
		
		# Check if tool is installed in library
		var is_installed = _library_manager.tool_exists(tool_id, tool_version)
		
		var availability = {"available": false, "installed": is_installed}
		
		# Build label with indicator
		var label = "%s v%s" % [tool_id, tool_version]
		var indicator = ""
		
		if not is_installed:
			missing_count += 1
			# Check if available in repository (only when repository data is loaded)
			if repository_known and available_tools.has(tool_id) and available_tools[tool_id].has(tool_version):
				indicator = " ⚠️"
				availability["available"] = true
				available_count += 1
			elif repository_known:
				indicator = " ❌"
				availability["available"] = false
			else:
				# Repository availability unknown yet; do not show false unavailability.
				indicator = " ⚠️"
				availability["available"] = true
				unknown_count += 1
		else:
			installed_count += 1
		
		_tool_availability["%s_%s" % [tool_id, tool_version]] = availability
		
		# Add tool path info if present
		if not tool_path.is_empty():
			label = "%s - %s%s" % [label, tool_path, indicator]
		else:
			label = label + indicator
			
		if project_tools_list != null:
			project_tools_list.add_item(label)
	
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

func _on_tool_item_clicked(index: int) -> void:
	## Handles click on a tool in the list to enable quick navigation.
## 
## When user clicks a tool that is not yet installed:
## 1. Logs the view request with tool context
## 2. Emits tool_view_requested signal to main.gd
## 3. UI navigates to Tools page for download
## 
## If tool is already installed, no action is taken
## (the launch button handles launching installed tools).
## 
## Parameters:
## index (int): Index in the tools list ItemList
## 
	_selected_tool_index = index
	_update_tool_action_buttons()
	if project_tools_list != null and index >= 0 and index < project_tools_list.item_count:
		project_tools_list.select(index)

	if current_manifest == null or index < 0 or index >= current_manifest.tools.size():
		OgsLogger.debug("tool_item_clicked_invalid_index", {
			"component": "projects",
			"index": index,
			"manifest_valid": current_manifest != null,
			"tools_count": current_manifest.tools.size() if current_manifest != null else 0
		})
		return
	
	var tool_entry = current_manifest.tools[index]
	var tool_id = String(tool_entry.get("id", "unknown"))
	var tool_version = String(tool_entry.get("version", "?"))
	var availability_key = "%s_%s" % [tool_id, tool_version]
	
	# Check if tool is not installed
	if availability_key in _tool_availability:
		var availability = _tool_availability[availability_key]
		if not availability["installed"]:
			OgsLogger.info("tool_view_requested_from_projects", {
				"component": "projects",
				"tool_id": tool_id,
				"version": tool_version,
				"available_in_repo": availability["available"]
			})
			tool_view_requested.emit(tool_id, tool_version)

func _on_tool_item_selected(index: int) -> void:
	## Tracks selected tool index for reliable launch button behavior.
## 
## Parameters:
## index (int): Selected index in tools list
## 
	_selected_tool_index = index
	_update_tool_action_buttons()

func _on_tool_item_activated(index: int) -> void:
	## Launches tool on double-click in tools list.
## 
## Parameters:
## index (int): Activated (double-clicked) tool index
## 
	_selected_tool_index = index
	if project_tools_list != null and index >= 0 and index < project_tools_list.item_count:
		project_tools_list.select(index)
	_on_launch_tool_pressed()
	

func _update_status(message: String) -> void:
	## Updates the projects status label.
	lbl_project_status.text = message

func _update_offline_status(config: OgsConfig) -> void:
	## Updates the offline status label based on config state.
	if config == null:
		lbl_offline_status.text = "Offline Mode: Unknown"
		return
	if config.force_offline:
		lbl_offline_status.text = "Offline Mode: Forced (force_offline=true)"
	elif config.offline_mode:
		lbl_offline_status.text = "Offline Mode: Enabled (offline_mode=true)"
	else:
		lbl_offline_status.text = "Offline Mode: Disabled"

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

var _selected_launch_target_path: String = ""
var _selected_launch_tool_id: String = ""

func _on_explorer_file_selected(file_path: String, tool_id: String) -> void:
	_selected_launch_target_path = file_path
	_selected_launch_tool_id = tool_id
	btn_remove_tool.disabled = true
	_update_tool_action_buttons()

func _on_explorer_folder_selected(folder_path: String, tool_id: String) -> void:
	_selected_launch_target_path = folder_path
	_selected_launch_tool_id = tool_id
	btn_remove_tool.disabled = tool_id.is_empty()
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

func _on_new_file_pressed() -> void:
	if new_file_name_edit != null:
		new_file_name_edit.text = ""
		new_file_dialog.popup_centered(Vector2(300, 150))
		new_file_name_edit.grab_focus()

func _on_new_file_confirmed() -> void:
	if not self.has_meta("project_explorer_instance") or new_file_name_edit == null: return
	var explorer = self.get_meta("project_explorer_instance")
	var selected_path = explorer.get_selected_path()
	var folder_path = selected_path if DirAccess.dir_exists_absolute(selected_path) else selected_path.get_base_dir()
	
	var file_name = new_file_name_edit.text.strip_edges()
	if file_name.is_empty(): return
	
	var tool_id = explorer._infer_tool_from_folder(folder_path)
	var ext = FileTypeMapper.get_extension_for_tool(tool_id)
	
	if not ext.is_empty() and not file_name.ends_with("." + ext):
		file_name += "." + ext
		
	var new_file_path = folder_path.path_join(file_name)
	
	# Binary tools like GIMP and Blender crash when given 0-byte files.
	# We only create empty text files on disk. For binary assets, we 
	# just launch the tool empty so the user can 'Save As' from the tool.
	var is_text = ext in ["txt", "json", "md", "gd"]
	
	if is_text or ext.is_empty():
		var file = FileAccess.open(new_file_path, FileAccess.WRITE)
		if file != null:
			file.store_string("")
			file.close()
		_selected_launch_target_path = new_file_path
	else:
		# Don't pass the non-existent file path, just launch the tool empty
		_selected_launch_target_path = ""
		
	explorer.refresh()
	new_file_dialog.hide()
	
	# Launch automatically
	_selected_launch_tool_id = tool_id
	if not tool_id.is_empty():
		_on_launch_tool_pressed()

func _on_launch_tool_pressed() -> void:
	## Launches the currently selected tool and file from the project explorer.
	if current_manifest == null:
		_update_status("Status: No project loaded. Cannot launch tool.")
		return
	
	if _selected_launch_tool_id.is_empty():
		_update_status("Status: No known tool associated with this file/folder.")
		return
		
	var tool_entry = null
	var selected_index = -1
	for i in range(current_manifest.tools.size()):
		if current_manifest.tools[i].get("id") == _selected_launch_tool_id:
			tool_entry = current_manifest.tools[i]
			selected_index = i
			break
			
	if tool_entry == null:
		_update_status("Status: Tool '%s' is not in this project's stack. Please add it first." % _selected_launch_tool_id)
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
	## Enables the launch button when a valid project is loaded.
	if btn_launch_tool:
		btn_launch_tool.disabled = false
	_update_tool_action_buttons()

func _disable_launch_button() -> void:
	## Disables the launch button when no valid project is loaded.
	if btn_launch_tool:
		btn_launch_tool.disabled = true
	current_project_dir = ""
	current_manifest = null
	_selected_project_index = -1
	_selected_tool_index = -1
	
	if explorer_tree != null and self.has_meta("project_explorer_instance"):
		var explorer = self.get_meta("project_explorer_instance")
		explorer.load_project("")
		
	btn_add_tool.disabled = true
	btn_remove_tool.disabled = true
	_disable_remove_button()

func _disable_launch_for_selected_project() -> void:
	## Disables launch state while preserving selected project for safe removal.
	if btn_launch_tool:
		btn_launch_tool.disabled = true
	current_project_dir = ""
	current_manifest = null
	_selected_tool_index = -1
	
	if explorer_tree != null and self.has_meta("project_explorer_instance"):
		var explorer = self.get_meta("project_explorer_instance")
		explorer.load_project("")
		
	btn_add_tool.disabled = true
	btn_remove_tool.disabled = true
	_enable_remove_button()

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

func _enable_remove_button() -> void:
	## Enables Remove Project button when a project is currently selected.
	if btn_remove_project != null:
		btn_remove_project.disabled = false

func _disable_remove_button() -> void:
	## Disables Remove Project button when no removable project is selected.
	if btn_remove_project != null:
		btn_remove_project.disabled = true
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
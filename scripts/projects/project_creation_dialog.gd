extends RefCounted
class_name ProjectCreationDialogController

const OgsLogger = preload("res://scripts/logging/logger.gd")

var _pc: ProjectsController
var _ui: ProjectsController.UIDeps

func setup(projects_controller: ProjectsController, ui_deps: ProjectsController.UIDeps) -> void:
	_pc = projects_controller
	_ui = ui_deps

func _on_new_project_pressed() -> void:
	## Shows New Project dialog for creating an empty OGS project scaffold.
	_ui.new_project_name_line_edit.text = ""
	_on_new_project_name_changed("")
	
	var label = _ui.new_project_dialog.get_node_or_null("VBoxContainer/InstructionsLabel")
	if label:
		label.text = "Enter project name. A folder will be created under:\n%s" % _pc.registry_manager._get_default_projects_dir()
		
	_ui.new_project_dialog.popup_centered_ratio(0.4)
	_ui.new_project_name_line_edit.grab_focus()

func _on_new_project_name_changed(new_text: String) -> void:
	## Enables create button only when sanitized project name is non-empty.
## 
## Parameters:
## new_text (String): User-entered project name text
## 
	var create_button = _ui.new_project_dialog.get_ok_button()
	if create_button == null:
		return
	var sanitized = _sanitize_project_name(new_text)
	create_button.disabled = sanitized.is_empty()

func _on_new_project_confirmed() -> void:
	## Creates a new project scaffold from dialog-entered project name.
	_create_new_project_from_name(_ui.new_project_name_line_edit.text)

func _create_new_project_from_name(project_name: String) -> bool:
	## Creates a new project folder plus stack/config scaffold and auto-adds it.
## 
## Parameters:
## project_name (String): Raw project name entered by user
## 
## Returns:
## bool: True when project scaffold is created and added to library
## 
	var sanitized_name = _sanitize_project_name(project_name)
	if sanitized_name.is_empty():
		_pc._update_status("Status: Enter a valid project name.")
		OgsLogger.warn("project_create_failed", {
			"component": "projects",
			"reason": "invalid_name"
		})
		return false

	var projects_root = _pc.registry_manager._resolve_ogs_projects_root_path()
	if projects_root.is_empty():
		_pc._update_status("Status: Unable to resolve OGS Projects directory.")
		OgsLogger.warn("project_create_failed", {
			"component": "projects",
			"reason": "projects_root_unresolved"
		})
		return false

	var make_root_result = DirAccess.make_dir_recursive_absolute(projects_root)
	if make_root_result != OK and not DirAccess.dir_exists_absolute(projects_root):
		_pc._update_status("Status: Failed to create OGS Projects folder.")
		OgsLogger.warn("project_create_failed", {
			"component": "projects",
			"reason": "projects_root_create_failed"
		})
		return false

	var new_project_dir = projects_root.path_join(sanitized_name)
	if DirAccess.dir_exists_absolute(new_project_dir):
		_pc._update_status("Status: Project '%s' already exists in OGS/Projects." % sanitized_name)
		OgsLogger.warn("project_create_failed", {
			"component": "projects",
			"reason": "project_folder_exists",
			"stack_name": sanitized_name
		})
		return false

	var make_project_result = DirAccess.make_dir_recursive_absolute(new_project_dir)
	if make_project_result != OK:
		_pc._update_status("Status: Failed to create project folder.")
		OgsLogger.warn("project_create_failed", {
			"component": "projects",
			"reason": "project_folder_create_failed"
		})
		return false

	var stack_payload = {
		"schema_version": StackManifest.CURRENT_SCHEMA_VERSION,
		"stack_name": sanitized_name,
		"tools": []
	}
	var config_payload = OgsConfig.new().to_dict()

	var stack_path = new_project_dir.path_join("stack.json")
	var config_path = new_project_dir.path_join("ogs_config.json")
	if not _pc.registry_manager._save_json_file(stack_path, stack_payload) or not _pc.registry_manager._save_json_file(config_path, config_payload):
		_pc._update_status("Status: Failed writing new project files.")
		OgsLogger.warn("project_create_failed", {
			"component": "projects",
			"reason": "scaffold_write_failed",
			"stack_name": sanitized_name
		})
		return false

	var add_ok = _pc.add_project_from_path(new_project_dir)
	if not add_ok:
		_pc._update_status("Status: Project created, but failed to add to Project Library.")
		OgsLogger.warn("project_create_add_failed", {
			"component": "projects",
			"stack_name": sanitized_name
		})
		return false

	_ui.new_project_dialog.hide()
	_pc._update_status("Status: Created project '%s' in OGS/Projects." % sanitized_name)
	OgsLogger.info("project_created", {
		"component": "projects",
		"stack_name": sanitized_name,
		"tools_count": 0
	})
	return true

func _sanitize_project_name(raw_name: String) -> String:
	## Normalizes project name for safe folder naming (spaces -> underscores).
## 
## Parameters:
## raw_name (String): User-entered project name
## 
## Returns:
## String: Sanitized folder-friendly project name
## 
	var trimmed = raw_name.strip_edges().replace(" ", "_")
	if trimmed.is_empty():
		return ""

	var sanitized = ""
	for character in trimmed:
		var code = character.unicode_at(0)
		var is_digit = code >= 48 and code <= 57
		var is_upper = code >= 65 and code <= 90
		var is_lower = code >= 97 and code <= 122
		var is_safe_symbol = character == "_" or character == "-"
		sanitized += character if (is_digit or is_upper or is_lower or is_safe_symbol) else "_"

	while sanitized.find("__") != -1:
		sanitized = sanitized.replace("__", "_")
	return sanitized.strip_edges().trim_prefix("_").trim_suffix("_")


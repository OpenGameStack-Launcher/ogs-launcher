## SettingsController: Manages the settings page UI and configuration.
extends RefCounted
class_name SettingsController

const MirrorPathResolverScript = preload("res://scripts/mirror/mirror_path_resolver.gd")
const OgsLogger = preload("res://scripts/logging/logger.gd")
const PathUtils = preload("res://scripts/utils/path_utils.gd")

## Emitted when the configured primary projects root path changes.
signal projects_root_changed(new_root: String)

class UIDeps extends RefCounted:
	var projects_root_path: LineEdit
	var projects_root_browse_button: Button
	var projects_root_reset_button: Button
	var mirror_root_path: LineEdit
	var mirror_repo_path: LineEdit
	var mirror_status_label: Label
	var app_node: Node # used to add file dialog to tree

var _ui: UIDeps
var _projects_controller: ProjectsController
var _default_remote_repo_url: String
var _settings_file_path: String
var projects_root_override: String = ""
var mirror_root_override: String = ""
var mirror_repository_url: String = ""

func setup(deps: UIDeps, projects_controller: ProjectsController, default_remote_repo_url: String, settings_file_path: String) -> void:
	## Initializes settings controller dependencies and loads persisted settings.
	_ui = deps
	_projects_controller = projects_controller
	_default_remote_repo_url = default_remote_repo_url
	_settings_file_path = settings_file_path
	
	_load_mirror_settings()
	update_mirror_status()

func get_projects_root() -> String:
	## Returns the custom primary projects root folder override, or empty string if using default.
	return projects_root_override

func get_primary_projects_folder() -> String:
	## Returns the active primary projects directory, resolving to default if unconfigured.
	if not projects_root_override.is_empty():
		return projects_root_override
	if _projects_controller != null and _projects_controller.registry_manager != null:
		return _projects_controller.registry_manager._get_default_projects_dir()
	var home_dir = OS.get_environment("USERPROFILE")
	if home_dir.is_empty():
		home_dir = OS.get_environment("HOME")
	if not home_dir.is_empty():
		return home_dir.path_join("OGS_Projects")
	return OS.get_user_data_dir().path_join("OGS_Projects")

func get_mirror_repository_url() -> String:
	## Returns configured mirror repo URL or default fallback.
	return mirror_repository_url if not mirror_repository_url.is_empty() else _default_remote_repo_url

func _load_mirror_settings() -> void:
	## Loads persisted launcher settings from disk and populates UI fields.
	var loaded_projects_root = ""
	var loaded_mirror_root = ""
	var loaded_mirror_repo = _default_remote_repo_url
	
	if FileAccess.file_exists(_settings_file_path):
		var file = FileAccess.open(_settings_file_path, FileAccess.READ)
		if file != null:
			var json_text = file.get_as_text()
			if not json_text.strip_edges().is_empty():
				var parser = JSON.new()
				if parser.parse(json_text) == OK and typeof(parser.data) == TYPE_DICTIONARY:
					loaded_projects_root = String(parser.data.get("projects_root", ""))
					loaded_mirror_root = String(parser.data.get("mirror_root", ""))
					loaded_mirror_repo = String(parser.data.get("remote_repository_url", _default_remote_repo_url))

	projects_root_override = loaded_projects_root
	mirror_root_override = loaded_mirror_root
	mirror_repository_url = loaded_mirror_repo
	
	if _ui != null:
		if _ui.projects_root_path != null:
			_ui.projects_root_path.text = projects_root_override
			_ui.projects_root_path.placeholder_text = PathUtils.format_for_display(get_primary_projects_folder())
		if _ui.mirror_root_path != null:
			_ui.mirror_root_path.text = mirror_root_override
		if _ui.mirror_repo_path != null:
			_ui.mirror_repo_path.text = mirror_repository_url

func save_mirror_settings() -> void:
	## Persists launcher settings to disk while preserving any existing keys.
	var data = {}
	if FileAccess.file_exists(_settings_file_path):
		var file_read = FileAccess.open(_settings_file_path, FileAccess.READ)
		if file_read != null:
			var json_text = file_read.get_as_text()
			var parser = JSON.new()
			if parser.parse(json_text) == OK and typeof(parser.data) == TYPE_DICTIONARY:
				data = parser.data

	data["projects_root"] = projects_root_override
	data["mirror_root"] = mirror_root_override
	data["remote_repository_url"] = mirror_repository_url
	data["timestamp"] = Time.get_ticks_msec()

	var file = FileAccess.open(_settings_file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		OgsLogger.info("mirror_settings_saved", {"component": "settings"})

func on_projects_root_text_changed(new_text: String) -> void:
	## Handles user typing into the primary projects root input field.
	projects_root_override = new_text.strip_edges()
	save_mirror_settings()
	projects_root_changed.emit(projects_root_override)
	OgsLogger.info("projects_root_changed", {
		"component": "settings",
		"is_custom": not projects_root_override.is_empty()
	})

func on_projects_root_browse_pressed() -> void:
	## Opens folder picker dialog to select a primary projects folder.
	var dialog = FileDialog.new()
	dialog.title = "Select Primary Projects Directory"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.dir_selected.connect(func(path: String):
		projects_root_override = path
		if _ui.projects_root_path != null:
			_ui.projects_root_path.text = path
		save_mirror_settings()
		projects_root_changed.emit(projects_root_override)
		OgsLogger.info("projects_root_changed", {
			"component": "settings",
			"is_custom": true
		})
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())
	dialog.dir_selected.connect(func(_path: String): dialog.queue_free())
	_ui.app_node.add_child(dialog)
	dialog.popup_centered_ratio(0.7)

func on_projects_root_reset_pressed() -> void:
	## Resets primary projects folder back to the default system directory.
	projects_root_override = ""
	if _ui.projects_root_path != null:
		_ui.projects_root_path.text = ""
		_ui.projects_root_path.placeholder_text = PathUtils.format_for_display(get_primary_projects_folder())
	save_mirror_settings()
	projects_root_changed.emit(projects_root_override)
	OgsLogger.info("projects_root_changed", {
		"component": "settings",
		"is_custom": false
	})

func on_mirror_root_text_changed(new_text: String) -> void:
	## Handles user typing into the mirror root path input field.
	mirror_root_override = new_text
	save_mirror_settings()
	update_mirror_status()

func on_mirror_root_browse_pressed() -> void:
	## Opens folder picker dialog to select a mirror root directory.
	var dialog = FileDialog.new()
	dialog.title = "Select Mirror Root Directory"
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.dir_selected.connect(func(path: String):
		mirror_root_override = path
		_ui.mirror_root_path.text = path
		save_mirror_settings()
		update_mirror_status()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())
	dialog.dir_selected.connect(func(_path: String): dialog.queue_free())
	_ui.app_node.add_child(dialog)
	dialog.popup_centered_ratio(0.7)

func on_mirror_root_reset_pressed() -> void:
	## Resets mirror root back to default system directory.
	mirror_root_override = ""
	_ui.mirror_root_path.text = ""
	save_mirror_settings()
	update_mirror_status()

func on_mirror_repo_text_changed(new_text: String) -> void:
	## Handles user edits to the remote repository URL input field.
	mirror_repository_url = new_text.strip_edges()
	save_mirror_settings()
	update_mirror_status()

func on_mirror_repo_clear_pressed() -> void:
	## Resets remote repository URL back to default.
	mirror_repository_url = _default_remote_repo_url
	_ui.mirror_repo_path.text = mirror_repository_url
	save_mirror_settings()
	update_mirror_status()

func update_mirror_status() -> void:
	## Evaluates and renders mirror configuration and repository readiness.
	var resolver = MirrorPathResolverScript.new()
	var effective_root = mirror_root_override if not mirror_root_override.is_empty() else resolver.get_mirror_root()
	var has_local_repo = false
	if not effective_root.is_empty() and DirAccess.dir_exists_absolute(effective_root):
		has_local_repo = FileAccess.file_exists(effective_root.path_join("repository.json"))
	if has_local_repo:
		_ui.mirror_status_label.text = "Mirror status: Local mirror ready"
		_ui.mirror_status_label.modulate = Color.GREEN
	elif not mirror_repository_url.is_empty():
		_ui.mirror_status_label.text = "Mirror status: Remote repository configured"
		_ui.mirror_status_label.modulate = Color(0.3, 0.6, 1.0, 1.0)
	elif mirror_root_override.is_empty():
		_ui.mirror_status_label.text = "Mirror status: Using default location"
		_ui.mirror_status_label.modulate = Color.GRAY
	elif DirAccess.dir_exists_absolute(mirror_root_override):
		_ui.mirror_status_label.text = "Mirror status: Directory exists, but repository.json not found"
		_ui.mirror_status_label.modulate = Color.YELLOW
	else:
		_ui.mirror_status_label.text = "Mirror status: Directory does not exist"
		_ui.mirror_status_label.modulate = Color.RED

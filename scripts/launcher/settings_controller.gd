## SettingsController: Manages the settings page UI and configuration.
extends RefCounted
class_name SettingsController

const MirrorPathResolverScript = preload("res://scripts/mirror/mirror_path_resolver.gd")
const OgsLogger = preload("res://scripts/logging/logger.gd")
const OgsConfig = preload("res://scripts/config/ogs_config.gd")

class UIDeps extends RefCounted:
	var mirror_root_path: LineEdit
	var mirror_repo_path: LineEdit
	var mirror_status_label: Label
	var project_offline_status_label: Label
	var project_offline_mode_check_button: CheckButton
	var project_force_offline_check_button: CheckButton
	var app_node: Node # used to add file dialog to tree

var _ui: UIDeps
var _projects_controller
var _default_remote_repo_url: String
var _settings_file_path: String
var mirror_root_override: String = ""
var mirror_repository_url: String = ""

func setup(deps: UIDeps, projects_controller, default_remote_repo_url: String, settings_file_path: String) -> void:
	_ui = deps
	_projects_controller = projects_controller
	_default_remote_repo_url = default_remote_repo_url
	_settings_file_path = settings_file_path
	
	_load_mirror_settings()
	update_mirror_status()

func get_mirror_repository_url() -> String:
	return mirror_repository_url if not mirror_repository_url.is_empty() else _default_remote_repo_url

func _load_mirror_settings() -> void:
	if FileAccess.file_exists(_settings_file_path):
		var file = FileAccess.open(_settings_file_path, FileAccess.READ)
		if file != null:
			var json_text = file.get_as_text()
			if not json_text.strip_edges().is_empty():
				var parser = JSON.new()
				if parser.parse(json_text) == OK and typeof(parser.data) == TYPE_DICTIONARY:
					mirror_root_override = String(parser.data.get("mirror_root", ""))
					mirror_repository_url = String(parser.data.get("remote_repository_url", _default_remote_repo_url))
					_ui.mirror_root_path.text = mirror_root_override
					_ui.mirror_repo_path.text = mirror_repository_url
					return
	mirror_root_override = ""
	mirror_repository_url = _default_remote_repo_url
	_ui.mirror_root_path.text = ""
	_ui.mirror_repo_path.text = mirror_repository_url

func save_mirror_settings() -> void:
	var data = {
		"mirror_root": mirror_root_override,
		"remote_repository_url": mirror_repository_url,
		"timestamp": Time.get_ticks_msec()
	}
	var file = FileAccess.open(_settings_file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		OgsLogger.info("mirror_settings_saved", {"component": "settings"})

func on_mirror_root_text_changed(new_text: String) -> void:
	mirror_root_override = new_text
	save_mirror_settings()
	update_mirror_status()

func on_mirror_root_browse_pressed() -> void:
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
	mirror_root_override = ""
	_ui.mirror_root_path.text = ""
	save_mirror_settings()
	update_mirror_status()

func on_mirror_repo_text_changed(new_text: String) -> void:
	mirror_repository_url = new_text.strip_edges()
	save_mirror_settings()
	update_mirror_status()

func on_mirror_repo_clear_pressed() -> void:
	mirror_repository_url = _default_remote_repo_url
	_ui.mirror_repo_path.text = mirror_repository_url
	save_mirror_settings()
	update_mirror_status()

func update_mirror_status() -> void:
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

func on_project_selection_changed(project_dir: String, offline_mode: bool, force_offline: bool) -> void:
	_ui.project_offline_status_label.text = "Selected: %s" % project_dir if not project_dir.is_empty() else "No project selected"
	_ui.project_offline_mode_check_button.set_pressed_no_signal(offline_mode)
	_ui.project_force_offline_check_button.set_pressed_no_signal(force_offline)
	_ui.project_offline_mode_check_button.disabled = project_dir.is_empty()
	_ui.project_force_offline_check_button.disabled = project_dir.is_empty()

func sync_project_offline_settings(project_dir: String, config: OgsConfig) -> void:
	on_project_selection_changed(project_dir, config.offline_mode if config != null else false, config.force_offline if config != null else false)

func on_project_offline_setting_toggled(_enabled: bool) -> void:
	if _projects_controller == null or _projects_controller.current_project_dir.is_empty(): return
	_projects_controller.update_current_project_offline_settings(
		_ui.project_offline_mode_check_button.button_pressed,
		_ui.project_force_offline_check_button.button_pressed
	)

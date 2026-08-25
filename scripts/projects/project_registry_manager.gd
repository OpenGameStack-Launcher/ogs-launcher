extends RefCounted
class_name ProjectRegistryManager

const OgsLogger = preload("res://scripts/logging/logger.gd")
const DEFAULT_PROJECTS_INDEX_PATH := "user://ogs_projects_index.json"

var tracked_projects: Array = []
var _projects_index_path := DEFAULT_PROJECTS_INDEX_PATH
var _projects_root_override := ""
var _pc

func setup(projects_controller) -> void:
	_pc = projects_controller

func _save_json_file(file_path: String, payload: Dictionary) -> bool:
	## Writes JSON dictionary to disk with pretty formatting.
## 
## Parameters:
## file_path (String): Destination absolute file path
## payload (Dictionary): JSON-compatible object payload
## 
## Returns:
## bool: True on successful write, false otherwise
## 
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true

func _resolve_ogs_projects_root_path() -> String:
	## Determines where the root OGS Projects folder should be.
## 
## Returns:
## String: Absolute path to the projects root folder
## 
	if not _projects_root_override.is_empty():
		return _projects_root_override
	return _get_default_projects_dir()

func _get_default_projects_dir() -> String:
	## Resolves the default root directory where new projects are created.
## 
## Returns:
## String: Absolute path to OGS_Projects folder
## 
	var home_dir = OS.get_environment("USERPROFILE")
	if home_dir.is_empty():
		home_dir = OS.get_environment("HOME")

	if not home_dir.is_empty():
		return home_dir.path_join("OGS_Projects")
	return OS.get_user_data_dir().path_join("OGS_Projects")

func set_projects_index_path_for_tests(path: String) -> void:
	## Overrides project index storage path for isolated tests.
## 
## Parameters:
## path (String): user:// path where project index JSON will be stored
## 
	if not path.is_empty():
		_projects_index_path = path

func set_projects_root_path_for_tests(path: String) -> void:
	## Overrides new project scaffold root path for isolated tests.
## 
## Parameters:
## path (String): Absolute or user:// path used for creating new project folders
## 
	_projects_root_override = path

func find_project_index_by_path(project_dir: String) -> int:
	## Returns tracked project index by normalized path, or -1 if missing.
	for index in range(tracked_projects.size()):
		var entry = tracked_projects[index]
		if String(entry.get("path", "")) == project_dir:
			return index
	return -1

func load_project_registry() -> void:
	## Loads persisted project entries from disk with validation and pruning.
	tracked_projects.clear()
	if not FileAccess.file_exists(_projects_index_path):
		OgsLogger.debug("project_registry_missing", {
			"component": "projects"
		})
		return

	var file = FileAccess.open(_projects_index_path, FileAccess.READ)
	if file == null:
		OgsLogger.warn("project_registry_read_failed", {
			"component": "projects"
		})
		return

	var text = file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		OgsLogger.warn("project_registry_parse_failed", {
			"component": "projects",
			"reason": "empty_json"
		})
		return
	var parser = JSON.new()
	var parse_err = parser.parse(text)
	var parsed = parser.data
	if parse_err != OK or typeof(parsed) != TYPE_DICTIONARY:
		OgsLogger.warn("project_registry_parse_failed", {
			"component": "projects",
			"reason": "invalid_json"
		})
		return

	var entries: Array = parsed.get("projects", [])
	for raw_entry in entries:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var project_dir = String(raw_entry.get("path", ""))
		if _pc._is_addable_project_dir(project_dir):
			tracked_projects.append(raw_entry)
			
	if parsed.has("last_selected_project_path"):
		_pc._last_selected_project_path = String(parsed.get("last_selected_project_path", ""))

	OgsLogger.info("project_registry_loaded", {
		"component": "projects",
		"count": tracked_projects.size()
	})

func save_project_registry() -> void:
	## Persists tracked projects list to disk for session continuity.
	var payload = {
		"version": 1,
		"projects": tracked_projects,
		"last_selected_project_path": _pc._last_selected_project_path,
		"updated_at": Time.get_unix_time_from_system()
	}
	var file = FileAccess.open(_projects_index_path, FileAccess.WRITE)
	if file == null:
		OgsLogger.warn("project_registry_write_failed", {
			"component": "projects"
		})
		return
	file.store_string(JSON.stringify(payload))
	file.close()
	OgsLogger.debug("project_registry_saved", {
		"component": "projects",
		"count": tracked_projects.size()
	})


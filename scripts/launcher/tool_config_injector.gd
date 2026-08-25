## ToolConfigInjector: Applies tool-specific offline overrides before launch.
##
## Ensures child tools run with network-limiting configuration in air-gapped mode.
## This class is best-effort for tool-specific settings while preserving portability.

extends RefCounted
class_name ToolConfigInjector

const OgsLogger = preload("res://scripts/logging/logger.gd")
const GODOT_OFFLINE_CACHE_ROOT = "user://ogs_offline_godot"

static func apply(tool_id: String, project_dir: String, launch_project_dir: String = "") -> Dictionary:
	## Applies offline configuration for a given tool.
## Parameters:
## tool_id (String): Tool identifier (e.g., "godot")
## project_dir (String): Project directory for contextual paths
## launch_project_dir (String): Resolved directory launched by the child tool
## Returns:
## Dictionary: {"success": bool, "error_message": String, "args": PackedStringArray}
## 
	var args = PackedStringArray()
	var target_project_dir = launch_project_dir if not launch_project_dir.is_empty() else project_dir
	match tool_id:
		"godot":
			var result = _apply_godot_overrides(target_project_dir)
			if not result["success"]:
				OgsLogger.warn("tool_config_failed", {"component": "launcher", "tool": "godot"})
				return result
			args.append_array(result["args"])
		"blender":
			args.append_array(_blender_offline_args())
			OgsLogger.info("tool_config_applied", {"component": "launcher", "tool": "blender"})
			return {
				"success": true,
				"error_message": "",
				"args": args
			}
		"krita":
			return _apply_placeholder_override("krita", project_dir, args)
		"audacity":
			return _apply_placeholder_override("audacity", project_dir, args)
		_:
			return {
				"success": true,
				"error_message": "",
				"args": args
			}
	return {
		"success": true,
		"error_message": "",
		"args": args
	}

static func _apply_godot_overrides(project_dir: String) -> Dictionary:
	## Writes project-local overrides to disable network features.
	var cache_paths = _godot_offline_cache_paths(project_dir)
	var cache_dir = String(cache_paths["cache_dir"])
	var settings_path = String(cache_paths["settings_path"])
	var override_path = String(cache_paths["override_path"])
	var profile_path = String(cache_paths["profile_path"])
	var mkdir_err = DirAccess.make_dir_recursive_absolute(cache_dir)
	if mkdir_err != OK and not DirAccess.dir_exists_absolute(cache_dir):
		return {
			"success": false,
			"error_message": "Failed to create editor settings directory: %s" % cache_dir,
			"args": PackedStringArray()
		}

	var override_config = ConfigFile.new()
	override_config.set_value("asset_library", "use_threads", false)
	override_config.set_value("network/debug", "bandwidth_limiter", 0)
	override_config.set_value("network/http_proxy", "enabled", false)
	override_config.set_value("network/http_proxy", "host", "")
	override_config.set_value("network/http_proxy", "port", 0)
	var override_save_err = override_config.save(override_path)
	if override_save_err != OK:
		return {
			"success": false,
			"error_message": "Failed to save offline override: %s" % override_path,
			"args": PackedStringArray()
		}

	var profile = FileAccess.open(profile_path, FileAccess.WRITE)
	if profile == null:
		return {
			"success": false,
			"error_message": "Failed to save offline profile: %s" % profile_path,
			"args": PackedStringArray()
		}
	profile.store_string(JSON.stringify({
		"type": "feature_profile",
		"disabled_features": ["asset_lib"]
	}, "\t"))
	var profile_write_err = profile.get_error()
	profile.close()
	if profile_write_err != OK:
		return {
			"success": false,
			"error_message": "Failed to write offline profile: %s" % profile_path,
			"args": PackedStringArray()
		}

	var editor_settings = FileAccess.open(settings_path, FileAccess.WRITE)
	if editor_settings == null:
		return {
			"success": false,
			"error_message": "Failed to save editor settings: %s" % settings_path,
			"args": PackedStringArray()
		}
	editor_settings.store_string(_build_editor_settings_resource(profile_path))
	var settings_write_err = editor_settings.get_error()
	editor_settings.close()
	if settings_write_err != OK:
		OgsLogger.warn("tool_config_failed", {"component": "launcher", "tool": "godot"})
		return {
			"success": false,
			"error_message": "Failed to save editor settings: %s" % settings_path,
			"args": PackedStringArray()
		}

	OgsLogger.info("tool_config_applied", {"component": "launcher", "tool": "godot"})
	return {
		"success": true,
		"error_message": "",
		"args": PackedStringArray(["--editor-settings", settings_path])
	}

static func clear(tool_id: String, project_dir: String) -> void:
	## Removes tool-specific offline configuration before a normal launch.
## Parameters:
## tool_id (String): Tool identifier being launched
## project_dir (String): Resolved project directory used by the child tool
## Returns:
## void
	match tool_id:
		"godot":
			_clear_godot_overrides(project_dir)
		"krita", "audacity":
			_clear_placeholder_override(tool_id)
		_:
			return

static func _clear_godot_overrides(project_dir: String) -> void:
	## Removes OGS-managed Godot offline overrides from the launched project.
## Parameters:
## project_dir (String): Resolved project directory used by the child tool
## Returns:
## void
	var cache_paths = _godot_offline_cache_paths(project_dir)
	var editor_settings_path = String(cache_paths["settings_path"])
	var override_path = String(cache_paths["override_path"])
	var profile_path = String(cache_paths["profile_path"])
	_remove_file_if_exists(editor_settings_path)
	_remove_file_if_exists(override_path)
	_remove_file_if_exists(profile_path)

static func _godot_offline_cache_paths(project_dir: String) -> Dictionary:
	## Resolves per-project writable cache paths used for Godot offline launch artifacts.
	var absolute_project_dir = _resolve_absolute_path(project_dir)
	var project_hash = _hash_project_id(absolute_project_dir)
	var cache_root = _resolve_absolute_path(GODOT_OFFLINE_CACHE_ROOT)
	var cache_dir = cache_root.path_join(project_hash)
	return {
		"cache_dir": cache_dir,
		"settings_path": cache_dir.path_join("editor_settings-4.tres"),
		"override_path": cache_dir.path_join("override.cfg"),
		"profile_path": cache_dir.path_join(".ogs_offline.profile")
	}

static func _build_editor_settings_resource(profile_path: String) -> String:
	## Builds a Godot editor settings resource payload for offline launch constraints.
	return "[gd_resource type=\"EditorSettings\" format=3]\n\n[resource]\nasset_library/use_threads = false\nnetwork/debug/bandwidth_limiter = 0\nnetwork/http_proxy/enabled = false\nnetwork/http_proxy/host = \"\"\nnetwork/http_proxy/port = 0\n_default_feature_profile = \"%s\"\n" % profile_path.c_escape()

static func _resolve_absolute_path(path: String) -> String:
	## Normalizes user:// and relative paths to native absolute filesystem paths.
	if path.begins_with("user://") or not path.is_absolute_path():
		return ProjectSettings.globalize_path(path)
	return path

static func _remove_file_if_exists(file_path: String) -> void:
	## Deletes a file when present so stale offline artifacts do not affect later launches.
	if FileAccess.file_exists(file_path):
		var absolute_path = file_path
		if absolute_path.begins_with("user://") or not absolute_path.is_absolute_path():
			absolute_path = ProjectSettings.globalize_path(absolute_path)
		var remove_err = DirAccess.remove_absolute(absolute_path)
		if remove_err != OK:
			OgsLogger.warn("tool_config_cleanup_failed", {
				"component": "launcher",
				"absolute_path": absolute_path,
				"error_code": remove_err
			})

static func _blender_offline_args() -> PackedStringArray:
	## Builds Blender arguments to disable online access at launch.
	var args = PackedStringArray()
	args.append("--python-expr")
	args.append("import bpy; bpy.context.preferences.system.use_online_access = False")
	return args

static func _apply_placeholder_override(tool_id: String, project_dir: String, args: PackedStringArray) -> Dictionary:
	## Writes a placeholder offline override file and sets env flags.
## Parameters:
## tool_id (String): Tool identifier
## project_dir (String): Project directory for context
## args (PackedStringArray): Launch arguments
## Returns:
## Dictionary: {"success": bool, "error_message": String, "args": PackedStringArray}
## 
	var write_result = _write_placeholder_override(tool_id, project_dir)
	if not write_result["success"]:
		OgsLogger.warn("tool_config_failed", {"component": "launcher", "tool": tool_id})
		return write_result
	OS.set_environment("OGS_OFFLINE_TOOL_%s" % tool_id.to_upper(), "1")
	OgsLogger.info("tool_config_applied", {"component": "launcher", "tool": tool_id})
	return {
		"success": true,
		"error_message": "",
		"args": args
	}

static func _clear_placeholder_override(tool_id: String) -> void:
	## Removes placeholder offline artifacts and env flags for tools using user:// overrides.
	var file_path = "user://ogs_offline_overrides/%s.json" % tool_id
	_remove_file_if_exists(file_path)
	OS.set_environment("OGS_OFFLINE_TOOL_%s" % tool_id.to_upper(), "")

static func _write_placeholder_override(tool_id: String, project_dir: String) -> Dictionary:
	## Creates a placeholder override file in user storage.
## Parameters:
## tool_id (String): Tool identifier
## project_dir (String): Project directory for context
## Returns:
## Dictionary: {"success": bool, "error_message": String, "args": PackedStringArray}
## 
	var dir_path = "user://ogs_offline_overrides"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file_path = "%s/%s.json" % [dir_path, tool_id]
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return {
			"success": false,
			"error_message": "Failed to write offline override for %s" % tool_id,
			"args": PackedStringArray()
		}
	var payload = {
		"tool_id": tool_id,
		"project_id": _hash_project_id(project_dir),
		"offline": true
	}
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return {
		"success": true,
		"error_message": "",
		"args": PackedStringArray()
	}

static func _hash_project_id(project_dir: String) -> String:
	var normalized = project_dir.strip_edges().to_lower()
	var hasher = HashingContext.new()
	var start_err = hasher.start(HashingContext.HASH_SHA256)
	if start_err != OK:
		return ""
	hasher.update(normalized.to_utf8_buffer())
	var digest = hasher.finish()
	return digest.hex_encode().to_lower()

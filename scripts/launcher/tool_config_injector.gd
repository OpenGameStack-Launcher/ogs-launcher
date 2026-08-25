## ToolConfigInjector: Applies tool-specific offline overrides before launch.
##
## Ensures child tools run with network-limiting configuration in air-gapped mode.
## This class is best-effort for tool-specific settings while preserving portability.

extends RefCounted
class_name ToolConfigInjector

const OgsLogger = preload("res://scripts/logging/logger.gd")

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
	var override_path = project_dir.path_join("override.cfg")
	var config = ConfigFile.new()
	var load_err = config.load(override_path)
	if load_err != OK and load_err != ERR_FILE_NOT_FOUND:
		return {
			"success": false,
			"error_message": "Failed to load override.cfg: %s" % override_path,
			"args": PackedStringArray()
		}
	
	config.set_value("asset_library", "use_threads", false)
	config.set_value("network/debug", "bandwidth_limiter", 0)
	config.set_value("network/http_proxy", "enabled", false)
	config.set_value("network/http_proxy", "host", "")
	config.set_value("network/http_proxy", "port", 0)
	var save_err = config.save(override_path)
	if save_err != OK:
		OgsLogger.warn("tool_config_failed", {"component": "launcher", "tool": "godot"})
		return {
			"success": false,
			"error_message": "Failed to save override.cfg: %s" % override_path,
			"args": PackedStringArray()
		}

	_remove_file_if_exists(project_dir.path_join(".ogs_offline.profile"))
	OgsLogger.info("tool_config_applied", {"component": "launcher", "tool": "godot"})
	return {
		"success": true,
		"error_message": "",
		"args": PackedStringArray()
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
		_:
			return

static func _clear_godot_overrides(project_dir: String) -> void:
	## Removes OGS-managed Godot offline overrides from the launched project.
## Parameters:
## project_dir (String): Resolved project directory used by the child tool
## Returns:
## void
	var override_path = project_dir.path_join("override.cfg")
	var profile_path = project_dir.path_join(".ogs_offline.profile")
	var config = ConfigFile.new()
	var load_err = config.load(override_path)
	if load_err == OK:
		config.erase_section_key("asset_library", "use_threads")
		config.erase_section_key("network/debug", "bandwidth_limiter")
		config.erase_section_key("network/http_proxy", "enabled")
		config.erase_section_key("network/http_proxy", "host")
		config.erase_section_key("network/http_proxy", "port")
		_erase_empty_sections(config, ["asset_library", "network/debug", "network/http_proxy"])
		if config.get_sections().is_empty():
			_remove_file_if_exists(override_path)
		elif config.save(override_path) == OK:
			pass
		else:
			OgsLogger.warn("tool_config_cleanup_failed", {"component": "launcher", "tool": "godot"})
			return
		_remove_file_if_exists(profile_path)
	elif load_err == ERR_FILE_NOT_FOUND:
		_remove_file_if_exists(profile_path)
	else:
		OgsLogger.warn("tool_config_cleanup_failed", {"component": "launcher", "tool": "godot"})

static func _erase_empty_sections(config: ConfigFile, sections: Array[String]) -> void:
	## Removes empty override sections so cleanup can delete fully managed files.
	for section in sections:
		if config.has_section(section) and config.get_section_keys(section).is_empty():
			config.erase_section(section)

static func _remove_file_if_exists(file_path: String) -> void:
	## Deletes a file when present so stale offline artifacts do not affect later launches.
	if FileAccess.file_exists(file_path):
		var absolute_path = file_path
		if absolute_path.begins_with("user://") or not absolute_path.is_absolute_path():
			absolute_path = ProjectSettings.globalize_path(absolute_path)
		DirAccess.remove_absolute(absolute_path)

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

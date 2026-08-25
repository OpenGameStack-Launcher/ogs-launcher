## ToolConfigInjector: Applies tool-specific offline overrides before launch.
##
## Ensures child tools run with network-limiting configuration in air-gapped mode.
## This class is best-effort for tool-specific settings while preserving portability.

extends RefCounted
class_name ToolConfigInjector

const OgsLogger = preload("res://scripts/logging/logger.gd")

const GODOT_SETTINGS_PRIMARY := "user://editor_settings-4.tres"
const GODOT_SETTINGS_LEGACY := "user://editor_settings.tres"

static func apply(tool_id: String, project_dir: String) -> Dictionary:
	## Applies offline configuration for a given tool.
## Parameters:
## tool_id (String): Tool identifier (e.g., "godot")
## project_dir (String): Project directory for contextual paths
## Returns:
## Dictionary: {"success": bool, "error_message": String, "args": PackedStringArray}
## 
	var args = PackedStringArray()
	match tool_id:
		"godot":
			var result = _apply_godot_overrides(project_dir)
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
	
	config.set_value("editor", "feature_profile", "res://.ogs_offline.profile")
	var save_err = config.save(override_path)
	if save_err != OK:
		OgsLogger.warn("tool_config_failed", {"component": "launcher", "tool": "godot"})
		return {
			"success": false,
			"error_message": "Failed to save override.cfg: %s" % override_path,
			"args": PackedStringArray()
		}

	var profile_path = project_dir.path_join(".ogs_offline.profile")
	var profile = FileAccess.open(profile_path, FileAccess.WRITE)
	if profile != null:
		var payload = {
			"type": "feature_profile",
			"disabled_features": [
				"asset_lib"
			]
		}
		profile.store_string(JSON.stringify(payload, "\t"))
		profile.close()
	else:
		return {
			"success": false,
			"error_message": "Failed to write .ogs_offline.profile",
			"args": PackedStringArray()
		}
		
	OgsLogger.info("tool_config_applied", {"component": "launcher", "tool": "godot"})
	return {
		"success": true,
		"error_message": "",
		"args": PackedStringArray()
	}

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

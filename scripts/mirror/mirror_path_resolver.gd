## MirrorPathResolver: Path helpers for local mirror repositories.
##
## Resolves default mirror roots and validates archive paths to ensure
## they remain inside the mirror root directory.

extends RefCounted
class_name MirrorPathResolver

const OgsLogger = preload("res://scripts/logging/logger.gd")

## Returns the default mirror root directory for the current platform.
## Windows: %LOCALAPPDATA%/OGS/Mirror
## Unix:    ~/.config/ogs-launcher/mirror
func get_mirror_root() -> String:
	"""Returns the default mirror root directory for this platform."""
	var root: String
	if OS.get_name() == "Windows":
		var appdata = OS.get_environment("LOCALAPPDATA")
		if appdata.is_empty():
			OgsLogger.error("mirror_root_resolution_failed", {
				"component": "mirror",
				"reason": "LOCALAPPDATA not set",
				"platform": OS.get_name()
			})
			return ""
		root = appdata.path_join("OGS").path_join("Mirror")
	else:
		var home = OS.get_environment("HOME")
		if home.is_empty():
			OgsLogger.error("mirror_root_resolution_failed", {
				"component": "mirror",
				"reason": "HOME not set",
				"platform": OS.get_name()
			})
			return ""
		root = home.path_join(".config").path_join("ogs-launcher").path_join("mirror")

	OgsLogger.debug("mirror_root_resolved", {
		"component": "mirror",
		"path": root,
		"platform": OS.get_name()
	})
	return root

## Normalizes a path string for consistent path handling.
## Parameters:
##   path_str (String): Input path
## Returns:
##   String: Normalized absolute path
func normalize_path(path_str: String) -> String:
	"""Normalizes a path string to an absolute path."""
	if path_str.is_empty():
		return ""
	var normalized = path_str.replace("\\", "/")
	if normalized.begins_with("~"):
		var home = OS.get_environment("HOME")
		if not home.is_empty():
			normalized = home + normalized.substr(1)
	var abs_path = ProjectSettings.globalize_path(normalized)
	OgsLogger.debug("mirror_path_normalized", {
		"component": "mirror",
		"input": path_str,
		"output": abs_path
	})
	return abs_path

## Resolves a mirror archive path and validates it is under the mirror root.
## Parameters:
##   mirror_root (String): Base mirror directory
##   archive_path (String): Relative archive path inside mirror
## Returns:
##   Dictionary: {"success": bool, "full_path": String, "error": String}
func resolve_archive_path(mirror_root: String, archive_path: String) -> Dictionary:
	"""Resolves and validates an archive path under the mirror root."""
	var result = {"success": false, "full_path": "", "error": ""}
	if mirror_root.is_empty():
		result["error"] = "Mirror root is empty"
		return result
	if archive_path.is_empty():
		result["error"] = "Archive path is empty"
		return result
	if archive_path.is_absolute_path():
		result["error"] = "Archive path must be relative"
		return result
	var normalized_archive = archive_path.replace("\\", "/")
	var full_path = mirror_root.path_join(normalized_archive).simplify_path()
	if not _is_path_under_root(full_path, mirror_root):
		result["error"] = "Archive path escapes mirror root"
		return result
	result["success"] = true
	result["full_path"] = full_path
	return result

## Checks if a path is under the given root directory.
static func _is_path_under_root(full_path: String, root: String) -> bool:
	"""Returns true if full_path is inside root (case-insensitive)."""
	var normalized_root = root.simplify_path().to_lower()
	var normalized_path = full_path.simplify_path().to_lower()
	if normalized_path == normalized_root:
		return true
	return normalized_path.begins_with(normalized_root + "/")

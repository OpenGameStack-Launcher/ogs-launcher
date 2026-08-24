## LibraryManager: Central management of the OGS tool library.
##
## The LibraryManager handles discovery, validation, and metadata about tools
## in the central library. It provides the interface between the Launcher UI
## and the actual file system structure where frozen stack tools are stored.
##
## Responsibilities:
## - Query available tools and versions
## - Validate tool integrity
## - Provide metadata (path, size, last updated)
## - Detect missing/broken tools
## - Report readiness for project hydration
##
## The library structure is:
## [LIBRARY_ROOT]/[tool_id]/[version]/[tool_files]
##
## Example queries:
## - "Is Godot 4.7.2 installed?" -> tool_exists("godot", "4.7.2")
## - "What tools do I have?" -> get_available_tools()
## - "What versions of Blender?" -> get_available_versions("blender")
## - "Where's Godot 4.7.2?" -> get_tool_path("godot", "4.7.2")
##
## Usage:
## var library = LibraryManager.new()
## if library.tool_exists("godot", "4.7.2"):
## print("Ready to launch: " + library.get_tool_path("godot", "4.7.2"))

extends RefCounted
class_name LibraryManager

const OgsLogger = preload("res://scripts/logging/logger.gd")

var path_resolver: PathResolver

func _init() -> void:
	path_resolver = PathResolver.new()

## Returns the absolute path to a tool in the library.
## Parameters:
## tool_id (String): Tool identifier (e.g., "godot", "blender")
## version (String): Version string (e.g., "4.7.2")
## Returns:
## String: Absolute path to the tool directory, or empty string if not found
func get_tool_path(tool_id: String, version: String) -> String:
	var path = path_resolver.get_tool_path(tool_id, version)
	
	if path.is_empty():
		OgsLogger.warn("library_tool_path_failed", {
			"component": "library",
			"tool_id": tool_id,
			"version": version,
			"reason": "path resolution failed"
		})
		return ""
	
	if not path_resolver.tool_exists(tool_id, version):
		OgsLogger.debug("library_tool_not_found", {
			"component": "library",
			"tool_id": tool_id,
			"version": version,
			"path": path
		})
		return ""
	
	return path

## Checks if a tool version exists in the library.
## Parameters:
## tool_id (String): Tool identifier
## version (String): Version string
## Returns:
## bool: True if the tool directory exists
func tool_exists(tool_id: String, version: String) -> bool:
	return path_resolver.tool_exists(tool_id, version)

## Removes one installed tool version from the central library.
## Returns a result dictionary with success and an error message for the OGS lifecycle.
func remove_tool(tool_id: String, version: String) -> Dictionary:
	## Deletes only the resolved tool/version directory after containment checks.
	var library_root = path_resolver.get_library_root().simplify_path()
	var tool_path = path_resolver.get_tool_path(tool_id, version).simplify_path()
	if library_root.is_empty() or tool_path.is_empty():
		return {"success": false, "error_message": "Unable to resolve the library path."}

	var expected_prefix = library_root + "/"
	if not tool_path.begins_with(expected_prefix) or tool_path == library_root:
		OgsLogger.error("tool_removal_rejected", {"component": "library", "reason": "path_outside_library"})
		return {"success": false, "error_message": "Removal path is outside the OGS library."}
	if not DirAccess.dir_exists_absolute(tool_path):
		return {"success": false, "error_message": "Installed tool directory was not found."}

	var remove_error = _remove_directory_contents(tool_path)
	if remove_error != OK:
		OgsLogger.error("tool_removal_failed", {"component": "library", "error": remove_error})
		return {
			"success": false,
			"error_message": "Could not delete the installed tool files (filesystem error %d). Close any running copy of this tool and try again." % remove_error
		}

	OgsLogger.info("tool_removed", {"component": "library", "tool_id": tool_id, "version": version})
	return {"success": true, "error_message": ""}

func _remove_directory_contents(directory_path: String) -> int:
	## Recursively removes a directory and its contents for tool uninstall.
	var directory = DirAccess.open(directory_path)
	if directory == null:
		return ERR_CANT_OPEN

	var entries: Array[Dictionary] = []
	directory.list_dir_begin()
	var entry_name = directory.get_next()
	while not entry_name.is_empty():
		if entry_name != "." and entry_name != "..":
			entries.append({
				"path": directory_path.path_join(entry_name),
				"is_dir": directory.current_is_dir()
			})
		entry_name = directory.get_next()
	directory.list_dir_end()

	for entry in entries:
		var entry_path = String(entry["path"])
		var error = OK
		if entry["is_dir"]:
			error = _remove_directory_contents(entry_path)
		else:
			error = DirAccess.remove_absolute(entry_path)
		if error != OK:
			return error

	return DirAccess.remove_absolute(directory_path)

## Returns a list of all tools currently in the library.
## Returns:
## Array[String]: Tool identifiers (e.g., ["godot", "blender"])
func get_available_tools() -> Array[String]:
	return path_resolver.get_available_tools()

## Returns all versions of a specific tool in the library.
## Parameters:
## tool_id (String): Tool identifier
## Returns:
## Array[String]: Version strings, sorted
func get_available_versions(tool_id: String) -> Array[String]:
	return path_resolver.get_available_versions(tool_id)

## Returns metadata about a tool in the library.
## Useful for UI display and validation.
## Parameters:
## tool_id (String): Tool identifier
## version (String): Version string
## Returns:
## Dictionary: {
## "exists": bool,
## "path": String,
## "size_bytes": int (0 if not found),
## "last_modified": int (unix timestamp, 0 if not found)
## }
func get_tool_metadata(tool_id: String, version: String) -> Dictionary:
	var meta = {
		"exists": false,
		"path": "",
		"size_bytes": 0,
		"last_modified": 0
	}
	
	var tool_path = path_resolver.get_tool_path(tool_id, version)
	if tool_path.is_empty():
		return meta
	
	if not path_resolver.tool_exists(tool_id, version):
		return meta
	
	meta["exists"] = true
	meta["path"] = tool_path
	
	# Calculate directory size
	var size = _calculate_dir_size(tool_path)
	meta["size_bytes"] = size
	
	# Get modification time
	if FileAccess.file_exists(tool_path):
		meta["last_modified"] = FileAccess.get_modified_time(tool_path)
	
	OgsLogger.debug("tool_metadata_retrieved", {
		"component": "library",
		"tool_id": tool_id,
		"version": version,
		"size_bytes": meta["size_bytes"]
	})
	
	return meta

## Validates that a tool exists and is accessible.
## Performs sanity checks (directory exists, readable, etc).
## Parameters:
## tool_id (String): Tool identifier
## version (String): Version string
## Returns:
## Dictionary: {
## "valid": bool,
## "errors": Array[String]
## }
func validate_tool(tool_id: String, version: String) -> Dictionary:
	var result = {
		"valid": true,
		"errors": []
	}
	
	# Check existence
	if not tool_exists(tool_id, version):
		result["valid"] = false
		result["errors"].append("Tool directory not found")
		OgsLogger.warn("tool_validation_failed", {
			"component": "library",
			"tool_id": tool_id,
			"version": version,
			"reason": "not found"
		})
		return result
	
	# Check readability
	var tool_path = path_resolver.get_tool_path(tool_id, version)
	var dir = DirAccess.open(tool_path)
	if dir == null:
		result["valid"] = false
		result["errors"].append("Tool directory not readable")
		OgsLogger.warn("tool_validation_failed", {
			"component": "library",
			"tool_id": tool_id,
			"version": version,
			"reason": "not readable"
		})
		return result
	
	OgsLogger.debug("tool_validation_success", {
		"component": "library",
		"tool_id": tool_id,
		"version": version
	})
	
	return result

## Returns the library root directory.
## Returns:
## String: Absolute path to library root
func get_library_root() -> String:
	return path_resolver.get_library_root()

## Returns a summary of the library state.
## Useful for status UI and diagnostics.
## Returns:
## Dictionary: {
## "library_root": String,
## "total_tools": int,
## "total_versions": int,
## "tools": Dictionary of tool_id -> Array[String] (versions)
## }
func get_library_summary() -> Dictionary:
	var summary = {
		"library_root": get_library_root(),
		"total_tools": 0,
		"total_versions": 0,
		"tools": {}
	}
	
	var tools = get_available_tools()
	summary["total_tools"] = tools.size()
	
	for tool_id in tools:
		var versions = get_available_versions(tool_id)
		summary["tools"][tool_id] = versions
		summary["total_versions"] += versions.size()
	
	OgsLogger.debug("library_summary_generated", {
		"component": "library",
		"total_tools": summary["total_tools"],
		"total_versions": summary["total_versions"]
	})
	
	return summary

## Recursively calculates the total size of a directory in bytes.
## Parameters:
## dir_path (String): Absolute path to the directory
## Returns:
## int: Total size in bytes, or 0 if directory doesn't exist/can't be read
func _calculate_dir_size(dir_path: String) -> int:
	var total_size: int = 0
	var dir = DirAccess.open(dir_path)
	
	if dir == null:
		OgsLogger.warn("calculate_dir_size_failed", {
			"component": "library",
			"path": dir_path,
			"reason": "could not open directory",
			"error": DirAccess.get_open_error()
		})
		return 0
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while not file_name.is_empty():
		if file_name != "." and file_name != "..":
			var path = dir_path.path_join(file_name)
			if dir.current_is_dir():
				total_size += _calculate_dir_size(path)
			else:
				var file = FileAccess.open(path, FileAccess.READ)
				if file != null:
					total_size += file.get_length()
					file.close()
				else:
					OgsLogger.warn("calculate_file_size_failed", {
						"component": "library",
						"path": path,
						"reason": "could not open file",
						"error": FileAccess.get_open_error()
					})
		file_name = dir.get_next()
		
	dir.list_dir_end()
	return total_size

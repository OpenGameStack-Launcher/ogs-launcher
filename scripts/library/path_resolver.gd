## PathResolver: Cross-platform path utilities for the OGS Library system.
##
## Provides standardized path resolution for the central library, ensuring
## consistent behavior across Windows and Unix-like systems. Handles expansion
## of environment variables (e.g., %LOCALAPPDATA%) and path normalization.
##
## The library root follows this structure:
##   Windows: %LOCALAPPDATA%/OGS/Library
##   Unix:    ~/.config/ogs-launcher/library
##
## Within the library, tools are organized as:
##   [LIBRARY_ROOT]/[tool_id]/[version]/[binaries]
##   Example: %LOCALAPPDATA%/OGS/Library/godot/4.3/godot.exe
##
## Usage:
##   var resolver = PathResolver.new()
##   var lib_root = resolver.get_library_root()
##   var godot_path = resolver.get_tool_path("godot", "4.3")

extends RefCounted
class_name PathResolver

const OgsLogger = preload("res://scripts/logging/logger.gd")

## Returns the root directory for the central library.
## On Windows: %LOCALAPPDATA%/OGS/Library (or %OGS_LIBRARY_ROOT% if set)
## On Unix:    ~/.config/ogs-launcher/library (or $OGS_LIBRARY_ROOT if set)
## 
## OGS_LIBRARY_ROOT environment variable can override the default path,
## useful for test isolation.
func get_library_root() -> String:
	# Check for test override first
	var override_root = OS.get_environment("OGS_LIBRARY_ROOT")
	if not override_root.is_empty():
		OgsLogger.debug("library_root_override", {
			"component": "library",
			"path": override_root,
			"reason": "OGS_LIBRARY_ROOT env var set"
		})
		return override_root
	
	var root: String
	
	if OS.get_name() == "Windows":
		var appdata = OS.get_environment("LOCALAPPDATA")
		if appdata.is_empty():
			OgsLogger.error("path_resolution_failed", {
				"component": "library",
				"reason": "LOCALAPPDATA not set",
				"platform": OS.get_name()
			})
			return ""
		root = appdata.path_join("OGS").path_join("Library")
	else:
		# Unix-like: use ~/.config/ogs-launcher/library
		var home = OS.get_environment("HOME")
		if home.is_empty():
			OgsLogger.error("path_resolution_failed", {
				"component": "library",
				"reason": "HOME not set",
				"platform": OS.get_name()
			})
			return ""
		root = home.path_join(".config").path_join("ogs-launcher").path_join("library")
	
	OgsLogger.debug("library_root_resolved", {
		"component": "library",
		"path": root,
		"platform": OS.get_name()
	})
	return root

## Returns the directory path for a specific tool version in the library.
## Parameters:
##   tool_id (String): Tool identifier (e.g., "godot", "blender")
##   version (String): Version string (e.g., "4.3", "4.2")
## Returns:
##   String: Full path to the tool directory (may not exist yet)
func get_tool_path(tool_id: String, version: String) -> String:
	var root = get_library_root()
	if root.is_empty():
		return ""
	return root.path_join(tool_id).path_join(version)

## Returns the normalized absolute path for a given file path string.
## Expands environment variables and ensures forward slashes for consistency.
## Parameters:
##   path_str (String): Path to normalize (may contain %VAR% or environment refs)
## Returns:
##   String: Absolute normalized path
func normalize_path(path_str: String) -> String:
	if path_str.is_empty():
		return ""
	
	# On Windows, convert backslashes to forward slashes for consistency
	var normalized = path_str.replace("\\", "/")
	
	# Expand ~ for home directory
	if normalized.begins_with("~"):
		var home = OS.get_environment("HOME")
		if not home.is_empty():
			normalized = normalized.substr(1)
			normalized = home + normalized
	
	# Convert to absolute path using Godot's file system
	var abs_path = ProjectSettings.globalize_path(normalized)
	
	OgsLogger.debug("path_normalized", {
		"component": "library",
		"input": path_str,
		"output": abs_path
	})
	
	return abs_path

## Returns all tool directories currently in the library.
## Used for discovery and validation during UI initialization.
## Returns:
##   Array[String]: List of tool_id directories in the library
func get_available_tools() -> Array[String]:
	var root = get_library_root()
	if root.is_empty():
		return []
	
	var tools: Array[String] = []
	var dir = DirAccess.open(root)
	
	if dir == null:
		OgsLogger.debug("library_discovery_empty", {
			"component": "library",
			"library_root": root,
			"reason": "directory does not exist"
		})
		return []
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not file_name.begins_with("."):
			var _full_path = root.path_join(file_name)
			if dir.current_is_dir():
				tools.append(file_name)
		file_name = dir.get_next()
	
	OgsLogger.debug("available_tools_discovered", {
		"component": "library",
		"count": tools.size(),
		"tools": tools
	})
	
	return tools

## Returns all versions of a specific tool in the library.
## Parameters:
##   tool_id (String): Tool identifier to query
## Returns:
##   Array[String]: List of version directories, sorted
func get_available_versions(tool_id: String) -> Array[String]:
	var tool_dir = get_tool_path(tool_id, "")
	if tool_dir.is_empty():
		return []
	
	# Remove trailing path separator
	tool_dir = tool_dir.trim_suffix("/")
	
	var versions: Array[String] = []
	var dir = DirAccess.open(tool_dir)
	
	if dir == null:
		OgsLogger.debug("versions_discovery_empty", {
			"component": "library",
			"tool_id": tool_id,
			"reason": "tool directory does not exist"
		})
		return []
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not file_name.begins_with("."):
			var _full_path = tool_dir.path_join(file_name)
			if dir.current_is_dir():
				versions.append(file_name)
		file_name = dir.get_next()
	
	versions.sort()
	
	OgsLogger.debug("available_versions_discovered", {
		"component": "library",
		"tool_id": tool_id,
		"count": versions.size(),
		"versions": versions
	})
	
	return versions

## Checks if a tool exists in the library.
## Parameters:
##   tool_id (String): Tool identifier to check
##   version (String, optional): Specific version to check (if omitted, checks if tool exists at all)
## Returns:
##   bool: True if tool (or tool+version) exists
func tool_exists(tool_id: String, version: String = "") -> bool:
	if version.is_empty():
		# Just check if tool directory exists
		var tool_dir = get_tool_path(tool_id, "")
		tool_dir = tool_dir.trim_suffix("/")
		return DirAccess.dir_exists_absolute(tool_dir)
	else:
		# Check specific version
		var tool_path = get_tool_path(tool_id, version)
		return DirAccess.dir_exists_absolute(tool_path)

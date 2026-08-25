## ToolLauncher: Responsible for launching tools from the frozen stack.
##
## Applies tool-specific arguments, offline injection overrides, and returns
## structured error details for UI-friendly reporting.

extends RefCounted
class_name ToolLauncher

const PathUtils = preload("res://scripts/utils/path_utils.gd")

const OgsLogger = preload("res://scripts/logging/logger.gd")
const CryptoUtils = preload("res://scripts/utils/crypto_utils.gd")

## Handles spawning external tools from the frozen stack with correct environment and working directory.
##
## This class is responsible for:
## - Resolving tool paths relative to the project directory
## - Rejecting absolute or project-escaping tool paths
## - Enforcing optional sha256 verification when provided
## - Building tool-specific launch arguments (e.g., Godot's --path flag)
## - Spawning processes in a way that respects air-gap constraints
## - Returning detailed error information for troubleshooting

## Error codes for launch failures
enum LaunchError {
	SUCCESS = 0,
	TOOL_PATH_MISSING = 1,   ## Tool path field provided but empty
	TOOL_NOT_FOUND = 2,      ## Executable file not found at resolved path
	INVALID_PROJECT_DIR = 3, ## Project directory is empty or invalid
	SPAWN_FAILED = 4,        ## OS.create_process() returned error
	OFFLINE_CONFIG_FAILED = 5, ## Offline tool configuration injection failed
	TOOL_PATH_ABSOLUTE = 6,     ## Tool path is absolute and disallowed
	TOOL_PATH_OUTSIDE_ROOT = 7, ## Tool path resolves outside the project root
	TOOL_HASH_INVALID = 8,      ## Tool sha256 value is invalid or unreadable
	TOOL_HASH_MISMATCH = 9,     ## Tool sha256 does not match file contents
	GODOT_PROJECT_INIT_FAILED = 10, ## Godot project.godot discovery/creation failed
	INVALID_TOOL_ENTRY = 11,     ## Missing required tool ID or version
	UNSUPPORTED_PLATFORM = 12    ## Current OS is not supported for executable discovery
}

## File extensions that are never standalone executables on Linux/BSD platforms.
const _NON_EXEC_EXTENSIONS: Array = [".so", ".py", ".txt", ".sh", ".json", ".xml",
	".cfg", ".ini", ".md", ".png", ".svg", ".jpg", ".desktop", ".mo", ".po",
	".a", ".la", ".pc"]


## Launches a tool from the manifest with the project directory as working context.
##
## @param tool_entry: Dictionary with keys: id, version, (optional) path
## @param project_dir: Absolute path to the project root (where stack.json lives)
## @return: Dictionary with keys: success (bool), error_code (int), error_message (String), pid (int, -1 if failed)
static func launch(tool_entry: Dictionary, project_dir: String, target_file: String = "") -> Dictionary:
	# Validate inputs
	if project_dir.is_empty():
		OgsLogger.warn("tool_launch_failed", {"component": "launcher", "reason": "empty_project_dir"})
		return _error_result(LaunchError.INVALID_PROJECT_DIR, "Project directory path is empty.")
	
	var tool_id = String(tool_entry.get("id", "unknown"))
	var tool_version = String(tool_entry.get("version", "unknown"))
	var full_tool_path := ""
	
	if tool_id == "unknown" or tool_version == "unknown":
		OgsLogger.warn("tool_launch_failed", {"component": "launcher", "reason": "invalid_entry"})
		return _error_result(LaunchError.INVALID_TOOL_ENTRY, "Invalid tool entry in stack.json")
		
	# Check if path is provided (legacy support for project-relative paths)
	if tool_entry.has("path"):
		var tool_path = String(tool_entry["path"])
		if tool_path.is_empty():
			OgsLogger.warn("tool_launch_failed", {"component": "launcher", "reason": "empty_path"})
			return _error_result(LaunchError.TOOL_PATH_MISSING, "Tool path is empty.")
		
		# Resolve tool path (relative paths only, within project root)
		if tool_path.is_absolute_path():
			OgsLogger.warn("tool_launch_failed", {"component": "launcher", "reason": "absolute_path"})
			return _error_result(LaunchError.TOOL_PATH_ABSOLUTE, "Tool path must be project-relative.")
		full_tool_path = project_dir.path_join(tool_path)
		if not PathUtils.is_path_under_root(full_tool_path, project_dir):
			OgsLogger.warn("tool_launch_failed", {"component": "launcher", "reason": "path_escape"})
			return _error_result(LaunchError.TOOL_PATH_OUTSIDE_ROOT, "Tool path escapes project root.")
	else:
		# Path not provided - resolve from library
		var resolver_result = _resolve_tool_from_library(LibraryManager.new(), tool_id, tool_version)
		if not resolver_result["success"]:
			OgsLogger.warn("tool_launch_failed", {"component": "launcher", "reason": "not_installed", "tool": tool_id})
			return _error_result(resolver_result["error_code"], resolver_result["error_message"])
		full_tool_path = String(resolver_result["executable_path"])
		
	if not _tool_path_exists(full_tool_path):
		OgsLogger.warn("tool_launch_failed", {"component": "launcher", "reason": "not_found", "absolute_path": full_tool_path})
		return _error_result(LaunchError.TOOL_NOT_FOUND, "Tool executable not found at: %s" % full_tool_path)

	var hash_check = _validate_tool_hash(tool_entry, full_tool_path)
	if not hash_check["success"]:
		OgsLogger.warn("tool_launch_failed", {"component": "launcher", "reason": "hash_check", "tool": tool_id})
		return _error_result(hash_check["error_code"], hash_check["error_message"])

	var launch_project_dir = project_dir
	if tool_id == "godot":
		var godot_project_result = _resolve_godot_project_dir(project_dir)
		if not godot_project_result["success"]:
			OgsLogger.warn("tool_launch_failed", {"component": "launcher", "reason": "godot_project_init", "tool": tool_id})
			return _error_result(godot_project_result["error_code"], godot_project_result["error_message"])
		launch_project_dir = String(godot_project_result["launch_project_dir"])
	
	# Build tool-specific arguments
	var args = _build_launch_arguments(tool_id, launch_project_dir, target_file)
	if OfflineEnforcer.is_offline():
		var inject = ToolConfigInjector.apply(tool_id, project_dir, launch_project_dir)
		if not inject["success"]:
			OgsLogger.warn("tool_launch_failed", {"component": "launcher", "reason": "offline_inject", "tool": tool_id})
			return _error_result(LaunchError.OFFLINE_CONFIG_FAILED, inject["error_message"])
		args.append_array(inject["args"])
	else:
		ToolConfigInjector.clear(tool_id, launch_project_dir)
	
	# Spawn the process
	var launch_path = _resolve_launch_path(full_tool_path, tool_id)
	if launch_path.is_empty():
		return _error_result(LaunchError.TOOL_NOT_FOUND, "macOS app bundle binary not found for tool: %s" % tool_id)
	var pid = OS.create_process(launch_path, args)
	if pid == -1:
		OgsLogger.error("tool_launch_failed", {"component": "launcher", "reason": "spawn_failed", "tool": tool_id})
		return _error_result(LaunchError.SPAWN_FAILED, "Failed to spawn process for tool: %s" % tool_id)
	OgsLogger.info("tool_launched", {"component": "launcher", "tool": tool_id, "project": project_dir.get_file()})
	
	return {
		"success": true,
		"error_code": LaunchError.SUCCESS,
		"error_message": "",
		"pid": pid
	}

## Resolves a launchable Godot project directory.
##
## Looks for an existing project.godot within the OGS project folder.
## If missing, creates a minimal project.godot under the OGS game/ folder
## using stack.json stack_name as the project name when available.
static func _resolve_godot_project_dir(project_dir: String) -> Dictionary:
	var existing_project_dir = _find_existing_godot_project_dir(project_dir)
	if not existing_project_dir.is_empty():
		return {
			"success": true,
			"launch_project_dir": existing_project_dir,
			"created": false
		}

	var project_name = _resolve_ogs_project_name(project_dir)
	var godot_project_dir = project_dir.path_join("game")
	var create_result = _create_godot_project_file(godot_project_dir, project_name)
	if not create_result["success"]:
		return {
			"success": false,
			"error_code": LaunchError.GODOT_PROJECT_INIT_FAILED,
			"error_message": create_result["error_message"]
		}

	OgsLogger.info("godot_project_created", {
		"component": "launcher",
		"project": project_dir.get_file(),
		"project_name": project_name
	})
	return {
		"success": true,
		"launch_project_dir": godot_project_dir,
		"created": true
	}


## Builds tool-specific launch arguments.
##
## Different tools require different arguments to operate in the project context:
## - Godot: --editor --path <project_dir> (opens the project in editor mode)
## - Blender, GIMP, Krita: (pass the target file directly if provided)
static func _build_launch_arguments(tool_id: String, project_dir: String, target_file: String = "") -> PackedStringArray:
	var args = PackedStringArray()
	
	match tool_id:
		"godot":
			# Force editor mode so launch never depends on a configured main scene.
			args.append("--editor")
			args.append("--path")
			args.append(project_dir)
		_:
			if not target_file.is_empty():
				args.append(target_file)
	
	return args

## Finds an existing Godot project.godot path and returns its parent directory.
static func _find_existing_godot_project_dir(project_dir: String) -> String:
	# Prefer canonical OGS layout first, then legacy locations.
	var common_paths = ["game/project.godot", "project_source/project.godot", "project.godot"]
	for relative_path in common_paths:
		var candidate = project_dir.path_join(relative_path)
		if FileAccess.file_exists(candidate):
			return candidate.get_base_dir()

	var recursive_match = _find_first_project_godot(project_dir, 3, 0)
	if recursive_match.is_empty():
		return ""
	return recursive_match.get_base_dir()

## Recursively searches for project.godot up to the provided depth.
static func _find_first_project_godot(directory: String, max_depth: int, depth: int) -> String:
	if depth > max_depth:
		return ""

	var project_file = directory.path_join("project.godot")
	if FileAccess.file_exists(project_file):
		return project_file

	var dir = DirAccess.open(directory)
	if dir == null:
		return ""

	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with(".") and entry != "tools":
			var nested_result = _find_first_project_godot(directory.path_join(entry), max_depth, depth + 1)
			if not nested_result.is_empty():
				dir.list_dir_end()
				return nested_result
		entry = dir.get_next()
	dir.list_dir_end()

	return ""

## Resolves the display project name from stack.json or falls back to folder name.
static func _resolve_ogs_project_name(project_dir: String) -> String:
	var stack_path = project_dir.path_join("stack.json")
	if FileAccess.file_exists(stack_path):
		var stack_file = FileAccess.open(stack_path, FileAccess.READ)
		if stack_file != null:
			var parse = JSON.parse_string(stack_file.get_as_text())
			stack_file.close()
			if parse is Dictionary:
				var stack_name = String(parse.get("stack_name", "")).strip_edges()
				if not stack_name.is_empty():
					return stack_name

	var fallback_name = project_dir.get_file().strip_edges()
	if fallback_name.is_empty():
		return "OGS Project"
	return fallback_name

## Creates a minimal Godot 4.x project.godot at the given Godot project directory.
static func _create_godot_project_file(godot_project_dir: String, project_name: String) -> Dictionary:
	var mkdir_result = DirAccess.make_dir_recursive_absolute(godot_project_dir)
	if mkdir_result != OK and not DirAccess.dir_exists_absolute(godot_project_dir):
		return {
			"success": false,
			"error_message": "Failed to create Godot project directory: %s" % godot_project_dir
		}

	var config_path = godot_project_dir.path_join("project.godot")
	var file = FileAccess.open(config_path, FileAccess.WRITE)
	if file == null:
		return {
			"success": false,
			"error_message": "Failed to create Godot project file at: %s" % config_path
		}

	var safe_name = project_name.replace("\\", "\\\\").replace("\"", "\\\"")
	var content = "config_version=5\n\n[application]\nconfig/name=\"%s\"\n" % safe_name
	file.store_string(content)
	file.close()
	return {"success": true}


## Helper to construct error result dictionaries.
static func _error_result(error_code: LaunchError, message: String) -> Dictionary:
	return {
		"success": false,
		"error_code": error_code,
		"error_message": message,
		"pid": -1
	}

## Resolves tool executable path from the library.
## Parameters:
##   library (LibraryManager): Library manager instance
##   tool_id (String): Tool identifier (e.g., "godot", "blender")
##   tool_version (String): Tool version (e.g., "4.7.2", "4.2")
## Returns:
##   Dictionary: {success: bool, error_code: int, error_message: String, executable_path: String}
static func _resolve_tool_from_library(library: LibraryManager, tool_id: String, tool_version: String) -> Dictionary:
	if not library.tool_exists(tool_id, tool_version):
		return {
			"success": false,
			"error_code": LaunchError.TOOL_NOT_FOUND,
			"error_message": "Tool %s v%s not found in library" % [tool_id, tool_version],
			"executable_path": ""
		}
	
	var tool_dir = library.get_tool_path(tool_id, tool_version)
	if tool_dir.is_empty():
		return {
			"success": false,
			"error_code": LaunchError.TOOL_NOT_FOUND,
			"error_message": "Failed to resolve library path for %s v%s" % [tool_id, tool_version],
			"executable_path": ""
		}
	
	# Try to find the exact executable path from the installed tool's portable metadata
	var metadata_path = tool_dir.path_join("ogs_metadata.json")
	if FileAccess.file_exists(metadata_path):
		var file = FileAccess.open(metadata_path, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(text) == OK:
				var metadata = json.data
				if typeof(metadata) == TYPE_DICTIONARY and metadata.has("executable_path"):
					var exe_path = tool_dir.path_join(metadata["executable_path"])
					if FileAccess.file_exists(exe_path):
						return {
							"success": true,
							"error_code": LaunchError.SUCCESS,
							"error_message": "",
							"executable_path": exe_path
						}
	
	# Fallback: Find executable within tool directory using legacy heuristics
	var executable_path = _find_executable_in_directory(tool_dir, tool_id)
	if executable_path.is_empty():
		return {
			"success": false,
			"error_code": LaunchError.TOOL_NOT_FOUND,
			"error_message": "No executable found in tool directory: %s" % tool_dir,
			"executable_path": ""
		}
	
	return {
		"success": true,
		"error_code": LaunchError.SUCCESS,
		"error_message": "",
		"executable_path": executable_path
	}

## Returns the executable file extension for the current platform.
static func _get_executable_extension() -> String:
	var os_name = OS.get_name()
	match os_name:
		"Windows":
			return ".exe"
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return ""
		"macOS":
			return ".app"
		_:
			return ""

## Returns true if the current platform is supported for executable discovery.
static func _is_platform_supported() -> bool:
	return OS.get_name() in ["Windows", "Linux", "macOS", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]

## Returns true if a tool path exists as a file or, on macOS, as a .app directory bundle.
static func _tool_path_exists(tool_path: String) -> bool:
	if FileAccess.file_exists(tool_path):
		return true
	# On macOS, .app bundles are directories; also accept them as valid tool paths.
	if tool_path.to_lower().ends_with(".app") and DirAccess.dir_exists_absolute(tool_path):
		return true
	return false

## Resolves the launchable executable path for a tool path.
## On macOS, .app bundles are directories; this returns the binary inside the bundle.
## On all other platforms, returns the path unchanged.
## Returns an empty string when the bundle binary cannot be located on macOS.
static func _resolve_launch_path(tool_path: String, tool_id: String) -> String:
	if OS.get_name() == "macOS" and tool_path.to_lower().ends_with(".app"):
		# macOS .app bundle: the binary lives at <Name>.app/Contents/MacOS/<Name>
		var bundle_name = tool_path.get_file().get_basename()
		var binary = tool_path.path_join("Contents/MacOS").path_join(bundle_name)
		if FileAccess.file_exists(binary):
			return binary
		# Fallback: try the tool_id as the binary name
		var fallback = tool_path.path_join("Contents/MacOS").path_join(tool_id)
		if FileAccess.file_exists(fallback):
			return fallback
		# Binary not found inside bundle; return empty to signal launch failure.
		OgsLogger.warn("tool_launch_failed", {
			"component": "launcher",
			"reason": "app_bundle_binary_not_found",
			"tool_id": tool_id
		})
		return ""
	return tool_path

## Checks whether a filename looks like an executable on the current platform.
static func _is_executable_filename(file_name: String) -> bool:
	var ext = _get_executable_extension()
	if ext.is_empty():
		# On Linux/BSD, executables may or may not have dots (e.g. Godot_v4.7.2-stable_linux.x86_64).
		# Reject files with known non-executable extensions (.so, .py, .txt, .sh, .json, etc.).
		var lower = file_name.to_lower()
		for nex in _NON_EXEC_EXTENSIONS:
			if lower.ends_with(nex):
				return false
		return not file_name.get_basename().is_empty()
	else:
		return file_name.to_lower().ends_with(ext)

## Finds the main executable within a tool directory.
## Uses tool-specific conventions to locate the executable.
## Parameters:
##   directory (String): Absolute path to tool directory
##   tool_id (String): Tool identifier for convention-based search
## Returns:
##   String: Absolute path to executable, or empty string if not found
static func _find_executable_in_directory(directory: String, tool_id: String) -> String:
	if not _is_platform_supported():
		OgsLogger.error("unsupported_platform", {
			"component": "launcher",
			"os": OS.get_name(),
			"tool_id": tool_id
		})
		return ""

	var dir = DirAccess.open(directory)
	if dir == null:
		return ""

	var ext = _get_executable_extension()

	# Tool-specific executable naming conventions
	match tool_id:
		"godot":
			# Look for Godot_*<ext> or godot<ext>, prioritizing non-console binaries
			dir.list_dir_begin()
			var godot_file = dir.get_next()
			var godot_console_fallback := ""
			while godot_file != "":
				if godot_file.to_lower().begins_with("godot") and _is_executable_filename(godot_file):
					var exe_path = directory.path_join(godot_file)
					if _tool_path_exists(exe_path):
						var lower = godot_file.to_lower()
						if not _is_console_binary_name(lower):
							dir.list_dir_end()
							return exe_path
						elif godot_console_fallback.is_empty():
							godot_console_fallback = exe_path
				godot_file = dir.get_next()
			dir.list_dir_end()
			if not godot_console_fallback.is_empty():
				OgsLogger.warn("tool_launcher_fallback_executable_used", {
					"component": "launcher",
					"directory": directory,
					"executable": godot_console_fallback.get_file(),
					"reason": "console_wrapper_fallback",
					"tool_id": tool_id
				})
				return godot_console_fallback
		"blender":
			var blender_exe = directory.path_join("blender" + ext)
			if _tool_path_exists(blender_exe):
				return blender_exe
		"krita":
			var krita_bin = directory.path_join("bin").path_join("krita" + ext)
			if _tool_path_exists(krita_bin):
				return krita_bin
			var krita_exe = directory.path_join("krita" + ext)
			if _tool_path_exists(krita_exe):
				return krita_exe
		"audacity":
			var audacity_exe = directory.path_join("audacity" + ext)
			if _tool_path_exists(audacity_exe):
				return audacity_exe

	# Fallback: scan for executable files or .app bundles in directory
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var exe_files = []
	while file_name != "":
		var is_app_bundle = file_name.to_lower().ends_with(".app") and dir.current_is_dir()
		if (not dir.current_is_dir() and _is_executable_filename(file_name)) or is_app_bundle:
			exe_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	if exe_files.is_empty():
		return ""

	# 1. Exact match with tool_id (prefer non-console)
	var exact_candidates = []
	for exe in exe_files:
		if exe.get_basename().to_lower() == tool_id.to_lower():
			if not _is_console_binary_name(exe):
				return directory.path_join(exe)
			exact_candidates.append(exe)
	if not exact_candidates.is_empty():
		OgsLogger.warn("tool_launcher_fallback_executable_used", {
			"component": "launcher",
			"directory": directory,
			"executable": exact_candidates[0],
			"reason": "exact_match_console",
			"tool_id": tool_id
		})
		return directory.path_join(exact_candidates[0])

	# 2. Contains tool_id (prefer non-console)
	var contains_candidates = []
	for exe in exe_files:
		if exe.to_lower().contains(tool_id.to_lower()):
			if not _is_console_binary_name(exe):
				OgsLogger.warn("tool_launcher_fallback_executable_used", {
					"component": "launcher",
					"directory": directory,
					"executable": exe,
					"reason": "heuristic_contains_tool_id",
					"tool_id": tool_id
				})
				return directory.path_join(exe)
			contains_candidates.append(exe)

	if not contains_candidates.is_empty():
		OgsLogger.warn("tool_launcher_fallback_executable_used", {
			"component": "launcher",
			"directory": directory,
			"executable": contains_candidates[0],
			"reason": "heuristic_contains_tool_id_console",
			"tool_id": tool_id
		})
		return directory.path_join(contains_candidates[0])

	# 3. Filter out common uninstaller/setup names and console binaries, and pick the first
	var filtered_candidates = []
	for exe in exe_files:
		var lower_name = exe.to_lower()
		if not lower_name.begins_with("unins") and not lower_name.begins_with("setup"):
			if not _is_console_binary_name(lower_name):
				OgsLogger.warn("tool_launcher_fallback_executable_used", {
					"component": "launcher",
					"directory": directory,
					"executable": exe,
					"reason": "heuristic_first_non_installer",
					"tool_id": tool_id
				})
				return directory.path_join(exe)
			filtered_candidates.append(exe)

	if not filtered_candidates.is_empty():
		OgsLogger.warn("tool_launcher_fallback_executable_used", {
			"component": "launcher",
			"directory": directory,
			"executable": filtered_candidates[0],
			"reason": "heuristic_first_console",
			"tool_id": tool_id
		})
		return directory.path_join(filtered_candidates[0])

	# 4. Absolute fallback
	var chosen = exe_files[0]
	OgsLogger.warn("tool_launcher_fallback_executable_used", {
		"component": "launcher",
		"directory": directory,
		"executable": chosen,
		"reason": "arbitrary_first_executable",
		"tool_id": tool_id
	})
	return directory.path_join(chosen)

## Checks if an executable filename corresponds to a console wrapper.
static func _is_console_binary_name(name: String) -> bool:
	var lower = name.to_lower()
	return lower.ends_with("_console.exe") or lower.ends_with("_console") or lower.contains("console")


## Validates sha256 when present in the tool entry.
static func _validate_tool_hash(tool_entry: Dictionary, full_tool_path: String) -> Dictionary:
	if not tool_entry.has("sha256"):
		return {"success": true}
	var sha_value = String(tool_entry.get("sha256", "")).strip_edges().to_lower()
	if sha_value.is_empty() or not _is_hex_sha256(sha_value):
		return {
			"success": false,
			"error_code": LaunchError.TOOL_HASH_INVALID,
			"error_message": "Tool sha256 value is invalid."
		}
	var hash_result = CryptoUtils.compute_sha256(full_tool_path)
	if not hash_result["success"]:
		return {
			"success": false,
			"error_code": LaunchError.TOOL_HASH_INVALID,
			"error_message": hash_result["error_message"]
		}
	if hash_result["sha256"] != sha_value:
		return {
			"success": false,
			"error_code": LaunchError.TOOL_HASH_MISMATCH,
			"error_message": "Tool sha256 does not match file contents."
		}
	return {"success": true}

## Validates sha256 hex format (64 hex characters).
static func _is_hex_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		var code = character.unicode_at(0)
		var is_digit = code >= 48 and code <= 57
		var is_lower = code >= 97 and code <= 102
		var is_upper = code >= 65 and code <= 70
		if not (is_digit or is_lower or is_upper):
			return false
	return true

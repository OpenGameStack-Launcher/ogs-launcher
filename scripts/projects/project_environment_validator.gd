## ProjectEnvironmentValidator: Validates that a project's required tools are available.
##
## Checks if all tools defined in stack.json exist in the central library.
## Provides detailed reporting on missing tools and their status.
##
## Usage:
##   var validator = ProjectEnvironmentValidator.new()
##   var validation = validator.validate_project(project_dir)
##   if not validation.ready:
##       print("Missing tools: " + str(validation.missing_tools))
##
## Validation Result:
##   {
##       "valid": bool,               # All tools found
##       "ready": bool,               # Safe to launch
##       "missing_tools": Array,      # Tool entries missing from library
##       "errors": Array[String]      # Validation error messages
##   }

extends RefCounted
class_name ProjectEnvironmentValidator

const OgsLogger = preload("res://scripts/logging/logger.gd")

var library: LibraryManager

func _init() -> void:
	library = LibraryManager.new()

## Validates that all tools in a project's stack.json exist in the library or project.
## Parameters:
##   project_dir (String): Path to project folder
##   use_project_tools (bool): When true, checks tools relative to project_dir
## Returns:
##   Dictionary: {
##       "valid": bool,
##       "ready": bool,
##       "missing_tools": Array[Dictionary],
##       "errors": Array[String]
##   }
func validate_project(project_dir: String, use_project_tools: bool = false) -> Dictionary:
	var result = {
		"valid": false,
		"ready": false,
		"missing_tools": [],
		"errors": []
	}
	
	if project_dir.is_empty():
		result["errors"].append("Project directory is empty")
		return result
	
	# Load manifest
	var stack_path = project_dir.path_join("stack.json")
	if not FileAccess.file_exists(stack_path):
		result["errors"].append("stack.json not found")
		return result
	
	var manifest = StackManifest.load_from_file(stack_path)
	if not manifest.is_valid():
		# Allow newly-created projects with empty tools list.
		if not _is_manifest_acceptable_for_project(manifest):
			result["errors"].append_array(manifest.errors)
			return result
	
	# Check each tool
	var missing = []
	for tool_entry in manifest.tools:
		var tool_id = tool_entry.get("id", "")
		var version = tool_entry.get("version", "")
		var tool_path = String(tool_entry.get("path", ""))
		
		if tool_id.is_empty() or version.is_empty():
			result["errors"].append("Tool entry missing id or version")
			continue
		
		if use_project_tools:
			if tool_path.is_empty():
				missing.append({"tool_id": tool_id, "version": version})
				OgsLogger.debug("tool_missing_from_project", {
					"component": "projects",
					"tool_id": tool_id,
					"version": version,
					"project": project_dir,
					"reason": "missing_path"
				})
				continue
			
			var resolved_path = tool_path
			if not tool_path.is_absolute_path():
				resolved_path = project_dir.path_join(tool_path)
			
			if not FileAccess.file_exists(resolved_path):
				missing.append({"tool_id": tool_id, "version": version})
				OgsLogger.debug("tool_missing_from_project", {
					"component": "projects",
					"tool_id": tool_id,
					"version": version,
					"project": project_dir,
					"path": resolved_path
				})
		else:
			if not library.tool_exists(tool_id, version):
				missing.append({"tool_id": tool_id, "version": version})
				OgsLogger.debug("tool_missing_from_library", {
					"component": "projects",
					"tool_id": tool_id,
					"version": version,
					"project": project_dir
				})
	
	result["missing_tools"] = missing
	result["valid"] = true
	result["ready"] = missing.is_empty()
	
	if result["ready"]:
		OgsLogger.info("environment_validated", {
			"component": "projects",
			"project": project_dir,
			"status": "ready"
		})
	else:
		OgsLogger.warn("environment_incomplete", {
			"component": "projects",
			"project": project_dir,
			"missing_count": missing.size()
		})
	
	return result

## Determines whether manifest errors are acceptable for project readiness checks.
## Parameters:
##   manifest (StackManifest): Parsed manifest to evaluate
## Returns:
##   bool: True if manifest is valid or has only tools_empty warning
func _is_manifest_acceptable_for_project(manifest: StackManifest) -> bool:
	if manifest.is_valid():
		return true
	return manifest.errors.size() == 1 and manifest.errors[0] == "tools_empty"

## Returns list of tools needed from the library.
## Useful for hydration UI to know what to download.
## Parameters:
##   missing_tools (Array): Array of tool entries from validation
## Returns:
##   Array[Dictionary]: [{
##       "tool_id": String,
##       "version": String,
##   }]
func get_download_list(missing_tools: Array) -> Array:
	var downloads = []
	for tool_entry in missing_tools:
		downloads.append({
			"tool_id": tool_entry.get("tool_id", ""),
			"version": tool_entry.get("version", "")
		})
	return downloads

## Checks if the library itself exists and is accessible.
## Returns:
##   Dictionary: {"accessible": bool, "path": String}
func is_library_accessible() -> Dictionary:
	var lib_root = library.get_library_root()
	var accessible = DirAccess.dir_exists_absolute(lib_root) or DirAccess.make_dir_absolute(lib_root) == OK
	
	return {
		"accessible": accessible,
		"path": lib_root
	}

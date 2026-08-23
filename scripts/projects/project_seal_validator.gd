## ProjectSealValidator: Validates project readiness for sealing.
##
## Ensures the target project directory exists, stack.json is valid,
## and required tools are present in the central library.

extends RefCounted
class_name ProjectSealValidator

## Validates a project before seal operations begin.
## Parameters:
## project_path (String): Absolute path to project
## library (LibraryManager): Library manager instance for tool lookups
## Returns:
## Dictionary: {"success": bool, "errors": Array, "manifest": StackManifest}
func validate_project(project_path: String, library: LibraryManager) -> Dictionary:
	## Checks project folder, manifest validity, and tool availability.
	var result = {
		"success": false,
		"errors": [],
		"manifest": null
	}

	if not DirAccess.dir_exists_absolute(project_path):
		result.errors.append("Project directory does not exist: %s" % project_path)
		return result

	var stack_path = project_path.path_join("stack.json")
	if not FileAccess.file_exists(stack_path):
		result.errors.append("stack.json not found at: %s" % stack_path)
		return result

	var manifest = StackManifest.load_from_file(stack_path)
	if not manifest.is_valid():
		result.errors.append("stack.json is invalid: %s" % str(manifest.errors))
		return result

	for tool in manifest.tools:
		var tool_id = tool.get("id", "")
		var version = tool.get("version", "")
		if not library.tool_exists(tool_id, version):
			result.errors.append("Tool not found in library: %s v%s" % [tool_id, version])

	if not result.errors.is_empty():
		return result

	result.success = true
	result.manifest = manifest
	return result

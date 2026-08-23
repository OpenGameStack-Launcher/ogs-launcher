## ProjectSealerTestHelpers: Shared fixtures and cleanup for ProjectSealer tests.

extends RefCounted
class_name ProjectSealerTestHelpers

## Creates a temporary project + temporary library tool fixture for seal success tests.
## Parameters:
## prefix (String): Prefix for generated fixture directories
## Returns:
## Dictionary: {"success": bool, "error": String, "project_dir": String, "tool_id": String, "version": String, "library_tool_root": String}
func create_seal_success_fixture(prefix: String) -> Dictionary:
	## Builds a deterministic fixture that allows ProjectSealer success-path testing.
	var suffix = str(Time.get_unix_time_from_system()) + "_" + str(Time.get_ticks_usec())
	var project_dir = "user://%s_%s" % [prefix, suffix]
	var tool_id = "sealer_tool_" + suffix
	var version = "1.0.0"

	DirAccess.make_dir_recursive_absolute(project_dir)
	var stack_file = FileAccess.open(project_dir.path_join("stack.json"), FileAccess.WRITE)
	if stack_file == null:
		return {"success": false, "error": "Cannot create stack.json for fixture"}

	stack_file.store_string('{"schema_version": 1, "stack_name": "test_stack", "tools": [{"id": "%s", "version": "%s", "path": "tools/%s"}]}' % [tool_id, version, tool_id])

	var resolver = PathResolver.new()
	var library_tool_dir = resolver.get_tool_path(tool_id, version)
	if library_tool_dir.is_empty():
		remove_directory_recursive(project_dir)
		return {"success": false, "error": "Cannot resolve library path for fixture tool"}

	DirAccess.make_dir_recursive_absolute(library_tool_dir.path_join("bin"))
	var tool_binary = FileAccess.open(library_tool_dir.path_join("bin").path_join("tool.exe"), FileAccess.WRITE)
	if tool_binary == null:
		remove_directory_recursive(project_dir)
		remove_directory_recursive(resolver.get_tool_path(tool_id, "").trim_suffix("/"))
		return {"success": false, "error": "Cannot create fixture tool binary"}

	tool_binary.store_string("fixture-binary")

	var tool_readme = FileAccess.open(library_tool_dir.path_join("README.txt"), FileAccess.WRITE)
	if tool_readme != null:
		tool_readme.store_string("fixture readme")

	return {
		"success": true,
		"project_dir": project_dir,
		"tool_id": tool_id,
		"version": version,
		"library_tool_root": resolver.get_tool_path(tool_id, "").trim_suffix("/")
	}

## Cleans temporary fixture directories created for tests.
## Parameters:
## fixture (Dictionary): Fixture dictionary from create_seal_success_fixture()
func cleanup_seal_fixture(fixture: Dictionary) -> void:
	## Deletes test project and temporary library tool directories.
	if fixture.has("project_dir"):
		remove_directory_recursive(String(fixture.project_dir))
	if fixture.has("library_tool_root"):
		remove_directory_recursive(String(fixture.library_tool_root))

## Removes a directory recursively if it exists.
## Parameters:
## path (String): Directory path to remove
func remove_directory_recursive(path: String) -> void:
	## Recursively deletes files and directories for fixture cleanup.
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return

	var dir = DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var item_path = path.path_join(name)
			if dir.current_is_dir():
				remove_directory_recursive(item_path)
			else:
				DirAccess.remove_absolute(item_path)
		name = dir.get_next()

	DirAccess.remove_absolute(path)

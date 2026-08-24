## ProjectSealToolCopier: Copies required tools into local project tools folder.
##
## Implements recursive directory copy operations used during the
## "Seal for Delivery" workflow.

extends RefCounted
class_name ProjectSealToolCopier

const OgsLogger = preload("res://scripts/logging/logger.gd")
const _COPY_CHUNK_SIZE := 1_048_576  # 1 MB

## Copies all manifest tools from central library to project ./tools.
## Parameters:
## project_path (String): Absolute project path
## manifest (StackManifest): Parsed and validated stack manifest
## library (LibraryManager): Library manager instance for tool path resolution
## Returns:
## Dictionary: {"success": bool, "errors": Array, "tools_copied": Array}
func copy_tools_to_local(project_path: String, manifest: StackManifest, library: LibraryManager) -> Dictionary:
	## Copies all required tools from library into the project-local tools folder.
	var result = {
		"success": false,
		"errors": [],
		"tools_copied": []
	}

	var tools_dir = project_path.path_join("tools")
	if not DirAccess.dir_exists_absolute(tools_dir):
		var dir = DirAccess.open(project_path)
		if dir == null:
			result.errors.append("Cannot open project directory for writing: %s" % project_path)
			return result

		var make_err = dir.make_dir("tools")
		if make_err != OK:
			result.errors.append("Failed to create ./tools directory: %s" % error_string(make_err))
			return result

	for tool in manifest.tools:
		var tool_id = tool.get("id", "")
		var version = tool.get("version", "")
		var source_path = library.get_tool_path(tool_id, version)
		if source_path.is_empty():
			result.errors.append("Cannot resolve tool path: %s v%s" % [tool_id, version])
			continue

		var dest_path = tools_dir.path_join("%s_%s" % [tool_id, version])
		var copy_err = _copy_directory_recursive(source_path, dest_path)
		if copy_err != OK:
			result.errors.append("Failed to copy %s v%s: %s" % [tool_id, version, error_string(copy_err)])
			continue

		result.tools_copied.append("%s v%s" % [tool_id, version])
		OgsLogger.debug("tool_copied_to_sealed", {
			"component": "sealer",
			"tool_id": tool_id,
			"version": version
		})

	if not result.errors.is_empty():
		return result

	result.success = true
	return result

## Recursively copies one directory to another.
## Parameters:
## source (String): Source directory path
## dest (String): Destination directory path
## Returns:
## int: Godot error code (OK on success)
func _copy_directory_recursive(source: String, dest: String) -> int:
	## Copies nested directory content preserving structure.
	if not DirAccess.dir_exists_absolute(dest):
		DirAccess.make_dir_recursive_absolute(dest)

	var dir = DirAccess.open(source)
	if dir == null:
		return FAILED

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var source_item = source.path_join(file_name)
		var dest_item = dest.path_join(file_name)
		if dir.current_is_dir():
			var recurse_err = _copy_directory_recursive(source_item, dest_item)
			if recurse_err != OK:
				return recurse_err
		else:
			var file_err = _copy_file(source_item, dest_item)
			if file_err != OK:
				return file_err

		file_name = dir.get_next()

	return OK

## Copies a single file from source to destination using chunked reads.
## Uses 1MB chunks to avoid loading entire large binaries into memory.
## Parameters:
## source (String): Source file path
## dest (String): Destination file path
## Returns:
## int: Godot error code (OK on success)
func _copy_file(source: String, dest: String) -> int:
	## Copies one file in 1MB chunks to keep memory usage bounded.
	var file = FileAccess.open(source, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()

	var out_file = FileAccess.open(dest, FileAccess.WRITE)
	if out_file == null:
		file.close()
		return FileAccess.get_open_error()

	while not file.eof_reached():
		var chunk = file.get_buffer(_COPY_CHUNK_SIZE)
		if chunk.size() == 0:
			break
		out_file.store_buffer(chunk)
		var write_err = out_file.get_error()
		if write_err != OK:
			file.close()
			out_file.close()
			return write_err

	file.close()
	out_file.close()
	return OK

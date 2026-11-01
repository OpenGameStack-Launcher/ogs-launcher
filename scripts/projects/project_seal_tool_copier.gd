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
## progress_callback (Callable): Optional callback for progress reporting (phase, current, total)
## Returns:
## Dictionary: {"success": bool, "errors": Array, "tools_copied": Array}
func copy_tools_to_local(
	project_path: String,
	manifest: StackManifest,
	library: LibraryManager,
	progress_callback: Callable = Callable()
) -> Dictionary:
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

	# Pre-count total files across all tools before copying starts
	var total_files: int = 0
	for tool in manifest.tools:
		var tool_id = tool.get("id", "")
		var version = tool.get("version", "")
		var source_path = library.get_tool_path(tool_id, version)
		if not source_path.is_empty() and DirAccess.dir_exists_absolute(source_path):
			total_files += _count_files_recursive(source_path)

	if total_files == 0:
		_notify_progress(progress_callback, "Step 1/2: Copying tools", 0, 0)
	else:
		_notify_progress(progress_callback, "Step 1/2: Copying tools", 0, total_files)

	var progress_context: Dictionary = {
		"current": 0,
		"total": total_files
	}

	for tool in manifest.tools:
		var tool_id = tool.get("id", "")
		var version = tool.get("version", "")
		var source_path = library.get_tool_path(tool_id, version)
		if source_path.is_empty():
			result.errors.append("Cannot resolve tool path: %s v%s" % [tool_id, version])
			continue

		var dest_path = tools_dir.path_join("%s_%s" % [tool_id, version])
		var copy_err = _copy_directory_recursive(source_path, dest_path, progress_callback, progress_context)
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

## Recursively counts total files within a directory.
## Parameters:
## dir_path (String): Directory to count files in
## Returns:
## int: Total number of files
func count_files_recursive(dir_path: String) -> int:
	## Public helper to count files in a directory.
	return _count_files_recursive(dir_path)

## Recursively counts total files within a directory hierarchy.
func _count_files_recursive(dir_path: String) -> int:
	## Recursively traverses directory to count non-directory files.
	var count: int = 0
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return 0

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var item_path = dir_path.path_join(file_name)
			if dir.current_is_dir():
				count += _count_files_recursive(item_path)
			else:
				count += 1
		file_name = dir.get_next()

	dir.list_dir_end()
	return count

## Recursively copies one directory to another.
## Parameters:
## source (String): Source directory path
## dest (String): Destination directory path
## progress_callback (Callable): Optional progress callback
## progress_context (Dictionary): Shared mutable tracking dictionary with "current" and "total"
## Returns:
## int: Godot error code (OK on success)
func _copy_directory_recursive(
	source: String,
	dest: String,
	progress_callback: Callable = Callable(),
	progress_context: Dictionary = {}
) -> int:
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
			var recurse_err = _copy_directory_recursive(source_item, dest_item, progress_callback, progress_context)
			if recurse_err != OK:
				dir.list_dir_end()
				return recurse_err
		else:
			var file_err = _copy_file(source_item, dest_item)
			if file_err != OK:
				dir.list_dir_end()
				return file_err
			if not progress_context.is_empty():
				progress_context["current"] = int(progress_context.get("current", 0)) + 1
				_notify_progress(
					progress_callback,
					"Step 1/2: Copying tools",
					int(progress_context["current"]),
					int(progress_context["total"])
				)

		file_name = dir.get_next()

	dir.list_dir_end()
	return OK

## Safely invokes progress callback supporting both 2-arg and 3-arg signatures.
static func _notify_progress(callback: Callable, phase: String, current: int, total: int) -> void:
	## Invokes progress callback if valid, forwarding phase, current, and total.
	if not callback.is_valid():
		return
	var arg_count: int = callback.get_argument_count()
	if arg_count == 2:
		callback.call(current, total)
	else:
		callback.call(phase, current, total)

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

	var final_write_err = out_file.get_error()
	file.close()
	out_file.close()
	if final_write_err != OK:
		return final_write_err
	return OK

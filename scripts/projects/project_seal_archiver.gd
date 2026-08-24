## ProjectSealArchiver: Builds final sealed zip artifacts for delivery.

extends RefCounted
class_name ProjectSealArchiver

const OgsLogger = preload("res://scripts/logging/logger.gd")

## Creates zip archive for project and returns output metadata.
## Parameters:
## project_path (String): Absolute project path to archive
## Returns:
## Dictionary: {"success": bool, "errors": Array, "zip_path": String, "size_mb": float}
func create_sealed_zip(project_path: String) -> Dictionary:
	## Packages full project content into a timestamped zip archive.
	var result = {
		"success": false,
		"errors": [],
		"zip_path": "",
		"size_mb": 0.0
	}

	var project_name = project_path.get_file()
	var parent_path = project_path.get_base_dir()
	var timestamp = Time.get_datetime_string_from_system().replace("T", "_").replace(":", "-")
	var zip_name = "%s_Sealed_%s.zip" % [project_name, timestamp]
	var zip_path = parent_path.path_join(zip_name) if not parent_path.is_empty() else zip_name

	if FileAccess.file_exists(zip_path):
		var remove_err = DirAccess.remove_absolute(zip_path)
		if remove_err != OK:
			result.errors.append("Failed to replace existing zip archive: %s" % error_string(remove_err))
			OgsLogger.error("sealed_zip_replace_failed", {
				"component": "sealer",
				"zip_path": zip_path,
				"error": error_string(remove_err)
			})
			return result

	var files_to_pack = _collect_files_recursive(project_path)
	files_to_pack.sort()

	OgsLogger.info("sealed_zip_packaging_start", {
		"component": "sealer",
		"project_path": project_path,
		"zip_path": zip_path,
		"file_count": files_to_pack.size()
	})

	var zipper = ZIPPacker.new()
	var open_error = zipper.open(zip_path)
	if open_error != OK:
		result.errors.append("Failed to create zip archive: %s" % error_string(open_error))
		OgsLogger.error("sealed_zip_open_failed", {
			"component": "sealer",
			"zip_path": zip_path,
			"error": error_string(open_error)
		})
		return result

	var normalized_project_path = project_path.replace("\\", "/")
	for abs_file_path in files_to_pack:
		var normalized_abs_path = abs_file_path.replace("\\", "/")
		var relative_path = normalized_abs_path.trim_prefix(normalized_project_path + "/")
		if relative_path.is_empty():
			continue

		var source_file = FileAccess.open(abs_file_path, FileAccess.READ)
		if source_file == null:
			zipper.close()
			result.errors.append("Failed to read file for packaging: %s" % abs_file_path)
			OgsLogger.error("sealed_zip_read_failed", {
				"component": "sealer",
				"file": relative_path,
				"error": error_string(FileAccess.get_open_error())
			})
			return result

		var start_error = zipper.start_file(relative_path)
		if start_error != OK:
			zipper.close()
			result.errors.append("Failed to add file to zip: %s" % relative_path)
			OgsLogger.error("sealed_zip_start_file_failed", {
				"component": "sealer",
				"file": relative_path,
				"error": error_string(start_error)
			})
			return result

		var chunk_size_limit = 1_048_576  # 1 MB
		var remaining = source_file.get_length()
		while remaining > 0:
			var chunk_size = mini(remaining, chunk_size_limit)
			var file_bytes = source_file.get_buffer(chunk_size)
			var bytes_read = file_bytes.size()
			if bytes_read == 0:
				source_file.close()
				zipper.close_file()
				zipper.close()
				result.errors.append("Failed to read bytes from file: %s" % relative_path)
				OgsLogger.error("sealed_zip_read_zero_bytes", {
					"component": "sealer",
					"file": relative_path
				})
				return result
			var write_error = zipper.write_file(file_bytes)
			if write_error != OK:
				source_file.close()
				zipper.close_file()
				zipper.close()
				result.errors.append("Failed to write file to zip: %s" % relative_path)
				OgsLogger.error("sealed_zip_write_failed", {
					"component": "sealer",
					"file": relative_path,
					"error": error_string(write_error)
				})
				return result
			remaining -= bytes_read

		source_file.close()
		zipper.close_file()

	zipper.close()

	if not FileAccess.file_exists(zip_path):
		result.errors.append("Zip archive was not created")
		OgsLogger.error("sealed_zip_missing_after_close", {
			"component": "sealer",
			"zip_path": zip_path
		})
		return result

	var zip_file = FileAccess.open(zip_path, FileAccess.READ)
	if zip_file == null:
		result.errors.append("Failed to read created zip archive")
		OgsLogger.error("sealed_zip_metadata_read_failed", {
			"component": "sealer",
			"zip_path": zip_path,
			"error": error_string(FileAccess.get_open_error())
		})
		return result

	var size_bytes = zip_file.get_length()
	result.success = true
	result.zip_path = zip_path
	result.size_mb = size_bytes / (1024.0 * 1024.0)

	OgsLogger.info("sealed_zip_created", {
		"component": "sealer",
		"zip_path": zip_path,
		"size_mb": result.size_mb,
		"file_count": files_to_pack.size()
	})

	return result

## Recursively collects files under a directory.
## Parameters:
## dir_path (String): Absolute directory path to scan
## Returns:
## Array[String]: Absolute file paths
func _collect_files_recursive(dir_path: String) -> Array[String]:
	## Builds a complete file list used by zip packaging.
	var files: Array[String] = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return files

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path = dir_path.path_join(file_name)
		if dir.current_is_dir():
			files.append_array(_collect_files_recursive(full_path))
		else:
			files.append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
	return files

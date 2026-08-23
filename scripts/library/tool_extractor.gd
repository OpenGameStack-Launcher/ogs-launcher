## ToolExtractor: Handles extraction of downloaded tools into the library.
##
## Responsible for unzipping tool archives and placing their contents into
## the proper library structure. Handles nested zip structures (where the
## actual tool binaries are in a subdirectory of the archive).
##
## Extraction workflow:
## 1. Download tool .zip to a temporary location
## 2. Call extract_to_library() with the .zip path
## 3. Extractor unzips to [LIBRARY_ROOT]/[tool_id]/[version]/
## 4. If extraction succeeds, temp .zip is deleted
## 5. LibraryManager can then discover the tool
##
## Example nested structure handling:
## Archive: godot-4.3-windows-x64.zip
## Contents:
## godot-4.3-windows-x64/
## godot.exe
## ... other files
## Result after extraction:
## [LIBRARY_ROOT]/godot/4.3/godot.exe
##
## Usage:
## var extractor = ToolExtractor.new()
## var result = extractor.extract_to_library(
## "C:/Downloads/godot-4.3.zip",
## "godot",
## "4.3"
## )
## if result.success:
## print("Tool ready at: " + result.tool_path)

extends RefCounted
class_name ToolExtractor

const OgsLogger = preload("res://scripts/logging/logger.gd")

## Error codes for extraction failures
enum ExtractionError {
	SUCCESS = 0,
	SOURCE_NOT_FOUND = 1,
	INVALID_ARCHIVE = 2,
	EXTRACTION_FAILED = 3,
	CLEANUP_FAILED = 4,
	INVALID_PARAMETERS = 5,
}

var path_resolver: PathResolver

func _init():
	path_resolver = PathResolver.new()

## Extracts a tool archive to the library.
##
## Parameters:
## archive_path (String): Full path to the .zip file
## tool_id (String): Tool identifier (e.g., "godot")
## version (String): Version string (e.g., "4.3")
##
## Returns:
## Dictionary: {
## "success": bool,
## "error_code": int,
## "error_message": String,
## "tool_path": String (set if success),
## "extracted_files": int (count of files extracted)
## }
func extract_to_library(archive_path: String, tool_id: String, version: String, is_cancelled_callback: Callable = Callable(), progress_callback: Callable = Callable()) -> Dictionary:
	var result = {
		"success": false,
		"error_code": ExtractionError.INVALID_PARAMETERS,
		"error_message": "",
		"tool_path": "",
		"extracted_files": 0
	}
	
	# Validate parameters
	if archive_path.is_empty() or tool_id.is_empty() or version.is_empty():
		result["error_message"] = "Missing required parameters"
		OgsLogger.error("extraction_failed", {
			"component": "library",
			"reason": "invalid parameters",
			"tool_id": tool_id,
			"version": version
		})
		return result
	
	# Check archive exists
	if not FileAccess.file_exists(archive_path):
		result["error_code"] = ExtractionError.SOURCE_NOT_FOUND
		result["error_message"] = "Archive file not found: %s" % archive_path
		OgsLogger.error("extraction_failed", {
			"component": "library",
			"reason": "archive not found",
			"archive": archive_path,
			"tool_id": tool_id
		})
		return result
	
	# Get target directory
	var target_dir = path_resolver.get_tool_path(tool_id, version)
	if target_dir.is_empty():
		result["error_code"] = ExtractionError.INVALID_PARAMETERS
		result["error_message"] = "Failed to resolve target directory"
		OgsLogger.error("extraction_failed", {
			"component": "library",
			"reason": "path resolution failed",
			"tool_id": tool_id,
			"version": version
		})
		return result
	
	# Create target directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(target_dir):
		var err = DirAccess.make_dir_recursive_absolute(target_dir)
		if err != OK:
			result["error_code"] = ExtractionError.EXTRACTION_FAILED
			result["error_message"] = "Failed to create target directory"
			OgsLogger.error("extraction_failed", {
				"component": "library",
				"reason": "mkdir failed",
				"target": target_dir,
				"tool_id": tool_id
			})
			return result
	
	# Perform extraction
	var extraction_result = _extract_zip(archive_path, target_dir, is_cancelled_callback, progress_callback)
	if not extraction_result["success"]:
		if extraction_result.get("error", "") == "cancelled":
			result["error_code"] = ExtractionError.EXTRACTION_FAILED
			result["error_message"] = "Extraction cancelled"
			return result
			
		result["error_code"] = ExtractionError.EXTRACTION_FAILED
		result["error_message"] = extraction_result["error"]
		OgsLogger.error("extraction_failed", {
			"component": "library",
			"reason": extraction_result["error"],
			"archive": archive_path,
			"tool_id": tool_id,
			"version": version
		})
		return result
	
	# Try to clean up the archive
	var cleanup_err = _cleanup_archive(archive_path)
	if cleanup_err != OK:
		OgsLogger.warn("archive_cleanup_failed", {
			"component": "library",
			"archive": archive_path,
			"tool_id": tool_id,
			"version": version
		})
		# Not a fatal error; log and continue
	
	result["success"] = true
	result["error_code"] = ExtractionError.SUCCESS
	result["tool_path"] = target_dir
	result["extracted_files"] = extraction_result["file_count"]
	
	OgsLogger.info("tool_extracted", {
		"component": "library",
		"tool_id": tool_id,
		"version": version,
		"target": target_dir,
		"file_count": result["extracted_files"]
	})
	
	return result

## Validates that an archive is a valid zip file.
## Parameters:
## archive_path (String): Path to file to validate
## Returns:
## Dictionary: {"valid": bool, "error": String}
func validate_archive(archive_path: String) -> Dictionary:
	if not FileAccess.file_exists(archive_path):
		return {"valid": false, "error": "File not found"}
	
	# MVP: Simple existence check. Phase 2 will validate zip structure.
	# For now, assume .zip extension means valid
	if archive_path.ends_with(".zip"):
		return {"valid": true, "error": ""}
	else:
		return {"valid": false, "error": "File does not end with .zip extension"}

# Private helper: extract zip using ZipReader
# MVP: Stubbed for Phase 2 - actual implementation requires ZipReader integration
func _extract_zip(archive_path: String, _target_dir: String, is_cancelled_callback: Callable = Callable(), progress_callback: Callable = Callable()) -> Dictionary:
	var result = {
		"success": false,
		"error": "",
		"file_count": 0
	}

	var reader = ZIPReader.new()
	var open_err = reader.open(archive_path)
	if open_err != OK:
		result["error"] = "Failed to open archive"
		return result

	var files = reader.get_files()
	if files.is_empty():
		reader.close()
		result["error"] = "Archive contains no files"
		return result

	var normalized_files: Array[String] = []
	for file_path in files:
		normalized_files.append(String(file_path).replace("\\", "/"))

	var root_prefix = _compute_common_root_prefix(normalized_files)
	var file_count = 0
	var total_files = normalized_files.size()
	for file_path in normalized_files:
		if is_cancelled_callback.is_valid() and is_cancelled_callback.call():
			reader.close()
			result["error"] = "cancelled"
			return result
			
		if not _is_safe_zip_path(file_path):
			reader.close()
			result["error"] = "Unsafe path in archive"
			return result
		var relative = file_path
		if not root_prefix.is_empty() and relative.begins_with(root_prefix):
			relative = relative.substr(root_prefix.length())
		if relative.is_empty():
			continue
		var output_path = _target_dir.path_join(relative).simplify_path()
		if not _is_path_under_root(output_path, _target_dir):
			reader.close()
			result["error"] = "Archive path escapes target directory"
			return result
		if relative.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(output_path)
			continue
		var parent_dir = output_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(parent_dir):
			DirAccess.make_dir_recursive_absolute(parent_dir)
		var data = reader.read_file(file_path)
		var out_file = FileAccess.open(output_path, FileAccess.WRITE)
		if out_file == null:
			reader.close()
			result["error"] = "Failed to write extracted file"
			return result
		out_file.store_buffer(data)
		out_file.close()
		file_count += 1
		
		if progress_callback.is_valid():
			progress_callback.call(file_count, total_files)

	reader.close()
	result["success"] = true
	result["file_count"] = file_count
	return result

## Computes a common root directory prefix from a list of archive paths.
static func _compute_common_root_prefix(paths: Array[String]) -> String:
	## Returns a common root prefix ending with '/' if all files share it.
	if paths.is_empty():
		return ""
	var candidate = ""
	var saw_root_file = false
	for path in paths:
		var clean = String(path)
		if clean.ends_with("/"):
			continue
		if clean.find("/") == -1:
			saw_root_file = true
			break
		var first = clean.substr(0, clean.find("/") + 1)
		if candidate == "":
			candidate = first
		elif candidate != first:
			return ""
	if saw_root_file:
		return ""
	return candidate

## Checks that a zip path is safe and relative (no traversal, no absolute paths).
static func _is_safe_zip_path(path: String) -> bool:
	## Returns true if the path is safe for extraction.
	if path.is_empty():
		return false
	if path.begins_with("/") or path.begins_with("\\"):
		return false
	if path.find(":") != -1:
		return false
	var parts = path.split("/")
	for part in parts:
		if part == "..":
			return false
	return true

## Checks if a path is under a target directory.
static func _is_path_under_root(full_path: String, root: String) -> bool:
	## Returns true if full_path is inside root (case-insensitive).
	var normalized_root = root.simplify_path().to_lower()
	var normalized_path = full_path.simplify_path().to_lower()
	if normalized_path == normalized_root:
		return true
	return normalized_path.begins_with(normalized_root + "/")

# Private helper: delete archive after successful extraction
func _cleanup_archive(archive_path: String) -> Error:
	if FileAccess.file_exists(archive_path):
		return DirAccess.remove_absolute(archive_path)
	return OK

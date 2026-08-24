## BaseHydrator: Base class for mirror hydrators providing shared utilities.
extends RefCounted
class_name BaseHydrator

signal tool_install_started(tool_id: String, version: String)
signal tool_install_progress(tool_id: String, version: String, file_count: int, total_files: int)
signal tool_install_complete(tool_id: String, version: String, success: bool, error_message: String)
signal tool_download_progress(tool_id: String, version: String, bytes_downloaded: int, total_bytes: int)
signal hydration_complete(success: bool, failed_tools: Array)

var scene_tree: SceneTree = null

func _emit_tool_install_started(tool_id: String, version: String) -> void:
	if scene_tree != null:
		call_deferred("_emit_tool_install_started_now", tool_id, version)
	else:
		tool_install_started.emit(tool_id, version)

func _emit_tool_install_started_now(tool_id: String, version: String) -> void:
	tool_install_started.emit(tool_id, version)

func _emit_tool_install_progress(tool_id: String, version: String, file_count: int, total_files: int) -> void:
	if scene_tree != null:
		call_deferred("_emit_tool_install_progress_now", tool_id, version, file_count, total_files)
	else:
		tool_install_progress.emit(tool_id, version, file_count, total_files)

func _emit_tool_install_progress_now(tool_id: String, version: String, file_count: int, total_files: int) -> void:
	tool_install_progress.emit(tool_id, version, file_count, total_files)

func _emit_tool_install_complete(tool_id: String, version: String, success: bool, error_message: String) -> void:
	if scene_tree != null:
		call_deferred("_emit_tool_install_complete_now", tool_id, version, success, error_message)
	else:
		tool_install_complete.emit(tool_id, version, success, error_message)

func _emit_tool_install_complete_now(tool_id: String, version: String, success: bool, error_message: String) -> void:
	tool_install_complete.emit(tool_id, version, success, error_message)

func _emit_hydration_complete(success: bool, failed_tools: Array) -> void:
	if scene_tree != null:
		call_deferred("_emit_hydration_complete_now", success, failed_tools)
	else:
		hydration_complete.emit(success, failed_tools)

func _emit_hydration_complete_now(success: bool, failed_tools: Array) -> void:
	hydration_complete.emit(success, failed_tools)

func _emit_tool_download_progress(tool_id: String, version: String, bytes_downloaded: int, total_bytes: int) -> void:
	if scene_tree != null:
		call_deferred("_emit_tool_download_progress_now", tool_id, version, bytes_downloaded, total_bytes)
	else:
		tool_download_progress.emit(tool_id, version, bytes_downloaded, total_bytes)

func _emit_tool_download_progress_now(tool_id: String, version: String, bytes_downloaded: int, total_bytes: int) -> void:
	tool_download_progress.emit(tool_id, version, bytes_downloaded, total_bytes)

## Copies an archive to a temp path using chunked reads to avoid memory spikes.
## Returns the temp_path on success, or empty string on failure.
func _copy_archive_to_temp(source_path: String, temp_path: String) -> String:
	var source = FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return ""
	var dest = FileAccess.open(temp_path, FileAccess.WRITE)
	if dest == null:
		source.close()
		return ""
	while not source.eof_reached():
		var chunk = source.get_buffer(1024 * 1024)
		if chunk.size() == 0:
			break
		dest.store_buffer(chunk)
	source.close()
	dest.close()
	return temp_path

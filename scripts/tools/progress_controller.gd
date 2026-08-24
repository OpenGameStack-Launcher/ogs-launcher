## ProgressController: Manages progress display for tool operations.
##
## Decouples progress tracking logic from UI, supporting both inline progress
## (embedded in tool cards) and future dialog-based progress for batch operations.
##
## Architecture:
## - Tracks multiple concurrent tool operations
## - Manages progress UI state (download → install phases)
## - Provides extensible design for future batch/queue operations
## - Emits completion/cancellation signals for coordination
##
## Usage (Inline Mode):
## var controller = ProgressController.new()
## controller.track_inline_progress("godot", "4.7.2", progress_bar, label, container)
## controller.update_progress("godot", "4.7.2", 1024000, 10240000)
## controller.set_install_phase("godot", "4.7.2")
## controller.complete_progress("godot", "4.7.2")
##
## Future Usage (Dialog Mode):
## controller.track_dialog_progress(["godot_4.7.2", "blender_4.5.7"], dialog_node)
## controller.update_batch_progress(...)

extends RefCounted
class_name ProgressController

## Emitted when progress completes successfully.
signal progress_completed(tool_id: String, version: String)

## Emitted when progress is cancelled by user.
signal progress_cancelled(tool_id: String, version: String)

## Progress phases for a tool operation.
enum Phase {
	NOT_TRACKED = -1,
	DOWNLOAD = 0,    ## Downloading archive (can show percentage)
	INSTALL = 1,     ## Extracting/installing (indeterminate)
	COMPLETE = 2     ## Operation finished
}

## Tracked progress items: {tool_key: progress_data}
## Each progress_data contains: {phase, ui_elements, bytes_total, bytes_downloaded}
var tracked_items: Dictionary = {}

## Registers an inline progress tracker for a tool.
##
## Sets up progress tracking for a tool with inline UI elements (progress bar,
## label, container). Progress updates will be applied to these elements.
##
## Parameters:
## tool_id (String): Tool identifier (e.g., "godot")
## version (String): Tool version (e.g., "4.7.2")
## progress_bar (ProgressBar): The progress bar UI element
## label (Label): Label for progress text (e.g., "10.5 / 25.0 MB")
## container (Control): Container holding progress UI (for visibility control)
func track_inline_progress(
	tool_id: String,
	version: String,
	progress_bar: ProgressBar,
	label: Label,
	container: Control
) -> void:
	## Register inline progress tracking for a tool operation.
	var key = _make_key(tool_id, version)
	
	tracked_items[key] = {
		"tool_id": tool_id,
		"version": version,
		"phase": Phase.DOWNLOAD,
		"progress_bar": progress_bar,
		"label": label,
		"container": container,
		"bytes_downloaded": 0,
		"bytes_total": 0
	}
	
	# Initialize UI state
	if container != null:
		container.visible = false
	if progress_bar != null:
		progress_bar.visible = false
		progress_bar.indeterminate = false
		progress_bar.value = 0
	if label != null:
		label.visible = false

## Updates progress for a tracked tool.
##
## Updates the progress bar and label to reflect current download progress.
## Automatically transitions to install phase when download completes.
##
## Parameters:
## tool_id (String): Tool identifier
## version (String): Tool version
## bytes_downloaded (int): Bytes downloaded so far
## total_bytes (int): Total bytes to download (0 = unknown)
func update_progress(
	tool_id: String,
	version: String,
	bytes_downloaded: int,
	total_bytes: int
) -> void:
	## Update download progress for a tracked tool.
	var key = _make_key(tool_id, version)
	var data = tracked_items.get(key)
	
	if data == null:
		return
	
	# Update stored progress
	data["bytes_downloaded"] = bytes_downloaded
	data["bytes_total"] = total_bytes
	
	# Only update UI if in download phase
	if data["phase"] != Phase.DOWNLOAD:
		return
	
	# Show progress elements
	var container = data.get("container")
	var progress_bar = data.get("progress_bar")
	var label = data.get("label")
	
	if container != null:
		container.visible = true
	if progress_bar != null:
		progress_bar.visible = true
	
	# Update progress bar
	if progress_bar != null and total_bytes > 0:
		progress_bar.indeterminate = false
		progress_bar.value = (bytes_downloaded * 100.0) / total_bytes
	
	# Update label with download progress
	if label != null:
		var downloaded_mb = bytes_downloaded / (1024.0 * 1024.0)
		var total_mb = total_bytes / (1024.0 * 1024.0)
		label.text = "%.1f / %.1f MB" % [downloaded_mb, total_mb]
		label.visible = true
	
	# Auto-transition to install phase when download completes
	if bytes_downloaded >= total_bytes and total_bytes > 0:
		set_install_phase(tool_id, version)

## Switches to installation phase (indeterminate progress).
##
## Changes progress display from percentage-based download to indeterminate
## "Installing..." state. Called automatically after download completes or
## can be called manually when extraction starts.
##
## Parameters:
## tool_id (String): Tool identifier
## version (String): Tool version
func set_install_phase(tool_id: String, version: String) -> void:
	## Transition to installation phase with indeterminate progress.
	var key = _make_key(tool_id, version)
	var data = tracked_items.get(key)
	
	if data == null:
		return
	
	data["phase"] = Phase.INSTALL
	
	var progress_bar = data.get("progress_bar")
	var label = data.get("label")
	var container = data.get("container")
	
	# Show progress elements
	if container != null:
		container.visible = true
	
	# Switch to indeterminate mode
	if progress_bar != null:
		progress_bar.visible = true
		progress_bar.indeterminate = true
		progress_bar.value = 0
	
	# Update label text
	if label != null:
		label.text = "Installing..."
		label.visible = true

func update_install_progress(tool_id: String, version: String, file_count: int, total_files: int) -> void:
	## Update the progress bar and label for installation phase.
	var key = _make_key(tool_id, version)
	var data = tracked_items.get(key)
	
	if data == null or data["phase"] != Phase.INSTALL:
		return
		
	var progress_bar = data.get("progress_bar")
	var label = data.get("label")
	
	if progress_bar != null and total_files > 0:
		progress_bar.indeterminate = false
		progress_bar.value = (file_count * 100.0) / total_files
		
	if label != null and total_files > 0:
		label.text = "Installing... (%d / %d files)" % [file_count, total_files]

## Marks progress as complete and cleans up tracking.
##
## Hides progress UI, emits completion signal, and removes tracking data.
## Should be called when tool operation finishes successfully.
##
## Parameters:
## tool_id (String): Tool identifier
## version (String): Tool version
func complete_progress(tool_id: String, version: String) -> void:
	## Mark progress as complete and clean up.
	var key = _make_key(tool_id, version)
	var data = tracked_items.get(key)
	
	if data == null:
		return
	
	data["phase"] = Phase.COMPLETE
	
	# Hide progress UI
	var container = data.get("container")
	if container != null:
		container.visible = false
	
	# Emit completion signal
	progress_completed.emit(tool_id, version)
	
	# Clean up tracking
	tracked_items.erase(key)

## Cancels progress and cleans up tracking.
##
## Hides progress UI, emits cancellation signal, and removes tracking data.
## Should be called when user cancels operation or operation fails.
##
## Parameters:
## tool_id (String): Tool identifier
## version (String): Tool version
func cancel_progress(tool_id: String, version: String) -> void:
	## Cancel progress and clean up tracking.
	var key = _make_key(tool_id, version)
	var data = tracked_items.get(key)
	
	if data == null:
		return
	
	# Hide progress UI
	var container = data.get("container")
	if container != null:
		container.visible = false
	
	# Emit cancellation signal
	progress_cancelled.emit(tool_id, version)
	
	# Clean up tracking
	tracked_items.erase(key)

## Checks if a tool is currently being tracked.
##
## Parameters:
## tool_id (String): Tool identifier
## version (String): Tool version
##
## Returns:
## bool: True if tool is tracked, False otherwise
func is_tracking(tool_id: String, version: String) -> bool:
	## Check if a tool is currently tracked.
	var key = _make_key(tool_id, version)
	return tracked_items.has(key)

## Gets the current phase for a tracked tool.
##
## Parameters:
## tool_id (String): Tool identifier
## version (String): Tool version
##
## Returns:
## Phase: Current phase, or Phase.NOT_TRACKED if not tracked
func get_phase(tool_id: String, version: String) -> Phase:
	## Get current phase for a tracked tool.
	var key = _make_key(tool_id, version)
	var data = tracked_items.get(key)
	if data != null:
		return data["phase"] as Phase
	return Phase.NOT_TRACKED

## Internal: Creates a unique key for tool tracking.
func _make_key(tool_id: String, version: String) -> String:
	## Generate unique key for tool.
	return "%s_%s" % [tool_id, version]

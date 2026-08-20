## SealController: Manages "Seal for Delivery" workflow.
##
## Handles seal dialog setup, ProjectSealer integration, result display,
## and folder navigation. Provides a clean abstraction for sealing projects.
##
## Usage:
##   var sealer = SealController.new()
##   sealer.setup(seal_dialog, status_label, output_label, open_button)
##   sealer.seal_for_delivery(project_path)

extends RefCounted
class_name SealController

const OgsLogger = preload("res://scripts/logging/logger.gd")

## Emitted when seal operation completes (success or failure).
signal seal_completed(success: bool, zip_path: String)

var _seal_dialog: AcceptDialog
var _status_label: Label
var _output_label: Label
var _open_folder_button: Button

var _last_sealed_zip: String = ""
var _seal_in_progress: bool = false
var _seal_thread: Thread
var _seal_started_at_msec: int = 0

## Sets up the seal controller with dialog and display components.
## Parameters:
##   seal_dialog (AcceptDialog): The dialog to show results
##   status_label (Label): Shows success/failure message
##   output_label (Label): Shows detailed information
##   open_folder_button (Button): Opens the sealed folder
func setup(
	seal_dialog: AcceptDialog,
	status_label: Label,
	output_label: Label,
	open_folder_button: Button
) -> void:
	"""Configures the seal controller."""
	_seal_dialog = seal_dialog
	_status_label = status_label
	_output_label = output_label
	_open_folder_button = open_folder_button
	
	# Wire button
	_open_folder_button.pressed.connect(_on_open_folder_pressed)

## Seals a project for offline delivery.
## Parameters:
##   project_path (String): Path to the project directory
func seal_for_delivery(project_path: String) -> void:
	"""Initiates the seal workflow."""
	if project_path.is_empty():
		_show_error("No project loaded.", "Please load a project first.")
		return

	if _seal_in_progress:
		_show_error("Seal already running.", "Please wait for the current seal operation to complete.")
		return
	
	# Show progress dialog
	_show_progress()
	_run_seal_async(project_path)

## Runs seal operation in a background thread and updates UI while waiting.
func _run_seal_async(project_path: String) -> void:
	"""Executes sealing asynchronously to keep the UI responsive."""
	_seal_in_progress = true
	_seal_started_at_msec = Time.get_ticks_msec()
	_seal_thread = Thread.new()

	# Yield one frame so the progress dialog renders before heavy work starts.
	await _seal_dialog.get_tree().process_frame

	var start_err = _seal_thread.start(Callable(self, "_threaded_seal_operation").bind(project_path))
	if start_err != OK:
		_seal_in_progress = false
		_show_error("Seal operation failed.", "Unable to start background packaging thread.")
		OgsLogger.error("seal_thread_start_failed", {
			"component": "sealer",
			"error": error_string(start_err)
		})
		seal_completed.emit(false, "")
		return

	while _seal_thread != null and _seal_thread.is_alive():
		_update_progress_status()
		await _seal_dialog.get_tree().create_timer(0.25).timeout

	var result = _seal_thread.wait_to_finish() if _seal_thread != null else {
		"success": false,
		"errors": ["Background thread result missing."]
	}
	_seal_thread = null
	_seal_in_progress = false

	if result.success:
		_show_success(result)
		_last_sealed_zip = result.sealed_zip
		seal_completed.emit(true, result.sealed_zip)
	else:
		_show_error("Seal operation failed.", result.errors)
		seal_completed.emit(false, "")

## Worker thread entry point for project sealing.
func _threaded_seal_operation(project_path: String) -> Dictionary:
	"""Performs the full seal workflow off the main thread."""
	var sealer = ProjectSealer.new()
	return sealer.seal_project(project_path)

## Updates in-progress status text while background seal runs.
func _update_progress_status() -> void:
	"""Shows elapsed time and stage hints during long-running packaging."""
	var elapsed_seconds = int((Time.get_ticks_msec() - _seal_started_at_msec) / 1000.0)
	var phase = "Validating and copying tools" if elapsed_seconds < 10 else "Packaging archive"
	_status_label.text = "Sealing project... (%ds)" % elapsed_seconds
	_output_label.text = "Stage: %s\n\nThis step can take several minutes for large toolchains.\nPlease keep this window open." % phase

## Displays success state with result details.
func _show_success(result: Dictionary) -> void:
	"""Shows the successful seal result."""
	_status_label.text = "✓ Project sealed successfully!"
	
	var size_text = "%.1f MB" % result.project_size_mb
	var tools_list = result.tools_copied
	var tools_text = "No tools to copy" if tools_list.is_empty() else "Tools copied:\n  • " + "\n  • ".join(tools_list)
	
	_output_label.text = "Archive: %s\nSize: %s\n\n%s" % [
		result.sealed_zip.get_file(),
		size_text,
		tools_text
	]
	
	_open_folder_button.visible = true
	_seal_dialog.popup_centered()
	
	OgsLogger.info("seal_completed_success", {
		"component": "sealer",
		"zip_path": result.sealed_zip,
		"size_mb": result.project_size_mb,
		"tools_count": result.tools_copied.size()
	})

## Displays error state with error messages.
func _show_error(title: String, errors: Variant) -> void:
	"""Shows the error result."""
	_status_label.text = "✗ %s" % title
	
	var error_text: String = ""
	if errors is Array:
		error_text = "\n".join(errors) if not errors.is_empty() else "Unknown error occurred."
	else:
		error_text = str(errors)
	
	_output_label.text = "Errors:\n" + error_text
	_open_folder_button.visible = false
	_seal_dialog.popup_centered()
	
	OgsLogger.warn("seal_completed_failure", {
		"component": "sealer",
		"error_count": errors.size() if errors is Array else 1
	})

## Displays progress state while sealing.
func _show_progress() -> void:
	"""Shows the progress dialog."""
	_status_label.text = "Sealing project..."
	_output_label.text = "Stage: Preparing\n\nCreating offline-ready artifact..."
	_open_folder_button.visible = false
	_seal_dialog.popup_centered()

## Opens the folder containing the sealed zip.
func _on_open_folder_pressed() -> void:
	"""Opens Windows Explorer to the sealed folder."""
	if _last_sealed_zip.is_empty():
		OgsLogger.warn("open_folder_no_path", {"component": "sealer"})
		return

	var folder_path = _last_sealed_zip.get_base_dir()
	if folder_path.is_empty() or not DirAccess.dir_exists_absolute(folder_path):
		OgsLogger.warn("open_folder_invalid_path", {
			"component": "sealer",
			"zip_path": _last_sealed_zip,
			"folder_path": folder_path
		})
		return

	OS.shell_open(folder_path)
	
	OgsLogger.info("open_folder_pressed", {
		"component": "sealer",
		"folder_path": folder_path
	})

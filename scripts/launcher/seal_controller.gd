## SealController: Manages "Seal for Delivery" workflow.
##
## Handles seal dialog setup, ProjectSealer integration, result display,
## and folder navigation. Provides a clean abstraction for sealing projects.
##
## Usage:
## var sealer = SealController.new()
## sealer.setup(seal_dialog, status_label, output_label, open_button, progress_bar)
## sealer.seal_for_delivery(project_path)

extends RefCounted
class_name SealController

## Joins any in-flight seal thread before this object is garbage-collected.
## Without this, an orphaned Thread causes Godot 4 warnings and potential crashes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _seal_thread != null and _seal_thread.is_started():
			OgsLogger.warn("seal_thread_join_on_free", {
				"component": "sealer"
			})
			_seal_thread.wait_to_finish()
		_seal_thread = null

const OgsLogger = preload("res://scripts/logging/logger.gd")
const ToolCategoryMapper = preload("res://scripts/tools/tool_category_mapper.gd")

## Emitted when seal operation completes (success or failure).
signal seal_completed(success: bool, zip_path: String)

var _seal_dialog: AcceptDialog
var _status_label: Label
var _output_label: Label
var _open_folder_button: Button
var _progress_bar: ProgressBar

var _last_sealed_zip: String = ""
var _seal_in_progress: bool = false
var _seal_thread: Thread
var _seal_started_at_msec: int = 0

## Sets up the seal controller with dialog and display components.
## Parameters:
## seal_dialog (AcceptDialog): The dialog to show results
## status_label (Label): Shows success/failure message
## output_label (Label): Shows detailed information
## open_folder_button (Button): Opens the sealed folder
## progress_bar (ProgressBar): Shows indeterminate progress during active sealing
func setup(
	seal_dialog: AcceptDialog,
	status_label: Label,
	output_label: Label,
	open_folder_button: Button,
	progress_bar: ProgressBar = null
) -> void:
	## Configures the seal controller.
	_seal_dialog = seal_dialog
	_status_label = status_label
	_output_label = output_label
	_open_folder_button = open_folder_button
	_progress_bar = progress_bar

	if is_instance_valid(_progress_bar):
		_progress_bar.visible = false

	# Wire button
	if is_instance_valid(_open_folder_button) and not _open_folder_button.pressed.is_connected(_on_open_folder_pressed):
		_open_folder_button.pressed.connect(_on_open_folder_pressed)

## Formats a tool entry using ToolCategoryMapper for canonical display naming.
static func _format_tool_entry(raw_entry: String) -> String:
	## Formats raw tool string (e.g. 'godot v4.7.2' -> 'Godot v4.7.2').
	var trimmed: String = raw_entry.strip_edges()
	if trimmed.is_empty():
		return ""
	var prefix: String = ""
	if trimmed.begins_with("• "):
		prefix = "• "
		trimmed = trimmed.substr(2).strip_edges()
	elif trimmed.begins_with("- "):
		prefix = "- "
		trimmed = trimmed.substr(2).strip_edges()
	elif trimmed.begins_with("* "):
		prefix = "* "
		trimmed = trimmed.substr(2).strip_edges()

	var first_space_idx: int = trimmed.find(" ")
	var formatted: String = ""
	if first_space_idx == -1:
		formatted = ToolCategoryMapper.get_display_name(trimmed)
	else:
		var raw_id: String = trimmed.substr(0, first_space_idx)
		var rest: String = trimmed.substr(first_space_idx)
		formatted = "%s%s" % [ToolCategoryMapper.get_display_name(raw_id), rest]
	return prefix + formatted

## Helper to set ok button disabled state on the seal dialog if available.
func _set_close_button_disabled(is_disabled: bool) -> void:
	## Updates dialog OK button disabled state.
	if is_instance_valid(_seal_dialog):
		var ok_btn: Button = _seal_dialog.get_ok_button()
		if is_instance_valid(ok_btn):
			ok_btn.disabled = is_disabled

## Seals a project for offline delivery.
## Parameters:
## project_path (String): Path to the project directory
func seal_for_delivery(project_path: String) -> void:
	## Initiates the seal workflow.
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
	## Executes sealing asynchronously to keep the UI responsive.
	_seal_in_progress = true
	_seal_started_at_msec = Time.get_ticks_msec()
	_seal_thread = Thread.new()

	if is_instance_valid(_progress_bar):
		_progress_bar.indeterminate = true
		_progress_bar.visible = true
	_set_close_button_disabled(true)
	if is_instance_valid(_status_label):
		_status_label.modulate = Color("#F3F4F6")

	# Yield one frame so the progress dialog renders before heavy work starts.
	if is_instance_valid(_seal_dialog) and _seal_dialog.is_inside_tree():
		await _seal_dialog.get_tree().process_frame

	var start_err = _start_seal_thread(project_path)
	if start_err != OK:
		_seal_thread = null
		_seal_in_progress = false
		_show_error("Seal operation failed.", "Unable to start background packaging thread.")
		OgsLogger.error("seal_thread_start_failed", {
			"component": "sealer",
			"error": error_string(start_err)
		})
		seal_completed.emit(false, "")
		return

	while _seal_thread != null and _seal_thread.is_alive():
		var tree = Engine.get_main_loop() as SceneTree
		if tree == null:
			break
		if is_instance_valid(_seal_dialog) and _seal_dialog.is_inside_tree():
			_update_progress_status()
		await tree.create_timer(0.25).timeout

	var result = _seal_thread.wait_to_finish() if _seal_thread != null else {
		"success": false,
		"errors": ["Background thread result missing."]
	}
	_seal_thread = null
	_seal_in_progress = false
	var can_present_result_ui = (
		is_instance_valid(_seal_dialog)
		and _seal_dialog.is_inside_tree()
		and is_instance_valid(_status_label)
		and is_instance_valid(_output_label)
		and is_instance_valid(_open_folder_button)
	)

	if result.success:
		_last_sealed_zip = result.sealed_zip
		if can_present_result_ui:
			_show_success(result)
		seal_completed.emit(true, result.sealed_zip)
	else:
		if can_present_result_ui:
			_show_error("Seal operation failed.", result.errors)
		seal_completed.emit(false, "")

## Starts the background seal worker thread for the requested project.
func _start_seal_thread(project_path: String) -> int:
	## Launches the worker entry point on the controller's thread instance.
	return _seal_thread.start(Callable(self, "_threaded_seal_operation").bind(project_path))

## Worker thread entry point for project sealing.
func _threaded_seal_operation(project_path: String) -> Dictionary:
	## Performs the full seal workflow off the main thread.
	var sealer = ProjectSealer.new()
	return sealer.seal_project(project_path)

## Updates in-progress status text while background seal runs.
func _update_progress_status() -> void:
	## Shows elapsed time and stage hints during long-running packaging.
	var elapsed_seconds = int((Time.get_ticks_msec() - _seal_started_at_msec) / 1000.0)
	var phase = "Validating and copying tools" if elapsed_seconds < 10 else "Packaging archive"
	if is_instance_valid(_status_label):
		_status_label.text = "Sealing project... (%ds)" % elapsed_seconds
		_status_label.modulate = Color("#F3F4F6")
	if is_instance_valid(_output_label):
		_output_label.text = "Stage: %s\n\nThis step can take several minutes for large toolchains.\nPlease keep this window open." % phase
	if is_instance_valid(_progress_bar):
		_progress_bar.indeterminate = true
		_progress_bar.visible = true
	_set_close_button_disabled(true)

## Displays success state with result details.
func _show_success(result: Dictionary) -> void:
	## Shows the successful seal result.
	if is_instance_valid(_status_label):
		_status_label.text = "✓ Project sealed successfully!"
		_status_label.modulate = Color("#22C55E")

	var size_text = "%.1f MB" % result.get("project_size_mb", 0.0)
	var tools_list = result.get("tools_copied", [])
	var formatted_tools: Array[String] = []
	for tool_item in tools_list:
		formatted_tools.append(_format_tool_entry(str(tool_item)))

	var tools_text = "No tools to copy" if formatted_tools.is_empty() else "Tools copied:\n  • " + "\n  • ".join(formatted_tools)

	if is_instance_valid(_output_label):
		_output_label.text = "Archive: %s\nSize: %s\n\n%s" % [
			result.get("sealed_zip", "").get_file(),
			size_text,
			tools_text
		]

	if is_instance_valid(_open_folder_button):
		_open_folder_button.visible = true
	if is_instance_valid(_progress_bar):
		_progress_bar.visible = false
	_set_close_button_disabled(false)

	if is_instance_valid(_seal_dialog) and _seal_dialog.is_inside_tree():
		_seal_dialog.popup_centered()

	OgsLogger.info("seal_completed_success", {
		"component": "sealer",
		"zip_path": result.get("sealed_zip", ""),
		"size_mb": result.get("project_size_mb", 0.0),
		"tools_count": formatted_tools.size()
	})

## Displays error state with error messages.
func _show_error(title: String, errors: Variant) -> void:
	## Shows the error result.
	if is_instance_valid(_status_label):
		_status_label.text = "✗ %s" % title
		_status_label.modulate = Color("#EF4444")

	var error_text: String = ""
	if errors is Array:
		error_text = "\n".join(errors) if not errors.is_empty() else "Unknown error occurred."
	else:
		error_text = str(errors)

	if is_instance_valid(_output_label):
		_output_label.text = "Errors:\n" + error_text
	if is_instance_valid(_open_folder_button):
		_open_folder_button.visible = false
	if is_instance_valid(_progress_bar):
		_progress_bar.visible = false
	_set_close_button_disabled(false)

	if is_instance_valid(_seal_dialog) and _seal_dialog.is_inside_tree():
		_seal_dialog.popup_centered()

	OgsLogger.warn("seal_completed_failure", {
		"component": "sealer",
		"error_count": errors.size() if errors is Array else 1
	})

## Displays progress state while sealing.
func _show_progress() -> void:
	## Shows the progress dialog and activates progress indicators.
	if is_instance_valid(_status_label):
		_status_label.text = "Sealing project..."
		_status_label.modulate = Color("#F3F4F6")
	if is_instance_valid(_output_label):
		_output_label.text = "Stage: Preparing\n\nCreating offline-ready artifact..."
	if is_instance_valid(_open_folder_button):
		_open_folder_button.visible = false
	if is_instance_valid(_progress_bar):
		_progress_bar.indeterminate = true
		_progress_bar.visible = true
	_set_close_button_disabled(true)

	if is_instance_valid(_seal_dialog) and _seal_dialog.is_inside_tree():
		_seal_dialog.popup_centered()

## Opens the folder containing the sealed zip.
func _on_open_folder_pressed() -> void:
	## Opens Windows Explorer to the sealed folder.
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

	# Validate path to prevent arbitrary URL execution
	if not folder_path.is_absolute_path() or folder_path.contains("://"):
		OgsLogger.warn("invalid_shell_open_path", {"component": "sealer", "absolute_path": folder_path})
		return

	OS.shell_show_in_file_manager(folder_path)

	OgsLogger.info("open_folder_pressed", {
		"component": "sealer",
		"folder_path": folder_path
	})

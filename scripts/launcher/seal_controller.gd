## SealController: Manages "Seal for Delivery" workflow.
##
## Handles seal dialog setup, pre-seal confirmation, ProjectSealer integration,
## result display, and folder navigation. Provides a clean abstraction for sealing projects.
##
## Usage:
## var sealer = SealController.new()
## sealer.setup(seal_dialog, status_label, output_label, open_button, progress_bar)
## sealer.seal_for_delivery(project_path)

extends RefCounted
class_name SealController

## Controller states representing the sealing workflow lifecycle.
enum State {
	IDLE,
	CONFIRMATION,
	SEALING,
	SUCCESS,
	ERROR
}

## Joins any in-flight seal thread before this object is garbage-collected.
## Without this, an orphaned Thread causes Godot 4 warnings and potential crashes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cancel_mutex.lock()
		_is_cancel_requested = true
		_cancel_mutex.unlock()
		if _active_sealer != null:
			_active_sealer.request_cancel()
		if _seal_thread != null and _seal_thread.is_started():
			OgsLogger.warn("seal_thread_join_on_free", {
				"component": "sealer"
			})
			_seal_thread.wait_to_finish()
		_seal_thread = null
		_active_sealer = null

const OgsLogger = preload("res://scripts/logging/logger.gd")
const ToolCategoryMapper = preload("res://scripts/tools/tool_category_mapper.gd")
const StackManifest = preload("res://scripts/manifest/stack_manifest.gd")

## Emitted when seal operation completes (success or failure).
signal seal_completed(success: bool, zip_path: String)

var _seal_dialog: AcceptDialog
var _status_label: Label
var _output_label: Label
var _open_folder_button: Button
var _progress_bar: ProgressBar

var _ok_button: Button
var _cancel_button: Button

var _current_state: State = State.IDLE
var _pending_project_path: String = ""
var _last_sealed_zip: String = ""
var _seal_in_progress: bool = false
var _seal_thread: Thread
var _seal_started_at_msec: int = 0

var _cancel_mutex: Mutex = Mutex.new()
var _is_cancel_requested: bool = false
var _is_cancelling: bool = false
var _active_sealer: ProjectSealer = null

var _progress_mutex: Mutex = Mutex.new()
var _current_phase: String = ""
var _current_file_count: int = 0
var _total_file_count: int = 0
var _has_progress_update: bool = false

## Sets up the seal controller with dialog and display components.
## Parameters:
## seal_dialog (AcceptDialog): The dialog to show results
## status_label (Label): Shows success/failure/confirmation message
## output_label (Label): Shows detailed information
## open_folder_button (Button): Opens the sealed folder
## progress_bar (ProgressBar): Shows indeterminate progress during active sealing
## cancel_button (Button): Optional explicit cancel button (defaults to add_cancel_button on dialog)
## confirm_button (Button): Optional explicit confirm button (defaults to get_ok_button on dialog)
func setup(
	seal_dialog: AcceptDialog,
	status_label: Label,
	output_label: Label,
	open_folder_button: Button,
	progress_bar: ProgressBar = null,
	cancel_button: Button = null,
	confirm_button: Button = null
) -> void:
	## Configures the seal controller.
	_seal_dialog = seal_dialog
	_status_label = status_label
	_output_label = output_label
	_open_folder_button = open_folder_button
	_progress_bar = progress_bar

	if is_instance_valid(_progress_bar):
		_progress_bar.visible = false
		_progress_bar.min_value = 0
		_progress_bar.max_value = 100

	# Wire folder button
	if is_instance_valid(_open_folder_button) and not _open_folder_button.pressed.is_connected(_on_open_folder_pressed):
		_open_folder_button.pressed.connect(_on_open_folder_pressed)

	if is_instance_valid(_seal_dialog):
		_seal_dialog.borderless = true
		_seal_dialog.dialog_hide_on_ok = false
		_seal_dialog.dialog_close_on_escape = false

		# Clear Window close theme icon so no X is drawn even if borderless is false or embedded
		var empty_img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		var empty_tex: ImageTexture = ImageTexture.create_from_image(empty_img)
		_seal_dialog.add_theme_icon_override("close", empty_tex)
		_seal_dialog.add_theme_icon_override("close_hl", empty_tex)

		# Apply sleek dialog panel styling with border and rounded corners
		var dialog_panel: StyleBoxFlat = StyleBoxFlat.new()
		dialog_panel.bg_color = Color(0.12, 0.14, 0.18, 1.0)
		dialog_panel.border_width_left = 1
		dialog_panel.border_width_top = 1
		dialog_panel.border_width_right = 1
		dialog_panel.border_width_bottom = 1
		dialog_panel.border_color = Color(0.28, 0.32, 0.40, 1.0)
		dialog_panel.corner_radius_top_left = 6
		dialog_panel.corner_radius_top_right = 6
		dialog_panel.corner_radius_bottom_left = 6
		dialog_panel.corner_radius_bottom_right = 6
		dialog_panel.content_margin_left = 16.0
		dialog_panel.content_margin_right = 16.0
		dialog_panel.content_margin_top = 16.0
		dialog_panel.content_margin_bottom = 16.0
		_seal_dialog.add_theme_stylebox_override("panel", dialog_panel)

		# Intercept close_requested
		if not _seal_dialog.close_requested.is_connected(_on_close_requested):
			_seal_dialog.close_requested.connect(_on_close_requested)

		# Resolve OK/Confirm button
		if confirm_button != null:
			_ok_button = confirm_button
		else:
			var found_confirm: Button = _seal_dialog.find_child("ConfirmButton", true, false) as Button
			if found_confirm != null:
				_ok_button = found_confirm
			else:
				_ok_button = _seal_dialog.get_ok_button()

		# Resolve Cancel button
		if cancel_button != null:
			_cancel_button = cancel_button
		else:
			var found_cancel: Button = _seal_dialog.find_child("CancelButton", true, false) as Button
			if found_cancel != null:
				_cancel_button = found_cancel
			else:
				_cancel_button = _seal_dialog.add_cancel_button("Cancel")

		if is_instance_valid(_ok_button):
			_ok_button.theme_type_variation = &"PrimaryButton"
			_ok_button.text = "Close"
			_ok_button.disabled = false
			if not _ok_button.pressed.is_connected(_on_ok_pressed):
				_ok_button.pressed.connect(_on_ok_pressed)

		if is_instance_valid(_cancel_button):
			_cancel_button.theme_type_variation = &"SecondaryButton"
			_cancel_button.text = "Cancel"
			_cancel_button.visible = false
			if not _cancel_button.pressed.is_connected(_on_cancel_pressed):
				_cancel_button.pressed.connect(_on_cancel_pressed)

## Returns current state of the seal controller.
func get_current_state() -> State:
	return _current_state

## Returns true if controller is in confirmation state.
func is_in_confirmation() -> bool:
	return _current_state == State.CONFIRMATION

## Returns true if controller is actively sealing in background.
func is_sealing() -> bool:
	return _seal_in_progress

## Returns true if cancellation has been requested.
func is_cancel_requested() -> bool:
	_cancel_mutex.lock()
	var req: bool = _is_cancel_requested
	_cancel_mutex.unlock()
	return req

## Returns true if cancel rollback is currently in progress.
func is_cancelling() -> bool:
	return _is_cancelling

## Returns dialog Cancel button if available.
func get_cancel_button() -> Button:
	return _cancel_button

## Returns dialog Confirm / OK button if available.
func get_confirm_button() -> Button:
	return _ok_button

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

## Formats an integer with thousands separator commas (e.g. 1000 -> "1,000").
static func format_number(value: int) -> String:
	## Formats integer with thousands commas.
	var s: String = str(value)
	var is_negative: bool = s.begins_with("-")
	if is_negative:
		s = s.substr(1)
	var res: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			res = "," + res
		res = s[i] + res
		count += 1
	if is_negative:
		res = "-" + res
	return res

## Internal shorthand for format_number.
static func _format_number(value: int) -> String:
	## Formats integer with thousands commas.
	return format_number(value)

## Helper to set ok button disabled state on the seal dialog if available.
func _set_close_button_disabled(is_disabled: bool) -> void:
	## Updates dialog OK button disabled state.
	if is_instance_valid(_ok_button):
		_ok_button.disabled = is_disabled
	elif is_instance_valid(_seal_dialog):
		var ok_btn: Button = _seal_dialog.get_ok_button()
		if is_instance_valid(ok_btn):
			ok_btn.disabled = is_disabled

## Prepares and presents the confirmation state for project sealing.
## Parameters:
## project_path (String): Path to the project directory
func seal_for_delivery(project_path: String) -> void:
	## Initiates the pre-seal confirmation workflow.
	if project_path.is_empty():
		_show_error("No project loaded.", "Please load a project first.")
		return

	if _seal_in_progress:
		_show_error("Seal already running.", "Please wait for the current seal operation to complete.")
		return

	_pending_project_path = project_path
	_show_confirmation(project_path)

## Displays the confirmation state with project name, tool list, and notice.
func _show_confirmation(project_path: String) -> void:
	_current_state = State.CONFIRMATION

	var project_info: Dictionary = _resolve_project_name_and_tools(project_path)
	var project_name: String = String(project_info.get("project_name", "Unknown Project"))
	var tools_list: Array = project_info.get("tools", []) as Array

	if is_instance_valid(_status_label):
		_status_label.text = "Confirm Project Sealing"
		_status_label.modulate = Color("#F3F4F6")

	var tools_text: String = ""
	if tools_list.is_empty():
		tools_text = "  • None configured"
	else:
		var bulleted: Array[String] = []
		for item in tools_list:
			bulleted.append("  • %s" % str(item))
		tools_text = "\n".join(bulleted)

	var notice_text: String = "This operation will bundle the project and all of its configured tools into a standalone .zip archive. The packaging process will copy tool binaries and may take several minutes to complete."

	if is_instance_valid(_output_label):
		_output_label.text = "Target Project: %s\n\nConfigured Stack Tools:\n%s\n\nNotice:\n%s" % [
			project_name,
			tools_text,
			notice_text
		]

	if is_instance_valid(_progress_bar):
		_progress_bar.visible = false
		_progress_bar.min_value = 0
		_progress_bar.max_value = 100
	if is_instance_valid(_open_folder_button):
		_open_folder_button.visible = false

	if is_instance_valid(_ok_button):
		_ok_button.text = "Confirm"
		_ok_button.disabled = false
		_ok_button.visible = true

	if is_instance_valid(_cancel_button):
		_cancel_button.text = "Cancel"
		_cancel_button.disabled = false
		_cancel_button.visible = true

	if is_instance_valid(_seal_dialog) and _seal_dialog.is_inside_tree():
		_seal_dialog.popup_centered()

	OgsLogger.info("seal_confirmation_presented", {
		"component": "sealer",
		"project_name": project_name,
		"tool_count": tools_list.size()
	})

## Confirms sealing and begins active background execution.
func confirm_seal() -> void:
	## Transitions from confirmation state into active sealing progress.
	if _pending_project_path.is_empty():
		OgsLogger.warn("confirm_seal_no_pending_project", {"component": "sealer"})
		return

	if _seal_in_progress:
		OgsLogger.warn("confirm_seal_already_in_progress", {"component": "sealer"})
		return

	var path_to_seal: String = _pending_project_path
	_pending_project_path = ""
	_show_progress()
	_run_seal_async(path_to_seal)

## Cancels sealing and closes the dialog without modifying files or launching a thread.
func cancel_seal() -> void:
	## Dismisses confirmation view or initiates cooperative cancellation and rollback.
	if _seal_in_progress:
		if _is_cancelling:
			return
		_is_cancelling = true
		_cancel_mutex.lock()
		_is_cancel_requested = true
		_cancel_mutex.unlock()

		if is_instance_valid(_ok_button):
			_ok_button.text = "Cancel"
			_ok_button.disabled = true
		if is_instance_valid(_cancel_button):
			_cancel_button.disabled = true
		if is_instance_valid(_status_label):
			_status_label.text = "Cancelling and restoring project state..."
			_status_label.modulate = Color("#F3F4F6")

		if _active_sealer != null:
			_active_sealer.request_cancel()

		OgsLogger.info("seal_cancel_requested", {"component": "sealer"})
		return

	_pending_project_path = ""
	_current_state = State.IDLE

	_progress_mutex.lock()
	_has_progress_update = false
	_current_phase = ""
	_current_file_count = 0
	_total_file_count = 0
	_progress_mutex.unlock()

	if is_instance_valid(_progress_bar):
		_progress_bar.visible = false
		_progress_bar.value = 0
		_progress_bar.indeterminate = false
		_progress_bar.min_value = 0
		_progress_bar.max_value = 100

	if is_instance_valid(_cancel_button):
		_cancel_button.visible = false

	if is_instance_valid(_ok_button):
		_ok_button.text = "Close"
		_ok_button.disabled = false

	if is_instance_valid(_seal_dialog):
		_seal_dialog.hide()

	OgsLogger.info("seal_cancelled_by_user", {"component": "sealer"})

## Handler for OK / Confirm / Cancel action button press.
func _on_ok_pressed() -> void:
	if _current_state == State.CONFIRMATION:
		confirm_seal()
	elif _current_state == State.SEALING or _seal_in_progress:
		cancel_seal()
	elif _current_state == State.SUCCESS or _current_state == State.ERROR or _current_state == State.IDLE:
		_current_state = State.IDLE
		if is_instance_valid(_seal_dialog):
			_seal_dialog.hide()

## Handler for Cancel button press.
func _on_cancel_pressed() -> void:
	if _current_state == State.CONFIRMATION:
		cancel_seal()
	elif _current_state == State.SEALING or _seal_in_progress:
		cancel_seal()
	else:
		_current_state = State.IDLE
		if is_instance_valid(_seal_dialog):
			_seal_dialog.hide()

## Handler for Window close_requested signal (blocking unexpected window chrome dismissal).
func _on_close_requested() -> void:
	if _seal_in_progress:
		OgsLogger.warn("seal_close_requested_blocked_during_execution", {
			"component": "sealer"
		})
		return

	if _current_state == State.CONFIRMATION:
		cancel_seal()
	else:
		_current_state = State.IDLE
		if is_instance_valid(_seal_dialog):
			_seal_dialog.hide()

## Runs seal operation in a background thread and updates UI while waiting.
func _run_seal_async(project_path: String) -> void:
	## Executes sealing asynchronously to keep the UI responsive.
	_seal_in_progress = true
	_seal_started_at_msec = Time.get_ticks_msec()
	_cancel_mutex.lock()
	_is_cancel_requested = false
	_cancel_mutex.unlock()
	_is_cancelling = false
	_seal_thread = Thread.new()
	_progress_mutex.lock()
	_has_progress_update = false
	_current_phase = ""
	_current_file_count = 0
	_total_file_count = 0
	_progress_mutex.unlock()

	if is_instance_valid(_progress_bar):
		_progress_bar.indeterminate = true
		_progress_bar.visible = true
	if is_instance_valid(_ok_button):
		_ok_button.text = "Cancel"
		_ok_button.disabled = false
		_ok_button.visible = true
	if is_instance_valid(_cancel_button):
		_cancel_button.visible = false
	if is_instance_valid(_status_label):
		_status_label.modulate = Color("#F3F4F6")

	# Yield one frame so the progress dialog renders before heavy work starts.
	if is_instance_valid(_seal_dialog) and _seal_dialog.is_inside_tree():
		await _seal_dialog.get_tree().process_frame

	var start_err: int = _start_seal_thread(project_path)
	if start_err != OK:
		_seal_thread = null
		_seal_in_progress = false
		_is_cancelling = false
		_active_sealer = null
		_progress_mutex.lock()
		_has_progress_update = false
		_current_phase = ""
		_current_file_count = 0
		_total_file_count = 0
		_progress_mutex.unlock()
		_show_error("Seal operation failed.", "Unable to start background packaging thread.")
		OgsLogger.error("seal_thread_start_failed", {
			"component": "sealer",
			"error": error_string(start_err)
		})
		seal_completed.emit(false, "")
		return

	while _seal_thread != null and _seal_thread.is_alive():
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree == null:
			break
		if is_instance_valid(_seal_dialog) and _seal_dialog.is_inside_tree():
			_update_progress_status()
		await tree.create_timer(0.05).timeout

	var result: Dictionary = _seal_thread.wait_to_finish() if _seal_thread != null else {
		"success": false,
		"errors": ["Background thread result missing."]
	}
	_seal_thread = null
	_seal_in_progress = false
	_active_sealer = null
	var was_cancelling: bool = _is_cancelling
	_is_cancelling = false

	var can_present_result_ui: bool = (
		is_instance_valid(_seal_dialog)
		and _seal_dialog.is_inside_tree()
		and is_instance_valid(_status_label)
		and is_instance_valid(_output_label)
		and is_instance_valid(_open_folder_button)
	)

	if result.get("cancelled", false) or was_cancelling:
		if can_present_result_ui:
			_show_cancelled(result)
		seal_completed.emit(false, "")
	elif result.success:
		_last_sealed_zip = String(result.get("sealed_zip", ""))
		if can_present_result_ui:
			_show_success(result)
		seal_completed.emit(true, _last_sealed_zip)
	else:
		if can_present_result_ui:
			_show_error("Seal operation failed.", result.get("errors", []))
		seal_completed.emit(false, "")

## Starts the background seal worker thread for the requested project.
func _start_seal_thread(project_path: String) -> int:
	## Launches the worker entry point on the controller's thread instance.
	return _seal_thread.start(Callable(self, "_threaded_seal_operation").bind(project_path))

## Worker thread entry point for project sealing.
func _threaded_seal_operation(project_path: String) -> Dictionary:
	## Performs the full seal workflow off the main thread.
	var sealer = ProjectSealer.new()
	_active_sealer = sealer
	var progress_cb: Callable = Callable(self, "_on_seal_progress_from_thread")
	var cancel_cb: Callable = Callable(self, "is_cancel_requested")
	var res = sealer.seal_project(project_path, progress_cb, cancel_cb)
	_active_sealer = null
	return res

## Handles thread-safe progress notifications from background worker thread.
func _on_seal_progress_from_thread(phase: String, current: int, total: int) -> void:
	## Receives background progress and schedules main-thread UI update.
	if _is_cancelling:
		return

	_progress_mutex.lock()
	_current_phase = phase
	_current_file_count = current
	_total_file_count = total
	_has_progress_update = true
	_progress_mutex.unlock()

	call_deferred("_apply_progress_to_ui", phase, current, total)

## Updates determinate progress bar and labels for active sealing phase.
## Parameters:
## phase (String): Active phase description (e.g. "Step 1/2: Copying tools")
## current (int): Current file index completed in this phase
## total (int): Total files in this phase
func update_progress(phase: String, current: int, total: int) -> void:
	## Directly updates progress state and UI.
	_progress_mutex.lock()
	_current_phase = phase
	_current_file_count = current
	_total_file_count = total
	_has_progress_update = true
	_progress_mutex.unlock()

	_apply_progress_to_ui(phase, current, total)

## Applies determinate progress values and formatted labels to UI nodes on main thread.
func _apply_progress_to_ui(phase: String, current: int, total: int) -> void:
	## Updates ProgressBar and labels on main thread.
	if _is_cancelling:
		return

	var percent: float = 100.0
	if total > 0:
		percent = clampf((float(current) / float(total)) * 100.0, 0.0, 100.0)
	elif current == 0 and total == 0:
		percent = 100.0

	if is_instance_valid(_progress_bar):
		_progress_bar.indeterminate = false
		_progress_bar.min_value = 0
		_progress_bar.max_value = 100
		_progress_bar.value = percent
		_progress_bar.visible = true

	var count_text: String = "%s of %s files" % [format_number(current), format_number(total)]
	var formatted_status: String = "%s (%s)" % [phase, count_text]

	if is_instance_valid(_status_label):
		_status_label.text = formatted_status
		_status_label.modulate = Color("#F3F4F6")

	if is_instance_valid(_output_label):
		var elapsed_seconds: int = int((Time.get_ticks_msec() - _seal_started_at_msec) / 1000.0)
		_output_label.text = "%s\n\nElapsed time: %ds\nPlease keep this window open while packaging completes." % [
			formatted_status,
			elapsed_seconds
		]

	if is_instance_valid(_ok_button):
		_ok_button.text = "Cancel"
		_ok_button.disabled = false
		_ok_button.visible = true

## Updates in-progress status text while background seal runs.
func _update_progress_status() -> void:
	## Shows elapsed time and stage hints during long-running packaging.
	if _is_cancelling:
		if is_instance_valid(_status_label):
			_status_label.text = "Cancelling and restoring project state..."
			_status_label.modulate = Color("#F3F4F6")
		if is_instance_valid(_ok_button):
			_ok_button.text = "Cancel"
			_ok_button.disabled = true
		return

	_progress_mutex.lock()
	var has_update: bool = _has_progress_update
	var phase: String = _current_phase
	var current: int = _current_file_count
	var total: int = _total_file_count
	_progress_mutex.unlock()

	if has_update:
		_apply_progress_to_ui(phase, current, total)
		if is_instance_valid(_ok_button):
			_ok_button.text = "Cancel"
			_ok_button.disabled = false
		if is_instance_valid(_cancel_button):
			_cancel_button.visible = false
		return

	var elapsed_seconds: int = int((Time.get_ticks_msec() - _seal_started_at_msec) / 1000.0)
	if is_instance_valid(_status_label):
		_status_label.text = "Sealing project... (%ds)" % elapsed_seconds
		_status_label.modulate = Color("#F3F4F6")
	if is_instance_valid(_output_label):
		_output_label.text = "Stage: Preparing tools\n\nThis step can take several minutes for large toolchains.\nPlease keep this window open."
	if is_instance_valid(_progress_bar):
		_progress_bar.indeterminate = true
		_progress_bar.visible = true
	if is_instance_valid(_ok_button):
		_ok_button.text = "Cancel"
		_ok_button.disabled = false
	if is_instance_valid(_cancel_button):
		_cancel_button.visible = false

## Displays success state with result details.
func _show_success(result: Dictionary) -> void:
	## Shows the successful seal result.
	_current_state = State.SUCCESS
	_progress_mutex.lock()
	_has_progress_update = false
	_current_phase = ""
	_current_file_count = 0
	_total_file_count = 0
	_progress_mutex.unlock()

	if is_instance_valid(_status_label):
		_status_label.text = "✓ Project sealed successfully!"
		_status_label.modulate = Color("#22C55E")

	var size_text: String = "%.1f MB" % result.get("project_size_mb", 0.0)
	var tools_list: Array = result.get("tools_copied", []) as Array
	var formatted_tools: Array[String] = []
	for tool_item in tools_list:
		formatted_tools.append(_format_tool_entry(str(tool_item)))

	var tools_text: String = "No tools to copy" if formatted_tools.is_empty() else "Tools copied:\n  • " + "\n  • ".join(formatted_tools)

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
		_progress_bar.value = 0
		_progress_bar.indeterminate = false
		_progress_bar.min_value = 0
		_progress_bar.max_value = 100

	if is_instance_valid(_ok_button):
		_ok_button.text = "Close"
		_ok_button.disabled = false
		_ok_button.visible = true
	if is_instance_valid(_cancel_button):
		_cancel_button.visible = false

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
	_current_state = State.ERROR
	_progress_mutex.lock()
	_has_progress_update = false
	_current_phase = ""
	_current_file_count = 0
	_total_file_count = 0
	_progress_mutex.unlock()

	if is_instance_valid(_status_label):
		_status_label.text = "✗ %s" % title
		_status_label.modulate = Color("#EF4444")

	var error_text: String = ""
	if errors is Array:
		var err_array: Array = errors as Array
		error_text = "\n".join(err_array) if not err_array.is_empty() else "Unknown error occurred."
	else:
		error_text = str(errors)

	if is_instance_valid(_output_label):
		_output_label.text = "Errors:\n" + error_text
	if is_instance_valid(_open_folder_button):
		_open_folder_button.visible = false
	if is_instance_valid(_progress_bar):
		_progress_bar.visible = false
		_progress_bar.value = 0
		_progress_bar.indeterminate = false
		_progress_bar.min_value = 0
		_progress_bar.max_value = 100

	if is_instance_valid(_ok_button):
		_ok_button.text = "Close"
		_ok_button.disabled = false
		_ok_button.visible = true
	if is_instance_valid(_cancel_button):
		_cancel_button.visible = false

	if is_instance_valid(_seal_dialog) and _seal_dialog.is_inside_tree():
		_seal_dialog.popup_centered()

	OgsLogger.warn("seal_completed_failure", {
		"component": "sealer",
		"error_count": errors.size() if errors is Array else 1
	})

## Displays progress state while sealing.
func _show_progress() -> void:
	## Shows the progress dialog and activates progress indicators.
	_current_state = State.SEALING
	_cancel_mutex.lock()
	_is_cancel_requested = false
	_cancel_mutex.unlock()
	_is_cancelling = false

	_progress_mutex.lock()
	_has_progress_update = false
	_current_phase = ""
	_current_file_count = 0
	_total_file_count = 0
	_progress_mutex.unlock()

	if is_instance_valid(_status_label):
		_status_label.text = "Sealing project..."
		_status_label.modulate = Color("#F3F4F6")
	if is_instance_valid(_output_label):
		_output_label.text = "Stage: Preparing\n\nCreating offline-ready artifact..."
	if is_instance_valid(_open_folder_button):
		_open_folder_button.visible = false
	if is_instance_valid(_progress_bar):
		_progress_bar.value = 0
		_progress_bar.indeterminate = true
		_progress_bar.visible = true

	if is_instance_valid(_ok_button):
		_ok_button.text = "Cancel"
		_ok_button.disabled = false
		_ok_button.visible = true
	if is_instance_valid(_cancel_button):
		_cancel_button.visible = false

	if is_instance_valid(_seal_dialog) and _seal_dialog.is_inside_tree():
		_seal_dialog.popup_centered()

## Displays cancelled state after rollback completes.
func _show_cancelled(_result: Dictionary = {}) -> void:
	## Shows the cancellation confirmation and enables Close button.
	_current_state = State.IDLE
	_progress_mutex.lock()
	_has_progress_update = false
	_current_phase = ""
	_current_file_count = 0
	_total_file_count = 0
	_progress_mutex.unlock()

	if is_instance_valid(_status_label):
		_status_label.text = "Seal cancelled."
		_status_label.modulate = Color("#F3F4F6")

	if is_instance_valid(_output_label):
		_output_label.text = "Packaging was cancelled by user.\nProject state has been restored."
	if is_instance_valid(_open_folder_button):
		_open_folder_button.visible = false
	if is_instance_valid(_progress_bar):
		_progress_bar.visible = false
		_progress_bar.value = 0
		_progress_bar.indeterminate = false
		_progress_bar.min_value = 0
		_progress_bar.max_value = 100

	if is_instance_valid(_ok_button):
		_ok_button.text = "Close"
		_ok_button.disabled = false
		_ok_button.visible = true
	if is_instance_valid(_cancel_button):
		_cancel_button.visible = false

	if is_instance_valid(_seal_dialog) and _seal_dialog.is_inside_tree():
		_seal_dialog.popup_centered()

	OgsLogger.info("seal_cancelled_and_restored", {
		"component": "sealer"
	})

## Opens the folder containing the sealed zip.
func _on_open_folder_pressed() -> void:
	## Opens Windows Explorer to the sealed folder.
	if _last_sealed_zip.is_empty():
		OgsLogger.warn("open_folder_no_path", {"component": "sealer"})
		return

	var folder_path: String = _last_sealed_zip.get_base_dir()
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

## Resolves project name and tool list from stack.json or project directory.
static func _resolve_project_name_and_tools(project_path: String) -> Dictionary:
	var stack_file: String = project_path.path_join("stack.json")
	var project_name: String = ""
	var tools_list: Array[String] = []

	if FileAccess.file_exists(stack_file):
		var manifest: StackManifest = StackManifest.load_from_file(stack_file) as StackManifest
		if manifest != null:
			if not String(manifest.stack_name).strip_edges().is_empty():
				project_name = String(manifest.stack_name).strip_edges()
			for tool_item in manifest.tools:
				var tool_id: String = String(tool_item.get("id", "")).strip_edges()
				if tool_id.is_empty():
					continue
				var canonical_name: String = ToolCategoryMapper.get_display_name(tool_id)
				var tool_ver: String = String(tool_item.get("version", "")).strip_edges()
				if not tool_ver.is_empty():
					var ver_str: String = tool_ver if tool_ver.begins_with("v") else "v" + tool_ver
					tools_list.append("%s %s" % [canonical_name, ver_str])
				else:
					tools_list.append(canonical_name)

	if project_name.is_empty():
		project_name = project_path.get_file()
		if project_name.is_empty():
			project_name = project_path

	return {
		"project_name": project_name,
		"tools": tools_list
	}

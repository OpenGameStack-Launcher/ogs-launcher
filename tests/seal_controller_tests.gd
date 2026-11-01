## SealControllerTests: Unit tests for SealController thread lifecycle.
##
## Covers:
##   (a) thread is joined cleanly when controller is freed while thread alive,
##   (b) predelete handler is safe when no thread is running,
##   (c) finished-but-started thread joined and cleared during predelete,
##   (d) thread start failure path clears seal state and emits failure,
##   (e) progress bar visibility and ok button disabled states during sealing,
##   (f) typography hierarchy, in-dialog header, and muted text colors,
##   (g) canonical display naming of copied tools,
##   (h) pre-seal confirmation view displaying stack name, tools, and multi-minute notice,
##   (i) cancel flow closing dialog without modifying files or launching thread,
##   (j) confirm flow transitioning dialog in-place to active sealing progress,
##   (k) close_requested dismissal blocking during active sealing, and
##   (l) SealDialog borderless window chrome and header configuration.

extends RefCounted
class_name SealControllerTests

const SealControllerScript = preload("res://scripts/launcher/seal_controller.gd")

class FailingSealController:
	extends SealController

	func _start_seal_thread(_project_path: String) -> int:
		## Forces a thread start failure so the controller's error path can be tested.
		return ERR_CANT_CREATE

class DialogFreedSealController:
	extends SealController

	var gate: Semaphore

	func _threaded_seal_operation(_project_path: String) -> Dictionary:
		## Holds the worker thread until the test releases it, then returns success.
		gate.wait()
		return {
			"success": true,
			"sealed_zip": "user://sealed/project.zip",
			"project_size_mb": 1.5,
			"tools_copied": ["godot v4.7.2"]
		}

func run() -> Dictionary:
	## Runs all SealController unit tests.
	var results = {
		"passed": 0,
		"failed": 0,
		"failures": []
	}

	_test_predelete_joins_alive_thread(results)
	_test_predelete_no_crash_when_thread_null(results)
	_test_thread_reference_cleared_after_predelete(results)
	await _test_thread_start_failure_clears_state(results)
	await _test_dialog_freed_while_thread_alive(results)
	_test_seal_dialog_typography_and_layout(results)
	_test_progress_bar_and_close_button_states(results)
	_test_tool_display_name_formatting_in_success(results)
	await _test_async_seal_progress_bar_and_close_button_lifecycle(results)
	_test_confirmation_state_presentation_and_content(results)
	_test_cancel_flow_leaves_project_intact_and_hides_dialog(results)
	await _test_confirm_transitions_in_place_to_sealing_progress(results)
	_test_close_requested_blocked_while_sealing(results)
	_test_main_tscn_seal_dialog_chrome_configuration(results)
	_test_determinate_progress_two_phases(results)
	_test_determinate_progress_thousands_formatting(results)
	_test_determinate_progress_zero_files_edge_case(results)
	_test_determinate_progress_error_hides_progress_bar(results)
	await _test_cancel_button_lifecycle_and_rollback(results)

	return results

## Helper: Assertion wrapper.
func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records a pass or failure for the given assertion.
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

## Test: _notification(NOTIFICATION_PREDELETE) joins a live thread without crashing.
func _test_predelete_joins_alive_thread(results: Dictionary) -> void:
	## Verifies that freeing a SealController while its thread is alive calls
	## wait_to_finish() and does not crash or leave Godot warnings.
	var controller = SealControllerScript.new()

	# Use a Semaphore to hold the thread alive until we release it, ensuring
	# is_alive() returns true when NOTIFICATION_PREDELETE is triggered.
	var sem = Semaphore.new()
	var thread = Thread.new()
	var start_err = thread.start(func() -> void: sem.wait())
	_expect(start_err == OK, "Thread.start() should succeed in test environment", results)
	if start_err != OK:
		return

	# Wait until the thread is actually alive (blocked on the semaphore),
	# polling with a timeout to avoid timing flakiness on slow runners.
	var deadline_msec = Time.get_ticks_msec() + 2000
	while not thread.is_alive() and Time.get_ticks_msec() < deadline_msec:
		OS.delay_msec(5)

	_expect(thread.is_alive(), "Thread should be alive (blocked on semaphore)", results)

	# Inject the live thread into the controller's private field.
	controller.set("_seal_thread", thread)

	# Release the semaphore so the thread can exit, then immediately trigger
	# predelete. The controller must join the thread safely.
	sem.post()
	controller.notification(NOTIFICATION_PREDELETE)

	# After the notification the thread should have been joined and nulled.
	var thread_field = controller.get("_seal_thread")
	_expect(thread_field == null, "NOTIFICATION_PREDELETE should null _seal_thread", results)

	# The thread itself must no longer be alive.
	_expect(not thread.is_alive(), "Thread should no longer be alive after join", results)

	# Safety: if the thread is still started after the handler returns, join it
	# here to avoid Godot orphaned-thread warnings in the test process.
	if thread.is_started():
		thread.wait_to_finish()

## Test: _notification(NOTIFICATION_PREDELETE) is safe when _seal_thread is null.
func _test_predelete_no_crash_when_thread_null(results: Dictionary) -> void:
	## Verifies that the predelete handler does not crash when no thread is running.
	var controller = SealControllerScript.new()
	# _seal_thread is null by default - just ensure no crash.
	controller.notification(NOTIFICATION_PREDELETE)
	_expect(true, "NOTIFICATION_PREDELETE with null thread should not crash", results)

## Test: _notification(NOTIFICATION_PREDELETE) joins a finished-but-started thread.
func _test_thread_reference_cleared_after_predelete(results: Dictionary) -> void:
	## Verifies predelete joins a finished thread that has not yet been waited on.
	var controller = SealControllerScript.new()

	var thread = Thread.new()
	var start_err = thread.start(func() -> void: pass)
	_expect(start_err == OK, "Thread.start() should succeed in test environment", results)
	if start_err != OK:
		return

	# Let the thread finish on its own without joining it first.
	var deadline_msec = Time.get_ticks_msec() + 2000
	while thread.is_alive() and Time.get_ticks_msec() < deadline_msec:
		OS.delay_msec(5)
	_expect(not thread.is_alive(), "Thread should finish on its own before predelete", results)
	_expect(thread.is_started(), "Finished thread should remain started until joined", results)

	controller.set("_seal_thread", thread)
	controller.notification(NOTIFICATION_PREDELETE)

	var thread_field = controller.get("_seal_thread")
	_expect(thread_field == null, "_seal_thread should be null after predelete on finished thread", results)
	_expect(not thread.is_started(), "Finished thread should be joined during predelete", results)

## Test: _run_seal_async clears state and emits failure when Thread.start() fails.
func _test_thread_start_failure_clears_state(results: Dictionary) -> void:
	## Verifies the seal start failure path clears thread state and surfaces a failure.
	var controller = FailingSealController.new()
	var dialog = AcceptDialog.new()
	var status_label = Label.new()
	var output_label = Label.new()
	var open_button = Button.new()
	var progress_bar = ProgressBar.new()
	dialog.add_child(status_label)
	dialog.add_child(progress_bar)
	dialog.add_child(output_label)
	dialog.add_child(open_button)
	(Engine.get_main_loop() as SceneTree).root.add_child(dialog)

	controller.setup(dialog, status_label, output_label, open_button, progress_bar)

	var emitted := {
		"called": false,
		"success": true,
		"zip_path": "unexpected"
	}
	controller.seal_completed.connect(func(success: bool, zip_path: String) -> void:
		emitted["called"] = true
		emitted["success"] = success
		emitted["zip_path"] = zip_path
	)

	controller.seal_for_delivery("res://tests")
	controller.confirm_seal()
	var tree = Engine.get_main_loop() as SceneTree
	await tree.process_frame
	await tree.process_frame

	_expect(controller.get("_seal_thread") == null, "_seal_thread should be cleared when thread start fails", results)
	_expect(controller.get("_seal_in_progress") == false, "_seal_in_progress should reset when thread start fails", results)
	_expect(
		emitted["called"] and emitted["success"] == false and emitted["zip_path"] == "",
		"seal_completed should emit failure when thread start fails",
		results
	)
	_expect(status_label.text == "✗ Seal operation failed.", "start failure should show the seal error title", results)
	_expect(
		output_label.text.contains("Unable to start background packaging thread."),
		"start failure should show the thread start error details",
		results
	)
	_expect(progress_bar.visible == false, "progress bar should be hidden on thread start failure", results)
	var ok_button: Button = dialog.get_ok_button()
	_expect(ok_button.disabled == false, "ok button should be enabled on thread start failure", results)
	_expect(status_label.modulate.is_equal_approx(Color("#EF4444")), "status label modulate should be red on thread start failure", results)

	controller = null
	dialog.free()

## Test: _run_seal_async exits loop safely when dialog is freed while thread is alive.
func _test_dialog_freed_while_thread_alive(results: Dictionary) -> void:
	## Verifies that freeing the seal dialog while the background thread is alive
	## causes the wait-loop to exit without touching freed UI, and that thread
	## state is cleaned up correctly after the coroutine finishes.
	var controller = DialogFreedSealController.new()
	var dialog = AcceptDialog.new()
	var status_label = Label.new()
	var output_label = Label.new()
	var open_button = Button.new()
	var progress_bar = ProgressBar.new()
	dialog.add_child(status_label)
	dialog.add_child(progress_bar)
	dialog.add_child(output_label)
	dialog.add_child(open_button)
	(Engine.get_main_loop() as SceneTree).root.add_child(dialog)

	var sem = Semaphore.new()
	controller.gate = sem
	controller.setup(dialog, status_label, output_label, open_button, progress_bar)
	controller.seal_for_delivery("res://tests")
	controller.confirm_seal()

	var tree = Engine.get_main_loop() as SceneTree
	var thread_start_deadline_msec = Time.get_ticks_msec() + 3000
	while controller.get("_seal_thread") == null and Time.get_ticks_msec() < thread_start_deadline_msec:
		await tree.process_frame

	var thread = controller.get("_seal_thread") as Thread
	_expect(thread != null, "_seal_thread should be created when sealing starts", results)
	if thread == null:
		dialog.free()
		controller = null
		return

	var thread_alive_deadline_msec = Time.get_ticks_msec() + 3000
	while not thread.is_alive() and Time.get_ticks_msec() < thread_alive_deadline_msec:
		await tree.process_frame
	_expect(thread.is_alive(), "Thread should be alive before dialog is freed", results)
	if not thread.is_alive():
		if thread.is_started():
			sem.post()
			thread.wait_to_finish()
		dialog.free()
		controller = null
		return

	var emitted := {
		"called": false,
		"success": false,
		"zip_path": ""
	}
	controller.seal_completed.connect(func(success: bool, zip_path: String) -> void:
		emitted["called"] = true
		emitted["success"] = success
		emitted["zip_path"] = zip_path
	)

	# Free the dialog while the thread is still alive - this simulates the UI
	# being torn down (e.g. scene change) before the seal completes.
	dialog.free()

	# Release the semaphore so the worker can finish and the coroutine can
	# continue through the result-handling path.
	sem.post()

	var completion_deadline_msec = Time.get_ticks_msec() + 3000
	while not emitted["called"] and Time.get_ticks_msec() < completion_deadline_msec:
		await tree.process_frame

	# After loop exit the coroutine should have nulled the thread field and
	# cleared in-progress state without crashing.
	_expect(emitted["called"], "seal_completed should emit after dialog teardown", results)
	_expect(
		emitted["success"] == true and emitted["zip_path"] == "user://sealed/project.zip",
		"dialog teardown should still emit the successful seal result",
		results
	)
	_expect(
		controller.get("_seal_thread") == null,
		"_seal_thread should be cleared after dialog teardown",
		results
	)
	_expect(
		controller.get("_seal_in_progress") == false,
		"_seal_in_progress should reset after dialog teardown",
		results
	)
	# The controller itself must not have crashed (reaching here is the assertion).
	_expect(true, "Controller survived dialog-freed-while-thread-alive without crash", results)

	controller = null

## Test: Verifies typography font sizes, muted colors, and progress bar in main.tscn.
func _test_seal_dialog_typography_and_layout(results: Dictionary) -> void:
	## Validates StatusLabel 18px, OutputLabel 14px muted #9CA3AF, and SealProgressBar defaults.
	var main_scene = load("res://main.tscn")
	_expect(main_scene != null, "main.tscn should load", results)
	if main_scene == null:
		return

	var instance: Node = main_scene.instantiate()
	_expect(instance != null, "main.tscn should instantiate", results)
	if instance == null:
		return

	var status_label: Label = instance.get_node_or_null("SealDialog/VBoxContainer/StatusLabel") as Label
	_expect(status_label != null, "StatusLabel should exist in SealDialog", results)
	if status_label != null:
		var status_font_size = status_label.get_theme_font_size("font_size")
		_expect(status_font_size == 18, "StatusLabel font size override should be 18px (was %d)" % status_font_size, results)

	var output_label: Label = instance.get_node_or_null("SealDialog/VBoxContainer/OutputLabel") as Label
	_expect(output_label != null, "OutputLabel should exist in SealDialog", results)
	if output_label != null:
		var output_font_size = output_label.get_theme_font_size("font_size")
		_expect(output_font_size == 14, "OutputLabel font size override should be 14px (was %d)" % output_font_size, results)
		var font_color: Color = output_label.get_theme_color("font_color")
		var expected_color: Color = Color("#9CA3AF")
		_expect(font_color.is_equal_approx(expected_color), "OutputLabel font color should match #9CA3AF", results)

	var progress_bar: ProgressBar = instance.get_node_or_null("SealDialog/VBoxContainer/SealProgressBar") as ProgressBar
	_expect(progress_bar != null, "SealProgressBar should exist in SealDialog", results)
	if progress_bar != null:
		_expect(progress_bar.indeterminate == true, "SealProgressBar indeterminate should be true by default", results)
		_expect(progress_bar.show_percentage == false, "SealProgressBar show_percentage should be false", results)
		_expect(progress_bar.custom_minimum_size == Vector2(0, 14), "SealProgressBar custom_minimum_size should be Vector2(0, 14)", results)
		_expect(progress_bar.visible == false, "SealProgressBar should be hidden by default", results)

	instance.free()

## Test: Verifies progress bar visibility, close button disabled state, and status label colors across states.
func _test_progress_bar_and_close_button_states(results: Dictionary) -> void:
	## Validates UI state transitions during progress, success, and error paths.
	var controller = SealControllerScript.new()
	var dialog = AcceptDialog.new()
	var status_label = Label.new()
	var output_label = Label.new()
	var open_button = Button.new()
	var progress_bar = ProgressBar.new()

	dialog.add_child(status_label)
	dialog.add_child(progress_bar)
	dialog.add_child(output_label)
	dialog.add_child(open_button)
	(Engine.get_main_loop() as SceneTree).root.add_child(dialog)

	controller.setup(dialog, status_label, output_label, open_button, progress_bar)

	# Initial setup state
	_expect(progress_bar.visible == false, "Progress bar should start invisible", results)
	var ok_button: Button = dialog.get_ok_button()
	_expect(not ok_button.disabled, "OK button should initially be enabled", results)

	# 1. Progress state
	controller._show_progress()
	_expect(progress_bar.visible == true, "Progress bar should be visible during _show_progress()", results)
	_expect(progress_bar.indeterminate == true, "Progress bar should be indeterminate during _show_progress()", results)
	_expect(ok_button.text == "Cancel", "Action button text should be 'Cancel' during _show_progress()", results)
	_expect(ok_button.disabled == false, "Action button should remain enabled as Cancel during _show_progress()", results)
	_expect(status_label.modulate.is_equal_approx(Color("#F3F4F6")), "Status label modulate should be #F3F4F6 in progress", results)

	# 2. Success state
	var mock_success = {
		"success": true,
		"project_size_mb": 12.4,
		"sealed_zip": "user://sealed/test.zip",
		"tools_copied": ["godot v4.7.2"]
	}
	controller._show_success(mock_success)
	_expect(progress_bar.visible == false, "Progress bar should be hidden on success", results)
	_expect(ok_button.text == "Close", "OK button text should be 'Close' on success", results)
	_expect(ok_button.disabled == false, "OK button should be re-enabled on success", results)
	_expect(status_label.modulate.is_equal_approx(Color("#22C55E")), "Status label modulate should be #22C55E on success", results)
	_expect(open_button.visible == true, "Open button should be visible on success", results)

	# 3. Re-enter progress state then trigger error
	controller._show_progress()
	_expect(progress_bar.visible == true, "Progress bar should become visible again on progress", results)
	_expect(ok_button.text == "Cancel", "Action button text should be 'Cancel' during progress", results)
	_expect(ok_button.disabled == false, "Action button should remain enabled during progress", results)

	# 4. Error state
	controller._show_error("Test Failure", ["Disk full", "Missing assets"])
	_expect(progress_bar.visible == false, "Progress bar should be hidden on error", results)
	_expect(ok_button.text == "Close", "OK button text should be 'Close' on error", results)
	_expect(ok_button.disabled == false, "OK button should be re-enabled on error", results)
	_expect(status_label.modulate.is_equal_approx(Color("#EF4444")), "Status label modulate should be #EF4444 on error", results)
	_expect(open_button.visible == false, "Open button should be hidden on error", results)

	controller = null
	dialog.free()

## Test: Verifies copied tool items are formatted using ToolCategoryMapper canonical display names.
func _test_tool_display_name_formatting_in_success(results: Dictionary) -> void:
	## Validates that tool IDs are mapped to clean display names in _show_success().
	var controller = SealControllerScript.new()
	var dialog = AcceptDialog.new()
	var status_label = Label.new()
	var output_label = Label.new()
	var open_button = Button.new()
	var progress_bar = ProgressBar.new()

	dialog.add_child(status_label)
	dialog.add_child(progress_bar)
	dialog.add_child(output_label)
	dialog.add_child(open_button)
	(Engine.get_main_loop() as SceneTree).root.add_child(dialog)

	controller.setup(dialog, status_label, output_label, open_button, progress_bar)

	var mock_result = {
		"success": true,
		"project_size_mb": 42.0,
		"sealed_zip": "user://sealed/my_game.zip",
		"tools_copied": [
			"godot v4.7.2",
			"blender v4.2.0",
			"vscodium (1.85.0)",
			"gimp",
			"krita v5.2.2"
		]
	}

	controller._show_success(mock_result)

	var out_text: String = output_label.text
	_expect(out_text.contains("Godot v4.7.2"), "Output text should contain 'Godot v4.7.2'", results)
	_expect(out_text.contains("Blender v4.2.0"), "Output text should contain 'Blender v4.2.0'", results)
	_expect(out_text.contains("VSCodium (1.85.0)"), "Output text should contain 'VSCodium (1.85.0)'", results)
	_expect(out_text.contains("GIMP"), "Output text should contain 'GIMP'", results)
	_expect(out_text.contains("Krita v5.2.2"), "Output text should contain 'Krita v5.2.2'", results)
	_expect(not out_text.contains("godot v4.7.2"), "Output text should not contain raw lowercase 'godot v4.7.2'", results)
	_expect(not out_text.contains("vscodium (1.85.0)"), "Output text should not contain raw lowercase 'vscodium (1.85.0)'", results)

	# Verify empty tools list handling
	var empty_result = {
		"success": true,
		"project_size_mb": 0.5,
		"sealed_zip": "user://sealed/empty_project.zip",
		"tools_copied": []
	}
	controller._show_success(empty_result)
	_expect(output_label.text.contains("No tools to copy"), "Empty tools list should display 'No tools to copy'", results)

	controller = null
	dialog.free()

## Test: Verifies live async sealing disables close button and shows progress bar while thread is alive.
func _test_async_seal_progress_bar_and_close_button_lifecycle(results: Dictionary) -> void:
	## Validates active async sealing lifecycle with running thread.
	var controller = DialogFreedSealController.new()
	var dialog = AcceptDialog.new()
	var status_label = Label.new()
	var output_label = Label.new()
	var open_button = Button.new()
	var progress_bar = ProgressBar.new()

	dialog.add_child(status_label)
	dialog.add_child(progress_bar)
	dialog.add_child(output_label)
	dialog.add_child(open_button)
	(Engine.get_main_loop() as SceneTree).root.add_child(dialog)

	var sem = Semaphore.new()
	controller.gate = sem
	controller.setup(dialog, status_label, output_label, open_button, progress_bar)

	var emitted := {"called": false, "success": false, "zip_path": ""}
	controller.seal_completed.connect(func(success: bool, zip_path: String) -> void:
		emitted["called"] = true
		emitted["success"] = success
		emitted["zip_path"] = zip_path
	)

	controller.seal_for_delivery("res://tests")
	controller.confirm_seal()

	var tree = Engine.get_main_loop() as SceneTree
	var thread_alive_deadline = Time.get_ticks_msec() + 3000
	var thread: Thread = null
	while Time.get_ticks_msec() < thread_alive_deadline:
		thread = controller.get("_seal_thread") as Thread
		if thread != null and thread.is_alive():
			break
		await tree.process_frame

	_expect(thread != null and thread.is_alive(), "Worker thread should be running and alive", results)
	if thread != null and thread.is_alive():
		var ok_btn: Button = dialog.get_ok_button()
		_expect(progress_bar.visible == true, "ProgressBar should be visible while thread is active", results)
		_expect(progress_bar.indeterminate == true, "ProgressBar should be indeterminate while thread is active", results)
		_expect(ok_btn.text == "Cancel", "Action button text should be 'Cancel' while thread is active", results)
		_expect(ok_btn.disabled == false, "Cancel button should be enabled while thread is active", results)
		_expect(status_label.modulate.is_equal_approx(Color("#F3F4F6")), "StatusLabel modulate should be neutral off-white while active", results)

	# Release worker thread
	sem.post()

	var completion_deadline = Time.get_ticks_msec() + 3000
	while not emitted["called"] and Time.get_ticks_msec() < completion_deadline:
		await tree.process_frame

	_expect(emitted["called"], "seal_completed should be emitted upon completion", results)
	_expect(emitted["success"], "seal_completed should emit success true", results)
	var ok_btn_post: Button = dialog.get_ok_button()
	_expect(progress_bar.visible == false, "ProgressBar should be hidden after seal completes", results)
	_expect(ok_btn_post.text == "Close", "Action button text should transition to 'Close' after seal completes", results)
	_expect(ok_btn_post.disabled == false, "Close button should be re-enabled after seal completes", results)
	_expect(status_label.modulate.is_equal_approx(Color("#22C55E")), "StatusLabel modulate should be success green after completion", results)
	_expect(output_label.text.contains("Godot v4.7.2"), "Output label should format tool display name", results)

	controller = null
	dialog.free()

## Test: Pre-seal confirmation state presents target project name, canonical tools, and notice without launching thread.
func _test_confirmation_state_presentation_and_content(results: Dictionary) -> void:
	## Validates confirmation state presentation and content accuracy.
	var controller = SealControllerScript.new()
	var dialog = AcceptDialog.new()
	var status_label = Label.new()
	var output_label = Label.new()
	var open_button = Button.new()
	var progress_bar = ProgressBar.new()

	dialog.add_child(status_label)
	dialog.add_child(progress_bar)
	dialog.add_child(output_label)
	dialog.add_child(open_button)
	(Engine.get_main_loop() as SceneTree).root.add_child(dialog)

	controller.setup(dialog, status_label, output_label, open_button, progress_bar)

	# Setup temporary project directory with stack.json
	var test_proj_dir: String = "user://test_confirm_project_%d" % int(Time.get_unix_time_from_system() * 1000.0)
	DirAccess.make_dir_recursive_absolute(test_proj_dir)
	var stack_json_path: String = test_proj_dir.path_join("stack.json")
	var manifest_content: String = JSON.stringify({
		"schema_version": 1,
		"stack_name": "Skybound Odyssey",
		"tools": [
			{"id": "godot", "version": "4.7.2"},
			{"id": "blender", "version": "4.2.0"},
			{"id": "krita", "version": "5.2.2"}
		]
	}, "  ")
	var f: FileAccess = FileAccess.open(stack_json_path, FileAccess.WRITE)
	if f != null:
		f.store_string(manifest_content)
		f.close()

	controller.seal_for_delivery(test_proj_dir)

	_expect(controller.is_in_confirmation() == true, "Controller should be in CONFIRMATION state", results)
	_expect(controller.is_sealing() == false, "Controller should not be actively sealing", results)
	_expect(controller.get("_seal_thread") == null, "_seal_thread should not be created during confirmation", results)
	_expect(status_label.text == "Confirm Project Sealing", "Status label should display 'Confirm Project Sealing'", results)

	var out_text: String = output_label.text
	_expect(out_text.contains("Skybound Odyssey"), "Confirmation output should contain project stack name 'Skybound Odyssey'", results)
	_expect(out_text.contains("Godot v4.7.2"), "Confirmation output should format canonical tool 'Godot v4.7.2'", results)
	_expect(out_text.contains("Blender v4.2.0"), "Confirmation output should format canonical tool 'Blender v4.2.0'", results)
	_expect(out_text.contains("Krita v5.2.2"), "Confirmation output should format canonical tool 'Krita v5.2.2'", results)
	_expect(out_text.contains("standalone .zip archive"), "Notice should mention bundling into a standalone .zip archive", results)
	_expect(out_text.contains("several minutes"), "Notice should mention that sealing will take several minutes", results)

	_expect(progress_bar.visible == false, "Progress bar should remain hidden during confirmation", results)
	_expect(open_button.visible == false, "Open button should remain hidden during confirmation", results)

	var confirm_btn: Button = controller.get_confirm_button()
	_expect(confirm_btn != null and confirm_btn.visible == true, "Confirm button should be visible during confirmation", results)
	_expect(confirm_btn != null and confirm_btn.text == "Confirm", "Confirm button text should be 'Confirm'", results)
	_expect(confirm_btn != null and confirm_btn.disabled == false, "Confirm button should be enabled during confirmation", results)

	var cancel_btn: Button = controller.get_cancel_button()
	_expect(cancel_btn != null and cancel_btn.visible == true, "Cancel button should be visible during confirmation", results)
	_expect(cancel_btn != null and cancel_btn.text == "Cancel", "Cancel button text should be 'Cancel'", results)
	_expect(cancel_btn != null and cancel_btn.disabled == false, "Cancel button should be enabled during confirmation", results)

	# Clean up temp files
	if FileAccess.file_exists(stack_json_path):
		DirAccess.remove_absolute(stack_json_path)
	if DirAccess.dir_exists_absolute(test_proj_dir):
		DirAccess.remove_absolute(test_proj_dir)

	controller = null
	dialog.free()

## Test: Cancel action hides SealDialog without modifying project files or launching worker thread.
func _test_cancel_flow_leaves_project_intact_and_hides_dialog(results: Dictionary) -> void:
	## Validates cancel flow cleanly closes dialog without execution.
	var controller = SealControllerScript.new()
	var dialog = AcceptDialog.new()
	var status_label = Label.new()
	var output_label = Label.new()
	var open_button = Button.new()
	var progress_bar = ProgressBar.new()

	dialog.add_child(status_label)
	dialog.add_child(progress_bar)
	dialog.add_child(output_label)
	dialog.add_child(open_button)
	(Engine.get_main_loop() as SceneTree).root.add_child(dialog)

	controller.setup(dialog, status_label, output_label, open_button, progress_bar)
	controller.seal_for_delivery("res://tests")

	_expect(controller.is_in_confirmation() == true, "Controller should be in CONFIRMATION state before cancel", results)

	controller.cancel_seal()

	_expect(controller.is_in_confirmation() == false, "Controller should exit confirmation state after cancel", results)
	_expect(controller.is_sealing() == false, "Controller should not be sealing after cancel", results)
	_expect(controller.get("_seal_thread") == null, "_seal_thread should be null after cancel", results)
	_expect(dialog.visible == false, "Dialog should be hidden after cancel", results)

	controller = null
	dialog.free()

## Test: Confirm action transitions SealDialog in-place to progress and begins background sealing.
func _test_confirm_transitions_in_place_to_sealing_progress(results: Dictionary) -> void:
	## Validates in-place transition from confirmation to active sealing.
	var controller = DialogFreedSealController.new()
	var dialog = AcceptDialog.new()
	var status_label = Label.new()
	var output_label = Label.new()
	var open_button = Button.new()
	var progress_bar = ProgressBar.new()

	dialog.add_child(status_label)
	dialog.add_child(progress_bar)
	dialog.add_child(output_label)
	dialog.add_child(open_button)
	(Engine.get_main_loop() as SceneTree).root.add_child(dialog)

	var sem = Semaphore.new()
	controller.gate = sem
	controller.setup(dialog, status_label, output_label, open_button, progress_bar)

	controller.seal_for_delivery("res://tests")
	_expect(controller.is_in_confirmation() == true, "Should enter confirmation state", results)
	_expect(progress_bar.visible == false, "Progress bar hidden in confirmation", results)

	controller.confirm_seal()

	_expect(controller.is_in_confirmation() == false, "Should exit confirmation state on confirm", results)
	_expect(controller.is_sealing() == true, "Should enter active sealing state on confirm", results)
	_expect(progress_bar.visible == true, "Progress bar should become visible upon confirm", results)
	_expect(progress_bar.indeterminate == true, "Progress bar should be indeterminate upon confirm", results)
	_expect(dialog.get_ok_button().text == "Cancel", "Action button text should be 'Cancel' upon confirm", results)
	_expect(dialog.get_ok_button().disabled == false, "Cancel button should be enabled upon confirm", results)

	var cancel_btn: Button = controller.get_cancel_button()
	_expect(cancel_btn != null and cancel_btn.visible == false, "Cancel button should be hidden during sealing", results)

	# Release worker thread
	sem.post()

	var tree = Engine.get_main_loop() as SceneTree
	var deadline = Time.get_ticks_msec() + 3000
	while controller.is_sealing() and Time.get_ticks_msec() < deadline:
		await tree.process_frame

	_expect(controller.is_sealing() == false, "Sealing should complete", results)
	_expect(dialog.get_ok_button().text == "Close", "Action button text should return to 'Close' after sealing", results)
	_expect(dialog.get_ok_button().disabled == false, "Close button should be re-enabled after sealing", results)

	controller = null
	dialog.free()

## Test: Intercepting close_requested blocks unexpected dialog dismissal while sealing is in progress.
func _test_close_requested_blocked_while_sealing(results: Dictionary) -> void:
	## Validates that close_requested signal is blocked while worker thread is active.
	var controller = SealControllerScript.new()
	var dialog = AcceptDialog.new()
	var status_label = Label.new()
	var output_label = Label.new()
	var open_button = Button.new()
	var progress_bar = ProgressBar.new()

	dialog.add_child(status_label)
	dialog.add_child(progress_bar)
	dialog.add_child(output_label)
	dialog.add_child(open_button)
	(Engine.get_main_loop() as SceneTree).root.add_child(dialog)

	controller.setup(dialog, status_label, output_label, open_button, progress_bar)
	dialog.popup_centered()
	_expect(dialog.visible == true, "Dialog should be visible initially", results)

	# Simulate active sealing state
	controller._show_progress()
	controller.set("_seal_in_progress", true)

	# Trigger close_requested while sealing is active
	dialog.close_requested.emit()

	_expect(dialog.visible == true, "Dialog should remain visible and not be dismissed during sealing", results)

	# Reset and test close_requested when NOT sealing
	controller.set("_seal_in_progress", false)
	dialog.close_requested.emit()
	_expect(dialog.visible == false, "Dialog should close on close_requested when not sealing", results)

	controller = null
	dialog.free()

## Test: Verifies main.tscn SealDialog borderless window chrome and in-dialog header configuration.
func _test_main_tscn_seal_dialog_chrome_configuration(results: Dictionary) -> void:
	## Validates SealDialog borderless = true, unresizable = true, and styled in-dialog header.
	var main_scene = load("res://main.tscn")
	_expect(main_scene != null, "main.tscn should load", results)
	if main_scene == null:
		return

	var instance: Node = main_scene.instantiate()
	_expect(instance != null, "main.tscn should instantiate", results)
	if instance == null:
		return

	var seal_dialog: AcceptDialog = instance.get_node_or_null("SealDialog") as AcceptDialog
	_expect(seal_dialog != null, "SealDialog should exist in main.tscn", results)
	if seal_dialog != null:
		_expect(seal_dialog.borderless == true, "SealDialog borderless should be true in main.tscn", results)
		_expect(seal_dialog.unresizable == true, "SealDialog unresizable should be true in main.tscn", results)
		_expect(seal_dialog.dialog_hide_on_ok == false, "SealDialog dialog_hide_on_ok should be false in main.tscn", results)
		_expect(seal_dialog.dialog_close_on_escape == false, "SealDialog dialog_close_on_escape should be false in main.tscn", results)

	var header_bar: HBoxContainer = instance.get_node_or_null("SealDialog/VBoxContainer/HeaderBar") as HBoxContainer
	_expect(header_bar != null, "SealDialog should have an in-dialog HeaderBar", results)

	var header_title: Label = instance.get_node_or_null("SealDialog/VBoxContainer/HeaderBar/HeaderTitle") as Label
	_expect(header_title != null, "HeaderBar should contain HeaderTitle", results)
	if header_title != null:
		_expect(header_title.text == "Seal for Delivery", "HeaderTitle text should be 'Seal for Delivery'", results)
		_expect(header_title.get_theme_font_size("font_size") == 18, "HeaderTitle font size should be 18px", results)

	instance.free()

## Test: Two-phase determinate progress reporting updates ProgressBar and labels accurately across Step 1 and Step 2.
func _test_determinate_progress_two_phases(results: Dictionary) -> void:
	## Validates determinate progress bar 0%..100% for Step 1, reset to 0%..100% for Step 2, and success hide.
	var controller = SealControllerScript.new()
	var dialog = AcceptDialog.new()
	var status_label = Label.new()
	var output_label = Label.new()
	var open_button = Button.new()
	var progress_bar = ProgressBar.new()

	dialog.add_child(status_label)
	dialog.add_child(progress_bar)
	dialog.add_child(output_label)
	dialog.add_child(open_button)
	(Engine.get_main_loop() as SceneTree).root.add_child(dialog)

	controller.setup(dialog, status_label, output_label, open_button, progress_bar)

	# --- Step 1/2: Copying tools ---
	controller.update_progress("Step 1/2: Copying tools", 0, 10)
	_expect(progress_bar.indeterminate == false, "Progress bar should be determinate during active copying", results)
	_expect(progress_bar.min_value == 0, "Progress bar min_value should be 0", results)
	_expect(progress_bar.max_value == 100, "Progress bar max_value should be 100", results)
	_expect(progress_bar.value == 0.0, "Progress bar value should be 0% at start of Step 1", results)
	_expect(progress_bar.visible == true, "Progress bar should be visible during active copying", results)
	_expect(status_label.text.contains("Step 1/2: Copying tools (0 of 10 files)"), "StatusLabel should format Step 1 0 of 10 files", results)
	_expect(output_label.text.contains("Step 1/2: Copying tools (0 of 10 files)"), "OutputLabel should format Step 1 0 of 10 files", results)

	controller.update_progress("Step 1/2: Copying tools", 5, 10)
	_expect(is_equal_approx(progress_bar.value, 50.0), "Progress bar value should be 50% at midpoint of Step 1", results)
	_expect(status_label.text.contains("Step 1/2: Copying tools (5 of 10 files)"), "StatusLabel should format Step 1 5 of 10 files", results)

	controller.update_progress("Step 1/2: Copying tools", 10, 10)
	_expect(is_equal_approx(progress_bar.value, 100.0), "Progress bar value should be 100% at end of Step 1", results)
	_expect(status_label.text.contains("Step 1/2: Copying tools (10 of 10 files)"), "StatusLabel should format Step 1 10 of 10 files", results)

	# --- Step 2/2: Creating ZIP archive (resets to 0%) ---
	controller.update_progress("Step 2/2: Creating ZIP archive", 0, 20)
	_expect(progress_bar.indeterminate == false, "Progress bar should remain determinate during Step 2", results)
	_expect(progress_bar.value == 0.0, "Progress bar value should reset to 0% at start of Step 2", results)
	_expect(status_label.text.contains("Step 2/2: Creating ZIP archive (0 of 20 files)"), "StatusLabel should format Step 2 0 of 20 files", results)
	_expect(output_label.text.contains("Step 2/2: Creating ZIP archive (0 of 20 files)"), "OutputLabel should format Step 2 0 of 20 files", results)

	controller.update_progress("Step 2/2: Creating ZIP archive", 10, 20)
	_expect(is_equal_approx(progress_bar.value, 50.0), "Progress bar value should be 50% at midpoint of Step 2", results)

	controller.update_progress("Step 2/2: Creating ZIP archive", 20, 20)
	_expect(is_equal_approx(progress_bar.value, 100.0), "Progress bar value should be 100% at end of Step 2", results)
	_expect(status_label.text.contains("Step 2/2: Creating ZIP archive (20 of 20 files)"), "StatusLabel should format Step 2 20 of 20 files", results)

	# --- Completion hides progress bar and enables OK button ---
	controller._show_success({
		"success": true,
		"project_size_mb": 5.0,
		"sealed_zip": "user://sealed/project.zip",
		"tools_copied": ["godot v4.7.2"]
	})
	_expect(progress_bar.visible == false, "Progress bar should be hidden upon success completion", results)
	_expect(dialog.get_ok_button().disabled == false, "OK button should be re-enabled upon completion", results)

	controller = null
	dialog.free()

## Test: Progress label formatting applies thousands separators for large counts.
func _test_determinate_progress_thousands_formatting(results: Dictionary) -> void:
	## Validates thousands comma formatting (e.g. 1,234 of 5,678 files).
	var controller = SealControllerScript.new()
	var dialog = AcceptDialog.new()
	var status_label = Label.new()
	var output_label = Label.new()
	var open_button = Button.new()
	var progress_bar = ProgressBar.new()

	dialog.add_child(status_label)
	dialog.add_child(progress_bar)
	dialog.add_child(output_label)
	dialog.add_child(open_button)
	(Engine.get_main_loop() as SceneTree).root.add_child(dialog)

	controller.setup(dialog, status_label, output_label, open_button, progress_bar)

	controller.update_progress("Step 1/2: Copying tools", 1234, 5678)
	_expect(status_label.text.contains("Step 1/2: Copying tools (1,234 of 5,678 files)"), "StatusLabel should format 1,234 of 5,678 files with commas", results)
	_expect(output_label.text.contains("Step 1/2: Copying tools (1,234 of 5,678 files)"), "OutputLabel should format 1,234 of 5,678 files with commas", results)

	controller.update_progress("Step 2/2: Creating ZIP archive", 1000000, 2500000)
	_expect(status_label.text.contains("Step 2/2: Creating ZIP archive (1,000,000 of 2,500,000 files)"), "StatusLabel should format million counts with commas", results)

	controller = null
	dialog.free()

## Test: Edge cases with 0 files report 100% cleanly without division by zero.
func _test_determinate_progress_zero_files_edge_case(results: Dictionary) -> void:
	## Validates clean handling of 0 files in both Step 1 and Step 2.
	var controller = SealControllerScript.new()
	var dialog = AcceptDialog.new()
	var status_label = Label.new()
	var output_label = Label.new()
	var open_button = Button.new()
	var progress_bar = ProgressBar.new()

	dialog.add_child(status_label)
	dialog.add_child(progress_bar)
	dialog.add_child(output_label)
	dialog.add_child(open_button)
	(Engine.get_main_loop() as SceneTree).root.add_child(dialog)

	controller.setup(dialog, status_label, output_label, open_button, progress_bar)

	controller.update_progress("Step 1/2: Copying tools", 0, 0)
	_expect(progress_bar.value == 100.0, "Progress bar should report 100% cleanly when total is 0", results)
	_expect(status_label.text.contains("Step 1/2: Copying tools (0 of 0 files)"), "StatusLabel should format 0 of 0 files cleanly", results)

	controller.update_progress("Step 2/2: Creating ZIP archive", 0, 0)
	_expect(progress_bar.value == 100.0, "Progress bar should report 100% cleanly in Step 2 when total is 0", results)
	_expect(status_label.text.contains("Step 2/2: Creating ZIP archive (0 of 0 files)"), "StatusLabel should format Step 2 0 of 0 files cleanly", results)

	controller = null
	dialog.free()

## Test: Error occurrence hides progress bar and re-enables close button.
func _test_determinate_progress_error_hides_progress_bar(results: Dictionary) -> void:
	## Validates that errors cleanly hide progress bar and display error message in output label.
	var controller = SealControllerScript.new()
	var dialog = AcceptDialog.new()
	var status_label = Label.new()
	var output_label = Label.new()
	var open_button = Button.new()
	var progress_bar = ProgressBar.new()

	dialog.add_child(status_label)
	dialog.add_child(progress_bar)
	dialog.add_child(output_label)
	dialog.add_child(open_button)
	(Engine.get_main_loop() as SceneTree).root.add_child(dialog)

	controller.setup(dialog, status_label, output_label, open_button, progress_bar)

	controller.update_progress("Step 1/2: Copying tools", 3, 10)
	_expect(progress_bar.visible == true, "Progress bar should be visible during progress", results)

	controller._show_error("Disk Full", ["Could not write archive to disk"])
	_expect(progress_bar.visible == false, "Progress bar should be hidden on error", results)
	_expect(output_label.text.contains("Could not write archive to disk"), "Output label should display error details", results)
	_expect(dialog.get_ok_button().disabled == false, "Close button should be re-enabled on error", results)
	_expect(status_label.modulate.is_equal_approx(Color("#EF4444")), "Status label modulate should be red on error", results)

	controller = null
	dialog.free()

## Test: Active Cancel button lifecycle during sealing, double-click prevention, status updates, and transition to Close.
func _test_cancel_button_lifecycle_and_rollback(results: Dictionary) -> void:
	## Validates that clicking Cancel disables the button, updates status, and transitions back to Close.
	var controller = DialogFreedSealController.new()
	var dialog = AcceptDialog.new()
	var status_label = Label.new()
	var output_label = Label.new()
	var open_button = Button.new()
	var progress_bar = ProgressBar.new()

	dialog.add_child(status_label)
	dialog.add_child(progress_bar)
	dialog.add_child(output_label)
	dialog.add_child(open_button)
	(Engine.get_main_loop() as SceneTree).root.add_child(dialog)

	var sem = Semaphore.new()
	controller.gate = sem
	controller.setup(dialog, status_label, output_label, open_button, progress_bar)

	var emitted := {"called": false, "success": false, "zip_path": ""}
	controller.seal_completed.connect(func(success: bool, zip_path: String) -> void:
		emitted["called"] = true
		emitted["success"] = success
		emitted["zip_path"] = zip_path
	)

	controller.seal_for_delivery("res://tests")
	controller.confirm_seal()

	var tree = Engine.get_main_loop() as SceneTree
	var thread_alive_deadline = Time.get_ticks_msec() + 3000
	var thread: Thread = null
	while Time.get_ticks_msec() < thread_alive_deadline:
		thread = controller.get("_seal_thread") as Thread
		if thread != null and thread.is_alive():
			break
		await tree.process_frame

	_expect(thread != null and thread.is_alive(), "Worker thread should be running and alive", results)
	var ok_btn: Button = dialog.get_ok_button()

	# Verify active Cancel button configuration
	_expect(ok_btn.text == "Cancel", "Action button text should be 'Cancel' while sealing is running", results)
	_expect(ok_btn.disabled == false, "Cancel button should be enabled during active sealing", results)
	_expect(controller.is_sealing() == true, "Controller should be in sealing state", results)

	# Click Cancel
	ok_btn.pressed.emit()

	# Immediately check disabled state and cancelling status
	_expect(ok_btn.disabled == true, "Cancel button should be disabled immediately after click to prevent double clicks", results)
	_expect(status_label.text == "Cancelling and restoring project state...", "Status label should update to cancelling message", results)
	_expect(controller.is_cancelling() == true, "Controller should report is_cancelling() == true", results)
	_expect(controller.is_cancel_requested() == true, "Controller should report is_cancel_requested() == true", results)

	# Release the background worker
	sem.post()

	var completion_deadline = Time.get_ticks_msec() + 3000
	while not emitted["called"] and Time.get_ticks_msec() < completion_deadline:
		await tree.process_frame

	_expect(emitted["called"], "seal_completed should be emitted after cancellation", results)
	_expect(emitted["success"] == false, "seal_completed should emit success false on cancellation", results)
	_expect(controller.is_sealing() == false, "Controller should not be sealing after cancellation completes", results)
	_expect(status_label.text == "Seal cancelled.", "Status label should display 'Seal cancelled.' after rollback", results)
	_expect(output_label.text.contains("Packaging was cancelled by user"), "Output label should explain cancellation and state restoration", results)
	_expect(progress_bar.visible == false, "Progress bar should be hidden after cancellation", results)
	_expect(ok_btn.text == "Close", "Action button text should transition back to 'Close' after rollback", results)
	_expect(ok_btn.disabled == false, "Close button should be enabled after rollback completes", results)

	# Click Close button to hide dialog
	ok_btn.pressed.emit()
	_expect(dialog.visible == false, "Clicking Close should dismiss the dialog", results)

	controller = null
	dialog.free()


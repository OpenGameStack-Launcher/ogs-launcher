## SealControllerTests: Unit tests for SealController thread lifecycle.
##
## Covers the NOTIFICATION_PREDELETE join behavior added to SealController:
##   (a) thread is joined cleanly when the controller is freed while a thread
##       is still alive,
##   (b) the predelete handler is safe when no thread is running, and
##   (c) the _seal_thread reference is cleared even when the thread has
##       already finished before predelete fires, and
##   (d) the thread start failure path clears seal state and emits failure.

extends RefCounted
class_name SealControllerTests

const SealControllerScript = preload("res://scripts/launcher/seal_controller.gd")

class FailingSealController:
	extends SealController

	func _start_seal_thread(_project_path: String) -> int:
		## Forces a thread start failure so the controller's error path can be tested.
		return ERR_CANT_CREATE

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

	# Safety: if the thread is still alive after the handler returns, join it
	# here to avoid Godot orphaned-thread warnings in the test process.
	if thread.is_alive():
		thread.wait_to_finish()

## Test: _notification(NOTIFICATION_PREDELETE) is safe when _seal_thread is null.
func _test_predelete_no_crash_when_thread_null(results: Dictionary) -> void:
	## Verifies that the predelete handler does not crash when no thread is running.
	var controller = SealControllerScript.new()
	# _seal_thread is null by default — just ensure no crash.
	controller.notification(NOTIFICATION_PREDELETE)
	_expect(true, "NOTIFICATION_PREDELETE with null thread should not crash", results)

## Test: _seal_thread reference is null after predelete even for an already-finished thread.
func _test_thread_reference_cleared_after_predelete(results: Dictionary) -> void:
	## Verifies _seal_thread is cleared to null when the thread is already done.
	var controller = SealControllerScript.new()

	var thread = Thread.new()
	var start_err = thread.start(func() -> void: pass)
	_expect(start_err == OK, "Thread.start() should succeed in test environment", results)
	if start_err != OK:
		return

	# Wait for the thread to finish before triggering predelete.
	thread.wait_to_finish()
	_expect(not thread.is_alive(), "Thread should not be alive after wait_to_finish()", results)

	controller.set("_seal_thread", thread)
	controller.notification(NOTIFICATION_PREDELETE)

	var thread_field = controller.get("_seal_thread")
	_expect(thread_field == null, "_seal_thread should be null after predelete on finished thread", results)

## Test: _run_seal_async clears state and emits failure when Thread.start() fails.
func _test_thread_start_failure_clears_state(results: Dictionary) -> void:
	## Verifies the seal start failure path clears thread state and surfaces a failure.
	var controller = FailingSealController.new()
	var dialog = AcceptDialog.new()
	var status_label = Label.new()
	var output_label = Label.new()
	var open_button = Button.new()
	dialog.add_child(status_label)
	dialog.add_child(output_label)
	dialog.add_child(open_button)
	(Engine.get_main_loop() as SceneTree).root.add_child(dialog)

	controller.setup(dialog, status_label, output_label, open_button)

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

	await controller._run_seal_async("res://tests")

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

	dialog.free()

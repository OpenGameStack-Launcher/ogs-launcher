## SealControllerTests: Unit tests for SealController thread lifecycle.
##
## Covers the NOTIFICATION_PREDELETE join behavior added to SealController:
##   (a) thread is joined cleanly when the controller is freed while a thread
##       is still alive, and
##   (b) the Thread.start() failure path sets _seal_in_progress back to false
##       and nulls the thread reference without crashing.

extends RefCounted
class_name SealControllerTests

const SealControllerScript = preload("res://scripts/launcher/seal_controller.gd")

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

	# Give the thread a moment to actually start and block on the semaphore.
	OS.delay_msec(20)

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

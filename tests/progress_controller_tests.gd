## ProgressControllerTests: Unit tests for progress tracking functionality.
##
## Validates ProgressController's ability to manage inline progress tracking
## for tool downloads and installations across multiple concurrent operations.

extends RefCounted
class_name ProgressControllerTests

const ProgressControllerScript = preload("res://scripts/tools/progress_controller.gd")

func run() -> Dictionary:
	## Runs all ProgressController unit tests.
	var results = {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	
	_test_track_inline_progress(results)
	_test_update_progress_basic(results)
	_test_update_progress_auto_install_transition(results)
	_test_set_install_phase(results)
	_test_complete_progress(results)
	_test_cancel_progress(results)
	_test_is_tracking(results)
	_test_get_phase(results)
	_test_multiple_concurrent_tracking(results)
	_test_progress_signals(results)
	
	return results

## Helper: Creates mock UI elements for testing.
func _create_mock_ui() -> Dictionary:
	## Creates mock Progress Bar, Label, and Container nodes.
	return {
		"progress_bar": ProgressBar.new(),
		"label": Label.new(),
		"container": Control.new()
	}

## Helper: Frees mock UI elements.
func _free_mock_ui(ui: Dictionary) -> void:
	## Frees all mock UI nodes.
	if ui.has("progress_bar") and ui["progress_bar"] != null:
		ui["progress_bar"].free()
	if ui.has("label") and ui["label"] != null:
		ui["label"].free()
	if ui.has("container") and ui["container"] != null:
		ui["container"].free()

## Helper: Assertion wrapper.
func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records test result.
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

## Test: track_inline_progress registers tracking.
func _test_track_inline_progress(results: Dictionary) -> void:
	## Verifies track_inline_progress registers progress tracking correctly.
	var controller = ProgressControllerScript.new()
	var ui = _create_mock_ui()
	
	controller.track_inline_progress("godot", "4.3", ui["progress_bar"], ui["label"], ui["container"])
	
	_expect(controller.is_tracking("godot", "4.3"), "should track godot 4.3", results)
	_expect(controller.get_phase("godot", "4.3") == ProgressControllerScript.Phase.DOWNLOAD, "should start in DOWNLOAD phase", results)
	_expect(ui["container"].visible == false, "container should start hidden", results)
	_expect(ui["progress_bar"].visible == false, "progress_bar should start hidden", results)
	
	_free_mock_ui(ui)

## Test: update_progress shows progress UI.
func _test_update_progress_basic(results: Dictionary) -> void:
	## Verifies update_progress shows and updates progress UI.
	var controller = ProgressControllerScript.new()
	var ui = _create_mock_ui()
	
	controller.track_inline_progress("blender", "4.5.7", ui["progress_bar"], ui["label"], ui["container"])
	controller.update_progress("blender", "4.5.7", 5242880, 10485760)  # 5MB / 10MB
	
	_expect(ui["container"].visible == true, "container should become visible", results)
	_expect(ui["progress_bar"].visible == true, "progress_bar should become visible", results)
	_expect(ui["progress_bar"].indeterminate == false, "progress_bar should not be indeterminate", results)
	_expect(abs(ui["progress_bar"].value - 50.0) < 0.1, "progress_bar should show 50%", results)
	_expect(ui["label"].visible == true, "label should become visible", results)
	_expect(ui["label"].text.contains("5.0"), "label should show downloaded MB", results)
	_expect(ui["label"].text.contains("10.0"), "label should show total MB", results)
	
	_free_mock_ui(ui)

## Test: update_progress auto-transitions to install phase.
func _test_update_progress_auto_install_transition(results: Dictionary) -> void:
	## Verifies update_progress auto-transitions to install when download completes.
	var controller = ProgressControllerScript.new()
	var ui = _create_mock_ui()
	
	controller.track_inline_progress("godot", "4.3", ui["progress_bar"], ui["label"], ui["container"])
	controller.update_progress("godot", "4.3", 10485760, 10485760)  # 10MB / 10MB (complete)
	
	_expect(controller.get_phase("godot", "4.3") == ProgressControllerScript.Phase.INSTALL, "should auto-transition to INSTALL", results)
	_expect(ui["progress_bar"].indeterminate == true, "should switch to indeterminate", results)
	_expect(ui["label"].text == "Installing...", "label should show 'Installing...'", results)
	
	_free_mock_ui(ui)

## Test: set_install_phase transitions manually.
func _test_set_install_phase(results: Dictionary) -> void:
	## Verifies set_install_phase transitions to install mode.
	var controller = ProgressControllerScript.new()
	var ui = _create_mock_ui()
	
	controller.track_inline_progress("krita", "5.2", ui["progress_bar"], ui["label"], ui["container"])
	controller.set_install_phase("krita", "5.2")
	
	_expect(controller.get_phase("krita", "5.2") == ProgressControllerScript.Phase.INSTALL, "phase should be INSTALL", results)
	_expect(ui["container"].visible == true, "container should be visible", results)
	_expect(ui["progress_bar"].indeterminate == true, "progress_bar should be indeterminate", results)
	_expect(ui["label"].text == "Installing...", "label should show 'Installing...'", results)
	
	_free_mock_ui(ui)

## Test: complete_progress hides UI and cleans up.
func _test_complete_progress(results: Dictionary) -> void:
	## Verifies complete_progress hides UI and removes tracking.
	var controller = ProgressControllerScript.new()
	var ui = _create_mock_ui()
	
	controller.track_inline_progress("audacity", "3.7", ui["progress_bar"], ui["label"], ui["container"])
	ui["container"].visible = true  # Simulate visible progress
	controller.complete_progress("audacity", "3.7")
	
	_expect(ui["container"].visible == false, "container should be hidden", results)
	_expect(controller.is_tracking("audacity", "3.7") == false, "should no longer track", results)
	_expect(controller.get_phase("audacity", "3.7") == null, "phase should be null", results)
	
	_free_mock_ui(ui)

## Test: cancel_progress hides UI and cleans up.
func _test_cancel_progress(results: Dictionary) -> void:
	## Verifies cancel_progress hides UI and removes tracking.
	var controller = ProgressControllerScript.new()
	var ui = _create_mock_ui()
	
	controller.track_inline_progress("godot", "4.3", ui["progress_bar"], ui["label"], ui["container"])
	ui["container"].visible = true  # Simulate visible progress
	controller.cancel_progress("godot", "4.3")
	
	_expect(ui["container"].visible == false, "container should be hidden", results)
	_expect(controller.is_tracking("godot", "4.3") == false, "should no longer track", results)
	
	_free_mock_ui(ui)

## Test: is_tracking works before and after tracking.
func _test_is_tracking(results: Dictionary) -> void:
	## Verifies is_tracking returns correct state.
	var controller = ProgressControllerScript.new()
	var ui = _create_mock_ui()
	
	_expect(controller.is_tracking("blender", "4.5") == false, "should not track initially", results)
	
	controller.track_inline_progress("blender", "4.5", ui["progress_bar"], ui["label"], ui["container"])
	_expect(controller.is_tracking("blender", "4.5") == true, "should track after registration", results)
	
	controller.complete_progress("blender", "4.5")
	_expect(controller.is_tracking("blender", "4.5") == false, "should not track after completion", results)
	
	_free_mock_ui(ui)

## Test: get_phase returns correct phase.
func _test_get_phase(results: Dictionary) -> void:
	## Verifies get_phase returns correct phase at each stage.
	var controller = ProgressControllerScript.new()
	var ui = _create_mock_ui()
	
	_expect(controller.get_phase("godot", "4.3") == null, "phase should be null before tracking", results)
	
	controller.track_inline_progress("godot", "4.3", ui["progress_bar"], ui["label"], ui["container"])
	_expect(controller.get_phase("godot", "4.3") == ProgressControllerScript.Phase.DOWNLOAD, "phase should be DOWNLOAD", results)
	
	controller.set_install_phase("godot", "4.3")
	_expect(controller.get_phase("godot", "4.3") == ProgressControllerScript.Phase.INSTALL, "phase should be INSTALL", results)
	
	controller.complete_progress("godot", "4.3")
	_expect(controller.get_phase("godot", "4.3") == null, "phase should be null after completion", results)
	
	_free_mock_ui(ui)

## Test: Multiple concurrent tool tracking.
func _test_multiple_concurrent_tracking(results: Dictionary) -> void:
	## Verifies multiple tools can be tracked concurrently.
	var controller = ProgressControllerScript.new()
	var ui1 = _create_mock_ui()
	var ui2 = _create_mock_ui()
	var ui3 = _create_mock_ui()
	
	controller.track_inline_progress("godot", "4.3", ui1["progress_bar"], ui1["label"], ui1["container"])
	controller.track_inline_progress("blender", "4.5", ui2["progress_bar"], ui2["label"], ui2["container"])
	controller.track_inline_progress("krita", "5.2", ui3["progress_bar"], ui3["label"], ui3["container"])
	
	_expect(controller.is_tracking("godot", "4.3"), "should track godot", results)
	_expect(controller.is_tracking("blender", "4.5"), "should track blender", results)
	_expect(controller.is_tracking("krita", "5.2"), "should track krita", results)
	
	controller.update_progress("godot", "4.3", 5000000, 10000000)
	controller.set_install_phase("blender", "4.5")
	
	_expect(controller.get_phase("godot", "4.3") == ProgressControllerScript.Phase.DOWNLOAD, "godot should be in DOWNLOAD", results)
	_expect(controller.get_phase("blender", "4.5") == ProgressControllerScript.Phase.INSTALL, "blender should be in INSTALL", results)
	_expect(controller.get_phase("krita", "5.2") == ProgressControllerScript.Phase.DOWNLOAD, "krita should be in DOWNLOAD", results)
	
	controller.complete_progress("godot", "4.3")
	_expect(controller.is_tracking("godot", "4.3") == false, "godot should stop tracking", results)
	_expect(controller.is_tracking("blender", "4.5") == true, "blender should still track", results)
	_expect(controller.is_tracking("krita", "5.2") == true, "krita should still track", results)
	
	_free_mock_ui(ui1)
	_free_mock_ui(ui2)
	_free_mock_ui(ui3)

## Test: Progress signals emitted correctly.
func _test_progress_signals(results: Dictionary) -> void:
	## Verifies progress_completed and progress_cancelled signals emit.
	var controller = ProgressControllerScript.new()
	var ui1 = _create_mock_ui()
	var ui2 = _create_mock_ui()
	
	# Test completed signal
	var completed_received = {"tool_id": "", "version": ""}
	var completed_handler = func(tool_id, version):
		completed_received["tool_id"] = tool_id
		completed_received["version"] = version
	
	controller.progress_completed.connect(completed_handler)
	controller.track_inline_progress("godot", "4.3", ui1["progress_bar"], ui1["label"], ui1["container"])
	
	# Verify tracking before completing
	var is_tracked_before = controller.is_tracking("godot", "4.3")
	controller.complete_progress("godot", "4.3")
	
	_expect(is_tracked_before, "should be tracked before complete", results)
	_expect(completed_received["tool_id"] == "godot", "completed signal should have tool_id='godot', got: '%s'" % completed_received["tool_id"], results)
	_expect(completed_received["version"] == "4.3", "completed signal should have version='4.3', got: '%s'" % completed_received["version"], results)
	
	# Test cancelled signal
	var cancelled_received = {"tool_id": "", "version": ""}
	var cancelled_handler = func(tool_id, version):
		cancelled_received["tool_id"] = tool_id
		cancelled_received["version"] = version
	
	controller.progress_cancelled.connect(cancelled_handler)
	controller.track_inline_progress("blender", "4.5", ui2["progress_bar"], ui2["label"], ui2["container"])
	var is_tracked_before2 = controller.is_tracking("blender", "4.5")
	controller.cancel_progress("blender", "4.5")
	
	_expect(is_tracked_before2, "should be tracked before cancel", results)
	_expect(cancelled_received["tool_id"] == "blender", "cancelled signal should have tool_id='blender', got: '%s'" % cancelled_received["tool_id"], results)
	_expect(cancelled_received["version"] == "4.5", "cancelled signal should have version='4.5', got: '%s'" % cancelled_received["version"], results)
	
	_free_mock_ui(ui1)
	_free_mock_ui(ui2)

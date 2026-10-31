## RemoteProjectDialogTests: Comprehensive unit and scene tests for RemoteProjectDialogController.
##
## Validates dialog instantiation, UI hierarchy, URL validation, destination override,
## subfolder collision resolution, async clone tracking, cancellation, and missing-Git guidance.
extends RefCounted
class_name RemoteProjectDialogTests

const RemoteProjectDialogControllerScript = preload("res://scripts/projects/remote_project_dialog.gd")
const RemoteProjectCloner = preload("res://scripts/projects/remote_project_cloner.gd")
const OfflineEnforcer = preload("res://scripts/network/offline_enforcer.gd")
const OgsConfig = preload("res://scripts/config/ogs_config.gd")
const LibraryManager = preload("res://scripts/library/library_manager.gd")

func run() -> Dictionary:
	## Executes all remote project dialog tests and returns aggregated results.
	var results := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	
	_test_dialog_instantiation_and_hierarchy(results)
	_test_url_input_enables_clone_button(results)
	_test_destination_prefilled_and_override(results)
	_test_subfolder_collision_detection_and_suggestion(results)
	_test_invalid_url_shows_error_keeps_dialog_open(results)
	_test_manifest_failure_re_enables_inputs_preserves_url(results)
	_test_cancel_during_clone_calls_cancel_and_resets(results)
	_test_successful_clone_closes_dialog_and_emits_signal(results)
	_test_missing_git_guided_dialog_emits_tool_view(results)
	_test_offline_blocks_dialog_open(results)
	
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records assertion pass or failure in test accumulator.
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_dialog_instantiation_and_hierarchy(results: Dictionary) -> void:
	## Verifies that all required UI nodes in the dialog hierarchy are instantiated.
	var root = Control.new()
	var controller = RemoteProjectDialogControllerScript.new()
	controller.setup(root)
	
	_expect(controller.dialog != null, "dialog should be instantiated", results)
	_expect(controller.dialog.exclusive == true, "dialog should be exclusive", results)
	_expect(controller.dialog.unresizable == true, "dialog should be unresizable", results)
	_expect(controller.dialog.ok_button_text == "Clone", "dialog OK button text should be 'Clone'", results)
	_expect(controller.dialog.cancel_button_text == "Cancel", "dialog cancel button text should be 'Cancel'", results)
	_expect(controller.header_label != null, "header_label should exist", results)
	_expect(controller.url_edit != null, "url_edit LineEdit should exist", results)
	_expect(controller.dest_edit != null, "dest_edit LineEdit should exist", results)
	_expect(controller.btn_browse != null, "btn_browse Button should exist", results)
	_expect(controller.lbl_status != null, "lbl_status Label should exist", results)
	_expect(controller.progress_bar != null, "progress_bar should exist", results)
	_expect(controller.missing_git_dialog != null, "missing_git_dialog should exist", results)
	_expect(controller.collision_dialog != null, "collision_dialog should exist", results)
	_expect(controller.collision_folder_edit != null, "collision_folder_edit should exist", results)
	
	controller.free_nodes()
	root.free()

func _test_url_input_enables_clone_button(results: Dictionary) -> void:
	## Verifies that the Clone button enables only when non-empty URL text is present.
	var root = Control.new()
	var controller = RemoteProjectDialogControllerScript.new()
	controller.setup(root)
	
	var ok_btn = controller.dialog.get_ok_button()
	_expect(ok_btn != null, "dialog OK button should exist", results)
	if ok_btn != null:
		_expect(ok_btn.disabled == true, "Clone button should be disabled initially", results)
		
		# Whitespace-only string should leave button disabled
		controller.url_edit.text = "   "
		controller._on_url_text_changed("   ")
		_expect(ok_btn.disabled == true, "Clone button should remain disabled for whitespace URL", results)
		
		# Valid URL enables button
		controller.url_edit.text = "https://github.com/OpenGameStack/sample-project.git"
		controller._on_url_text_changed(controller.url_edit.text)
		_expect(ok_btn.disabled == false, "Clone button should be enabled for valid URL", results)
		
		# Clearing URL disables button again
		controller.url_edit.text = ""
		controller._on_url_text_changed("")
		_expect(ok_btn.disabled == true, "Clone button should disable when URL is cleared", results)
	
	controller.free_nodes()
	root.free()

func _test_destination_prefilled_and_override(results: Dictionary) -> void:
	## Verifies destination field pre-fills with Primary Projects Folder and allows manual override.
	var root = Control.new()
	var controller = RemoteProjectDialogControllerScript.new()
	controller.setup(root)
	
	var primary_path = "user://test_primary_projects"
	controller.show_clone_dialog(primary_path)
	_expect(controller.dest_edit.text == primary_path, "Destination should pre-fill with primary folder", results)
	
	# Manual override
	var custom_path = "user://custom_destination_override"
	controller.dest_edit.text = custom_path
	_expect(controller.dest_edit.text == custom_path, "Destination should accept user override", results)
	
	controller.dialog.hide()
	controller.free_nodes()
	root.free()

func _test_subfolder_collision_detection_and_suggestion(results: Dictionary) -> void:
	## Verifies subfolder collision detection and suggested incremental naming.
	var test_root = "user://test_collision_dir"
	var global_test_root = ProjectSettings.globalize_path(test_root)
	DirAccess.make_dir_recursive_absolute(global_test_root)
	
	var existing_folder = global_test_root.path_join("sample-game")
	DirAccess.make_dir_recursive_absolute(existing_folder)
	
	var root = Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var controller = RemoteProjectDialogControllerScript.new()
	controller.setup(root)
	
	controller.dest_edit.text = global_test_root
	controller.url_edit.text = "https://github.com/org/sample-game.git"
	
	# Trigger clone attempt which encounters existing folder
	controller._on_clone_pressed()
	
	_expect(controller.collision_dialog.visible == true, "Collision dialog should open on duplicate folder", results)
	_expect(controller.collision_folder_edit.text == "sample-game-1", "Suggested folder name should be sample-game-1", results)
	
	# Create sample-game-1 and verify next suggestion increments to sample-game-2
	var existing_inc1 = global_test_root.path_join("sample-game-1")
	DirAccess.make_dir_recursive_absolute(existing_inc1)
	var next_suggestion = RemoteProjectCloner.suggest_next_available_folder_name(global_test_root, "sample-game")
	_expect(next_suggestion == "sample-game-2", "Next suggestion should be sample-game-2, got: " + next_suggestion, results)
	
	# Clean up test directories
	DirAccess.remove_absolute(existing_inc1)
	DirAccess.remove_absolute(existing_folder)
	DirAccess.remove_absolute(global_test_root)
	
	controller.collision_dialog.hide()
	root.free()

func _test_invalid_url_shows_error_keeps_dialog_open(results: Dictionary) -> void:
	## Verifies invalid URL produces an inline error message and keeps modal open with input intact.
	var root = Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var controller = RemoteProjectDialogControllerScript.new()
	controller.setup(root)
	controller.show_clone_dialog("user://test_projects")
	
	var disallowed_url = "file:///disallowed/local/path"
	controller.dest_edit.text = "user://test_projects"
	controller.url_edit.text = disallowed_url
	
	controller._on_clone_pressed()
	
	_expect(not controller.lbl_status.text.is_empty(), "Status label should display error message", results)
	_expect(controller.url_edit.text == disallowed_url, "URL text should remain intact after validation error", results)
	_expect(controller.dialog.visible == true, "Dialog should remain open on validation failure", results)
	
	root.free()

func _test_manifest_failure_re_enables_inputs_preserves_url(results: Dictionary) -> void:
	## Verifies manifest verification error keeps dialog open, re-enables inputs, and preserves URL.
	var root = Control.new()
	var controller = RemoteProjectDialogControllerScript.new()
	controller.setup(root)
	
	var entered_url = "https://github.com/org/missing-stack-project.git"
	controller.url_edit.text = entered_url
	controller._set_busy_ui(true)
	
	# Simulate cloner emitting clone_failed for missing manifest
	var error_msg = "Repository root must contain stack.json manifest."
	controller._on_cloner_clone_failed("missing_stack_json", error_msg)
	
	_expect(controller.lbl_status.text == error_msg, "Status label should display manifest error message", results)
	_expect(controller.url_edit.text == entered_url, "Entered URL should remain intact after manifest failure", results)
	_expect(controller.url_edit.editable == true, "URL LineEdit should be re-enabled", results)
	_expect(controller.dest_edit.editable == true, "Destination LineEdit should be re-enabled", results)
	_expect(controller.btn_browse.disabled == false, "Browse button should be re-enabled", results)
	_expect(controller.dialog.get_ok_button().disabled == false, "Clone button should be re-enabled", results)
	
	controller.free_nodes()
	root.free()

func _test_cancel_during_clone_calls_cancel_and_resets(results: Dictionary) -> void:
	## Verifies clicking Cancel during active clone changes text to 'Cancelling...' and resets on finish.
	var root = Control.new()
	var controller = RemoteProjectDialogControllerScript.new()
	var cloner = RemoteProjectCloner.new()
	controller.setup(root, null, cloner)
	
	# Start busy UI state
	controller.url_edit.text = "https://github.com/org/test-repo.git"
	controller._set_busy_ui(true)
	
	# Cancel pressed while idle/active
	controller._on_cancel_pressed()
	
	# Cloner reports cancellation completed
	controller._on_cloner_clone_failed("cancelled", "Clone operation was cancelled.")
	
	var cancel_btn = controller.dialog.get_cancel_button()
	_expect(cancel_btn.text == "Cancel", "Cancel button text should reset to 'Cancel'", results)
	_expect(cancel_btn.disabled == false, "Cancel button should be re-enabled", results)
	_expect(controller.url_edit.editable == true, "Inputs should be re-enabled after cancellation", results)
	_expect(controller.lbl_status.text == "Clone operation was cancelled.", "Status label should indicate cancellation", results)
	
	controller.free_nodes()
	root.free()

func _test_successful_clone_closes_dialog_and_emits_signal(results: Dictionary) -> void:
	## Verifies successful clone closes the modal and emits clone_completed signal.
	var root = Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var controller = RemoteProjectDialogControllerScript.new()
	controller.setup(root)
	
	var state := {"emitted": false, "dir": ""}
	controller.clone_completed.connect(func(dir: String):
		state["emitted"] = true
		state["dir"] = dir
	)
	
	controller.show_clone_dialog("user://test_projects")
	_expect(controller.dialog.visible == true, "Dialog should be visible before completion", results)
	
	var expected_cloned_dir = "user://test_projects/my-game"
	controller._on_cloner_clone_completed(expected_cloned_dir)
	
	_expect(controller.dialog.visible == false, "Dialog should be closed after successful clone", results)
	_expect(state["emitted"] == true, "clone_completed signal should be emitted", results)
	_expect(state["dir"] == expected_cloned_dir, "clone_completed should pass cloned directory path", results)
	
	root.free()

func _test_missing_git_guided_dialog_emits_tool_view(results: Dictionary) -> void:
	## Verifies missing-Git prompt opens and emits tool_view_requested upon confirmation.
	var root = Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var controller = RemoteProjectDialogControllerScript.new()
	var empty_lib = LibraryManager.new()
	controller.setup(root, empty_lib)
	
	var state := {"called": false, "tool_id": "", "version": ""}
	controller.tool_view_requested.connect(func(tid: String, ver: String):
		state["called"] = true
		state["tool_id"] = tid
		state["version"] = ver
	)
	
	controller.open("user://test_projects")
	_expect(controller.missing_git_dialog.visible == true, "missing_git_dialog should open when Git is not installed", results)
	
	controller._on_missing_git_confirmed()
	_expect(controller.missing_git_dialog.visible == false, "missing_git_dialog should hide after confirmation", results)
	_expect(state["called"] == true, "tool_view_requested should be emitted", results)
	_expect(state["tool_id"] == "git", "tool_view_requested should specify 'git'", results)
	
	root.free()

func _test_offline_blocks_dialog_open(results: Dictionary) -> void:
	## Verifies that opening remote clone dialog is blocked when OfflineEnforcer is active.
	var root = Control.new()
	var controller = RemoteProjectDialogControllerScript.new()
	controller.setup(root)
	
	var config = OgsConfig.new()
	config.offline_mode = true
	OfflineEnforcer.apply_config(config)
	controller.open("user://test_projects")
	
	_expect(controller.dialog.visible == false, "Main clone dialog should not open when offline", results)
	_expect(controller.missing_git_dialog.visible == false, "Missing-Git dialog should not open when offline", results)
	
	OfflineEnforcer.reset()
	controller.free_nodes()
	root.free()

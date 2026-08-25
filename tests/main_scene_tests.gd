## MainSceneTests: Scene smoke tests for main.tscn
##
## Verifies the main scene loads and default visibility state is correct.

extends RefCounted
class_name MainSceneTests

func run() -> Dictionary:
	## Runs main scene smoke tests.
## Returns:
## Dictionary: {"passed": int, "failed": int, "failures": Array[String]}
	var results := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	_test_main_scene_loads(results)
	_test_network_ui_disabled_offline(results)
	_test_mirror_root_browse_dialog_frees_on_close(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records test assertion.
## Parameters:
## condition (bool): If true, increments passed; if false, increments failed
## message (String): Failure description
## results (Dictionary): Test accumulator (modified in-place)
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_main_scene_loads(results: Dictionary) -> void:
	## Verifies main.tscn loads and projects page is visible by default.
	var scene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load", results)
	if scene == null:
		return

	var instance = scene.instantiate()
	var page_projects = instance.get_node_or_null("AppLayout/Content/PageProjects")
	var page_tools = instance.get_node_or_null("AppLayout/Content/PageTools")
	var page_settings = instance.get_node_or_null("AppLayout/Content/PageSettings")

	_expect(page_projects != null, "Projects page should exist", results)
	_expect(page_tools != null, "Tools page should exist", results)
	_expect(page_settings != null, "Settings page should exist", results)

	var add_button = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsControls/AddButton")
	_expect(add_button != null, "Add button should exist", results)

	var new_button = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsControls/NewProjectButton")
	_expect(new_button != null, "New Project button should exist", results)

	var projects_list = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectsList")
	_expect(projects_list != null, "Projects list should exist", results)

	var add_tool_button = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ToolActionRow/AddToolButton")
	_expect(add_tool_button != null, "Add Tool button should exist", results)

	var remove_tool_button = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ToolActionRow/RemoveToolButton")
	_expect(remove_tool_button != null, "Remove Tool button should exist", results)

	var remove_button = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectActionRow/RemoveButton")
	_expect(remove_button != null, "Remove Project button should exist", results)

	instance.free()

func _test_network_ui_disabled_offline(results: Dictionary) -> void:
	## Verifies network-related controls are disabled in offline mode.
	var scene = load("res://main.tscn")
	if scene == null:
		_expect(false, "main.tscn should load for offline UI test", results)
		return
	var instance = scene.instantiate()
	var check_updates = instance.get_node_or_null("AppLayout/Content/PageSettings/CheckUpdatesButton")
	_expect(check_updates != null, "Check Updates button should exist", results)
	if check_updates != null:
		instance._collect_network_ui_nodes()
		instance._on_offline_state_changed(true, "offline_mode")
		_expect(check_updates.disabled == true, "network UI should be disabled when offline", results)
	instance.free()

func _test_mirror_root_browse_dialog_frees_on_close(results: Dictionary) -> void:
	## Verifies mirror root browse dialog is queued for free when closed without a selection.
	var scene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for mirror browse dialog close test", results)
	if scene == null:
		return
	var instance = scene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(instance)
	instance._on_mirror_root_browse_pressed()
	var canceled_dialog = _find_new_file_dialog(instance, null)
	_expect(canceled_dialog != null, "mirror root browse should create a file dialog", results)
	if canceled_dialog != null:
		canceled_dialog.canceled.emit()
		_expect(canceled_dialog.is_queued_for_deletion(), "mirror root browse dialog should be queued for free on canceled", results)

	instance._on_mirror_root_browse_pressed()
	var closed_dialog = _find_new_file_dialog(instance, canceled_dialog)
	_expect(closed_dialog != null, "mirror root browse should create a second file dialog", results)
	if closed_dialog != null:
		closed_dialog.close_requested.emit()
		_expect(closed_dialog.is_queued_for_deletion(), "mirror root browse dialog should be queued for free on close_requested", results)
	instance.free()

func _find_new_file_dialog(parent: Node, exclude_dialog: FileDialog) -> FileDialog:
	## Isolates the newest mirror-browse dialog so close-path regression checks target the correct node.
	for idx in range(parent.get_child_count() - 1, -1, -1):
		var child = parent.get_child(idx) as FileDialog
		if child != null and child != exclude_dialog:
			return child
	return null

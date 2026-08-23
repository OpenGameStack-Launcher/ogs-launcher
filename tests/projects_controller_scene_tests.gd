## ProjectsControllerSceneTests: Scene-style tests for ProjectsController
##
## Verifies Unity-Hub-style project-library behaviors with real UI nodes:
##   - Add Project requires stack.json + ogs_config.json
##   - Valid project adds to persistent list and selects automatically
##   - Persisted entries reload on next controller setup

extends RefCounted
class_name ProjectsControllerSceneTests

const ProjectsControllerScript = preload("res://scripts/projects/projects_controller.gd")

func run() -> Dictionary:
	"""Runs all ProjectsController scene tests.
	Returns:
	  Dictionary: {"passed": int, "failed": int, "failures": Array[String]}"""
	var results := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	_test_add_requires_both_project_files(results)
	_test_add_valid_project_populates_lists(results)
	_test_project_registry_persists_between_setups(results)
	_test_project_removal(results)
	_test_new_project_creates_scaffold_and_adds(results)
	_test_launch_button_disabled_initially(results)
	_test_launch_button_enabled_after_select(results)
	_test_offline_enforcer_updates(results)
	_test_offline_enforcer_updates(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	"""Records test assertion.
	Parameters:
	  condition (bool): If true, increments passed; if false, increments failed
	  message (String): Failure description
	  results (Dictionary): Test accumulator (modified in-place)"""
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _build_controller(storage_path: String) -> Dictionary:
	"""Creates a controller with UI nodes wired for testing.

	Parameters:
	  storage_path (String): user:// path for isolated project index persistence

	Returns:
	  Dictionary: Controller and created nodes
	"""
	var controller = ProjectsControllerScript.new()
	controller.set_projects_index_path_for_tests(storage_path)
	var add_button = Button.new()
	var new_button = Button.new()
	var projects_list = ItemList.new()
	var status_label = Label.new()
	var offline_label = Label.new()
	var explorer_title_lbl = Label.new()
	var explorer_tree = Tree.new()
	var new_folder_btn = Button.new()
	var new_file_btn = Button.new()
	var new_file_dialog = ConfirmationDialog.new()
	var new_file_name = LineEdit.new()
	var add_tool_button = Button.new()
	var remove_tool_button = Button.new()
	var remove_button = Button.new()
	var launch_button = Button.new()
	var dialog = FileDialog.new()
	var remove_dialog = ConfirmationDialog.new()
	var new_project_dialog = ConfirmationDialog.new()
	var new_project_name = LineEdit.new()
	var add_tool_dialog = ConfirmationDialog.new()
	var add_tool_option = ItemList.new()

	# Setup without ToolsController (optional)
	controller.setup(
		add_button,
		new_button,
		projects_list,
		status_label,
		offline_label,
		explorer_title_lbl,
		explorer_tree,
		new_folder_btn,
		new_file_btn,
		new_file_dialog,
		new_file_name,
		add_tool_button,
		remove_tool_button,
		remove_button,
		launch_button,
		dialog,
		remove_dialog,
		new_project_dialog,
		new_project_name,
		add_tool_dialog,
		add_tool_option,
		null  # tools_controller is optional
	)

	return {
		"controller": controller,
		"projects": projects_list,
		"status": status_label,
		"offline": offline_label,
		"tree": explorer_tree,
		"remove_btn": remove_button,
		"launch_btn": launch_button,
		"new_name": new_project_name,
		"remove_dialog": remove_dialog,
		"nodes": [add_button, new_button, projects_list, status_label, offline_label, explorer_tree, new_folder_btn, new_file_btn, new_file_dialog, new_file_name, add_tool_button, remove_tool_button, remove_button, launch_button, dialog, remove_dialog, new_project_dialog, new_project_name, add_tool_dialog, add_tool_option]
	}

func _cleanup_nodes(nodes: Array) -> void:
	"""Frees UI nodes created during tests to avoid leaks."""
	for node in nodes:
		if node:
			node.free()

func _cleanup_registry(storage_path: String) -> void:
	"""Deletes test project index file to keep tests isolated."""
	if not FileAccess.file_exists(storage_path):
		return
	var absolute = ProjectSettings.globalize_path(storage_path)
	DirAccess.remove_absolute(absolute)

func _cleanup_dir_recursive(user_or_abs_path: String) -> void:
	"""Recursively removes a directory tree used by new-project tests."""
	if user_or_abs_path.is_empty():
		return
	var path = user_or_abs_path
	if path.begins_with("user://"):
		path = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir = DirAccess.open(path)
	if dir != null:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				var full_path = path.path_join(file_name)
				if dir.current_is_dir():
					_cleanup_dir_recursive(full_path)
				else:
					DirAccess.remove_absolute(full_path)
			file_name = dir.get_next()
	DirAccess.remove_absolute(path)

func _test_add_requires_both_project_files(results: Dictionary) -> void:
	"""Verifies Add Project rejects folder missing required files."""
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_missing_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	var ctx = _build_controller(storage_path)
	var controller = ctx["controller"]
	var added = controller.add_project_from_path("res://samples/does_not_exist")
	_expect(not added, "missing project directory should fail to add", results)
	_cleanup_nodes(ctx["nodes"])
	_cleanup_registry(storage_path)

func _test_add_valid_project_populates_lists(results: Dictionary) -> void:
	"""Verifies valid sample project is added and selected."""
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_valid_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	var ctx = _build_controller(storage_path)
	var controller = ctx["controller"]
	var added = controller.add_project_from_path("res://samples/sample_project")
	var projects_list: ItemList = ctx["projects"]
	var explorer_tree: Tree = ctx["tree"]
	_expect(added, "valid project should be added", results)
	_expect(projects_list.item_count == 1, "projects list should include added project", results)
	_expect(explorer_tree.get_root() != null, "selected project should populate explorer tree", results)
	_cleanup_nodes(ctx["nodes"])
	_cleanup_registry(storage_path)

func _test_project_registry_persists_between_setups(results: Dictionary) -> void:
	"""Verifies added projects are persisted and reloaded on next setup."""
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_persist_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)

	var ctx1 = _build_controller(storage_path)
	var controller1 = ctx1["controller"]
	controller1.add_project_from_path("res://samples/sample_project")
	_cleanup_nodes(ctx1["nodes"])

	var ctx2 = _build_controller(storage_path)
	var projects_list: ItemList = ctx2["projects"]
	_expect(projects_list.item_count == 1, "persisted project should reload on next setup", results)
	_cleanup_nodes(ctx2["nodes"])
	_cleanup_registry(storage_path)

func _test_project_removal(results: Dictionary) -> void:
	"""Verifies projects can be removed and it persists."""
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_remove_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	
	var ctx = _build_controller(storage_path)
	var controller = ctx["controller"]
	controller.add_project_from_path("res://samples/sample_project")
	
	var projects_list: ItemList = ctx["projects"]
	var remove_dialog: ConfirmationDialog = ctx["remove_dialog"]
	
	_expect(projects_list.item_count == 1, "projects list should contain one project before removal", results)
	controller._on_remove_project_pressed()
	controller._on_remove_project_confirmed()
	
	_expect(projects_list.item_count == 0, "projects list should be empty after removal", results)
	_cleanup_nodes(ctx["nodes"])
	
	var ctx_reload = _build_controller(storage_path)
	var projects_list_reload: ItemList = ctx_reload["projects"]
	_expect(projects_list_reload.item_count == 0, "registry should persist project removal", results)
	_cleanup_nodes(ctx_reload["nodes"])
	_cleanup_registry(storage_path)

func _test_new_project_creates_scaffold_and_adds(results: Dictionary) -> void:
	"""Verifies New Project creates files and auto-adds project to library."""
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_new_%s.json" % str(Time.get_ticks_msec())
	var projects_root = "user://projects_controller_scene_new_root_%s" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	_cleanup_dir_recursive(projects_root)

	var ctx = _build_controller(storage_path)
	var controller = ctx["controller"]
	controller.set_projects_root_path_for_tests(projects_root)
	var projects_list: ItemList = ctx["projects"]
	var new_name: LineEdit = ctx["new_name"]
	new_name.text = "Unit Test New Project"

	var created = controller._create_new_project_from_name(new_name.text)
	_expect(created, "new project should be created", results)
	_expect(projects_list.item_count >= 1, "created project should appear in project library", results)
	var created_dir = ProjectSettings.globalize_path(projects_root.path_join("Unit_Test_New_Project"))
	_expect(DirAccess.dir_exists_absolute(created_dir), "new project folder should be created in OGS_Projects root", results)
	_cleanup_nodes(ctx["nodes"])
	_cleanup_dir_recursive(projects_root)
	_cleanup_registry(storage_path)

func _test_launch_button_disabled_initially(results: Dictionary) -> void:
	"""Verifies launch button starts disabled."""
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_launch0_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	var ctx = _build_controller(storage_path)
	var launch_btn: Button = ctx["launch_btn"]
	_expect(launch_btn.disabled == true, "launch button should be disabled initially", results)
	_cleanup_nodes(ctx["nodes"])
	_cleanup_registry(storage_path)

func _test_launch_button_enabled_after_select(results: Dictionary) -> void:
	"""Verifies launch button is enabled after selecting valid project."""
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_launch1_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	var ctx = _build_controller(storage_path)
	var controller = ctx["controller"]
	var launch_btn: Button = ctx["launch_btn"]
	var added = controller.add_project_from_path("res://samples/sample_project")
	_expect(added, "project should add successfully", results)
	_expect(launch_btn.disabled == false, "launch button should be enabled after valid select", results)
	_cleanup_nodes(ctx["nodes"])
	_cleanup_registry(storage_path)

func _test_launch_after_click_uses_selected_tool(results: Dictionary) -> void:
	"""Verifies clicked tool is treated as selected by launch handler."""
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_launch_click_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	var ctx = _build_controller(storage_path)
	var controller = ctx["controller"]
	var status_label: Label = ctx["status"]
	var tools_list: ItemList = ctx["list"]
	var added = controller.add_project_from_path("res://samples/sample_project")
	_expect(added, "project should add successfully for launch-click test", results)
	if added and tools_list.item_count > 0:
		tools_list.item_clicked.emit(0, Vector2.ZERO, 1)
		controller._on_launch_tool_pressed()
		_expect(status_label.text.find("No tool selected") == -1, "launch after click should not report no-selection", results)
	else:
		_expect(false, "sample project should provide at least one tool", results)
	_cleanup_nodes(ctx["nodes"])
	_cleanup_registry(storage_path)

func _test_launch_no_selection(results: Dictionary) -> void:
	"""Verifies launching with no tool selected shows error."""
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_launch2_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	var ctx = _build_controller(storage_path)
	var controller = ctx["controller"]
	var status_label: Label = ctx["status"]
	controller.add_project_from_path("res://samples/sample_project")
	controller._on_launch_tool_pressed()
	_expect(status_label.text.find("No tool selected") != -1, "launch with no selection should error", results)
	_cleanup_nodes(ctx["nodes"])
	_cleanup_registry(storage_path)

func _test_offline_enforcer_updates(results: Dictionary) -> void:
	"""Verifies loading a project applies offline enforcement state."""
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_offline_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	var ctx = _build_controller(storage_path)
	var controller = ctx["controller"]
	controller.add_project_from_path("res://samples/sample_project")
	_expect(not OfflineEnforcer.is_offline(), "sample project should keep offline disabled", results)
	_expect(OfflineEnforcer.get_reason() == "disabled", "sample project should set disabled reason", results)
	_cleanup_nodes(ctx["nodes"])
	_cleanup_registry(storage_path)

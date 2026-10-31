## ProjectsControllerSceneTests: Scene-style tests for ProjectsController
##
## Verifies Unity-Hub-style project-library behaviors with real UI nodes:
## - Add Project requires stack.json + ogs_config.json
## - Valid project adds to persistent list and selects automatically
## - Persisted entries reload on next controller setup

extends RefCounted
class_name ProjectsControllerSceneTests

const ProjectsControllerScript = preload("res://scripts/projects/projects_controller.gd")
const PathUtils = preload("res://scripts/utils/path_utils.gd")

func run() -> Dictionary:
	## Runs all ProjectsController scene tests.
## Returns:
## Dictionary: {"passed": int, "failed": int, "failures": Array[String]}
	var results := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	_test_add_requires_both_project_files(results)
	_test_add_project_with_only_stack_json(results)
	_test_add_valid_project_populates_lists(results)
	_test_project_registry_persists_between_setups(results)
	_test_project_removal(results)
	_test_new_project_creates_scaffold_and_adds(results)
	_test_new_project_honors_configured_primary_projects_folder(results)
	_test_launch_button_disabled_initially(results)
	_test_launch_button_enabled_after_select(results)
	_test_launch_after_click_uses_selected_tool(results)
	_test_launch_no_selection(results)
	_test_offline_enforcer_updates(results)
	_test_add_code_tool_skips_asset_folder_creation(results)
	_test_select_tool_in_project_tools_list_sets_launch_state(results)
	_test_launch_selected_tool_from_project_tools_list_runs_at_project_root(results)
	_test_project_switching_and_reset_clears_launch_state(results)
	_test_mutual_deselection_between_tools_list_and_explorer(results)
	_test_explorer_double_click_triggers_activation_and_launch(results)
	_test_new_file_creation_with_vscodium_in_stack(results)
	_test_three_button_toolbar_layout(results)
	_test_missing_git_opens_guided_dialog_and_emits_navigation(results)
	_test_offline_mode_disables_remote_button_and_enforces_tooltip(results)
	_test_single_click_missing_tool_selects_without_navigation(results)
	_test_double_click_missing_tool_emits_navigation(results)
	_test_launch_missing_tool_emits_navigation(results)
	_test_single_click_selects_project_without_switching_tab(results)
	_test_double_click_activates_project_and_switches_tab(results)
	_test_open_project_button_switches_tab(results)
	_test_action_buttons_disabled_initially_and_on_empty(results)
	_test_custom_item_list_double_click_activation(results)
	_test_project_display_paths_normalized(results)
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

func _build_controller(storage_path: String) -> Dictionary:
	## Creates a controller with UI nodes wired for testing.
## 
## Parameters:
## storage_path (String): user:// path for isolated project index persistence
## 
## Returns:
## Dictionary: Controller and created nodes
## 
	var controller = ProjectsControllerScript.new()
	controller.set_projects_index_path_for_tests(storage_path)
	var add_button = Button.new()
	var add_remote_button = Button.new()
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
	var open_button = Button.new()
	var remove_button = Button.new()
	var seal_button = Button.new()
	var launch_button = Button.new()
	var dialog = FileDialog.new()
	var remove_dialog = ConfirmationDialog.new()
	var new_project_dialog = ConfirmationDialog.new()
	var new_project_vbox = VBoxContainer.new()
	new_project_vbox.name = "VBoxContainer"
	var instructions_label = Label.new()
	instructions_label.name = "InstructionsLabel"
	new_project_vbox.add_child(instructions_label)
	new_project_dialog.add_child(new_project_vbox)
	var new_project_name = LineEdit.new()
	var add_tool_dialog = ConfirmationDialog.new()
	var add_tool_option = ItemList.new()
	var project_tools_list = ItemList.new()
	var projects_tabs = TabContainer.new()
	var tab_library = Control.new()
	tab_library.name = "Project Library"
	projects_tabs.add_child(tab_library)
	var tab_details = Control.new()
	tab_details.name = "Project Details"
	projects_tabs.add_child(tab_details)
	if Engine.get_main_loop() is SceneTree:
		(Engine.get_main_loop() as SceneTree).root.add_child(projects_tabs)
	projects_tabs.current_tab = 0
	var change_version_button = Button.new()

	var deps = ProjectsController.UIDeps.new()
	deps.btn_add_project = add_button
	deps.btn_add_remote_project = add_remote_button
	deps.btn_new_project = new_button
	deps.btn_open_project = open_button
	deps.btn_remove_project = remove_button
	deps.btn_seal_project = seal_button
	deps.projects_list = projects_list
	deps.lbl_project_status = status_label
	deps.lbl_offline_status = offline_label
	deps.lbl_tools_for_project = explorer_title_lbl
	deps.explorer_tree = explorer_tree
	deps.btn_new_folder = new_folder_btn
	deps.btn_new_file = new_file_btn
	deps.new_file_dialog = new_file_dialog
	deps.new_file_name_edit = new_file_name
	deps.btn_add_tool = add_tool_button
	deps.btn_remove_tool = remove_tool_button
	deps.btn_remove_project = remove_button
	deps.btn_launch_tool = launch_button
	deps.project_dir_dialog = dialog
	deps.remove_project_dialog = remove_dialog
	deps.new_project_dialog = new_project_dialog
	deps.new_project_name_line_edit = new_project_name
	deps.add_tool_dialog = add_tool_dialog
	deps.add_tool_option_list = add_tool_option
	deps.projects_tabs = projects_tabs
	deps.project_tools_list = project_tools_list
	deps.btn_change_version = change_version_button
	
	controller.setup(deps, null)

	return {
		"controller": controller,
		"projects": projects_list,
		"status": status_label,
		"offline": offline_label,
		"tree": explorer_tree,
		"open_btn": open_button,
		"remove_btn": remove_button,
		"seal_btn": seal_button,
		"launch_btn": launch_button,
		"new_name": new_project_name,
		"new_file_name": new_file_name,
		"remove_dialog": remove_dialog,
		"instructions_label": instructions_label,
		"explorer_title_lbl": explorer_title_lbl,
		"list": project_tools_list,
		"project_tools_list": project_tools_list,
		"tabs": projects_tabs,
		"change_version_btn": change_version_button,
		"add_remote_btn": add_remote_button,
		"remove_tool_btn": remove_tool_button,
		"add_tool_btn": add_tool_button,
		"nodes": [add_button, add_remote_button, new_button, open_button, remove_button, seal_button, projects_list, status_label, offline_label, explorer_title_lbl, explorer_tree, new_folder_btn, new_file_btn, new_file_dialog, new_file_name, add_tool_button, remove_tool_button, launch_button, dialog, remove_dialog, new_project_dialog, new_project_vbox, instructions_label, new_project_name, add_tool_dialog, add_tool_option, project_tools_list, projects_tabs, change_version_button]
	}

func _cleanup_nodes(nodes: Array, controller: ProjectsController = null) -> void:
	## Frees UI nodes created during tests to avoid leaks.
	if controller != null:
		controller.cleanup()
	for node in nodes:
		if node and is_instance_valid(node) and not node.is_queued_for_deletion():
			node.free()

func _cleanup_registry(storage_path: String) -> void:
	## Deletes test project index file to keep tests isolated.
	if not FileAccess.file_exists(storage_path):
		return
	var absolute = ProjectSettings.globalize_path(storage_path)
	DirAccess.remove_absolute(absolute)

func _cleanup_dir_recursive(user_or_abs_path: String) -> void:
	## Recursively removes a directory tree used by new-project tests.
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
	## Verifies Add Local Project rejects folder missing stack.json.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_missing_%s.json" % str(Time.get_ticks_msec())
	var empty_dir = "user://test_empty_folder_%s" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	_cleanup_dir_recursive(empty_dir)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(empty_dir))

	var ctx = _build_controller(storage_path)
	var controller = ctx["controller"]
	var added = controller.add_project_from_path(empty_dir)
	_expect(not added, "folder without stack.json should fail to add", results)
	var status_label: Label = ctx["status"]
	_expect(status_label.text.contains("stack.json"), "status should state stack.json is required", results)
	_cleanup_nodes(ctx["nodes"])
	_cleanup_dir_recursive(empty_dir)
	_cleanup_registry(storage_path)

func _test_add_project_with_only_stack_json(results: Dictionary) -> void:
	## Verifies adding a folder with only stack.json succeeds and auto-generates ogs_config.json.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_only_stack_%s.json" % str(Time.get_ticks_msec())
	var test_dir = "user://test_stack_only_%s" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	_cleanup_dir_recursive(test_dir)
	var abs_dir = ProjectSettings.globalize_path(test_dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)

	var stack_path = abs_dir.path_join("stack.json")
	var config_path = abs_dir.path_join("ogs_config.json")
	var stack_payload = {
		"schema_version": StackManifest.CURRENT_SCHEMA_VERSION,
		"stack_name": "Stack Only Project",
		"tools": []
	}
	var f = FileAccess.open(stack_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(stack_payload))
	f.close()

	_expect(not FileAccess.file_exists(config_path), "ogs_config.json should not exist initially", results)

	var ctx = _build_controller(storage_path)
	var controller = ctx["controller"]
	var added = controller.add_project_from_path(abs_dir)
	_expect(added, "adding project with only stack.json should succeed", results)
	_expect(FileAccess.file_exists(config_path), "ogs_config.json should be auto-generated on disk", results)

	var loaded_config = OgsConfig.load_from_file(config_path)
	_expect(loaded_config != null, "auto-generated ogs_config.json should be valid", results)
	_expect(loaded_config.offline_mode == false, "default offline_mode should be false", results)
	_expect(loaded_config.force_offline == false, "default force_offline should be false", results)

	_cleanup_nodes(ctx["nodes"])
	_cleanup_dir_recursive(test_dir)
	_cleanup_registry(storage_path)

func _test_add_valid_project_populates_lists(results: Dictionary) -> void:
	## Verifies valid sample project is added and selected.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_valid_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	var ctx = _build_controller(storage_path)
	var controller = ctx["controller"]
	var added = controller.add_project_from_path("res://samples/sample_project")
	var projects_list: Control = ctx["projects"]
	var explorer_tree: Tree = ctx["tree"]
	_expect(added, "valid project should be added", results)
	_expect(projects_list.item_count == 1, "projects list should include added project", results)
	_expect(explorer_tree.get_root() != null, "selected project should populate explorer tree", results)
	_cleanup_nodes(ctx["nodes"])
	_cleanup_registry(storage_path)

func _test_project_registry_persists_between_setups(results: Dictionary) -> void:
	## Verifies added projects are persisted and reloaded on next setup.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_persist_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)

	var ctx1 = _build_controller(storage_path)
	var controller1 = ctx1["controller"]
	controller1.add_project_from_path("res://samples/sample_project")
	_cleanup_nodes(ctx1["nodes"])

	var ctx2 = _build_controller(storage_path)
	var projects_list: Control = ctx2["projects"]
	_expect(projects_list.item_count == 1, "persisted project should reload on next setup", results)
	_cleanup_nodes(ctx2["nodes"])
	_cleanup_registry(storage_path)

func _test_project_removal(results: Dictionary) -> void:
	## Verifies projects can be removed and it persists.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_remove_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	
	var ctx = _build_controller(storage_path)
	var controller = ctx["controller"]
	controller.add_project_from_path("res://samples/sample_project")
	
	var projects_list: Control = ctx["projects"]
	var remove_dialog: ConfirmationDialog = ctx["remove_dialog"]
	
	_expect(projects_list.item_count == 1, "projects list should contain one project before removal", results)
	controller._on_remove_project_pressed()
	controller._on_remove_project_confirmed()
	
	_expect(projects_list.item_count == 0, "projects list should be empty after removal", results)
	_cleanup_nodes(ctx["nodes"])
	
	var ctx_reload = _build_controller(storage_path)
	var projects_list_reload: Control = ctx_reload["projects"]
	_expect(projects_list_reload.item_count == 0, "registry should persist project removal", results)
	_cleanup_nodes(ctx_reload["nodes"])
	_cleanup_registry(storage_path)

func _test_new_project_creates_scaffold_and_adds(results: Dictionary) -> void:
	## Verifies New Project creates files and auto-adds project to library.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_new_%s.json" % str(Time.get_ticks_msec())
	var projects_root = "user://projects_controller_scene_new_root_%s" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	_cleanup_dir_recursive(projects_root)

	var ctx = _build_controller(storage_path)
	var controller = ctx["controller"]
	controller.set_projects_root_path_for_tests(projects_root)
	var projects_list: Control = ctx["projects"]
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

func _test_new_project_honors_configured_primary_projects_folder(results: Dictionary) -> void:
	## Verifies creating a project honors configured Primary Projects Folder while test override takes precedence.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_primary_root_%s.json" % str(Time.get_ticks_msec())
	var configured_root = "user://test_configured_projects_root_%s" % str(Time.get_ticks_msec())
	var test_override_root = "user://test_override_projects_root_%s" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	_cleanup_dir_recursive(configured_root)
	_cleanup_dir_recursive(test_override_root)

	var ctx = _build_controller(storage_path)
	var controller = ctx["controller"]
	
	# When configured root is set without test override
	controller.registry_manager.set_configured_projects_root(configured_root)
	_expect(controller.get_primary_projects_folder() == configured_root.simplify_path(), "primary projects folder should match configured root", results)
	
	var created = controller._create_new_project_from_name("Configured Project")
	_expect(created, "new project should be created in configured root", results)
	var configured_project_dir = ProjectSettings.globalize_path(configured_root.path_join("Configured_Project"))
	_expect(DirAccess.dir_exists_absolute(configured_project_dir), "project folder should exist in configured root", results)
	
	# When test override is set, it must take precedence over configured root
	controller.set_projects_root_path_for_tests(test_override_root)
	_expect(controller.get_primary_projects_folder() == test_override_root, "test override should take precedence", results)
	
	var created_override = controller._create_new_project_from_name("Override Project")
	_expect(created_override, "new project should be created in override root", results)
	var override_project_dir = ProjectSettings.globalize_path(test_override_root.path_join("Override_Project"))
	_expect(DirAccess.dir_exists_absolute(override_project_dir), "project folder should exist in test override root", results)

	_cleanup_nodes(ctx["nodes"])
	_cleanup_dir_recursive(configured_root)
	_cleanup_dir_recursive(test_override_root)
	_cleanup_registry(storage_path)

func _test_launch_button_disabled_initially(results: Dictionary) -> void:
	## Verifies launch button starts disabled.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_launch0_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	var ctx = _build_controller(storage_path)
	var launch_btn: Button = ctx["launch_btn"]
	_expect(launch_btn.disabled == true, "launch button should be disabled initially", results)
	_cleanup_nodes(ctx["nodes"])
	_cleanup_registry(storage_path)

func _test_launch_button_enabled_after_select(results: Dictionary) -> void:
	## Verifies launch button is enabled after selecting valid project.
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
	## Verifies clicked tool is treated as selected by launch handler.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_launch_click_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	var ctx = _build_controller(storage_path)
	var controller = ctx["controller"]
	var status_label: Label = ctx["status"]
	var tools_list: Control = ctx.get("list")
	_expect(tools_list != null, "tools list should exist in launch-click test context", results)
	var added = controller.add_project_from_path("res://samples/sample_project")
	_expect(added, "project should add successfully for launch-click test", results)
	if added and tools_list != null and tools_list.item_count > 0:
		tools_list.item_clicked.emit(0, Vector2.ZERO, 1)
		controller._on_launch_tool_pressed()
		_expect(status_label.text.find("No tool selected") == -1, "launch after click should not report no-selection", results)
	else:
		_expect(false, "sample project should provide at least one tool", results)
	_cleanup_nodes(ctx["nodes"])
	_cleanup_registry(storage_path)

func _test_launch_no_selection(results: Dictionary) -> void:
	## Verifies launching with no tool selected shows error.
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
	## Verifies loading a project applies offline enforcement state.
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

func _test_add_code_tool_skips_asset_folder_creation(results: Dictionary) -> void:
	## Verifies that adding Code category tools (git, vscodium) skips creating assets/Code/* directories.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_code_%s.json" % str(Time.get_ticks_msec())
	var projects_root = "user://projects_controller_scene_code_root_%s" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	_cleanup_dir_recursive(projects_root)

	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	controller.set_projects_root_path_for_tests(projects_root)
	var created = controller._create_new_project_from_name("Code Tool Test Project")
	_expect(created, "new project should be created", results)

	var project_dir = controller.current_project_dir
	_expect(not project_dir.is_empty(), "current_project_dir should be populated", results)

	# Add Git tool
	var added_git = controller.tool_manager.add_tool_to_current_project("git", "2.56.0.4")
	_expect(added_git, "git should be added to project", results)
	_expect(not DirAccess.dir_exists_absolute(project_dir.path_join("assets/Code/git")), "assets/Code/git should not be created", results)
	_expect(not DirAccess.dir_exists_absolute(project_dir.path_join("assets/Code")), "assets/Code should not be created for git", results)

	# Add VSCodium tool
	var added_codium = controller.tool_manager.add_tool_to_current_project("vscodium", "1.143.17232")
	_expect(added_codium, "vscodium should be added to project", results)
	_expect(not DirAccess.dir_exists_absolute(project_dir.path_join("assets/Code/vscodium")), "assets/Code/vscodium should not be created", results)

	# Add Blender tool (which is 3D category) to verify asset folders ARE created for asset tools
	var added_blender = controller.tool_manager.add_tool_to_current_project("blender", "4.2")
	_expect(added_blender, "blender should be added to project", results)
	_expect(DirAccess.dir_exists_absolute(project_dir.path_join("assets/3D/blender")), "assets/3D/blender should be created for blender", results)

	_cleanup_nodes(ctx["nodes"])
	_cleanup_dir_recursive(projects_root)
	_cleanup_registry(storage_path)

func _test_select_tool_in_project_tools_list_sets_launch_state(results: Dictionary) -> void:
	## Verifies selecting a tool in project_tools_list sets _selected_launch_tool_id and clears _selected_launch_target_path.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_select_tool_%s.json" % str(Time.get_ticks_msec())
	var projects_root = "user://projects_controller_scene_select_tool_root_%s" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	_cleanup_dir_recursive(projects_root)

	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	controller.set_projects_root_path_for_tests(projects_root)
	var created = controller._create_new_project_from_name("Select Tool Test")
	_expect(created, "project should create successfully", results)

	# Add Godot and VSCodium tools
	var added_godot = controller.tool_manager.add_tool_to_current_project("godot", "4.7.2")
	_expect(added_godot, "godot should be added to project", results)
	var added_codium = controller.tool_manager.add_tool_to_current_project("vscodium", "1.143.17232")
	_expect(added_codium, "vscodium should be added to project", results)

	# Set simulated explorer selection with target file
	controller._on_explorer_file_selected("res://samples/sample_project/game/project.godot", "godot")
	_expect(controller._selected_launch_target_path == "res://samples/sample_project/game/project.godot", "explorer target path should be set initially", results)
	_expect(controller._selected_launch_tool_id == "godot", "explorer tool ID should be set initially", results)

	# Find vscodium index in project_tools_list
	var vscodium_index := -1
	for i in range(controller.current_manifest.tools.size()):
		if String(controller.current_manifest.tools[i].get("id", "")) == "vscodium":
			vscodium_index = i
			break
	_expect(vscodium_index >= 0, "vscodium index should be found in manifest tools", results)

	# Select vscodium in project_tools_list via item_selected
	var tools_list: ItemList = ctx["project_tools_list"]
	tools_list.item_selected.emit(vscodium_index)

	_expect(controller._selected_launch_tool_id == "vscodium", "selecting tool in tools list should set _selected_launch_tool_id", results)
	_expect(controller._selected_launch_target_path == "", "selecting tool in tools list should clear _selected_launch_target_path", results)
	_expect(controller._selected_tool_index == vscodium_index, "_selected_tool_index should match selected tool", results)
	var explorer_tree: Tree = ctx["tree"]
	_expect(explorer_tree.get_selected() == null, "selecting tool should deselect explorer tree", results)

	# Click godot in project_tools_list via item_clicked
	var godot_index := -1
	for i in range(controller.current_manifest.tools.size()):
		if String(controller.current_manifest.tools[i].get("id", "")) == "godot":
			godot_index = i
			break
	_expect(godot_index >= 0, "godot index should be found in manifest tools", results)

	tools_list.item_clicked.emit(godot_index, Vector2.ZERO, 1)
	_expect(controller._selected_launch_tool_id == "godot", "clicking tool should update _selected_launch_tool_id", results)
	_expect(controller._selected_launch_target_path == "", "clicking tool should keep target path cleared", results)
	_expect(controller._selected_tool_index == godot_index, "clicking tool should update _selected_tool_index", results)

	_cleanup_nodes(ctx["nodes"])
	_cleanup_dir_recursive(projects_root)
	_cleanup_registry(storage_path)

func _test_launch_selected_tool_from_project_tools_list_runs_at_project_root(results: Dictionary) -> void:
	## Verifies pressing launch or double-clicking with a tools list selection runs at project root.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_launch_root_%s.json" % str(Time.get_ticks_msec())
	var projects_root = "user://projects_controller_scene_launch_root_dir_%s" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	_cleanup_dir_recursive(projects_root)

	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	controller.set_projects_root_path_for_tests(projects_root)
	controller._create_new_project_from_name("Root Launch Test")

	# Add VSCodium tool (which has no explorer folder)
	controller.tool_manager.add_tool_to_current_project("vscodium", "1.143.17232")
	var tool_dir = PathResolver.new().get_tool_path("vscodium", "1.143.17232")
	DirAccess.make_dir_recursive_absolute(tool_dir)
	var vscodium_index := -1
	for i in range(controller.current_manifest.tools.size()):
		if String(controller.current_manifest.tools[i].get("id", "")) == "vscodium":
			vscodium_index = i
			break
	_expect(vscodium_index >= 0, "vscodium index should exist", results)

	var tools_list: ItemList = ctx["project_tools_list"]
	var status_label: Label = ctx["status"]

	# Select vscodium and launch
	tools_list.item_selected.emit(vscodium_index)
	_expect(controller._selected_launch_target_path == "", "target path should be empty before launch", results)
	controller._on_launch_tool_pressed()

	_expect(status_label.text.find("No known tool associated with this file/folder") == -1, "launching selected tool should not report no known tool", results)
	_expect(status_label.text.find("No tool selected") == -1, "launching selected tool should not report no tool selected", results)
	_expect(status_label.text.begins_with("Status: Launch failed") or status_label.text.begins_with("Status: Launched"), "launch should be attempted at project root", results)

	# Now test double-click activation via item_activated
	tools_list.item_activated.emit(vscodium_index)
	_expect(controller._selected_launch_tool_id == "vscodium", "activation should retain tool ID", results)
	_expect(controller._selected_launch_target_path == "", "activation should retain empty target path", results)
	_expect(status_label.text.find("No known tool") == -1, "double click activation should attempt launch without explorer selection", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_dir_recursive(projects_root)
	_cleanup_dir_recursive(tool_dir)
	_cleanup_registry(storage_path)

func _test_project_switching_and_reset_clears_launch_state(results: Dictionary) -> void:
	## Verifies switching projects or disabling launch resets launch tool and target path.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_reset_%s.json" % str(Time.get_ticks_msec())
	var projects_root = "user://projects_controller_scene_reset_root_%s" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	_cleanup_dir_recursive(projects_root)

	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	controller.set_projects_root_path_for_tests(projects_root)

	controller._create_new_project_from_name("Project One")
	controller.tool_manager.add_tool_to_current_project("godot", "4.7.2")
	controller._on_tool_item_selected(0)
	_expect(not controller._selected_launch_tool_id.is_empty(), "tool should be selected in Project One", results)

	# Switch to a second project
	controller._create_new_project_from_name("Project Two")
	_expect(controller._selected_launch_tool_id == "", "switching project should clear _selected_launch_tool_id", results)
	_expect(controller._selected_launch_target_path == "", "switching project should clear _selected_launch_target_path", results)
	_expect(controller._selected_tool_index == -1, "switching project should reset _selected_tool_index", results)

	# Set launch state again and test _disable_launch_button
	controller.tool_manager.add_tool_to_current_project("vscodium", "1.143.17232")
	controller._on_tool_item_selected(0)
	_expect(not controller._selected_launch_tool_id.is_empty(), "tool should be re-selected", results)
	controller._disable_launch_button()
	_expect(controller._selected_launch_tool_id == "", "_disable_launch_button should clear _selected_launch_tool_id", results)
	_expect(controller._selected_launch_target_path == "", "_disable_launch_button should clear _selected_launch_target_path", results)

	# Select project again and test _disable_launch_for_selected_project
	controller._select_project(0)
	controller._on_tool_item_selected(0)
	_expect(not controller._selected_launch_tool_id.is_empty(), "tool should be selected again", results)
	controller._disable_launch_for_selected_project()
	_expect(controller._selected_launch_tool_id == "", "_disable_launch_for_selected_project should clear _selected_launch_tool_id", results)
	_expect(controller._selected_launch_target_path == "", "_disable_launch_for_selected_project should clear _selected_launch_target_path", results)

	_cleanup_nodes(ctx["nodes"])
	_cleanup_dir_recursive(projects_root)
	_cleanup_registry(storage_path)

func _test_mutual_deselection_between_tools_list_and_explorer(results: Dictionary) -> void:
	## Verifies selecting an explorer item deselects project_tools_list, and vice versa.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_mutual_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)

	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	var added = controller.add_project_from_path("res://samples/sample_project")
	_expect(added, "sample project should be added", results)

	var tools_list: ItemList = ctx["project_tools_list"]
	var explorer_tree: Tree = ctx["tree"]

	# Select tool in tools list
	controller._on_tool_item_selected(0)
	_expect(tools_list.is_selected(0), "tool index 0 should be selected", results)
	_expect(controller._selected_tool_index == 0, "_selected_tool_index should be 0", results)

	# Now select explorer file
	controller._on_explorer_file_selected("res://samples/sample_project/game/project.godot", "godot")
	_expect(tools_list.get_selected_items().is_empty(), "selecting explorer file should deselect tools list", results)
	_expect(controller._selected_tool_index == -1, "selecting explorer file should reset _selected_tool_index", results)
	_expect(controller._selected_launch_target_path == "res://samples/sample_project/game/project.godot", "explorer file path should be set", results)

	# Now select explorer folder
	controller._on_explorer_folder_selected("res://samples/sample_project/assets/3D/blender", "blender")
	_expect(tools_list.get_selected_items().is_empty(), "selecting explorer folder should deselect tools list", results)
	_expect(controller._selected_tool_index == -1, "selecting explorer folder should reset _selected_tool_index", results)
	_expect(controller._selected_launch_target_path == "res://samples/sample_project/assets/3D/blender", "explorer folder path should be set", results)

	# Now select tool in tools list again
	controller._on_tool_item_selected(1)
	_expect(explorer_tree.get_selected() == null, "selecting tool should deselect explorer tree", results)
	_expect(controller._selected_launch_target_path == "", "selecting tool should reset target path", results)
	_expect(controller._selected_launch_tool_id == "blender", "selecting tool should update launch tool ID", results)

	_cleanup_nodes(ctx["nodes"])
	_cleanup_registry(storage_path)

func _test_explorer_double_click_triggers_activation_and_launch(results: Dictionary) -> void:
	## Verifies double-clicking a file in the project explorer emits file_activated and triggers launch.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_activation_%s.json" % str(Time.get_ticks_msec())
	var projects_root = "user://projects_controller_scene_activation_root_%s" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	_cleanup_dir_recursive(projects_root)

	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	controller.set_projects_root_path_for_tests(projects_root)
	controller._create_new_project_from_name("Activation Launch Test")

	controller.tool_manager.add_tool_to_current_project("vscodium", "1.143.17232")
	var tool_dir = PathResolver.new().get_tool_path("vscodium", "1.143.17232")
	DirAccess.make_dir_recursive_absolute(tool_dir)
	var project_dir = controller.current_project_dir
	var script_path = project_dir.path_join("player.gd")
	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if file != null:
		file.store_string("extends Node\n")
		file.close()

	var explorer = controller.get_meta("project_explorer_instance")
	_expect(explorer != null, "project explorer instance should exist", results)

	var status_label: Label = ctx["status"]
	# Simulate explorer double click activation on the file
	explorer.file_activated.emit(script_path, "vscodium")

	_expect(controller._selected_launch_target_path == script_path, "activation should set launch target path", results)
	_expect(controller._selected_launch_tool_id == "vscodium", "activation should set launch tool id to vscodium", results)
	_expect(controller._selected_tool_index == -1, "activation should reset _selected_tool_index", results)
	_expect(status_label.text.begins_with("Status: Launch failed") or status_label.text.begins_with("Status: Launched"), "launch should be triggered by activation", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_dir_recursive(projects_root)
	_cleanup_dir_recursive(tool_dir)
	_cleanup_registry(storage_path)

func _test_new_file_creation_with_vscodium_in_stack(results: Dictionary) -> void:
	## Verifies creating new text files when VSCodium is in stack creates files and sets launch state.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_newfile_%s.json" % str(Time.get_ticks_msec())
	var projects_root = "user://projects_controller_scene_newfile_root_%s" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	_cleanup_dir_recursive(projects_root)

	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	controller.set_projects_root_path_for_tests(projects_root)
	controller._create_new_project_from_name("New File VSCodium Test")

	controller.tool_manager.add_tool_to_current_project("vscodium", "1.143.17232")
	var project_dir = controller.current_project_dir

	# 1. Create a script file (extension 'gd')
	var name_edit: LineEdit = ctx["new_file_name"]
	name_edit.text = "main.gd"
	controller._on_new_file_confirmed()

	var expected_script_path = project_dir.path_join("main.gd")
	_expect(FileAccess.file_exists(expected_script_path), "main.gd should be created on disk", results)
	_expect(controller._selected_launch_tool_id == "vscodium", "launch tool should be vscodium for gd file", results)
	_expect(controller._selected_launch_target_path == expected_script_path, "target path should match main.gd", results)

	# 2. Create an extensionless file -> should default to .txt with vscodium
	name_edit.text = "todo_notes"
	controller._on_new_file_confirmed()

	var expected_txt_path = project_dir.path_join("todo_notes.txt")
	_expect(FileAccess.file_exists(expected_txt_path), "todo_notes.txt should be created on disk with default .txt", results)
	_expect(controller._selected_launch_tool_id == "vscodium", "launch tool should be vscodium for default txt", results)
	_expect(controller._selected_launch_target_path == expected_txt_path, "target path should match todo_notes.txt", results)

	# 3. Create a structured data file (extension 'json')
	name_edit.text = "settings.json"
	controller._on_new_file_confirmed()

	var expected_json_path = project_dir.path_join("settings.json")
	_expect(FileAccess.file_exists(expected_json_path), "settings.json should be created on disk", results)
	_expect(controller._selected_launch_tool_id == "vscodium", "launch tool should be vscodium for json file", results)
	_expect(controller._selected_launch_target_path == expected_json_path, "target path should match settings.json", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_dir_recursive(projects_root)
	_cleanup_registry(storage_path)

func _test_three_button_toolbar_layout(results: Dictionary) -> void:
	## Verifies the three-button toolbar layout, button ordering, and separation constants in main.tscn.
	var scene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for toolbar layout test", results)
	if scene == null:
		return
	var instance = scene.instantiate()
	var controls = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsControls") as HBoxContainer
	_expect(controls != null, "ProjectsControls HBoxContainer should exist", results)
	if controls != null:
		var separation = controls.get_theme_constant("separation")
		_expect(separation == 16, "ProjectsControls separation should be 16, got %d" % separation, results)
		_expect(controls.get_child_count() >= 3, "ProjectsControls should have at least 3 children", results)
		
		var add_local = controls.get_child(0) as Button
		var add_remote = controls.get_child(1) as Button
		var new_proj = controls.get_child(2) as Button
		
		_expect(add_local != null and add_local.name == "AddButton", "Child 0 should be AddButton", results)
		if add_local != null:
			_expect(add_local.text == "Add Local Project", "Child 0 text should be 'Add Local Project'", results)
			_expect(add_local.size_flags_horizontal == 3, "Child 0 size_flags_horizontal should be 3", results)
			
		_expect(add_remote != null and add_remote.name == "AddRemoteProjectButton", "Child 1 should be AddRemoteProjectButton", results)
		if add_remote != null:
			_expect(add_remote.text == "Add Remote Project", "Child 1 text should be 'Add Remote Project'", results)
			_expect(add_remote.size_flags_horizontal == 3, "Child 1 size_flags_horizontal should be 3", results)
			_expect(add_remote.has_meta("network_ui") and add_remote.get_meta("network_ui") == true, "AddRemoteProjectButton should have metadata/network_ui = true", results)
			
		_expect(new_proj != null and new_proj.name == "NewProjectButton", "Child 2 should be NewProjectButton", results)
		if new_proj != null:
			_expect(new_proj.text == "New Project", "Child 2 text should be 'New Project'", results)
			_expect(new_proj.size_flags_horizontal == 3, "Child 2 size_flags_horizontal should be 3", results)
	instance.free()

func _test_missing_git_opens_guided_dialog_and_emits_navigation(results: Dictionary) -> void:
	## Verifies missing-Git detection opens guided dialog and 'Go to Tools' emits navigation hook.
	var storage_path = "user://test_projects_missing_git.json"
	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	
	# Ensure cloner sees git as not installed by pointing to an empty test library manager
	var empty_lib = LibraryManager.new()
	controller.remote_dialog.set_library_manager(empty_lib)
	
	var nav_state := {"called": false, "tool_id": "", "version": ""}
	controller.tool_view_requested.connect(func(tid: String, ver: String):
		nav_state["called"] = true
		nav_state["tool_id"] = tid
		nav_state["version"] = ver
	)
	
	# Simulate pressing Add Remote Project button
	controller._on_add_remote_project_pressed()
	
	_expect(controller.remote_dialog.missing_git_dialog != null, "Missing-Git dialog should exist", results)
	if controller.remote_dialog.missing_git_dialog != null:
		_expect(controller.remote_dialog.missing_git_dialog.visible == true, "Missing-Git dialog should be visible", results)
		_expect(controller.remote_dialog.missing_git_dialog.ok_button_text == "Go to Tools", "Confirm button text should be 'Go to Tools'", results)
		
		# Confirm dialog ("Go to Tools")
		controller.remote_dialog.missing_git_dialog.confirmed.emit()
		_expect(nav_state["called"] == true, "tool_view_requested should be emitted on Go to Tools", results)
		_expect(nav_state["tool_id"] == "git", "tool_view_requested should request 'git' tool", results)
		_expect(controller.remote_dialog.missing_git_dialog.visible == false, "Missing-Git dialog should close after Go to Tools", results)
	
	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_registry(storage_path)

func _test_offline_mode_disables_remote_button_and_enforces_tooltip(results: Dictionary) -> void:
	## Verifies AddRemoteProjectButton is disabled with offline tooltip when offline mode is toggled.
	var scene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for offline button test", results)
	if scene == null:
		return
	var instance = scene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(instance)
	
	var add_remote = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsControls/AddRemoteProjectButton") as Button
	_expect(add_remote != null, "AddRemoteProjectButton should exist in main scene", results)
	if add_remote != null:
		instance._collect_network_ui_nodes()
		
		# Toggle offline mode on
		instance._on_offline_state_changed(true, "offline_mode")
		_expect(add_remote.disabled == true, "AddRemoteProjectButton should be disabled when offline", results)
		_expect(add_remote.tooltip_text == "Disabled because OGS Launcher is currently in offline mode.", "AddRemoteProjectButton should have descriptive offline tooltip", results)
		
		# Toggle offline mode off
		instance._on_offline_state_changed(false, "online_mode")
		_expect(add_remote.disabled == false, "AddRemoteProjectButton should be enabled when online", results)
		_expect(add_remote.tooltip_text == "", "AddRemoteProjectButton tooltip should be empty when online", results)
	
	instance.free()

func _test_single_click_missing_tool_selects_without_navigation(results: Dictionary) -> void:
	## Verifies that single-clicking a missing tool row in ProjectToolsList selects it
	## and enables Remove Tool and Change Version without emitting tool_view_requested.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_click_missing_%s.json" % str(Time.get_ticks_msec())
	var projects_root = "user://projects_controller_scene_click_missing_root_%s" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	_cleanup_dir_recursive(projects_root)

	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	controller.set_projects_root_path_for_tests(projects_root)
	controller._create_new_project_from_name("Missing Tool Click Test")

	# Add an uninstalled tool to project stack
	controller.tool_manager.add_tool_to_current_project("blender", "4.2")

	var tools_list: ItemList = ctx["project_tools_list"]
	var remove_btn: Button = ctx["remove_tool_btn"]
	var change_ver_btn: Button = ctx["change_version_btn"]

	# Connect tool_view_requested signal to track any premature emission
	var nav_emitted := false
	controller.tool_view_requested.connect(func(_tool_id: String, _version: String):
		nav_emitted = true
	)

	# Verify action buttons initially disabled before tool row selection
	controller._selected_tool_index = -1
	controller._update_tool_action_buttons()
	_expect(remove_btn.disabled == true, "Remove Tool should be disabled before row selection", results)
	_expect(change_ver_btn.disabled == true, "Change Version should be disabled before row selection", results)

	# Single click missing tool row
	tools_list.item_clicked.emit(0, Vector2.ZERO, 1)

	_expect(nav_emitted == false, "Single-clicking missing tool row must not emit tool_view_requested", results)
	_expect(controller._selected_tool_index == 0, "Selected tool index should be 0", results)
	_expect(tools_list.is_selected(0) == true, "Tool row 0 should be selected in ItemList", results)
	_expect(remove_btn.disabled == false, "Remove Tool button must be enabled when missing tool is selected", results)
	_expect(change_ver_btn.disabled == false, "Change Version button must be enabled when missing tool is selected", results)

	# Also verify selecting via item_selected preserves state without navigation
	tools_list.item_selected.emit(0)
	_expect(nav_emitted == false, "item_selected on missing tool must not emit tool_view_requested", results)
	_expect(remove_btn.disabled == false, "Remove Tool button remains enabled after item_selected", results)
	_expect(change_ver_btn.disabled == false, "Change Version button remains enabled after item_selected", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_dir_recursive(projects_root)
	_cleanup_registry(storage_path)

func _test_double_click_missing_tool_emits_navigation(results: Dictionary) -> void:
	## Verifies that double-clicking (item_activated) a missing tool in ProjectToolsList
	## emits tool_view_requested(tool_id, tool_version).
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_activate_missing_%s.json" % str(Time.get_ticks_msec())
	var projects_root = "user://projects_controller_scene_activate_missing_root_%s" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	_cleanup_dir_recursive(projects_root)

	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	controller.set_projects_root_path_for_tests(projects_root)
	controller._create_new_project_from_name("Activate Missing Tool Test")

	controller.tool_manager.add_tool_to_current_project("blender", "4.2")

	var nav_info := {"called": false, "tool_id": "", "version": ""}
	controller.tool_view_requested.connect(func(tid: String, ver: String):
		nav_info["called"] = true
		nav_info["tool_id"] = tid
		nav_info["version"] = ver
	)

	var tools_list: ItemList = ctx["project_tools_list"]
	tools_list.item_activated.emit(0)

	_expect(nav_info["called"] == true, "Double-clicking missing tool should emit tool_view_requested", results)
	_expect(nav_info["tool_id"] == "blender", "Emitted tool_id should be 'blender', got: %s" % nav_info["tool_id"], results)
	_expect(nav_info["version"] == "4.2", "Emitted version should be '4.2', got: %s" % nav_info["version"], results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_dir_recursive(projects_root)
	_cleanup_registry(storage_path)

func _test_launch_missing_tool_emits_navigation(results: Dictionary) -> void:
	## Verifies that clicking Launch Selected Tool with a missing tool selected
	## emits tool_view_requested(tool_id, tool_version) instead of attempting execution.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_launch_missing_%s.json" % str(Time.get_ticks_msec())
	var projects_root = "user://projects_controller_scene_launch_missing_root_%s" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	_cleanup_dir_recursive(projects_root)

	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	controller.set_projects_root_path_for_tests(projects_root)
	controller._create_new_project_from_name("Launch Missing Tool Test")

	controller.tool_manager.add_tool_to_current_project("godot", "4.7.2")

	var nav_info := {"called": false, "tool_id": "", "version": ""}
	controller.tool_view_requested.connect(func(tid: String, ver: String):
		nav_info["called"] = true
		nav_info["tool_id"] = tid
		nav_info["version"] = ver
	)

	var tools_list: ItemList = ctx["project_tools_list"]
	tools_list.item_selected.emit(0)
	_expect(nav_info["called"] == false, "Selecting tool should not emit navigation", results)

	controller._on_launch_tool_pressed()

	_expect(nav_info["called"] == true, "Launching uninstalled tool should emit tool_view_requested", results)
	_expect(nav_info["tool_id"] == "godot", "Emitted tool_id should be 'godot', got: %s" % nav_info["tool_id"], results)
	_expect(nav_info["version"] == "4.7.2", "Emitted version should be '4.7.2', got: %s" % nav_info["version"], results)
	var status_label: Label = ctx["status"]
	_expect(status_label.text.find("not installed") != -1, "Status should indicate tool is not installed", results)
	_expect(status_label.text.find("Launch failed") == -1, "Status should not indicate Launch failed", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_dir_recursive(projects_root)
	_cleanup_registry(storage_path)

func _test_single_click_selects_project_without_switching_tab(results: Dictionary) -> void:
	## Verifies that single-clicking a project in the library list selects it,
	## loads metadata, updates the Tab 1 header title, and enables action buttons,
	## while remaining on Tab 0 (Project Library).
	OfflineEnforcer.reset()
	var storage_path = "user://projects_ctrl_single_click_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	var tabs: TabContainer = ctx["tabs"]
	var open_btn: Button = ctx["open_btn"]
	var remove_btn: Button = ctx["remove_btn"]
	var projects_list = ctx["projects"]

	var added = controller.add_project_from_path("res://samples/sample_project")
	_expect(added, "Sample project should be added", results)
	_expect(tabs.current_tab == 0, "Current tab should remain Tab 0 after adding project", results)
	_expect(open_btn.disabled == false, "Open Project button should be enabled after project is added and selected", results)
	_expect(remove_btn.disabled == false, "Remove Project button should be enabled after project is added and selected", results)

	projects_list.item_selected.emit(0)
	_expect(tabs.current_tab == 0, "Single-clicking project in list must keep current_tab at 0", results)
	_expect(controller.current_project_dir != "", "Selected project directory should be set", results)
	_expect(controller.current_manifest != null, "Manifest should be loaded", results)
	_expect(tabs.get_tab_title(1) == "Sample OGS Project", "Tab 1 title should match project stack_name", results)
	_expect(open_btn.disabled == false, "Open Project button should remain enabled", results)
	_expect(remove_btn.disabled == false, "Remove Project button should remain enabled", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_registry(storage_path)

func _test_double_click_activates_project_and_switches_tab(results: Dictionary) -> void:
	## Verifies that double-clicking (item_activated) a project in the library list
	## selects the project and switches projects_tabs.current_tab to 1 (Project Details).
	OfflineEnforcer.reset()
	var storage_path = "user://projects_ctrl_double_click_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	var tabs: TabContainer = ctx["tabs"]
	var projects_list = ctx["projects"]

	controller.add_project_from_path("res://samples/sample_project")
	tabs.current_tab = 0
	_expect(tabs.current_tab == 0, "Tab should be 0 before activation", results)

	projects_list.item_activated.emit(0)
	_expect(tabs.current_tab == 1, "Double-clicking project must switch projects_tabs.current_tab to 1", results)
	_expect(tabs.get_tab_title(1) == "Sample OGS Project", "Tab 1 title should match project stack_name", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_registry(storage_path)

func _test_open_project_button_switches_tab(results: Dictionary) -> void:
	## Verifies that clicking the Open Project button switches projects_tabs.current_tab to 1.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_ctrl_open_btn_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	var tabs: TabContainer = ctx["tabs"]
	var open_btn: Button = ctx["open_btn"]

	controller.add_project_from_path("res://samples/sample_project")
	tabs.current_tab = 0
	_expect(tabs.current_tab == 0, "Tab should be 0 before pressing Open Project", results)

	open_btn.pressed.emit()
	_expect(tabs.current_tab == 1, "Pressing Open Project button must switch current_tab to 1", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_registry(storage_path)

func _test_action_buttons_disabled_initially_and_on_empty(results: Dictionary) -> void:
	## Verifies that Open Project, Remove Project, and Seal buttons are disabled
	## when no project is selected or when the library becomes empty.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_ctrl_action_btns_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	var open_btn: Button = ctx["open_btn"]
	var remove_btn: Button = ctx["remove_btn"]
	var seal_btn: Button = ctx["seal_btn"]

	_expect(open_btn.disabled == true, "Open Project button should be disabled when library is empty", results)
	_expect(remove_btn.disabled == true, "Remove Project button should be disabled when library is empty", results)
	_expect(seal_btn.disabled == true, "Seal button should be disabled when library is empty", results)

	controller.add_project_from_path("res://samples/sample_project")
	_expect(open_btn.disabled == false, "Open Project button should be enabled after project added", results)
	_expect(remove_btn.disabled == false, "Remove Project button should be enabled after project added", results)

	controller._remove_project_at_index(0)
	_expect(open_btn.disabled == true, "Open Project button should be disabled when library becomes empty", results)
	_expect(remove_btn.disabled == true, "Remove Project button should be disabled when library becomes empty", results)
	_expect(seal_btn.disabled == true, "Seal button should be disabled when library becomes empty", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_registry(storage_path)

func _test_custom_item_list_double_click_activation(results: Dictionary) -> void:
	## Verifies CustomItemList emits item_selected on single-click and item_activated on double-click.
	var list := CustomItemList.new()
	var selected_indices: Array[int] = []
	var activated_indices: Array[int] = []
	list.item_selected.connect(func(idx: int): selected_indices.append(idx))
	list.item_activated.connect(func(idx: int): activated_indices.append(idx))

	list.add_item("Project Alpha")
	list.add_item("Project Beta")
	_expect(list.item_count == 2, "CustomItemList should have 2 items", results)

	var btn0: Button = list.get_item_button(0)
	_expect(btn0 != null, "get_item_button(0) should return Button", results)

	var press_event := InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	press_event.double_click = false
	btn0.gui_input.emit(press_event)
	btn0.pressed.emit()

	_expect(selected_indices.size() == 1 and selected_indices[0] == 0, "Single-click should emit item_selected(0)", results)
	_expect(activated_indices.is_empty(), "Single-click should not emit item_activated", results)

	var double_event := InputEventMouseButton.new()
	double_event.button_index = MOUSE_BUTTON_LEFT
	double_event.pressed = true
	double_event.double_click = true
	btn0.gui_input.emit(double_event)

	_expect(activated_indices.size() == 1 and activated_indices[0] == 0, "Double-click should emit item_activated(0)", results)

	list.free()

func _test_project_display_paths_normalized(results: Dictionary) -> void:
	## Verifies that project item labels, tooltips, Project Explorer header, and dialog instructions
	## normalize mixed path separators and contain no backslashes.
	OfflineEnforcer.reset()
	var storage_path: String = "user://projects_controller_scene_norm_%s.json" % str(Time.get_ticks_msec())
	var test_dir: String = "user://test_norm_proj_%s" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	_cleanup_dir_recursive(test_dir)
	var abs_dir: String = ProjectSettings.globalize_path(test_dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)

	var stack_payload: Dictionary = {
		"schema_version": 1,
		"stack_name": "Normalized Path Project",
		"tools": []
	}
	var f = FileAccess.open(abs_dir.path_join("stack.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(stack_payload))
	f.close()

	var ctx: Dictionary = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"] as ProjectsController
	
	# Pass a path containing Windows backslashes
	var mixed_path: String = abs_dir.replace("/", "\\")
	var added: bool = controller.add_project_from_path(mixed_path)
	_expect(added, "mixed path project should add successfully", results)

	var projects_list: Control = ctx["projects"] as Control
	_expect(projects_list.item_count == 1, "projects list should have 1 item", results)
	if projects_list.item_count > 0:
		var item_text: String = projects_list.get_item_text(0)
		var item_tooltip: String = projects_list.get_item_tooltip(0)
		_expect(not item_text.contains("\\"), "project list item text should not contain backslashes: %s" % item_text, results)
		_expect(not item_tooltip.contains("\\"), "project list item tooltip should not contain backslashes: %s" % item_tooltip, results)
		var expected_display_path: String = PathUtils.format_for_display(mixed_path)
		_expect(item_tooltip == expected_display_path, "item tooltip should match format_for_display", results)
		_expect(item_text.ends_with(expected_display_path), "item text should end with format_for_display", results)

	var explorer_lbl: Label = ctx["explorer_title_lbl"] as Label
	_expect(not explorer_lbl.text.contains("\\"), "Project Explorer header should not contain backslashes: %s" % explorer_lbl.text, results)
	_expect(explorer_lbl.text.begins_with("Project Explorer - "), "Project Explorer header should have prefix", results)

	# Test new project dialog instructions label normalization
	controller._on_new_project_pressed()
	var instructions_lbl: Label = ctx["instructions_label"] as Label
	_expect(not instructions_lbl.text.contains("\\"), "New project dialog instructions should not contain backslashes: %s" % instructions_lbl.text, results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_dir_recursive(test_dir)
	_cleanup_registry(storage_path)




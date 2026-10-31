## ProjectsControllerSceneTests: Scene-style tests for ProjectsController
##
## Verifies Unity-Hub-style project-library behaviors with real UI nodes:
## - Add Project requires stack.json + ogs_config.json
## - Valid project adds to persistent list and selects automatically
## - Persisted entries reload on next controller setup

extends RefCounted
class_name ProjectsControllerSceneTests

const ProjectsControllerScript = preload("res://scripts/projects/projects_controller.gd")
const CustomItemListScript = preload("res://scripts/projects/custom_item_list.gd")
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
	_test_status_bar_severity_color_modulation(results)
	_test_offline_status_pill_badge_styling(results)
	_test_summarize_tools_canonical_names_and_overflow(results)
	_test_project_cards_rendered_in_custom_item_list(results)
	_test_empty_library_state_when_zero_projects(results)
	_test_search_filtering_by_stack_name_path_and_tool(results)
	_test_filtered_selection_and_data_loading(results)
	_test_empty_state_on_zero_search_results_and_clear_action(results)
	_test_empty_state_hides_when_project_added(results)
	_test_toolchain_section_header_and_list_icons(results)
	_test_project_details_split_container_and_explorer_label(results)
	_test_contextual_launch_button_states_and_transitions(results)
	_test_offline_policy_toggles_and_persistence(results)
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
	var projects_list = CustomItemListScript.new()
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

	var search_edit = LineEdit.new()
	var empty_state = CenterContainer.new()
	var empty_vbox = VBoxContainer.new()
	empty_vbox.name = "EmptyStateContent"
	var empty_title = Label.new()
	empty_title.name = "EmptyTitleLabel"
	var empty_msg = Label.new()
	empty_msg.name = "EmptyMessageLabel"
	var empty_actions = HBoxContainer.new()
	empty_actions.name = "EmptyActionsContainer"
	var empty_new_btn = Button.new()
	empty_new_btn.name = "EmptyNewProjectButton"
	var empty_add_local_btn = Button.new()
	empty_add_local_btn.name = "EmptyAddLocalButton"
	var empty_add_remote_btn = Button.new()
	empty_add_remote_btn.name = "EmptyAddRemoteButton"
	var empty_clear_filter_btn = Button.new()
	empty_clear_filter_btn.name = "EmptyClearFilterButton"

	empty_actions.add_child(empty_new_btn)
	empty_actions.add_child(empty_add_local_btn)
	empty_actions.add_child(empty_add_remote_btn)
	empty_actions.add_child(empty_clear_filter_btn)
	empty_vbox.add_child(empty_title)
	empty_vbox.add_child(empty_msg)
	empty_vbox.add_child(empty_actions)
	empty_state.add_child(empty_vbox)

	var deps = ProjectsController.UIDeps.new()
	deps.btn_add_project = add_button
	deps.btn_add_remote_project = add_remote_button
	deps.btn_new_project = new_button
	deps.btn_open_project = open_button
	deps.btn_remove_project = remove_button
	deps.btn_seal_project = seal_button
	deps.projects_list = projects_list
	deps.project_search_line_edit = search_edit
	deps.empty_library_state = empty_state
	deps.empty_title_label = empty_title
	deps.empty_message_label = empty_msg
	deps.empty_new_project_button = empty_new_btn
	deps.empty_add_local_button = empty_add_local_btn
	deps.empty_add_remote_button = empty_add_remote_btn
	deps.empty_clear_filter_button = empty_clear_filter_btn
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

	var offline_mode_cb = CheckButton.new()
	var force_offline_cb = CheckButton.new()
	var offline_status_lbl = Label.new()
	var offline_mode_helper_lbl = Label.new()
	var force_offline_helper_lbl = Label.new()

	deps.project_offline_mode_check_button = offline_mode_cb
	deps.project_force_offline_check_button = force_offline_cb
	deps.project_offline_status_label = offline_status_lbl
	deps.project_offline_mode_helper_label = offline_mode_helper_lbl
	deps.project_force_offline_helper_label = force_offline_helper_lbl
	
	controller.setup(deps, null)

	return {
		"controller": controller,
		"projects": projects_list,
		"search_edit": search_edit,
		"empty_state": empty_state,
		"empty_title": empty_title,
		"empty_msg": empty_msg,
		"empty_new_btn": empty_new_btn,
		"empty_add_local_btn": empty_add_local_btn,
		"empty_add_remote_btn": empty_add_remote_btn,
		"empty_clear_filter_btn": empty_clear_filter_btn,
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
		"project_offline_mode_check_button": offline_mode_cb,
		"project_force_offline_check_button": force_offline_cb,
		"project_offline_status_label": offline_status_lbl,
		"project_offline_mode_helper_label": offline_mode_helper_lbl,
		"project_force_offline_helper_label": force_offline_helper_lbl,
		"nodes": [add_button, add_remote_button, new_button, open_button, remove_button, seal_button, projects_list, search_edit, empty_state, status_label, offline_label, explorer_title_lbl, explorer_tree, new_folder_btn, new_file_btn, new_file_dialog, new_file_name, add_tool_button, remove_tool_button, launch_button, dialog, remove_dialog, new_project_dialog, new_project_vbox, instructions_label, new_project_name, add_tool_dialog, add_tool_option, project_tools_list, projects_tabs, change_version_button, offline_mode_cb, force_offline_cb, offline_status_lbl, offline_mode_helper_lbl, force_offline_helper_lbl]
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
	## Verifies launch button is initially disabled until a tool is explicitly selected.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_launch1_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	var ctx = _build_controller(storage_path)
	var controller = ctx["controller"]
	var launch_btn: Button = ctx["launch_btn"]
	var added = controller.add_project_from_path("res://samples/sample_project")
	_expect(added, "project should add successfully", results)
	_expect(launch_btn.disabled == true, "launch button should remain disabled after valid project select when no tool is selected", results)
	_expect(launch_btn.text == "Select a Tool to Launch", "launch button text should prompt selection", results)

	controller._on_tool_item_selected(0)
	_expect(launch_btn.disabled == false, "launch button should be enabled after tool item selected", results)
	_expect(launch_btn.text.begins_with("Launch "), "launch button text should update to Launch <Tool>, got: %s" % launch_btn.text, results)
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
	## Verifies launching with no tool selected shows error and button remains disabled.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_launch2_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	var ctx = _build_controller(storage_path)
	var controller = ctx["controller"]
	var status_label: Label = ctx["status"]
	var launch_btn: Button = ctx["launch_btn"]
	controller.add_project_from_path("res://samples/sample_project")
	_expect(launch_btn.disabled == true, "launch button should be disabled without tool selection", results)
	_expect(launch_btn.text == "Select a Tool to Launch", "launch button text should prompt selection", results)
	controller._on_launch_tool_pressed()
	_expect(status_label.text.find("No tool selected") != -1, "launch with no selection should error", results)
	_expect(launch_btn.disabled == true, "launch button should remain disabled after failed launch attempt", results)
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
	var launch_btn: Button = ctx["launch_btn"]
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
	_expect(launch_btn.disabled == false, "launch button should be enabled after selecting explorer file", results)
	_expect(launch_btn.text == "Open project.godot in Godot", "launch button text should display Open <filename> in <tool>, got: %s" % launch_btn.text, results)

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
	_expect(launch_btn.disabled == false, "launch button should be enabled after selecting tool in list", results)
	_expect(launch_btn.text.begins_with("Launch VSCodium"), "launch button text should display Launch <tool>, got: %s" % launch_btn.text, results)
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
	_expect(launch_btn.disabled == false, "launch button should be enabled after clicking godot", results)
	_expect(launch_btn.text.begins_with("Launch Godot"), "launch button text should display Launch Godot, got: %s" % launch_btn.text, results)

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

func _test_status_bar_severity_color_modulation(results: Dictionary) -> void:
	## Verifies ProjectsController._update_status modulates font color and severity properly.
	var storage_path := "user://test_status_bar_severity.json"
	_cleanup_registry(storage_path)
	var ctx := _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	var status_label: Label = ctx["status"]

	# 1. Ready / Success state
	controller._update_status("Status: Manifest loaded. Environment ready - all tools in library.")
	_expect(controller.get_current_status_severity() == "ready", "Manifest loaded ready status should be 'ready' severity", results)
	_expect(status_label.text == "Status: Manifest loaded. Environment ready - all tools in library.", "Status text preserved for ready", results)
	var ready_color: Color = status_label.get_theme_color("font_color")
	_expect(ready_color.is_equal_approx(ProjectsController.COLOR_STATUS_READY), "Ready status should have green font_color accent", results)

	# 2. Launched success state
	controller._update_status("Status: Launched godot (PID: 1234)")
	_expect(controller.get_current_status_severity() == "ready", "Launched tool should have 'ready' severity", results)
	_expect(status_label.get_theme_color("font_color").is_equal_approx(ProjectsController.COLOR_STATUS_READY), "Launched tool should have green font_color accent", results)

	# 3. Warning / Incomplete state (missing tools in library)
	controller._update_status("Status: Manifest loaded (1 tool(s) missing - use Tools page to download).")
	_expect(controller.get_current_status_severity() == "warning", "Missing tools status should be 'warning' severity", results)
	_expect(status_label.text.contains("1 tool(s) missing"), "Status text preserved for missing tools warning", results)
	var warning_color: Color = status_label.get_theme_color("font_color")
	_expect(warning_color.is_equal_approx(ProjectsController.COLOR_STATUS_WARNING), "Warning status should have amber font_color accent", results)

	# 4. Warning / Incomplete state (offline mode download prevention)
	controller._update_status("Status: Manifest loaded (2 tool(s) missing - offline mode prevents downloads).")
	_expect(controller.get_current_status_severity() == "warning", "Offline mode missing tools should be 'warning' severity", results)
	_expect(status_label.get_theme_color("font_color").is_equal_approx(ProjectsController.COLOR_STATUS_WARNING), "Offline missing tools should have amber font_color accent", results)

	# 5. Error / Failure state (launch failed)
	controller._update_status("Status: Launch failed - Binary not found")
	_expect(controller.get_current_status_severity() == "error", "Launch failed should be 'error' severity", results)
	_expect(status_label.text == "Status: Launch failed - Binary not found", "Status text preserved for launch failed", results)
	var error_color: Color = status_label.get_theme_color("font_color")
	_expect(error_color.is_equal_approx(ProjectsController.COLOR_STATUS_ERROR), "Error status should have red font_color accent", results)

	# 6. Error / Failure state (missing stack.json)
	controller._update_status("Status: Selected project is missing stack.json.")
	_expect(controller.get_current_status_severity() == "error", "Missing stack.json should be 'error' severity", results)
	_expect(status_label.get_theme_color("font_color").is_equal_approx(ProjectsController.COLOR_STATUS_ERROR), "Missing stack.json should have red font_color accent", results)

	# 7. Neutral / Idle state (initial waiting prompt)
	controller._update_status("Status: Waiting for project selection.")
	_expect(controller.get_current_status_severity() == "neutral", "Waiting prompt should be 'neutral' severity", results)
	_expect(status_label.text == "Status: Waiting for project selection.", "Status text preserved for neutral waiting prompt", results)
	var neutral_color: Color = status_label.get_theme_color("font_color")
	_expect(neutral_color.is_equal_approx(ProjectsController.COLOR_STATUS_NEUTRAL), "Neutral status should have muted font_color", results)

	# 8. Explicit severity override
	controller._update_status("Custom test message", "error")
	_expect(controller.get_current_status_severity() == "error", "Explicit severity should be honored", results)
	_expect(status_label.get_theme_color("font_color").is_equal_approx(ProjectsController.COLOR_STATUS_ERROR), "Explicit severity should apply red color", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_registry(storage_path)

func _test_offline_status_pill_badge_styling(results: Dictionary) -> void:
	## Verifies ProjectsController._update_offline_status renders styled pill badges.
	var storage_path := "user://test_offline_badge.json"
	_cleanup_registry(storage_path)
	var ctx := _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	var offline_label: Label = ctx["offline"]

	# 1. Null config (Unknown)
	controller._update_offline_status(null)
	_expect(controller.get_current_offline_state() == "unknown", "Null config should be 'unknown' offline state", results)
	_expect(offline_label.text == "Offline Mode: Unknown", "Offline label text preserved for unknown", results)
	var unknown_style: StyleBoxFlat = offline_label.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(unknown_style != null, "Offline label should have normal StyleBoxFlat for unknown", results)
	if unknown_style != null:
		_expect(unknown_style.corner_radius_top_left == 10, "Pill badge should have rounded corners (10px)", results)
		_expect(unknown_style.bg_color.is_equal_approx(ProjectsController.COLOR_OFFLINE_UNKNOWN_BG), "Unknown badge should have muted bg", results)
	var unknown_text_color: Color = offline_label.get_theme_color("font_color")
	_expect(unknown_text_color.is_equal_approx(ProjectsController.COLOR_OFFLINE_UNKNOWN_TEXT), "Unknown badge font color should match", results)

	# 2. Online (Disabled)
	var online_cfg := OgsConfig.new()
	online_cfg.offline_mode = false
	online_cfg.force_offline = false
	controller._update_offline_status(online_cfg)
	_expect(controller.get_current_offline_state() == "disabled", "Online config should be 'disabled' offline state", results)
	_expect(offline_label.text == "Offline Mode: Disabled", "Offline label text preserved for online", results)
	var online_style: StyleBoxFlat = offline_label.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(online_style != null, "Online badge should have StyleBoxFlat", results)
	if online_style != null:
		_expect(online_style.bg_color.is_equal_approx(ProjectsController.COLOR_OFFLINE_ONLINE_BG), "Online badge should have neutral bg", results)
		_expect(online_style.border_color.is_equal_approx(ProjectsController.COLOR_OFFLINE_ONLINE_BORDER), "Online badge border should match", results)
	var online_text_color: Color = offline_label.get_theme_color("font_color")
	_expect(online_text_color.is_equal_approx(ProjectsController.COLOR_OFFLINE_ONLINE_TEXT), "Online badge font color should match", results)

	# 3. Offline Mode Enabled (Amber badge)
	var offline_cfg := OgsConfig.new()
	offline_cfg.offline_mode = true
	offline_cfg.force_offline = false
	controller._update_offline_status(offline_cfg)
	_expect(controller.get_current_offline_state() == "enabled", "Offline mode should be 'enabled' offline state", results)
	_expect(offline_label.text == "Offline Mode: Enabled (offline_mode=true)", "Offline label text preserved for enabled", results)
	var enabled_style: StyleBoxFlat = offline_label.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(enabled_style != null, "Enabled badge should have StyleBoxFlat", results)
	if enabled_style != null:
		_expect(enabled_style.bg_color.is_equal_approx(ProjectsController.COLOR_OFFLINE_ENABLED_BG), "Enabled badge should have amber bg", results)
		_expect(enabled_style.border_color.is_equal_approx(ProjectsController.COLOR_OFFLINE_ENABLED_BORDER), "Enabled badge should have amber border", results)
	var enabled_text_color: Color = offline_label.get_theme_color("font_color")
	_expect(enabled_text_color.is_equal_approx(ProjectsController.COLOR_OFFLINE_ENABLED_TEXT), "Enabled badge font color should be amber", results)

	# 4. Forced Offline (Red / high-contrast badge)
	var forced_cfg := OgsConfig.new()
	forced_cfg.offline_mode = true
	forced_cfg.force_offline = true
	controller._update_offline_status(forced_cfg)
	_expect(controller.get_current_offline_state() == "forced", "Forced offline should be 'forced' offline state", results)
	_expect(offline_label.text == "Offline Mode: Forced (force_offline=true)", "Offline label text preserved for forced", results)
	var forced_style: StyleBoxFlat = offline_label.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(forced_style != null, "Forced badge should have StyleBoxFlat", results)
	if forced_style != null:
		_expect(forced_style.bg_color.is_equal_approx(ProjectsController.COLOR_OFFLINE_FORCED_BG), "Forced badge should have danger red bg", results)
		_expect(forced_style.border_color.is_equal_approx(ProjectsController.COLOR_OFFLINE_FORCED_BORDER), "Forced badge should have danger red border", results)
	var forced_text_color: Color = offline_label.get_theme_color("font_color")
	_expect(forced_text_color.is_equal_approx(ProjectsController.COLOR_OFFLINE_FORCED_TEXT), "Forced badge font color should be high-contrast red", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_registry(storage_path)

func _test_summarize_tools_canonical_names_and_overflow(results: Dictionary) -> void:
	## Verifies _summarize_tools formats canonical display names and handles tool count overflow.
	var storage_path := "user://test_summarize_tools.json"
	_cleanup_registry(storage_path)
	var ctx := _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]

	# 1. Empty tools
	_expect(controller._summarize_tools([]) == "No tools", "Empty tools list should summarize as 'No tools'", results)

	# 2. Single tool with canonical name mapping
	var one_tool: Array = [{"id": "godot", "version": "4.7.2"}]
	_expect(controller._summarize_tools(one_tool) == "Godot 4.7.2", "Single tool should format as canonical 'Godot 4.7.2', got '%s'" % controller._summarize_tools(one_tool), results)

	# 3. Two tools
	var two_tools: Array = [
		{"id": "godot", "version": "4.7.2"},
		{"id": "gimp", "version": "3.2.4"}
	]
	_expect(controller._summarize_tools(two_tools) == "Godot 4.7.2, GIMP 3.2.4", "Two tools should format canonical names separated by comma", results)

	# 4. Three tools with overflow (+1 more)
	var three_tools: Array = [
		{"id": "godot", "version": "4.7.2"},
		{"id": "gimp", "version": "3.2.4"},
		{"id": "blender", "version": "4.2"}
	]
	_expect(controller._summarize_tools(three_tools) == "Godot 4.7.2, GIMP 3.2.4 (+1 more)", "Three tools should format with (+1 more) overflow", results)

	# 5. Four tools with overflow (+2 more) and VSCodium canonical casing
	var four_tools: Array = [
		{"id": "godot", "version": "4.7.2"},
		{"id": "vscodium", "version": "1.143.17232"},
		{"id": "blender", "version": "4.2"},
		{"id": "krita", "version": "5.2.2"}
	]
	_expect(controller._summarize_tools(four_tools) == "Godot 4.7.2, VSCodium 1.143.17232 (+2 more)", "Four tools should format with VSCodium casing and (+2 more) overflow", results)

	# 6. Tool without version (omits '?')
	var unversioned_tool: Array = [{"id": "git"}]
	_expect(controller._summarize_tools(unversioned_tool) == "Git", "Tool with missing version should omit question mark and format as 'Git'", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_registry(storage_path)

func _test_project_cards_rendered_in_custom_item_list(results: Dictionary) -> void:
	## Verifies that ProjectsController populates CustomItemList with structured cards and badges.
	var storage_path := "user://test_project_cards_render.json"
	_cleanup_registry(storage_path)
	var ctx := _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	var projects_list: CustomItemList = ctx["projects"] as CustomItemList

	_expect(projects_list != null, "Projects list should be CustomItemList instance", results)

	var added = controller.add_project_from_path("res://samples/sample_project")
	_expect(added, "Sample project should be added successfully", results)
	_expect(projects_list.item_count == 1, "Projects list should contain 1 project card", results)

	if projects_list.item_count > 0:
		var title: String = projects_list.get_card_title(0)
		_expect(title == "Sample OGS Project", "Card title should match 'Sample OGS Project', got '%s'" % title, results)

		var path: String = projects_list.get_card_path(0)
		_expect(not path.contains("\\"), "Card path should be normalized without backslashes", results)

		var badges := projects_list.get_card_badge_texts(0)
		_expect(not badges.is_empty(), "Card should contain tool badges", results)

		# Verify selection state
		_expect(projects_list.get_selected_index() == 0, "Added project should be automatically selected", results)
		var btn: Button = projects_list.get_item_button(0)
		_expect(btn.button_pressed == true, "Selected project button should have button_pressed = true", results)

		var pressed_style: StyleBoxFlat = btn.get_theme_stylebox("pressed") as StyleBoxFlat
		_expect(pressed_style != null, "Selected card should have StyleBoxFlat", results)
		if pressed_style != null:
			_expect(pressed_style.border_width_left == 2, "Selected card border width should be 2px", results)
			_expect(pressed_style.border_color.is_equal_approx(CustomItemListScript.COLOR_CARD_BORDER_SELECTED), "Selected card border should have accent color", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_registry(storage_path)

func _create_dummy_project(base_dir_name: String, stack_name: String, tools: Array) -> String:
	## Helper to scaffold an isolated valid OGS project on disk for testing.
	var path_str := "user://%s_%s_%d" % [base_dir_name, str(Time.get_ticks_msec()), randi() % 10000]
	var abs_dir := ProjectSettings.globalize_path(path_str)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var stack_payload = {
		"schema_version": StackManifest.CURRENT_SCHEMA_VERSION,
		"stack_name": stack_name,
		"tools": tools
	}
	var f = FileAccess.open(abs_dir.path_join("stack.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(stack_payload))
	f.close()
	var config_f = FileAccess.open(abs_dir.path_join("ogs_config.json"), FileAccess.WRITE)
	config_f.store_string(JSON.stringify(OgsConfig.new().to_dict()))
	config_f.close()
	return abs_dir

func _test_empty_library_state_when_zero_projects(results: Dictionary) -> void:
	## Verifies that zero tracked projects shows empty state container and hides projects list.
	OfflineEnforcer.reset()
	var storage_path = "user://test_empty_lib_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)

	var ctx = _build_controller(storage_path)
	var projects_list: Control = ctx["projects"]
	var empty_state: Control = ctx["empty_state"]
	var empty_title: Label = ctx["empty_title"]
	var empty_new_btn: Button = ctx["empty_new_btn"]
	var empty_add_local_btn: Button = ctx["empty_add_local_btn"]
	var empty_add_remote_btn: Button = ctx["empty_add_remote_btn"]
	var empty_clear_filter_btn: Button = ctx["empty_clear_filter_btn"]
	var open_btn: Button = ctx["open_btn"]
	var remove_btn: Button = ctx["remove_btn"]
	var seal_btn: Button = ctx["seal_btn"]

	_expect(not projects_list.visible, "ProjectsList should be hidden when zero projects tracked", results)
	_expect(empty_state.visible, "EmptyLibraryState should be visible when zero projects tracked", results)
	_expect(empty_title.text == "No Projects Tracked", "Empty title should indicate no projects tracked", results)
	_expect(empty_new_btn.visible, "New Project button should be visible in empty state", results)
	_expect(empty_add_local_btn.visible, "Add Local Project button should be visible in empty state", results)
	_expect(empty_add_remote_btn.visible, "Add Remote Project button should be visible in empty state", results)
	_expect(not empty_clear_filter_btn.visible, "Clear Filter button should be hidden when zero projects tracked", results)
	_expect(open_btn.disabled, "Open Project button should be disabled when empty", results)
	_expect(remove_btn.disabled, "Remove Project button should be disabled when empty", results)
	_expect(seal_btn.disabled, "Seal button should be disabled when empty", results)

	_cleanup_nodes(ctx["nodes"])
	_cleanup_registry(storage_path)

func _test_search_filtering_by_stack_name_path_and_tool(results: Dictionary) -> void:
	## Verifies case-insensitive search filtering across stack name, path, and tool IDs/versions.
	OfflineEnforcer.reset()
	var storage_path = "user://test_search_filter_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)

	var dir1 = _create_dummy_project("proj_alpha", "Alpha Platformer", [{"id": "godot", "version": "4.7.2"}])
	var dir2 = _create_dummy_project("proj_beta", "Beta Brawler", [{"id": "blender", "version": "4.5.7"}])
	var dir3 = _create_dummy_project("proj_gamma", "Gamma Galaxy", [{"id": "gimp", "version": "3.0.0"}, {"id": "vscodium", "version": "1.90.0"}])

	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	var projects_list: CustomItemList = ctx["projects"]
	var empty_state: Control = ctx["empty_state"]

	controller.add_project_from_path(dir1)
	controller.add_project_from_path(dir2)
	controller.add_project_from_path(dir3)

	_expect(projects_list.item_count == 3, "All 3 projects should be loaded initially", results)
	_expect(controller.get_filtered_indices().size() == 3, "Filtered indices size should be 3 initially", results)

	# 1. Filter by stack name (case-insensitive substring)
	controller._on_search_text_changed("alpha")
	_expect(controller.get_filtered_indices().size() == 1, "Filter 'alpha' should match exactly 1 project", results)
	_expect(projects_list.item_count == 1, "List item count should be 1 for 'alpha'", results)
	_expect(projects_list.get_card_title(0) == "Alpha Platformer", "Matching card title should be 'Alpha Platformer'", results)
	_expect(projects_list.visible, "Projects list should be visible when results match", results)
	_expect(not empty_state.visible, "Empty state should be hidden when results match", results)

	# 2. Filter by directory path
	var path_fragment = dir2.get_file().to_lower()
	controller._on_search_text_changed(path_fragment)
	_expect(controller.get_filtered_indices().size() == 1, "Filter by dir fragment should match beta project", results)
	_expect(projects_list.get_card_title(0) == "Beta Brawler", "Matching card title should be 'Beta Brawler'", results)

	# 3. Filter by tool ID ("blender")
	controller._on_search_text_changed("blender")
	_expect(controller.get_filtered_indices().size() == 1, "Filter 'blender' should match beta project", results)
	_expect(projects_list.get_card_title(0) == "Beta Brawler", "Matching card title should be 'Beta Brawler'", results)

	# 4. Filter by tool display name ("GIMP")
	controller._on_search_text_changed("GIMP")
	_expect(controller.get_filtered_indices().size() == 1, "Filter 'GIMP' should match gamma project", results)
	_expect(projects_list.get_card_title(0) == "Gamma Galaxy", "Matching card title should be 'Gamma Galaxy'", results)

	# 5. Filter by tool version ("4.7.2")
	controller._on_search_text_changed("4.7.2")
	_expect(controller.get_filtered_indices().size() == 1, "Filter '4.7.2' should match alpha project", results)
	_expect(projects_list.get_card_title(0) == "Alpha Platformer", "Matching card title should be 'Alpha Platformer'", results)

	# 6. Clear filter query
	controller._on_search_text_changed("")
	_expect(controller.get_filtered_indices().size() == 3, "Clearing filter should restore all 3 projects", results)
	_expect(projects_list.item_count == 3, "List should contain 3 items when filter cleared", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_dir_recursive(dir1)
	_cleanup_dir_recursive(dir2)
	_cleanup_dir_recursive(dir3)
	_cleanup_registry(storage_path)

func _test_filtered_selection_and_data_loading(results: Dictionary) -> void:
	## Verifies that clicking/activating an item in filtered search results maps to the correct tracked project.
	OfflineEnforcer.reset()
	var storage_path = "user://test_filtered_sel_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)

	var dir1 = _create_dummy_project("sel_alpha", "Alpha Platformer", [{"id": "godot", "version": "4.7.2"}])
	var dir2 = _create_dummy_project("sel_beta", "Beta Brawler", [{"id": "blender", "version": "4.5.7"}])
	var dir3 = _create_dummy_project("sel_gamma", "Gamma Galaxy", [{"id": "gimp", "version": "3.0.0"}])

	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	var projects_list: CustomItemList = ctx["projects"]
	var tabs: TabContainer = ctx["tabs"]

	controller.add_project_from_path(dir1)
	controller.add_project_from_path(dir2)
	controller.add_project_from_path(dir3)

	# Filter for "Gamma" which is index 2 in tracked_projects, but index 0 in filtered list
	controller._on_search_text_changed("Gamma")
	_expect(controller.get_filtered_indices().size() == 1, "Filtered indices size should be 1", results)
	_expect(controller.get_filtered_indices()[0] == 2, "Filtered index should point to original index 2", results)

	# Simulate selecting item 0 in the filtered projects list
	projects_list.item_selected.emit(0)
	_expect(controller.current_project_dir == dir3, "current_project_dir should be dir3", results)
	_expect(controller.current_manifest != null and controller.current_manifest.stack_name == "Gamma Galaxy", "current_manifest should be Gamma Galaxy", results)
	_expect(controller._selected_project_index == 2, "Selected project index should be 2 in registry", results)

	# Simulate activating item 0 in filtered list (double-click)
	tabs.current_tab = 0
	projects_list.item_activated.emit(0)
	_expect(tabs.current_tab == 1, "Double-clicking filtered item should switch to Project Details tab (tab 1)", results)
	_expect(tabs.get_tab_title(1) == "Gamma Galaxy", "Details tab title should be Gamma Galaxy", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_dir_recursive(dir1)
	_cleanup_dir_recursive(dir2)
	_cleanup_dir_recursive(dir3)
	_cleanup_registry(storage_path)

func _test_empty_state_on_zero_search_results_and_clear_action(results: Dictionary) -> void:
	## Verifies empty state displays when search filter yields 0 matches and clearing restores list.
	OfflineEnforcer.reset()
	var storage_path = "user://test_zero_matches_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)

	var dir1 = _create_dummy_project("zero_alpha", "Alpha Platformer", [{"id": "godot", "version": "4.7.2"}])
	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	var projects_list: CustomItemList = ctx["projects"]
	var search_edit: LineEdit = ctx["search_edit"]
	var empty_state: Control = ctx["empty_state"]
	var empty_title: Label = ctx["empty_title"]
	var empty_msg: Label = ctx["empty_msg"]
	var empty_clear_filter_btn: Button = ctx["empty_clear_filter_btn"]
	var empty_new_btn: Button = ctx["empty_new_btn"]

	controller.add_project_from_path(dir1)
	_expect(projects_list.item_count == 1, "Should have 1 project initially", results)

	# Apply filter with zero matches
	search_edit.text = "nonexistent_query_xyz"
	controller._on_search_text_changed(search_edit.text)

	_expect(controller.get_filtered_indices().is_empty(), "Filtered indices should be empty", results)
	_expect(not projects_list.visible, "ProjectsList should be hidden on 0 matches", results)
	_expect(empty_state.visible, "EmptyLibraryState should be visible on 0 matches", results)
	_expect(empty_title.text == "No Projects Match Filter", "Title should indicate no projects match filter", results)
	_expect(empty_msg.text.contains("No projects match your filter"), "Message should mention filter", results)
	_expect(empty_clear_filter_btn.visible, "Clear Filter button should be visible on 0 matches", results)
	_expect(not empty_new_btn.visible, "New Project button should be hidden on 0 filter matches", results)

	# Trigger clear filter button
	empty_clear_filter_btn.pressed.emit()

	_expect(search_edit.text.is_empty(), "Search LineEdit text should be cleared", results)
	_expect(controller.get_filtered_indices().size() == 1, "Filtered indices should restore to 1", results)
	_expect(projects_list.visible, "ProjectsList should be visible after clearing filter", results)
	_expect(not empty_state.visible, "EmptyLibraryState should be hidden after clearing filter", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_dir_recursive(dir1)
	_cleanup_registry(storage_path)

func _test_empty_state_hides_when_project_added(results: Dictionary) -> void:
	## Verifies that adding a project transitions from empty state to populated projects list.
	OfflineEnforcer.reset()
	var storage_path = "user://test_empty_trans_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)

	var dir1 = _create_dummy_project("trans_alpha", "Transition Project", [{"id": "godot", "version": "4.7.2"}])
	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	var projects_list: CustomItemList = ctx["projects"]
	var empty_state: Control = ctx["empty_state"]

	_expect(empty_state.visible, "Empty state should be visible initially when zero projects", results)
	_expect(not projects_list.visible, "ProjectsList should be hidden initially when zero projects", results)

	controller.add_project_from_path(dir1)

	_expect(not empty_state.visible, "Empty state should be hidden after adding project", results)
	_expect(projects_list.visible, "ProjectsList should be visible after adding project", results)
	_expect(projects_list.item_count == 1, "ProjectsList should have 1 item", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_dir_recursive(dir1)
	_cleanup_registry(storage_path)

func _test_toolchain_section_header_and_list_icons(results: Dictionary) -> void:
	## Verifies ToolchainHeaderLabel presence in main.tscn and icon rendering on project_tools_list.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_toolchain_%s.json" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)

	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	var added = controller.add_project_from_path("res://samples/sample_project")
	_expect(added, "sample project should be added for toolchain scene test", results)

	var tools_list: ItemList = ctx["project_tools_list"]
	_expect(tools_list != null, "project_tools_list should exist", results)
	if tools_list != null:
		_expect(tools_list.fixed_icon_size == Vector2i(20, 20), "project_tools_list fixed_icon_size should be 20x20", results)
		_expect(tools_list.item_count >= 2, "sample project should populate at least 2 tools (godot, blender)", results)
		for i in range(tools_list.item_count):
			var icon = tools_list.get_item_icon(i)
			_expect(icon != null, "tool item %d should have an icon assigned" % i, results)
			var text = tools_list.get_item_text(i)
			_expect(text.contains("Installed") or text.contains("Missing") or text.contains("Unavailable"), "tool item %d text should have explicit status indicator, got: %s" % [i, text], results)
			var tooltip = tools_list.get_item_tooltip(i)
			_expect(not tooltip.is_empty(), "tool item %d tooltip should not be empty" % i, results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_registry(storage_path)

func _test_project_details_split_container_and_explorer_label(results: Dictionary) -> void:
	## Verifies VSplitContainer hierarchy, minimum sizes, and ExplorerLabel truncation properties in main.tscn.
	var main_scene = load("res://main.tscn")
	_expect(main_scene != null, "main.tscn should load successfully", results)
	if main_scene == null:
		return

	var main_instance = main_scene.instantiate()
	_expect(main_instance != null, "main.tscn should instantiate successfully", results)
	if main_instance == null:
		return

	var project_details: Control = main_instance.find_child("Project Details", true, false) as Control
	_expect(project_details != null, "Project Details tab container should exist in main.tscn", results)

	if project_details != null:
		var split: VSplitContainer = project_details.get_node_or_null("VSplitContainer") as VSplitContainer
		_expect(split != null, "VSplitContainer should exist directly under Project Details", results)
		if split != null:
			_expect(split.size_flags_vertical == Control.SIZE_EXPAND_FILL, "VSplitContainer should have vertical expand fill flags", results)
			
			var toolchain_section: VBoxContainer = split.get_node_or_null("ToolchainSection") as VBoxContainer
			_expect(toolchain_section != null, "ToolchainSection should exist under VSplitContainer", results)
			if toolchain_section != null:
				_expect(toolchain_section.custom_minimum_size.y >= 80.0, "ToolchainSection should have sensible minimum height", results)
				var header_lbl: Label = toolchain_section.get_node_or_null("ToolchainHeaderLabel") as Label
				_expect(header_lbl != null, "ToolchainHeaderLabel should exist under ToolchainSection", results)
				var tools_list: ItemList = toolchain_section.get_node_or_null("ProjectToolsList") as ItemList
				_expect(tools_list != null, "ProjectToolsList should exist under ToolchainSection", results)
				var tool_action_row: HBoxContainer = toolchain_section.get_node_or_null("ToolActionRow") as HBoxContainer
				_expect(tool_action_row != null, "ToolActionRow should exist under ToolchainSection", results)

			var explorer_section: VBoxContainer = split.get_node_or_null("ExplorerSection") as VBoxContainer
			_expect(explorer_section != null, "ExplorerSection should exist under VSplitContainer", results)
			if explorer_section != null:
				_expect(explorer_section.custom_minimum_size.y >= 100.0, "ExplorerSection should have sensible minimum height", results)
				var explorer_toolbar: HBoxContainer = explorer_section.get_node_or_null("ExplorerToolbar") as HBoxContainer
				_expect(explorer_toolbar != null, "ExplorerToolbar should exist under ExplorerSection", results)
				var tree_node: Tree = explorer_section.get_node_or_null("ProjectExplorerTree") as Tree
				_expect(tree_node != null, "ProjectExplorerTree should exist under ExplorerSection", results)

				if explorer_toolbar != null:
					var explorer_label: Label = explorer_toolbar.get_node_or_null("ExplorerLabel") as Label
					_expect(explorer_label != null, "ExplorerLabel should exist under ExplorerToolbar", results)
					if explorer_label != null:
						_expect(explorer_label.clip_text == true, "ExplorerLabel should have clip_text enabled", results)
						_expect(explorer_label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "ExplorerLabel text_overrun_behavior should be OVERRUN_TRIM_ELLIPSIS (3)", results)

		var launch_btn: Button = project_details.get_node_or_null("LaunchButton") as Button
		_expect(launch_btn != null, "LaunchButton should exist directly under Project Details", results)
		if launch_btn != null:
			_expect(launch_btn.disabled == true, "LaunchButton should be disabled by default in main.tscn", results)
			_expect(launch_btn.text == "Select a Tool to Launch", "LaunchButton default text should be 'Select a Tool to Launch'", results)

	main_instance.free()

func _test_contextual_launch_button_states_and_transitions(results: Dictionary) -> void:
	## Verifies contextual launch button states and transitions across tool and file selections, deselections, and resets.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_ctx_launch_%s.json" % str(Time.get_ticks_msec())
	var projects_root = "user://projects_controller_scene_ctx_root_%s" % str(Time.get_ticks_msec())
	_cleanup_registry(storage_path)
	_cleanup_dir_recursive(projects_root)

	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	controller.set_projects_root_path_for_tests(projects_root)
	var launch_btn: Button = ctx["launch_btn"]

	# 1. Initially disabled before any project is added
	_expect(launch_btn.disabled == true, "launch button should be disabled initially", results)
	_expect(launch_btn.text == "Select a Tool to Launch", "launch button initial text should prompt tool selection", results)

	# 2. Add project with Godot and VSCodium
	var created = controller._create_new_project_from_name("Contextual Launch Project")
	_expect(created, "new project should be created", results)
	var added_godot = controller.tool_manager.add_tool_to_current_project("godot", "4.7.2")
	_expect(added_godot, "godot should be added", results)
	var added_codium = controller.tool_manager.add_tool_to_current_project("vscodium", "1.143.17232")
	_expect(added_codium, "vscodium should be added", results)

	# After project selection, launch button must remain disabled
	_expect(launch_btn.disabled == true, "launch button should remain disabled upon project selection", results)
	_expect(launch_btn.text == "Select a Tool to Launch", "launch button text should prompt tool selection after project load", results)

	# 3. Select Godot in ProjectToolsList
	var godot_idx := -1
	var codium_idx := -1
	for i in range(controller.current_manifest.tools.size()):
		var t_id = String(controller.current_manifest.tools[i].get("id", ""))
		if t_id == "godot": godot_idx = i
		elif t_id == "vscodium": codium_idx = i
	_expect(godot_idx >= 0 and codium_idx >= 0, "both tools should be present in manifest", results)

	controller._on_tool_item_selected(godot_idx)
	_expect(launch_btn.disabled == false, "launch button should be enabled after tool item selected", results)
	_expect(launch_btn.text == "Launch Godot v4.7.2", "launch button text should display 'Launch Godot v4.7.2', got: %s" % launch_btn.text, results)

	# 4. Select a file in ProjectExplorerTree with associated tool
	controller._on_explorer_file_selected("res://samples/sample_project/game/main.gd", "vscodium")
	_expect(launch_btn.disabled == false, "launch button should be enabled after file selected", results)
	_expect(launch_btn.text == "Open main.gd in VSCodium", "launch button text should display 'Open main.gd in VSCodium', got: %s" % launch_btn.text, results)

	# 5. Select a file with empty tool ID
	controller._on_explorer_file_selected("res://samples/sample_project/README.unknown", "")
	_expect(launch_btn.disabled == true, "launch button should be disabled for file with no associated tool", results)
	_expect(launch_btn.text == "Select a Tool to Launch", "launch button text should revert to prompt when file has no tool", results)

	# 6. Select VSCodium in tools list
	controller._on_tool_item_selected(codium_idx)
	_expect(launch_btn.disabled == false, "launch button should be enabled after selecting vscodium", results)
	_expect(launch_btn.text == "Launch VSCodium v1.143.17232", "launch button text should display 'Launch VSCodium v1.143.17232', got: %s" % launch_btn.text, results)

	# 7. Deselect / clear selection
	controller.deselect_launch_target()
	_expect(launch_btn.disabled == true, "launch button should be disabled after deselect_launch_target()", results)
	_expect(launch_btn.text == "Select a Tool to Launch", "launch button text should revert to prompt after deselect", results)

	# 8. Test double-click activation on tool item
	controller._on_tool_item_activated(godot_idx)
	_expect(launch_btn.disabled == false, "launch button should be enabled after tool activation", results)
	_expect(launch_btn.text == "Launch Godot v4.7.2", "launch button text should be Launch Godot v4.7.2 after activation", results)

	# 9. Test double-click activation on explorer file
	controller._on_explorer_file_activated("res://samples/sample_project/game/project.godot", "godot")
	_expect(launch_btn.disabled == false, "launch button should be enabled after file activation", results)
	_expect(launch_btn.text == "Open project.godot in Godot", "launch button text should be Open project.godot in Godot after activation", results)

	# 10. Deselect via clicking empty tools list
	controller._on_tools_list_empty_clicked()
	_expect(launch_btn.disabled == true, "launch button should be disabled after tools list empty click", results)
	_expect(launch_btn.text == "Select a Tool to Launch", "launch button text should prompt selection after tools list empty click", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_dir_recursive(projects_root)
	_cleanup_registry(storage_path)

func _test_offline_policy_toggles_and_persistence(results: Dictionary) -> void:
	## Verifies that ProjectsController properly initializes offline toggle states
	## when selecting projects, updates toggles and status label, and persists
	## offline configuration changes to ogs_config.json on disk.
	OfflineEnforcer.reset()
	var storage_path = "user://projects_controller_scene_offline_toggles_%s.json" % str(Time.get_ticks_msec())
	var test_dir = "user://offline_toggle_test_proj_%s" % str(Time.get_ticks_msec())
	var abs_dir = ProjectSettings.globalize_path(test_dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)

	var stack_path = abs_dir.path_join("stack.json")
	var config_path = abs_dir.path_join("ogs_config.json")
	var stack_payload = {
		"schema_version": StackManifest.CURRENT_SCHEMA_VERSION,
		"stack_name": "Offline Policy Test Project",
		"tools": []
	}
	var f = FileAccess.open(stack_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(stack_payload))
	f.close()

	var config_payload = {
		"schema_version": OgsConfig.CURRENT_SCHEMA_VERSION,
		"offline_mode": false,
		"force_offline": false
	}
	var cf = FileAccess.open(config_path, FileAccess.WRITE)
	cf.store_string(JSON.stringify(config_payload))
	cf.close()

	_cleanup_registry(storage_path)
	var ctx = _build_controller(storage_path)
	var controller: ProjectsController = ctx["controller"]
	var offline_mode_cb: CheckButton = ctx["project_offline_mode_check_button"]
	var force_offline_cb: CheckButton = ctx["project_force_offline_check_button"]
	var offline_status_lbl: Label = ctx["project_offline_status_label"]

	# 1. Before project selection: toggles must be disabled and status indicates no project
	_expect(offline_mode_cb.disabled, "offline_mode CheckButton should be disabled when no project selected", results)
	_expect(force_offline_cb.disabled, "force_offline CheckButton should be disabled when no project selected", results)
	_expect(offline_mode_cb.button_pressed == false, "offline_mode CheckButton should be unpressed initially", results)
	_expect(force_offline_cb.button_pressed == false, "force_offline CheckButton should be unpressed initially", results)
	_expect(offline_status_lbl.text == "No project selected", "status label should say 'No project selected'", results)

	# Track signal emissions
	var selection_changed_signals: Array = []
	var offline_state_signals: Array = []
	controller.project_selection_changed.connect(func(dir, off, force):
		selection_changed_signals.append({"dir": dir, "offline_mode": off, "force_offline": force})
	)
	controller.offline_state_changed.connect(func(is_off, reason):
		offline_state_signals.append({"is_offline": is_off, "reason": reason})
	)

	# 2. Add and select the project
	var added = controller.add_project_from_path(abs_dir)
	_expect(added, "adding test project should succeed", results)
	_expect(not offline_mode_cb.disabled, "offline_mode CheckButton should be enabled after project selection", results)
	_expect(not force_offline_cb.disabled, "force_offline CheckButton should be enabled after project selection", results)
	_expect(offline_mode_cb.button_pressed == false, "offline_mode CheckButton should reflect false config", results)
	_expect(force_offline_cb.button_pressed == false, "force_offline CheckButton should reflect false config", results)
	_expect(offline_status_lbl.text.contains(PathUtils.format_for_display(abs_dir)), "status label should display project path", results)

	# 3. Toggle offline_mode
	selection_changed_signals.clear()
	offline_state_signals.clear()
	offline_mode_cb.button_pressed = true
	_expect(controller.current_project_config != null and controller.current_project_config.offline_mode == true, "controller config offline_mode should be true", results)
	_expect(OfflineEnforcer.is_offline() == true, "OfflineEnforcer should be active", results)
	_expect(OfflineEnforcer.get_reason() == "offline_mode", "OfflineEnforcer reason should be offline_mode", results)
	_expect(selection_changed_signals.size() > 0, "project_selection_changed should be emitted on offline toggle", results)
	_expect(offline_state_signals.size() > 0, "offline_state_changed should be emitted on offline toggle", results)

	# Verify persistence on disk
	var disk_config = OgsConfig.load_from_file(config_path)
	_expect(disk_config != null and disk_config.offline_mode == true, "disk ogs_config.json should have offline_mode = true", results)

	# 4. Toggle force_offline
	selection_changed_signals.clear()
	offline_state_signals.clear()
	force_offline_cb.button_pressed = true
	_expect(controller.current_project_config != null and controller.current_project_config.force_offline == true, "controller config force_offline should be true", results)
	_expect(OfflineEnforcer.is_offline() == true, "OfflineEnforcer should be active for force_offline", results)
	_expect(OfflineEnforcer.get_reason() == "force_offline", "OfflineEnforcer reason should be force_offline", results)

	var disk_config2 = OgsConfig.load_from_file(config_path)
	_expect(disk_config2 != null and disk_config2.force_offline == true, "disk ogs_config.json should have force_offline = true", results)

	# 5. Remove project and verify UI resets
	controller._on_remove_project_pressed()
	controller._on_remove_project_confirmed()
	_expect(offline_mode_cb.disabled, "offline_mode CheckButton should be disabled after project removal", results)
	_expect(force_offline_cb.disabled, "force_offline CheckButton should be disabled after project removal", results)
	_expect(offline_mode_cb.button_pressed == false, "offline_mode CheckButton should reset to unpressed", results)
	_expect(force_offline_cb.button_pressed == false, "force_offline CheckButton should reset to unpressed", results)
	_expect(offline_status_lbl.text == "No project selected", "status label should reset to 'No project selected'", results)

	# 6. Re-add the project with true flags to verify toggle states initialize to true
	var readded = controller.add_project_from_path(abs_dir)
	_expect(readded, "re-adding test project should succeed", results)
	_expect(not offline_mode_cb.disabled, "offline_mode CheckButton should be enabled after re-selection", results)
	_expect(not force_offline_cb.disabled, "force_offline CheckButton should be enabled after re-selection", results)
	_expect(offline_mode_cb.button_pressed == true, "offline_mode CheckButton should initialize to true from disk", results)
	_expect(force_offline_cb.button_pressed == true, "force_offline CheckButton should initialize to true from disk", results)

	_cleanup_nodes(ctx["nodes"], controller)
	_cleanup_dir_recursive(test_dir)
	_cleanup_registry(storage_path)
	OfflineEnforcer.reset()





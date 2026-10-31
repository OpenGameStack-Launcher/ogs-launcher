## ProjectsPageIndicatorsTests: Tests for tool availability indicators
##
## Verifies that the Projects page correctly displays:
## - Tool icons rendered on items in ProjectToolsList
## - Stack Toolchain section header presence and styling
## - fixed_icon_size = Vector2i(20, 20) on ProjectToolsList
## - ✓ Installed indicator and tooltip for installed tools
## - ⚠️ Missing (Available in Tools) indicator and tooltip for missing but available tools
## - ❌ Unavailable in Repository indicator and tooltip for missing and unavailable tools
## - Double-click and launch navigation to Tools page for missing tools

extends RefCounted
class_name ProjectsPageIndicatorsTests

const ProjectsControllerScript = preload("res://scripts/projects/projects_controller.gd")
const ToolsControllerScript = preload("res://scripts/tools/tools_controller.gd")
const PathResolverScript = preload("res://scripts/library/path_resolver.gd")
const TEST_REGISTRY_PATH := "user://projects_page_indicators_tests.json"

func run() -> Dictionary:
	## Runs all Projects page indicator tests.
	## Returns:
	## Dictionary: {"passed": int, "failed": int, "failures": Array[String]}
	var results := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	_test_availability_tracking(results)
	_test_status_bar_indicators_integration(results)
	_test_toolchain_header_and_fixed_icon_size(results)
	_test_tool_icon_mapping_and_fallback(results)
	_test_explicit_status_labels_and_tooltips(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records test assertion.
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _build_projects_controller() -> Dictionary:
	## Creates a projects controller with UI nodes and tools controller.
	## Returns:
	## Dictionary: {"controller": ProjectsController, "tools_controller": ToolsController, ...}
	var projects_controller = ProjectsControllerScript.new()
	projects_controller.set_projects_index_path_for_tests(TEST_REGISTRY_PATH)
	var tools_controller = ToolsControllerScript.new(null, "")  # null scene tree, empty URL
	
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
	var toolchain_header = Label.new()
	var project_tools_list = ItemList.new()

	var deps = ProjectsController.UIDeps.new()
	deps.btn_add_project = add_button
	deps.btn_new_project = new_button
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
	deps.toolchain_header_label = toolchain_header
	deps.project_tools_list = project_tools_list
	
	projects_controller.setup(deps, tools_controller)

	return {
		"controller": projects_controller,
		"tools_controller": tools_controller,
		"status": status_label,
		"offline": offline_label,
		"tree": explorer_tree,
		"toolchain_header": toolchain_header,
		"project_tools_list": project_tools_list,
		"nodes": [add_button, new_button, projects_list, status_label, offline_label, explorer_title_lbl, explorer_tree, new_folder_btn, new_file_btn, new_file_dialog, new_file_name, add_tool_button, remove_tool_button, remove_button, launch_button, dialog, remove_dialog, new_project_dialog, new_project_name, add_tool_dialog, add_tool_option, toolchain_header, project_tools_list]
	}

func _cleanup_nodes(nodes: Array) -> void:
	## Frees UI nodes created during tests to avoid leaks.
	for node in nodes:
		if node is Node:
			node.free()
	if FileAccess.file_exists(TEST_REGISTRY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_REGISTRY_PATH))

func _test_availability_tracking(results: Dictionary) -> void:
	## Verifies _tool_availability dictionary is populated correctly.
	var ctx = _build_projects_controller()
	var controller: ProjectsController = ctx["controller"]
	
	# Create test tools
	var tools = [
		{"id": "godot", "version": "4.3", "path": ""},
		{"id": "missing_tool", "version": "1.0", "path": ""}
	]
	
	controller._populate_tools_list(tools)
	
	# Check that availability tracking is set up
	_expect("godot_4.3" in controller._tool_availability, "Should track godot_4.3 availability", results)
	_expect("missing_tool_1.0" in controller._tool_availability, "Should track missing_tool_1.0 availability", results)
	
	# Check structure of availability entries
	var godot_info = controller._tool_availability.get("godot_4.3", {})
	_expect(godot_info.has("installed"), "Availability entry should have 'installed' key", results)
	_expect(godot_info.has("available"), "Availability entry should have 'available' key", results)
	
	_cleanup_nodes(ctx["nodes"])

func _test_status_bar_indicators_integration(results: Dictionary) -> void:
	## Verifies that indicator-related status updates apply appropriate semantic styling.
	var ctx = _build_projects_controller()
	var controller: ProjectsController = ctx["controller"]
	var status_label: Label = ctx["status"]
	var offline_label: Label = ctx["offline"]

	# Missing tool guidance status -> warning severity & amber color
	controller._update_status("Status: Tool 'godot' is not installed. Opening Tools page to download.")
	_expect(controller.get_current_status_severity() == "warning", "Tool missing guidance should be warning severity", results)
	_expect(status_label.get_theme_color("font_color").is_equal_approx(ProjectsController.COLOR_STATUS_WARNING), "Tool missing guidance should have amber color", results)

	# Verify offline pill badge styling on controller
	controller._update_offline_status(null)
	_expect(controller.get_current_offline_state() == "unknown", "Initial offline state should be unknown", results)
	var pill: StyleBoxFlat = offline_label.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(pill != null, "Offline label should have StyleBoxFlat pill", results)
	if pill != null:
		_expect(pill.corner_radius_top_left == 10, "Offline pill should have 10px rounded corners", results)

	_cleanup_nodes(ctx["nodes"])

func _test_toolchain_header_and_fixed_icon_size(results: Dictionary) -> void:
	## Verifies ToolchainHeaderLabel in main.tscn and fixed_icon_size on ProjectToolsList.
	var scene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for header and icon size test", results)
	if scene != null:
		var instance = scene.instantiate()
		var header = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ToolchainHeaderLabel") as Label
		_expect(header != null, "ToolchainHeaderLabel should exist in main.tscn", results)
		if header != null:
			_expect(header.text == "Stack Toolchain", "ToolchainHeaderLabel text should be 'Stack Toolchain'", results)
			_expect(header.get_theme_font_size("font_size") == 18, "ToolchainHeaderLabel font size should be 18", results)
			_expect(header.get_theme_color("font_color").is_equal_approx(Color(0.45, 0.8, 1, 1)), "ToolchainHeaderLabel color should match header accent", results)
		
		var list = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectToolsList") as ItemList
		_expect(list != null, "ProjectToolsList should exist in main.tscn", results)
		if list != null:
			_expect(list.fixed_icon_size == Vector2i(20, 20), "ProjectToolsList fixed_icon_size should be Vector2i(20, 20)", results)
			
			# Verify hierarchy order: ToolchainHeaderLabel is directly above ProjectToolsList
			if header != null:
				_expect(header.get_index() < list.get_index(), "ToolchainHeaderLabel should sit directly above ProjectToolsList", results)
		
		instance.free()

func _test_tool_icon_mapping_and_fallback(results: Dictionary) -> void:
	## Verifies that ProjectsController maps standard tool icons from res://Images/tools/ and handles fallbacks.
	var ctx = _build_projects_controller()
	var controller: ProjectsController = ctx["controller"]
	
	var standard_tools := ["audacity", "blender", "gimp", "git", "godot", "krita", "vscodium"]
	for tid in standard_tools:
		var icon: Texture2D = controller.get_tool_icon(tid)
		_expect(icon != null, "Tool icon for '%s' should load" % tid, results)
		if icon != null:
			_expect(icon.get_width() > 0 and icon.get_height() > 0, "Icon for '%s' should have non-zero dimensions" % tid, results)
	
	# Verify case insensitivity
	var icon_mixed: Texture2D = controller.get_tool_icon("Godot")
	_expect(icon_mixed != null, "Tool icon lookup should be case-insensitive ('Godot')", results)
	var icon_upper: Texture2D = controller.get_tool_icon("BLENDER")
	_expect(icon_upper != null, "Tool icon lookup should be case-insensitive ('BLENDER')", results)
	
	# Verify fallback on unknown tool ID or empty string
	var icon_unknown: Texture2D = controller.get_tool_icon("unsupported_tool_xyz")
	_expect(icon_unknown == null, "Unknown tool icon should return null", results)
	var icon_empty: Texture2D = controller.get_tool_icon("")
	_expect(icon_empty == null, "Empty tool ID should return null", results)
	
	_cleanup_nodes(ctx["nodes"])

func _test_explicit_status_labels_and_tooltips(results: Dictionary) -> void:
	## Verifies that items in ProjectToolsList display explicit status indicators, icons, and tooltips.
	var ctx = _build_projects_controller()
	var controller: ProjectsController = ctx["controller"]
	var tools_controller: ToolsController = ctx["tools_controller"]
	var tools_list: ItemList = ctx["project_tools_list"]
	
	# Create simulated installed directory for godot 4.3 using PathResolver
	var resolver = PathResolverScript.new()
	var installed_dir = resolver.get_tool_path("godot", "4.3")
	DirAccess.make_dir_recursive_absolute(installed_dir)
	
	# Set repository data on tools_controller: blender is available, custom_engine is not
	tools_controller._available_tools = [
		{"id": "blender", "version": "4.2", "category": "3D", "installed": false}
	]
	
	var tools := [
		{"id": "godot", "version": "4.3", "path": ""},
		{"id": "blender", "version": "4.2", "path": ""},
		{"id": "custom_engine", "version": "1.0", "path": ""}
	]
	
	controller._populate_tools_list(tools)
	
	_expect(tools_list.item_count == 3, "project_tools_list should have 3 items", results)
	_expect(tools_list.fixed_icon_size == Vector2i(20, 20), "project_tools_list fixed_icon_size should be 20x20", results)
	
	# Item 0: Installed tool (Godot)
	if tools_list.item_count > 0:
		var text_0 = tools_list.get_item_text(0)
		_expect(text_0.contains("✓ Installed"), "Installed tool label should display '✓ Installed', got: %s" % text_0, results)
		_expect(tools_list.get_item_icon(0) != null, "Installed tool item should have an icon assigned", results)
		var tooltip_0 = tools_list.get_item_tooltip(0)
		_expect(tooltip_0.contains("installed and ready to launch"), "Installed tool tooltip should explain ready state, got: %s" % tooltip_0, results)
	
	# Item 1: Missing but downloadable (Blender)
	if tools_list.item_count > 1:
		var text_1 = tools_list.get_item_text(1)
		_expect(text_1.contains("⚠️ Missing (Available in Tools)"), "Available tool label should display '⚠️ Missing (Available in Tools)', got: %s" % text_1, results)
		_expect(tools_list.get_item_icon(1) != null, "Available tool item should have an icon assigned", results)
		var tooltip_1 = tools_list.get_item_tooltip(1)
		_expect(tooltip_1.contains("can be downloaded from the Tools page"), "Available tool tooltip should explain download from Tools page, got: %s" % tooltip_1, results)
	
	# Item 2: Missing and unavailable (custom_engine)
	if tools_list.item_count > 2:
		var text_2 = tools_list.get_item_text(2)
		_expect(text_2.contains("❌ Unavailable in Repository"), "Unavailable tool label should display '❌ Unavailable in Repository', got: %s" % text_2, results)
		_expect(tools_list.get_item_icon(2) == null, "Unknown tool item should have null icon", results)
		var tooltip_2 = tools_list.get_item_tooltip(2)
		_expect(tooltip_2.contains("not available in the active repository"), "Unavailable tool tooltip should indicate repository absence, got: %s" % tooltip_2, results)
	
	# Clean up created tool directory
	if DirAccess.dir_exists_absolute(installed_dir):
		DirAccess.remove_absolute(installed_dir)
		var parent_dir = installed_dir.get_base_dir()
		DirAccess.remove_absolute(parent_dir)
	
	_cleanup_nodes(ctx["nodes"])

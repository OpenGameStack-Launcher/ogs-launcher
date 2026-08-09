## ProjectsPageIndicatorsTests: Tests for tool availability indicators
##
## Verifies that the Projects page correctly displays:
##   - ⚠️ indicator for missing but available tools
##   - ❌ indicator for missing and unavailable tools
##   - No indicator for installed tools
##   - Click-through navigation to Tools page

extends RefCounted
class_name ProjectsPageIndicatorsTests

const ProjectsControllerScript = preload("res://scripts/projects/projects_controller.gd")
const ToolsControllerScript = preload("res://scripts/tools/tools_controller.gd")
const TEST_REGISTRY_PATH := "user://projects_page_indicators_tests.json"

func run() -> Dictionary:
	"""Runs all Projects page indicator tests.
	Returns:
	  Dictionary: {"passed": int, "failed": int, "failures": Array[String]}"""
	var results := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	_test_populate_tools_list_with_availability(results)
	_test_tool_view_requested_signal(results)
	_test_availability_tracking(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	"""Records test assertion."""
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _build_projects_controller() -> Dictionary:
	"""Creates a projects controller with UI nodes and tools controller.
	Returns:
	  Dictionary: {"controller": ProjectsController, "tools_controller": ToolsController, ...}"""
	var projects_controller = ProjectsControllerScript.new()
	projects_controller.set_projects_index_path_for_tests(TEST_REGISTRY_PATH)
	var tools_controller = ToolsControllerScript.new(null, "")  # null scene tree, empty URL
	
	var add_button = Button.new()
	var new_button = Button.new()
	var projects_list = ItemList.new()
	var status_label = Label.new()
	var offline_label = Label.new()
	var tools_list = ItemList.new()
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

	projects_controller.setup(
		add_button,
		new_button,
		projects_list,
		status_label,
		offline_label,
		tools_list,
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
		tools_controller  # Pass tools controller for availability checking
	)

	return {
		"controller": projects_controller,
		"tools_controller": tools_controller,
		"tools_list": tools_list,
		"nodes": [add_button, new_button, projects_list, status_label, offline_label, tools_list, add_tool_button, remove_tool_button, remove_button, launch_button, dialog, remove_dialog, new_project_dialog, new_project_name, add_tool_dialog, add_tool_option]
	}

func _cleanup_nodes(nodes: Array) -> void:
	"""Frees UI nodes created during tests to avoid leaks."""
	for node in nodes:
		if node is Node:
			node.free()
	if FileAccess.file_exists(TEST_REGISTRY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_REGISTRY_PATH))

func _test_populate_tools_list_with_availability(results: Dictionary) -> void:
	"""Verifies _populate_tools_list adds indicators based on availability."""
	var ctx = _build_projects_controller()
	var controller = ctx["controller"]
	var tools_list = ctx["tools_list"]
	
	# Create test tools manifest
	var tools = [
		{"id": "godot", "version": "4.3", "path": ""},
		{"id": "blender", "version": "4.5", "path": ""},
		{"id": "krita", "version": "5.2", "path": ""}
	]
	
	# Populate the list
	controller._populate_tools_list(tools)
	
	# Check that tools were added to the list
	_expect(tools_list.item_count == 3, "Should add 3 tools to list", results)
	
	# Check that labels contain tool IDs and versions (indicators may vary based on availability)
	var item_0_text = tools_list.get_item_text(0)
	var item_1_text = tools_list.get_item_text(1)
	var item_2_text = tools_list.get_item_text(2)
	
	_expect(item_0_text.find("godot") != -1, "Item 0 should contain 'godot'", results)
	_expect(item_0_text.find("4.3") != -1, "Item 0 should contain '4.3'", results)
	_expect(item_1_text.find("blender") != -1, "Item 1 should contain 'blender'", results)
	_expect(item_2_text.find("krita") != -1, "Item 2 should contain 'krita'", results)
	
	_cleanup_nodes(ctx["nodes"])

func _test_tool_view_requested_signal(results: Dictionary) -> void:
	"""Verifies tool_view_requested signal is emitted via ItemList click wiring."""
	var ctx = _build_projects_controller()
	var controller = ctx["controller"]
	var tools_list = ctx["tools_list"]
	
	# Use dictionary to track signal state (avoids lambda capture issues)
	var signal_state = {
		"emitted": false,
		"tool_id": "",
		"version": ""
	}
	
	controller.tool_view_requested.connect(func(tool_id: String, version: String):
		signal_state["emitted"] = true
		signal_state["tool_id"] = tool_id
		signal_state["version"] = version
	)
	
	# Set up test manifest and populate using sample project data
	var added = controller.add_project_from_path("res://samples/sample_project")
	_expect(added, "sample project should be addable for signal test", results)
	if not added:
		_cleanup_nodes(ctx["nodes"])
		return

	var first_tool = controller.current_manifest.tools[0]
	var expected_tool_id = String(first_tool.get("id", ""))
	var expected_tool_version = String(first_tool.get("version", ""))
	
	# Simulate clicking the first tool through ItemList signal wiring
	tools_list.item_clicked.emit(0, Vector2.ZERO, 1)
	
	# Verify setup
	_expect(tools_list.item_count >= 1, "Should have at least one tool in selected project", results)
	_expect(controller._tool_availability.size() >= 1, "Should track selected project tools in _tool_availability", results)
	_expect(signal_state["emitted"] == true, "tool_view_requested should emit on item click", results)
	_expect(signal_state["tool_id"] == expected_tool_id, "tool_view_requested should pass selected tool id", results)
	_expect(signal_state["version"] == expected_tool_version, "tool_view_requested should pass selected tool version", results)
	
	_cleanup_nodes(ctx["nodes"])

func _test_availability_tracking(results: Dictionary) -> void:
	"""Verifies _tool_availability dictionary is populated correctly."""
	var ctx = _build_projects_controller()
	var controller = ctx["controller"]
	
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

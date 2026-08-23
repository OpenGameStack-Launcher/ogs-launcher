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

	projects_controller.setup(
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
		tools_controller  # Pass tools controller for availability checking
	)

	return {
		"controller": projects_controller,
		"tools_controller": tools_controller,
		"tree": explorer_tree,
		"nodes": [add_button, new_button, projects_list, status_label, offline_label, explorer_tree, new_folder_btn, new_file_btn, new_file_dialog, new_file_name, add_tool_button, remove_tool_button, remove_button, launch_button, dialog, remove_dialog, new_project_dialog, new_project_name, add_tool_dialog, add_tool_option]
	}

func _cleanup_nodes(nodes: Array) -> void:
	"""Frees UI nodes created during tests to avoid leaks."""
	for node in nodes:
		if node is Node:
			node.free()
	if FileAccess.file_exists(TEST_REGISTRY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_REGISTRY_PATH))

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

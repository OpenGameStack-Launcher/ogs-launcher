## StartupTests: Verifies launcher startup and initialization without errors.
##
## These tests load the main scene and ensure all critical nodes
## initialize without runtime errors or missing references.

extends RefCounted
class_name StartupTests

func run() -> Dictionary:
	## Runs all startup verification tests.
	var results := {"passed": 0, "failed": 0, "failures": []}
	
	_test_main_scene_loads(results)
	_test_all_required_nodes_exist(results)
	_test_controllers_initialize(results)
	_test_no_runtime_errors(results)
	_test_mcp_interaction_server_setup(results)
	
	return results

## Test 1: Main scene loads without crashing.
func _test_main_scene_loads(results: Dictionary) -> void:
	## Verifies that main.tscn can be instantiated without errors.
	var success = false
	var message = "Main scene failed to load"
	
	var main_scene = load("res://main.tscn")
	if main_scene == null:
		message = "Failed to load main.tscn resource"
		_expect(false, message, results)
		return
	
	var instance = main_scene.instantiate()
	if instance == null:
		message = "Main scene instantiation returned null"
		_expect(false, message, results)
		return
	
	# Check if main.gd script is attached and valid
	var script = instance.get_script()
	if script == null:
		message = "Main scene missing script (main.gd)"
		_expect(false, message, results)
		instance.free()
		return
	
	# Verify the script has no parse errors
	if script.get_instance_base_type() == "":
		message = "Main scene script has parse or initialization error"
		_expect(false, message, results)
		instance.free()
		return
	
	success = true
	message = "Main scene loaded successfully with valid script"
	
	instance.free()
	_expect(success, message, results)

## Test 2: All required UI nodes exist and are accessible.
func _test_all_required_nodes_exist(results: Dictionary) -> void:
	## Verifies critical UI nodes needed by main.gd are present.
	var main_scene = load("res://main.tscn")
	if main_scene == null:
		_expect(false, "Cannot verify nodes: main.tscn not found", results)
		return
	
	var instance = main_scene.instantiate()
	if instance == null:
		_expect(false, "Cannot verify nodes: main.tscn instantiation failed", results)
		return
	
	# List of critical nodes that must exist
	var required_nodes = [
		"AppLayout/Sidebar/VBoxContainer/BtnProjects",
		"AppLayout/Sidebar/VBoxContainer/BtnSettings",
		"AppLayout/Content/PageProjects",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectsControls/AddRemoteProjectButton",
		"AppLayout/Content/PageSettings",
		"AppLayout/Content/PageSettings/ProjectsCard",
		"AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsSettingsLabel",
		"AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsHelperLabel",
		"AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsRootContainer/ProjectsRootLabel",
		"AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsRootContainer/ProjectsRootPath",
		"AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsRootContainer/ProjectsRootBrowseButton",
		"AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsRootContainer/ProjectsRootResetButton",
		"AppLayout/Content/PageSettings/MirrorCard",
		"AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorSettingsLabel",
		"AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorHelperLabel",
		"AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRootContainer/MirrorRootPath",
		"AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRootContainer/MirrorRootBrowseButton",
		"AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRootContainer/MirrorRootResetButton",
		"AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRepoContainer/MirrorRepoPath",
		"AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRepoContainer/MirrorRepoClearButton",
		"AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorStatusLabel",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/ProjectOfflineSettingsLabel",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/ProjectOfflineStatusLabel",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/OfflineModeContainer/ProjectOfflineModeCheckButton",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/OfflineModeContainer/ProjectOfflineModeHelperLabel",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/ForceOfflineContainer/ProjectForceOfflineCheckButton",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/ForceOfflineContainer/ProjectForceOfflineHelperLabel",
		"RemoveToolDialog",
		"RemoveToolDialog/VBoxContainer/ConfirmationLabel",
		"RemoveToolDialog/VBoxContainer/ProgressBar",
		"SealDialog",
		"SealDialog/VBoxContainer/HeaderBar",
		"SealDialog/VBoxContainer/HeaderBar/HeaderTitle",
		"SealDialog/VBoxContainer/SealProgressBar",
		"ProjectDirDialog"
	]
	
	var missing_nodes = []
	for node_path in required_nodes:
		var node = instance.get_node_or_null(node_path)
		if node == null:
			missing_nodes.append(node_path)
	
	instance.free()
	
	var success = missing_nodes.is_empty()
	var message = "All required nodes exist" if success else "Missing nodes: " + ", ".join(missing_nodes)
	_expect(success, message, results)

## Test 3: Controllers initialize without errors.
func _test_controllers_initialize(results: Dictionary) -> void:
	## Verifies controller classes can be instantiated.
	var success = true
	var errors = []
	
	var proj_controller = ProjectsController.new()
	if proj_controller == null:
		errors.append("ProjectsController instantiation failed")
		success = false
	
	var seal_controller = SealController.new()
	if seal_controller == null:
		errors.append("SealController instantiation failed")
		success = false
	
	var layout_controller = LayoutController.new()
	if layout_controller == null:
		errors.append("LayoutController instantiation failed")
		success = false
	
	var wizard = OnboardingWizard.new()
	if wizard == null:
		errors.append("OnboardingWizard instantiation failed")
		success = false
	
	var message = "All controllers initialized successfully" if success else "Controller errors: " + ", ".join(errors)
	_expect(success, message, results)

## Test 4: Script validation - ensure main.gd has no syntax errors.
func _test_no_runtime_errors(results: Dictionary) -> void:
	## Validates that main.gd script is properly formed and callable.
	var success = true
	var message = "Main script validation passed"
	
	# Load the script directly to check for parse errors
	var main_script = load("res://main.gd")
	if main_script == null:
		_expect(false, "Failed to load main.gd script", results)
		return
	
	# Check for script syntax/parse errors by looking at the script resource
	if not main_script is GDScript:
		_expect(false, "main.gd is not a valid GDScript", results)
		return
	
	# Try to get the script's class by checking if key methods exist
	var test_instance = main_script.new()
	if test_instance == null:
		success = false
		message = "Failed to instantiate main.gd script - check for parse errors"
		test_instance.free()
		_expect(success, message, results)
		return
	
	# Check if the script object was created properly
	if test_instance.get_script() == null:
		success = false
		message = "Script created but get_script() returned null"
	else:
		success = true
		message = "Main.gd script is valid and instantiable"
	
	test_instance.free()
	_expect(success, message, results)

## Test 5: Verifies McpInteractionServer autoload and mcp_client.py setup for visual QA.
func _test_mcp_interaction_server_setup(results: Dictionary) -> void:
	## Validates that project.godot registers McpInteractionServer and the autoload script and CLI client exist.
	var proj_file: FileAccess = FileAccess.open("res://project.godot", FileAccess.READ)
	_expect(proj_file != null, "project.godot should be readable", results)
	if proj_file != null:
		var proj_content: String = proj_file.get_as_text()
		proj_file.close()
		_expect(
			proj_content.contains("McpInteractionServer=\"*res://autoloads/mcp_interaction_server.gd\""),
			"project.godot should register McpInteractionServer autoload",
			results
		)

	_expect(
		FileAccess.file_exists("res://autoloads/mcp_interaction_server.gd"),
		"autoloads/mcp_interaction_server.gd should exist",
		results
	)
	_expect(
		FileAccess.file_exists("res://mcp_client.py"),
		"mcp_client.py CLI helper should exist at project root",
		results
	)

	var mcp_script: GDScript = load("res://autoloads/mcp_interaction_server.gd") as GDScript
	_expect(mcp_script != null, "mcp_interaction_server.gd should load as a valid GDScript", results)
	if mcp_script != null:
		var mcp_node: Node = mcp_script.new() as Node
		_expect(mcp_node != null, "McpInteractionServer should instantiate cleanly", results)
		if mcp_node != null:
			mcp_node.free()

## Helper to record test results.
func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records test pass/fail with descriptive message.
	if condition:
		results["passed"] += 1
		#print("✓ " + message)
	else:
		results["failed"] += 1
		results["failures"].append(message)
		#print("✗ " + message)

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
		"AppLayout/Content/PageSettings",
		"AppLayout/Content/PageSettings/MirrorRootContainer/MirrorRootPath",
		"AppLayout/Content/PageSettings/MirrorRootContainer/MirrorRootBrowseButton",
		"AppLayout/Content/PageSettings/MirrorRootContainer/MirrorRootResetButton",
		"AppLayout/Content/PageSettings/MirrorRepoContainer/MirrorRepoPath",
		"AppLayout/Content/PageSettings/MirrorRepoContainer/MirrorRepoClearButton",
		"AppLayout/Content/PageSettings/MirrorStatusLabel",
		"AppLayout/Content/PageSettings/ProjectOfflineStatusLabel",
		"AppLayout/Content/PageSettings/ProjectOfflineModeCheckButton",
		"AppLayout/Content/PageSettings/ProjectForceOfflineCheckButton",
		"RemoveToolDialog",
		"RemoveToolDialog/VBoxContainer/ConfirmationLabel",
		"RemoveToolDialog/VBoxContainer/ProgressBar",
		"SealDialog",
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

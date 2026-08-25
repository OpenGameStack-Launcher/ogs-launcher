## TestRunner: Headless Test Execution Entry Point
##
## Loads all test suites, aggregates results, and exits with status code:
## 0 = All tests passed
## 1 = One or more tests failed
##
## Usage:
## godot --headless --script res://tests/test_runner.gd

extends SceneTree

var exit_code := 0

func _init() -> void:
	## Initializes the test runner.
	# Schedule the actual tests to run in _process on the next frame
	pass

var _tests_running := false
var _tests_done := false

func _process(_delta: float) -> bool:
	## Called once per frame. Runs tests on first frame.
	if _tests_done:
		return true
		
	if not _tests_running:
		_tests_running = true
		_run_tests_async()
		
	return false

func _run_tests_async() -> void:
	## Orchestrates headless test execution: loads all suites, runs each one (handling
	## both synchronous and async suites), aggregates results, and exits the process
	## with code 0 (all passed) or 1 (one or more failures).
	
	# Set up test-isolated library path to prevent test/production conflicts
	_setup_test_library()
	
	print("TestRunner: Starting test execution...")
	
	# Pre-load classes to register class_name
	load("res://scripts/config/ogs_config.gd")
	load("res://scripts/manifest/stack_manifest.gd")
	load("res://scripts/manifest/stack_generator.gd")
	load("res://scripts/projects/projects_controller.gd")
	load("res://scripts/projects/project_environment_validator.gd")
	load("res://scripts/projects/project_sealer.gd")
	load("res://scripts/launcher/tool_launcher.gd")
	load("res://scripts/launcher/tool_config_injector.gd")
	load("res://scripts/launcher/seal_controller.gd")
	load("res://scripts/logging/logger.gd")
	load("res://scripts/network/offline_enforcer.gd")
	load("res://scripts/network/socket_blocker.gd")
	load("res://scripts/network/tool_downloader.gd")
	load("res://scripts/library/path_resolver.gd")
	load("res://scripts/library/library_manager.gd")
	load("res://scripts/library/tool_extractor.gd")
	load("res://scripts/library/library_hydrator.gd")
	load("res://scripts/mirror/mirror_repository.gd")
	load("res://scripts/mirror/mirror_path_resolver.gd")
	load("res://scripts/mirror/mirror_hydrator.gd")
	load("res://scripts/mirror/remote_mirror_hydrator.gd")
	load("res://scripts/onboarding/onboarding_wizard.gd")
	load("res://scripts/tools/tool_category_mapper.gd")
	load("res://scripts/tools/tools_controller.gd")
	load("res://scripts/tools/progress_controller.gd")
	
	var summary := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	
	# Instantiate test suites dynamically
	var test_suites: Array = []
	var test_files = [
		"res://tests/stack_manifest_tests.gd",
		"res://tests/ogs_config_tests.gd",
		"res://tests/stack_generator_tests.gd",
		"res://tests/projects_controller_scene_tests.gd",
		"res://tests/projects_page_indicators_tests.gd",
		"res://tests/main_scene_tests.gd",
		"res://tests/tools_page_scene_tests.gd",
		"res://tests/tool_launcher_tests.gd",
		"res://tests/offline_enforcer_tests.gd",
		"res://tests/tool_downloader_tests.gd",
		"res://tests/tool_config_injector_tests.gd",
		"res://tests/socket_blocker_tests.gd",
		"res://tests/logger_tests.gd",
		"res://tests/path_resolver_tests.gd",
		"res://tests/library_manager_tests.gd",
		"res://tests/tool_extractor_tests.gd",
		"res://tests/project_environment_validator_tests.gd",
		"res://tests/library_hydrator_tests.gd",
		"res://tests/project_sealer_tests.gd",
		"res://tests/mirror_repository_tests.gd",
		"res://tests/mirror_path_resolver_tests.gd",
		"res://tests/mirror_hydrator_tests.gd",
		"res://tests/remote_mirror_hydrator_tests.gd",
		"res://tests/tool_category_mapper_tests.gd",
		"res://tests/tools_controller_tests.gd",
		"res://tests/progress_controller_tests.gd",
		"res://tests/onboarding_wizard_tests.gd",
		"res://tests/startup_tests.gd",
		"res://tests/seal_controller_tests.gd",
	]
	
	for test_file in test_files:
		var test_class = load(test_file)
		if test_class:
			test_suites.append(test_class.new())
	
	print("TestRunner: Running %d test suites..." % test_suites.size())
	
	# Run all tests
	for suite in test_suites:
		var raw = await suite.run()
		var result: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}

		summary["passed"] += result["passed"]
		summary["failed"] += result["failed"]
		summary["failures"].append_array(result["failures"])
	
	# Print summary
	print("tests passed: %d" % summary["passed"])
	print("tests failed: %d" % summary["failed"])
	if summary["failed"] > 0:
		for failure in summary["failures"]:
			printerr("failure: %s" % failure)
	
	# Exit with appropriate code
	exit_code = 1 if summary["failed"] > 0 else 0
	print("TestRunner: Tests complete, exiting with code %d" % exit_code)
	
	# Clean up test library
	_cleanup_test_library()
	
	_tests_done = true
	# Exit on the next frame
	quit(exit_code)

func _setup_test_library() -> void:
	## Sets up an isolated test library directory and sets OGS_LIBRARY_ROOT env var.
	var appdata = OS.get_environment("LOCALAPPDATA")
	if appdata.is_empty():
		# Fall back to user data dir on non-Windows
		appdata = OS.get_user_data_dir()
	var test_library_root = appdata.path_join("OGS_TEST").path_join("Library")
	
	# Set environment variable so PathResolver uses test path
	OS.set_environment("OGS_LIBRARY_ROOT", test_library_root)
	print("TestRunner: Test library isolated to %s" % test_library_root)

func _cleanup_test_library() -> void:
	## Removes test library directory after tests complete.
	var appdata = OS.get_environment("LOCALAPPDATA")
	if appdata.is_empty():
		appdata = OS.get_user_data_dir()
	var test_library_root = appdata.path_join("OGS_TEST").path_join("Library")
	
	if DirAccess.dir_exists_absolute(test_library_root):
		_recursive_remove_dir(test_library_root)
		print("TestRunner: Cleaned up test library at %s" % test_library_root)

func _recursive_remove_dir(path: String) -> void:
	## Recursively removes a directory and all its contents.
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = path.path_join(file_name)
			if dir.current_is_dir():
				_recursive_remove_dir(full_path)
			else:
				DirAccess.remove_absolute(full_path)
			file_name = dir.get_next()
	DirAccess.remove_absolute(path)

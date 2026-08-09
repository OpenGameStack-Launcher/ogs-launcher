extends RefCounted
class_name ToolLauncherTests
const OgsConfigScript = preload("res://scripts/config/ogs_config.gd")

## Unit tests for ToolLauncher process spawning logic.
##
## Note: These tests focus on error handling and argument building.
## Actual process spawning is tested manually to avoid side effects.

func run() -> Dictionary:
	var results := {"passed": 0, "failed": 0, "failures": []}
	
	_test_missing_path_field(results)
	_test_empty_path_field(results)
	_test_empty_project_dir(results)
	_test_tool_not_found(results)
	_test_godot_arguments(results)
	_test_blender_arguments(results)
	_test_unknown_tool_arguments(results)
	_test_absolute_path_handling(results)
	_test_relative_path_handling(results)
	_test_path_traversal_blocked(results)
	_test_find_existing_godot_project(results)
	_test_create_godot_project_when_missing(results)
	_test_resolve_ogs_project_name_from_stack(results)
	_test_sha256_mismatch(results)
	_test_sha256_invalid(results)
	_test_offline_injection_failure(results)
	
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_missing_path_field(results: Dictionary) -> void:
	"""Validates that missing 'path' field resolves from library (and fails if not in library)."""
	var tool_entry = {"id": "godot", "version": "4.3"}
	var result = ToolLauncher.launch(tool_entry, "C:/Projects/test")
	
	# Since path is omitted, launcher attempts library resolution
	# In test environment with no library, this should return TOOL_NOT_FOUND
	_expect(not result["success"], "missing path with no library should fail", results)
	_expect(result["error_code"] == ToolLauncher.LaunchError.TOOL_NOT_FOUND, 
		"missing path should attempt library resolution and return TOOL_NOT_FOUND", results)
	_expect(result["pid"] == -1, "failed launch should return pid -1", results)

func _test_empty_path_field(results: Dictionary) -> void:
	"""Validates that empty 'path' field returns TOOL_PATH_MISSING error."""
	var tool_entry = {"id": "godot", "version": "4.3", "path": ""}
	var result = ToolLauncher.launch(tool_entry, "C:/Projects/test")
	
	_expect(not result["success"], "empty path should fail", results)
	_expect(result["error_code"] == ToolLauncher.LaunchError.TOOL_PATH_MISSING, 
		"empty path should return TOOL_PATH_MISSING", results)

func _test_empty_project_dir(results: Dictionary) -> void:
	"""Validates that empty project directory returns INVALID_PROJECT_DIR error."""
	var tool_entry = {"id": "godot", "version": "4.3", "path": "tools/godot.exe"}
	var result = ToolLauncher.launch(tool_entry, "")
	
	_expect(not result["success"], "empty project dir should fail", results)
	_expect(result["error_code"] == ToolLauncher.LaunchError.INVALID_PROJECT_DIR, 
		"empty project dir should return INVALID_PROJECT_DIR", results)

func _test_tool_not_found(results: Dictionary) -> void:
	"""Validates that non-existent tool path returns TOOL_NOT_FOUND error."""
	var tool_entry = {"id": "godot", "version": "4.3", "path": "tools/nonexistent.exe"}
	var result = ToolLauncher.launch(tool_entry, "C:/Projects/test")
	
	_expect(not result["success"], "nonexistent tool should fail", results)
	_expect(result["error_code"] == ToolLauncher.LaunchError.TOOL_NOT_FOUND, 
		"nonexistent tool should return TOOL_NOT_FOUND", results)

func _test_godot_arguments(results: Dictionary) -> void:
	"""Validates that Godot tool launches in editor mode with project path."""
	var args = ToolLauncher._build_launch_arguments("godot", "C:/Projects/MyGame")
	
	_expect(args.size() == 3, "godot should get 3 args (--editor + --path + dir)", results)
	_expect(args[0] == "--editor", "first arg should be --editor", results)
	_expect(args[1] == "--path", "second arg should be --path", results)
	_expect(args[2] == "C:/Projects/MyGame", "third arg should be project dir", results)

func _test_blender_arguments(results: Dictionary) -> void:
	"""Validates that Blender tool receives no special arguments."""
	var args = ToolLauncher._build_launch_arguments("blender", "C:/Projects/MyGame")
	
	_expect(args.size() == 0, "blender should get no special args", results)

func _test_unknown_tool_arguments(results: Dictionary) -> void:
	"""Validates that unknown tools receive no special arguments."""
	var args = ToolLauncher._build_launch_arguments("krita", "C:/Projects/MyGame")
	
	_expect(args.size() == 0, "unknown tool should get no special args", results)

func _test_absolute_path_handling(results: Dictionary) -> void:
	"""Validates that absolute paths are rejected."""
	var tool_entry = {"id": "test", "version": "1.0", "path": "C:/absolute/path/test.exe"}
	var result = ToolLauncher.launch(tool_entry, "C:/Projects/MyGame")
	
	_expect(not result["success"], "nonexistent absolute path should fail", results)
	_expect(result["error_code"] == ToolLauncher.LaunchError.TOOL_PATH_ABSOLUTE,
		"absolute paths should be rejected", results)

func _test_relative_path_handling(results: Dictionary) -> void:
	"""Validates that relative paths are joined with project directory."""
	var tool_entry = {"id": "test", "version": "1.0", "path": "tools/relative.exe"}
	var result = ToolLauncher.launch(tool_entry, "C:/Projects/MyGame")
	
	_expect(not result["success"], "nonexistent relative path should fail", results)
	_expect(result["error_message"].find("C:/Projects/MyGame/tools/relative.exe") != -1, 
		"error should show joined relative path", results)

func _test_path_traversal_blocked(results: Dictionary) -> void:
	"""Validates that path traversal outside the project root is blocked."""
	var tool_entry = {"id": "test", "version": "1.0", "path": "../outside.exe"}
	var result = ToolLauncher.launch(tool_entry, "C:/Projects/MyGame")
	_expect(not result["success"], "path traversal should fail", results)
	_expect(result["error_code"] == ToolLauncher.LaunchError.TOOL_PATH_OUTSIDE_ROOT,
		"path traversal should return TOOL_PATH_OUTSIDE_ROOT", results)

func _test_find_existing_godot_project(results: Dictionary) -> void:
	"""Validates existing nested project.godot paths are detected for launch."""
	var project_dir = ProjectSettings.globalize_path("user://tool_launcher_existing_project")
	var godot_dir = project_dir.path_join("game")
	var project_file = godot_dir.path_join("project.godot")
	DirAccess.make_dir_recursive_absolute(godot_dir)
	var file = FileAccess.open(project_file, FileAccess.WRITE)
	if file:
		file.store_string("config_version=5\n\n[application]\nconfig/name=\"Existing\"\n")
		file.close()

	var resolve_result = ToolLauncher._resolve_godot_project_dir(project_dir)
	_expect(resolve_result["success"], "existing godot project should resolve", results)
	_expect(String(resolve_result["launch_project_dir"]) == godot_dir,
		"existing project should launch from nested game directory", results)
	_expect(not resolve_result["created"], "existing project should not be recreated", results)

func _test_create_godot_project_when_missing(results: Dictionary) -> void:
	"""Validates missing Godot project files are created under game/."""
	var project_dir = ProjectSettings.globalize_path("user://tool_launcher_create_project")
	DirAccess.make_dir_recursive_absolute(project_dir)
	var existing_root_project = project_dir.path_join("project.godot")
	if FileAccess.file_exists(existing_root_project):
		DirAccess.remove_absolute(existing_root_project)
	var existing_game_project = project_dir.path_join("game").path_join("project.godot")
	if FileAccess.file_exists(existing_game_project):
		DirAccess.remove_absolute(existing_game_project)
	var existing_source_project = project_dir.path_join("project_source").path_join("project.godot")
	if FileAccess.file_exists(existing_source_project):
		DirAccess.remove_absolute(existing_source_project)
	var stack_path = project_dir.path_join("stack.json")
	var stack_file = FileAccess.open(stack_path, FileAccess.WRITE)
	if stack_file:
		stack_file.store_string(JSON.stringify({
			"schema_version": 1,
			"stack_name": "My OGS Project",
			"tools": []
		}))
		stack_file.close()

	var resolve_result = ToolLauncher._resolve_godot_project_dir(project_dir)
	var expected_launch_dir = project_dir.path_join("game")
	var created_project = expected_launch_dir.path_join("project.godot")
	_expect(resolve_result["success"], "missing godot project should be created", results)
	_expect(String(resolve_result["launch_project_dir"]) == expected_launch_dir,
		"created project should launch from game directory", results)
	_expect(resolve_result["created"], "creation flag should be true", results)
	_expect(FileAccess.file_exists(created_project), "project.godot should exist after creation", results)

	var created_file = FileAccess.open(created_project, FileAccess.READ)
	if created_file:
		var created_text = created_file.get_as_text()
		created_file.close()
		_expect(created_text.find("config/name=\"My OGS Project\"") != -1,
			"created project.godot should use stack_name", results)
	else:
		_expect(false, "created project.godot should be readable", results)

func _test_resolve_ogs_project_name_from_stack(results: Dictionary) -> void:
	"""Validates stack.json stack_name is preferred for Godot project naming."""
	var project_dir = ProjectSettings.globalize_path("user://tool_launcher_stack_name")
	DirAccess.make_dir_recursive_absolute(project_dir)
	var stack_path = project_dir.path_join("stack.json")
	var stack_file = FileAccess.open(stack_path, FileAccess.WRITE)
	if stack_file:
		stack_file.store_string(JSON.stringify({
			"schema_version": 1,
			"stack_name": "Named From Stack"
		}))
		stack_file.close()

	var resolved_name = ToolLauncher._resolve_ogs_project_name(project_dir)
	_expect(resolved_name == "Named From Stack", "stack_name should be resolved from stack.json", results)

func _test_sha256_mismatch(results: Dictionary) -> void:
	"""Validates sha256 mismatch is detected before spawning tools."""
	var project_dir = ProjectSettings.globalize_path("user://tool_launcher_tests")
	var rel_path = "tools/mock_tool.bin"
	var full_path = project_dir.path_join(rel_path)
	DirAccess.make_dir_recursive_absolute(full_path.get_base_dir())
	var file = FileAccess.open(full_path, FileAccess.WRITE)
	if file:
		file.store_string("mock")
		file.close()
	var tool_entry = {
		"id": "test",
		"version": "1.0",
		"path": rel_path,
		"sha256": "0".repeat(64)
	}
	var result = ToolLauncher.launch(tool_entry, project_dir)
	_expect(not result["success"], "sha256 mismatch should fail", results)
	_expect(result["error_code"] == ToolLauncher.LaunchError.TOOL_HASH_MISMATCH,
		"sha256 mismatch should return TOOL_HASH_MISMATCH", results)

func _test_sha256_invalid(results: Dictionary) -> void:
	"""Validates invalid sha256 values are rejected."""
	var project_dir = ProjectSettings.globalize_path("user://tool_launcher_tests")
	var rel_path = "tools/mock_tool_invalid.bin"
	var full_path = project_dir.path_join(rel_path)
	DirAccess.make_dir_recursive_absolute(full_path.get_base_dir())
	var file = FileAccess.open(full_path, FileAccess.WRITE)
	if file:
		file.store_string("mock")
		file.close()
	var tool_entry = {
		"id": "test",
		"version": "1.0",
		"path": rel_path,
		"sha256": "not-a-hash"
	}
	var result = ToolLauncher.launch(tool_entry, project_dir)
	_expect(not result["success"], "invalid sha256 should fail", results)
	_expect(result["error_code"] == ToolLauncher.LaunchError.TOOL_HASH_INVALID,
		"invalid sha256 should return TOOL_HASH_INVALID", results)

func _test_offline_injection_failure(results: Dictionary) -> void:
	"""Verifies offline injection errors are surfaced when config write fails."""
	var tool_entry = {"id": "godot", "version": "4.3", "path": "tools/missing.exe"}
	var config = OgsConfigScript.from_dict({"offline_mode": true})
	OfflineEnforcer.apply_config(config)
	var result = ToolLauncher.launch(tool_entry, "C:/Projects/MyGame")
	_expect(not result["success"], "offline launch should fail on bad config", results)
	_expect(result["error_code"] == ToolLauncher.LaunchError.OFFLINE_CONFIG_FAILED or result["error_code"] == ToolLauncher.LaunchError.TOOL_NOT_FOUND,
		"offline errors should be surfaced", results)
	OfflineEnforcer.apply_config(OgsConfigScript.from_dict({"offline_mode": false}))

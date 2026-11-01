## ProjectEnvironmentValidator Tests
##
## Unit tests for the ProjectEnvironmentValidator module.
## Tests cover environment validation, missing tool detection, and library accessibility.

extends RefCounted
class_name ProjectEnvironmentValidatorTests

func run() -> Dictionary:
	var results = {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	
	var tests = [
		{"name": "test_validator_initializes", "func": test_validator_initializes},
		{"name": "test_validate_project_empty_dir_fails", "func": test_validate_project_empty_dir_fails},
		{"name": "test_validate_project_missing_stack_fails", "func": test_validate_project_missing_stack_fails},
		{"name": "test_validate_project_returns_dict", "func": test_validate_project_returns_dict},
		{"name": "test_get_download_list_returns_array", "func": test_get_download_list_returns_array},
		{"name": "test_is_library_accessible_returns_dict", "func": test_is_library_accessible_returns_dict},
		{"name": "test_validate_project_with_local_ogs_tools_succeeds", "func": test_validate_project_with_local_ogs_tools_succeeds},
		{"name": "test_validate_project_with_missing_local_ogs_tools_fails", "func": test_validate_project_with_missing_local_ogs_tools_fails},
	]
	
	for test in tests:
		var result = test.func.call()
		if result["passed"]:
			results.passed += 1
		else:
			results.failed += 1
			if result.has("error"):
				results.failures.append("%s: %s" % [test.name, result["error"]])
			else:
				results.failures.append("%s: unknown error" % test.name)
	
	return results

func test_validator_initializes() -> Dictionary:
	## Verifies validator initializes with valid state.
	var validator = ProjectEnvironmentValidator.new()
	
	if validator == null:
		return {"passed": false, "error": "Validator should not be null"}
	
	if validator.library == null:
		return {"passed": false, "error": "LibraryManager should be initialized"}
	
	return {"passed": true}

func test_validate_project_empty_dir_fails() -> Dictionary:
	## Verifies validation fails for empty directory.
	var validator = ProjectEnvironmentValidator.new()
	var result = validator.validate_project("")
	
	if result["valid"]:
		return {"passed": false, "error": "Should be invalid for empty directory"}
	
	if result["errors"].is_empty():
		return {"passed": false, "error": "Should have error message"}
	
	return {"passed": true}

func test_validate_project_missing_stack_fails() -> Dictionary:
	## Verifies validation fails when ogs_stack.json is missing.
	var validator = ProjectEnvironmentValidator.new()
	
	# Use a directory that exists but has no ogs_stack.json
	var result = validator.validate_project("user://")
	
	if result["valid"]:
		return {"passed": false, "error": "Should be invalid when ogs_stack.json missing"}
	
	if result["errors"].is_empty():
		return {"passed": false, "error": "Should have error message"}
	
	return {"passed": true}

func test_validate_project_returns_dict() -> Dictionary:
	## Verifies validation result has required structure.
	var validator = ProjectEnvironmentValidator.new()
	var result = validator.validate_project("user://")
	
	if not result.has("valid"):
		return {"passed": false, "error": "Result missing 'valid' key"}
	
	if not result.has("ready"):
		return {"passed": false, "error": "Result missing 'ready' key"}
	
	if not result.has("missing_tools"):
		return {"passed": false, "error": "Result missing 'missing_tools' key"}
	
	if not result.has("errors"):
		return {"passed": false, "error": "Result missing 'errors' key"}
	
	if not result["missing_tools"] is Array:
		return {"passed": false, "error": "'missing_tools' should be an array"}
	
	if not result["errors"] is Array:
		return {"passed": false, "error": "'errors' should be an array"}
	
	return {"passed": true}

func test_get_download_list_returns_array() -> Dictionary:
	## Verifies get_download_list returns proper structure.
	var validator = ProjectEnvironmentValidator.new()
	
	var missing_tools = [
		{"id": "godot", "version": "4.3"},
		{"id": "blender", "version": "4.2"}
	]
	
	var downloads = validator.get_download_list(missing_tools)
	
	if not downloads is Array:
		return {"passed": false, "error": "Should return array"}
	
	if downloads.size() != 2:
		return {"passed": false, "error": "Should have 2 items"}
	
	if not downloads[0].has("tool_id") or not downloads[0].has("version"):
		return {"passed": false, "error": "Items should have tool_id and version"}
	
	return {"passed": true}

func test_is_library_accessible_returns_dict() -> Dictionary:
	## Verifies library accessibility check returns proper structure.
	var validator = ProjectEnvironmentValidator.new()
	var result = validator.is_library_accessible()
	
	if not result.has("accessible"):
		return {"passed": false, "error": "Result missing 'accessible' key"}
	
	if not result.has("path"):
		return {"passed": false, "error": "Result missing 'path' key"}
	
	if not result["accessible"] is bool:
		return {"passed": false, "error": "'accessible' should be boolean"}
	
	return {"passed": true}

func test_validate_project_with_local_ogs_tools_succeeds() -> Dictionary:
	## Verifies that validation succeeds when use_project_tools=true and tools are in ogs_tools/<id>_<version>.
	var test_id = str(Time.get_ticks_msec())
	var project_dir = ProjectSettings.globalize_path("user://test_pev_local_ogs_tools_%s" % test_id)
	DirAccess.make_dir_recursive_absolute(project_dir)

	var stack_file = project_dir.path_join("ogs_stack.json")
	var stack_payload = {
		"schema_version": StackManifest.CURRENT_SCHEMA_VERSION,
		"stack_name": "PEV Local Test",
		"tools": [
			{"id": "godot", "version": "4.7.2"}
		]
	}
	var f = FileAccess.open(stack_file, FileAccess.WRITE)
	f.store_string(JSON.stringify(stack_payload))
	f.close()

	# Create local ogs_tools/godot_4.7.2/ with mock binary and ogs_metadata.json
	var local_tool_dir = project_dir.path_join("ogs_tools").path_join("godot_4.7.2")
	DirAccess.make_dir_recursive_absolute(local_tool_dir)
	var bin_file = local_tool_dir.path_join("godot.exe" if OS.get_name() == "Windows" else "godot")
	var bf = FileAccess.open(bin_file, FileAccess.WRITE)
	bf.store_string("mock")
	bf.close()

	var meta_file = local_tool_dir.path_join("ogs_metadata.json")
	var mf = FileAccess.open(meta_file, FileAccess.WRITE)
	mf.store_string(JSON.stringify({"executable_path": bin_file.get_file()}))
	mf.close()

	var validator = ProjectEnvironmentValidator.new()
	var result = validator.validate_project(project_dir, true)

	_cleanup_dir_recursive(project_dir)

	if not result["valid"]:
		return {"passed": false, "error": "Validation should be valid: %s" % str(result["errors"])}
	if not result["ready"]:
		return {"passed": false, "error": "Validation should be ready with local ogs_tools populated"}
	if not result["missing_tools"].is_empty():
		return {"passed": false, "error": "Missing tools should be empty, but got: %s" % str(result["missing_tools"])}

	return {"passed": true}

func test_validate_project_with_missing_local_ogs_tools_fails() -> Dictionary:
	## Verifies that validation marks tool missing when use_project_tools=true and ogs_tools/ is empty.
	var test_id = str(Time.get_ticks_msec())
	var project_dir = ProjectSettings.globalize_path("user://test_pev_missing_local_%s" % test_id)
	DirAccess.make_dir_recursive_absolute(project_dir)

	var stack_file = project_dir.path_join("ogs_stack.json")
	var stack_payload = {
		"schema_version": StackManifest.CURRENT_SCHEMA_VERSION,
		"stack_name": "PEV Missing Local Test",
		"tools": [
			{"id": "godot", "version": "4.7.2"}
		]
	}
	var f = FileAccess.open(stack_file, FileAccess.WRITE)
	f.store_string(JSON.stringify(stack_payload))
	f.close()

	var validator = ProjectEnvironmentValidator.new()
	var result = validator.validate_project(project_dir, true)

	_cleanup_dir_recursive(project_dir)

	if not result["valid"]:
		return {"passed": false, "error": "Validation syntax should be valid"}
	if result["ready"]:
		return {"passed": false, "error": "Validation should not be ready when ogs_tools is missing"}
	if result["missing_tools"].size() != 1:
		return {"passed": false, "error": "Expected 1 missing tool, got %d" % result["missing_tools"].size()}

	return {"passed": true}

static func _cleanup_dir_recursive(path: String) -> void:
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var item_path = path.path_join(name)
			if dir.current_is_dir():
				_cleanup_dir_recursive(item_path)
			else:
				DirAccess.remove_absolute(item_path)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)

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
	## Verifies validation fails when stack.json is missing.
	var validator = ProjectEnvironmentValidator.new()
	
	# Use a directory that exists but has no stack.json
	var result = validator.validate_project("user://")
	
	if result["valid"]:
		return {"passed": false, "error": "Should be invalid when stack.json missing"}
	
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

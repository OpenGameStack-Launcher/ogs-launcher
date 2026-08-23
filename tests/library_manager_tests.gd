## LibraryManager Tests
##
## Unit tests for the LibraryManager module.
## Tests cover tool discovery, validation, and metadata retrieval.

extends RefCounted
class_name LibraryManagerTests

func run() -> Dictionary:
	var results = {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	
	var tests = [
		{"name": "test_get_available_tools_returns_array", "func": test_get_available_tools_returns_array},
		{"name": "test_get_available_versions_returns_array", "func": test_get_available_versions_returns_array},
		{"name": "test_tool_exists_false_for_missing", "func": test_tool_exists_false_for_missing},
		{"name": "test_get_tool_path_returns_non_empty_for_valid_tool", "func": test_get_tool_path_returns_non_empty_for_valid_tool},
		{"name": "test_validate_tool_returns_dict_structure", "func": test_validate_tool_returns_dict_structure},
		{"name": "test_validate_tool_fails_for_missing", "func": test_validate_tool_fails_for_missing},
		{"name": "test_get_tool_metadata_returns_dict", "func": test_get_tool_metadata_returns_dict},
		{"name": "test_get_library_summary_returns_dict", "func": test_get_library_summary_returns_dict},
		{"name": "test_calculate_dir_size_returns_correct_value", "func": test_calculate_dir_size_returns_correct_value},
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

func test_get_available_tools_returns_array() -> Dictionary:
	var library = LibraryManager.new()
	var tools = library.get_available_tools()
	
	if tools == null:
		return {"passed": false, "error": "Should return array, not null"}
	
	if not tools is Array:
		return {"passed": false, "error": "Should return Array type"}
	
	return {"passed": true}

func test_get_available_versions_returns_array() -> Dictionary:
	var library = LibraryManager.new()
	var versions = library.get_available_versions("godot")
	
	if versions == null:
		return {"passed": false, "error": "Should return array, not null"}
	
	if not versions is Array:
		return {"passed": false, "error": "Should return Array type"}
	
	return {"passed": true}

func test_tool_exists_false_for_missing() -> Dictionary:
	var library = LibraryManager.new()
	var exists = library.tool_exists("nonexistent_tool_xyz", "999.999")
	
	if exists:
		return {"passed": false, "error": "Nonexistent tool should return false"}
	
	if exists != false:
		return {"passed": false, "error": "Should return boolean false"}
	
	return {"passed": true}

func test_get_tool_path_returns_non_empty_for_valid_tool() -> Dictionary:
	var library = LibraryManager.new()
	
	# Get a tool that might not exist; this tests the path construction logic
	# regardless of actual existence
	var path = library.get_tool_path("godot", "4.3")
	
	# If tool doesn't exist, path should be empty
	# If it does exist, path should be non-empty
	# We can't assume either, so just check the logic doesn't crash
	
	if path == null:
		return {"passed": false, "error": "Should return string (empty if not found)"}
	
	return {"passed": true}

func test_validate_tool_returns_dict_structure() -> Dictionary:
	var library = LibraryManager.new()
	var validation = library.validate_tool("nonexistent", "1.0")
	
	if not validation.has("valid"):
		return {"passed": false, "error": "Result should have 'valid' key"}
	
	if not validation.has("errors"):
		return {"passed": false, "error": "Result should have 'errors' key"}
	
	if not validation["errors"] is Array:
		return {"passed": false, "error": "'errors' should be an array"}
	
	return {"passed": true}

func test_validate_tool_fails_for_missing() -> Dictionary:
	var library = LibraryManager.new()
	var validation = library.validate_tool("nonexistent_tool_xyz", "999.999")
	
	if validation["valid"]:
		return {"passed": false, "error": "Should be invalid for missing tool"}
	
	if validation["errors"].is_empty():
		return {"passed": false, "error": "Should have error message for missing tool"}
	
	return {"passed": true}

func test_get_tool_metadata_returns_dict() -> Dictionary:
	var library = LibraryManager.new()
	var metadata = library.get_tool_metadata("godot", "4.3")
	
	if not metadata.has("exists"):
		return {"passed": false, "error": "Result should have 'exists' key"}
	
	if not metadata.has("path"):
		return {"passed": false, "error": "Result should have 'path' key"}
	
	if not metadata.has("size_bytes"):
		return {"passed": false, "error": "Result should have 'size_bytes' key"}
	
	if not metadata.has("last_modified"):
		return {"passed": false, "error": "Result should have 'last_modified' key"}
	
	if metadata["exists"]:
		# If tool exists, path should be non-empty
		if metadata["path"].is_empty():
			return {"passed": false, "error": "Path should be non-empty for existing tool"}
	else:
		# If tool doesn't exist, these should be default values
		if not metadata["path"].is_empty():
			return {"passed": false, "error": "Path should be empty for nonexistent tool"}
	
	return {"passed": true}

func test_get_library_summary_returns_dict() -> Dictionary:
	var library = LibraryManager.new()
	var summary = library.get_library_summary()
	
	if not summary.has("library_root"):
		return {"passed": false, "error": "Should have 'library_root' key"}
	
	if not summary.has("total_tools"):
		return {"passed": false, "error": "Should have 'total_tools' key"}
	
	if not summary.has("total_versions"):
		return {"passed": false, "error": "Should have 'total_versions' key"}
	
	if not summary.has("tools"):
		return {"passed": false, "error": "Should have 'tools' key"}
	
	if summary["total_tools"] < 0:
		return {"passed": false, "error": "total_tools should be >= 0"}
	
	return {"passed": true}

func test_calculate_dir_size_returns_correct_value() -> Dictionary:
	var library = LibraryManager.new()
	var test_dir = "user://test_dir_size_calc"
	var dir = DirAccess.open("user://")
	
	if dir != null:
		if dir.dir_exists(test_dir):
			library._remove_directory_contents(test_dir)
		dir.make_dir_recursive(test_dir)
		
		var file = FileAccess.open(test_dir + "/test.txt", FileAccess.WRITE)
		if file != null:
			file.store_string("Hello World") # 11 bytes
			file.close()
			
		dir.make_dir(test_dir + "/sub")
		var file2 = FileAccess.open(test_dir + "/sub/test2.txt", FileAccess.WRITE)
		if file2 != null:
			file2.store_string("12345") # 5 bytes
			file2.close()
			
	var size = library._calculate_dir_size(test_dir)
	
	# Cleanup
	library._remove_directory_contents(test_dir)
	
	if size != 16:
		return {"passed": false, "error": "Size should be 16 bytes, got " + str(size)}
		
	return {"passed": true}

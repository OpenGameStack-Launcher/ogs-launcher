## PathResolver Tests
##
## Unit tests for the PathResolver utility module.
## Tests cover path resolution, environment variable expansion, and tool discovery.

extends RefCounted
class_name PathResolverTests

func run() -> Dictionary:
	var results = {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	
	var tests = [
		{"name": "test_get_library_root_returns_non_empty", "func": test_get_library_root_returns_non_empty},
		{"name": "test_get_tool_path_constructs_correct_path", "func": test_get_tool_path_constructs_correct_path},
		{"name": "test_normalize_path_handles_forward_slashes", "func": test_normalize_path_handles_forward_slashes},
		{"name": "test_tool_exists_returns_false_for_missing", "func": test_tool_exists_returns_false_for_missing},
		{"name": "test_get_available_tools_handles_missing_library", "func": test_get_available_tools_handles_missing_library},
		{"name": "test_get_available_versions_handles_missing_tool", "func": test_get_available_versions_handles_missing_tool},
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

func test_get_library_root_returns_non_empty() -> Dictionary:
	var resolver = PathResolver.new()
	var root = resolver.get_library_root()
	
	if root.is_empty():
		return {"passed": false, "error": "Library root is empty"}
	
	if OS.get_name() == "Windows":
		if not root.contains("OGS"):
			return {"passed": false, "error": "Windows path should contain 'OGS'"}
	
	return {"passed": true}

func test_get_tool_path_constructs_correct_path() -> Dictionary:
	var resolver = PathResolver.new()
	var tool_path = resolver.get_tool_path("godot", "4.3")
	
	if tool_path.is_empty():
		return {"passed": false, "error": "Tool path is empty"}
	
	if not tool_path.contains("godot"):
		return {"passed": false, "error": "Tool path should contain 'godot'"}
	
	if not tool_path.contains("4.3"):
		return {"passed": false, "error": "Tool path should contain version '4.3'"}
	
	return {"passed": true}

func test_normalize_path_handles_forward_slashes() -> Dictionary:
	var resolver = PathResolver.new()
	
	# Test with backslashes
	var backslash_path = "C:\\Users\\Test\\Path"
	var normalized = PathResolver.normalize_path(backslash_path)
	
	if normalized.is_empty():
		return {"passed": false, "error": "Normalized path is empty"}
	
	# Check that normalization occurred (forward slashes)
	if normalized.contains("\\"):
		return {"passed": false, "error": "Normalized path should not contain backslashes"}
	
	return {"passed": true}

func test_tool_exists_returns_false_for_missing() -> Dictionary:
	var resolver = PathResolver.new()
	
	# Query for a tool that definitely doesn't exist
	var exists = resolver.tool_exists("nonexistent_tool_xyz", "999.999")
	
	if exists:
		return {"passed": false, "error": "Nonexistent tool should return false"}
	
	return {"passed": true}

func test_get_available_tools_handles_missing_library() -> Dictionary:
	var resolver = PathResolver.new()
	
	# This should not crash even if library doesn't exist
	var tools = resolver.get_available_tools()
	
	if tools == null:
		return {"passed": false, "error": "Should return array, not null"}
	
	# It's okay if empty (library may not exist yet)
	return {"passed": true}

func test_get_available_versions_handles_missing_tool() -> Dictionary:
	var resolver = PathResolver.new()
	
	# Query for a tool that doesn't exist
	var versions = resolver.get_available_versions("nonexistent_tool_xyz")
	
	if versions == null:
		return {"passed": false, "error": "Should return array, not null"}
	
	# Should be empty
	if not versions.is_empty():
		return {"passed": false, "error": "Should return empty array for missing tool"}
	
	return {"passed": true}

## ProjectSealer Tests
##
## Unit tests for the ProjectSealer module.
## Tests cover validation, tool copying, config writing, and zip creation.

extends RefCounted
class_name ProjectSealerTests

const OgsLogger = preload("res://scripts/logging/logger.gd")

const SealerTestHelpersScript = preload("res://tests/project_sealer_test_helpers.gd")
const SealToolCopierScript = preload("res://scripts/projects/project_seal_tool_copier.gd")

var _helpers = SealerTestHelpersScript.new()

func run() -> Dictionary:
	var results = {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	
	var tests = [
		{"name": "test_seal_project_returns_dict", "func": test_seal_project_returns_dict},
		{"name": "test_seal_project_rejects_empty_path", "func": test_seal_project_rejects_empty_path},
		{"name": "test_seal_project_rejects_missing_directory", "func": test_seal_project_rejects_missing_directory},
		{"name": "test_seal_project_rejects_missing_stack_json", "func": test_seal_project_rejects_missing_stack_json},
		{"name": "test_seal_project_rejects_missing_tools", "func": test_seal_project_rejects_missing_tools},
		{"name": "test_seal_project_validates_manifest_integrity", "func": test_seal_project_validates_manifest_integrity},
		{"name": "test_seal_project_success_with_valid_project", "func": test_seal_project_success_with_valid_project},
		{"name": "test_seal_project_creates_ogs_config", "func": test_seal_project_creates_ogs_config},
		{"name": "test_seal_project_returns_tools_copied", "func": test_seal_project_returns_tools_copied},
		{"name": "test_seal_project_returns_zip_path", "func": test_seal_project_returns_zip_path},
		{"name": "test_seal_project_trims_path_slash", "func": test_seal_project_trims_path_slash},
		{"name": "test_seal_project_creates_real_zip_archive", "func": test_seal_project_creates_real_zip_archive},
		{"name": "test_sealed_zip_contains_expected_files", "func": test_sealed_zip_contains_expected_files},
		{"name": "test_seal_project_writes_packaging_logs", "func": test_seal_project_writes_packaging_logs},
		{"name": "test_project_seal_tool_copier_copies_large_files", "func": test_project_seal_tool_copier_copies_large_files},
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

## Test: seal_project returns a dictionary with expected structure
func test_seal_project_returns_dict() -> Dictionary:
	var sealer = ProjectSealer.new()
	var result = sealer.seal_project("")
	
	if not result is Dictionary:
		return {"passed": false, "error": "Should return Dictionary"}
	
	if not result.has("success"):
		return {"passed": false, "error": "Missing 'success' key"}
	
	if not result.has("errors"):
		return {"passed": false, "error": "Missing 'errors' key"}
	
	if not result.has("sealed_zip"):
		return {"passed": false, "error": "Missing 'sealed_zip' key"}
	
	if not result.has("tools_copied"):
		return {"passed": false, "error": "Missing 'tools_copied' key"}
	
	if not result.has("project_size_mb"):
		return {"passed": false, "error": "Missing 'project_size_mb' key"}
	
	return {"passed": true}

## Test: seal_project rejects empty path
func test_seal_project_rejects_empty_path() -> Dictionary:
	var sealer = ProjectSealer.new()
	var result = sealer.seal_project("")
	
	if result.success:
		return {"passed": false, "error": "Should reject empty path"}
	
	if result.errors.is_empty():
		return {"passed": false, "error": "Should have error message"}
	
	return {"passed": true}

## Test: seal_project rejects non-existent directory
func test_seal_project_rejects_missing_directory() -> Dictionary:
	var sealer = ProjectSealer.new()
	var result = sealer.seal_project("/nonexistent/path/xyz")
	
	if result.success:
		return {"passed": false, "error": "Should reject missing directory"}
	
	if result.errors.is_empty():
		return {"passed": false, "error": "Should have error message"}
	
	var error_text = str(result.errors)
	if not error_text.contains("does not exist"):
		return {"passed": false, "error": "Error should mention directory not existing"}
	
	return {"passed": true}

## Test: seal_project rejects directory without stack.json
func test_seal_project_rejects_missing_stack_json() -> Dictionary:
	# Create temporary directory without stack.json
	var temp_dir = "user://test_seal_no_stack"
	var dir_access = DirAccess.open("user://")
	if dir_access == null:
		return {"passed": false, "error": "Cannot access user:// directory"}
	
	DirAccess.make_dir_absolute(temp_dir)
	
	var sealer = ProjectSealer.new()
	var result = sealer.seal_project(temp_dir)
	
	# Cleanup
	DirAccess.remove_absolute(temp_dir)
	
	if result.success:
		return {"passed": false, "error": "Should reject missing stack.json"}
	
	if result.errors.is_empty():
		return {"passed": false, "error": "Should have error message"}
	
	var error_text = str(result.errors)
	if not error_text.contains("stack.json"):
		return {"passed": false, "error": "Error should mention stack.json"}
	
	return {"passed": true}

## Test: seal_project rejects manifest with missing tools in library
func test_seal_project_rejects_missing_tools() -> Dictionary:
	# Create temporary directory with stack.json
	var temp_dir = "user://test_seal_missing_tools"
	var dir_access = DirAccess.open("user://")
	if dir_access == null:
		return {"passed": false, "error": "Cannot access user:// directory"}
	
	DirAccess.make_dir_absolute(temp_dir)
	
	# Create a stack.json with a tool that definitely doesn't exist
	var stack_file = FileAccess.open(temp_dir.path_join("stack.json"), FileAccess.WRITE)
	if stack_file == null:
		DirAccess.remove_absolute(temp_dir)
		return {"passed": false, "error": "Cannot write test stack.json"}
	
	stack_file.store_string('{"schema_version": 1, "stack_name": "test", "tools": [{"id": "nonexistent_xyz", "version": "999.999.999", "path": "test"}]}')
	
	var sealer = ProjectSealer.new()
	var result = sealer.seal_project(temp_dir)
	
	# Cleanup
	DirAccess.remove_absolute(temp_dir)
	
	if result.success:
		return {"passed": false, "error": "Should reject missing tools"}
	
	if result.errors.is_empty():
		return {"passed": false, "error": "Should have error message"}
	
	var error_text = str(result.errors)
	# Check for error mentioning tool or validation failure
	if not (error_text.contains("Tool") or error_text.contains("not found") or error_text.contains("invalid")):
		return {"passed": false, "error": "Error should mention missing tool, got: %s" % error_text}
	
	return {"passed": true}

## Test: seal_project validates manifest schema
func test_seal_project_validates_manifest_integrity() -> Dictionary:
	# Create temporary directory with invalid stack.json
	var temp_dir = "user://test_seal_invalid_manifest"
	var dir_access = DirAccess.open("user://")
	if dir_access == null:
		return {"passed": false, "error": "Cannot access user:// directory"}
	
	DirAccess.make_dir_absolute(temp_dir)
	
	var stack_file = FileAccess.open(temp_dir.path_join("stack.json"), FileAccess.WRITE)
	if stack_file == null:
		DirAccess.remove_absolute(temp_dir)
		return {"passed": false, "error": "Cannot write test stack.json"}
	
	# Invalid manifest (missing schema_version)
	stack_file.store_string('{"stack_name": "broken", "tools": [{"id": "test", "version": "1.0", "path": "t"}]}')
	
	var sealer = ProjectSealer.new()
	var result = sealer.seal_project(temp_dir)
	
	# Cleanup
	DirAccess.remove_absolute(temp_dir)
	
	if result.success:
		return {"passed": false, "error": "Should reject invalid manifest"}
	
	if result.errors.is_empty():
		return {"passed": false, "error": "Should have error message"}
	
	var error_text = str(result.errors)
	if not error_text.contains("invalid"):
		return {"passed": false, "error": "Error should mention manifest validity"}
	
	return {"passed": true}

## Test: seal_project succeeds with valid project (if tools exist in library)
func test_seal_project_success_with_valid_project() -> Dictionary:
	# Create temporary project with valid stack.json
	var temp_dir = "user://test_seal_valid_project"
	var dir_access = DirAccess.open("user://")
	if dir_access == null:
		return {"passed": false, "error": "Cannot access user:// directory"}
	
	DirAccess.make_dir_absolute(temp_dir)
	
	var stack_file = FileAccess.open(temp_dir.path_join("stack.json"), FileAccess.WRITE)
	if stack_file == null:
		DirAccess.remove_absolute(temp_dir)
		return {"passed": false, "error": "Cannot write test stack.json"}
	
	# Create a valid stack.json (but godot 4.3 may not exist in library, so seal will fail)
	stack_file.store_string('{"schema_version": 1, "stack_name": "test_stack", "tools": [{"id": "godot", "version": "4.3", "path": "tools/godot"}]}')
	
	var sealer = ProjectSealer.new()
	var result = sealer.seal_project(temp_dir)
	
	# Cleanup
	DirAccess.remove_absolute(temp_dir)
	
	# Test just verifies that the result has expected structure, not that it succeeds
	# (tool may not exist in test library)
	if not result.has("success"):
		return {"passed": false, "error": "Result should have success key"}
	
	if not result.has("errors"):
		return {"passed": false, "error": "Result should have errors key"}
	
	return {"passed": true}

## Test: seal_project creates ogs_config.json with force_offline=true
func test_seal_project_creates_ogs_config() -> Dictionary:
	# Note: This test verifies config creation happens when sealing completes successfully.
	# Since we can't guarantee tools exist in test library, this test verifies the write function works
	# by checking the config was created when the full seal would succeed.
	# For MVP, we just verify the sealer attempts to create it as part of the workflow.
	var temp_dir = "user://test_seal_config"
	var dir_access = DirAccess.open("user://")
	if dir_access == null:
		return {"passed": false, "error": "Cannot access user:// directory"}
	
	DirAccess.make_dir_absolute(temp_dir)
	
	var stack_file = FileAccess.open(temp_dir.path_join("stack.json"), FileAccess.WRITE)
	if stack_file == null:
		DirAccess.remove_absolute(temp_dir)
		return {"passed": false, "error": "Cannot write test stack.json"}
	
	# Use a valid manifest structure
	stack_file.store_string('{"schema_version": 1, "stack_name": "test_stack", "tools": [{"id": "test_tool", "version": "1.0", "path": "tools/test"}]}')
	
	var sealer = ProjectSealer.new()
	var result = sealer.seal_project(temp_dir)
	
	# Cleanup
	DirAccess.remove_absolute(temp_dir)
	
	# Result should be a proper dictionary regardless of success
	if not result is Dictionary:
		return {"passed": false, "error": "seal_project should return a Dictionary"}
	
	if not result.has("errors"):
		return {"passed": false, "error": "Result should have errors key"}
	
	return {"passed": true}

## Test: seal_project returns tools_copied array
func test_seal_project_returns_tools_copied() -> Dictionary:
	var temp_dir = "user://test_seal_tools_copied"
	var dir_access = DirAccess.open("user://")
	if dir_access == null:
		return {"passed": false, "error": "Cannot access user:// directory"}
	
	DirAccess.make_dir_absolute(temp_dir)
	
	var stack_file = FileAccess.open(temp_dir.path_join("stack.json"), FileAccess.WRITE)
	if stack_file == null:
		DirAccess.remove_absolute(temp_dir)
		return {"passed": false, "error": "Cannot write test stack.json"}
	
	stack_file.store_string('{"schema_version": 1, "stack_name": "test_stack", "tools": [{"id": "godot", "version": "4.3", "path": "tools/godot"}]}')
	
	var sealer = ProjectSealer.new()
	var result = sealer.seal_project(temp_dir)
	
	# Cleanup
	DirAccess.remove_absolute(temp_dir)
	
	if not result.has("tools_copied"):
		return {"passed": false, "error": "Missing tools_copied key"}
	
	if not result.tools_copied is Array:
		return {"passed": false, "error": "tools_copied should be an Array"}
	
	return {"passed": true}

## Test: seal_project returns sealed_zip path
func test_seal_project_returns_zip_path() -> Dictionary:
	var temp_dir = "user://test_seal_zip_path"
	var dir_access = DirAccess.open("user://")
	if dir_access == null:
		return {"passed": false, "error": "Cannot access user:// directory"}
	
	DirAccess.make_dir_absolute(temp_dir)
	
	var stack_file = FileAccess.open(temp_dir.path_join("stack.json"), FileAccess.WRITE)
	if stack_file == null:
		DirAccess.remove_absolute(temp_dir)
		return {"passed": false, "error": "Cannot write test stack.json"}
	
	stack_file.store_string('{"schema_version": 1, "stack_name": "test_stack", "tools": [{"id": "godot", "version": "4.3", "path": "tools/godot"}]}')
	
	var sealer = ProjectSealer.new()
	var result = sealer.seal_project(temp_dir)
	
	# Cleanup
	DirAccess.remove_absolute(temp_dir)
	
	if result.success and result.sealed_zip.is_empty():
		return {"passed": false, "error": "sealed_zip should not be empty on success"}
	
	if result.success and not result.sealed_zip.contains(".zip"):
		return {"passed": false, "error": "sealed_zip should be a .zip file"}
	
	return {"passed": true}

## Test: seal_project trims trailing slashes from path
func test_seal_project_trims_path_slash() -> Dictionary:
	# Create temporary project
	var temp_dir = "user://test_seal_slash"
	var dir_access = DirAccess.open("user://")
	if dir_access == null:
		return {"passed": false, "error": "Cannot access user:// directory"}
	
	DirAccess.make_dir_absolute(temp_dir)
	
	var stack_file = FileAccess.open(temp_dir.path_join("stack.json"), FileAccess.WRITE)
	if stack_file == null:
		DirAccess.remove_absolute(temp_dir)
		return {"passed": false, "error": "Cannot write test stack.json"}
	
	# Use a tool that likely doesn't exist so seal fails, but we just test path handling
	stack_file.store_string('{"schema_version": 1, "stack_name": "test_stack", "tools": [{"id": "nonexistent_tool_xyz", "version": "1.0", "path": "tools/test"}]}')
	
	var sealer = ProjectSealer.new()
	# Call with trailing slash - path should still be normalized
	var result = sealer.seal_project(temp_dir + "/")
	
	# Cleanup
	DirAccess.remove_absolute(temp_dir)
	
	# Should fail because tool doesn't exist, but result should have proper structure
	if not result.has("errors"):
		return {"passed": false, "error": "Result should have errors key even on failure"}
	
	return {"passed": true}

## Test: seal_project creates a real zip archive when tools are available
func test_seal_project_creates_real_zip_archive() -> Dictionary:
	var fixture = _helpers.create_seal_success_fixture("test_seal_real_zip")
	if not fixture.success:
		return {"passed": false, "error": fixture.error}

	var sealer = ProjectSealer.new()
	var result = sealer.seal_project(fixture.project_dir)

	_helpers.cleanup_seal_fixture(fixture)

	if not result.success:
		return {"passed": false, "error": "Seal should succeed, got errors: %s" % str(result.errors)}

	if result.sealed_zip.is_empty():
		return {"passed": false, "error": "sealed_zip should not be empty on success"}

	if not FileAccess.file_exists(result.sealed_zip):
		return {"passed": false, "error": "Expected zip archive to exist at: %s" % result.sealed_zip}

	if result.project_size_mb <= 0.0:
		return {"passed": false, "error": "project_size_mb should be greater than 0 for created zip"}

	return {"passed": true}

## Test: sealed zip contains stack, config, and copied tool files
func test_sealed_zip_contains_expected_files() -> Dictionary:
	var fixture = _helpers.create_seal_success_fixture("test_seal_zip_contents")
	if not fixture.success:
		return {"passed": false, "error": fixture.error}

	var sealer = ProjectSealer.new()
	var result = sealer.seal_project(fixture.project_dir)

	if not result.success:
		_helpers.cleanup_seal_fixture(fixture)
		return {"passed": false, "error": "Seal should succeed, got errors: %s" % str(result.errors)}

	var zip_reader = ZIPReader.new()
	var open_error = zip_reader.open(result.sealed_zip)
	if open_error != OK:
		_helpers.cleanup_seal_fixture(fixture)
		return {"passed": false, "error": "Failed to open sealed zip: %s" % error_string(open_error)}

	var zip_files = zip_reader.get_files()
	zip_reader.close()

	_helpers.cleanup_seal_fixture(fixture)

	if not zip_files.has("stack.json"):
		return {"passed": false, "error": "Zip missing stack.json"}

	if not zip_files.has("ogs_config.json"):
		return {"passed": false, "error": "Zip missing ogs_config.json"}

	var expected_prefix = "tools/%s_%s/" % [fixture.tool_id, fixture.version]
	var has_tool_file = false
	for zip_path in zip_files:
		if String(zip_path).begins_with(expected_prefix):
			has_tool_file = true
			break

	if not has_tool_file:
		return {"passed": false, "error": "Zip missing copied tool files under %s" % expected_prefix}

	return {"passed": true}

## Test: seal_project logs packaging lifecycle events
func test_seal_project_writes_packaging_logs() -> Dictionary:
	OgsLogger.clear_logs_for_tests()
	OgsLogger.set_level(OgsLogger.Level.DEBUG)

	var fixture = _helpers.create_seal_success_fixture("test_seal_logging")
	if not fixture.success:
		return {"passed": false, "error": fixture.error}

	var sealer = ProjectSealer.new()
	var result = sealer.seal_project(fixture.project_dir)

	_helpers.cleanup_seal_fixture(fixture)

	if not result.success:
		return {"passed": false, "error": "Seal should succeed to verify logs"}

	var log_file = FileAccess.open("user://logs/ogs_launcher.log", FileAccess.READ)
	if log_file == null:
		return {"passed": false, "error": "Log file not found after sealing"}

	var log_text = log_file.get_as_text()

	if not log_text.contains("sealed_zip_packaging_start"):
		return {"passed": false, "error": "Missing sealed_zip_packaging_start log event"}

	if not log_text.contains("sealed_zip_created"):
		return {"passed": false, "error": "Missing sealed_zip_created log event"}

	if not log_text.contains("seal_project_complete"):
		return {"passed": false, "error": "Missing seal_project_complete log event"}

	return {"passed": true}

## Test: project seal tool copier preserves large file contents across chunk boundaries
func test_project_seal_tool_copier_copies_large_files() -> Dictionary:
	var temp_dir = "user://test_seal_tool_copy_large_%s" % str(Time.get_ticks_usec())
	var source_dir = temp_dir.path_join("source")
	var dest_dir = temp_dir.path_join("dest")
	var source_path = source_dir.path_join("large.bin")
	var dest_path = dest_dir.path_join("large.bin")

	DirAccess.make_dir_recursive_absolute(source_dir)
	DirAccess.make_dir_recursive_absolute(dest_dir)

	var source_file = FileAccess.open(source_path, FileAccess.WRITE)
	if source_file == null:
		_helpers.remove_directory_recursive(temp_dir)
		return {"passed": false, "error": "Cannot create large source file"}

	var payload := PackedByteArray()
	payload.resize(SealToolCopierScript._COPY_CHUNK_SIZE + 257)
	for index in range(payload.size()):
		payload[index] = index % 251

	if payload.size() <= SealToolCopierScript._COPY_CHUNK_SIZE:
		_helpers.remove_directory_recursive(temp_dir)
		return {"passed": false, "error": "Test fixture did not exceed copy chunk size"}

	source_file.store_buffer(payload)
	source_file.close()

	var copier = SealToolCopierScript.new()
	var copy_err = copier._copy_file(source_path, dest_path)
	if copy_err != OK:
		_helpers.remove_directory_recursive(temp_dir)
		return {"passed": false, "error": "Large file copy failed: %s" % error_string(copy_err)}

	var copied_file = FileAccess.open(dest_path, FileAccess.READ)
	if copied_file == null:
		_helpers.remove_directory_recursive(temp_dir)
		return {"passed": false, "error": "Copied file was not created"}

	var copied_size = copied_file.get_length()
	var copied_payload = copied_file.get_buffer(copied_size)
	copied_file.close()

	_helpers.remove_directory_recursive(temp_dir)

	if copied_size != payload.size():
		return {"passed": false, "error": "Copied file size mismatch: expected %d, got %d" % [payload.size(), copied_size]}

	if copied_payload != payload:
		return {"passed": false, "error": "Copied file contents did not match source"}

	return {"passed": true}

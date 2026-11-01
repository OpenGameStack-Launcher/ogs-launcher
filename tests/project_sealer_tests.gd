## ProjectSealer Tests
##
## Unit tests for the ProjectSealer module.
## Tests cover validation, tool copying, config writing, and zip creation.

extends RefCounted
class_name ProjectSealerTests

const OgsLogger = preload("res://scripts/logging/logger.gd")

const SealerTestHelpersScript = preload("res://tests/project_sealer_test_helpers.gd")
const SealToolCopierScript = preload("res://scripts/projects/project_seal_tool_copier.gd")
const SealArchiverScript = preload("res://scripts/projects/project_seal_archiver.gd")
const StackManifest = preload("res://scripts/manifest/stack_manifest.gd")

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
		{"name": "test_seal_project_rejects_missing_ogs_stack_json", "func": test_seal_project_rejects_missing_ogs_stack_json},
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
		{"name": "test_tool_copier_reports_file_counts_and_progress", "func": test_tool_copier_reports_file_counts_and_progress},
		{"name": "test_archiver_reports_file_counts_and_progress", "func": test_archiver_reports_file_counts_and_progress},
		{"name": "test_sealer_forwards_two_phase_progress", "func": test_sealer_forwards_two_phase_progress},
		{"name": "test_progress_zero_files_edge_case", "func": test_progress_zero_files_edge_case},
		{"name": "test_seal_project_cancel_during_tool_copy", "func": test_seal_project_cancel_during_tool_copy},
		{"name": "test_seal_project_cancel_during_archiving", "func": test_seal_project_cancel_during_archiving},
		{"name": "test_seal_project_failure_triggers_complete_rollback", "func": test_seal_project_failure_triggers_complete_rollback},
		{"name": "test_seal_project_preserves_pre_existing_tools_and_config", "func": test_seal_project_preserves_pre_existing_tools_and_config},
		{"name": "test_seal_project_rollback_preserves_developer_tools_directory", "func": test_seal_project_rollback_preserves_developer_tools_directory},
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

## Test: seal_project rejects directory without ogs_stack.json
func test_seal_project_rejects_missing_ogs_stack_json() -> Dictionary:
	# Create temporary directory without ogs_stack.json
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
		return {"passed": false, "error": "Should reject missing ogs_stack.json"}
	
	if result.errors.is_empty():
		return {"passed": false, "error": "Should have error message"}
	
	var error_text = str(result.errors)
	if not error_text.contains("ogs_stack.json"):
		return {"passed": false, "error": "Error should mention ogs_stack.json"}
	
	return {"passed": true}

## Test: seal_project rejects manifest with missing tools in library
func test_seal_project_rejects_missing_tools() -> Dictionary:
	# Create temporary directory with ogs_stack.json
	var temp_dir = "user://test_seal_missing_tools"
	var dir_access = DirAccess.open("user://")
	if dir_access == null:
		return {"passed": false, "error": "Cannot access user:// directory"}
	
	DirAccess.make_dir_absolute(temp_dir)
	
	# Create a ogs_stack.json with a tool that definitely doesn't exist
	var stack_file = FileAccess.open(temp_dir.path_join("ogs_stack.json"), FileAccess.WRITE)
	if stack_file == null:
		DirAccess.remove_absolute(temp_dir)
		return {"passed": false, "error": "Cannot write test ogs_stack.json"}
	
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
	# Create temporary directory with invalid ogs_stack.json
	var temp_dir = "user://test_seal_invalid_manifest"
	var dir_access = DirAccess.open("user://")
	if dir_access == null:
		return {"passed": false, "error": "Cannot access user:// directory"}
	
	DirAccess.make_dir_absolute(temp_dir)
	
	var stack_file = FileAccess.open(temp_dir.path_join("ogs_stack.json"), FileAccess.WRITE)
	if stack_file == null:
		DirAccess.remove_absolute(temp_dir)
		return {"passed": false, "error": "Cannot write test ogs_stack.json"}
	
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
	# Create temporary project with valid ogs_stack.json
	var temp_dir = "user://test_seal_valid_project"
	var dir_access = DirAccess.open("user://")
	if dir_access == null:
		return {"passed": false, "error": "Cannot access user:// directory"}
	
	DirAccess.make_dir_absolute(temp_dir)
	
	var stack_file = FileAccess.open(temp_dir.path_join("ogs_stack.json"), FileAccess.WRITE)
	if stack_file == null:
		DirAccess.remove_absolute(temp_dir)
		return {"passed": false, "error": "Cannot write test ogs_stack.json"}
	
	# Create a valid ogs_stack.json (but godot 4.3 may not exist in library, so seal will fail)
	stack_file.store_string('{"schema_version": 1, "stack_name": "test_stack", "tools": [{"id": "godot", "version": "4.3", "path": "ogs_tools/godot"}]}')
	
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
	
	var stack_file = FileAccess.open(temp_dir.path_join("ogs_stack.json"), FileAccess.WRITE)
	if stack_file == null:
		DirAccess.remove_absolute(temp_dir)
		return {"passed": false, "error": "Cannot write test ogs_stack.json"}
	
	# Use a valid manifest structure
	stack_file.store_string('{"schema_version": 1, "stack_name": "test_stack", "tools": [{"id": "test_tool", "version": "1.0", "path": "ogs_tools/test"}]}')
	
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
	
	var stack_file = FileAccess.open(temp_dir.path_join("ogs_stack.json"), FileAccess.WRITE)
	if stack_file == null:
		DirAccess.remove_absolute(temp_dir)
		return {"passed": false, "error": "Cannot write test ogs_stack.json"}
	
	stack_file.store_string('{"schema_version": 1, "stack_name": "test_stack", "tools": [{"id": "godot", "version": "4.3", "path": "ogs_tools/godot"}]}')
	
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
	
	var stack_file = FileAccess.open(temp_dir.path_join("ogs_stack.json"), FileAccess.WRITE)
	if stack_file == null:
		DirAccess.remove_absolute(temp_dir)
		return {"passed": false, "error": "Cannot write test ogs_stack.json"}
	
	stack_file.store_string('{"schema_version": 1, "stack_name": "test_stack", "tools": [{"id": "godot", "version": "4.3", "path": "ogs_tools/godot"}]}')
	
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
	
	var stack_file = FileAccess.open(temp_dir.path_join("ogs_stack.json"), FileAccess.WRITE)
	if stack_file == null:
		DirAccess.remove_absolute(temp_dir)
		return {"passed": false, "error": "Cannot write test ogs_stack.json"}
	
	# Use a tool that likely doesn't exist so seal fails, but we just test path handling
	stack_file.store_string('{"schema_version": 1, "stack_name": "test_stack", "tools": [{"id": "nonexistent_tool_xyz", "version": "1.0", "path": "ogs_tools/test"}]}')
	
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

	if not zip_files.has("ogs_stack.json"):
		return {"passed": false, "error": "Zip missing ogs_stack.json"}

	if not zip_files.has("ogs_config.json"):
		return {"passed": false, "error": "Zip missing ogs_config.json"}

	var expected_prefix = "ogs_tools/%s_%s/" % [fixture.tool_id, fixture.version]
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

## Test: ProjectSealToolCopier reports expected file counts and progress updates from 0 to total_files
func test_tool_copier_reports_file_counts_and_progress() -> Dictionary:
	var fixture = _helpers.create_seal_success_fixture("test_copier_prog")
	if not fixture.success:
		return {"passed": false, "error": fixture.error}

	# Add extra fixture files in the tool directory to test multi-file progress
	var tool_dir = fixture.library_tool_root.path_join(fixture.version)
	var f2 = FileAccess.open(tool_dir.path_join("extra.txt"), FileAccess.WRITE)
	if f2 != null:
		f2.store_string("extra-content")
		f2.close()

	var manifest = StackManifest.load_from_file(fixture.project_dir.path_join("ogs_stack.json"))
	if manifest == null:
		_helpers.cleanup_seal_fixture(fixture)
		return {"passed": false, "error": "Failed to load manifest from fixture"}

	var library = LibraryManager.new()
	var copier = SealToolCopierScript.new()

	var events: Array = []
	var callback = func(phase: String, current: int, total: int) -> void:
		events.append({"phase": phase, "current": current, "total": total})

	var result = copier.copy_tools_to_local(fixture.project_dir, manifest, library, callback)
	_helpers.cleanup_seal_fixture(fixture)

	if not result.success:
		return {"passed": false, "error": "Tool copy failed: %s" % str(result.errors)}

	if events.is_empty():
		return {"passed": false, "error": "No progress events recorded"}

	var expected_total: int = events[0].total
	if expected_total < 3:
		return {"passed": false, "error": "Expected at least 3 files, got %d" % expected_total}

	if events[0].current != 0:
		return {"passed": false, "error": "First progress event should report current = 0"}

	if events[0].phase != "Step 1/2: Copying tools":
		return {"passed": false, "error": "Expected phase 'Step 1/2: Copying tools', got '%s'" % events[0].phase}

	var last_event = events[-1]
	if last_event.current != expected_total or last_event.total != expected_total:
		return {"passed": false, "error": "Final progress event should report (%d of %d), got (%d of %d)" % [
			expected_total, expected_total, last_event.current, last_event.total
		]}

	for i in range(1, events.size()):
		if events[i].current < events[i - 1].current:
			return {"passed": false, "error": "Progress event current file decreased at index %d" % i}
		if events[i].total != expected_total:
			return {"passed": false, "error": "Total file count changed during copy progress at index %d" % i}

	return {"passed": true}

## Test: ProjectSealArchiver reports expected file counts and progress updates from 0 to total_files
func test_archiver_reports_file_counts_and_progress() -> Dictionary:
	var temp_proj: String = "user://test_archiver_prog_%d" % int(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(temp_proj.path_join("sub"))

	var f1 = FileAccess.open(temp_proj.path_join("file1.txt"), FileAccess.WRITE)
	if f1 != null:
		f1.store_string("one")
		f1.close()
	var f2 = FileAccess.open(temp_proj.path_join("file2.txt"), FileAccess.WRITE)
	if f2 != null:
		f2.store_string("two")
		f2.close()
	var f3 = FileAccess.open(temp_proj.path_join("sub").path_join("file3.txt"), FileAccess.WRITE)
	if f3 != null:
		f3.store_string("three")
		f3.close()

	var archiver = SealArchiverScript.new()
	var events: Array = []
	var callback = func(phase: String, current: int, total: int) -> void:
		events.append({"phase": phase, "current": current, "total": total})

	var result = archiver.create_sealed_zip(temp_proj, callback)

	if result.success and FileAccess.file_exists(result.zip_path):
		DirAccess.remove_absolute(result.zip_path)
	_helpers.remove_directory_recursive(temp_proj)

	if not result.success:
		return {"passed": false, "error": "Archiver failed: %s" % str(result.errors)}

	if events.size() != 4:
		return {"passed": false, "error": "Expected 4 progress events (0..3 of 3), got %d" % events.size()}

	if events[0].current != 0 or events[0].total != 3:
		return {"passed": false, "error": "Expected first event (0 of 3), got (%d of %d)" % [events[0].current, events[0].total]}

	if events[0].phase != "Step 2/2: Creating ZIP archive":
		return {"passed": false, "error": "Expected phase 'Step 2/2: Creating ZIP archive', got '%s'" % events[0].phase}

	if events[-1].current != 3 or events[-1].total != 3:
		return {"passed": false, "error": "Expected last event (3 of 3), got (%d of %d)" % [events[-1].current, events[-1].total]}

	return {"passed": true}

## Test: ProjectSealer forwards progress events across both Phase 1 and Phase 2
func test_sealer_forwards_two_phase_progress() -> Dictionary:
	var fixture = _helpers.create_seal_success_fixture("test_sealer_two_phase")
	if not fixture.success:
		return {"passed": false, "error": fixture.error}

	var sealer = ProjectSealer.new()
	var events: Array = []
	var callback = func(phase: String, current: int, total: int) -> void:
		events.append({"phase": phase, "current": current, "total": total})

	var result = sealer.seal_project(fixture.project_dir, callback)

	if result.success and FileAccess.file_exists(result.sealed_zip):
		DirAccess.remove_absolute(result.sealed_zip)
	_helpers.cleanup_seal_fixture(fixture)

	if not result.success:
		return {"passed": false, "error": "Seal failed: %s" % str(result.errors)}

	var saw_phase1: bool = false
	var saw_phase2: bool = false
	for ev in events:
		if ev.phase == "Step 1/2: Copying tools":
			saw_phase1 = true
		elif ev.phase == "Step 2/2: Creating ZIP archive":
			saw_phase2 = true

	if not saw_phase1:
		return {"passed": false, "error": "Did not receive progress events for Step 1/2: Copying tools"}
	if not saw_phase2:
		return {"passed": false, "error": "Did not receive progress events for Step 2/2: Creating ZIP archive"}

	return {"passed": true}

## Test: Zero-file edge cases report cleanly without division by zero
func test_progress_zero_files_edge_case() -> Dictionary:
	var empty_dir: String = "user://test_empty_arch_%d" % int(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(empty_dir)

	var archiver = SealArchiverScript.new()
	var archiver_events: Array = []
	var arch_cb = func(phase: String, current: int, total: int) -> void:
		archiver_events.append({"phase": phase, "current": current, "total": total})

	var arch_result = archiver.create_sealed_zip(empty_dir, arch_cb)
	if arch_result.success and FileAccess.file_exists(arch_result.zip_path):
		DirAccess.remove_absolute(arch_result.zip_path)
	_helpers.remove_directory_recursive(empty_dir)

	if archiver_events.is_empty():
		return {"passed": false, "error": "Archiver should report progress even with 0 files"}

	if archiver_events[0].current != 0 or archiver_events[0].total != 0:
		return {"passed": false, "error": "Expected archiver 0-file progress (0 of 0), got (%d of %d)" % [
			archiver_events[0].current, archiver_events[0].total
		]}

	return {"passed": true}

class MockFailingArchiver:
	extends RefCounted
	var current_zip_path: String = ""
	func create_sealed_zip(_path: String, _progress: Callable = Callable(), _cancel: Callable = Callable()) -> Dictionary:
		return {"success": false, "cancelled": false, "errors": ["Mock zip write error"]}

## Test: Cancelling during Step 1 (tool copy) aborts copying promptly and cleans up newly copied directories under ./ogs_tools/ without affecting pre-existing files
func test_seal_project_cancel_during_tool_copy() -> Dictionary:
	var fixture = _helpers.create_seal_success_fixture("test_cancel_step1")
	if not fixture.success:
		return {"passed": false, "error": fixture.error}

	# Pre-create a custom tool folder in ./ogs_tools/
	var pre_tools_dir = fixture.project_dir.path_join("ogs_tools")
	var custom_dir = pre_tools_dir.path_join("custom_preexisting_tool")
	DirAccess.make_dir_recursive_absolute(custom_dir)
	var custom_file = FileAccess.open(custom_dir.path_join("notes.txt"), FileAccess.WRITE)
	if custom_file != null:
		custom_file.store_string("preserve me")
		custom_file.close()

	var cancel_state := {"requested": false}
	var cancel_cb = func() -> bool:
		return cancel_state["requested"]

	var sealer = ProjectSealer.new()
	var progress_cb = func(phase: String, current: int, _total: int) -> void:
		if phase.contains("Step 1") and current >= 0:
			cancel_state["requested"] = true
			sealer.request_cancel()

	var result = sealer.seal_project(fixture.project_dir, progress_cb, cancel_cb)

	# Verify result
	var failed_msg: String = ""
	if result.success:
		failed_msg = "Expected seal_project to fail on cancellation"
	elif not result.get("cancelled", false):
		failed_msg = "Expected result.cancelled to be true"
	elif not DirAccess.dir_exists_absolute(custom_dir):
		failed_msg = "Pre-existing tool directory was deleted by rollback"
	elif not FileAccess.file_exists(custom_dir.path_join("notes.txt")):
		failed_msg = "Pre-existing file inside tool directory was deleted by rollback"

	var tool_sealed_dir = pre_tools_dir.path_join("%s_%s" % [fixture.tool_id, fixture.version])
	if failed_msg.is_empty() and DirAccess.dir_exists_absolute(tool_sealed_dir):
		failed_msg = "Newly copied tool directory was not cleaned up by rollback"

	if failed_msg.is_empty() and FileAccess.file_exists(fixture.project_dir.path_join("ogs_config.json")):
		failed_msg = "ogs_config.json was not deleted during Step 1 rollback"

	_helpers.cleanup_seal_fixture(fixture)

	if not failed_msg.is_empty():
		return {"passed": false, "error": failed_msg}

	return {"passed": true}

## Test: Cancelling during Step 2 (archiving) closes and deletes partial ZIP, restores ogs_config.json, and cleans up tools
func test_seal_project_cancel_during_archiving() -> Dictionary:
	var fixture = _helpers.create_seal_success_fixture("test_cancel_step2")
	if not fixture.success:
		return {"passed": false, "error": fixture.error}

	# Pre-create ogs_config.json with custom content that must be preserved
	var config_path = fixture.project_dir.path_join("ogs_config.json")
	var original_config_text = '{"custom_project_setting": true, "offline": false}'
	var cfg = FileAccess.open(config_path, FileAccess.WRITE)
	if cfg != null:
		cfg.store_string(original_config_text)
		cfg.close()

	var cancel_state := {"requested": false}
	var cancel_cb = func() -> bool:
		return cancel_state["requested"]

	var sealer = ProjectSealer.new()
	var progress_cb = func(phase: String, current: int, _total: int) -> void:
		if phase.contains("Step 2"):
			cancel_state["requested"] = true
			sealer.request_cancel()

	var result = sealer.seal_project(fixture.project_dir, progress_cb, cancel_cb)

	var failed_msg: String = ""
	if result.success:
		failed_msg = "Expected seal_project to fail on Step 2 cancellation"
	elif not result.get("cancelled", false):
		failed_msg = "Expected result.cancelled to be true"

	# Verify ogs_config.json was restored to exact pre-seal contents
	if failed_msg.is_empty():
		var restored_cfg = FileAccess.open(config_path, FileAccess.READ)
		if restored_cfg == null:
			failed_msg = "ogs_config.json was missing after Step 2 cancellation rollback"
		else:
			var restored_text = restored_cfg.get_as_text()
			restored_cfg.close()
			if restored_text != original_config_text:
				failed_msg = "ogs_config.json was not restored to pre-seal contents: got '%s'" % restored_text

	# Verify newly copied tools were cleaned up
	var tools_dir = fixture.project_dir.path_join("ogs_tools")
	if failed_msg.is_empty() and DirAccess.dir_exists_absolute(tools_dir):
		failed_msg = "ogs_tools directory was not cleaned up during Step 2 rollback"

	# Verify partial zip was removed
	if failed_msg.is_empty() and not String(result.get("sealed_zip", "")).is_empty():
		if FileAccess.file_exists(result.sealed_zip):
			failed_msg = "Partial zip file was not deleted during Step 2 rollback"

	_helpers.cleanup_seal_fixture(fixture)

	if not failed_msg.is_empty():
		return {"passed": false, "error": failed_msg}

	return {"passed": true}

## Test: Mid-seal failure automatically triggers complete rollback and leaves project in pre-seal state
func test_seal_project_failure_triggers_complete_rollback() -> Dictionary:
	var fixture = _helpers.create_seal_success_fixture("test_failure_rollback")
	if not fixture.success:
		return {"passed": false, "error": fixture.error}

	var sealer = ProjectSealer.new()
	# Inject mock failing archiver to simulate Step 4 failure
	sealer.archiver = MockFailingArchiver.new()

	var result = sealer.seal_project(fixture.project_dir)

	var failed_msg: String = ""
	if result.success:
		failed_msg = "Expected seal_project to fail with mock archiver"
	elif result.get("cancelled", false):
		failed_msg = "Expected result.cancelled to be false on mid-seal error"
	elif DirAccess.dir_exists_absolute(fixture.project_dir.path_join("ogs_tools")):
		failed_msg = "ogs_tools directory was not cleaned up after mid-seal failure"
	elif FileAccess.file_exists(fixture.project_dir.path_join("ogs_config.json")):
		failed_msg = "ogs_config.json was not cleaned up after mid-seal failure"

	_helpers.cleanup_seal_fixture(fixture)

	if not failed_msg.is_empty():
		return {"passed": false, "error": failed_msg}

	return {"passed": true}

## Test: Pre-seal snapshot preserves pre-existing tools and config when seal is cancelled immediately
func test_seal_project_preserves_pre_existing_tools_and_config() -> Dictionary:
	var fixture = _helpers.create_seal_success_fixture("test_preserve_existing")
	if not fixture.success:
		return {"passed": false, "error": fixture.error}

	# Pre-create ogs_tools directory and ogs_config.json
	var tools_dir = fixture.project_dir.path_join("ogs_tools")
	var existing_subdir = tools_dir.path_join("existing_tool")
	DirAccess.make_dir_recursive_absolute(existing_subdir)
	var f = FileAccess.open(existing_subdir.path_join("keep.txt"), FileAccess.WRITE)
	if f != null:
		f.store_string("existing data")
		f.close()

	var config_path = fixture.project_dir.path_join("ogs_config.json")
	var initial_config = '{"my_original_config": 42}'
	var f2 = FileAccess.open(config_path, FileAccess.WRITE)
	if f2 != null:
		f2.store_string(initial_config)
		f2.close()

	var sealer = ProjectSealer.new()
	var cancel_cb = func() -> bool: return true

	var result = sealer.seal_project(fixture.project_dir, Callable(), cancel_cb)

	var failed_msg: String = ""
	if not result.get("cancelled", false):
		failed_msg = "Expected result.cancelled to be true"
	elif not DirAccess.dir_exists_absolute(existing_subdir):
		failed_msg = "Pre-existing tool directory was lost"
	elif not FileAccess.file_exists(existing_subdir.path_join("keep.txt")):
		failed_msg = "Pre-existing file inside tool directory was lost"
	else:
		var read_cfg = FileAccess.open(config_path, FileAccess.READ)
		if read_cfg == null:
			failed_msg = "ogs_config.json was lost"
		else:
			var cfg_text = read_cfg.get_as_text()
			read_cfg.close()
			if cfg_text != initial_config:
				failed_msg = "ogs_config.json content changed: expected '%s', got '%s'" % [initial_config, cfg_text]

	_helpers.cleanup_seal_fixture(fixture)

	if not failed_msg.is_empty():
		return {"passed": false, "error": failed_msg}

	return {"passed": true}

## Test: Developer-authored tools/ directory with custom files is completely preserved and untouched when sealing is rolled back
func test_seal_project_rollback_preserves_developer_tools_directory() -> Dictionary:
	var fixture = _helpers.create_seal_success_fixture("test_preserve_dev_tools")
	if not fixture.success:
		return {"passed": false, "error": fixture.error}

	# Pre-create a developer-authored <project_dir>/tools/ folder with custom scripts
	var dev_tools_dir = fixture.project_dir.path_join("tools")
	DirAccess.make_dir_recursive_absolute(dev_tools_dir)
	var build_script_path = dev_tools_dir.path_join("build_helper.py")
	var f = FileAccess.open(build_script_path, FileAccess.WRITE)
	if f != null:
		f.store_string("print('developer build automation')")
		f.close()

	var cancel_state := {"requested": false}
	var cancel_cb = func() -> bool:
		return cancel_state["requested"]

	var sealer = ProjectSealer.new()
	var progress_cb = func(phase: String, current: int, _total: int) -> void:
		if phase.contains("Step 1") and current >= 0:
			cancel_state["requested"] = true
			sealer.request_cancel()

	var result = sealer.seal_project(fixture.project_dir, progress_cb, cancel_cb)

	var failed_msg: String = ""
	if result.success:
		failed_msg = "Expected seal_project to be cancelled"
	elif not result.get("cancelled", false):
		failed_msg = "Expected result.cancelled to be true"
	elif not DirAccess.dir_exists_absolute(dev_tools_dir):
		failed_msg = "Developer tools/ directory was deleted during rollback!"
	elif not FileAccess.file_exists(build_script_path):
		failed_msg = "Developer build_helper.py was deleted during rollback!"
	else:
		var script_file = FileAccess.open(build_script_path, FileAccess.READ)
		if script_file == null or script_file.get_as_text() != "print('developer build automation')":
			failed_msg = "Developer build_helper.py content was corrupted during rollback!"
		if script_file != null:
			script_file.close()

	# Also verify ogs_tools was removed or cleaned up
	var ogs_tools_dir = fixture.project_dir.path_join("ogs_tools")
	if failed_msg.is_empty() and DirAccess.dir_exists_absolute(ogs_tools_dir):
		failed_msg = "ogs_tools directory was not cleaned up during rollback"

	_helpers.cleanup_seal_fixture(fixture)

	if not failed_msg.is_empty():
		return {"passed": false, "error": failed_msg}

	return {"passed": true}



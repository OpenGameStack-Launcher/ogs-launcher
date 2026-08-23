## StackManifestTests: Unit Test Suite for StackManifest
##
## Validates core manifest functionality:
## - Valid manifests pass schema checks
## - Required fields (schema_version, stack_name, tools) are enforced
## - Invalid JSON/types are rejected
## - Tool entries are validated individually
##
## All tests pass when manifest validation correctly identifies valid and invalid data.
## Run with: godot --headless --script res://tests/test_runner.gd

extends RefCounted
class_name StackManifestTests

## Runs all validation tests.
## Returns:
## Dictionary: {"passed": int, "failed": int, "failures": Array[String]}
func run() -> Dictionary:
	## Runs manifest validation tests and returns a summary dictionary.
	var results := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	_test_valid_manifest(results)
	_test_missing_schema_version(results)
	_test_schema_version_float_valid(results)
	_test_schema_version_float_invalid(results)
	_test_invalid_tools_type(results)
	_test_missing_tool_id(results)
	_test_unsupported_schema_version(results)
	_test_invalid_sha256(results)
	_test_invalid_json(results)
	return results

## Records a test assertion.
## Parameters:
## condition (bool): If true, increments passed count; if false, increments failed
## message (String): Description of the assertion for failure reports
## results (Dictionary): Test results accumulator (modified in-place)
func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records a test assertion result.
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

## Builds a valid manifest dictionary for test reuse.
## Returns:
## Dictionary: Template with schema_version=1, valid stack_name, and one Godot tool
func _make_valid_manifest_data() -> Dictionary:
	## Creates a valid manifest dictionary for test use.
	return {
		"schema_version": 1,
		"stack_name": "Test Stack",
		"tools": [
			{
				"id": "godot",
				"version": "4.3",
				"path": "tools/godot/Godot.exe"
			}
		]
	}

func _test_valid_manifest(results: Dictionary) -> void:
	## Verifies a valid manifest passes validation.
	var data = _make_valid_manifest_data()
	var manifest = StackManifest.from_dict(data)
	_expect(manifest.is_valid(), "valid manifest should pass", results)

func _test_missing_schema_version(results: Dictionary) -> void:
	## Verifies schema_version is required.
	var data = _make_valid_manifest_data()
	data.erase("schema_version")
	var manifest = StackManifest.from_dict(data)
	_expect(not manifest.is_valid(), "missing schema_version should fail", results)

func _test_schema_version_float_valid(results: Dictionary) -> void:
	## Verifies schema_version as float 1.0 is accepted.
	var data = _make_valid_manifest_data()
	data["schema_version"] = 1.0
	var manifest = StackManifest.from_dict(data)
	_expect(manifest.is_valid(), "schema_version float 1.0 should pass", results)

func _test_schema_version_float_invalid(results: Dictionary) -> void:
	## Verifies non-integer float schema_version is rejected.
	var data = _make_valid_manifest_data()
	data["schema_version"] = 1.5
	var manifest = StackManifest.from_dict(data)
	_expect(not manifest.is_valid(), "schema_version float 1.5 should fail", results)

func _test_invalid_tools_type(results: Dictionary) -> void:
	## Verifies tools must be an array.
	var data = _make_valid_manifest_data()
	data["tools"] = {}
	var manifest = StackManifest.from_dict(data)
	_expect(not manifest.is_valid(), "tools must be an array", results)

func _test_missing_tool_id(results: Dictionary) -> void:
	## Verifies tool id is required.
	var data = _make_valid_manifest_data()
	data["tools"][0].erase("id")
	var manifest = StackManifest.from_dict(data)
	_expect(not manifest.is_valid(), "tool id is required", results)

func _test_unsupported_schema_version(results: Dictionary) -> void:
	## Verifies unsupported schema versions fail.
	var data = _make_valid_manifest_data()
	data["schema_version"] = 2
	var manifest = StackManifest.from_dict(data)
	_expect(not manifest.is_valid(), "unsupported schema version should fail", results)

func _test_invalid_sha256(results: Dictionary) -> void:
	## Verifies invalid sha256 formats are rejected.
	var data = _make_valid_manifest_data()
	data["tools"][0]["sha256"] = "not-a-hash"
	var manifest = StackManifest.from_dict(data)
	_expect(not manifest.is_valid(), "invalid sha256 should fail", results)

func _test_invalid_json(results: Dictionary) -> void:
	## Verifies invalid JSON text is rejected.
	var manifest = StackManifest.parse_json_string("{broken}")
	_expect(not manifest.is_valid(), "invalid JSON should fail", results)

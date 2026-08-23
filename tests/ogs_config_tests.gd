## OgsConfigTests: Unit Test Suite for OgsConfig
##
## Validates config loading and offline mode detection:
## - Valid config loads correctly
## - Missing files return defaults (no error)
## - Invalid JSON is rejected
## - Invalid field types are caught
##
## Run with: godot --headless --script res://tests/test_runner.gd

extends RefCounted
class_name OgsConfigTests

var ogs_config_class = preload("res://scripts/config/ogs_config.gd")

func run() -> Dictionary:
	## Runs all config validation tests.
## Returns:
## Dictionary: {\"passed\": int, \"failed\": int, \"failures\": Array[String]}
	var results := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	_test_valid_offline_mode(results)
	_test_valid_force_offline(results)
	_test_schema_version_float_valid(results)
	_test_schema_version_float_invalid(results)
	_test_missing_file_returns_defaults(results)
	_test_invalid_json(results)
	_test_invalid_field_types(results)
	_test_allowlist_fields(results)
	_test_allowlist_field_validation(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records test assertion.
## Parameters:
## condition (bool): If true, increments passed; if false, increments failed
## message (String): Failure description
## results (Dictionary): Test accumulator (modified in-place)
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _make_valid_config_data() -> Dictionary:
	## Creates a minimal valid config dictionary.
## Returns:
## Dictionary: {\"schema_version\": 1, \"offline_mode\": false, \"force_offline\": false}
	return {
		"schema_version": 1,
		"offline_mode": false,
		"force_offline": false
	}

func _test_valid_offline_mode(results: Dictionary) -> void:
	## Verifies config with offline_mode=true loads and is_offline() returns true.
	var data = _make_valid_config_data()
	data["offline_mode"] = true
	var config = ogs_config_class.from_dict(data)
	_expect(config.is_valid(), "valid config should pass validation", results)
	_expect(config.offline_mode, "offline_mode should be true", results)
	_expect(config.is_offline(), "is_offline() should be true when offline_mode=true", results)

func _test_valid_force_offline(results: Dictionary) -> void:
	## Verifies config with force_offline=true loads and is_offline() returns true.
	var data = _make_valid_config_data()
	data["force_offline"] = true
	var config = ogs_config_class.from_dict(data)
	_expect(config.is_valid(), "valid config should pass validation", results)
	_expect(config.force_offline, "force_offline should be true", results)
	_expect(config.is_offline(), "is_offline() should be true when force_offline=true", results)

func _test_schema_version_float_valid(results: Dictionary) -> void:
	## Verifies schema_version float 1.0 is accepted.
	var data = _make_valid_config_data()
	data["schema_version"] = 1.0
	var config = ogs_config_class.from_dict(data)
	_expect(config.is_valid(), "schema_version float 1.0 should pass", results)

func _test_schema_version_float_invalid(results: Dictionary) -> void:
	## Verifies non-integer float schema_version is rejected.
	var data = _make_valid_config_data()
	data["schema_version"] = 1.5
	var config = ogs_config_class.from_dict(data)
	_expect(not config.is_valid(), "schema_version float 1.5 should fail", results)

func _test_missing_file_returns_defaults(results: Dictionary) -> void:
	## Verifies missing config file returns defaults without error.
	var config = ogs_config_class.load_from_file("res://nonexistent_ogs_config.json")
	_expect(config.is_valid(), "missing file should not error", results)
	_expect(not config.offline_mode, "offline_mode should default to false", results)
	_expect(not config.force_offline, "force_offline should default to false", results)
	_expect(not config.is_offline(), "is_offline() should be false by default", results)

func _test_invalid_json(results: Dictionary) -> void:
	## Verifies invalid JSON is rejected.
	var config = ogs_config_class.parse_json_string("{broken}")
	_expect(not config.is_valid(), "invalid JSON should fail validation", results)

func _test_invalid_field_types(results: Dictionary) -> void:
	## Verifies non-boolean offline_mode/force_offline are rejected.
	var data = _make_valid_config_data()
	data["offline_mode"] = "true"  # String instead of bool
	var config = ogs_config_class.from_dict(data)
	_expect(not config.is_valid(), "offline_mode must be boolean", results)
	
	data = _make_valid_config_data()
	data["force_offline"] = 1  # Int instead of bool
	config = ogs_config_class.from_dict(data)
	_expect(not config.is_valid(), "force_offline must be boolean", results)

func _test_allowlist_fields(results: Dictionary) -> void:
	## Verifies allowlist fields load and serialize correctly.
	var data = _make_valid_config_data()
	data["allowed_hosts"] = ["Example.com", " localhost "]
	data["allowed_ports"] = [443, 8080]
	var config = ogs_config_class.from_dict(data)
	_expect(config.is_valid(), "allowlist arrays should validate", results)
	_expect(config.allowed_hosts == ["example.com", "localhost"], "allowed_hosts should normalize and persist", results)
	_expect(config.allowed_ports == [443, 8080], "allowed_ports should persist", results)
	var serialized = config.to_dict()
	_expect(serialized.get("allowed_hosts", []) == ["example.com", "localhost"], "to_dict should include allowed_hosts", results)
	_expect(serialized.get("allowed_ports", []) == [443, 8080], "to_dict should include allowed_ports", results)

func _test_allowlist_field_validation(results: Dictionary) -> void:
	## Verifies allowlist fields reject invalid types and ranges.
	var data = _make_valid_config_data()
	data["allowed_hosts"] = ["ok", 123]
	var config = ogs_config_class.from_dict(data)
	_expect(not config.is_valid(), "allowed_hosts must contain only strings", results)

	data = _make_valid_config_data()
	data["allowed_ports"] = [443, "8080"]
	config = ogs_config_class.from_dict(data)
	_expect(not config.is_valid(), "allowed_ports must contain only integers", results)

	data = _make_valid_config_data()
	data["allowed_ports"] = [0]
	config = ogs_config_class.from_dict(data)
	_expect(not config.is_valid(), "allowed_ports must be in range 1-65535", results)

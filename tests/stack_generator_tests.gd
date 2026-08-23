## StackGeneratorTests: Unit Test Suite for StackGenerator
##
## Validates manifest generation and serialization:
## - Default manifest contains standard tools
## - JSON pretty/compact formatting behavior
## - save_to_file() writes and returns true

extends RefCounted
class_name StackGeneratorTests

func run() -> Dictionary:
	## Runs all StackGenerator tests.
## Returns:
## Dictionary: {"passed": int, "failed": int, "failures": Array[String]}
	var results := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	_test_create_default(results)
	_test_json_formatting(results)
	_test_save_to_file(results)
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

func _test_create_default(results: Dictionary) -> void:
	## Verifies create_default returns a manifest with standard tools.
	var manifest = StackGenerator.create_default()
	_expect(manifest.stack_name == "OGS Standard Profile", "default stack name should match", results)
	_expect(manifest.tools.size() >= 4, "default manifest should include standard tools", results)

func _test_json_formatting(results: Dictionary) -> void:
	## Verifies pretty and compact JSON formatting behaviors.
	var manifest = StackGenerator.create_default()
	var pretty_json = StackGenerator.to_json_string(manifest, true)
	var compact_json = StackGenerator.to_json_string(manifest, false)
	_expect(pretty_json.find("\n") != -1, "pretty JSON should include newlines", results)
	_expect(pretty_json.find("\t") != -1, "pretty JSON should include tabs", results)
	_expect(compact_json.find("\n") == -1, "compact JSON should not include newlines", results)

func _test_save_to_file(results: Dictionary) -> void:
	## Verifies save_to_file writes a manifest to disk.
	var manifest = StackGenerator.create_default()
	var path = "user://stack_generator_test.json"
	var ok = StackGenerator.save_to_file(manifest, path)
	_expect(ok, "save_to_file should return true", results)
	_expect(FileAccess.file_exists(path), "saved manifest should exist", results)

	var file = FileAccess.open(path, FileAccess.READ)
	if file != null:
		var text = file.get_as_text()
		file.close()
		_expect(text.find("\"stack_name\"") != -1, "saved manifest should contain stack_name", results)
	else:
		_expect(false, "saved manifest should be readable", results)

	var dir = DirAccess.open("user://")
	if dir:
		dir.remove("stack_generator_test.json")

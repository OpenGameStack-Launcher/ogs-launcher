## ToolConfigInjectorTests: Unit tests for tool config injection.

extends RefCounted
class_name ToolConfigInjectorTests

func run() -> Dictionary:
	## Runs ToolConfigInjector unit tests.
## Returns:
## Dictionary: {"passed": int, "failed": int, "failures": Array[String]}
	var results := {"passed": 0, "failed": 0, "failures": []}
	_test_blender_args(results)
	_test_godot_settings_written(results)
	_test_krita_placeholder(results)
	_test_audacity_placeholder(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records test assertions.
## Parameters:
## condition (bool): Pass/fail condition
## message (String): Failure message
## results (Dictionary): Aggregated results
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_blender_args(results: Dictionary) -> void:
	## Verifies Blender offline args include python expression.
	var result = ToolConfigInjector.apply("blender", "res://")
	_expect(result["success"], "blender injection should succeed", results)
	var args: PackedStringArray = result["args"]
	_expect(args.size() == 2, "blender args should include --python-expr and script", results)
	_expect(args[0] == "--python-expr", "first arg should be --python-expr", results)

func _test_godot_settings_written(results: Dictionary) -> void:
	## Verifies Godot override.cfg and profile are written with offline overrides.
	var test_dir = "user://test_injector_godot"
	DirAccess.make_dir_recursive_absolute(test_dir)
	var result = ToolConfigInjector.apply("godot", test_dir)
	_expect(result["success"], "godot injection should succeed", results)
	var override_path = test_dir.path_join("override.cfg")
	var config = ConfigFile.new()
	var load_err = config.load(override_path)
	_expect(load_err == OK, "override.cfg should exist and load successfully", results)
	_expect(config.get_value("editor", "feature_profile", "") == "res://.ogs_offline.profile", "editor/feature_profile should be set", results)
	var profile_path = test_dir.path_join(".ogs_offline.profile")
	_expect(FileAccess.file_exists(profile_path), "offline profile should exist", results)

func _test_krita_placeholder(results: Dictionary) -> void:
	## Verifies Krita placeholder override file and env flag are set.
	var result = ToolConfigInjector.apply("krita", "res://")
	_expect(result["success"], "krita injection should succeed", results)
	var file_path = "user://ogs_offline_overrides/krita.json"
	_expect(FileAccess.file_exists(file_path), "krita override file should exist", results)
	_expect(OS.get_environment("OGS_OFFLINE_TOOL_KRITA") == "1", "krita env flag should be set", results)
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var payload = JSON.parse_string(file.get_as_text())
		file.close()
		_expect(payload.has("project_id"), "krita override should include project_id", results)
		_expect(not payload.has("project_dir"), "krita override should not include project_dir", results)

func _test_audacity_placeholder(results: Dictionary) -> void:
	## Verifies Audacity placeholder override file and env flag are set.
	var result = ToolConfigInjector.apply("audacity", "res://")
	_expect(result["success"], "audacity injection should succeed", results)
	var file_path = "user://ogs_offline_overrides/audacity.json"
	_expect(FileAccess.file_exists(file_path), "audacity override file should exist", results)
	_expect(OS.get_environment("OGS_OFFLINE_TOOL_AUDACITY") == "1", "audacity env flag should be set", results)
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var payload = JSON.parse_string(file.get_as_text())
		file.close()
		_expect(payload.has("project_id"), "audacity override should include project_id", results)
		_expect(not payload.has("project_dir"), "audacity override should not include project_dir", results)

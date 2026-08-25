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
	## Verifies Godot offline editor settings are written under the launched project and cleaned up.
	var test_dir = "user://test_injector_godot_%s" % str(Time.get_ticks_msec())
	var launch_project_dir = test_dir.path_join("project_source")
	var absolute_launch_project_dir = ProjectSettings.globalize_path(launch_project_dir)
	DirAccess.make_dir_recursive_absolute(absolute_launch_project_dir)
	var project_file = FileAccess.open(launch_project_dir.path_join("project.godot"), FileAccess.WRITE)
	if project_file != null:
		project_file.store_string("[application]\nconfig/name=\"ToolConfigInjectorTests\"\n")
		project_file.close()
	var existing_override = FileAccess.open(launch_project_dir.path_join("override.cfg"), FileAccess.WRITE)
	if existing_override != null:
		existing_override.store_string("[application]\nconfig/name=\"PreserveOverride\"\n")
		existing_override.close()
	var existing_profile = FileAccess.open(launch_project_dir.path_join(".ogs_offline.profile"), FileAccess.WRITE)
	if existing_profile != null:
		existing_profile.store_string("preexisting profile")
		existing_profile.close()
	var result = ToolConfigInjector.apply("godot", test_dir, launch_project_dir)
	_expect(result["success"], "godot injection should succeed", results)
	var args: PackedStringArray = result["args"]
	_expect(args.size() == 2, "godot injection should provide editor settings args", results)
	_expect(args[0] == "--editor-settings", "first godot offline arg should be --editor-settings", results)
	var settings_path = absolute_launch_project_dir.path_join(".ogs_offline_editor_settings").path_join("editor_settings-4.tres")
	_expect(args[1] == settings_path, "second godot offline arg should be absolute editor settings file path", results)
	var config = ConfigFile.new()
	var load_err = config.load(settings_path)
	_expect(load_err == OK, "editor settings should exist and load successfully", results)
	_expect(config.get_value("asset_library", "use_threads", true) == false, "asset_library/use_threads should be false", results)
	_expect(int(config.get_value("network/debug", "bandwidth_limiter", 1)) == 0, "network/debug/bandwidth_limiter should be 0", results)
	_expect(config.get_value("network/http_proxy", "enabled", true) == false, "network/http_proxy/enabled should be false", results)
	_expect(config.get_value("network/http_proxy", "host", "proxy") == "", "network/http_proxy/host should be empty", results)
	_expect(int(config.get_value("network/http_proxy", "port", 1)) == 0, "network/http_proxy/port should be 0", results)
	var preserved_override = FileAccess.open(launch_project_dir.path_join("override.cfg"), FileAccess.READ)
	if preserved_override != null:
		_expect(preserved_override.get_as_text().contains("PreserveOverride"), "existing override.cfg should be preserved", results)
		preserved_override.close()
	else:
		_expect(false, "existing override.cfg should remain readable", results)
	var preserved_profile = FileAccess.open(launch_project_dir.path_join(".ogs_offline.profile"), FileAccess.READ)
	if preserved_profile != null:
		_expect(preserved_profile.get_as_text() == "preexisting profile", "existing offline profile should be preserved", results)
		preserved_profile.close()
	else:
		_expect(false, "existing offline profile should remain readable", results)
	ToolConfigInjector.clear("godot", launch_project_dir)
	_expect(not FileAccess.file_exists(settings_path), "editor settings should be removed when offline cleanup runs", results)
	_expect(FileAccess.file_exists(launch_project_dir.path_join("override.cfg")), "cleanup should not remove existing override.cfg", results)
	_expect(FileAccess.file_exists(launch_project_dir.path_join(".ogs_offline.profile")), "cleanup should not remove existing offline profile", results)
	_cleanup_dir(test_dir)

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
	ToolConfigInjector.clear("krita", "res://")
	_expect(OS.get_environment("OGS_OFFLINE_TOOL_KRITA") == "", "krita env flag should clear on cleanup", results)
	_expect(not FileAccess.file_exists(file_path), "krita override file should be removed on cleanup", results)

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
	ToolConfigInjector.clear("audacity", "res://")
	_expect(OS.get_environment("OGS_OFFLINE_TOOL_AUDACITY") == "", "audacity env flag should clear on cleanup", results)
	_expect(not FileAccess.file_exists(file_path), "audacity override file should be removed on cleanup", results)

func _cleanup_dir(path: String) -> void:
	## Recursively removes temporary test directories created for injector fixtures.
	var absolute_path = ProjectSettings.globalize_path(path) if path.begins_with("user://") else path
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	var dir = DirAccess.open(absolute_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full_path = absolute_path.path_join(entry)
		var is_directory = dir.current_is_dir()
		if is_directory:
			_cleanup_dir(full_path)
		else:
			DirAccess.remove_absolute(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)

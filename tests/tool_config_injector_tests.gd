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
	## Verifies Godot offline editor settings preserve global preferences, enforce offline keys, and clean up cache artifacts.
	var test_dir = "user://test_injector_godot_%s" % str(Time.get_ticks_msec())
	var launch_project_dir = test_dir.path_join("project_source")
	var absolute_launch_project_dir = ProjectSettings.globalize_path(launch_project_dir)
	DirAccess.make_dir_recursive_absolute(absolute_launch_project_dir)
	var project_file = FileAccess.open(launch_project_dir.path_join("project.godot"), FileAccess.WRITE)
	if project_file != null:
		project_file.store_string("[application]\nconfig/name=\"ToolConfigInjectorTests\"\n")
		project_file.close()
	var existing_profile = FileAccess.open(launch_project_dir.path_join(".ogs_offline.profile"), FileAccess.WRITE)
	if existing_profile != null:
		existing_profile.store_string("preexisting profile")
		existing_profile.close()
	var seed_settings_path = launch_project_dir.path_join("seed_editor_settings-4.tres")
	var sentinel_seed_settings_text = "[gd_resource type=\"EditorSettings\" format=3]\n\n[resource]\ninterface/editor/editor_language = \"fr\"\n"
	var seed_settings_file = FileAccess.open(seed_settings_path, FileAccess.WRITE)
	_expect(seed_settings_file != null, "seed editor settings fixture should be writable", results)
	if seed_settings_file != null:
		seed_settings_file.store_string(sentinel_seed_settings_text)
		seed_settings_file.close()
	var global_settings_path = "user://editor_settings-4.tres"
	var had_global_settings = FileAccess.file_exists(global_settings_path)
	var original_global_settings_text = ""
	if had_global_settings:
		var existing_global_settings = FileAccess.open(global_settings_path, FileAccess.READ)
		_expect(existing_global_settings != null, "existing global editor settings should be readable", results)
		if existing_global_settings != null:
			original_global_settings_text = existing_global_settings.get_as_text()
			existing_global_settings.close()
	var previous_seed_env = OS.get_environment(ToolConfigInjector.GODOT_EDITOR_SETTINGS_SEED_ENV)
	OS.set_environment(ToolConfigInjector.GODOT_EDITOR_SETTINGS_SEED_ENV, seed_settings_path)
	var result = ToolConfigInjector.apply("godot", test_dir, launch_project_dir)
	OS.set_environment(ToolConfigInjector.GODOT_EDITOR_SETTINGS_SEED_ENV, previous_seed_env)
	_expect(result["success"], "godot injection should succeed", results)
	var args: PackedStringArray = result["args"]
	_expect(args.size() == 2, "godot injection should provide editor settings args", results)
	_expect(args[0] == "--editor-settings", "first godot offline arg should be --editor-settings", results)
	var project_hash = ToolConfigInjector._hash_project_id(absolute_launch_project_dir)
	var cache_dir = ProjectSettings.globalize_path("user://ogs_offline_godot").path_join(project_hash)
	var settings_path = cache_dir.path_join("editor_settings-4.tres")
	var profile_path = cache_dir.path_join(".ogs_offline.profile")
	_expect(args[1] == settings_path, "second godot offline arg should be absolute editor settings file path", results)
	var settings_file = FileAccess.open(settings_path, FileAccess.READ)
	if settings_file != null:
		var settings_text = settings_file.get_as_text()
		settings_file.close()
		_expect(settings_text.contains("[gd_resource type=\"EditorSettings\""), "editor settings should use Godot resource format", results)
		_expect(settings_text.contains("asset_library/use_threads = false"), "editor settings should disable asset library threading", results)
		_expect(settings_text.contains("network/debug/bandwidth_limiter = 0"), "editor settings should disable bandwidth limiting", results)
		_expect(settings_text.contains("network/http_proxy/enabled = false"), "editor settings should disable HTTP proxy", results)
		_expect(settings_text.contains("network/http_proxy/host = \"\""), "editor settings should clear HTTP proxy host", results)
		_expect(settings_text.contains("network/http_proxy/port = 0"), "editor settings should clear HTTP proxy port", results)
		_expect(settings_text.contains("_default_feature_profile"), "editor settings should activate offline feature profile", results)
		_expect(settings_text.contains(profile_path.c_escape()), "editor settings should reference generated offline profile path", results)
		_expect(settings_text.contains("interface/editor/editor_language = \"fr\""), "seeded editor settings should preserve existing preferences", results)
	else:
		_expect(false, "editor settings should exist and be readable", results)
	var unchanged_global_settings = FileAccess.open(global_settings_path, FileAccess.READ)
	if had_global_settings:
		if unchanged_global_settings != null:
			_expect(unchanged_global_settings.get_as_text() == original_global_settings_text, "global editor settings should remain unchanged after apply", results)
			unchanged_global_settings.close()
		else:
			_expect(false, "global editor settings should remain readable after apply", results)
	else:
		_expect(unchanged_global_settings == null, "global editor settings should not be created by apply", results)
	var profile = EditorFeatureProfile.new()
	_expect(profile.load_from_file(profile_path) == OK, "offline profile should load through Godot's feature profile loader", results)
	_expect(profile.is_feature_disabled(EditorFeatureProfile.FEATURE_ASSET_LIB), "offline profile should disable asset_lib", results)
	var preserved_profile = FileAccess.open(launch_project_dir.path_join(".ogs_offline.profile"), FileAccess.READ)
	if preserved_profile != null:
		_expect(preserved_profile.get_as_text() == "preexisting profile", "existing offline profile should be preserved", results)
		preserved_profile.close()
	else:
		_expect(false, "existing offline profile should remain readable", results)
	ToolConfigInjector.clear("godot", launch_project_dir)
	_expect(not FileAccess.file_exists(settings_path), "editor settings should be removed when offline cleanup runs", results)
	_expect(not FileAccess.file_exists(profile_path), "offline profile should be removed when offline cleanup runs", results)
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

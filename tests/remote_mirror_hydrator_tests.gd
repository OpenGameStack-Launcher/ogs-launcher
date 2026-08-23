## RemoteMirrorHydratorTests: Unit tests for remote mirror hydration behavior.

extends RefCounted
class_name RemoteMirrorHydratorTests

const RemoteMirrorHydratorScript = preload("res://scripts/mirror/remote_mirror_hydrator.gd")

func run() -> Dictionary:
	## Runs RemoteMirrorHydrator unit tests.
	var results = {"passed": 0, "failed": 0, "failures": []}
	_cleanup_library()
	_test_missing_repository_url(results)
	_test_invalid_repository_json(results)
	_test_missing_archive_file(results)
	_cleanup_library()
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records test assertions.
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_missing_repository_url(results: Dictionary) -> void:
	## Hydration should fail when repository_url is missing.
	OfflineEnforcer.reset()
	var hydrator = RemoteMirrorHydratorScript.new("")
	var result = hydrator.hydrate([
		{"tool_id": "godot", "version": "4.3"}
	])
	_expect(result["success"] == false, "should fail without repository_url", results)

func _test_invalid_repository_json(results: Dictionary) -> void:
	## Hydration should fail when repository.json is invalid.
	OfflineEnforcer.reset()
	var temp_root = OS.get_user_data_dir().path_join("remote_repo_invalid")
	if not DirAccess.dir_exists_absolute(temp_root):
		DirAccess.make_dir_recursive_absolute(temp_root)
	var repo_path = temp_root.path_join("repository.json")
	var file = FileAccess.open(repo_path, FileAccess.WRITE)
	if file:
		file.store_string("not-json")
		file.close()

	var hydrator = RemoteMirrorHydratorScript.new(repo_path)
	var result = hydrator.hydrate([
		{"tool_id": "godot", "version": "4.3"}
	])
	_expect(result["success"] == false, "should fail on invalid repository json", results)

	if FileAccess.file_exists(repo_path):
		DirAccess.remove_absolute(repo_path)
	if DirAccess.dir_exists_absolute(temp_root):
		DirAccess.remove_absolute(temp_root)

func _test_missing_archive_file(results: Dictionary) -> void:
	## Hydration should fail when archive_url points to a missing local file.
	OfflineEnforcer.reset()
	var temp_root = OS.get_user_data_dir().path_join("remote_repo_missing_archive")
	if not DirAccess.dir_exists_absolute(temp_root):
		DirAccess.make_dir_recursive_absolute(temp_root)
	var repo_path = temp_root.path_join("repository.json")
	var missing_archive = temp_root.path_join("missing_archive.zip")
	var repo_json = {
		"schema_version": 1,
		"mirror_name": "OGS Remote",
		"tools": [
			{
				"id": "godot",
				"version": "4.3",
				"archive_url": missing_archive,
				"sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
			}
		]
	}
	var file = FileAccess.open(repo_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(repo_json))
		file.close()

	var hydrator = RemoteMirrorHydratorScript.new(repo_path)
	var result = hydrator.hydrate([
		{"tool_id": "godot", "version": "4.3"}
	])
	_expect(result["success"] == false, "should fail when archive file is missing", results)
	_expect(result["failed_count"] == 1, "failed_count should be 1 when archive missing", results)

	if FileAccess.file_exists(repo_path):
		DirAccess.remove_absolute(repo_path)
	if DirAccess.dir_exists_absolute(temp_root):
		DirAccess.remove_absolute(temp_root)

func _cleanup_library() -> void:
	## Removes test tool directories from the library.
	var appdata = OS.get_environment("LOCALAPPDATA")
	if appdata.is_empty():
		appdata = OS.get_user_data_dir()
	# Use test-isolated library path set by test_runner
	var library_root = appdata.path_join("OGS_TEST").path_join("Library")
	if DirAccess.dir_exists_absolute(library_root):
		for tool_id in ["godot", "blender", "krita", "audacity"]:
			var tool_dir = library_root.path_join(tool_id)
			if DirAccess.dir_exists_absolute(tool_dir):
				_recursive_remove_dir(tool_dir)

func _recursive_remove_dir(path: String) -> void:
	## Recursively removes a directory and all its contents.
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = path.path_join(file_name)
			if dir.current_is_dir():
				_recursive_remove_dir(full_path)
			else:
				DirAccess.remove_absolute(full_path)
			file_name = dir.get_next()
	DirAccess.remove_absolute(path)

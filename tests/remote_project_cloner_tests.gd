## RemoteProjectClonerTests: Unit tests for RemoteProjectCloner service.
##
## Validates URL filtering, anti-injection flags, slug extraction, collision detection,
## air-gap enforcement, PortableGit discovery, two-phase clone manifest verification,
## cancellation teardown, and defensive directory cleanup.
extends RefCounted
class_name RemoteProjectClonerTests

const RemoteProjectCloner = preload("res://scripts/projects/remote_project_cloner.gd")
const LibraryManager = preload("res://scripts/library/library_manager.gd")
const OfflineEnforcer = preload("res://scripts/network/offline_enforcer.gd")

func run() -> Dictionary:
	var results: Dictionary = {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	
	_test_url_validation_valid(results)
	_test_url_validation_invalid(results)
	_test_slug_extraction(results)
	_test_collision_resolution(results)
	_test_target_path_validation(results)
	_test_portable_git_resolution(results)
	_test_semver_comparison(results)
	await _test_air_gap_blocking(results)
	await _test_clone_flow_success(results)
	await _test_clone_flow_fallback(results)
	await _test_clone_missing_manifest(results)
	await _test_clone_invalid_manifest(results)
	await _test_clone_checkout_failure(results)
	await _test_clone_cancellation(results)
	await _test_clone_target_already_exists(results)
	_test_safe_cleanup_bounds(results)
	
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_url_validation_valid(results: Dictionary) -> void:
	var valid_urls: Array[String] = [
		"https://github.com/opengamestack/ogs-launcher.git",
		"https://gitlab.com/group/subgroup/project",
		"http://localhost:3000/dev/game.git",
		"http://192.168.1.50:8080/repos/game.git",
		"ssh://git@github.com/opengamestack/sample-repo.git",
		"ssh://git@gitlab.internal:2222/org/project.git",
		"git@github.com:opengamestack/sample-repo.git",
		"git@gitlab.internal:team/project.git",
		"developer@host.org:games/adventure.git",
		"github.com:user/project.git"
	]
	
	for url in valid_urls:
		var res: Dictionary = RemoteProjectCloner.validate_remote_url(url)
		_expect(res.get("valid", false), "Expected valid URL: " + url + " (" + res.get("error_message", "") + ")", results)
		_expect(RemoteProjectCloner.is_valid_remote_url(url), "Expected is_valid_remote_url true for: " + url, results)

func _test_url_validation_invalid(results: Dictionary) -> void:
	var invalid_cases: Array[Dictionary] = [
		{"url": "", "code": "empty_url"},
		{"url": "   ", "code": "empty_url"},
		{"url": "https://github.com/org /repo.git", "code": "illegal_characters"},
		{"url": "https://github.com/org\trepo.git", "code": "illegal_characters"},
		{"url": "-u https://github.com/org/repo", "code": "argument_injection"},
		{"url": "--upload-pack=calc.exe", "code": "argument_injection"},
		{"url": "file:///C:/Users/test/repo", "code": "disallowed_protocol"},
		{"url": "file://localhost/repo", "code": "disallowed_protocol"},
		{"url": "ext::sh -c evil", "code": "disallowed_protocol"},
		{"url": "https://ext::evil/repo", "code": "disallowed_protocol"},
		{"url": "C:\\Projects\\repo", "code": "local_path"},
		{"url": "D:/Projects/repo", "code": "local_path"},
		{"url": "/var/repos/game", "code": "local_path"},
		{"url": "./repo", "code": "local_path"},
		{"url": "../repo", "code": "local_path"},
		{"url": "foo/../bar", "code": "local_path"},
		{"url": "https://github.com/org/repo;rm -rf /", "code": "shell_metacharacters"},
		{"url": "https://github.com/org/repo & echo hacked", "code": "shell_metacharacters"},
		{"url": "https://github.com/org/repo | nc 1.2.3.4 80", "code": "shell_metacharacters"},
		{"url": "https://github.com/org/`evil`", "code": "shell_metacharacters"},
		{"url": "https://github.com/org/$USER", "code": "shell_metacharacters"},
		{"url": "https://github.com/org/repo\nevil", "code": "shell_metacharacters"},
		{"url": "https://github.com/org/repo\revil", "code": "shell_metacharacters"},
		{"url": "https://github.com/org/repo<evil", "code": "shell_metacharacters"},
		{"url": "https://github.com/org/repo>evil", "code": "shell_metacharacters"},
		{"url": "https://github.com/org/\"repo\"", "code": "shell_metacharacters"},
		{"url": "https://github.com/org/'repo'", "code": "shell_metacharacters"},
		{"url": "ftp://github.com/org/repo", "code": "unsupported_scheme"},
		{"url": "git://github.com/org/repo", "code": "unsupported_scheme"},
		{"url": "https://", "code": "invalid_url_format"},
		{"url": "https://github.com", "code": "invalid_url_format"},
		{"url": "git@github.com::repo", "code": "invalid_url_format"},
		{"url": "git@github.com:/absolute/path", "code": "invalid_url_format"}
	]
	
	for tc in invalid_cases:
		var url: String = tc["url"]
		var expected_code: String = tc["code"]
		var res: Dictionary = RemoteProjectCloner.validate_remote_url(url)
		_expect(not res.get("valid", true), "Expected invalid URL: " + url, results)
		_expect(res.get("error_code") == expected_code, "Expected code " + expected_code + " for " + url + ", got: " + res.get("error_code", ""), results)
		_expect(not RemoteProjectCloner.is_valid_remote_url(url), "Expected is_valid_remote_url false for: " + url, results)

func _test_slug_extraction(results: Dictionary) -> void:
	var slug_tests: Array[Dictionary] = [
		{"input": "https://github.com/org/my-game-repo.git", "expected": "my-game-repo"},
		{"input": "https://github.com/org/my-game-repo.git/", "expected": "my-game-repo"},
		{"input": "https://github.com/org/my-game-repo", "expected": "my-game-repo"},
		{"input": "https://github.com/org/my-game-repo/", "expected": "my-game-repo"},
		{"input": "git@github.com:org/my-game-repo.git", "expected": "my-game-repo"},
		{"input": "git@github.com:org/my-game-repo", "expected": "my-game-repo"},
		{"input": "ssh://git@github.com/org/nested/space-invaders.git", "expected": "space-invaders"},
		{"input": "http://gitlab.local/group/super_racer_3d.git/", "expected": "super_racer_3d"},
		{"input": "", "expected": ""},
		{"input": "https://github.com/org/..", "expected": ""},
		{"input": "https://github.com/org/.git", "expected": ""},
		{"input": "https://github.com/org/CON.git", "expected": ""},
		{"input": "https://github.com/org/NUL.git", "expected": ""}
	]
	
	for st in slug_tests:
		var input_url: String = st["input"]
		var expected: String = st["expected"]
		var actual: String = RemoteProjectCloner.extract_repo_slug(input_url)
		_expect(actual == expected, "Slug for '%s': expected '%s', got '%s'" % [input_url, expected, actual], results)

func _test_collision_resolution(results: Dictionary) -> void:
	var temp_dir: String = OS.get_user_data_dir().path_join("test_collision_" + str(Time.get_ticks_msec()))
	DirAccess.make_dir_recursive_absolute(temp_dir)
	
	var slug: String = "my-project"
	var name1: String = RemoteProjectCloner.suggest_next_available_folder_name(temp_dir, slug)
	_expect(name1 == "my-project", "First candidate should be base slug", results)
	
	DirAccess.make_dir_recursive_absolute(temp_dir.path_join(name1))
	var name2: String = RemoteProjectCloner.suggest_next_available_folder_name(temp_dir, slug)
	_expect(name2 == "my-project-1", "Second candidate should be base-1", results)
	
	DirAccess.make_dir_recursive_absolute(temp_dir.path_join(name2))
	var name3: String = RemoteProjectCloner.suggest_next_available_folder_name(temp_dir, slug)
	_expect(name3 == "my-project-2", "Third candidate should be base-2", results)
	
	# Cleanup
	RemoteProjectCloner._safe_remove_directory(temp_dir, OS.get_user_data_dir())

func _test_target_path_validation(results: Dictionary) -> void:
	var dest_root: String = OS.get_user_data_dir().path_join("dest_root")
	_expect(RemoteProjectCloner.is_target_path_valid("my-project", dest_root), "Valid subfolder name accepted", results)
	_expect(not RemoteProjectCloner.is_target_path_valid("../escape", dest_root), "Traversal rejected", results)
	_expect(not RemoteProjectCloner.is_target_path_valid("sub/folder", dest_root), "Nested slashes rejected", results)
	_expect(not RemoteProjectCloner.is_target_path_valid("sub\\folder", dest_root), "Backslashes rejected", results)
	_expect(not RemoteProjectCloner.is_target_path_valid("", dest_root), "Empty target name rejected", results)
	_expect(not RemoteProjectCloner.is_target_path_valid("valid", ""), "Empty dest_root rejected", results)

func _test_portable_git_resolution(results: Dictionary) -> void:
	var temp_lib_root: String = OS.get_user_data_dir().path_join("test_lib_git_" + str(Time.get_ticks_msec()))
	DirAccess.make_dir_recursive_absolute(temp_lib_root)
	
	var old_env: String = OS.get_environment("OGS_LIBRARY_ROOT")
	OS.set_environment("OGS_LIBRARY_ROOT", temp_lib_root)
	
	var lib: LibraryManager = LibraryManager.new()
	
	# 1. Not installed
	_expect(RemoteProjectCloner.resolve_git_executable(lib).is_empty(), "Git not installed returns empty string", results)
	_expect(not RemoteProjectCloner.is_git_installed(lib), "is_git_installed returns false when empty", results)
	
	# 2. Install multiple versions: 2.43.0 and 2.44.0
	var v1_cmd: String = temp_lib_root.path_join("git/2.43.0/cmd")
	var v2_cmd: String = temp_lib_root.path_join("git/2.44.0/cmd")
	DirAccess.make_dir_recursive_absolute(v1_cmd)
	DirAccess.make_dir_recursive_absolute(v2_cmd)
	
	var git_exe_name: String = "git.exe" if OS.get_name() == "Windows" else "git"
	var f1: FileAccess = FileAccess.open(v1_cmd.path_join(git_exe_name), FileAccess.WRITE)
	f1.store_string("mock git 2.43.0")
	f1.close()
	
	var f2: FileAccess = FileAccess.open(v2_cmd.path_join(git_exe_name), FileAccess.WRITE)
	f2.store_string("mock git 2.44.0")
	f2.close()
	
	var resolved_exe: String = RemoteProjectCloner.resolve_git_executable(lib)
	_expect(resolved_exe.contains("2.44.0"), "Should resolve highest version 2.44.0, got: " + resolved_exe, results)
	_expect(RemoteProjectCloner.is_git_installed(lib), "is_git_installed returns true when installed", results)
	
	# Specific version query
	var v1_resolved: String = lib.resolve_git_executable("2.43.0")
	_expect(v1_resolved.contains("2.43.0"), "Specific version resolves 2.43.0", results)
	
	# Restore environment and cleanup
	if old_env.is_empty():
		OS.set_environment("OGS_LIBRARY_ROOT", "")
	else:
		OS.set_environment("OGS_LIBRARY_ROOT", old_env)
	RemoteProjectCloner._safe_remove_directory(temp_lib_root, OS.get_user_data_dir())

func _test_semver_comparison(results: Dictionary) -> void:
	_expect(LibraryManager.compare_versions("2.10.0", "2.9.0") > 0, "2.10.0 > 2.9.0", results)
	_expect(LibraryManager.compare_versions("2.9.0", "2.10.0") < 0, "2.9.0 < 2.10.0", results)
	_expect(LibraryManager.compare_versions("2.44.0.windows.1", "2.43.0.windows.1") > 0, "2.44 > 2.43", results)
	_expect(LibraryManager.compare_versions("2.43.0", "2.43.0") == 0, "equal versions return 0", results)

func _test_air_gap_blocking(results: Dictionary) -> void:
	OfflineEnforcer.reset()
	OfflineEnforcer._set_offline(true, "test")
	
	var cloner: RemoteProjectCloner = RemoteProjectCloner.new()
	var state: Dictionary = {"failed": false, "code": "", "done": false}
	
	cloner.clone_failed.connect(func(code: String, _msg: String):
		state["failed"] = true
		state["code"] = code
		state["done"] = true
	)
	
	var test_root: String = OS.get_user_data_dir().path_join("test_airgap_" + str(Time.get_ticks_msec()))
	cloner.clone_project_async("https://github.com/org/repo.git", "repo", test_root)
	
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var start_time: int = Time.get_ticks_msec()
	while not state["done"] and (Time.get_ticks_msec() - start_time) < 5000:
		await tree.process_frame
	
	cloner.wait_for_finish()
	await tree.process_frame
	
	_expect(state["failed"], "Air-gap mode emitted clone_failed", results)
	_expect(state["code"] == "offline", "Expected 'offline' error code, got: " + String(state["code"]), results)
	_expect(not cloner.is_busy(), "Cloner is not busy after offline rejection", results)
	
	OfflineEnforcer.reset()

func _create_mock_lib_with_git(temp_dir: String) -> LibraryManager:
	var cmd_dir: String = temp_dir.path_join("git/2.44.0/cmd")
	DirAccess.make_dir_recursive_absolute(cmd_dir)
	var git_exe_name: String = "git.exe" if OS.get_name() == "Windows" else "git"
	var f: FileAccess = FileAccess.open(cmd_dir.path_join(git_exe_name), FileAccess.WRITE)
	f.store_string("mock git")
	f.close()
	
	var lib: LibraryManager = LibraryManager.new()
	lib.path_resolver = PathResolver.new()
	return lib

func _test_clone_flow_success(results: Dictionary) -> void:
	var temp_root: String = OS.get_user_data_dir().path_join("test_success_" + str(Time.get_ticks_msec()))
	DirAccess.make_dir_recursive_absolute(temp_root)
	var old_env: String = OS.get_environment("OGS_LIBRARY_ROOT")
	OS.set_environment("OGS_LIBRARY_ROOT", temp_root)
	
	var lib: LibraryManager = _create_mock_lib_with_git(temp_root)
	var cloner: RemoteProjectCloner = RemoteProjectCloner.new(lib)
	
	var state: Dictionary = {
		"done": false,
		"completed_path": "",
		"phases": [],
		"progress_updates": [],
		"executed_commands": []
	}
	
	cloner.phase_changed.connect(func(p: String): state["phases"].append(p))
	cloner.progress_updated.connect(func(pct: float, _msg: String): state["progress_updates"].append(pct))
	cloner.clone_completed.connect(func(path: String):
		state["completed_path"] = path
		state["done"] = true
	)
	cloner.clone_failed.connect(func(_code: String, _msg: String):
		state["done"] = true
	)
	
	var target_dest: String = temp_root.path_join("projects")
	var valid_manifest_json: String = JSON.stringify({
		"schema_version": 1,
		"stack_name": "Sample RPG",
		"tools": []
	})
	
	cloner.custom_command_runner = func(_exe: String, args: PackedStringArray, on_progress: Callable) -> Dictionary:
		state["executed_commands"].append(args)
		
		if args.has("clone"):
			if on_progress.is_valid():
				on_progress.call("Receiving objects:  50% (5/10)")
				on_progress.call("Resolving deltas: 100% (4/4)")
			DirAccess.make_dir_recursive_absolute(target_dest.path_join("sample-rpg"))
			return {"exit_code": 0, "stdout": "", "stderr": "", "cancelled": false}
		elif args.has("show"):
			return {"exit_code": 0, "stdout": valid_manifest_json, "stderr": "", "cancelled": false}
		elif args.has("checkout"):
			if on_progress.is_valid():
				on_progress.call("Checking out files: 100% (20/20)")
			return {"exit_code": 0, "stdout": "", "stderr": "", "cancelled": false}
		return {"exit_code": 0, "stdout": "", "stderr": "", "cancelled": false}
	
	cloner.clone_project_async("https://github.com/org/sample-rpg.git", "sample-rpg", target_dest)
	
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var start_time: int = Time.get_ticks_msec()
	while not state["done"] and (Time.get_ticks_msec() - start_time) < 5000:
		await tree.process_frame
	
	cloner.wait_for_finish()
	await tree.process_frame
	
	_expect(not String(state["completed_path"]).is_empty(), "Clone completed successfully", results)
	_expect(state["phases"].has("verifying"), "Phase changed to 'verifying'", results)
	_expect(state["phases"].has("cloning"), "Phase changed to 'cloning'", results)
	_expect(state["progress_updates"].size() > 0, "Progress updates received", results)
	_expect(state["progress_updates"].has(50.0) or state["progress_updates"].has(100.0), "Parsed percentage from progress stream", results)
	
	# Verify ogs_config.json auto-generation
	var config_file: String = String(state["completed_path"]).path_join("ogs_config.json")
	_expect(FileAccess.file_exists(config_file), "ogs_config.json was auto-generated", results)
	
	# Verify hardened flags on all executed commands
	for cmd in state["executed_commands"]:
		var cmd_str: String = " ".join(cmd)
		_expect(cmd_str.contains("protocol.ext.allow=never"), "Hardened ext.allow flag passed", results)
		_expect(cmd_str.contains("protocol.file.allow=never"), "Hardened file.allow flag passed", results)
		_expect(cmd_str.contains("core.symlinks=false"), "Hardened symlinks flag passed", results)
		_expect(cmd_str.contains("core.fsmonitor=false"), "Hardened fsmonitor flag passed", results)
	
	if old_env.is_empty():
		OS.set_environment("OGS_LIBRARY_ROOT", "")
	else:
		OS.set_environment("OGS_LIBRARY_ROOT", old_env)
	RemoteProjectCloner._safe_remove_directory(temp_root, OS.get_user_data_dir())

func _test_clone_flow_fallback(results: Dictionary) -> void:
	var temp_root: String = OS.get_user_data_dir().path_join("test_fallback_" + str(Time.get_ticks_msec()))
	DirAccess.make_dir_recursive_absolute(temp_root)
	var old_env: String = OS.get_environment("OGS_LIBRARY_ROOT")
	OS.set_environment("OGS_LIBRARY_ROOT", temp_root)
	
	var lib: LibraryManager = _create_mock_lib_with_git(temp_root)
	var cloner: RemoteProjectCloner = RemoteProjectCloner.new(lib)
	
	var target_dest: String = temp_root.path_join("projects")
	var state: Dictionary = {
		"done": false,
		"completed": false,
		"attempt_count": 0,
		"executed_commands": []
	}
	
	cloner.clone_completed.connect(func(_p):
		state["completed"] = true
		state["done"] = true
	)
	cloner.clone_failed.connect(func(_code, _msg):
		state["done"] = true
	)
	
	var valid_manifest_json: String = JSON.stringify({
		"schema_version": 1,
		"stack_name": "Fallback RPG",
		"tools": []
	})
	
	cloner.custom_command_runner = func(_exe: String, args: PackedStringArray, _progress: Callable) -> Dictionary:
		state["executed_commands"].append(args)
		
		if args.has("clone"):
			state["attempt_count"] += 1
			if state["attempt_count"] == 1:
				return {"exit_code": 1, "stdout": "", "stderr": "fatal: filter not supported", "cancelled": false}
			else:
				DirAccess.make_dir_recursive_absolute(target_dest.path_join("fallback-rpg"))
				return {"exit_code": 0, "stdout": "", "stderr": "", "cancelled": false}
		elif args.has("show"):
			return {"exit_code": 0, "stdout": valid_manifest_json, "stderr": "", "cancelled": false}
		elif args.has("checkout"):
			return {"exit_code": 0, "stdout": "", "stderr": "", "cancelled": false}
		return {"exit_code": 0, "stdout": "", "stderr": "", "cancelled": false}
	
	cloner.clone_project_async("https://github.com/org/fallback-rpg.git", "fallback-rpg", target_dest)
	
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var start_time: int = Time.get_ticks_msec()
	while not state["done"] and (Time.get_ticks_msec() - start_time) < 5000:
		await tree.process_frame
	
	cloner.wait_for_finish()
	await tree.process_frame
	
	_expect(state["completed"], "Clone succeeded after fallback", results)
	_expect(state["attempt_count"] == 2, "Expected exactly 2 clone attempts for fallback", results)
	
	var first_clone: String = " ".join(state["executed_commands"][0])
	var second_clone: String = " ".join(state["executed_commands"][1])
	_expect(first_clone.contains("--filter=blob:none"), "First attempt used blobless clone", results)
	_expect(not second_clone.contains("--filter=blob:none") and second_clone.contains("--no-checkout"), "Second attempt used standard no-checkout", results)
	
	if old_env.is_empty():
		OS.set_environment("OGS_LIBRARY_ROOT", "")
	else:
		OS.set_environment("OGS_LIBRARY_ROOT", old_env)
	RemoteProjectCloner._safe_remove_directory(temp_root, OS.get_user_data_dir())

func _test_clone_missing_manifest(results: Dictionary) -> void:
	var temp_root: String = OS.get_user_data_dir().path_join("test_missing_" + str(Time.get_ticks_msec()))
	DirAccess.make_dir_recursive_absolute(temp_root)
	var old_env: String = OS.get_environment("OGS_LIBRARY_ROOT")
	OS.set_environment("OGS_LIBRARY_ROOT", temp_root)
	
	var lib: LibraryManager = _create_mock_lib_with_git(temp_root)
	var cloner: RemoteProjectCloner = RemoteProjectCloner.new(lib)
	
	var target_dest: String = temp_root.path_join("projects")
	var state: Dictionary = {"done": false, "failed_code": ""}
	
	cloner.clone_failed.connect(func(code: String, _msg: String):
		state["failed_code"] = code
		state["done"] = true
	)
	cloner.clone_completed.connect(func(_path: String):
		state["done"] = true
	)
	
	cloner.custom_command_runner = func(_exe: String, args: PackedStringArray, _progress: Callable) -> Dictionary:
		if args.has("clone"):
			DirAccess.make_dir_recursive_absolute(target_dest.path_join("no-manifest-repo"))
			return {"exit_code": 0, "stdout": "", "stderr": "", "cancelled": false}
		elif args.has("show"):
			return {"exit_code": 128, "stdout": "", "stderr": "fatal: path 'ogs_stack.json' does not exist in 'HEAD'", "cancelled": false}
		return {"exit_code": 0, "stdout": "", "stderr": "", "cancelled": false}
	
	cloner.clone_project_async("https://github.com/org/no-manifest-repo.git", "no-manifest-repo", target_dest)
	
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var start_time: int = Time.get_ticks_msec()
	while not state["done"] and (Time.get_ticks_msec() - start_time) < 5000:
		await tree.process_frame
	
	cloner.wait_for_finish()
	await tree.process_frame
	
	_expect(state["failed_code"] == "missing_ogs_stack_json", "Missing ogs_stack.json reported: " + String(state["failed_code"]), results)
	_expect(not DirAccess.dir_exists_absolute(target_dest.path_join("no-manifest-repo")), "Incomplete directory purged on missing manifest", results)
	
	if old_env.is_empty():
		OS.set_environment("OGS_LIBRARY_ROOT", "")
	else:
		OS.set_environment("OGS_LIBRARY_ROOT", old_env)
	RemoteProjectCloner._safe_remove_directory(temp_root, OS.get_user_data_dir())

func _test_clone_invalid_manifest(results: Dictionary) -> void:
	var temp_root: String = OS.get_user_data_dir().path_join("test_invalid_" + str(Time.get_ticks_msec()))
	DirAccess.make_dir_recursive_absolute(temp_root)
	var old_env: String = OS.get_environment("OGS_LIBRARY_ROOT")
	OS.set_environment("OGS_LIBRARY_ROOT", temp_root)
	
	var lib: LibraryManager = _create_mock_lib_with_git(temp_root)
	var cloner: RemoteProjectCloner = RemoteProjectCloner.new(lib)
	
	var target_dest: String = temp_root.path_join("projects")
	var state: Dictionary = {"done": false, "failed_code": ""}
	
	cloner.clone_failed.connect(func(code: String, _msg: String):
		state["failed_code"] = code
		state["done"] = true
	)
	cloner.clone_completed.connect(func(_path: String):
		state["done"] = true
	)
	
	cloner.custom_command_runner = func(_exe: String, args: PackedStringArray, _progress: Callable) -> Dictionary:
		if args.has("clone"):
			DirAccess.make_dir_recursive_absolute(target_dest.path_join("invalid-manifest-repo"))
			return {"exit_code": 0, "stdout": "", "stderr": "", "cancelled": false}
		elif args.has("show"):
			return {"exit_code": 0, "stdout": '{"schema_version": 999}', "stderr": "", "cancelled": false}
		return {"exit_code": 0, "stdout": "", "stderr": "", "cancelled": false}
	
	cloner.clone_project_async("https://github.com/org/invalid-manifest-repo.git", "invalid-manifest-repo", target_dest)
	
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var start_time: int = Time.get_ticks_msec()
	while not state["done"] and (Time.get_ticks_msec() - start_time) < 5000:
		await tree.process_frame
	
	cloner.wait_for_finish()
	await tree.process_frame
	
	_expect(state["failed_code"] == "invalid_ogs_stack_json", "Invalid ogs_stack.json reported: " + String(state["failed_code"]), results)
	_expect(not DirAccess.dir_exists_absolute(target_dest.path_join("invalid-manifest-repo")), "Incomplete directory purged on invalid manifest", results)
	
	if old_env.is_empty():
		OS.set_environment("OGS_LIBRARY_ROOT", "")
	else:
		OS.set_environment("OGS_LIBRARY_ROOT", old_env)
	RemoteProjectCloner._safe_remove_directory(temp_root, OS.get_user_data_dir())

func _test_clone_checkout_failure(results: Dictionary) -> void:
	var temp_root: String = OS.get_user_data_dir().path_join("test_chkfail_" + str(Time.get_ticks_msec()))
	DirAccess.make_dir_recursive_absolute(temp_root)
	var old_env: String = OS.get_environment("OGS_LIBRARY_ROOT")
	OS.set_environment("OGS_LIBRARY_ROOT", temp_root)
	
	var lib: LibraryManager = _create_mock_lib_with_git(temp_root)
	var cloner: RemoteProjectCloner = RemoteProjectCloner.new(lib)
	
	var target_dest: String = temp_root.path_join("projects")
	var state: Dictionary = {"done": false, "failed_code": ""}
	
	cloner.clone_failed.connect(func(code: String, _msg: String):
		state["failed_code"] = code
		state["done"] = true
	)
	cloner.clone_completed.connect(func(_path: String):
		state["done"] = true
	)
	
	var valid_manifest_json: String = JSON.stringify({
		"schema_version": 1,
		"stack_name": "Valid RPG",
		"tools": []
	})
	
	cloner.custom_command_runner = func(_exe: String, args: PackedStringArray, _progress: Callable) -> Dictionary:
		if args.has("clone"):
			DirAccess.make_dir_recursive_absolute(target_dest.path_join("checkout-fail-repo"))
			return {"exit_code": 0, "stdout": "", "stderr": "", "cancelled": false}
		elif args.has("show"):
			return {"exit_code": 0, "stdout": valid_manifest_json, "stderr": "", "cancelled": false}
		elif args.has("checkout"):
			return {"exit_code": 1, "stdout": "", "stderr": "fatal: unable to checkout working tree", "cancelled": false}
		return {"exit_code": 0, "stdout": "", "stderr": "", "cancelled": false}
	
	cloner.clone_project_async("https://github.com/org/checkout-fail-repo.git", "checkout-fail-repo", target_dest)
	
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var start_time: int = Time.get_ticks_msec()
	while not state["done"] and (Time.get_ticks_msec() - start_time) < 5000:
		await tree.process_frame
	
	cloner.wait_for_finish()
	await tree.process_frame
	
	_expect(state["failed_code"] == "checkout_failed", "Checkout failure reported: " + String(state["failed_code"]), results)
	_expect(not DirAccess.dir_exists_absolute(target_dest.path_join("checkout-fail-repo")), "Incomplete directory purged on checkout failure", results)
	
	if old_env.is_empty():
		OS.set_environment("OGS_LIBRARY_ROOT", "")
	else:
		OS.set_environment("OGS_LIBRARY_ROOT", old_env)
	RemoteProjectCloner._safe_remove_directory(temp_root, OS.get_user_data_dir())

func _test_clone_cancellation(results: Dictionary) -> void:
	var temp_root: String = OS.get_user_data_dir().path_join("test_cancel_" + str(Time.get_ticks_msec()))
	DirAccess.make_dir_recursive_absolute(temp_root)
	var old_env: String = OS.get_environment("OGS_LIBRARY_ROOT")
	OS.set_environment("OGS_LIBRARY_ROOT", temp_root)
	
	var lib: LibraryManager = _create_mock_lib_with_git(temp_root)
	var cloner: RemoteProjectCloner = RemoteProjectCloner.new(lib)
	
	var target_dest: String = temp_root.path_join("projects")
	var state: Dictionary = {"done": false, "failed_code": ""}
	
	cloner.clone_failed.connect(func(code: String, _msg: String):
		state["failed_code"] = code
		state["done"] = true
	)
	cloner.clone_completed.connect(func(_path: String):
		state["done"] = true
	)
	
	cloner.custom_command_runner = func(_exe: String, args: PackedStringArray, _progress: Callable) -> Dictionary:
		if args.has("clone"):
			DirAccess.make_dir_recursive_absolute(target_dest.path_join("cancel-repo"))
			cloner.cancel()
			return {"exit_code": -1, "stdout": "", "stderr": "", "cancelled": true}
		return {"exit_code": 0, "stdout": "", "stderr": "", "cancelled": false}
	
	cloner.clone_project_async("https://github.com/org/cancel-repo.git", "cancel-repo", target_dest)
	
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var start_time: int = Time.get_ticks_msec()
	while not state["done"] and (Time.get_ticks_msec() - start_time) < 5000:
		await tree.process_frame
	
	cloner.wait_for_finish()
	await tree.process_frame
	
	_expect(state["failed_code"] == "cancelled", "Cancellation reported: " + String(state["failed_code"]), results)
	_expect(not DirAccess.dir_exists_absolute(target_dest.path_join("cancel-repo")), "Directory purged on cancel", results)
	
	if old_env.is_empty():
		OS.set_environment("OGS_LIBRARY_ROOT", "")
	else:
		OS.set_environment("OGS_LIBRARY_ROOT", old_env)
	RemoteProjectCloner._safe_remove_directory(temp_root, OS.get_user_data_dir())

func _test_clone_target_already_exists(results: Dictionary) -> void:
	var temp_root: String = OS.get_user_data_dir().path_join("test_exists_" + str(Time.get_ticks_msec()))
	DirAccess.make_dir_recursive_absolute(temp_root)
	var old_env: String = OS.get_environment("OGS_LIBRARY_ROOT")
	OS.set_environment("OGS_LIBRARY_ROOT", temp_root)
	
	var lib: LibraryManager = _create_mock_lib_with_git(temp_root)
	var cloner: RemoteProjectCloner = RemoteProjectCloner.new(lib)
	
	var target_dest: String = temp_root.path_join("projects")
	DirAccess.make_dir_recursive_absolute(target_dest.path_join("existing-project"))
	
	var state: Dictionary = {"done": false, "failed_code": ""}
	cloner.clone_failed.connect(func(code: String, _msg: String):
		state["failed_code"] = code
		state["done"] = true
	)
	cloner.clone_completed.connect(func(_path: String):
		state["done"] = true
	)
	
	cloner.clone_project_async("https://github.com/org/existing-project.git", "existing-project", target_dest)
	
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var start_time: int = Time.get_ticks_msec()
	while not state["done"] and (Time.get_ticks_msec() - start_time) < 5000:
		await tree.process_frame
	
	cloner.wait_for_finish()
	await tree.process_frame
	
	_expect(state["failed_code"] == "target_dir_exists", "Existing target reported: " + String(state["failed_code"]), results)
	
	if old_env.is_empty():
		OS.set_environment("OGS_LIBRARY_ROOT", "")
	else:
		OS.set_environment("OGS_LIBRARY_ROOT", old_env)
	RemoteProjectCloner._safe_remove_directory(temp_root, OS.get_user_data_dir())

func _test_safe_cleanup_bounds(results: Dictionary) -> void:
	var dest_root: String = OS.get_user_data_dir().path_join("test_safe_root")
	var outside_dir: String = OS.get_user_data_dir().path_join("test_safe_outside")
	DirAccess.make_dir_recursive_absolute(dest_root)
	DirAccess.make_dir_recursive_absolute(outside_dir)
	
	_expect(not RemoteProjectCloner._safe_remove_directory(outside_dir, dest_root), "Cannot delete directory outside root", results)
	_expect(not RemoteProjectCloner._safe_remove_directory(dest_root, dest_root), "Cannot delete dest_root itself", results)
	_expect(not RemoteProjectCloner._safe_remove_directory("", dest_root), "Empty target cannot be deleted", results)
	_expect(not RemoteProjectCloner._safe_remove_directory(outside_dir, ""), "Empty root rejected", results)
	
	RemoteProjectCloner._safe_remove_directory(dest_root, OS.get_user_data_dir())
	RemoteProjectCloner._safe_remove_directory(outside_dir, OS.get_user_data_dir())

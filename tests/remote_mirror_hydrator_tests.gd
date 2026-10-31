## RemoteMirrorHydratorTests: Unit tests for remote mirror hydration behavior.

extends RefCounted
class_name RemoteMirrorHydratorTests

const RemoteMirrorHydratorScript = preload("res://scripts/mirror/remote_mirror_hydrator.gd")
const OgsConfigScript = preload("res://scripts/config/ogs_config.gd")
const CryptoUtils = preload("res://scripts/utils/crypto_utils.gd")

func run() -> Dictionary:
	## Runs RemoteMirrorHydrator unit tests.
	var results = {"passed": 0, "failed": 0, "failures": []}
	_cleanup_library()
	await _test_missing_repository_url(results)
	await _test_invalid_repository_json(results)
	await _test_missing_archive_file(results)
	await _test_http_download_loopback_integration(results)
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
	var result = await hydrator.hydrate([
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
	var result = await hydrator.hydrate([
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
	var result = await hydrator.hydrate([
		{"tool_id": "godot", "version": "4.3"}
	])
	_expect(result["success"] == false, "should fail when archive file is missing", results)
	_expect(result["failed_count"] == 1, "failed_count should be 1 when archive missing", results)

	if FileAccess.file_exists(repo_path):
		DirAccess.remove_absolute(repo_path)
	if DirAccess.dir_exists_absolute(temp_root):
		DirAccess.remove_absolute(temp_root)

func _test_http_download_loopback_integration(results: Dictionary) -> void:
	## Tests remote HTTP tool download end-to-end using a loopback TCPServer on 127.0.0.1.
	var was_offline: bool = OfflineEnforcer.is_offline()
	var prev_reason: String = OfflineEnforcer.get_reason()
	OfflineEnforcer.reset()

	var temp_root: String = OS.get_user_data_dir().path_join("remote_loopback_test")
	if not DirAccess.dir_exists_absolute(temp_root):
		DirAccess.make_dir_recursive_absolute(temp_root)

	var zip_path: String = temp_root.path_join("godot_test.zip")
	var repo_path: String = temp_root.path_join("repository.json")

	# 1. Create a valid mock zip archive
	var zipper: ZIPPacker = ZIPPacker.new()
	var zip_err: Error = zipper.open(zip_path)
	_expect(zip_err == OK, "ZIPPacker open should succeed", results)
	zipper.start_file("godot.exe")
	zipper.write_file("OGS Mock Godot Executable Payload".to_utf8_buffer())
	zipper.close_file()
	zipper.close()

	var hash_res: Dictionary = CryptoUtils.compute_sha256(zip_path)
	_expect(hash_res["success"] == true, "sha256 computation of test zip should succeed", results)
	var expected_hash: String = hash_res.get("sha256", "")

	var zip_file: FileAccess = FileAccess.open(zip_path, FileAccess.READ)
	_expect(zip_file != null, "test zip file should be openable", results)
	var zip_bytes: PackedByteArray = zip_file.get_buffer(zip_file.get_length())
	zip_file.close()

	# 2. Setup loopback TCPServer on 127.0.0.1 ephemeral port
	var server: TCPServer = TCPServer.new()
	var listen_err: Error = server.listen(0, "127.0.0.1")
	_expect(listen_err == OK, "TCPServer listen should succeed on ephemeral port", results)
	var port: int = server.get_local_port()

	var thread_state: Dictionary = {"running": true}
	var server_thread: Thread = Thread.new()
	var server_worker: Callable = func() -> void:
		while thread_state["running"]:
			if server.is_connection_available():
				var peer: StreamPeerTCP = server.take_connection()
				if peer != null:
					var wait_count: int = 0
					while peer.get_status() == StreamPeerTCP.STATUS_CONNECTED and peer.get_available_bytes() == 0 and wait_count < 100:
						OS.delay_msec(10)
						wait_count += 1
					if peer.get_available_bytes() > 0:
						var _req: PackedByteArray = peer.get_data(peer.get_available_bytes())[1]
						var header: String = "HTTP/1.1 200 OK\r\nContent-Type: application/zip\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % zip_bytes.size()
						peer.put_data(header.to_utf8_buffer())
						peer.put_data(zip_bytes)
						peer.disconnect_from_host()
			OS.delay_msec(10)

	server_thread.start(server_worker)

	# 3. Create repository.json referencing the loopback HTTP archive URL
	var repo_json: Dictionary = {
		"schema_version": 1,
		"mirror_name": "Loopback Test Mirror",
		"tools": [
			{
				"id": "godot",
				"version": "4.3",
				"archive_url": "http://127.0.0.1:%d/godot-4.3.zip" % port,
				"sha256": expected_hash,
				"executable_path": "godot.exe"
			}
		]
	}
	var repo_file: FileAccess = FileAccess.open(repo_path, FileAccess.WRITE)
	if repo_file:
		repo_file.store_string(JSON.stringify(repo_json))
		repo_file.close()

	# 4. Run hydration
	var hydrator = RemoteMirrorHydratorScript.new(repo_path)
	var install_complete_data: Dictionary = {"emitted": false, "tool_id": "", "version": "", "success": false, "error_message": ""}
	hydrator.tool_install_complete.connect(func(tid: String, ver: String, succ: bool, err_msg: String) -> void:
		install_complete_data["emitted"] = true
		install_complete_data["tool_id"] = tid
		install_complete_data["version"] = ver
		install_complete_data["success"] = succ
		install_complete_data["error_message"] = err_msg
	)

	var download_progress_data: Dictionary = {"emitted": false, "downloaded": 0, "total": 0}
	hydrator.tool_download_progress.connect(func(_tid: String, _ver: String, dl: int, tot: int) -> void:
		download_progress_data["emitted"] = true
		download_progress_data["downloaded"] = dl
		download_progress_data["total"] = tot
	)

	var result: Dictionary = await hydrator.hydrate([
		{"tool_id": "godot", "version": "4.3"}
	])

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.process_frame
		await tree.process_frame

	_expect(result["success"] == true, "hydration should succeed over loopback HTTP", results)
	_expect(result["installed_count"] == 1, "installed_count should be 1", results)
	_expect(result["failed_count"] == 0, "failed_count should be 0", results)
	_expect(install_complete_data["emitted"] == true, "tool_install_complete should be emitted", results)
	_expect(install_complete_data["success"] == true, "tool_install_complete success should be true", results)
	_expect(install_complete_data["tool_id"] == "godot", "tool_install_complete tool_id should be godot", results)
	_expect(hydrator.library.tool_exists("godot", "4.3") == true, "godot 4.3 should be installed in library", results)
	_expect(download_progress_data["emitted"] == true, "tool_download_progress should be emitted during HTTP transfer", results)

	# 5. Clean up server thread and socket
	thread_state["running"] = false
	server_thread.wait_to_finish()
	server.stop()

	# 6. Clean up temporary files
	if FileAccess.file_exists(zip_path):
		DirAccess.remove_absolute(zip_path)
	if FileAccess.file_exists(repo_path):
		DirAccess.remove_absolute(repo_path)
	if DirAccess.dir_exists_absolute(temp_root):
		DirAccess.remove_absolute(temp_root)

	# 7. Restore OfflineEnforcer state
	if was_offline:
		var restore_cfg: OgsConfig = OgsConfigScript.from_dict({
			"offline_mode": prev_reason == "offline_mode",
			"force_offline": prev_reason == "force_offline"
		})
		OfflineEnforcer.apply_config(restore_cfg)
	else:
		OfflineEnforcer.reset()

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

## RemoteMirrorHydrator: Installs tools from a remote mirror repository into the library.
##
## Downloads repository.json from a remote URL (or local file URL), validates
## entries, fetches tool archives, verifies hashes, and extracts archives into
## the central library. This workflow respects offline enforcement.

extends "res://scripts/mirror/base_hydrator.gd"
class_name RemoteMirrorHydrator

const OgsLogger = preload("res://scripts/logging/logger.gd")

const MirrorRepositoryScript = preload("res://scripts/mirror/mirror_repository.gd")

var repository_url: String = ""
var repository: MirrorRepository
var extractor: ToolExtractor
var library: LibraryManager

var _cancelled_tools: Dictionary = {}
var _cancel_mutex: Mutex = Mutex.new()

func _init(repo_url: String = "", tree: SceneTree = null) -> void:
	## Initializes the remote mirror hydrator with a repository URL.
	## Parameters:
	##   repo_url (String): URL to the remote repository.json
	##   tree (SceneTree): Optional scene tree for safe signal emission from threads
	repository_url = repo_url
	scene_tree = tree
	repository = MirrorRepositoryScript.new()
	extractor = ToolExtractor.new()
	library = LibraryManager.new()

## Sets the repository.json URL for this hydrator.
func set_repository_url(repo_url: String) -> void:
	## Sets the remote repository URL.
	repository_url = repo_url
	
## Flags an active download for cancellation.
func cancel_download(tool_id: String, version: String) -> void:
	## Marks a tool for cancellation to abort the download loop.
	var key = "%s_%s" % [tool_id, version]
	_cancel_mutex.lock()
	_cancelled_tools[key] = true
	_cancel_mutex.unlock()

func _is_cancelled(tool_id: String, version: String) -> bool:
	var key = "%s_%s" % [tool_id, version]
	_cancel_mutex.lock()
	var cancelled = _cancelled_tools.has(key)
	_cancel_mutex.unlock()
	return cancelled

## Hydrates missing tools from the remote mirror into the library.
## Parameters:
## tools_to_install (Array): Array of {"tool_id": String, "version": String}
## Returns:
## Dictionary: {"success": bool, "installed_count": int, "failed_count": int, "failed_tools": Array}
func hydrate(tools_to_install: Array) -> Dictionary:
	## Installs tools from remote mirror archives into the library.
	return await _hydrate_internal(tools_to_install)

## Starts hydration asynchronously without blocking.
func hydrate_async(tools_to_install: Array) -> void:
	## Starts remote hydration asynchronously.
	_hydrate_internal(tools_to_install)

## Performs the hydration workflow synchronously.
func _hydrate_internal(tools_to_install: Array) -> Dictionary:
	## Installs tools from remote mirror archives into the library.
	var result = {
		"success": true,
		"installed_count": 0,
		"failed_count": 0,
		"failed_tools": []
	}

	if tools_to_install.is_empty():
		OgsLogger.info("remote_hydration_complete", {
			"component": "mirror",
			"reason": "no tools to install"
		})
		_emit_hydration_complete(true, [])
		return result

	var guard = OfflineEnforcer.guard_network_call("remote_mirror_hydration")
	if not guard["allowed"]:
		result["success"] = false
		result["failed_count"] = tools_to_install.size()
		result["failed_tools"] = tools_to_install
		OgsLogger.warn("remote_hydration_blocked", {
			"component": "mirror",
			"reason": guard["error_message"]
		})
		_emit_hydration_complete(false, tools_to_install)
		return result

	if repository_url.is_empty():
		result["success"] = false
		result["failed_count"] = tools_to_install.size()
		result["failed_tools"] = tools_to_install
		OgsLogger.error("remote_repo_missing", {
			"component": "mirror",
			"reason": "repository_url_not_set"
		})
		_emit_hydration_complete(false, tools_to_install)
		return result

	var repo_result = await _load_repository()
	if not repo_result["success"]:
		result["success"] = false
		result["failed_count"] = tools_to_install.size()
		result["failed_tools"] = tools_to_install
		OgsLogger.error("remote_repo_invalid", {
			"component": "mirror",
			"reason": repo_result.get("error", "unknown")
		})
		_emit_hydration_complete(false, tools_to_install)
		return result

	repository = repo_result["repository"]
	if not repository.is_valid():
		result["success"] = false
		result["failed_count"] = tools_to_install.size()
		result["failed_tools"] = tools_to_install
		OgsLogger.error("remote_repo_validation_failed", {
			"component": "mirror",
			"error_count": repository.errors.size()
		})
		_emit_hydration_complete(false, tools_to_install)
		return result

	OgsLogger.info("remote_hydration_started", {
		"component": "mirror",
		"tool_count": tools_to_install.size()
	})

	for tool_entry in tools_to_install:
		var tool_id = String(tool_entry.get("tool_id", ""))
		var version = String(tool_entry.get("version", ""))
		if tool_id.is_empty() or version.is_empty():
			result["failed_count"] += 1
			result["failed_tools"].append(tool_entry)
			continue

		var key = "%s_%s" % [tool_id, version]
		_cancel_mutex.lock()
		_cancelled_tools.erase(key)
		_cancel_mutex.unlock()

		if library.tool_exists(tool_id, version):
			OgsLogger.debug("remote_tool_skip", {
				"component": "mirror",
				"tool_id": tool_id,
				"version": version,
				"reason": "already in library"
			})
			result["installed_count"] += 1
			_emit_tool_install_complete(tool_id, version, true, "")
			continue

		var repo_entry = repository.get_tool_entry(tool_id, version)
		if repo_entry.is_empty():
			var missing_msg = "Tool not found in remote repository"
			OgsLogger.error("remote_tool_missing", {
				"component": "mirror",
				"tool_id": tool_id,
				"version": version
			})
			result["failed_count"] += 1
			result["failed_tools"].append(tool_entry)
			_emit_tool_install_complete(tool_id, version, false, missing_msg)
			continue

		var archive_url = String(repo_entry.get("archive_url", ""))
		if archive_url.is_empty():
			var archive_error = "Remote archive_url missing"
			result["failed_count"] += 1
			result["failed_tools"].append(tool_entry)
			_emit_tool_install_complete(tool_id, version, false, archive_error)
			continue

		var temp_archive = await _stage_archive(archive_url, tool_id, version)
		if temp_archive.is_empty():
			var download_error = "Failed to download remote archive"
			result["failed_count"] += 1
			result["failed_tools"].append(tool_entry)
			_emit_tool_install_complete(tool_id, version, false, download_error)
			continue

		var sha_value = String(repo_entry.get("sha256", "")).strip_edges().to_lower()
		if not sha_value.is_empty():
			var hash_result = _compute_sha256(temp_archive)
			if not hash_result["success"]:
				result["failed_count"] += 1
				result["failed_tools"].append(tool_entry)
				_emit_tool_install_complete(tool_id, version, false, hash_result["error_message"])
				continue
			if hash_result["sha256"] != sha_value:
				var mismatch = "Archive sha256 does not match repository"
				OgsLogger.error("remote_hash_mismatch", {
					"component": "mirror",
					"tool_id": tool_id,
					"version": version
				})
				result["failed_count"] += 1
				result["failed_tools"].append(tool_entry)
				_emit_tool_install_complete(tool_id, version, false, mismatch)
				continue

		if _is_cancelled(tool_id, version):
			if FileAccess.file_exists(temp_archive):
				DirAccess.remove_absolute(temp_archive)
			result["failed_count"] += 1
			result["failed_tools"].append(tool_entry)
			_emit_tool_install_complete(tool_id, version, false, "Cancelled")
			continue

		_emit_tool_install_started(tool_id, version)
		var progress_cb = func(fc: int, tf: int): _emit_tool_install_progress(tool_id, version, fc, tf)
		var extract_thread = Thread.new()
		var extract_result: Dictionary
		extract_thread.start(func():
			extract_result = extractor.extract_to_library(temp_archive, tool_id, version, _is_cancelled.bind(tool_id, version), progress_cb)
		)
		var tree = scene_tree
		if tree == null:
			tree = Engine.get_main_loop() as SceneTree
			scene_tree = tree
		while extract_thread.is_alive():
			if tree != null:
				await tree.process_frame
			else:
				break
		extract_thread.wait_to_finish()
		
		# Second cancellation checkpoint: Abort and delete if cancelled during extraction
		if _is_cancelled(tool_id, version):
			if FileAccess.file_exists(temp_archive):
				DirAccess.remove_absolute(temp_archive)
			library.remove_tool(tool_id, version)
			result["failed_count"] += 1
			result["failed_tools"].append(tool_entry)
			_emit_tool_install_complete(tool_id, version, false, "Cancelled")
			continue
			
		if not extract_result["success"]:
			result["failed_count"] += 1
			result["failed_tools"].append(tool_entry)
			_emit_tool_install_complete(tool_id, version, false, extract_result["error_message"])
			continue

		if not library.tool_exists(tool_id, version):
			var validation_error = "Tool not found in library after extraction"
			result["failed_count"] += 1
			result["failed_tools"].append(tool_entry)
			_emit_tool_install_complete(tool_id, version, false, validation_error)
			continue
			
		# Write local metadata into the installed tool directory so it is entirely portable
		if repo_entry.has("executable_path"):
			var tool_dir = library.get_tool_path(tool_id, version)
			var metadata_path = tool_dir.path_join("ogs_metadata.json")
			var file = FileAccess.open(metadata_path, FileAccess.WRITE)
			if file:
				file.store_string(JSON.stringify({"executable_path": repo_entry["executable_path"]}, "  "))
				file.close()

		result["installed_count"] += 1
		_emit_tool_install_complete(tool_id, version, true, "")

	result["success"] = result["failed_count"] == 0
	OgsLogger.info("remote_hydration_complete", {
		"component": "mirror",
		"installed": result["installed_count"],
		"failed": result["failed_count"]
	})

	_emit_hydration_complete(result["success"], result["failed_tools"])
	return result

## Loads repository.json from the configured URL.
func _load_repository() -> Dictionary:
	## Loads and parses repository.json from the remote URL.
	var text_result = await _read_text_from_url(repository_url)
	if not text_result["success"]:
		return {"success": false, "error": text_result.get("error", "read_failed")}
	var repo = MirrorRepositoryScript.parse_json_string(text_result["text"])
	return {"success": true, "repository": repo}

## Reads text content from a URL or local file path.
func _read_text_from_url(url: String) -> Dictionary:
	## Reads text content from a URL or local file path.
	if _is_local_reference(url):
		var local_path = _resolve_local_path(url)
		if local_path.is_empty() or not FileAccess.file_exists(local_path):
			return {"success": false, "error": "local_file_missing"}
		var file = FileAccess.open(local_path, FileAccess.READ)
		if file == null:
			return {"success": false, "error": "local_file_unreadable"}
		var text = file.get_as_text()
		file.close()
		return {"success": true, "text": text}
	return await _http_get_text(url)

## Stages an archive either by copying a local file or downloading remote content.
func _stage_archive(archive_url: String, tool_id: String, version: String) -> String:
	## Stages a remote archive into a temp location and returns the path.
	var temp_dir = OS.get_cache_dir()
	if temp_dir.is_empty():
		temp_dir = OS.get_user_data_dir()
	if temp_dir.is_empty():
		return ""
	var safe_name = "%s_%s.zip" % [tool_id, version]
	var temp_path = temp_dir.path_join("ogs_remote_" + safe_name)
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_path)

	if _is_local_reference(archive_url):
		var local_path = _resolve_local_path(archive_url)
		if local_path.is_empty() or not FileAccess.file_exists(local_path):
			return ""
		return _copy_archive_to_temp(local_path, temp_path)

	var download_result = await _http_download_to_file(archive_url, temp_path, tool_id, version)
	if not download_result["success"]:
		OgsLogger.error("remote_archive_download_failed", {
			"component": "mirror",
			"error": download_result.get("error", "unknown")
		})
		return ""

	return temp_path

## Returns true if the reference points to a local file path.
func _is_local_reference(url: String) -> bool:
	## Returns true if the reference is a local path or file:// URL.
	if url.begins_with("file://"):
		return true
	if url.find("://") != -1:
		return false
	return url.is_absolute_path() or FileAccess.file_exists(url)

## Resolves file:// URLs or raw paths into a usable local path.
func _resolve_local_path(url: String) -> String:
	## Resolves a local file path from a URL or raw path.
	if url.begins_with("file://"):
		return url.replace("file://", "")
	return url

## Downloads a URL and returns its contents as text.
func _http_get_text(url: String) -> Dictionary:
	## Downloads a URL and returns response text.
	var byte_result = await _http_get_bytes(url)
	if not byte_result["success"]:
		return {"success": false, "error": byte_result.get("error", "http_failed")}
	return {"success": true, "text": byte_result["bytes"].get_string_from_utf8()}

## Downloads a URL to a local file.
func _http_download_to_file(url: String, dest_path: String, tool_id: String = "", version: String = "") -> Dictionary:
	## Downloads a URL to a local file, following redirects automatically.
	if FileAccess.file_exists(dest_path):
		DirAccess.remove_absolute(dest_path)
		
	var http = HTTPRequest.new()
	var tree = scene_tree if scene_tree != null else Engine.get_main_loop() as SceneTree
	if tree == null:
		return {"success": false, "error": "no_scene_tree"}
		
	tree.root.call_deferred("add_child", http)
	await tree.process_frame
		
	http.download_file = dest_path
	var err = http.request(url, ["User-Agent: OGS-Launcher"])
	if err != OK:
		http.queue_free()
		return {"success": false, "error": "request_failed"}
		
	var is_done = false
	var request_result = 0
	var response_code = 0
	
	http.request_completed.connect(func(res, code, _h, _b):
		is_done = true
		request_result = res
		response_code = code
	)
	
	while not is_done:
		if not tool_id.is_empty() and not version.is_empty():
			if _is_cancelled(tool_id, version):
				http.cancel_request()
				http.queue_free()
				if FileAccess.file_exists(dest_path):
					DirAccess.remove_absolute(dest_path)
				return {"success": false, "error": "cancelled"}
				
			var downloaded = http.get_downloaded_bytes()
			var total = http.get_body_size()
			if downloaded > 0:
				_emit_tool_download_progress(tool_id, version, downloaded, total if total > 0 else downloaded)
		
		await tree.create_timer(0.05).timeout
		
	http.queue_free()
	
	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "error": "http_status_%d" % response_code}
	if response_code < 200 or response_code >= 300:
		return {"success": false, "error": "http_status_%d" % response_code}
		
	return {"success": true}

## Downloads a URL and returns the bytes.
func _http_get_bytes(url: String) -> Dictionary:
	## Downloads a URL and returns bytes, following redirects automatically.
	var http = HTTPRequest.new()
	var tree = scene_tree if scene_tree != null else Engine.get_main_loop() as SceneTree
	if tree == null:
		return {"success": false, "error": "no_scene_tree"}
		
	tree.root.call_deferred("add_child", http)
	await tree.process_frame
		
	var err = http.request(url, ["User-Agent: OGS-Launcher"])
	if err != OK:
		http.queue_free()
		return {"success": false, "error": "request_failed"}
		
	var result = await http.request_completed
	http.queue_free()
	
	var req_result = result[0]
	var code = result[1]
	var body = result[3]
	
	if req_result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		return {"success": false, "error": "http_status_%d" % code}
		
	return {"success": true, "bytes": body}

## Computes sha256 for a file path using streaming reads.
static func _compute_sha256(file_path: String) -> Dictionary:
	## Computes the SHA-256 hash for a file.
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"success": false, "error_message": "Failed to read archive for hashing."}
	var hasher = HashingContext.new()
	var start_err = hasher.start(HashingContext.HASH_SHA256)
	if start_err != OK:
		file.close()
		return {"success": false, "error_message": "Failed to initialize hash context."}
	while not file.eof_reached():
		var chunk = file.get_buffer(1024 * 1024)
		if chunk.size() == 0:
			break
		hasher.update(chunk)
	file.close()
	var digest = hasher.finish()
	return {"success": true, "sha256": digest.hex_encode().to_lower()}

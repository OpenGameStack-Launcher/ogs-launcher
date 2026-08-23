## RemoteMirrorHydrator: Installs tools from a remote mirror repository into the library.
##
## Downloads repository.json from a remote URL (or local file URL), validates
## entries, fetches tool archives, verifies hashes, and extracts archives into
## the central library. This workflow respects offline enforcement.

extends RefCounted
class_name RemoteMirrorHydrator

const OgsLogger = preload("res://scripts/logging/logger.gd")

signal tool_install_started(tool_id: String, version: String)
signal tool_install_complete(tool_id: String, version: String, success: bool, error_message: String)
signal tool_download_progress(tool_id: String, version: String, bytes_downloaded: int, total_bytes: int)
signal hydration_complete(success: bool, failed_tools: Array)

const MirrorRepositoryScript = preload("res://scripts/mirror/mirror_repository.gd")

var repository_url: String = ""
var repository: MirrorRepository
var extractor: ToolExtractor
var library: LibraryManager
var worker_thread: Thread
var scene_tree: SceneTree = null

func _init(repo_url: String = "", tree: SceneTree = null):
	"""Initializes the remote mirror hydrator with a repository URL.
	Parameters:
	  repo_url (String): URL to the remote repository.json
	  tree (SceneTree): Optional scene tree for safe signal emission from threads
	"""
	repository_url = repo_url
	scene_tree = tree
	repository = MirrorRepositoryScript.new()
	extractor = ToolExtractor.new()
	library = LibraryManager.new()

## Sets the repository.json URL for this hydrator.
func set_repository_url(repo_url: String) -> void:
	"""Sets the remote repository URL."""
	repository_url = repo_url

## Hydrates missing tools from the remote mirror into the library.
## Parameters:
##   tools_to_install (Array): Array of {"tool_id": String, "version": String}
## Returns:
##   Dictionary: {"success": bool, "installed_count": int, "failed_count": int, "failed_tools": Array}
func hydrate(tools_to_install: Array) -> Dictionary:
	"""Installs tools from remote mirror archives into the library."""
	return _hydrate_internal(tools_to_install)

## Starts hydration in a background thread to keep the UI responsive.
func hydrate_async(tools_to_install: Array) -> void:
	"""Starts remote hydration in a background thread."""
	if worker_thread != null and worker_thread.is_alive():
		return
	worker_thread = Thread.new()
	worker_thread.start(Callable(self, "_hydrate_thread").bind(tools_to_install))

## Internal thread entry for hydration.
func _hydrate_thread(tools_to_install: Array) -> void:
	"""Runs hydration in a worker thread."""
	_hydrate_internal(tools_to_install)
	call_deferred("_finish_async")

## Finalizes the async hydration thread.
func _finish_async() -> void:
	"""Joins and clears the hydration worker thread."""
	if worker_thread != null:
		worker_thread.wait_to_finish()
		worker_thread = null

## Performs the hydration workflow synchronously.
func _hydrate_internal(tools_to_install: Array) -> Dictionary:
	"""Installs tools from remote mirror archives into the library."""
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

	var repo_result = _load_repository()
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

		_emit_tool_install_started(tool_id, version)

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

		var temp_archive = _stage_archive(archive_url, tool_id, version)
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

		var extract_result = extractor.extract_to_library(temp_archive, tool_id, version)
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

## Thread-safe signal helpers.
func _emit_tool_install_started(tool_id: String, version: String) -> void:
	"""Emits tool_install_started safely across threads."""
	if scene_tree != null:
		call_deferred("_emit_tool_install_started_now", tool_id, version)
	else:
		tool_install_started.emit(tool_id, version)

func _emit_tool_install_started_now(tool_id: String, version: String) -> void:
	"""Deferred emit for tool_install_started."""
	tool_install_started.emit(tool_id, version)

func _emit_tool_install_complete(tool_id: String, version: String, success: bool, error_message: String) -> void:
	"""Emits tool_install_complete safely across threads."""
	if scene_tree != null:
		call_deferred("_emit_tool_install_complete_now", tool_id, version, success, error_message)
	else:
		tool_install_complete.emit(tool_id, version, success, error_message)

func _emit_tool_install_complete_now(tool_id: String, version: String, success: bool, error_message: String) -> void:
	"""Deferred emit for tool_install_complete."""
	tool_install_complete.emit(tool_id, version, success, error_message)

func _emit_hydration_complete(success: bool, failed_tools: Array) -> void:
	"""Emits hydration_complete safely across threads."""
	if scene_tree != null:
		call_deferred("_emit_hydration_complete_now", success, failed_tools)
	else:
		hydration_complete.emit(success, failed_tools)

func _emit_hydration_complete_now(success: bool, failed_tools: Array) -> void:
	"""Deferred emit for hydration_complete."""
	hydration_complete.emit(success, failed_tools)

func _emit_tool_download_progress(tool_id: String, version: String, bytes_downloaded: int, total_bytes: int) -> void:
	"""Emits tool_download_progress safely across threads."""
	if scene_tree != null:
		call_deferred("_emit_tool_download_progress_now", tool_id, version, bytes_downloaded, total_bytes)
	else:
		tool_download_progress.emit(tool_id, version, bytes_downloaded, total_bytes)

func _emit_tool_download_progress_now(tool_id: String, version: String, bytes_downloaded: int, total_bytes: int) -> void:
	"""Deferred emit for tool_download_progress."""
	tool_download_progress.emit(tool_id, version, bytes_downloaded, total_bytes)

## Loads repository.json from the configured URL.
func _load_repository() -> Dictionary:
	"""Loads and parses repository.json from the remote URL."""
	var text_result = _read_text_from_url(repository_url)
	if not text_result["success"]:
		return {"success": false, "error": text_result.get("error", "read_failed")}
	var repo = MirrorRepositoryScript.parse_json_string(text_result["text"])
	return {"success": true, "repository": repo}

## Reads text content from a URL or local file path.
func _read_text_from_url(url: String) -> Dictionary:
	"""Reads text content from a URL or local file path."""
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
	return _http_get_text(url)

## Stages an archive either by copying a local file or downloading remote content.
func _stage_archive(archive_url: String, tool_id: String, version: String) -> String:
	"""Stages a remote archive into a temp location and returns the path."""
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

	var download_result = _http_download_to_file(archive_url, temp_path, "", 0, tool_id, version)
	if not download_result["success"]:
		OgsLogger.error("remote_archive_download_failed", {
			"component": "mirror",
			"error": download_result.get("error", "unknown")
		})
		return ""

	return temp_path

## Copies an archive to a temp path.
func _copy_archive_to_temp(source_path: String, temp_path: String) -> String:
	"""Copies a local archive to a temp path and returns the temp path."""
	var source = FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return ""
	var dest = FileAccess.open(temp_path, FileAccess.WRITE)
	if dest == null:
		source.close()
		return ""
	while not source.eof_reached():
		var chunk = source.get_buffer(1024 * 1024)
		if chunk.size() == 0:
			break
		dest.store_buffer(chunk)
	source.close()
	dest.close()
	return temp_path

## Returns true if the reference points to a local file path.
func _is_local_reference(url: String) -> bool:
	"""Returns true if the reference is a local path or file:// URL."""
	if url.begins_with("file://"):
		return true
	if url.find("://") != -1:
		return false
	return url.is_absolute_path() or FileAccess.file_exists(url)

## Resolves file:// URLs or raw paths into a usable local path.
func _resolve_local_path(url: String) -> String:
	"""Resolves a local file path from a URL or raw path."""
	if url.begins_with("file://"):
		return url.replace("file://", "")
	return url

## Downloads a URL and returns its contents as text.
func _http_get_text(url: String) -> Dictionary:
	"""Downloads a URL and returns response text."""
	var byte_result = _http_get_bytes(url)
	if not byte_result["success"]:
		return {"success": false, "error": byte_result.get("error", "http_failed")}
	return {"success": true, "text": byte_result["bytes"].get_string_from_utf8()}

## Downloads a URL to a local file.
func _http_download_to_file(url: String, dest_path: String, _redirect_url: String = "", redirect_count: int = 0, tool_id: String = "", version: String = "") -> Dictionary:
	"""Downloads a URL to a local file, following redirects.
	Parameters:
	  url: URL to download from
	  dest_path: Destination file path
	  _redirect_url: Internal parameter for recursion (unused, kept for compatibility)
	  redirect_count: Current redirect count
	  tool_id: Tool ID for progress signal emission
	  version: Tool version for progress signal emission
	"""
	if redirect_count > 5:
		return {"success": false, "error": "redirect_limit"}
	var parsed = _parse_url(url)
	if not parsed["success"]:
		return {"success": false, "error": "invalid_url"}
	var client = HTTPClient.new()
	var tls_options = TLSOptions.client() if parsed["use_tls"] else null
	var err = client.connect_to_host(parsed["host"], parsed["port"], tls_options)
	if err != OK:
		return {"success": false, "error": "connect_failed"}
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return {"success": false, "error": "connection_failed"}
	var request_err = client.request(HTTPClient.METHOD_GET, parsed["path"], ["User-Agent: OGS-Launcher"])
	if request_err != OK:
		return {"success": false, "error": "request_failed"}
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
	var status_code = client.get_response_code()
	var headers = _parse_headers(client.get_response_headers())
	if status_code >= 300 and status_code < 400:
		var location = String(headers.get("location", ""))
		if location.is_empty():
			return {"success": false, "error": "redirect_missing_location"}
		return _http_download_to_file(location, dest_path, "", redirect_count + 1, tool_id, version)
	if status_code < 200 or status_code >= 300:
		return {"success": false, "error": "http_status_%d" % status_code}
	var file = FileAccess.open(dest_path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "error": "write_failed"}
	
	# Extract content-length from headers for progress tracking
	var total_bytes = -1
	if "content-length" in headers:
		var content_length_str = String(headers.get("content-length", ""))
		if content_length_str.is_valid_int():
			total_bytes = int(content_length_str)
	
	var bytes_downloaded = 0
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk = client.read_response_body_chunk()
		if chunk.size() == 0:
			OS.delay_msec(10)
			continue
		file.store_buffer(chunk)
		bytes_downloaded += chunk.size()
		
		# Emit progress signal if we have tool_id and version
		if not tool_id.is_empty() and not version.is_empty():
			_emit_tool_download_progress(tool_id, version, bytes_downloaded, total_bytes if total_bytes > 0 else bytes_downloaded)
	
	file.close()
	return {"success": true}

## Downloads a URL and returns the bytes.
func _http_get_bytes(url: String, redirect_count: int = 0) -> Dictionary:
	"""Downloads a URL and returns bytes, following redirects."""
	if redirect_count > 5:
		return {"success": false, "error": "redirect_limit"}
	var response = _http_request(url)
	if not response["success"]:
		return response
	var status_code = int(response["status_code"])
	if status_code >= 300 and status_code < 400:
		var location = String(response.get("headers", {}).get("location", ""))
		if location.is_empty():
			return {"success": false, "error": "redirect_missing_location"}
		return _http_get_bytes(location, redirect_count + 1)
	if status_code < 200 or status_code >= 300:
		return {"success": false, "error": "http_status_%d" % status_code}
	var body = PackedByteArray()
	for chunk in response["body_chunks"]:
		body.append_array(chunk)
	return {"success": true, "bytes": body}

## Performs an HTTP request and returns response data.
func _http_request(url: String) -> Dictionary:
	"""Performs an HTTP GET request and returns status, headers, and body chunks."""
	var parsed = _parse_url(url)
	if not parsed["success"]:
		return {"success": false, "error": "invalid_url"}
	
	var client = HTTPClient.new()
	var tls_options = TLSOptions.client() if parsed["use_tls"] else null
	
	OgsLogger.debug("http_connecting", {
		"component": "mirror",
		"host": parsed["host"],
		"port": parsed["port"],
		"use_tls": parsed["use_tls"]
	})
	
	var err = client.connect_to_host(parsed["host"], parsed["port"], tls_options)
	if err != OK:
		OgsLogger.error("http_connect_error", {
			"component": "mirror",
			"error_code": err,
			"host": parsed["host"],
			"port": parsed["port"]
		})
		return {"success": false, "error": "connect_failed"}
	
	# Wait for connection with timeout
	var max_polls = 100  # ~1 second with 10ms delays
	var poll_count = 0
	while (client.get_status() == HTTPClient.STATUS_CONNECTING or 
		   client.get_status() == HTTPClient.STATUS_RESOLVING) and poll_count < max_polls:
		client.poll()
		OS.delay_msec(10)
		poll_count += 1
	
	var final_status = client.get_status()
	OgsLogger.debug("http_after_connect", {
		"component": "mirror",
		"status": _status_name(final_status),
		"poll_count": poll_count
	})
	
	if final_status != HTTPClient.STATUS_CONNECTED:
		OgsLogger.error("http_connection_failed", {
			"component": "mirror",
			"status": _status_name(final_status),
			"host": parsed["host"],
			"port": parsed["port"]
		})
		return {"success": false, "error": "connection_failed"}
	
	var request_err = client.request(HTTPClient.METHOD_GET, parsed["path"], ["User-Agent: OGS-Launcher"])
	if request_err != OK:
		OgsLogger.error("http_request_error", {
			"component": "mirror",
			"error_code": request_err,
			"path": parsed["path"]
		})
		return {"success": false, "error": "request_failed"}
	
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
	
	var status_code = client.get_response_code()
	var headers = _parse_headers(client.get_response_headers())
	var chunks: Array = []
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk = client.read_response_body_chunk()
		if chunk.size() == 0:
			OS.delay_msec(10)
			continue
		chunks.append(chunk)
	
	OgsLogger.debug("http_response_received", {
		"component": "mirror",
		"status_code": status_code,
		"chunk_count": chunks.size()
	})
	
	return {"success": true, "status_code": status_code, "headers": headers, "body_chunks": chunks}

## Parses response headers into a dictionary.
func _parse_headers(headers: Array) -> Dictionary:
	"""Parses response headers into a lowercased dictionary."""
	var result: Dictionary = {}
	for header in headers:
		var parts = String(header).split(":", true, 1)
		if parts.size() == 2:
			result[parts[0].strip_edges().to_lower()] = parts[1].strip_edges()
	return result

## Helper to convert HTTPClient status code to name.
func _status_name(status: int) -> String:
	"""Converts HTTPClient status constant to readable name."""
	match status:
		HTTPClient.STATUS_DISCONNECTED: return "DISCONNECTED"
		HTTPClient.STATUS_RESOLVING: return "RESOLVING"
		HTTPClient.STATUS_CONNECTING: return "CONNECTING"
		HTTPClient.STATUS_CONNECTED: return "CONNECTED"
		HTTPClient.STATUS_REQUESTING: return "REQUESTING"
		HTTPClient.STATUS_BODY: return "BODY"
		HTTPClient.STATUS_CONNECTION_ERROR: return "CONNECTION_ERROR"
		_: return "UNKNOWN(%d)" % status

## Parses a URL into host/port/path fields.
func _parse_url(url: String) -> Dictionary:
	"""Parses a URL into components for HTTPClient."""
	if url.begins_with("https://"):
		return _build_url_parts(url, "https://", true, 443)
	if url.begins_with("http://"):
		return _build_url_parts(url, "http://", false, 80)
	return {"success": false}

## Builds URL parts based on the scheme.
func _build_url_parts(url: String, scheme: String, use_tls: bool, default_port: int) -> Dictionary:
	"""Builds URL parts for HTTPClient."""
	var remainder = url.substr(scheme.length())
	var slash_index = remainder.find("/")
	var host = remainder
	var path = "/"
	if slash_index != -1:
		host = remainder.substr(0, slash_index)
		path = remainder.substr(slash_index)
	if host.find(":") != -1:
		var host_parts = host.split(":", true, 1)
		host = host_parts[0]
		var port = int(host_parts[1])
		return {"success": true, "host": host, "port": port, "path": path, "use_tls": use_tls}
	return {"success": true, "host": host, "port": default_port, "path": path, "use_tls": use_tls}

## Computes sha256 for a file path using streaming reads.
static func _compute_sha256(file_path: String) -> Dictionary:
	"""Computes the SHA-256 hash for a file."""
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

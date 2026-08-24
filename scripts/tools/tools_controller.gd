## ToolsController: Manages the Tools page UI and tool discovery.
##
## Responsibilities:
## - Fetch remote repository.json on startup (with offline fallback)
## - Determine which tools are installed vs available
## - Categorize tools using ToolCategoryMapper
## - Provide structured data for UI rendering
## - Handle tool download requests
##
## Usage:
## var controller = ToolsController.new(scene_tree, config)
## controller.refresh_tool_list()
## var tools = controller.get_categorized_tools()

extends RefCounted
class_name ToolsController

const OgsLogger = preload("res://scripts/logging/logger.gd")

signal tool_list_updated()
signal tool_list_refresh_failed(error_message: String)
signal tool_download_started(tool_id: String, version: String)
signal tool_download_complete(tool_id: String, version: String, success: bool, error_message: String)
signal tool_download_progress(tool_id: String, version: String, bytes_downloaded: int, total_bytes: int)
signal tool_install_started(tool_id: String, version: String)
signal tool_install_progress(tool_id: String, version: String, file_count: int, total_files: int)
signal connectivity_checked(is_online: bool)

var remote_repository_url: String
var library: LibraryManager
var remote_hydrator: RemoteMirrorHydrator
var repository: MirrorRepository  # Populated after fetching repository.json
var scene_tree: SceneTree

var _available_tools: Array = []  # Tools from repository.json
var _installed_tools: Dictionary = {}  # {tool_id: [versions]}
var _is_loading: bool = false
var _last_error: String = ""
var _is_online: bool = false
var _currently_downloading: Dictionary = {}  # {tool_id+version: true}

func _init(tree: SceneTree, repo_url: String) -> void:
	## Initializes the tools controller.
	## Parameters:
	##   tree (SceneTree): Scene tree for signal handling
	##   repo_url (String): Remote repository.json URL
	scene_tree = tree
	remote_repository_url = repo_url
	library = LibraryManager.new()
	repository = null  # Will be populated after fetch
	
	remote_hydrator = RemoteMirrorHydrator.new(remote_repository_url, scene_tree)
	
	# Connect hydrator signals for progress tracking
	remote_hydrator.tool_download_progress.connect(_on_download_progress)
	remote_hydrator.tool_install_started.connect(_on_install_started)
	remote_hydrator.tool_install_progress.connect(_on_install_progress)
	remote_hydrator.tool_install_complete.connect(_on_install_complete)

## Refreshes the tool list by fetching remote repository.json and scanning library.
func refresh_tool_list() -> void:
	## Fetches repository.json and updates tool availability.
	if _is_loading:
		return
	
	_is_loading = true
	_last_error = ""
	
	OgsLogger.info("tools_refresh_started", {
		"component": "tools",
		"context": "user_initiated"
	})
	
	# Fetch remote repository.json
	if remote_repository_url.is_empty():
		_last_error = "No remote repository URL configured"
		OgsLogger.warn("tools_refresh_no_url", {
			"component": "tools",
			"reason": "remote_url_empty"
		})
		_finalize_refresh(false)
		return
	
	var guard = OfflineEnforcer.guard_network_call("tools_refresh")
	if not guard["allowed"]:
		_last_error = guard["error_message"]
		OgsLogger.info("tools_refresh_offline", {
			"component": "tools",
			"reason": "offline_mode_active"
		})
		_finalize_refresh(false)
		return
	
	# Fetch repository.json
	var http = HTTPRequest.new()
	scene_tree.root.add_child(http)
	http.request_completed.connect(_on_repository_fetched.bind(http))
	
	var err = http.request(remote_repository_url)
	if err != OK:
		_last_error = "Failed to start HTTP request: " + str(err)
		OgsLogger.error("tools_refresh_http_failed", {
			"component": "tools",
			"url": remote_repository_url,
			"error": err
		})
		http.queue_free()
		_finalize_refresh(false)

## HTTP callback for repository.json fetch.
func _on_repository_fetched(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	## Handles repository.json download completion.
	http.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_last_error = "HTTP request failed: code %d" % response_code
		OgsLogger.error("tools_refresh_http_error", {
			"component": "tools",
			"result": result,
			"response_code": response_code
		})
		_finalize_refresh(false)
		return
	
	var json_text = body.get_string_from_utf8()
	
	# Parse and validate repository using static factory method
	repository = MirrorRepository.parse_json_string(json_text)
	
	if not repository.is_valid():
		_last_error = "Invalid repository.json: " + ", ".join(repository.errors)
		OgsLogger.error("tools_refresh_validation_failed", {
			"component": "tools",
			"errors": repository.errors
		})
		_finalize_refresh(false)
		return
	
	# Store available tools
	_available_tools = repository.tools
	
	# Scan installed tools from library
	_scan_installed_tools()
	
	OgsLogger.info("tools_refresh_success", {
		"component": "tools",
		"available_count": _available_tools.size(),
		"installed_count": _get_installed_count()
	})
	
	_finalize_refresh(true)

## Scans the library for installed tools.
func _scan_installed_tools() -> void:
	## Updates _installed_tools with library contents.
	_installed_tools.clear()
	
	var tool_ids = library.get_available_tools()
	for tool_id in tool_ids:
		var versions = library.get_available_versions(tool_id)
		if not versions.is_empty():
			_installed_tools[tool_id] = versions

## Finalizes the refresh operation.
func _finalize_refresh(success: bool) -> void:
	## Completes refresh and emits signals.
	_is_loading = false
	
	if success:
		tool_list_updated.emit()
	else:
		tool_list_refresh_failed.emit(_last_error)

## Returns categorized tools for UI display.
## Returns:
## Dictionary: {
## "Engine": [{"id": "godot", "version": "4.7.2", "installed": true, ...}],
## "2D": [...],
## "3D": [...],
## "Audio": [...]
## }
func get_categorized_tools() -> Dictionary:
	## Returns tools organized by category.
	var categorized: Dictionary = {}
	
	# Initialize categories
	for category in ToolCategoryMapper.get_all_categories():
		categorized[category] = []
	
	# Categorize available tools
	for tool in _available_tools:
		var category = ToolCategoryMapper.get_category_for_tool(tool)
		var tool_id = tool["id"]
		var version = tool["version"]
		var is_installed = _is_tool_installed(tool_id, version)
		
		categorized[category].append({
			"id": tool_id,
			"version": version,
			"installed": is_installed,
			"category": category,
			"size_bytes": tool.get("size_bytes", 0),
			"sha256": tool.get("sha256", ""),
			"archive_url": tool.get("archive_url", ""),
			"info_url": tool.get("info_url", "")
		})
	
	return categorized

## Checks if a specific tool version is installed.
func _is_tool_installed(tool_id: String, version: String) -> bool:
	## Returns true if tool version exists in library.
	return library.tool_exists(tool_id, version)

## Returns total count of installed tool versions.
func _get_installed_count() -> int:
	## Counts installed tool versions.
	var count = 0
	for versions in _installed_tools.values():
		count += versions.size()
	return count

## Downloads and installs a tool from the remote repository.
func download_tool(tool_id: String, version: String) -> void:
	## Initiates download and installation of a tool.
## Parameters:
## tool_id (String): Tool identifier
## version (String): Version string
## 
	var key = "%s_%s" % [tool_id, version]
	
	# Check if already downloading
	if _currently_downloading.get(key, false):
		OgsLogger.warn("tool_already_downloading", {
			"component": "tools",
			"tool_id": tool_id,
			"version": version
		})
		return
	
	OgsLogger.info("tool_download_requested", {
		"component": "tools",
		"tool_id": tool_id,
		"version": version
	})
	
	# Verify tool exists in repository
	if repository == null:
		OgsLogger.error("tool_download_no_repository", {
			"component": "tools",
			"tool_id": tool_id,
			"version": version
		})
		return
	
	var tool = repository.get_tool_entry(tool_id, version)
	if tool.is_empty():
		OgsLogger.error("tool_download_not_found", {
			"component": "tools",
			"tool_id": tool_id,
			"version": version
		})
		return
	
	# Mark as downloading
	_currently_downloading[key] = true
	
	# Start async download
	remote_hydrator.hydrate_async([{"tool_id": tool_id, "version": version}])

## Signal handlers for download progress.
func _on_download_progress(tool_id: String, version: String, bytes_downloaded: int, total_bytes: int) -> void:
	## Forwards download progress signals.
	tool_download_progress.emit(tool_id, version, bytes_downloaded, total_bytes)

func _on_install_started(tool_id: String, version: String) -> void:
	## Forwards install started signals.
	tool_install_started.emit(tool_id, version)

func _on_install_progress(tool_id: String, version: String, file_count: int, total_files: int) -> void:
	## Forwards install progress signals.
	tool_install_progress.emit(tool_id, version, file_count, total_files)

func _on_install_complete(tool_id: String, version: String, success: bool, error_message: String) -> void:
	## Handles install completion.
	var key = "%s_%s" % [tool_id, version]
	_currently_downloading.erase(key)
	
	if success:
		# Rescan library to update UI
		_scan_installed_tools()
		tool_list_updated.emit()
	
	tool_download_complete.emit(tool_id, version, success, error_message)
	
	OgsLogger.info("tool_download_complete", {
		"component": "tools",
		"tool_id": tool_id,
		"version": version,
		"success": success,
		"error": error_message
	})

## Returns true if currently loading repository.
func is_loading() -> bool:
	## Returns true if refresh is in progress.
	return _is_loading

## Returns the last error message if refresh failed.
func get_last_error() -> String:
	## Returns last error message.
	return _last_error

## Returns true if repository data is available.
func has_repository_data() -> bool:
	## Returns true if tools have been loaded.
	return not _available_tools.is_empty()

## Checks connectivity to GitHub by performing a lightweight HEAD request.
func check_connectivity() -> void:
	## Performs a HEAD request to check if GitHub is reachable.
	if remote_repository_url.is_empty():
		_is_online = false
		connectivity_checked.emit(false)
		return
	
	var guard = OfflineEnforcer.guard_network_call("tools_connectivity_check")
	if not guard["allowed"]:
		_is_online = false
		connectivity_checked.emit(false)
		OgsLogger.debug("tools_connectivity_offline", {
			"component": "tools",
			"reason": "offline_mode_active"
		})
		return
	
	# Use HEAD request for minimal bandwidth
	var http = HTTPRequest.new()
	scene_tree.root.add_child(http)
	http.request_completed.connect(_on_connectivity_checked.bind(http))
	
	var err = http.request(remote_repository_url, PackedStringArray(), HTTPClient.METHOD_HEAD)
	if err != OK:
		_is_online = false
		connectivity_checked.emit(false)
		http.queue_free()
		OgsLogger.debug("tools_connectivity_failed", {
			"component": "tools",
			"error": err
		})

## HTTP callback for connectivity check.
func _on_connectivity_checked(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, http: HTTPRequest) -> void:
	## Handles connectivity check completion.
	http.queue_free()
	
	_is_online = (result == HTTPRequest.RESULT_SUCCESS and (response_code == 200 or response_code == 304))
	connectivity_checked.emit(_is_online)
	
	OgsLogger.debug("tools_connectivity_result", {
		"component": "tools",
		"online": _is_online,
		"result": result,
		"response_code": response_code
	})

## Returns current online status.
func is_online() -> bool:
	## Returns true if last connectivity check succeeded.
	return _is_online

## Returns true if a tool is currently downloading.
func is_downloading(tool_id: String, version: String) -> bool:
	## Checks if a specific tool is currently being downloaded.
	var key = "%s_%s" % [tool_id, version]
	return _currently_downloading.get(key, false)

## Returns true if any tool download is active.
func has_active_downloads() -> bool:
	## Checks if any downloads are currently in progress.
	return not _currently_downloading.is_empty()

## Cancels an active download (if supported by hydrator).
func cancel_download(tool_id: String, version: String) -> void:
	## Attempts to cancel an ongoing download.
## Parameters:
## tool_id (String): Tool identifier
## version (String): Version string
## 
	var key = "%s_%s" % [tool_id, version]
	# Intentionally NOT erasing from _currently_downloading here so the UI knows it's still busy cancelling/cleaning up.
	# The key will be erased when the hydrator emits tool_install_complete with success=false.
	
	if remote_hydrator != null and remote_hydrator.has_method("cancel_download"):
		remote_hydrator.cancel_download(tool_id, version)
	
	OgsLogger.info("tool_download_cancelled", {
		"component": "tools",
		"tool_id": tool_id,
		"version": version
	})

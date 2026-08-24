## MirrorHydrator: Installs tools from a local mirror into the central library.
##
## Loads repository.json from a mirror root, validates tool archives,
## verifies hashes, and extracts archives into the library. This workflow
## is offline-only and performs no network access.

extends "res://scripts/mirror/base_hydrator.gd"
class_name MirrorHydrator

const OgsLogger = preload("res://scripts/logging/logger.gd")
const CryptoUtils = preload("res://scripts/utils/crypto_utils.gd")

var mirror_root: String = ""
var repository: MirrorRepository
var path_resolver: MirrorPathResolver
var extractor: ToolExtractor
var library: LibraryManager
var worker_thread: Thread

func _init(root_path: String = "", tree: SceneTree = null) -> void:
	## Initializes the mirror hydrator with a mirror root path.
	## Parameters:
	##   root_path (String): Path to the local mirror root
	##   tree (SceneTree): Optional scene tree for safe signal emission from threads
	mirror_root = root_path
	scene_tree = tree
	repository = MirrorRepository.new()
	path_resolver = MirrorPathResolver.new()
	extractor = ToolExtractor.new()
	library = LibraryManager.new()

## Sets the mirror root directory for this hydrator.
func set_mirror_root(root_path: String) -> void:
	## Sets the mirror root directory.
	mirror_root = root_path

## Hydrates missing tools from the mirror into the library.
## Parameters:
## tools_to_install (Array): Array of {"tool_id": String, "version": String}
## Returns:
## Dictionary: {"success": bool, "installed_count": int, "failed_count": int, "failed_tools": Array}
func hydrate(tools_to_install: Array) -> Dictionary:
	## Installs tools from mirror archives into the library.
	return _hydrate_internal(tools_to_install)

## Starts hydration in a background thread to keep the UI responsive.
func hydrate_async(tools_to_install: Array) -> void:
	## Starts mirror hydration in a background thread.
	if worker_thread != null and worker_thread.is_alive():
		return
	worker_thread = Thread.new()
	worker_thread.start(Callable(self, "_hydrate_thread").bind(tools_to_install))

## Internal thread entry for hydration.
func _hydrate_thread(tools_to_install: Array) -> void:
	## Runs hydration in a worker thread.
	_hydrate_internal(tools_to_install)
	call_deferred("_finish_async")

## Finalizes the async hydration thread.
func _finish_async() -> void:
	## Joins and clears the hydration worker thread.
	if worker_thread != null:
		worker_thread.wait_to_finish()
		worker_thread = null

## Performs the hydration workflow synchronously.
func _hydrate_internal(tools_to_install: Array) -> Dictionary:
	## Installs tools from mirror archives into the library.
	var result = {
		"success": true,
		"installed_count": 0,
		"failed_count": 0,
		"failed_tools": []
	}

	if tools_to_install.is_empty():
		OgsLogger.info("mirror_hydration_complete", {
			"component": "mirror",
			"reason": "no tools to install"
		})
		_emit_hydration_complete(true, [])
		return result

	var repo_path = mirror_root.path_join("repository.json")
	repository = MirrorRepository.load_from_file(repo_path)
	if not repository.is_valid():
		result["success"] = false
		result["failed_count"] = tools_to_install.size()
		result["failed_tools"] = tools_to_install
		OgsLogger.error("mirror_repo_invalid", {
			"component": "mirror",
			"error_count": repository.errors.size()
		})
		_emit_hydration_complete(false, tools_to_install)
		return result

	OgsLogger.info("mirror_hydration_started", {
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
			OgsLogger.debug("mirror_tool_skip", {
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
			var missing_msg = "Tool not found in repository"
			OgsLogger.error("mirror_tool_missing", {
				"component": "mirror",
				"tool_id": tool_id,
				"version": version
			})
			result["failed_count"] += 1
			result["failed_tools"].append(tool_entry)
			_emit_tool_install_complete(tool_id, version, false, missing_msg)
			continue

		var archive_path = String(repo_entry.get("archive_path", ""))
		var resolve_result = path_resolver.resolve_archive_path(mirror_root, archive_path)
		if not resolve_result["success"]:
			var resolve_error = String(resolve_result.get("error", ""))
			OgsLogger.error("mirror_archive_invalid", {
				"component": "mirror",
				"tool_id": tool_id,
				"version": version,
				"reason": resolve_error
			})
			result["failed_count"] += 1
			result["failed_tools"].append(tool_entry)
			_emit_tool_install_complete(tool_id, version, false, resolve_error)
			continue

		var full_archive_path = String(resolve_result["full_path"])
		if not FileAccess.file_exists(full_archive_path):
			var missing_archive = "Archive file not found"
			OgsLogger.error("mirror_archive_missing", {
				"component": "mirror",
				"tool_id": tool_id,
				"version": version
			})
			result["failed_count"] += 1
			result["failed_tools"].append(tool_entry)
			_emit_tool_install_complete(tool_id, version, false, missing_archive)
			continue

		var sha_value = String(repo_entry.get("sha256", "")).strip_edges().to_lower()
		if not sha_value.is_empty():
			var hash_result = CryptoUtils.compute_sha256(full_archive_path)
			if not hash_result["success"]:
				result["failed_count"] += 1
				result["failed_tools"].append(tool_entry)
				_emit_tool_install_complete(tool_id, version, false, hash_result["error_message"])
				continue
			if hash_result["sha256"] != sha_value:
				var mismatch = "Archive sha256 does not match repository"
				OgsLogger.error("mirror_hash_mismatch", {
					"component": "mirror",
					"tool_id": tool_id,
					"version": version
				})
				result["failed_count"] += 1
				result["failed_tools"].append(tool_entry)
				_emit_tool_install_complete(tool_id, version, false, mismatch)
				continue

		var temp_dir = OS.get_cache_dir()
		if temp_dir.is_empty():
			temp_dir = OS.get_user_data_dir()
		var temp_archive = ""
		if not temp_dir.is_empty():
			var safe_name = "%s_%s.zip" % [tool_id, version]
			var temp_path = temp_dir.path_join("ogs_mirror_" + safe_name)
			if FileAccess.file_exists(temp_path):
				DirAccess.remove_absolute(temp_path)
			temp_archive = _copy_archive_to_temp(full_archive_path, temp_path)

		if temp_archive.is_empty():
			var copy_error = "Failed to stage archive in temp directory"
			result["failed_count"] += 1
			result["failed_tools"].append(tool_entry)
			_emit_tool_install_complete(tool_id, version, false, copy_error)
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

		result["installed_count"] += 1
		_emit_tool_install_complete(tool_id, version, true, "")

	result["success"] = result["failed_count"] == 0
	OgsLogger.info("mirror_hydration_complete", {
		"component": "mirror",
		"installed": result["installed_count"],
		"failed": result["failed_count"]
	})
	
	_emit_hydration_complete(result["success"], result["failed_tools"])
	return result

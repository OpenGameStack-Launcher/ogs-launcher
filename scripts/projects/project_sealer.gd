## ProjectSealer: Converts a linked project to a sealed, self-contained artifact.
##
## Implements the "Seal for Delivery" protocol: takes a project with linked tools
## from the central library and creates a sealed, offline-ready deliverable.
##
## Workflow:
## 1. Validate project has ogs_stack.json and all required tools exist in library
## 2. Create ./ogs_tools directory and copy tool binaries from library
## 3. Write ogs_config.json with force_offline=true
## 4. Create a sealed zip archive: [ProjectName]_Sealed_[Date].zip
##
## Result Dictionary:
## {
## "success": bool,
## "sealed_zip": String,        # Path to created zip (if success)
## "project_size_mb": float,    # Size of sealed artifact (if success)
## "tools_copied": Array[String], # Tool IDs that were copied
## "errors": Array[String]      # Error messages if failure
## }
##
## Usage:
## var sealer = ProjectSealer.new()
## var result = sealer.seal_project("/path/to/project")
## if result.success:
## print("Sealed: " + result.sealed_zip)
## else:
## print("Error: " + str(result.errors))

extends RefCounted
class_name ProjectSealer

const OgsLogger = preload("res://scripts/logging/logger.gd")

const SealValidatorScript = preload("res://scripts/projects/project_seal_validator.gd")
const SealToolCopierScript = preload("res://scripts/projects/project_seal_tool_copier.gd")
const SealConfigWriterScript = preload("res://scripts/projects/project_seal_config_writer.gd")
const SealArchiverScript = preload("res://scripts/projects/project_seal_archiver.gd")

var library: LibraryManager
var validator
var copier
var config_writer
var archiver

var _cancel_mutex: Mutex = Mutex.new()
var _cancel_requested: bool = false

func _init() -> void:
	library = LibraryManager.new()
	validator = SealValidatorScript.new()
	copier = SealToolCopierScript.new()
	config_writer = SealConfigWriterScript.new()
	archiver = SealArchiverScript.new()

## Signals cancellation to in-progress seal operation.
func request_cancel() -> void:
	## Sets internal cancel flag in a thread-safe manner.
	_cancel_mutex.lock()
	_cancel_requested = true
	_cancel_mutex.unlock()

## Checks whether cancellation has been requested.
func is_cancelled() -> bool:
	## Returns true if cancel was requested on this sealer.
	_cancel_mutex.lock()
	var req: bool = _cancel_requested
	_cancel_mutex.unlock()
	return req

## Checks combined internal and external cancellation conditions.
func _is_cancelled(cancel_check: Callable = Callable()) -> bool:
	if is_cancelled():
		return true
	if cancel_check.is_valid():
		return bool(cancel_check.call())
	return false

## Captures pre-seal state of project directory for safe rollback.
func _capture_pre_seal_snapshot(project_path: String) -> Dictionary:
	var snapshot: Dictionary = {
		"tools_dir_existed": false,
		"pre_existing_tool_subdirs": [] as Array[String],
		"config_existed": false,
		"pre_seal_config_content": ""
	}

	var tools_dir = project_path.path_join("ogs_tools")
	if DirAccess.dir_exists_absolute(tools_dir):
		snapshot["tools_dir_existed"] = true
		var dir = DirAccess.open(tools_dir)
		if dir != null:
			dir.list_dir_begin()
			var name = dir.get_next()
			while name != "":
				if name != "." and name != "..":
					if dir.current_is_dir():
						snapshot["pre_existing_tool_subdirs"].append(name)
				name = dir.get_next()
			dir.list_dir_end()

	var config_path = project_path.path_join("ogs_config.json")
	if FileAccess.file_exists(config_path):
		snapshot["config_existed"] = true
		var cfg_file = FileAccess.open(config_path, FileAccess.READ)
		if cfg_file != null:
			snapshot["pre_seal_config_content"] = cfg_file.get_as_text()
			cfg_file.close()

	return snapshot

## Rolls back any disk mutations made during sealing.
func _rollback(project_path: String, snapshot: Dictionary, partial_zip_path: String = "") -> void:
	OgsLogger.info("seal_rollback_started", {
		"component": "sealer",
		"project_path": project_path
	})

	# 1. Remove partial ZIP archive if present
	if not partial_zip_path.is_empty() and FileAccess.file_exists(partial_zip_path):
		var rm_zip_err = DirAccess.remove_absolute(partial_zip_path)
		if rm_zip_err != OK:
			OgsLogger.warn("seal_rollback_zip_remove_failed", {
				"component": "sealer",
				"zip_path": partial_zip_path,
				"error": error_string(rm_zip_err)
			})
	if is_instance_valid(archiver) and not archiver.current_zip_path.is_empty() and FileAccess.file_exists(archiver.current_zip_path):
		DirAccess.remove_absolute(archiver.current_zip_path)
		archiver.current_zip_path = ""

	# 2. Revert ogs_tools directory
	var tools_dir = project_path.path_join("ogs_tools")
	if snapshot.get("tools_dir_existed", false):
		if DirAccess.dir_exists_absolute(tools_dir):
			var pre_existing: Array = snapshot.get("pre_existing_tool_subdirs", [])
			var dir = DirAccess.open(tools_dir)
			if dir != null:
				dir.list_dir_begin()
				var name = dir.get_next()
				var to_remove: Array[String] = []
				while name != "":
					if name != "." and name != "..":
						if dir.current_is_dir() and not pre_existing.has(name):
							to_remove.append(tools_dir.path_join(name))
					name = dir.get_next()
				dir.list_dir_end()
				for sub in to_remove:
					_remove_dir_recursive(sub)
	else:
		if DirAccess.dir_exists_absolute(tools_dir):
			_remove_dir_recursive(tools_dir)

	# 3. Revert ogs_config.json
	var config_path = project_path.path_join("ogs_config.json")
	if snapshot.get("config_existed", false):
		var f = FileAccess.open(config_path, FileAccess.WRITE)
		if f != null:
			f.store_string(snapshot.get("pre_seal_config_content", ""))
			f.close()
	else:
		if FileAccess.file_exists(config_path):
			DirAccess.remove_absolute(config_path)

	OgsLogger.info("seal_rollback_completed", {
		"component": "sealer",
		"project_path": project_path
	})

## Recursively deletes a directory and all contained files.
static func _remove_dir_recursive(path: String) -> void:
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return

	var dir = DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var item_path = path.path_join(name)
			if dir.current_is_dir():
				_remove_dir_recursive(item_path)
			else:
				DirAccess.remove_absolute(item_path)
		name = dir.get_next()

	dir.list_dir_end()
	DirAccess.remove_absolute(path)

## Main entry point: seals a project for offline delivery.
## Parameters:
## project_path (String): Absolute path to the project directory
## progress_callback (Callable): Optional callback for progress reporting (phase, current, total)
## cancel_check (Callable): Optional callback returning bool to check for cooperative cancellation
## Returns:
## Dictionary: Seal operation result with success flag and metadata
func seal_project(
	project_path: String,
	progress_callback: Callable = Callable(),
	cancel_check: Callable = Callable()
) -> Dictionary:
	var result = {
		"success": false,
		"cancelled": false,
		"sealed_zip": "",
		"project_size_mb": 0.0,
		"tools_copied": [],
		"errors": []
	}
	
	if project_path.is_empty():
		result.errors.append("Project path cannot be empty")
		OgsLogger.error("seal_project_invalid_path", {
			"component": "sealer",
			"reason": "empty project path"
		})
		return result
	
	# Normalize path
	project_path = project_path.trim_suffix("/")
	
	# Check cancellation before starting
	if _is_cancelled(cancel_check):
		result.cancelled = true
		result.errors.append("Seal cancelled by user.")
		return result

	# Step 1: Validate project
	OgsLogger.info("seal_project_starting", {
		"component": "sealer",
		"project_path": project_path
	})
	
	var validation = _validate_project(project_path)
	if not validation.success:
		result.errors = validation.errors
		OgsLogger.error("seal_project_validation_failed", {
			"component": "sealer",
			"project_path": project_path,
			"errors": validation.errors
		})
		return result

	var combined_cancel = func() -> bool:
		return _is_cancelled(cancel_check)

	if combined_cancel.call():
		result.cancelled = true
		result.errors.append("Seal cancelled by user.")
		return result

	# Capture pre-seal snapshot before any disk modifications
	var snapshot: Dictionary = _capture_pre_seal_snapshot(project_path)

	# Step 2: Copy tools to local ./ogs_tools directory
	var copy_result = _copy_tools_to_local(project_path, validation.manifest, progress_callback, combined_cancel)
	if copy_result.get("cancelled", false) or combined_cancel.call():
		_rollback(project_path, snapshot)
		result.cancelled = true
		result.errors.append("Seal cancelled by user.")
		OgsLogger.info("seal_project_cancelled_during_copy", {
			"component": "sealer",
			"project_path": project_path
		})
		return result

	if not copy_result.success:
		_rollback(project_path, snapshot)
		result.errors = copy_result.errors
		OgsLogger.error("seal_project_copy_failed", {
			"component": "sealer",
			"project_path": project_path,
			"errors": copy_result.errors
		})
		return result
	
	result.tools_copied = copy_result.tools_copied
	
	# Step 3: Write offline config
	if combined_cancel.call():
		_rollback(project_path, snapshot)
		result.cancelled = true
		result.errors.append("Seal cancelled by user.")
		return result

	var config_result = _write_offline_config(project_path)
	if not config_result.success:
		_rollback(project_path, snapshot)
		result.errors = config_result.errors
		OgsLogger.error("seal_project_config_failed", {
			"component": "sealer",
			"project_path": project_path,
			"errors": config_result.errors
		})
		return result
	
	# Step 4: Create sealed zip
	if combined_cancel.call():
		_rollback(project_path, snapshot)
		result.cancelled = true
		result.errors.append("Seal cancelled by user.")
		return result

	var zip_result = _create_sealed_zip(project_path, progress_callback, combined_cancel)
	if zip_result.get("cancelled", false) or combined_cancel.call():
		var partial_zip: String = zip_result.get("zip_path", "")
		_rollback(project_path, snapshot, partial_zip)
		result.cancelled = true
		result.errors.append("Seal cancelled by user.")
		OgsLogger.info("seal_project_cancelled_during_archiving", {
			"component": "sealer",
			"project_path": project_path
		})
		return result

	if not zip_result.success:
		var partial_zip: String = zip_result.get("zip_path", "")
		_rollback(project_path, snapshot, partial_zip)
		result.errors = zip_result.errors
		OgsLogger.error("seal_project_zip_failed", {
			"component": "sealer",
			"project_path": project_path,
			"errors": zip_result.errors
		})
		return result
	
	result.success = true
	result.sealed_zip = zip_result.zip_path
	result.project_size_mb = zip_result.size_mb
	
	OgsLogger.info("seal_project_complete", {
		"component": "sealer",
		"project_path": project_path,
		"sealed_zip": result.sealed_zip,
		"size_mb": result.project_size_mb,
		"tools_count": result.tools_copied.size()
	})
	
	return result

## Validates that the project exists, has ogs_stack.json, and all required tools are in library.
## Returns: {"success": bool, "errors": Array, "manifest": StackManifest}
func _validate_project(project_path: String) -> Dictionary:
	## Delegates project pre-seal validation to ProjectSealValidator.
	return validator.validate_project(project_path, library)

## Copies all tools from library to project's ./ogs_tools directory.
## Returns: {"success": bool, "cancelled": bool, "errors": Array, "tools_copied": Array}
func _copy_tools_to_local(
	project_path: String,
	manifest: StackManifest,
	progress_callback: Callable = Callable(),
	cancel_check: Callable = Callable()
) -> Dictionary:
	## Delegates library-to-project tool copy operations to ProjectSealToolCopier.
	return copier.copy_tools_to_local(project_path, manifest, library, progress_callback, cancel_check)

## Writes ogs_config.json with force_offline=true to project root.
## Returns: {"success": bool, "errors": Array}
func _write_offline_config(project_path: String) -> Dictionary:
	## Delegates offline config writing to ProjectSealConfigWriter.
	return config_writer.write_offline_config(project_path)

## Creates a sealed zip archive of the entire project.
## Returns: {"success": bool, "cancelled": bool, "errors": Array, "zip_path": String, "size_mb": float}
func _create_sealed_zip(
	project_path: String,
	progress_callback: Callable = Callable(),
	cancel_check: Callable = Callable()
) -> Dictionary:
	## Delegates zip packaging to ProjectSealArchiver.
	return archiver.create_sealed_zip(project_path, progress_callback, cancel_check)


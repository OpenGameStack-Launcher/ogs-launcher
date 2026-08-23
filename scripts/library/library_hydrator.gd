## LibraryHydrator: Orchestrates downloading and installing tools to the library.
##
## Manages the complete workflow of hydrating missing tools:
##   1. Takes a list of missing tools
##   2. Downloads each from the mirror
##   3. Extracts to the library
##   4. Reports progress and completion
##
## Usage:
##   var hydrator = LibraryHydrator.new("https://mirror.ogs.io")
##   hydrator.tool_download_started.connect(_on_tool_download_started)
##   hydrator.tool_download_complete.connect(_on_tool_download_complete)
##   hydrator.hydration_complete.connect(_on_hydration_complete)
##   var result = hydrator.hydrate([{"tool_id": "godot", "version": "4.3"}])
##
## Signals:
##   - tool_download_started(tool_id: String, version: String)
##   - tool_download_progress(tool_id: String, version: String, bytes_received: int, bytes_total: int)
##   - tool_download_complete(tool_id: String, version: String, success: bool)
##   - hydration_complete(success: bool, failed_tools: Array)

extends RefCounted
class_name LibraryHydrator

const OgsLogger = preload("res://scripts/logging/logger.gd")

signal tool_download_started(tool_id: String, version: String)
signal tool_download_progress(tool_id: String, version: String, bytes_received: int, bytes_total: int)
signal tool_download_complete(tool_id: String, version: String, success: bool, error_message: String)
signal hydration_complete(success: bool, failed_tools: Array)

var mirror_url: String
var downloader: ToolDownloader
var library: LibraryManager

func _init(mirror: String = "") -> void:
	"""Initialize the hydrator with a mirror URL.
	Parameters:
	  mirror (String): Base URL for the OGS mirror
	"""
	mirror_url = mirror
	downloader = ToolDownloader.new(mirror)
	library = LibraryManager.new()

## Hydrates (downloads and installs) all missing tools.
## Parameters:
##   tools_to_download (Array): Array of {"tool_id": String, "version": String}
## Returns:
##   Dictionary: {
##       "success": bool,
##       "downloaded_count": int,
##       "failed_count": int,
##       "failed_tools": Array[Dictionary]
##   }
func hydrate(tools_to_download: Array) -> Dictionary:
	"""Orchestrates downloading and installing all missing tools."""
	var result = {
		"success": true,
		"downloaded_count": 0,
		"failed_count": 0,
		"failed_tools": []
	}
	
	if tools_to_download.is_empty():
		OgsLogger.info("hydration_complete", {
			"component": "library",
			"reason": "no tools to download"
		})
		hydration_complete.emit(true, [])
		return result
	
	OgsLogger.info("hydration_started", {
		"component": "library",
		"tool_count": tools_to_download.size()
	})
	
	for tool_entry in tools_to_download:
		var tool_id = tool_entry.get("tool_id", "")
		var version = tool_entry.get("version", "")
		
		if tool_id.is_empty() or version.is_empty():
			result["failed_tools"].append(tool_entry)
			result["failed_count"] += 1
			continue
		
		var download_result = _download_and_install_tool(tool_id, version)
		
		if download_result["success"]:
			result["downloaded_count"] += 1
			tool_download_complete.emit(tool_id, version, true, "")
		else:
			result["failed_count"] += 1
			result["failed_tools"].append(tool_entry)
			tool_download_complete.emit(tool_id, version, false, download_result["error"])
	
	result["success"] = result["failed_count"] == 0
	
	OgsLogger.info("hydration_complete", {
		"component": "library",
		"downloaded": result["downloaded_count"],
		"failed": result["failed_count"]
	})
	
	hydration_complete.emit(result["success"], result["failed_tools"])
	
	return result

## Downloads and installs a single tool.
## Parameters:
##   tool_id (String): Tool identifier (e.g., "godot")
##   version (String): Version string (e.g., "4.3")
## Returns:
##   Dictionary: {"success": bool, "error": String, "path": String}
func _download_and_install_tool(tool_id: String, version: String) -> Dictionary:
	"""Downloads a single tool and installs it to the library."""
	tool_download_started.emit(tool_id, version)
	
	# Check if already in library (skip if present)
	if library.tool_exists(tool_id, version):
		OgsLogger.debug("tool_hydration_skipped", {
			"component": "library",
			"tool_id": tool_id,
			"version": version,
			"reason": "already in library"
		})
		return {"success": true, "error": "", "path": library.get_tool_path(tool_id, version)}
	
	# Download tool
	var download_result = downloader.download_tool(tool_id, version)
	
	if not download_result["success"]:
		OgsLogger.error("tool_download_failed", {
			"component": "library",
			"tool_id": tool_id,
			"version": version,
			"error": download_result["error_message"]
		})
		return {
			"success": false,
			"error": download_result["error_message"],
			"path": ""
		}
	
	# Verify tool is now in library
	if not library.tool_exists(tool_id, version):
		var error_msg = "Tool not found in library after download"
		OgsLogger.error("tool_hydration_failed", {
			"component": "library",
			"tool_id": tool_id,
			"version": version,
			"reason": error_msg
		})
		return {"success": false, "error": error_msg, "path": ""}
	
	var tool_path = library.get_tool_path(tool_id, version)
	OgsLogger.info("tool_hydrated", {
		"component": "library",
		"tool_id": tool_id,
		"version": version,
		"path": tool_path
	})
	
	return {"success": true, "error": "", "path": tool_path}

## Returns count of tools already in library.
## Useful for UI to show what will be skipped.
## Parameters:
##   tools (Array): Array of {"tool_id": String, "version": String}
## Returns:
##   int: Count of tools already in library
func count_already_installed(tools: Array) -> int:
	var count = 0
	for tool_entry in tools:
		var tool_id = tool_entry.get("tool_id", "")
		var version = tool_entry.get("version", "")
		if library.tool_exists(tool_id, version):
			count += 1
	return count

## Checks if mirror is configured.
## Returns:
##   bool: True if mirror URL is non-empty
func is_mirror_configured() -> bool:
	return not mirror_url.is_empty()

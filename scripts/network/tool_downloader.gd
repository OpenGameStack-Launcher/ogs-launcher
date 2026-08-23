## ToolDownloader: Manages tool downloads and library integration.
##
## Orchestrates the workflow of downloading tools from the OGS mirror,
## extracting them, and registering them in the central library.
##
## Workflow:
##   1. Check if tool already in library → return success
##   2. Guard: Check offline mode → block if offline
##   3. Download: Fetch from mirror URL to temp location
##   4. Extract: Use ToolExtractor to decompress into library
##   5. Validate: Confirm tool is now in library
##
## This module respects the offline enforcement rules and will not attempt
## network access when offline_mode or force_offline is active.
##
## Usage:
##   var downloader = ToolDownloader.new("https://mirror.ogs.io")
##   var result = downloader.download_tool("godot", "4.3")
##   if result.success:
##       print("Tool ready: " + result.tool_path)

extends RefCounted
class_name ToolDownloader

const OgsLogger = preload("res://scripts/logging/logger.gd")

## Error codes for download failures.
enum DownloadError {
	SUCCESS = 0,
	OFFLINE_BLOCKED = 1,
	MIRROR_NOT_CONFIGURED = 2,
	DOWNLOAD_FAILED = 3,
	EXTRACTION_FAILED = 4,
	VALIDATION_FAILED = 5,
	NOT_IMPLEMENTED = 99,
}

## Mirror URL for downloading tools (set via constructor)
var mirror_url: String = ""

## LibraryManager instance for querying/validating library state
var library: LibraryManager

## ToolExtractor instance for unpacking archives
var extractor: ToolExtractor

## Temporary directory for downloads
var temp_dir: String = ""

func _init(mirror: String = "") -> void:
	"""Initialize the downloader with a mirror URL.
	Parameters:
	  mirror (String): Base URL for the OGS mirror (e.g., "https://mirror.ogs.io/tools")
	"""
	mirror_url = mirror
	library = LibraryManager.new()
	extractor = ToolExtractor.new()
	
	# Use system temp directory
	temp_dir = OS.get_cache_dir()
	if temp_dir.is_empty():
		temp_dir = OS.get_user_data_dir()

## Downloads and installs a tool to the central library.
## Parameters:
##   tool_id (String): Tool identifier (e.g., "godot")
##   version (String): Version string (e.g., "4.3")
## Returns:
##   Dictionary: {
##       "success": bool,
##       "error_code": int,
##       "error_message": String,
##       "tool_path": String (set if success),
##       "already_exists": bool
##   }
func download_tool(tool_id: String, version: String) -> Dictionary:
	"""Attempts to download and install a tool.
	Handles the complete workflow: check existence, download, extract, validate.
	"""
	var result = {
		"success": false,
		"error_code": DownloadError.NOT_IMPLEMENTED,
		"error_message": "",
		"tool_path": "",
		"already_exists": false
	}
	
	# Check if tool already in library
	if library.tool_exists(tool_id, version):
		result["success"] = true
		result["error_code"] = DownloadError.SUCCESS
		result["tool_path"] = library.get_tool_path(tool_id, version)
		result["already_exists"] = true
		OgsLogger.info("tool_already_installed", {
			"component": "network",
			"tool_id": tool_id,
			"version": version,
			"path": result["tool_path"]
		})
		return result
	
	# Check offline mode
	var guard = OfflineEnforcer.guard_network_call("download_tool:%s" % tool_id)
	if not guard["allowed"]:
		result["error_code"] = DownloadError.OFFLINE_BLOCKED
		result["error_message"] = guard["error_message"]
		OgsLogger.warn("download_blocked", {
			"component": "network",
			"reason": "offline",
			"tool": tool_id,
			"version": version
		})
		return result
	
	# Validate mirror is configured
	if mirror_url.is_empty():
		result["error_code"] = DownloadError.MIRROR_NOT_CONFIGURED
		result["error_message"] = "Mirror URL not configured"
		OgsLogger.error("download_failed", {
			"component": "network",
			"tool_id": tool_id,
			"version": version,
			"reason": "mirror not configured"
		})
		return result
	
	# Download tool archive
	var download_result = _download_archive(tool_id, version)
	if not download_result["success"]:
		result["error_code"] = DownloadError.DOWNLOAD_FAILED
		result["error_message"] = download_result["error"]
		OgsLogger.error("download_failed", {
			"component": "network",
			"tool_id": tool_id,
			"version": version,
			"reason": download_result["error"]
		})
		return result
	
	# Extract archive to library
	var extract_result = extractor.extract_to_library(
		download_result["archive_path"],
		tool_id,
		version
	)
	
	if not extract_result["success"]:
		result["error_code"] = DownloadError.EXTRACTION_FAILED
		result["error_message"] = extract_result["error_message"]
		_cleanup_download(download_result["archive_path"])
		OgsLogger.error("download_failed", {
			"component": "network",
			"tool_id": tool_id,
			"version": version,
			"reason": "extraction failed: " + extract_result["error_message"]
		})
		return result
	
	# Validate tool is now in library
	var validation = library.validate_tool(tool_id, version)
	if not validation["valid"]:
		result["error_code"] = DownloadError.VALIDATION_FAILED
		result["error_message"] = "Validation failed: " + str(validation["errors"])
		OgsLogger.error("download_failed", {
			"component": "network",
			"tool_id": tool_id,
			"version": version,
			"reason": "validation failed"
		})
		return result
	
	# Success!
	result["success"] = true
	result["error_code"] = DownloadError.SUCCESS
	result["tool_path"] = library.get_tool_path(tool_id, version)
	
	OgsLogger.info("tool_downloaded", {
		"component": "network",
		"tool_id": tool_id,
		"version": version,
		"path": result["tool_path"]
	})
	
	return result

# Private helper: downloads archive from mirror
func _download_archive(tool_id: String, version: String) -> Dictionary:
	"""Downloads tool archive to temp directory.
	STUBBED: Actual HTTP implementation will be added after Phase 2 infrastructure.
	Returns:
	  Dictionary: {"success": bool, "error": String, "archive_path": String}
	"""
	var result = {
		"success": false,
		"error": "",
		"archive_path": ""
	}
	
	# Construct archive URL
	var archive_name = "%s-%s-windows-x64.zip" % [tool_id, version]
	var download_url = mirror_url.path_join(tool_id).path_join(version).path_join(archive_name)
	
	# Stub: Actually implement HTTPRequest in Phase 2
	# For now, log and return not implemented
	OgsLogger.info("download_stubbed", {
		"component": "network",
		"tool_id": tool_id,
		"version": version,
		"url": download_url
	})
	
	result["error"] = "Download not yet implemented (Phase 2)"
	return result

# Private helper: deletes archive after failed extraction
func _cleanup_download(archive_path: String) -> void:
	"""Attempts to clean up a failed download."""
	if FileAccess.file_exists(archive_path):
		var err = DirAccess.remove_absolute(archive_path)
		if err != OK:
			OgsLogger.warn("cleanup_failed", {
				"component": "network",
				"archive": archive_path
			})

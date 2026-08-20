## ProjectSealer: Converts a linked project to a sealed, self-contained artifact.
##
## Implements the "Seal for Delivery" protocol: takes a project with linked tools
## from the central library and creates a sealed, offline-ready deliverable.
##
## Workflow:
##   1. Validate project has stack.json and all required tools exist in library
##   2. Create ./tools directory and copy tool binaries from library
##   3. Write ogs_config.json with force_offline=true
##   4. Create a sealed zip archive: [ProjectName]_Sealed_[Date].zip
##
## Result Dictionary:
##   {
##       "success": bool,
##       "sealed_zip": String,        # Path to created zip (if success)
##       "project_size_mb": float,    # Size of sealed artifact (if success)
##       "tools_copied": Array[String], # Tool IDs that were copied
##       "errors": Array[String]      # Error messages if failure
##   }
##
## Usage:
##   var sealer = ProjectSealer.new()
##   var result = sealer.seal_project("/path/to/project")
##   if result.success:
##       print("Sealed: " + result.sealed_zip)
##   else:
##       print("Error: " + str(result.errors))

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

func _init():
	library = LibraryManager.new()
	validator = SealValidatorScript.new()
	copier = SealToolCopierScript.new()
	config_writer = SealConfigWriterScript.new()
	archiver = SealArchiverScript.new()

## Main entry point: seals a project for offline delivery.
## Parameters:
##   project_path (String): Absolute path to the project directory
## Returns:
##   Dictionary: Seal operation result with success flag and metadata
func seal_project(project_path: String) -> Dictionary:
	var result = {
		"success": false,
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
	
	# Step 2: Copy tools to local ./tools directory
	var copy_result = _copy_tools_to_local(project_path, validation.manifest)
	if not copy_result.success:
		result.errors = copy_result.errors
		OgsLogger.error("seal_project_copy_failed", {
			"component": "sealer",
			"project_path": project_path,
			"errors": copy_result.errors
		})
		return result
	
	result.tools_copied = copy_result.tools_copied
	
	# Step 3: Write offline config
	var config_result = _write_offline_config(project_path)
	if not config_result.success:
		result.errors = config_result.errors
		OgsLogger.error("seal_project_config_failed", {
			"component": "sealer",
			"project_path": project_path,
			"errors": config_result.errors
		})
		return result
	
	# Step 4: Create sealed zip
	var zip_result = _create_sealed_zip(project_path)
	if not zip_result.success:
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

## Validates that the project exists, has stack.json, and all required tools are in library.
## Returns: {"success": bool, "errors": Array, "manifest": StackManifest}
func _validate_project(project_path: String) -> Dictionary:
	"""Delegates project pre-seal validation to ProjectSealValidator."""
	return validator.validate_project(project_path, library)

## Copies all tools from library to project's ./tools directory.
## Returns: {"success": bool, "errors": Array, "tools_copied": Array}
func _copy_tools_to_local(project_path: String, manifest: StackManifest) -> Dictionary:
	"""Delegates library-to-project tool copy operations to ProjectSealToolCopier."""
	return copier.copy_tools_to_local(project_path, manifest, library)

## Writes ogs_config.json with force_offline=true to project root.
## Returns: {"success": bool, "errors": Array}
func _write_offline_config(project_path: String) -> Dictionary:
	"""Delegates offline config writing to ProjectSealConfigWriter."""
	return config_writer.write_offline_config(project_path)

## Creates a sealed zip archive of the entire project.
## Returns: {"success": bool, "errors": Array, "zip_path": String, "size_mb": float}
func _create_sealed_zip(project_path: String) -> Dictionary:
	"""Delegates zip packaging to ProjectSealArchiver."""
	return archiver.create_sealed_zip(project_path)

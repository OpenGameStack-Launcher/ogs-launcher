## StackManifest: OGS Manifest Loader & Validator
##
## Provides offline-safe loading, parsing, and validation of 'stack.json' manifests.
## Manifests define the exact frozen stack of tools (Godot, Blender, Krita, Audacity) required
## for a specific project. Validation enforces schema compliance and produces explicit error codes
## for UI-level reporting without external dependencies.
##
## Usage:
##   # Load from disk
##   var manifest = StackManifest.load_from_file("res://stack.json")
##   if manifest.is_valid():
##       for tool in manifest.tools:
##           print("%s v%s at %s" % [tool["id"], tool["version"], tool["path"]])
##
##   # Parse JSON text
##   var manifest = StackManifest.parse_json_string(json_text)
##
##   # Build from dictionary
##   var manifest = StackManifest.from_dict({"schema_version": 1, ...})
##
## Schema Version:
##   Currently supports schema_version=1 only. Unsupported versions fail validation.
##
## Error Codes:
##   - manifest_file_unreadable: File I/O failed
##   - manifest_json_invalid: JSON parsing failed
##   - manifest_root_not_object: Root must be a dictionary
##   - schema_version_missing/not_int/unsupported: Schema version issues
##   - stack_name_missing/not_string/empty: Stack name issues
##   - tools_missing/not_array/empty: Tools array issues
##   - tool_not_object:INDEX: Tool at INDEX is not a dictionary
##   - tool_id_missing/invalid:INDEX: Tool ID at INDEX missing or invalid
##   - tool_version_missing/invalid:INDEX: Tool version missing or invalid
##   - tool_path_missing/invalid:INDEX: Tool path missing or invalid
##   - tool_sha256_invalid:INDEX: SHA-256 checksum format invalid at INDEX

extends RefCounted
class_name StackManifest

const OgsLogger = preload("res://scripts/logging/logger.gd")

const CURRENT_SCHEMA_VERSION := 1

var schema_version := 0
var stack_name := ""
var tools: Array[Dictionary] = []
var errors: Array[String] = []

## Loads manifest from a file path on disk.
## Returns a StackManifest instance with validation errors in .errors if I/O or parsing fails.
## Parameters:
##   file_path (String): Path to stack.json (e.g., "res://projects/game/stack.json")
## Returns:
##   StackManifest: Callers should check .is_valid() before using fields.
static func load_from_file(file_path: String) -> StackManifest:
	var manifest := StackManifest.new()
	manifest._load_from_file(file_path)
	return manifest

## Parses JSON text into a manifest.
## Parameters:
##   json_text (String): Raw JSON string (e.g., from fileread or network)
## Returns:
##   StackManifest: Check .is_valid() and .errors for parse/validation failures.
static func parse_json_string(json_text: String) -> StackManifest:
	"""Parses manifest JSON text into a validated StackManifest instance."""
	var manifest := StackManifest.new()
	manifest._load_from_json_string(json_text)
	return manifest

## Builds a manifest from a dictionary.
## Parameters:
##   data (Dictionary): Parsed JSON or manually-constructed object
## Returns:
##   StackManifest: Instance with validation errors in .errors if data is invalid.
static func from_dict(data: Dictionary) -> StackManifest:
	"""Builds a manifest from a dictionary and validates required fields."""
	var manifest := StackManifest.new()
	manifest._load_from_dict(data)
	return manifest

## Checks if manifest validation passed.
## Returns:
##   bool: True if .errors is empty, false otherwise.
func is_valid() -> bool:
	"""Returns true when the manifest has no validation errors."""
	return errors.is_empty()

## Converts manifest to a dictionary for serialization or inspection.
## Returns:
##   Dictionary: {"schema_version": int, "stack_name": string, "tools": Array[Dictionary]}
func to_dict() -> Dictionary:
	"""Serializes the manifest to a dictionary for storage or inspection."""
	return {
		"schema_version": schema_version,
		"stack_name": stack_name,
		"tools": tools
	}

## Validates a manifest dictionary against the schema.
## This is a static helper used internally and by test suites.
## Parameters:
##   data (Dictionary): Parsed manifest data to validate
## Returns:
##   Array[String]: List of error codes. Empty array means validation passed.
static func validate_data(data: Dictionary) -> Array[String]:
	"""Validates manifest content and returns a list of error codes."""
	var found_errors: Array[String] = []
	if not data.has("schema_version"):
		found_errors.append("schema_version_missing")
	else:
		var schema_value = data["schema_version"]
		if typeof(schema_value) == TYPE_INT:
			if int(schema_value) != CURRENT_SCHEMA_VERSION:
				found_errors.append("schema_version_unsupported")
		elif typeof(schema_value) == TYPE_FLOAT:
			if int(schema_value) != schema_value:
				found_errors.append("schema_version_not_int")
			elif int(schema_value) != CURRENT_SCHEMA_VERSION:
				found_errors.append("schema_version_unsupported")
		else:
			found_errors.append("schema_version_not_int")

	if not data.has("stack_name"):
		found_errors.append("stack_name_missing")
	elif typeof(data["stack_name"]) != TYPE_STRING:
		found_errors.append("stack_name_not_string")
	elif String(data["stack_name"]).strip_edges() == "":
		found_errors.append("stack_name_empty")

	if not data.has("tools"):
		found_errors.append("tools_missing")
	elif typeof(data["tools"]) != TYPE_ARRAY:
		found_errors.append("tools_not_array")
	else:
		var tool_list: Array = data["tools"]
		if tool_list.is_empty():
			found_errors.append("tools_empty")
		else:
			for index in tool_list.size():
				var tool_entry = tool_list[index]
				if typeof(tool_entry) != TYPE_DICTIONARY:
					found_errors.append("tool_not_object:%d" % index)
					continue
				_validate_tool_entry(tool_entry, index, found_errors)

	return found_errors

## Internal method: Validates a single tool entry in the tools array.
## Parameters:
##   tool_entry (Dictionary): The tool object to validate (must have id, version, path)
##   index (int): Position in the tools array (for error reporting)
##   found_errors (Array[String]): Error list to append to
static func _validate_tool_entry(tool_entry: Dictionary, index: int, found_errors: Array[String]) -> void:
	"""Validates a single tool entry dictionary and records any errors."""
	if not tool_entry.has("id"):
		found_errors.append("tool_id_missing:%d" % index)
	elif typeof(tool_entry["id"]) != TYPE_STRING or String(tool_entry["id"]).strip_edges() == "":
		found_errors.append("tool_id_invalid:%d" % index)

	if not tool_entry.has("version"):
		found_errors.append("tool_version_missing:%d" % index)
	elif typeof(tool_entry["version"]) != TYPE_STRING or String(tool_entry["version"]).strip_edges() == "":
		found_errors.append("tool_version_invalid:%d" % index)

	# Path is now optional - if omitted, launcher will resolve from library
	if tool_entry.has("path"):
		if typeof(tool_entry["path"]) != TYPE_STRING or String(tool_entry["path"]).strip_edges() == "":
			found_errors.append("tool_path_invalid:%d" % index)

	if tool_entry.has("sha256"):
		var sha_value = tool_entry["sha256"]
		if typeof(sha_value) != TYPE_STRING or not _is_hex_sha256(String(sha_value)):
			found_errors.append("tool_sha256_invalid:%d" % index)

## Internal method: Validates SHA-256 checksum format.
## Uses character-by-character ASCII checks to avoid external regex libraries.
## Parameters:
##   value (String): Hex string to validate
## Returns:
##   bool: True if value is exactly 64 hex chars (0-9, a-f, A-F), false otherwise.
static func _is_hex_sha256(value: String) -> bool:
	"""Returns true when the string is a valid hex-encoded SHA-256."""
	if value.length() != 64:
		return false
	for character in value:
		var code = character.unicode_at(0)
		var is_digit = code >= 48 and code <= 57
		var is_lower = code >= 97 and code <= 102
		var is_upper = code >= 65 and code <= 70
		if not (is_digit or is_lower or is_upper):
			return false
	return true

## Internal method: Loads JSON from disk.
## Private to this class; use load_from_file() instead.
## Parameters:
##   file_path (String): Path to stack.json
func _load_from_file(file_path: String) -> void:
	"""Loads JSON from disk and validates it without contacting external services."""
	errors.clear()
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		OgsLogger.warn("manifest_read_failed", {"component": "manifest"})
		errors.append("manifest_file_unreadable")
		return
	var json_text = file.get_as_text()
	file.close()
	_load_from_json_string(json_text)

## Internal method: Parses JSON string.
## Private to this class; use parse_json_string() instead.
## Parameters:
##   json_text (String): Raw JSON to parse
func _load_from_json_string(json_text: String) -> void:
	"""Loads manifest data from JSON text while recording parse errors."""
	errors.clear()
	if json_text.strip_edges().is_empty():
		OgsLogger.warn("manifest_parse_failed", {"component": "manifest"})
		errors.append("manifest_json_invalid")
		return
	var parser = JSON.new()
	var parse_err = parser.parse(json_text)
	if parse_err != OK:
		OgsLogger.warn("manifest_parse_failed", {"component": "manifest"})
		errors.append("manifest_json_invalid")
		return
	var data = parser.data
	if typeof(data) != TYPE_DICTIONARY:
		OgsLogger.warn("manifest_root_invalid", {"component": "manifest"})
		errors.append("manifest_root_not_object")
		return
	_load_from_dict(data)

## Internal method: Populates instance fields from dictionary.
## Private to this class; use from_dict(), load_from_file(), or parse_json_string() instead.
## Performs validation and populates .errors if validation fails.
## Parameters:
##   data (Dictionary): Object to load from
func _load_from_dict(data: Dictionary) -> void:
	"""Populates fields from a dictionary after validation."""
	errors = validate_data(data)
	if not errors.is_empty():
		OgsLogger.warn("manifest_validation_failed", {"component": "manifest", "error_count": errors.size()})
	schema_version = int(data.get("schema_version", 0))
	stack_name = String(data.get("stack_name", ""))
	var raw_tools = data.get("tools", [])
	if typeof(raw_tools) == TYPE_ARRAY:
		# Manually convert untyped array to Array[Dictionary]
		tools.clear()
		for item in raw_tools:
			if typeof(item) == TYPE_DICTIONARY:
				tools.append(item)

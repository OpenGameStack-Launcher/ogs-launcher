## MirrorRepository: Loader and validator for mirror repository.json files.
##
## Provides offline-safe parsing, validation, and lookup for tool archives
## stored in a local mirror root or remote repository. This class never
## performs network access.

extends RefCounted
class_name MirrorRepository

const OgsLogger = preload("res://scripts/logging/logger.gd")

const CURRENT_SCHEMA_VERSION := 1

var schema_version := 0
var mirror_name := ""
var tools: Array[Dictionary] = []
var errors: Array[String] = []

## Loads a repository.json file from disk.
## Parameters:
##   file_path (String): Absolute path to repository.json
## Returns:
##   MirrorRepository: Instance with validation errors in .errors
static func load_from_file(file_path: String) -> MirrorRepository:
	"""Loads a mirror repository from disk."""
	var repo := MirrorRepository.new()
	repo._load_from_file(file_path)
	return repo

## Parses JSON text into a repository instance.
## Parameters:
##   json_text (String): Raw JSON string
## Returns:
##   MirrorRepository: Instance with validation errors in .errors
static func parse_json_string(json_text: String) -> MirrorRepository:
	"""Parses repository JSON text into a MirrorRepository instance."""
	var repo := MirrorRepository.new()
	repo._load_from_json_string(json_text)
	return repo

## Builds a repository from a dictionary.
## Parameters:
##   data (Dictionary): Parsed JSON or constructed object
## Returns:
##   MirrorRepository: Instance with validation errors in .errors
static func from_dict(data: Dictionary) -> MirrorRepository:
	"""Builds a repository from a dictionary and validates required fields."""
	var repo := MirrorRepository.new()
	repo._load_from_dict(data)
	return repo

## Returns true if the repository has no validation errors.
func is_valid() -> bool:
	"""Returns true when repository validation passes."""
	return errors.is_empty()

## Converts repository to a dictionary for serialization or inspection.
func to_dict() -> Dictionary:
	"""Serializes the repository to a dictionary."""
	return {
		"schema_version": schema_version,
		"mirror_name": mirror_name,
		"tools": tools
	}

## Finds a tool entry by id and version.
## Parameters:
##   tool_id (String): Tool identifier
##   version (String): Version string
## Returns:
##   Dictionary: Matching tool entry or empty dictionary if not found
func get_tool_entry(tool_id: String, version: String) -> Dictionary:
	"""Returns a matching tool entry or an empty dictionary."""
	for entry in tools:
		if String(entry.get("id", "")) == tool_id and String(entry.get("version", "")) == version:
			return entry
	return {}

## Validates a repository dictionary against the schema.
## Parameters:
##   data (Dictionary): Parsed repository data
## Returns:
##   Array[String]: List of validation error codes
static func validate_data(data: Dictionary) -> Array[String]:
	"""Validates repository content and returns a list of error codes."""
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

	if not data.has("mirror_name"):
		found_errors.append("mirror_name_missing")
	elif typeof(data["mirror_name"]) != TYPE_STRING:
		found_errors.append("mirror_name_not_string")
	elif String(data["mirror_name"]).strip_edges() == "":
		found_errors.append("mirror_name_empty")

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

## Validates a single tool entry.
static func _validate_tool_entry(tool_entry: Dictionary, index: int, found_errors: Array[String]) -> void:
	"""Validates a tool entry dictionary and appends errors."""
	if not tool_entry.has("id"):
		found_errors.append("tool_id_missing:%d" % index)
	elif typeof(tool_entry["id"]) != TYPE_STRING or String(tool_entry["id"]).strip_edges() == "":
		found_errors.append("tool_id_invalid:%d" % index)

	if not tool_entry.has("version"):
		found_errors.append("tool_version_missing:%d" % index)
	elif typeof(tool_entry["version"]) != TYPE_STRING or String(tool_entry["version"]).strip_edges() == "":
		found_errors.append("tool_version_invalid:%d" % index)

	# Category is optional, but if present must be a non-empty string
	if tool_entry.has("category"):
		var category_value = tool_entry["category"]
		if typeof(category_value) != TYPE_STRING or String(category_value).strip_edges() == "":
			found_errors.append("tool_category_invalid:%d" % index)

	# info_url is optional, but if present must be a non-empty string
	if tool_entry.has("info_url"):
		var info_url_value = tool_entry["info_url"]
		if typeof(info_url_value) != TYPE_STRING or String(info_url_value).strip_edges() == "":
			found_errors.append("tool_info_url_invalid:%d" % index)

	var has_archive_path = tool_entry.has("archive_path")
	var has_archive_url = tool_entry.has("archive_url")
	if not has_archive_path and not has_archive_url:
		found_errors.append("tool_archive_source_missing:%d" % index)
	elif has_archive_path:
		var archive_path = tool_entry["archive_path"]
		if typeof(archive_path) != TYPE_STRING or String(archive_path).strip_edges() == "":
			found_errors.append("tool_archive_path_invalid:%d" % index)
	elif has_archive_url:
		var archive_url = tool_entry["archive_url"]
		if typeof(archive_url) != TYPE_STRING or String(archive_url).strip_edges() == "":
			found_errors.append("tool_archive_url_invalid:%d" % index)

	if not tool_entry.has("sha256"):
		found_errors.append("tool_sha256_missing:%d" % index)
	else:
		var sha_value = tool_entry["sha256"]
		if typeof(sha_value) != TYPE_STRING or not _is_hex_sha256(String(sha_value)):
			found_errors.append("tool_sha256_invalid:%d" % index)

	_validate_size_field(tool_entry, "size", index, found_errors)
	_validate_size_field(tool_entry, "size_bytes", index, found_errors)

## Validates size fields for tool entries.
static func _validate_size_field(tool_entry: Dictionary, field_name: String, index: int, found_errors: Array[String]) -> void:
	"""Validates optional size fields for a tool entry."""
	if not tool_entry.has(field_name):
		return
	var size_value = tool_entry[field_name]
	if typeof(size_value) == TYPE_INT:
		if int(size_value) <= 0:
			found_errors.append("tool_size_invalid:%d" % index)
		return
	if typeof(size_value) == TYPE_FLOAT:
		if int(size_value) != size_value or int(size_value) <= 0:
			found_errors.append("tool_size_invalid:%d" % index)
		return
	found_errors.append("tool_size_invalid:%d" % index)

## Validates sha256 hex format (64 hex characters).
static func _is_hex_sha256(value: String) -> bool:
	"""Returns true if value is a valid hex-encoded SHA-256 string."""
	if value.length() != 64:
		return false
	for character in value:
		var code = character.unicode_at(0)
		var is_digit = code >= 48 and code <= 57
		var is_lower = code >= 97 and code <= 102
		if not (is_digit or is_lower):
			return false
	return true

## Internal: Loads JSON from disk.
func _load_from_file(file_path: String) -> void:
	"""Loads repository JSON from disk and validates it."""
	errors.clear()
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		OgsLogger.warn("mirror_repo_read_failed", {"component": "mirror"})
		errors.append("repository_file_unreadable")
		return
	var json_text = file.get_as_text()
	file.close()
	_load_from_json_string(json_text)

## Internal: Parses JSON string.
func _load_from_json_string(json_text: String) -> void:
	"""Loads repository data from JSON text while recording parse errors."""
	errors.clear()
	if json_text.strip_edges().is_empty():
		OgsLogger.warn("mirror_repo_parse_failed", {"component": "mirror"})
		errors.append("repository_json_invalid")
		return
	var parser = JSON.new()
	var parse_err = parser.parse(json_text)
	if parse_err != OK:
		OgsLogger.warn("mirror_repo_parse_failed", {"component": "mirror"})
		errors.append("repository_json_invalid")
		return
	var data = parser.data
	if typeof(data) != TYPE_DICTIONARY:
		OgsLogger.warn("mirror_repo_root_invalid", {"component": "mirror"})
		errors.append("repository_root_not_object")
		return
	_load_from_dict(data)

## Internal: Populates fields from dictionary.
func _load_from_dict(data: Dictionary) -> void:
	"""Populates fields from a dictionary after validation."""
	errors = validate_data(data)
	if not errors.is_empty():
		OgsLogger.warn("mirror_repo_validation_failed", {"component": "mirror", "error_count": errors.size()})
	schema_version = int(data.get("schema_version", 0))
	mirror_name = String(data.get("mirror_name", ""))
	var raw_tools = data.get("tools", [])
	if typeof(raw_tools) == TYPE_ARRAY:
		tools.clear()
		for item in raw_tools:
			if typeof(item) == TYPE_DICTIONARY:
				tools.append(item)

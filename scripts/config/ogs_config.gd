## OgsConfig: Launcher Configuration Loader
##
## Manages the `ogs_config.json` configuration file that controls launcher behavior,
## especially air-gap enforcement and offline mode.
##
## Usage:
##   var config = OgsConfig.load_from_file("res://ogs_config.json")
##   if config.is_offline():
##       # enforce sovereign mode
##       pass

extends RefCounted
class_name OgsConfig

const OgsLogger = preload("res://scripts/logging/logger.gd")

const CURRENT_SCHEMA_VERSION := 1

var schema_version := 1
var offline_mode := false
var force_offline := false
var allowed_hosts: Array[String] = []
var allowed_ports: Array[int] = []
var errors: Array[String] = []

func to_dict() -> Dictionary:
	"""Converts config to dictionary for serialization in the OGS lifecycle.
	Returns:
	  Dictionary: Config payload including offline and allowlist controls."""
	return {
		"schema_version": schema_version,
		"offline_mode": offline_mode,
		"force_offline": force_offline,
		"allowed_hosts": allowed_hosts,
		"allowed_ports": allowed_ports
	}

static func load_from_file(file_path: String) -> OgsConfig:
	"""Loads OGS config from disk or returns defaults when missing.
	Parameters:
	  file_path (String): Path to ogs_config.json
	Returns:
	  OgsConfig: Loaded config object for launcher startup policy."""
	var config := OgsConfig.new()
	config._load_from_file(file_path)
	return config

static func parse_json_string(json_text: String) -> OgsConfig:
	"""Parses config JSON text into an OgsConfig object.
	Parameters:
	  json_text (String): Raw JSON string
	Returns:
	  OgsConfig: Parsed config or validation-error instance."""
	var config := OgsConfig.new()
	config._load_from_json_string(json_text)
	return config

static func from_dict(data: Dictionary) -> OgsConfig:
	"""Builds config from dictionary data.
	Parameters:
	  data (Dictionary): Input configuration dictionary
	Returns:
	  OgsConfig: Parsed config object with validation state."""
	var config := OgsConfig.new()
	config._load_from_dict(data)
	return config

func is_offline() -> bool:
	"""Returns whether sovereign/offline mode is active for launcher behavior."""
	return offline_mode or force_offline

func is_valid() -> bool:
	"""Returns true when schema and field validation produced no errors."""
	return errors.is_empty()

static func validate_data(data: Dictionary) -> Array[String]:
	"""Validates schema and policy fields for launcher configuration.
	Parameters:
	  data (Dictionary): Config dictionary to validate
	Returns:
	  Array[String]: Validation error codes; empty means valid."""
	var found_errors: Array[String] = []

	if data.has("schema_version"):
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

	if data.has("offline_mode") and typeof(data["offline_mode"]) != TYPE_BOOL:
		found_errors.append("offline_mode_not_bool")

	if data.has("force_offline") and typeof(data["force_offline"]) != TYPE_BOOL:
		found_errors.append("force_offline_not_bool")

	if data.has("allowed_hosts"):
		if typeof(data["allowed_hosts"]) != TYPE_ARRAY:
			found_errors.append("allowed_hosts_not_array")
		else:
			var hosts: Array = data["allowed_hosts"]
			for host in hosts:
				if typeof(host) != TYPE_STRING:
					found_errors.append("allowed_hosts_contains_non_string")
					break

	if data.has("allowed_ports"):
		if typeof(data["allowed_ports"]) != TYPE_ARRAY:
			found_errors.append("allowed_ports_not_array")
		else:
			var ports: Array = data["allowed_ports"]
			for port in ports:
				if typeof(port) != TYPE_INT:
					found_errors.append("allowed_ports_contains_non_int")
					break
				if int(port) < 1 or int(port) > 65535:
					found_errors.append("allowed_ports_out_of_range")
					break

	return found_errors

func _load_from_file(file_path: String) -> void:
	"""Internal loader for startup config from disk in OGS lifecycle.
	Parameters:
	  file_path (String): Config file path to read."""
	errors.clear()
	if not FileAccess.file_exists(file_path):
		OgsLogger.debug("config_missing", {"component": "config"})
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		OgsLogger.warn("config_read_failed", {"component": "config"})
		errors.append("config_file_unreadable")
		return

	var json_text = file.get_as_text()
	file.close()
	_load_from_json_string(json_text)

func _load_from_json_string(json_text: String) -> void:
	"""Internal JSON parser for OGS config payloads.
	Parameters:
	  json_text (String): Raw config JSON string."""
	errors.clear()
	if json_text.strip_edges().is_empty():
		OgsLogger.warn("config_parse_failed", {"component": "config"})
		errors.append("config_json_invalid")
		return
	var parser = JSON.new()
	var parse_err = parser.parse(json_text)
	if parse_err != OK:
		OgsLogger.warn("config_parse_failed", {"component": "config"})
		errors.append("config_json_invalid")
		return
	var data = parser.data
	if typeof(data) != TYPE_DICTIONARY:
		OgsLogger.warn("config_root_invalid", {"component": "config"})
		errors.append("config_root_not_object")
		return
	_load_from_dict(data)

func _load_from_dict(data: Dictionary) -> void:
	"""Internal field mapping and normalization from validated dictionary.
	Parameters:
	  data (Dictionary): Parsed config dictionary."""
	errors = validate_data(data)
	if not errors.is_empty():
		OgsLogger.warn("config_validation_failed", {"component": "config", "error_count": errors.size()})

	if data.has("schema_version"):
		schema_version = int(data["schema_version"])

	var offline_value = data.get("offline_mode", false)
	offline_mode = offline_value if typeof(offline_value) == TYPE_BOOL else false

	var force_value = data.get("force_offline", false)
	force_offline = force_value if typeof(force_value) == TYPE_BOOL else false

	allowed_hosts.clear()
	var hosts_value = data.get("allowed_hosts", [])
	if typeof(hosts_value) == TYPE_ARRAY:
		for host in hosts_value:
			if typeof(host) == TYPE_STRING:
				allowed_hosts.append(String(host).strip_edges().to_lower())

	allowed_ports.clear()
	var ports_value = data.get("allowed_ports", [])
	if typeof(ports_value) == TYPE_ARRAY:
		for port in ports_value:
			if typeof(port) == TYPE_INT and int(port) >= 1 and int(port) <= 65535:
				allowed_ports.append(int(port))

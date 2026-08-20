## ProjectSealConfigWriter: Writes offline configuration during seal workflow.

extends RefCounted
class_name ProjectSealConfigWriter

const OgsLogger = preload("res://scripts/logging/logger.gd")

## Writes ogs_config.json configured for forced offline execution.
## Parameters:
##   project_path (String): Absolute project path
## Returns:
##   Dictionary: {"success": bool, "errors": Array}
func write_offline_config(project_path: String) -> Dictionary:
	"""Creates the forced-offline config file in project root."""
	var result = {
		"success": false,
		"errors": []
	}

	var config_path = project_path.path_join("ogs_config.json")
	var config_json_text = "{\"schema_version\":1,\"offline_mode\":true,\"force_offline\":true}"
	var file = FileAccess.open(config_path, FileAccess.WRITE)
	if file == null:
		result.errors.append("Cannot write ogs_config.json: %s" % error_string(FileAccess.get_open_error()))
		return result

	file.store_string(config_json_text)
	result.success = true

	OgsLogger.debug("offline_config_written", {
		"component": "sealer",
		"project_path": project_path
	})

	return result

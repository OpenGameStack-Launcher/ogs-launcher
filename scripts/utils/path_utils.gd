## PathUtils: Shared path validation utility functions.

extends RefCounted
class_name PathUtils

## Ensures the resolved path stays inside the given root directory.
static func is_path_under_root(full_path: String, project_root: String) -> bool:
	var normalized_root = project_root.simplify_path().to_lower()
	var normalized_path = full_path.simplify_path().to_lower()
	if normalized_path == normalized_root:
		return true
	return normalized_path.begins_with(normalized_root + "/")

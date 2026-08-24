## PathUtils: Shared path validation utility functions.

extends RefCounted
class_name PathUtils

## Ensures the resolved path stays inside the given root directory.
static func is_path_under_root(full_path: String, root_dir: String) -> bool:
	var normalized_root = root_dir.simplify_path().replace("\\", "/")
	var normalized_path = full_path.simplify_path().replace("\\", "/")
	if OS.has_feature("windows"):
		normalized_root = normalized_root.to_lower()
		normalized_path = normalized_path.to_lower()
	if normalized_root.is_empty():
		return false
	if normalized_path == normalized_root:
		return true
	var root_prefix = normalized_root
	if not root_prefix.ends_with("/"):
		root_prefix += "/"
	return normalized_path.begins_with(root_prefix)

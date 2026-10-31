## PathUtils: Shared path validation utility functions.

extends RefCounted
class_name PathUtils

## Ensures the resolved path stays inside the given root directory.
static func is_path_under_root(full_path: String, root_dir: String) -> bool:
	var normalized_root: String = root_dir.simplify_path().replace("\\", "/")
	var normalized_path: String = full_path.simplify_path().replace("\\", "/")
	if OS.has_feature("windows"):
		normalized_root = normalized_root.to_lower()
		normalized_path = normalized_path.to_lower()
	if normalized_root.is_empty():
		return false
	if normalized_path == normalized_root:
		return true
	var root_prefix: String = normalized_root
	if not root_prefix.ends_with("/"):
		root_prefix += "/"
	return normalized_path.begins_with(root_prefix)

## Formats a filesystem or resource path consistently for user-facing presentation.
## Strips leading/trailing whitespace, unifies backslashes into forward slashes,
## and removes redundant and trailing slashes while preserving root slashes.
static func format_for_display(path: String) -> String:
	var trimmed: String = path.strip_edges()
	if trimmed.is_empty():
		return ""
	var forward_slashed: String = trimmed.replace("\\", "/")
	return forward_slashed.simplify_path()


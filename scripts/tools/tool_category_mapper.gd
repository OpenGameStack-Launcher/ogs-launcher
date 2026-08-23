## ToolCategoryMapper: Maps tool IDs to categories with fallback logic.
##
## Provides category classification for OGS tools. Categories represent the
## primary use case: Engine, 2D, 3D, Audio. When repository.json includes a
## category field, that takes precedence. Otherwise, this class provides
## hardcoded fallback mappings.
##
## Usage:
## var category = ToolCategoryMapper.get_category("godot")  # Returns "Engine"
## var category = ToolCategoryMapper.get_category_for_tool(tool_dict)  # Checks tool["category"] first

extends RefCounted
class_name ToolCategoryMapper

## Hardcoded fallback mappings: tool_id → category
const FALLBACK_CATEGORIES := {
	"godot": "Engine",
	"blender": "3D",
	"krita": "2D",
	"audacity": "Audio",
	"gimp": "2D"
}

## Gets category for a tool ID using fallback mapping.
## Parameters:
## tool_id (String): Tool identifier (e.g., "godot", "blender")
## Returns:
## String: Category ("Engine", "2D", "3D", "Audio") or "Unknown" if not mapped
static func get_category(tool_id: String) -> String:
	## Returns category for tool_id, or 'Unknown' if not in fallback map.
	return FALLBACK_CATEGORIES.get(tool_id.to_lower(), "Unknown")

## Gets category for a tool entry dictionary with fallback support.
## Checks tool["category"] first, then falls back to hardcoded mapping by ID.
## Parameters:
## tool_entry (Dictionary): Tool entry from repository.json or stack.json
## Returns:
## String: Category ("Engine", "2D", "3D", "Audio") or "Unknown"
static func get_category_for_tool(tool_entry: Dictionary) -> String:
	## Returns category from tool entry, falling back to ID-based mapping.
	# First priority: category field in tool entry
	if tool_entry.has("category"):
		var category = String(tool_entry.get("category", "")).strip_edges()
		if not category.is_empty():
			return category
	
	# Second priority: fallback mapping by tool ID
	if tool_entry.has("id"):
		var tool_id = String(tool_entry.get("id", "")).strip_edges()
		if not tool_id.is_empty():
			return get_category(tool_id)
	
	return "Unknown"

## Returns all supported categories in order.
## Returns:
## Array[String]: List of category names
static func get_all_categories() -> Array:
	## Returns list of all supported categories.
	return ["Engine", "2D", "3D", "Audio"]

## Checks if a category is valid/supported.
## Parameters:
## category (String): Category name to check
## Returns:
## bool: True if category is supported
static func is_valid_category(category: String) -> bool:
	## Returns true if category is in the supported list.
	return category in get_all_categories()

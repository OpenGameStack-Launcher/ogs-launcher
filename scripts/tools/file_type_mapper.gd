## FileTypeMapper: Maps file extensions to their default tool IDs.
##
## Used by the Project Explorer to determine which tool should launch
## when a specific file is selected.

extends RefCounted
class_name FileTypeMapper

const EXTENSION_TO_TOOL := {
	"xcf": "gimp",
	"blend": "blender",
	"kra": "krita",
	"aup3": "audacity",
	"godot": "godot"
}

const TOOL_TO_EXTENSION := {
	"gimp": "xcf",
	"blender": "blend",
	"krita": "kra",
	"audacity": "aup3"
}

## Returns the tool ID associated with a file path or extension.
static func get_tool_for_file(file_path: String) -> String:
	var ext = file_path.get_extension().to_lower()
	if ext.is_empty() and file_path.get_file().to_lower() == "project.godot":
		return "godot"
	return EXTENSION_TO_TOOL.get(ext, "")

## Returns the default extension (without dot) for a given tool.
static func get_extension_for_tool(tool_id: String) -> String:
	return TOOL_TO_EXTENSION.get(tool_id.to_lower(), "")


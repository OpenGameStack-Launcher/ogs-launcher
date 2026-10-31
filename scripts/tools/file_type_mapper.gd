## FileTypeMapper: Maps file extensions to their default tool IDs.
##
## Used by the Project Explorer to determine which tool should launch
## when a specific file is selected.
## Note: Code category tools (Git, VSCodium) operate directly on the project
## workspace and command-line level rather than single proprietary file extensions,
## though VSCodium accepts arbitrary project file paths as launch arguments.

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
	"audacity": "aup3",
	"vscodium": "txt"
}

const VSCODIUM_EXTENSIONS: Array[String] = [
	"gd", "cs", "gdshader", "shader", "txt", "md", "csv", "json", "yaml", "yml", "toml"
]

const EXCLUDED_FILENAMES: Array[String] = [
	"stack.json",
	"ogs_config.json",
	"ogs_metadata.json"
]

const EXCLUDED_EXTENSIONS: Array[String] = [
	"import",
	"uid",
	"cfg",
	"tres",
	"tscn"
]

## Returns true if the extension is recognized as a VSCodium supported file type.
static func is_vscodium_extension(ext: String) -> bool:
	return ext.to_lower() in VSCODIUM_EXTENSIONS

## Returns true if the file or extension represents internal launcher or engine metadata.
static func is_excluded_file(file_path: String) -> bool:
	var file_name: String = file_path.get_file().to_lower()
	if file_name in EXCLUDED_FILENAMES:
		return true
	var ext: String = file_path.get_extension().to_lower()
	if ext in EXCLUDED_EXTENSIONS:
		return true
	if file_name.begins_with(".") and file_name.trim_prefix(".") in EXCLUDED_EXTENSIONS:
		return true
	return false

## Returns the tool ID associated with a file path or extension.
##
## When active_tool_ids is empty, direct queries return "vscodium" for VSCodium extensions.
## When active_tool_ids is non-empty, VSCodium extensions are only mapped if "vscodium" is present.
static func get_tool_for_file(file_path: String, active_tool_ids: Array = []) -> String:
	if is_excluded_file(file_path):
		return ""
	var file_name: String = file_path.get_file().to_lower()
	if file_name == "project.godot":
		return "godot"
	var ext: String = file_path.get_extension().to_lower()
	if ext.is_empty() and file_name == "project.godot":
		return "godot"
	if EXTENSION_TO_TOOL.has(ext):
		var tool_id: String = EXTENSION_TO_TOOL[ext]
		if tool_id != "godot" or file_name == "project.godot":
			return tool_id
	if is_vscodium_extension(ext):
		if active_tool_ids.is_empty():
			return "vscodium"
		for t: Variant in active_tool_ids:
			if String(t).to_lower() == "vscodium":
				return "vscodium"
		return ""
	return ""

## Returns the default extension (without dot) for a given tool.
static func get_extension_for_tool(tool_id: String) -> String:
	return TOOL_TO_EXTENSION.get(tool_id.to_lower(), "")

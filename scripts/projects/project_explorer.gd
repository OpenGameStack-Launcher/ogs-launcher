## ProjectExplorer: Manages the Tree view for the project file hierarchy.

extends RefCounted
class_name ProjectExplorer

const FileTypeMapper = preload("res://scripts/tools/file_type_mapper.gd")
const ToolCategoryMapper = preload("res://scripts/tools/tool_category_mapper.gd")
const OgsLogger = preload("res://scripts/logging/logger.gd")

const TOOL_ICON_PATHS := {
	"audacity": "res://Images/tools/Audacity.png",
	"blender": "res://Images/tools/Blender.png",
	"gimp": "res://Images/tools/GIMP.png",
	"git": "res://Images/tools/Git.png",
	"godot": "res://Images/tools/Godot.png",
	"krita": "res://Images/tools/Krita.png",
	"vscodium": "res://Images/tools/VSCodium.png"
}
const ICON_MAX_WIDTH: int = 20

signal file_selected(file_path: String, tool_id: String)
signal folder_selected(folder_path: String, tool_id: String)
signal file_activated(file_path: String, tool_id: String)

var tree: Tree
var current_project_dir: String = ""
var active_tool_ids: Array[String] = []
var context_menu: PopupMenu
var context_target_path: String = ""
var _icon_cache: Dictionary = {}

func _init(tree_node: Tree) -> void:
	tree = tree_node
	tree.allow_rmb_select = true
	tree.item_selected.connect(_on_item_selected)
	tree.item_activated.connect(_on_item_activated)
	tree.item_mouse_selected.connect(_on_item_mouse_selected)
	
	_setup_context_menu()

func _setup_context_menu() -> void:
	context_menu = PopupMenu.new()
	context_menu.add_item("Open in File Explorer", 0)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	tree.add_child(context_menu)

func _on_item_mouse_selected(position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		var item: TreeItem = tree.get_item_at_position(position)
		if item:
			item.select(0)
			var meta: Variant = item.get_metadata(0)
			if meta is Dictionary and meta.has("path"):
				context_target_path = String(meta["path"])
				var mouse_pos: Vector2 = tree.get_screen_position() + position
				context_menu.popup(Rect2(mouse_pos, Vector2.ZERO))

func _on_context_menu_id_pressed(id: int) -> void:
	if id == 0 and not context_target_path.is_empty():
		var path_to_open: String = ProjectSettings.globalize_path(context_target_path)
		
		# Validate path to prevent arbitrary URL execution and ensure it stays inside the loaded project.
		var normalized_root: String = current_project_dir.simplify_path().to_lower()
		var normalized_path: String = path_to_open.simplify_path().to_lower()
		if current_project_dir.is_empty() or not path_to_open.is_absolute_path() or path_to_open.contains("://") or (normalized_path != normalized_root and not normalized_path.begins_with(normalized_root + "/")):
			OgsLogger.warn("invalid_shell_open_path", {"component": "project_explorer", "absolute_path": path_to_open})
			return
			
		if not DirAccess.dir_exists_absolute(path_to_open):
			path_to_open = path_to_open.get_base_dir()
			
		OS.shell_show_in_file_manager(path_to_open)

## Loads a new project directory into the Tree.
## When active_tool_ids is omitted or empty, reads tool IDs from <project_dir>/ogs_stack.json if present.
func load_project(project_dir: String, p_active_tool_ids: Array[String] = []) -> void:
	current_project_dir = project_dir
	active_tool_ids.clear()
	
	if not p_active_tool_ids.is_empty():
		for tid: String in p_active_tool_ids:
			active_tool_ids.append(tid.to_lower())
	elif not project_dir.is_empty():
		var stack_path: String = project_dir.path_join("ogs_stack.json")
		if FileAccess.file_exists(stack_path):
			var file: FileAccess = FileAccess.open(stack_path, FileAccess.READ)
			if file != null:
				var json_text: String = file.get_as_text()
				file.close()
				var json: JSON = JSON.new()
				if json.parse(json_text) == OK and json.data is Dictionary:
					var tools_val: Variant = (json.data as Dictionary).get("tools", [])
					if tools_val is Array:
						for t: Variant in (tools_val as Array):
							if t is Dictionary and (t as Dictionary).has("id"):
								active_tool_ids.append(String((t as Dictionary)["id"]).to_lower())

	tree.clear()
	
	if current_project_dir.is_empty() or not DirAccess.dir_exists_absolute(current_project_dir):
		return
		
	var root: TreeItem = tree.create_item()
	root.set_text(0, current_project_dir.get_file())
	root.set_metadata(0, {"path": current_project_dir, "is_dir": true})
	
	_populate_dir(current_project_dir, root)

## Traverses and populates child items in the Tree, pruning non-relevant folders.
func _populate_dir(dir_path: String, parent_item: TreeItem) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
		
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var candidate_dirs: Array[String] = []
	var launchable_files: Array[String] = []
	
	while not file_name.is_empty():
		if not file_name.begins_with("."):
			if dir.current_is_dir():
				var full_sub_path: String = dir_path.path_join(file_name)
				if _has_relevant_content(full_sub_path):
					candidate_dirs.append(file_name)
			else:
				if _is_launchable_file(file_name):
					launchable_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	candidate_dirs.sort()
	launchable_files.sort()
	
	for d: String in candidate_dirs:
		var item: TreeItem = tree.create_item(parent_item)
		item.set_text(0, d)
		var full_path: String = dir_path.path_join(d)
		item.set_metadata(0, {"path": full_path, "is_dir": true})
		var tool_id: String = _infer_tool_from_folder(full_path)
		if not tool_id.is_empty():
			var icon: Texture2D = _get_tool_icon(tool_id)
			if icon != null:
				item.set_icon(0, icon)
				item.set_icon_max_width(0, ICON_MAX_WIDTH)
		_populate_dir(full_path, item)
		
	for f: String in launchable_files:
		var item: TreeItem = tree.create_item(parent_item)
		item.set_text(0, f)
		var full_path: String = dir_path.path_join(f)
		item.set_metadata(0, {"path": full_path, "is_dir": false})
		var tool_id: String = _get_tool_for_file(full_path)
		if not tool_id.is_empty():
			var icon: Texture2D = _get_tool_icon(tool_id)
			if icon != null:
				item.set_icon(0, icon)
				item.set_icon_max_width(0, ICON_MAX_WIDTH)

## Checks whether a directory or any of its non-dot-prefixed descendants
## contains at least one launchable file or at least one direct tool folder.
func _has_relevant_content(dir_path: String) -> bool:
	if _is_direct_tool_folder(dir_path):
		return true
		
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return false
		
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var sub_dirs: Array[String] = []
	
	while not file_name.is_empty():
		if not file_name.begins_with("."):
			if dir.current_is_dir():
				sub_dirs.append(dir_path.path_join(file_name))
			else:
				if _is_launchable_file(file_name):
					dir.list_dir_end()
					return true
		file_name = dir.get_next()
	dir.list_dir_end()
	
	for sub_dir: String in sub_dirs:
		if _has_relevant_content(sub_dir):
			return true
			
	return false

## Determines if a file is recognized as launchable based on active tools and exclusions.
func _is_launchable_file(file_name: String) -> bool:
	if FileTypeMapper.is_excluded_file(file_name):
		return false
	if file_name.to_lower() == "project.godot":
		return true
	var ext: String = file_name.get_extension().to_lower()
	if FileTypeMapper.EXTENSION_TO_TOOL.has(ext) and ext != "godot":
		return true
	if _has_vscodium() and FileTypeMapper.is_vscodium_extension(ext):
		return true
	return false

## Returns true if VSCodium is present among the active tool IDs.
func _has_vscodium() -> bool:
	return "vscodium" in active_tool_ids

## Returns the resolved tool ID for a file path within the current project context.
func _get_tool_for_file(file_path: String) -> String:
	var ext: String = file_path.get_extension().to_lower()
	if FileTypeMapper.is_vscodium_extension(ext):
		if not _has_vscodium():
			return ""
	return FileTypeMapper.get_tool_for_file(file_path, active_tool_ids)

## Returns true if the folder directly represents a recognized tool.
func _is_direct_tool_folder(folder_path: String) -> bool:
	return not _infer_tool_from_folder(folder_path).is_empty()

func _on_item_selected() -> void:
	var item: TreeItem = tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if not (meta is Dictionary):
		return
		
	var path: String = String(meta["path"])
	var is_dir: bool = bool(meta["is_dir"])
	
	if is_dir:
		var tool_id: String = _infer_tool_from_folder(path)
		folder_selected.emit(path, tool_id)
	else:
		var tool_id: String = _get_tool_for_file(path)
		file_selected.emit(path, tool_id)

func _on_item_activated() -> void:
	var item: TreeItem = tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if not (meta is Dictionary):
		return

	var is_dir: bool = bool(meta.get("is_dir", false))
	if is_dir:
		if not item.get_children().is_empty():
			item.collapsed = not item.collapsed
	else:
		var path: String = String(meta.get("path", ""))
		var tool_id: String = _get_tool_for_file(path)
		file_activated.emit(path, tool_id)

func _infer_tool_from_folder(folder_path: String) -> String:
	# If they select assets/2D/gimp, the tool is gimp.
	# We can just look at the last folder name and see if its a known tool.
	var folder_name: String = folder_path.get_file().to_lower()
	if ToolCategoryMapper.FALLBACK_CATEGORIES.has(folder_name):
		return folder_name
	if folder_name == "game":
		return "godot"
	return ""

## Returns the cached Texture2D icon for a tool ID, or null if not found.
func _get_tool_icon(tool_id: String) -> Texture2D:
	if tool_id.is_empty():
		return null
	var lower_id: String = tool_id.to_lower()
	if _icon_cache.has(lower_id):
		return _icon_cache[lower_id] as Texture2D
	if TOOL_ICON_PATHS.has(lower_id):
		var icon_path: String = TOOL_ICON_PATHS[lower_id]
		if ResourceLoader.exists(icon_path):
			var res: Resource = load(icon_path)
			if res is Texture2D:
				var tex: Texture2D = res as Texture2D
				_icon_cache[lower_id] = tex
				return tex
	_icon_cache[lower_id] = null
	return null

## Gets the currently selected path, or project root if nothing is selected.
func get_selected_path() -> String:
	var item: TreeItem = tree.get_selected()
	if item != null:
		var meta: Variant = item.get_metadata(0)
		if meta is Dictionary and meta.has("path"):
			return String(meta["path"])
	return current_project_dir

func refresh() -> void:
	load_project(current_project_dir, active_tool_ids)

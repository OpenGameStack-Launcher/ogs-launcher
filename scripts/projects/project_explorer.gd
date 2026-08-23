## ProjectExplorer: Manages the Tree view for the project file hierarchy.

extends RefCounted
class_name ProjectExplorer

const FileTypeMapper = preload("res://scripts/tools/file_type_mapper.gd")
const ToolCategoryMapper = preload("res://scripts/tools/tool_category_mapper.gd")

signal file_selected(file_path: String, tool_id: String)
signal folder_selected(folder_path: String, tool_id: String)

var tree: Tree
var current_project_dir: String = ""

func _init(tree_node: Tree) -> void:
	tree = tree_node
	tree.allow_rmb_select = true
	tree.item_selected.connect(_on_item_selected)
	tree.item_activated.connect(_on_item_activated)
	tree.item_mouse_selected.connect(_on_item_mouse_selected)
	
	_setup_context_menu()

var context_menu: PopupMenu
var context_target_path: String = ""

func _setup_context_menu() -> void:
	context_menu = PopupMenu.new()
	context_menu.add_item("Open in File Explorer", 0)
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	tree.add_child(context_menu)

func _on_item_mouse_selected(position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		var item = tree.get_item_at_position(position)
		if item:
			item.select(0)
			var meta = item.get_metadata(0)
			if meta and meta.has("path"):
				context_target_path = meta["path"]
				var mouse_pos = tree.get_screen_position() + position
				context_menu.popup(Rect2(mouse_pos, Vector2.ZERO))

func _on_context_menu_id_pressed(id: int) -> void:
	if id == 0 and not context_target_path.is_empty():
		var path_to_open = ProjectSettings.globalize_path(context_target_path)
		if not DirAccess.dir_exists_absolute(path_to_open):
			path_to_open = path_to_open.get_base_dir()
		OS.shell_open(path_to_open)

## Loads a new project directory into the Tree.
func load_project(project_dir: String) -> void:
	current_project_dir = project_dir
	tree.clear()
	
	if current_project_dir.is_empty() or not DirAccess.dir_exists_absolute(current_project_dir):
		return
		
	var root = tree.create_item()
	root.set_text(0, current_project_dir.get_file())
	root.set_metadata(0, {"path": current_project_dir, "is_dir": true})
	
	_populate_dir(current_project_dir, root)

func _populate_dir(dir_path: String, parent_item: TreeItem) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var dirs = []
	var files = []
	
	while file_name != "":
		if file_name != "." and file_name != "..":
			if dir.current_is_dir():
				# Hide internal Godot folders
				if file_name != ".godot":
					dirs.append(file_name)
			else:
				var ext = file_name.get_extension().to_lower()
				# Only show files that have an associated tool, or are project.godot
				if FileTypeMapper.EXTENSION_TO_TOOL.has(ext) or file_name.to_lower() == "project.godot":
					files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	dirs.sort()
	files.sort()
	
	for d in dirs:
		var item = tree.create_item(parent_item)
		item.set_text(0, d)
		var full_path = dir_path.path_join(d)
		item.set_metadata(0, {"path": full_path, "is_dir": true})
		_populate_dir(full_path, item)
		
	for f in files:
		var item = tree.create_item(parent_item)
		item.set_text(0, f)
		var full_path = dir_path.path_join(f)
		item.set_metadata(0, {"path": full_path, "is_dir": false})

func _on_item_selected() -> void:
	var item = tree.get_selected()
	if item == null:
		return
	var meta = item.get_metadata(0)
	if meta == null:
		return
		
	var path = String(meta["path"])
	var is_dir = bool(meta["is_dir"])
	
	if is_dir:
		var tool_id = _infer_tool_from_folder(path)
		folder_selected.emit(path, tool_id)
	else:
		var tool_id = FileTypeMapper.get_tool_for_file(path)
		file_selected.emit(path, tool_id)

func _on_item_activated() -> void:
	# Double click to toggle collapse
	var item = tree.get_selected()
	if item != null and item.get_children() != null:
		item.collapsed = not item.collapsed

func _infer_tool_from_folder(folder_path: String) -> String:
	# If they select assets/2D/gimp, the tool is gimp.
	# We can just look at the last folder name and see if its a known tool.
	var folder_name = folder_path.get_file().to_lower()
	if ToolCategoryMapper.FALLBACK_CATEGORIES.has(folder_name):
		return folder_name
	if folder_name == "game":
		return "godot"
	return ""

## Gets the currently selected path, or project root if nothing is selected.
func get_selected_path() -> String:
	var item = tree.get_selected()
	if item != null:
		var meta = item.get_metadata(0)
		if meta != null:
			return meta["path"]
	return current_project_dir

func refresh() -> void:
	load_project(current_project_dir)


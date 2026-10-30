## ProjectExplorerTests: Automated tests for ProjectExplorer directory filtering and pruning.

extends RefCounted
class_name ProjectExplorerTests

const ProjectExplorerScript = preload("res://scripts/projects/project_explorer.gd")
const FileTypeMapperScript = preload("res://scripts/tools/file_type_mapper.gd")

func run() -> Dictionary:
	## Runs all ProjectExplorer automated tests.
	var results: Dictionary = {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	_test_empty_folders_excluded(results)
	_test_folders_with_non_launchable_files_excluded(results)
	_test_direct_tool_folders_and_ancestors_displayed_when_empty(results)
	_test_empty_nested_subfolders_inside_tool_folder_excluded(results)
	_test_dot_prefixed_directories_ignored(results)
	_test_folders_containing_launchable_files_displayed(results)
	_test_zero_launchable_files_and_zero_tool_folders_displays_root_only(results)
	_test_tool_folder_with_non_launchable_files_displayed_but_files_hidden(results)
	_test_selection_signals_and_selected_path(results)
	_test_context_menu_initialized(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _create_test_dir(prefix: String) -> String:
	var path: String = "user://test_explorer_%s_%d" % [prefix, Time.get_ticks_usec()]
	var abs_path: String = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path)
	return abs_path

func _create_file(file_path: String, content: String = "") -> void:
	var base_dir: String = file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()

func _cleanup_dir_recursive(path: String) -> void:
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return
	var dir: DirAccess = DirAccess.open(path)
	if dir != null:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while not file_name.is_empty():
			if file_name != "." and file_name != "..":
				var full_path: String = path.path_join(file_name)
				if dir.current_is_dir():
					_cleanup_dir_recursive(full_path)
				else:
					DirAccess.remove_absolute(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(path)

func _collect_item_texts(item: TreeItem) -> Array[String]:
	var texts: Array[String] = []
	if item == null:
		return texts
	texts.append(item.get_text(0))
	for child: TreeItem in item.get_children():
		texts.append_array(_collect_item_texts(child))
	return texts

func _find_child_item(parent: TreeItem, text: String) -> TreeItem:
	if parent == null:
		return null
	for child: TreeItem in parent.get_children():
		if child.get_text(0) == text:
			return child
		var found: TreeItem = _find_child_item(child, text)
		if found != null:
			return found
	return null

func _test_empty_folders_excluded(results: Dictionary) -> void:
	## Empty folders that are not direct tool folders or ancestors must be pruned.
	var proj: String = _create_test_dir("empty_folders")
	DirAccess.make_dir_recursive_absolute(proj.path_join("empty_folder"))
	DirAccess.make_dir_recursive_absolute(proj.path_join("docs/nested_empty"))
	
	var tree: Tree = Tree.new()
	var explorer = ProjectExplorerScript.new(tree)
	explorer.load_project(proj)
	
	var root: TreeItem = tree.get_root()
	_expect(root != null, "root should exist", results)
	if root != null:
		_expect(root.get_children().is_empty(), "empty non-tool folders should be excluded from tree", results)
	
	tree.free()
	_cleanup_dir_recursive(proj)

func _test_folders_with_non_launchable_files_excluded(results: Dictionary) -> void:
	## Folders with only non-launchable files must be pruned unless they are direct tool folders or ancestors.
	var proj: String = _create_test_dir("non_launchable")
	_create_file(proj.path_join("scripts/player.gd"), "extends Node")
	_create_file(proj.path_join("docs/readme.md"), "# Readme")
	_create_file(proj.path_join("data/config.json"), "{}")
	_create_file(proj.path_join("notes/todo.txt"), "TODO")
	_create_file(proj.path_join("textures/icon.png"), "fake png")
	
	var tree: Tree = Tree.new()
	var explorer = ProjectExplorerScript.new(tree)
	explorer.load_project(proj)
	
	var root: TreeItem = tree.get_root()
	_expect(root != null, "root should exist", results)
	if root != null:
		_expect(root.get_children().is_empty(), "folders containing only non-launchable files should be excluded", results)
	
	tree.free()
	_cleanup_dir_recursive(proj)

func _test_direct_tool_folders_and_ancestors_displayed_when_empty(results: Dictionary) -> void:
	## Direct tool folders and their ancestors must be displayed even when empty.
	var proj: String = _create_test_dir("tool_folders")
	DirAccess.make_dir_recursive_absolute(proj.path_join("assets/2D/gimp"))
	DirAccess.make_dir_recursive_absolute(proj.path_join("assets/3D/blender"))
	DirAccess.make_dir_recursive_absolute(proj.path_join("assets/2D/krita"))
	DirAccess.make_dir_recursive_absolute(proj.path_join("assets/Audio/audacity"))
	DirAccess.make_dir_recursive_absolute(proj.path_join("assets/godot"))
	DirAccess.make_dir_recursive_absolute(proj.path_join("game"))
	
	var tree: Tree = Tree.new()
	var explorer = ProjectExplorerScript.new(tree)
	explorer.load_project(proj)
	
	var root: TreeItem = tree.get_root()
	_expect(root != null, "root should exist", results)
	if root != null:
		var texts: Array[String] = _collect_item_texts(root)
		_expect(texts.has("assets"), "ancestor folder assets should be displayed", results)
		_expect(texts.has("2D"), "ancestor folder 2D should be displayed", results)
		_expect(texts.has("gimp"), "direct tool folder gimp should be displayed even when empty", results)
		_expect(texts.has("3D"), "ancestor folder 3D should be displayed", results)
		_expect(texts.has("blender"), "direct tool folder blender should be displayed even when empty", results)
		_expect(texts.has("krita"), "direct tool folder krita should be displayed even when empty", results)
		_expect(texts.has("Audio"), "ancestor folder Audio should be displayed", results)
		_expect(texts.has("audacity"), "direct tool folder audacity should be displayed even when empty", results)
		_expect(texts.has("godot"), "direct tool folder godot should be displayed even when empty", results)
		_expect(texts.has("game"), "direct tool folder game should be displayed even when empty", results)
	
	tree.free()
	_cleanup_dir_recursive(proj)

func _test_empty_nested_subfolders_inside_tool_folder_excluded(results: Dictionary) -> void:
	## Empty subfolders inside direct tool folders must be excluded.
	var proj: String = _create_test_dir("nested_tool_subfolders")
	DirAccess.make_dir_recursive_absolute(proj.path_join("assets/2D/gimp/characters"))
	DirAccess.make_dir_recursive_absolute(proj.path_join("assets/3D/blender/props"))
	
	var tree: Tree = Tree.new()
	var explorer = ProjectExplorerScript.new(tree)
	explorer.load_project(proj)
	
	var root: TreeItem = tree.get_root()
	_expect(root != null, "root should exist", results)
	if root != null:
		var texts: Array[String] = _collect_item_texts(root)
		_expect(texts.has("gimp"), "gimp tool folder should be displayed", results)
		_expect(texts.has("blender"), "blender tool folder should be displayed", results)
		_expect(not texts.has("characters"), "empty nested subfolder characters inside gimp should be excluded", results)
		_expect(not texts.has("props"), "empty nested subfolder props inside blender should be excluded", results)
	
	tree.free()
	_cleanup_dir_recursive(proj)

func _test_dot_prefixed_directories_ignored(results: Dictionary) -> void:
	## Dot-prefixed directories must be completely ignored during traversal.
	var proj: String = _create_test_dir("dot_dirs")
	_create_file(proj.path_join(".git/hooks/tool.blend"), "dummy")
	DirAccess.make_dir_recursive_absolute(proj.path_join(".git/gimp"))
	_create_file(proj.path_join(".godot/imported/sample.blend"), "dummy")
	_create_file(proj.path_join(".worktrees/issue-100/assets/game/project.godot"), "dummy")
	_create_file(proj.path_join(".github/workflows/ci.blend"), "dummy")
	
	var tree: Tree = Tree.new()
	var explorer = ProjectExplorerScript.new(tree)
	explorer.load_project(proj)
	
	var root: TreeItem = tree.get_root()
	_expect(root != null, "root should exist", results)
	if root != null:
		var texts: Array[String] = _collect_item_texts(root)
		_expect(not texts.has(".git"), ".git directory should be ignored", results)
		_expect(not texts.has(".godot"), ".godot directory should be ignored", results)
		_expect(not texts.has(".worktrees"), ".worktrees directory should be ignored", results)
		_expect(not texts.has(".github"), ".github directory should be ignored", results)
		_expect(not texts.has("tool.blend"), "files inside dot-prefixed dirs should be ignored", results)
		_expect(not texts.has("sample.blend"), "files inside dot-prefixed dirs should be ignored", results)
		_expect(root.get_children().is_empty(), "tree should have no children when only dot dirs exist", results)
	
	tree.free()
	_cleanup_dir_recursive(proj)

func _test_folders_containing_launchable_files_displayed(results: Dictionary) -> void:
	## Folders containing launchable files and all their ancestors must be displayed.
	var proj: String = _create_test_dir("launchable_files")
	_create_file(proj.path_join("project.godot"), "; godot project")
	_create_file(proj.path_join("art/2D/sprites/hero.xcf"), "xcf data")
	_create_file(proj.path_join("models/environment/dungeon.blend"), "blend data")
	_create_file(proj.path_join("textures/paintings/canvas.kra"), "kra data")
	_create_file(proj.path_join("audio/music/intro.aup3"), "aup3 data")
	
	# Non-launchable files to verify they are omitted
	_create_file(proj.path_join("art/2D/sprites/hero.png"), "png data")
	_create_file(proj.path_join("docs/manual.md"), "manual")
	
	var tree: Tree = Tree.new()
	var explorer = ProjectExplorerScript.new(tree)
	explorer.load_project(proj)
	
	var root: TreeItem = tree.get_root()
	_expect(root != null, "root should exist", results)
	if root != null:
		var texts: Array[String] = _collect_item_texts(root)
		_expect(texts.has("project.godot"), "project.godot at root should be displayed", results)
		_expect(texts.has("art"), "art ancestor should be displayed", results)
		_expect(texts.has("2D"), "2D ancestor should be displayed", results)
		_expect(texts.has("sprites"), "sprites folder should be displayed", results)
		_expect(texts.has("hero.xcf"), "hero.xcf should be displayed", results)
		_expect(texts.has("models"), "models ancestor should be displayed", results)
		_expect(texts.has("environment"), "environment folder should be displayed", results)
		_expect(texts.has("dungeon.blend"), "dungeon.blend should be displayed", results)
		_expect(texts.has("textures"), "textures ancestor should be displayed", results)
		_expect(texts.has("paintings"), "paintings folder should be displayed", results)
		_expect(texts.has("canvas.kra"), "canvas.kra should be displayed", results)
		_expect(texts.has("audio"), "audio ancestor should be displayed", results)
		_expect(texts.has("music"), "music folder should be displayed", results)
		_expect(texts.has("intro.aup3"), "intro.aup3 should be displayed", results)
		_expect(not texts.has("hero.png"), "non-launchable hero.png should NOT be displayed", results)
		_expect(not texts.has("docs"), "unrelated docs folder should NOT be displayed", results)
		_expect(not texts.has("manual.md"), "non-launchable manual.md should NOT be displayed", results)
	
	tree.free()
	_cleanup_dir_recursive(proj)

func _test_zero_launchable_files_and_zero_tool_folders_displays_root_only(results: Dictionary) -> void:
	## A project with zero launchable files and zero tool folders displays only the root node.
	var proj: String = _create_test_dir("zero_content")
	_create_file(proj.path_join("src/main.gd"), "extends Node")
	_create_file(proj.path_join("docs/changelog.txt"), "Changelog")
	DirAccess.make_dir_recursive_absolute(proj.path_join("empty_sub"))
	
	var tree: Tree = Tree.new()
	var explorer = ProjectExplorerScript.new(tree)
	explorer.load_project(proj)
	
	var root: TreeItem = tree.get_root()
	_expect(root != null, "root item should exist", results)
	if root != null:
		_expect(root.get_children().is_empty(), "root item should have zero child nodes", results)
		_expect(root.get_text(0) == proj.get_file(), "root item text should match project directory name", results)
	
	tree.free()
	_cleanup_dir_recursive(proj)

func _test_tool_folder_with_non_launchable_files_displayed_but_files_hidden(results: Dictionary) -> void:
	## A direct tool folder containing only non-launchable files is displayed, but files are omitted.
	var proj: String = _create_test_dir("tool_non_launchable")
	_create_file(proj.path_join("assets/2D/gimp/notes.txt"), "notes")
	_create_file(proj.path_join("assets/2D/gimp/palette.gpl"), "gpl data")
	
	var tree: Tree = Tree.new()
	var explorer = ProjectExplorerScript.new(tree)
	explorer.load_project(proj)
	
	var root: TreeItem = tree.get_root()
	_expect(root != null, "root should exist", results)
	if root != null:
		var texts: Array[String] = _collect_item_texts(root)
		_expect(texts.has("assets"), "assets should be displayed", results)
		_expect(texts.has("2D"), "2D should be displayed", results)
		_expect(texts.has("gimp"), "gimp tool folder should be displayed", results)
		_expect(not texts.has("notes.txt"), "non-launchable notes.txt should NOT be displayed", results)
		_expect(not texts.has("palette.gpl"), "non-launchable palette.gpl should NOT be displayed", results)
		
		var gimp_item: TreeItem = _find_child_item(root, "gimp")
		_expect(gimp_item != null, "gimp item should be found", results)
		if gimp_item != null:
			_expect(gimp_item.get_children().is_empty(), "gimp item should have no children since files are non-launchable", results)
	
	tree.free()
	_cleanup_dir_recursive(proj)

func _test_selection_signals_and_selected_path(results: Dictionary) -> void:
	## Selection signals and get_selected_path work correctly with pruned trees.
	var proj: String = _create_test_dir("selection_test")
	DirAccess.make_dir_recursive_absolute(proj.path_join("assets/2D/gimp"))
	DirAccess.make_dir_recursive_absolute(proj.path_join("game"))
	_create_file(proj.path_join("models/character.blend"), "blend data")
	
	var tree: Tree = Tree.new()
	var explorer = ProjectExplorerScript.new(tree)
	
	var selected_folder_path: Array[String] = [""]
	var selected_folder_tool: Array[String] = [""]
	var selected_file_path: Array[String] = [""]
	var selected_file_tool: Array[String] = [""]
	
	explorer.folder_selected.connect(func(path: String, tool_id: String) -> void:
		selected_folder_path[0] = path
		selected_folder_tool[0] = tool_id
	)
	explorer.file_selected.connect(func(path: String, tool_id: String) -> void:
		selected_file_path[0] = path
		selected_file_tool[0] = tool_id
	)
	
	explorer.load_project(proj)
	var root: TreeItem = tree.get_root()
	_expect(root != null, "root should exist", results)
	
	if root != null:
		# Root selection
		root.select(0)
		_expect(explorer.get_selected_path() == proj, "get_selected_path should return project root when root selected", results)
		
		# Direct tool folder selection (gimp)
		var gimp_item: TreeItem = _find_child_item(root, "gimp")
		_expect(gimp_item != null, "gimp item should be found", results)
		if gimp_item != null:
			gimp_item.select(0)
			explorer._on_item_selected()
			_expect(selected_folder_tool[0] == "gimp", "folder_selected should emit tool_id gimp", results)
			_expect(selected_folder_path[0].ends_with("gimp"), "folder_selected should emit correct path for gimp", results)
			_expect(explorer.get_selected_path() == selected_folder_path[0], "get_selected_path should return gimp folder path", results)
		
		# Direct tool folder selection (game -> godot)
		var game_item: TreeItem = _find_child_item(root, "game")
		_expect(game_item != null, "game item should be found", results)
		if game_item != null:
			game_item.select(0)
			explorer._on_item_selected()
			_expect(selected_folder_tool[0] == "godot", "game folder should emit tool_id godot", results)
			_expect(selected_folder_path[0].ends_with("game"), "folder_selected should emit correct path for game", results)
		
		# Launchable file selection (character.blend -> blender)
		var blend_item: TreeItem = _find_child_item(root, "character.blend")
		_expect(blend_item != null, "character.blend item should be found", results)
		if blend_item != null:
			blend_item.select(0)
			explorer._on_item_selected()
			_expect(selected_file_tool[0] == "blender", "file_selected should emit tool_id blender", results)
			_expect(selected_file_path[0].ends_with("character.blend"), "file_selected should emit correct path for blend file", results)
			_expect(explorer.get_selected_path() == selected_file_path[0], "get_selected_path should return blend file path", results)
	
	tree.free()
	_cleanup_dir_recursive(proj)

func _test_context_menu_initialized(results: Dictionary) -> void:
	## Context menu should be properly initialized and attached.
	var tree: Tree = Tree.new()
	var explorer = ProjectExplorerScript.new(tree)
	
	_expect(explorer.context_menu != null, "context menu should be initialized", results)
	if explorer.context_menu != null:
		_expect(explorer.context_menu.get_item_count() > 0, "context menu should have items", results)
		_expect(explorer.context_menu.get_item_text(0) == "Open in File Explorer", "context menu should contain Open in File Explorer", results)
	
	tree.free()

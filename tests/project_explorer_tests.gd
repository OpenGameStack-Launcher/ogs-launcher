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
	_test_launchable_files_receive_tool_icons(results)
	_test_direct_tool_folders_receive_tool_icons(results)
	_test_container_folders_have_null_icons(results)
	_test_icon_cache_reuses_textures(results)
	_test_vscodium_files_displayed_and_emit_selection(results)
	_test_metadata_files_hidden_even_when_json_supported(results)
	_test_vscodium_files_pruned_when_not_in_stack(results)
	_test_double_click_file_activated_signal(results)
	_test_load_project_reads_stack_json_when_tools_omitted(results)
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

func _test_launchable_files_receive_tool_icons(results: Dictionary) -> void:
	## Launchable files (project.godot, .xcf, .blend, .kra, .aup3) must receive the correct tool icon and max width 20.
	var proj: String = _create_test_dir("file_icons")
	_create_file(proj.path_join("project.godot"), "; godot project")
	_create_file(proj.path_join("art/hero.xcf"), "xcf data")
	_create_file(proj.path_join("models/character.blend"), "blend data")
	_create_file(proj.path_join("paintings/canvas.kra"), "kra data")
	_create_file(proj.path_join("audio/theme.aup3"), "aup3 data")
	
	var tree: Tree = Tree.new()
	var explorer = ProjectExplorerScript.new(tree)
	explorer.load_project(proj)
	
	var root: TreeItem = tree.get_root()
	_expect(root != null, "root item should exist", results)
	if root != null:
		var godot_item: TreeItem = _find_child_item(root, "project.godot")
		_expect(godot_item != null, "project.godot item should exist", results)
		if godot_item != null:
			var icon: Texture2D = godot_item.get_icon(0)
			_expect(icon != null, "project.godot should have a tool icon", results)
			if icon != null:
				_expect(icon.resource_path == ProjectExplorerScript.TOOL_ICON_PATHS["godot"], "project.godot icon should match godot tool icon path", results)
			_expect(godot_item.get_icon_max_width(0) == 20, "project.godot icon max width should be 20", results)
			
		var gimp_item: TreeItem = _find_child_item(root, "hero.xcf")
		_expect(gimp_item != null, "hero.xcf item should exist", results)
		if gimp_item != null:
			var icon: Texture2D = gimp_item.get_icon(0)
			_expect(icon != null, "hero.xcf should have a tool icon", results)
			if icon != null:
				_expect(icon.resource_path == ProjectExplorerScript.TOOL_ICON_PATHS["gimp"], "hero.xcf icon should match gimp tool icon path", results)
			_expect(gimp_item.get_icon_max_width(0) == 20, "hero.xcf icon max width should be 20", results)
			
		var blender_item: TreeItem = _find_child_item(root, "character.blend")
		_expect(blender_item != null, "character.blend item should exist", results)
		if blender_item != null:
			var icon: Texture2D = blender_item.get_icon(0)
			_expect(icon != null, "character.blend should have a tool icon", results)
			if icon != null:
				_expect(icon.resource_path == ProjectExplorerScript.TOOL_ICON_PATHS["blender"], "character.blend icon should match blender tool icon path", results)
			_expect(blender_item.get_icon_max_width(0) == 20, "character.blend icon max width should be 20", results)
			
		var krita_item: TreeItem = _find_child_item(root, "canvas.kra")
		_expect(krita_item != null, "canvas.kra item should exist", results)
		if krita_item != null:
			var icon: Texture2D = krita_item.get_icon(0)
			_expect(icon != null, "canvas.kra should have a tool icon", results)
			if icon != null:
				_expect(icon.resource_path == ProjectExplorerScript.TOOL_ICON_PATHS["krita"], "canvas.kra icon should match krita tool icon path", results)
			_expect(krita_item.get_icon_max_width(0) == 20, "canvas.kra icon max width should be 20", results)
			
		var audacity_item: TreeItem = _find_child_item(root, "theme.aup3")
		_expect(audacity_item != null, "theme.aup3 item should exist", results)
		if audacity_item != null:
			var icon: Texture2D = audacity_item.get_icon(0)
			_expect(icon != null, "theme.aup3 should have a tool icon", results)
			if icon != null:
				_expect(icon.resource_path == ProjectExplorerScript.TOOL_ICON_PATHS["audacity"], "theme.aup3 icon should match audacity tool icon path", results)
			_expect(audacity_item.get_icon_max_width(0) == 20, "theme.aup3 icon max width should be 20", results)
	
	tree.free()
	_cleanup_dir_recursive(proj)

func _test_direct_tool_folders_receive_tool_icons(results: Dictionary) -> void:
	## Direct tool folders (gimp, blender, krita, audacity, godot, game) must receive the correct tool icon and max width 20.
	var proj: String = _create_test_dir("folder_icons")
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
	_expect(root != null, "root item should exist", results)
	if root != null:
		var check_folders: Dictionary = {
			"gimp": "gimp",
			"blender": "blender",
			"krita": "krita",
			"audacity": "audacity",
			"godot": "godot",
			"game": "godot"
		}
		for folder_name: String in check_folders:
			var item: TreeItem = _find_child_item(root, folder_name)
			_expect(item != null, "%s folder item should exist" % folder_name, results)
			if item != null:
				var expected_tool: String = check_folders[folder_name]
				var icon: Texture2D = item.get_icon(0)
				_expect(icon != null, "%s folder should have an icon" % folder_name, results)
				if icon != null:
					_expect(icon.resource_path == ProjectExplorerScript.TOOL_ICON_PATHS[expected_tool], "%s folder icon should match %s tool icon" % [folder_name, expected_tool], results)
				_expect(item.get_icon_max_width(0) == 20, "%s folder icon max width should be 20" % folder_name, results)
	
	tree.free()
	_cleanup_dir_recursive(proj)

func _test_container_folders_have_null_icons(results: Dictionary) -> void:
	## Container folders (project root, assets, 2D, 3D, Audio, and nested subfolders inside tool folders) must have null icons.
	var proj: String = _create_test_dir("container_null_icons")
	_create_file(proj.path_join("assets/2D/gimp/characters/hero.xcf"), "xcf data")
	_create_file(proj.path_join("assets/3D/blender/props/sword.blend"), "blend data")
	_create_file(proj.path_join("assets/Audio/audacity/voiceover/take1.aup3"), "aup3 data")
	
	var tree: Tree = Tree.new()
	var explorer = ProjectExplorerScript.new(tree)
	explorer.load_project(proj)
	
	var root: TreeItem = tree.get_root()
	_expect(root != null, "root item should exist", results)
	if root != null:
		_expect(root.get_icon(0) == null, "project root folder must have null icon", results)
		
		var assets_item: TreeItem = _find_child_item(root, "assets")
		_expect(assets_item != null, "assets item should exist", results)
		if assets_item != null:
			_expect(assets_item.get_icon(0) == null, "assets container folder must have null icon", results)
			
		var item_2d: TreeItem = _find_child_item(root, "2D")
		_expect(item_2d != null, "2D item should exist", results)
		if item_2d != null:
			_expect(item_2d.get_icon(0) == null, "2D container folder must have null icon", results)
			
		var item_3d: TreeItem = _find_child_item(root, "3D")
		_expect(item_3d != null, "3D item should exist", results)
		if item_3d != null:
			_expect(item_3d.get_icon(0) == null, "3D container folder must have null icon", results)
			
		var audio_item: TreeItem = _find_child_item(root, "Audio")
		_expect(audio_item != null, "Audio item should exist", results)
		if audio_item != null:
			_expect(audio_item.get_icon(0) == null, "Audio container folder must have null icon", results)
			
		var characters_item: TreeItem = _find_child_item(root, "characters")
		_expect(characters_item != null, "characters nested subfolder should exist", results)
		if characters_item != null:
			_expect(characters_item.get_icon(0) == null, "nested characters subfolder inside tool folder must have null icon", results)
			
		var props_item: TreeItem = _find_child_item(root, "props")
		_expect(props_item != null, "props nested subfolder should exist", results)
		if props_item != null:
			_expect(props_item.get_icon(0) == null, "nested props subfolder inside tool folder must have null icon", results)
			
		var voiceover_item: TreeItem = _find_child_item(root, "voiceover")
		_expect(voiceover_item != null, "voiceover nested subfolder should exist", results)
		if voiceover_item != null:
			_expect(voiceover_item.get_icon(0) == null, "nested voiceover subfolder inside tool folder must have null icon", results)
			
		# Also verify the direct tool folders and files themselves DO have icons
		var gimp_item: TreeItem = _find_child_item(root, "gimp")
		_expect(gimp_item != null and gimp_item.get_icon(0) != null, "gimp direct tool folder should have icon", results)
		var hero_item: TreeItem = _find_child_item(root, "hero.xcf")
		_expect(hero_item != null and hero_item.get_icon(0) != null, "hero.xcf should have icon", results)
	
	tree.free()
	_cleanup_dir_recursive(proj)

func _test_icon_cache_reuses_textures(results: Dictionary) -> void:
	## ProjectExplorer should cache loaded Texture2D icon resources.
	var tree: Tree = Tree.new()
	var explorer = ProjectExplorerScript.new(tree)
	
	var godot_icon1: Texture2D = explorer._get_tool_icon("godot")
	_expect(godot_icon1 != null, "_get_tool_icon('godot') should return Texture2D", results)
	_expect(explorer._icon_cache.has("godot"), "_icon_cache should have 'godot' key", results)
	
	var godot_icon2: Texture2D = explorer._get_tool_icon("godot")
	_expect(godot_icon1 == godot_icon2, "cached icon must return exact same object reference", results)
	
	var nonexistent: Texture2D = explorer._get_tool_icon("nonexistent_tool")
	_expect(nonexistent == null, "unknown tool ID should return null", results)
	_expect(explorer._icon_cache.has("nonexistent_tool"), "_icon_cache should record null for missing tool", results)
	
	tree.free()

func _test_vscodium_files_displayed_and_emit_selection(results: Dictionary) -> void:
	## When vscodium is in the stack, all mapped extensions appear, show the icon, and emit "vscodium" on selection.
	var proj: String = _create_test_dir("vscodium_files")
	var exts: Array[String] = [
		"gd", "cs", "gdshader", "shader", "txt", "md", "csv", "json", "yaml", "yml", "toml"
	]
	for ext: String in exts:
		_create_file(proj.path_join("src/sample.%s" % ext), "content")

	var tree: Tree = Tree.new()
	var explorer = ProjectExplorerScript.new(tree)
	var active_tools: Array[String] = ["godot", "vscodium"]
	explorer.load_project(proj, active_tools)

	var selected_path: Array[String] = [""]
	var selected_tool: Array[String] = [""]
	explorer.file_selected.connect(func(path: String, tool_id: String) -> void:
		selected_path[0] = path
		selected_tool[0] = tool_id
	)

	var root: TreeItem = tree.get_root()
	_expect(root != null, "root should exist", results)
	if root != null:
		var texts: Array[String] = _collect_item_texts(root)
		_expect(texts.has("src"), "src folder should appear in tree", results)
		for ext: String in exts:
			var fname: String = "sample.%s" % ext
			_expect(texts.has(fname), "%s should appear in tree when vscodium is in stack" % fname, results)
			var item: TreeItem = _find_child_item(root, fname)
			if item != null:
				var icon: Texture2D = item.get_icon(0)
				_expect(icon != null, "%s should have an icon" % fname, results)
				if icon != null:
					_expect(icon.resource_path == ProjectExplorerScript.TOOL_ICON_PATHS["vscodium"], "%s icon should match vscodium tool icon" % fname, results)
				_expect(item.get_icon_max_width(0) == 20, "%s icon max width should be 20" % fname, results)

				# Test selection
				item.select(0)
				explorer._on_item_selected()
				_expect(selected_tool[0] == "vscodium", "selecting %s should emit vscodium" % fname, results)
				_expect(selected_path[0].ends_with(fname), "selecting %s should emit correct path" % fname, results)

	tree.free()
	_cleanup_dir_recursive(proj)

func _test_metadata_files_hidden_even_when_json_supported(results: Dictionary) -> void:
	## Internal metadata files (stack.json, ogs_config.json, ogs_metadata.json, .import, .uid, .cfg, .tres, .tscn) are never displayed.
	var proj: String = _create_test_dir("metadata_hidden")
	_create_file(proj.path_join("stack.json"), '{"stack_name": "Test"}')
	_create_file(proj.path_join("ogs_config.json"), '{"offline_mode": false}')
	_create_file(proj.path_join("ogs_metadata.json"), '{"version": "1.0"}')
	_create_file(proj.path_join("art/hero.png.import"), "import data")
	_create_file(proj.path_join("scripts/player.gd.uid"), "uid data")
	_create_file(proj.path_join("export_presets.cfg"), "cfg data")
	_create_file(proj.path_join("theme.tres"), "tres data")
	_create_file(proj.path_join("level.tscn"), "tscn data")
	_create_file(proj.path_join("data/game_data.json"), '{"score": 100}')

	var tree: Tree = Tree.new()
	var explorer = ProjectExplorerScript.new(tree)
	var active_tools: Array[String] = ["godot", "vscodium"]
	explorer.load_project(proj, active_tools)

	var root: TreeItem = tree.get_root()
	_expect(root != null, "root should exist", results)
	if root != null:
		var texts: Array[String] = _collect_item_texts(root)
		_expect(texts.has("game_data.json"), "user game_data.json should be visible", results)
		_expect(not texts.has("stack.json"), "stack.json must be hidden", results)
		_expect(not texts.has("ogs_config.json"), "ogs_config.json must be hidden", results)
		_expect(not texts.has("ogs_metadata.json"), "ogs_metadata.json must be hidden", results)
		_expect(not texts.has("hero.png.import"), ".import file must be hidden", results)
		_expect(not texts.has("player.gd.uid"), ".uid file must be hidden", results)
		_expect(not texts.has("export_presets.cfg"), ".cfg file must be hidden", results)
		_expect(not texts.has("theme.tres"), ".tres file must be hidden", results)
		_expect(not texts.has("level.tscn"), ".tscn file must be hidden", results)

	tree.free()
	_cleanup_dir_recursive(proj)

func _test_vscodium_files_pruned_when_not_in_stack(results: Dictionary) -> void:
	## When vscodium is NOT in the stack, text and script files are pruned while project.godot and binary assets appear.
	var proj: String = _create_test_dir("no_vscodium_pruning")
	_create_file(proj.path_join("project.godot"), "; godot project")
	_create_file(proj.path_join("art/hero.xcf"), "xcf data")
	_create_file(proj.path_join("models/character.blend"), "blend data")
	_create_file(proj.path_join("textures/canvas.kra"), "kra data")
	_create_file(proj.path_join("audio/music.aup3"), "aup3 data")
	_create_file(proj.path_join("scripts/player.gd"), "extends Node")
	_create_file(proj.path_join("docs/readme.md"), "# Readme")
	_create_file(proj.path_join("data/config.json"), "{}")
	_create_file(proj.path_join("notes/todo.txt"), "TODO")

	var tree: Tree = Tree.new()
	var explorer = ProjectExplorerScript.new(tree)
	var godot_stack: Array[String] = ["godot", "gimp", "blender", "krita", "audacity"]
	explorer.load_project(proj, godot_stack)

	var root: TreeItem = tree.get_root()
	_expect(root != null, "root should exist", results)
	if root != null:
		var texts: Array[String] = _collect_item_texts(root)
		# Binary assets and project.godot appear
		_expect(texts.has("project.godot"), "project.godot should be visible", results)
		_expect(texts.has("hero.xcf"), "hero.xcf should be visible", results)
		_expect(texts.has("character.blend"), "character.blend should be visible", results)
		_expect(texts.has("canvas.kra"), "canvas.kra should be visible", results)
		_expect(texts.has("music.aup3"), "music.aup3 should be visible", results)
		# Text/script files are pruned
		_expect(not texts.has("player.gd"), "player.gd should be pruned when vscodium not in stack", results)
		_expect(not texts.has("readme.md"), "readme.md should be pruned when vscodium not in stack", results)
		_expect(not texts.has("config.json"), "config.json should be pruned when vscodium not in stack", results)
		_expect(not texts.has("todo.txt"), "todo.txt should be pruned when vscodium not in stack", results)
		_expect(not texts.has("scripts"), "scripts folder should be pruned", results)
		_expect(not texts.has("docs"), "docs folder should be pruned", results)
		_expect(not texts.has("data"), "data folder should be pruned", results)
		_expect(not texts.has("notes"), "notes folder should be pruned", results)

	tree.free()
	_cleanup_dir_recursive(proj)

func _test_double_click_file_activated_signal(results: Dictionary) -> void:
	## Double clicking a file emits file_activated(file_path, tool_id).
	var proj: String = _create_test_dir("double_click")
	_create_file(proj.path_join("notes.txt"), "some notes")
	_create_file(proj.path_join("assets/hero.xcf"), "xcf data")

	var tree: Tree = Tree.new()
	var explorer = ProjectExplorerScript.new(tree)
	var active_tools: Array[String] = ["vscodium", "gimp"]
	explorer.load_project(proj, active_tools)

	var activated_path: Array[String] = [""]
	var activated_tool: Array[String] = [""]
	explorer.file_activated.connect(func(path: String, tool_id: String) -> void:
		activated_path[0] = path
		activated_tool[0] = tool_id
	)

	var root: TreeItem = tree.get_root()
	_expect(root != null, "root should exist", results)
	if root != null:
		# Double-click text file
		var text_item: TreeItem = _find_child_item(root, "notes.txt")
		_expect(text_item != null, "notes.txt should exist", results)
		if text_item != null:
			text_item.select(0)
			explorer._on_item_activated()
			_expect(activated_tool[0] == "vscodium", "double clicking text file should emit tool_id vscodium", results)
			_expect(activated_path[0].ends_with("notes.txt"), "double clicking text file should emit correct path", results)

		# Double-click binary asset file
		var xcf_item: TreeItem = _find_child_item(root, "hero.xcf")
		_expect(xcf_item != null, "hero.xcf should exist", results)
		if xcf_item != null:
			xcf_item.select(0)
			explorer._on_item_activated()
			_expect(activated_tool[0] == "gimp", "double clicking xcf file should emit tool_id gimp", results)
			_expect(activated_path[0].ends_with("hero.xcf"), "double clicking xcf file should emit correct path", results)

		# Double-click folder item should NOT emit file_activated
		activated_tool[0] = ""
		activated_path[0] = ""
		var assets_item: TreeItem = _find_child_item(root, "assets")
		_expect(assets_item != null, "assets folder should exist", results)
		if assets_item != null:
			assets_item.select(0)
			explorer._on_item_activated()
			_expect(activated_tool[0] == "", "activating folder should not emit file_activated", results)
			_expect(activated_path[0] == "", "activating folder should not set path", results)

	tree.free()
	_cleanup_dir_recursive(proj)

func _test_load_project_reads_stack_json_when_tools_omitted(results: Dictionary) -> void:
	## When active_tool_ids is omitted, load_project reads tool IDs from stack.json.
	var proj: String = _create_test_dir("stack_json_fallback")
	var stack_content: String = JSON.stringify({
		"stack_name": "TestStack",
		"tools": [
			{"id": "godot", "version": "4.7.2"},
			{"id": "vscodium", "version": "1.143.17232"}
		]
	})
	_create_file(proj.path_join("stack.json"), stack_content)
	_create_file(proj.path_join("scripts/helper.gd"), "extends Node")

	var tree: Tree = Tree.new()
	var explorer = ProjectExplorerScript.new(tree)
	# Call without active_tool_ids parameter
	explorer.load_project(proj)

	_expect("vscodium" in explorer.active_tool_ids, "active_tool_ids should contain vscodium read from stack.json", results)
	_expect("godot" in explorer.active_tool_ids, "active_tool_ids should contain godot read from stack.json", results)

	var root: TreeItem = tree.get_root()
	_expect(root != null, "root should exist", results)
	if root != null:
		var texts: Array[String] = _collect_item_texts(root)
		_expect(texts.has("helper.gd"), "helper.gd should appear because stack.json enabled vscodium", results)

	tree.free()
	_cleanup_dir_recursive(proj)

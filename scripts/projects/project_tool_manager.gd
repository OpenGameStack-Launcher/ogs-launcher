extends RefCounted
class_name ProjectToolManager

const OgsLogger = preload("res://scripts/logging/logger.gd")
const StackManifest = preload("res://scripts/manifest/stack_manifest.gd")
const LibraryManager = preload("res://scripts/library/library_manager.gd")

var _pc
var _ui

func setup(projects_controller, ui_deps) -> void:
	_pc = projects_controller
	_ui = ui_deps

func _on_change_version_pressed() -> void:
	if _pc.current_manifest == null or _pc._selected_tool_index < 0 or _pc._selected_tool_index >= _pc.current_manifest.tools.size():
		return
	var tool_entry = _pc.current_manifest.tools[_pc._selected_tool_index]
	var tool_id = String(tool_entry.get("id", ""))
	if tool_id.is_empty():
		return
	_ui.add_tool_dialog.set_meta("change_version_target", tool_id)
	_on_add_tool_pressed("Change Version for " + tool_id)

func _on_add_tool_pressed(title_override: String = "Add Tool") -> void:
	## Opens catalog picker for adding a new tool entry to current project stack.
	if title_override == "Add Tool":
		_ui.add_tool_dialog.set_meta("change_version_target", "")
	_ui.add_tool_dialog.title = title_override
	if _pc.current_manifest == null or _pc.current_project_dir.is_empty():
		_pc._update_status("Status: Select a project before adding tools.")
		return

	var target_tool_id = String(_ui.add_tool_dialog.get_meta("change_version_target")) if _ui.add_tool_dialog.has_meta("change_version_target") else ""
	var is_change_version = not target_tool_id.is_empty()
	var add_button = _ui.add_tool_dialog.get_ok_button()
	if add_button != null:
		add_button.disabled = true
		add_button.text = "Change to version..." if is_change_version else "Add Tool"
		
	var instructions = _ui.add_tool_dialog.get_node_or_null("VBoxContainer/InstructionsLabel")
	if instructions != null:
		if is_change_version:
			var current_version = "?"
			for tool in _pc.current_manifest.tools:
				if String(tool.get("id", "")) == target_tool_id:
					current_version = String(tool.get("version", ""))
					break
			instructions.text = "Current %s version is %s.\nSelect a version to change to:" % [target_tool_id, current_version]
		else:
			instructions.text = "Select a tool/version to add to this project."
			
	_populate_add_tool_options()
	if _pc._add_tool_candidates.is_empty():
		_pc._update_status("Status: No additional tools available to add.")
		return

	_ui.add_tool_dialog.popup_centered_ratio(0.4)

func _populate_add_tool_options() -> void:
	## Builds add-tool list from catalog and offline-safe local sources.
	_pc._add_tool_candidates.clear()
	_ui.add_tool_option_list.clear()

	var existing_keys: Dictionary = {}
	var existing_tool_ids: Dictionary = {}
	if _pc.current_manifest != null:
		for entry in _pc.current_manifest.tools:
			var id = String(entry.get("id", ""))
			var key = "%s_%s" % [id, String(entry.get("version", ""))]
			existing_keys[key] = true
			existing_tool_ids[id] = true

	var target_tool_id = ""
	if _ui.add_tool_dialog.has_meta("change_version_target"):
		target_tool_id = _ui.add_tool_dialog.get_meta("change_version_target")
		
	var seen_keys: Dictionary = {}
	for tool in _collect_add_tool_catalog_entries():
		var tool_id = String(tool.get("id", "")).strip_edges()
		var version = String(tool.get("version", "")).strip_edges()
		if tool_id.is_empty() or version.is_empty():
			continue
			
		var key = "%s_%s" % [tool_id, version]
		
		if not target_tool_id.is_empty():
			if tool_id != target_tool_id:
				continue
			if existing_keys.has(key):
				continue
		else:
			if existing_tool_ids.has(tool_id):
				continue
				
		if seen_keys.has(key):
			continue
			
		seen_keys[key] = true
		_pc._add_tool_candidates.append({
			"id": tool_id,
			"version": version
		})

	_pc._add_tool_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_key = "%s_%s" % [String(a.get("id", "")), String(a.get("version", ""))]
		var b_key = "%s_%s" % [String(b.get("id", "")), String(b.get("version", ""))]
		return a_key < b_key
	)

	for candidate in _pc._add_tool_candidates:
		var label = "%s v%s" % [String(candidate.get("id", "")), String(candidate.get("version", ""))]
		_ui.add_tool_option_list.add_item(label)

	var add_button = _ui.add_tool_dialog.get_ok_button()
	if add_button != null:
		add_button.custom_minimum_size = Vector2(350, 40)
		add_button.disabled = _pc._add_tool_candidates.is_empty()

	if _ui.add_tool_option_list.item_count > 0:
		_ui.add_tool_option_list.select(0)
		_on_add_tool_item_selected(0)

func _collect_add_tool_catalog_entries() -> Array:
	## Collects tool/version entries from remote catalog and local fallback sources.
## 
## Returns:
## Array: List of dictionaries containing id/version keys
## 
	var entries: Array = []

	entries.append_array(_collect_add_tool_entries_from_tools_controller())
	entries.append_array(_collect_add_tool_entries_from_library())
	entries.append_array(_collect_add_tool_entries_from_tracked_projects())

	return entries

func _collect_add_tool_entries_from_tools_controller() -> Array:
	## Collects id/version entries from ToolsController categorized catalog.
## 
## Returns:
## Array: Tool dictionaries from known repository data
## 
	if _pc.tools_controller == null:
		return []

	var entries: Array = []
	var categorized = _pc.tools_controller.get_categorized_tools()
	for category in categorized.keys():
		for tool in categorized[category]:
			entries.append({
				"id": String(tool.get("id", "")).strip_edges(),
				"version": String(tool.get("version", "")).strip_edges()
			})
	return entries

func _collect_add_tool_entries_from_library() -> Array:
	## Collects installed library tool versions as offline Add Tool candidates.
## 
## Returns:
## Array: Tool dictionaries discovered in local library
## 
	if _pc._library_manager == null:
		return []

	var entries: Array = []
	for tool_id in _pc._library_manager.get_available_tools():
		for version in _pc._library_manager.get_available_versions(String(tool_id)):
			entries.append({
				"id": String(tool_id).strip_edges(),
				"version": String(version).strip_edges()
			})
	return entries

func _collect_add_tool_entries_from_tracked_projects() -> Array:
	## Collects tool/version pairs from tracked project entries as local fallback.
## 
## Returns:
## Array: Tool dictionaries found in project registry snapshots
## 
	var entries: Array = []
	for project_entry in _pc.registry_manager.tracked_projects:
		var project_tools = project_entry.get("tools", [])
		if not (project_tools is Array):
			continue
		for tool in project_tools:
			if not (tool is Dictionary):
				continue
			entries.append({
				"id": String(tool.get("id", "")).strip_edges(),
				"version": String(tool.get("version", "")).strip_edges()
			})
	return entries

func _on_add_tool_item_selected(index: int) -> void:
	## Enables Add Tool confirm action when a list item is selected.
## 
## Parameters:
## index (int): Selected add-tool candidate index
## 
	var add_button = _ui.add_tool_dialog.get_ok_button()
	if add_button != null:
		add_button.disabled = (index < 0 or index >= _pc._add_tool_candidates.size())
		if not add_button.disabled:
			var candidate = _pc._add_tool_candidates[index]
			var tool_id = String(candidate.get("id", ""))
			var version = String(candidate.get("version", ""))
			if _ui.add_tool_dialog.has_meta("change_version_target") and not String(_ui.add_tool_dialog.get_meta("change_version_target")).is_empty():
				add_button.text = "Change to %s version %s" % [tool_id, version]
			else:
				add_button.text = "Add %s version %s" % [tool_id, version]

func _on_add_tool_item_activated(index: int) -> void:
	## Adds tool immediately on double-click activation from Add Tool list.
## 
## Parameters:
## index (int): Activated add-tool candidate index
## 
	if index < 0 or index >= _pc._add_tool_candidates.size():
		return
	_ui.add_tool_option_list.select(index)
	_on_add_tool_confirmed()
	_ui.add_tool_dialog.hide()

func _on_add_tool_confirmed() -> void:
	## Adds selected catalog tool entry to current project's stack manifest.
	var selected_items = _ui.add_tool_option_list.get_selected_items()
	if selected_items.is_empty():
		_pc._update_status("Status: Select a tool to add.")
		return
	var selected = int(selected_items[0])
	if selected < 0 or selected >= _pc._add_tool_candidates.size():
		_pc._update_status("Status: Select a tool to add.")
		return

	var candidate: Dictionary = _pc._add_tool_candidates[selected]
	add_tool_to_current_project(String(candidate.get("id", "")), String(candidate.get("version", "")))

func add_tool_to_current_project(tool_id: String, version: String) -> bool:
	## Adds a tool/version entry to current project's stack.json and refreshes UI.
## 
## Parameters:
## tool_id (String): Tool identifier from repository catalog
## version (String): Tool version string
## 
## Returns:
## bool: True if tool was added and saved successfully
## 
	if _pc.current_manifest == null or _pc.current_project_dir.is_empty():
		_pc._update_status("Status: Select a project before adding tools.")
		return false
	if tool_id.is_empty() or version.is_empty():
		_pc._update_status("Status: Invalid tool selection.")
		return false

	var found_existing = false
	for entry in _pc.current_manifest.tools:
		if String(entry.get("id", "")) == tool_id:
			if String(entry.get("version", "")) == version:
				_pc._update_status("Status: %s v%s is already in this project." % [tool_id, version])
				return false
			else:
				var old_version = String(entry.get("version", ""))
				entry["version"] = version
				_pc._update_status("Status: Updated %s from v%s to v%s." % [tool_id, old_version, version])
				found_existing = true
				break

	if not found_existing:
		_pc.current_manifest.tools.append({
			"id": tool_id,
			"version": version
		})
	
	# Automatically scaffold project directories for the newly added tool
	var tool_category = ToolCategoryMapper.get_category(tool_id)
	if tool_category == "Unknown":
		tool_category = "Other"
		
	if _pc.tools_controller != null and _pc.tools_controller.repository != null:
		for t in _pc.tools_controller.repository.tools:
			if String(t.get("id", "")) == tool_id and String(t.get("version", "")) == version:
				var cat = String(t.get("category", "")).strip_edges()
				if not cat.is_empty():
					tool_category = cat
				break
				
	if tool_id == "godot":
		var godot_project_dir = ToolLauncher._find_existing_godot_project_dir(_pc.current_project_dir)
		if godot_project_dir.is_empty():
			godot_project_dir = _pc.current_project_dir.path_join("game")
			var project_name = ToolLauncher._resolve_ogs_project_name(_pc.current_project_dir)
			ToolLauncher._create_godot_project_file(godot_project_dir, project_name)
	else:
		var asset_dir = _pc.current_project_dir.path_join("assets").path_join(tool_category).path_join(tool_id)
		if not DirAccess.dir_exists_absolute(asset_dir):
			DirAccess.make_dir_recursive_absolute(asset_dir)

	if not _save_current_stack_manifest():
		return false

	if _pc._selected_project_index >= 0:
		_pc._select_project(_pc._selected_project_index)
	_pc._update_status("Status: Added %s v%s to project stack." % [tool_id, version])
	OgsLogger.info("project_tool_added", {
		"component": "projects",
		"tool_id": tool_id,
		"version": version
	})
	return true

func _on_remove_tool_pressed() -> void:
	## Removes currently selected tool entry from project stack manifest.
	if _pc.current_manifest == null or _pc._selected_tool_index < 0 or _pc._selected_tool_index >= _pc.current_manifest.tools.size():
		return
	
	remove_tool_at_index(_pc._selected_tool_index)

func remove_tool_at_index(index: int) -> bool:
	## Removes tool entry at index from current stack.json and refreshes UI.
## 
## Parameters:
## index (int): Tool index in current manifest tools list
## 
## Returns:
## bool: True if removal saved successfully
## 
	if _pc.current_manifest == null or _pc.current_project_dir.is_empty():
		_pc._update_status("Status: Select a project before removing tools.")
		return false
	if index < 0 or index >= _pc.current_manifest.tools.size():
		_pc._update_status("Status: Select a tool before removing it.")
		return false

	var removed_entry = _pc.current_manifest.tools[index]
	var removed_id = String(removed_entry.get("id", "unknown"))
	var removed_version = String(removed_entry.get("version", "?"))
	_pc.current_manifest.tools.remove_at(index)
	_pc._selected_tool_index = -1

	if not _save_current_stack_manifest():
		return false

	if _pc._selected_project_index >= 0:
		_pc._select_project(_pc._selected_project_index)
	_pc._update_status("Status: Removed %s v%s from project stack." % [removed_id, removed_version])
	OgsLogger.info("project_tool_removed", {
		"component": "projects",
		"tool_id": removed_id,
		"version": removed_version
	})
	return true

func _save_current_stack_manifest() -> bool:
	## Persists current stack manifest to stack.json on disk.
## 
## Returns:
## bool: True if manifest write succeeded
## 
	if _pc.current_project_dir.is_empty() or _pc.current_manifest == null:
		return false
	var stack_path = _pc.current_project_dir.path_join("stack.json")
	var payload = _pc.current_manifest.to_dict()
	if not _pc.registry_manager._save_json_file(stack_path, payload):
		_pc._update_status("Status: Failed to update stack.json.")
		OgsLogger.warn("project_stack_save_failed", {
			"component": "projects"
		})
		return false
	return true


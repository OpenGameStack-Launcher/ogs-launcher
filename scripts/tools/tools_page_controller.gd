## ToolsPageController: Manages the tools page UI and updates.
extends RefCounted
class_name ToolsPageController

const OgsLogger = preload("res://scripts/logging/logger.gd")
const OfflineEnforcer = preload("res://scripts/network/offline_enforcer.gd")
const LibraryManager = preload("res://scripts/library/library_manager.gd")
const ToolCategoryMapper = preload("res://scripts/tools/tool_category_mapper.gd")
const PathResolverScript = preload("res://scripts/library/path_resolver.gd")
const PathUtils = preload("res://scripts/utils/path_utils.gd")

const TOOL_ICON_PATHS := {
	"audacity": "res://Images/tools/Audacity.png",
	"blender": "res://Images/tools/Blender.png",
	"gimp": "res://Images/tools/GIMP.png",
	"git": "res://Images/tools/Git.png",
	"godot": "res://Images/tools/Godot.png",
	"krita": "res://Images/tools/Krita.png",
	"vscodium": "res://Images/tools/VSCodium.png"
}

class UIDeps extends RefCounted:
	var tools_tabs: TabContainer
	var installed_content: Container
	var download_content: Container
	var installed_empty_state: Control
	var browse_available_tools_button: Button
	var installed_engine_tools: Container
	var installed_2d_tools: Container
	var installed_3d_tools: Container
	var installed_audio_tools: Container
	var installed_code_tools: Container
	var download_engine_tools: Container
	var download_2d_tools: Container
	var download_3d_tools: Container
	var download_audio_tools: Container
	var download_code_tools: Container
	var tools_status_label: Label
	var tools_offline_message: Label
	var remove_tool_dialog: ConfirmationDialog
	var remove_tool_confirmation_label: Label
	var remove_tool_status_label: Label
	var remove_tool_progress_bar: ProgressBar
	var library_footer: Control
	var library_path_label: Label
	var library_warning_label: Label

var _ui: UIDeps
var _tools_controller: ToolsController
var _progress_controller: ProgressController
var _projects_controller: ProjectsController
var _download_dialog_controller: DownloadDialogController

var tool_cards: Dictionary = {}
var requested_tool_key: String = ""
var removal_thread: Thread = null
var removal_tool_id: String = ""
var removal_tool_version: String = ""
var removal_result: Dictionary = {}

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if removal_thread != null and removal_thread.is_started():
			OgsLogger.warn("tool_removal_thread_join_on_free", {
				"component": "tools_page"
			})
			removal_thread.wait_to_finish()
			removal_thread = null

## Joins running removal thread and releases resources.
func cleanup() -> void:
	if removal_thread != null and removal_thread.is_started():
		OgsLogger.warn("tool_removal_thread_join_on_free", {
			"component": "tools_page"
		})
		removal_thread.wait_to_finish()
		removal_thread = null

func setup(deps: UIDeps, tools_controller: ToolsController, progress_controller: ProgressController, projects_controller: ProjectsController, download_dialog_controller: DownloadDialogController) -> void:
	_ui = deps
	_tools_controller = tools_controller
	_progress_controller = progress_controller
	_projects_controller = projects_controller
	_download_dialog_controller = download_dialog_controller
	
	if _ui != null:
		if _ui.remove_tool_dialog != null:
			_ui.remove_tool_dialog.confirmed.connect(_on_remove_tool_confirmed)
		if _ui.remove_tool_status_label != null:
			_ui.remove_tool_status_label.visible = false
			_ui.remove_tool_status_label.text = ""
		if _ui.remove_tool_progress_bar != null:
			_ui.remove_tool_progress_bar.visible = false
		if _ui.browse_available_tools_button == null and _ui.installed_empty_state != null:
			_ui.browse_available_tools_button = _ui.installed_empty_state.find_child("BrowseAvailableToolsButton", true, false) as Button
		if _ui.browse_available_tools_button != null and not _ui.browse_available_tools_button.pressed.is_connected(_on_browse_available_tools_pressed):
			_ui.browse_available_tools_button.pressed.connect(_on_browse_available_tools_pressed)
		if _ui.library_footer == null and _ui.tools_tabs != null:
			_ui.library_footer = _ui.tools_tabs.find_child("LibraryFooter", true, false) as Control
		if _ui.library_path_label == null and _ui.tools_tabs != null:
			_ui.library_path_label = _ui.tools_tabs.find_child("LibraryPathLabel", true, false) as Label
		if _ui.library_warning_label == null and _ui.tools_tabs != null:
			_ui.library_warning_label = _ui.tools_tabs.find_child("LibraryWarningLabel", true, false) as Label
	
	populate_tools_ui()

## Switches the tools view to the Download tab when the installed empty state action is triggered.
func _on_browse_available_tools_pressed() -> void:
	if _ui != null and _ui.tools_tabs != null:
		_ui.tools_tabs.current_tab = 1
		var tab_bar = _ui.tools_tabs.get_tab_bar()
		if tab_bar != null:
			tab_bar.current_tab = 1

func navigate_to_tool(tool_id: String, tool_version: String) -> void:
	requested_tool_key = "%s_%s" % [tool_id, tool_version]
	if _ui.tools_tabs != null:
		_ui.tools_tabs.current_tab = 1
		var tab_bar = _ui.tools_tabs.get_tab_bar()
		if tab_bar != null:
			tab_bar.current_tab = 1
	_focus_requested_tool_card()

func update_connectivity_status(is_online: bool) -> void:
	if OfflineEnforcer.is_offline():
		_ui.tools_status_label.text = "Status: Offline (enforced: %s)" % OfflineEnforcer.get_reason()
		_ui.tools_status_label.modulate = Color(1, 0.6, 0.2, 1)
		_ui.tools_offline_message.visible = true
	elif is_online:
		_ui.tools_status_label.text = "Status: Online ✓"
		_ui.tools_status_label.modulate = Color.GREEN
		_ui.tools_offline_message.visible = false
	else:
		_ui.tools_status_label.text = "Status: Offline ⚠️"
		_ui.tools_status_label.modulate = Color(1, 0.6, 0.2, 1)
		_ui.tools_offline_message.visible = true

func populate_tools_ui() -> void:
	if _tools_controller == null:
		return
	
	tool_cards.clear()
	_clear_tool_containers()
	
	var installed_count: int = 0
	var available_count: int = 0
	var categorized_tools = _tools_controller.get_categorized_tools()
	for category in categorized_tools.keys():
		var tools = categorized_tools[category]
		if tools.is_empty(): continue
		for tool in tools:
			available_count += 1
			var is_installed = tool["installed"]
			if is_installed:
				installed_count += 1
				_add_tool_card_to_category(category, tool, true)
			_add_tool_card_to_category(category, tool, is_installed, false)

	if _ui != null and _ui.tools_tabs != null:
		_ui.tools_tabs.set_tab_title(0, "Installed (%d)" % installed_count)
		_ui.tools_tabs.set_tab_title(1, "Download (%d)" % available_count)

	_update_category_sections_and_dividers(_get_installed_category_containers(), _get_installed_content())
	_update_category_sections_and_dividers(_get_download_category_containers(), _get_download_content())
	_update_installed_empty_state(installed_count)
	_update_library_footer()

	update_download_button_states()
	_focus_requested_tool_card()

func _clear_tool_containers() -> void:
	if _ui == null:
		return
	var containers = [
		_ui.installed_engine_tools, _ui.installed_2d_tools, _ui.installed_3d_tools, _ui.installed_audio_tools, _ui.installed_code_tools,
		_ui.download_engine_tools, _ui.download_2d_tools, _ui.download_3d_tools, _ui.download_audio_tools, _ui.download_code_tools
	]
	for container in containers:
		if container != null:
			for child in container.get_children():
				container.remove_child(child)
				child.queue_free()

## Returns the list of installed tool category containers configured in UIDeps.
func _get_installed_category_containers() -> Array[Container]:
	if _ui == null:
		return []
	var list: Array[Container] = []
	if _ui.installed_engine_tools != null: list.append(_ui.installed_engine_tools)
	if _ui.installed_2d_tools != null: list.append(_ui.installed_2d_tools)
	if _ui.installed_3d_tools != null: list.append(_ui.installed_3d_tools)
	if _ui.installed_audio_tools != null: list.append(_ui.installed_audio_tools)
	if _ui.installed_code_tools != null: list.append(_ui.installed_code_tools)
	return list

## Returns the list of download tool category containers configured in UIDeps.
func _get_download_category_containers() -> Array[Container]:
	if _ui == null:
		return []
	var list: Array[Container] = []
	if _ui.download_engine_tools != null: list.append(_ui.download_engine_tools)
	if _ui.download_2d_tools != null: list.append(_ui.download_2d_tools)
	if _ui.download_3d_tools != null: list.append(_ui.download_3d_tools)
	if _ui.download_audio_tools != null: list.append(_ui.download_audio_tools)
	if _ui.download_code_tools != null: list.append(_ui.download_code_tools)
	return list

## Resolves the InstalledContent container from UIDeps, container parents, or the scene tree.
func _get_installed_content() -> Container:
	if _ui == null:
		return null
	if _ui.installed_content != null:
		return _ui.installed_content
	if _ui.installed_engine_tools != null and _ui.installed_engine_tools.get_parent() != null and _ui.installed_engine_tools.get_parent().get_parent() is Container:
		return _ui.installed_engine_tools.get_parent().get_parent() as Container
	if _ui.tools_tabs != null:
		return _ui.tools_tabs.find_child("InstalledContent", true, false) as Container
	return null

## Resolves the DownloadContent container from UIDeps, container parents, or the scene tree.
func _get_download_content() -> Container:
	if _ui == null:
		return null
	if _ui.download_content != null:
		return _ui.download_content
	if _ui.download_engine_tools != null and _ui.download_engine_tools.get_parent() != null and _ui.download_engine_tools.get_parent().get_parent() is Container:
		return _ui.download_engine_tools.get_parent().get_parent() as Container
	if _ui.tools_tabs != null:
		return _ui.tools_tabs.find_child("DownloadContent", true, false) as Container
	return null

## Resolves the InstalledEmptyState control from UIDeps or the tools tab hierarchy.
func _get_installed_empty_state() -> Control:
	if _ui == null:
		return null
	if _ui.installed_empty_state != null:
		return _ui.installed_empty_state
	if _ui.tools_tabs != null:
		return _ui.tools_tabs.find_child("InstalledEmptyState", true, false) as Control
	return null

## Toggles InstalledEmptyState and InstalledContent visibility based on installed tool count.
func _update_installed_empty_state(installed_count: int) -> void:
	var empty_state = _get_installed_empty_state()
	var installed_content = _get_installed_content()
	var is_empty: bool = (installed_count == 0)
	
	if empty_state != null:
		empty_state.visible = is_empty
	if installed_content != null:
		installed_content.visible = not is_empty

	var footer = _get_library_footer()
	if footer != null:
		footer.visible = true

## Resolves the LibraryFooter control from UIDeps or the tools tab hierarchy.
func _get_library_footer() -> Control:
	if _ui == null:
		return null
	if _ui.library_footer != null:
		return _ui.library_footer
	if _ui.tools_tabs != null:
		return _ui.tools_tabs.find_child("LibraryFooter", true, false) as Control
	return null

## Resolves the LibraryPathLabel from UIDeps or the tools tab hierarchy.
func _get_library_path_label() -> Label:
	if _ui == null:
		return null
	if _ui.library_path_label != null:
		return _ui.library_path_label
	if _ui.tools_tabs != null:
		return _ui.tools_tabs.find_child("LibraryPathLabel", true, false) as Label
	return null

## Resolves the LibraryWarningLabel from UIDeps or the tools tab hierarchy.
func _get_library_warning_label() -> Label:
	if _ui == null:
		return null
	if _ui.library_warning_label != null:
		return _ui.library_warning_label
	if _ui.tools_tabs != null:
		return _ui.tools_tabs.find_child("LibraryWarningLabel", true, false) as Label
	return null

## Updates the Central Library footer path label and ensures persistent visibility.
func _update_library_footer() -> void:
	var footer = _get_library_footer()
	if footer != null:
		footer.visible = true
	var path_label = _get_library_path_label()
	if path_label != null:
		var resolver = PathResolverScript.new()
		var formatted_path = PathUtils.format_for_display(resolver.get_library_root())
		path_label.text = formatted_path
		path_label.tooltip_text = formatted_path
	var warning_label = _get_library_warning_label()
	if warning_label != null and warning_label.text.is_empty():
		warning_label.text = "⚠️ Do not manually adjust or modify files in the Central Library directory on disk. Use the Tools screen to install and remove software."

## Hides empty category sections and ensures dividers appear strictly between visible sections.
func _update_category_sections_and_dividers(category_containers: Array, content_container: Container) -> void:
	for container in category_containers:
		if container == null:
			continue
		var section = container.get_parent() as CanvasItem
		if section != null:
			section.visible = (container.get_child_count() > 0)
	
	if content_container == null:
		return
	
	for child in content_container.get_children():
		if child is HSeparator:
			continue
		if child is Container:
			var handled: bool = false
			for c in category_containers:
				if c != null and c.get_parent() == child:
					handled = true
					break
			if not handled:
				var tool_container: Container = null
				for sub in child.get_children():
					if sub is Container:
						tool_container = sub as Container
						break
				if tool_container != null:
					child.visible = (tool_container.get_child_count() > 0)
	
	var seen_first_visible_section: bool = false
	var pending_divider: CanvasItem = null
	
	for child in content_container.get_children():
		if child is HSeparator:
			child.visible = false
			if seen_first_visible_section and pending_divider == null:
				pending_divider = child
		elif child is Control and child.visible:
			if seen_first_visible_section and pending_divider != null:
				pending_divider.visible = true
			seen_first_visible_section = true
			pending_divider = null

func _add_tool_card_to_category(category: String, tool: Dictionary, is_installed: bool, target_installed_section: bool = true) -> void:
	var container: VBoxContainer = null
	if target_installed_section:
		match category:
			"Engine": container = _ui.installed_engine_tools
			"2D": container = _ui.installed_2d_tools
			"3D": container = _ui.installed_3d_tools
			"Audio": container = _ui.installed_audio_tools
			"Code": container = _ui.installed_code_tools
	else:
		match category:
			"Engine": container = _ui.download_engine_tools
			"2D": container = _ui.download_2d_tools
			"3D": container = _ui.download_3d_tools
			"Audio": container = _ui.download_audio_tools
			"Code": container = _ui.download_code_tools
	
	if container == null: return
	var card = _create_tool_card(tool, is_installed, target_installed_section)
	container.add_child(card)

func _create_tool_card(tool: Dictionary, is_installed: bool, show_remove_action: bool) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 68)
	card.add_theme_stylebox_override("panel", _create_tool_card_style(is_installed))
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	card.add_child(main_vbox)
	
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 42)
	hbox.add_theme_constant_override("separation", 14)
	main_vbox.add_child(hbox)

	var icon = _create_tool_icon(tool)
	if icon != null:
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(icon)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = "%s %s" % [ToolCategoryMapper.get_display_name(tool["id"]), tool["version"]]
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)
	
	var size_label = Label.new()
	if tool.get("size_bytes", 0) > 0:
		size_label.text = "Size: %.1f MB" % (tool["size_bytes"] / 1048576.0)
		size_label.modulate = Color(0.7, 0.7, 0.7, 1.0)
	vbox.add_child(size_label)
	
	var button = Button.new()
	button.custom_minimum_size = Vector2(115, 36)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if is_installed and show_remove_action:
		button.text = "Remove"
		button.tooltip_text = "Remove this installed tool from the OGS library."
		button.theme_type_variation = &"DangerButton"
		button.pressed.connect(_on_remove_tool_pressed.bind(tool["id"], tool["version"]))
	elif is_installed:
		button.text = "Installed ✓"
		button.disabled = true
	else:
		if _tools_controller != null and _tools_controller.is_downloading(tool["id"], tool["version"]):
			button.text = "Cancel"
			button.theme_type_variation = &"SecondaryButton"
			button.pressed.connect(_on_cancel_tool_download.bind(tool["id"], tool["version"]))
		else:
			button.text = "Download"
			button.theme_type_variation = &"PrimaryButton"
			button.pressed.connect(_on_download_tool_pressed.bind(tool["id"], tool["version"]))
	
	hbox.add_child(button)
	
	var error_label = Label.new()
	error_label.visible = false
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.modulate = Color(1, 0.45, 0.35, 1.0)
	main_vbox.add_child(error_label)
	
	if not is_installed:
		var key = "%s_%s" % [tool["id"], tool["version"]]
		tool_cards[key] = {
			"panel": card,
			"button": button,
			"tool_id": tool["id"],
			"version": tool["version"],
			"error_label": error_label
		}
	
	return card

func _create_tool_icon(tool: Dictionary) -> TextureRect:
	var tool_id = String(tool.get("id", "")).to_lower()
	var icon_path = String(TOOL_ICON_PATHS.get(tool_id, ""))
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path): return null
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(42, 42)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture = load(icon_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.tooltip_text = ToolCategoryMapper.get_display_name(String(tool.get("id", "")))
	return icon

func _create_tool_card_style(is_installed: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.2, 0.96) if is_installed else Color(0.1, 0.13, 0.18, 0.96)
	style.border_color = Color(0.3, 0.55, 0.72, 0.8) if is_installed else Color(0.32, 0.38, 0.48, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12
	style.content_margin_top = 9
	style.content_margin_right = 12
	style.content_margin_bottom = 9
	return style

func update_download_button_states() -> void:
	if _tools_controller == null: return
	var any_active = _tools_controller.has_active_downloads()
	for card_data in tool_cards.values():
		var button = card_data.get("button")
		if button == null: continue
		var t_id = card_data.get("tool_id", "")
		var ver = card_data.get("version", "")
		if _tools_controller.is_downloading(t_id, ver):
			button.disabled = false
			button.tooltip_text = ""
			button.text = "Cancel"
			button.theme_type_variation = &"SecondaryButton"
		else:
			button.text = "Download"
			button.disabled = any_active
			button.tooltip_text = "Wait for the current download to finish." if any_active else ""
			button.theme_type_variation = &"PrimaryButton"

func show_tool_download_error(tool_id: String, version: String, error_message: String) -> void:
	var key = "%s_%s" % [tool_id, version]
	var card_data = tool_cards.get(key)
	if card_data == null: return
	var error_label = card_data.get("error_label")
	if error_label == null: return
	error_label.text = "Download failed: %s" % error_message if not error_message.is_empty() else "Download failed."
	error_label.visible = true

func _on_download_tool_pressed(tool_id: String, version: String) -> void:
	if _tools_controller != null and _download_dialog_controller != null:
		_download_dialog_controller.show_dialog(tool_id, version, _progress_controller)
		_tools_controller.download_tool(tool_id, version)
		update_connectivity_status(_tools_controller.is_online())
		update_download_button_states()

func _on_cancel_tool_download(tool_id: String, version: String) -> void:
	if _tools_controller != null:
		_tools_controller.cancel_download(tool_id, version)
		update_connectivity_status(_tools_controller.is_online())

func _on_remove_tool_pressed(tool_id: String, version: String) -> void:
	if removal_thread != null and removal_thread.is_alive(): return
	removal_tool_id = tool_id
	removal_tool_version = version
	_ui.remove_tool_confirmation_label.text = "Remove %s %s from the OGS library?\nThis deletes its installed files." % [ToolCategoryMapper.get_display_name(tool_id), version]
	_ui.remove_tool_status_label.visible = false
	_ui.remove_tool_status_label.text = ""
	_ui.remove_tool_progress_bar.visible = false
	_ui.remove_tool_progress_bar.indeterminate = false
	_ui.remove_tool_dialog.get_ok_button().disabled = false
	_ui.remove_tool_dialog.get_cancel_button().disabled = false
	if _ui.remove_tool_dialog.is_inside_tree():
		_ui.remove_tool_dialog.size = Vector2i(420, 150)
		_ui.remove_tool_dialog.popup_centered(Vector2i(420, 150))

func _on_remove_tool_confirmed() -> void:
	if removal_tool_id.is_empty() or removal_tool_version.is_empty(): return
	_ui.remove_tool_dialog.get_ok_button().disabled = true
	_ui.remove_tool_dialog.get_cancel_button().disabled = true
	_ui.remove_tool_status_label.visible = true
	_ui.remove_tool_status_label.text = "Removing %s %s..." % [ToolCategoryMapper.get_display_name(removal_tool_id), removal_tool_version]
	_ui.remove_tool_progress_bar.visible = true
	_ui.remove_tool_progress_bar.indeterminate = true
	removal_thread = Thread.new()
	removal_result = {}
	var start_error = removal_thread.start(_remove_tool_on_thread.bind(removal_tool_id, removal_tool_version))
	if start_error != OK:
		removal_thread = null
		_on_tool_removal_finished({"success": false, "error_message": "Could not start the removal operation."})

func _remove_tool_on_thread(tool_id: String, version: String) -> Dictionary:
	var library = LibraryManager.new()
	removal_result = library.remove_tool(tool_id, version)
	call_deferred("_on_tool_removal_thread_finished")
	return removal_result

func _on_tool_removal_thread_finished() -> void:
	if removal_thread == null: return
	var result: Dictionary = removal_thread.wait_to_finish()
	removal_thread = null
	_on_tool_removal_finished(result)

func _on_tool_removal_finished(result: Dictionary) -> void:
	_ui.remove_tool_progress_bar.indeterminate = false
	_ui.remove_tool_progress_bar.visible = false
	_ui.remove_tool_dialog.get_cancel_button().disabled = false
	if result.get("success", false):
		_ui.remove_tool_status_label.visible = true
		_ui.remove_tool_status_label.text = "Removal complete."
		_ui.remove_tool_dialog.hide()
		populate_tools_ui()
		if _projects_controller != null:
			_projects_controller.refresh_project_tools_state()
	else:
		_ui.remove_tool_status_label.visible = true
		_ui.remove_tool_status_label.text = "Removal failed: %s" % result.get("error_message", "Unknown error")
		_ui.remove_tool_dialog.get_ok_button().disabled = false

func _focus_requested_tool_card() -> void:
	if requested_tool_key.is_empty(): return
	var card_data = tool_cards.get(requested_tool_key)
	if card_data == null: return
	if _ui.tools_tabs != null: _ui.tools_tabs.current_tab = 1
	var button = card_data.get("button")
	if button != null: button.grab_focus()
	requested_tool_key = ""

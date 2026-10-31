## ToolsPageSceneTests: Scene-style tests for Tools page UI.
##
## Verifies Tools page nodes exist and download button state handling.

extends RefCounted
class_name ToolsPageSceneTests

const ToolsControllerScript = preload("res://scripts/tools/tools_controller.gd")

func run() -> Dictionary:
	## Runs Tools page scene tests.
## Returns:
## Dictionary: {"passed": int, "failed": int, "failures": Array[String]}
	var results := {"passed": 0, "failed": 0, "failures": []}
	_test_tools_nodes_exist(results)
	_test_connectivity_status_label(results)
	_test_enforced_offline_status_label(results)
	_test_tool_card_style(results)
	_test_download_button_state(results)
	_test_installed_empty_state_nodes_exist(results)
	_test_main_scene_tools_dynamic_collapse_and_empty_state(results)
	_test_remove_tool_dialog_compact_sizing_and_status_visibility(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records test assertion.
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _instantiate_main_scene(results: Dictionary) -> Node:
	## Loads and instantiates main scene.
	var scene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for tools page tests", results)
	if scene == null:
		return null
	return scene.instantiate()

func _test_tools_nodes_exist(results: Dictionary) -> void:
	## Verifies Tools page nodes for Download tab exist.
	var instance = _instantiate_main_scene(results)
	if instance == null:
		return

	_expect(instance.get_node_or_null("AppLayout/Content/PageTools") != null, "Tools page should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs") != null, "Tools tabs should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Download") != null, "Download tab should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Download/MarginContainer") != null, "Download MarginContainer should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Download/MarginContainer/DownloadContent") != null, "Download content should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Download/MarginContainer/DownloadContent/EngineSection/EngineTools") != null, "Download Engine tools container should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Download/MarginContainer/DownloadContent/2DSection/2DTools") != null, "Download 2D tools container should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Download/MarginContainer/DownloadContent/3DSection/3DTools") != null, "Download 3D tools container should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Download/MarginContainer/DownloadContent/AudioSection/AudioTools") != null, "Download Audio tools container should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Download/MarginContainer/DownloadContent/CodeSection/CodeTools") != null, "Download Code tools container should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Installed/MarginContainer") != null, "Installed MarginContainer should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Installed/MarginContainer/InstalledContent/CodeSection/CodeTools") != null, "Installed Code tools container should exist", results)

	var installed_mc: MarginContainer = instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Installed/MarginContainer") as MarginContainer
	var download_mc: MarginContainer = instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Download/MarginContainer") as MarginContainer
	if installed_mc != null:
		_expect(installed_mc.get_theme_constant("margin_right") == 14, "Installed tab MarginContainer should have 14px right margin", results)
	if download_mc != null:
		_expect(download_mc.get_theme_constant("margin_right") == 14, "Download tab MarginContainer should have 14px right margin", results)

	instance.free()

func _test_enforced_offline_status_label(results: Dictionary) -> void:
	## Verifies the Tools status identifies project-enforced offline mode.
	var instance = _instantiate_main_scene(results)
	if instance == null:
		return

	var status_label = instance.get_node_or_null("AppLayout/Content/PageTools/ToolsStatusLabel")
	var offline_label = instance.get_node_or_null("AppLayout/Content/PageTools/OfflineMessage")
	if status_label != null and offline_label != null:
		instance.tools_status_label = status_label
		instance.tools_offline_message = offline_label
		var config = OgsConfig.new()
		config.force_offline = true
		OfflineEnforcer.apply_config(config)
		instance._update_tools_connectivity_status(false)
		_expect(status_label.text.find("enforced: force_offline") != -1, "Tools status should identify enforced offline mode", results)
		OfflineEnforcer.reset()
	else:
		_expect(false, "Tools status labels should exist for enforced offline test", results)

	instance.free()

func _test_connectivity_status_label(results: Dictionary) -> void:
	## Verifies online/offline status updates the Tools status label.
	var instance = _instantiate_main_scene(results)
	if instance == null:
		return

	var status_label = instance.get_node_or_null("AppLayout/Content/PageTools/ToolsStatusLabel")
	var offline_label = instance.get_node_or_null("AppLayout/Content/PageTools/OfflineMessage")
	_expect(status_label != null, "Tools status label should exist", results)
	_expect(offline_label != null, "Tools offline label should exist", results)
	if status_label != null:
		instance.tools_status_label = status_label
		instance.tools_offline_message = offline_label
		instance._update_tools_connectivity_status(true)
		_expect(status_label.text.find("Online") != -1, "Status label should show Online", results)
		instance._update_tools_connectivity_status(false)
		_expect(status_label.text.find("Offline") != -1, "Status label should show Offline", results)

	instance.free()

func _test_tool_card_style(results: Dictionary) -> void:
	## Verifies dynamically-created tool cards have explicit visual separation and semantic button variations.
	var page_controller = ToolsPageController.new()
	var controller = ToolsControllerScript.new(null, "https://example.com/repository.json")
	var deps = ToolsPageController.UIDeps.new()
	var remove_dialog = ConfirmationDialog.new()
	deps.remove_tool_dialog = remove_dialog
	page_controller.setup(deps, controller, null, null, null)

	# 1. Download tool card
	var download_card = page_controller._create_tool_card({"id": "godot", "version": "4.3", "size_bytes": 1024}, false, false)
	_expect(download_card != null, "Download tool card should be created", results)
	if download_card != null:
		var style = download_card.get_theme_stylebox("panel")
		_expect(download_card.custom_minimum_size == Vector2(0, 68), "Tool cards should have 68px minimum height (was: %s)" % str(download_card.custom_minimum_size), results)
		_expect(style is StyleBoxFlat, "Tool cards should use a bordered panel style", results)

		var main_vbox: VBoxContainer = download_card.get_child(0) as VBoxContainer
		_expect(main_vbox != null, "Main VBox should exist in tool card", results)
		if main_vbox != null:
			var hbox: HBoxContainer = main_vbox.get_child(0) as HBoxContainer
			_expect(hbox != null, "HBox should exist in tool card", results)
			if hbox != null:
				_expect(hbox.get_theme_constant("separation") == 14, "HBox should have 14px separation override", results)
				var icon: TextureRect = hbox.get_child(0) as TextureRect
				if icon != null:
					_expect(icon.size_flags_vertical == Control.SIZE_SHRINK_CENTER, "Icon should be vertically centered", results)
				var label_vbox: VBoxContainer = hbox.get_child(1) as VBoxContainer
				if label_vbox != null:
					_expect(label_vbox.size_flags_vertical == Control.SIZE_SHRINK_CENTER, "Label VBox should be vertically centered", results)

		var download_button: Button = _find_button_in_card(download_card)
		_expect(download_button != null, "Download button should exist in download card", results)
		if download_button != null:
			_expect(download_button.text == "Download", "Download button text should be 'Download'", results)
			_expect(download_button.theme_type_variation == &"PrimaryButton", "Download button should have PrimaryButton variation (was: %s)" % String(download_button.theme_type_variation), results)
			_expect(download_button.custom_minimum_size == Vector2(115, 36), "Download button should have 115x36 minimum size (was: %s)" % str(download_button.custom_minimum_size), results)
			_expect(download_button.size_flags_vertical == Control.SIZE_SHRINK_CENTER, "Download button should be vertically centered", results)
		download_card.free()

	# 2. Installed tool card with remove action
	var remove_card = page_controller._create_tool_card({"id": "godot", "version": "4.3", "size_bytes": 1024}, true, true)
	_expect(remove_card != null, "Remove tool card should be created", results)
	if remove_card != null:
		var remove_button: Button = _find_button_in_card(remove_card)
		_expect(remove_button != null, "Remove button should exist in installed tool card with remove action", results)
		if remove_button != null:
			_expect(remove_button.text == "Remove", "Remove button text should be 'Remove'", results)
			_expect(remove_button.theme_type_variation == &"DangerButton", "Remove button should have DangerButton variation (was: %s)" % String(remove_button.theme_type_variation), results)
			_expect(remove_button.custom_minimum_size == Vector2(115, 36), "Remove button should have 115x36 minimum size (was: %s)" % str(remove_button.custom_minimum_size), results)
			_expect(remove_button.size_flags_vertical == Control.SIZE_SHRINK_CENTER, "Remove button should be vertically centered", results)
		remove_card.free()

	# 3. Installed tool card without remove action ("Installed ✓")
	var installed_card = page_controller._create_tool_card({"id": "godot", "version": "4.3", "size_bytes": 1024}, true, false)
	_expect(installed_card != null, "Installed tool card should be created", results)
	if installed_card != null:
		var installed_button: Button = _find_button_in_card(installed_card)
		_expect(installed_button != null, "Installed button should exist", results)
		if installed_button != null:
			_expect(installed_button.text == "Installed ✓", "Button text should be 'Installed ✓'", results)
			_expect(installed_button.disabled == true, "Installed button should be disabled", results)
			_expect(installed_button.custom_minimum_size == Vector2(115, 36), "Installed button should have 115x36 minimum size", results)
			_expect(installed_button.size_flags_vertical == Control.SIZE_SHRINK_CENTER, "Installed button should be vertically centered", results)
		installed_card.free()

	remove_dialog.free()

func _find_button_in_card(node: Node) -> Button:
	for child in node.get_children():
		if child is Button:
			return child as Button
		var found = _find_button_in_card(child)
		if found != null:
			return found
	return null

func _test_download_button_state(results: Dictionary) -> void:
	## Verifies download buttons disable while a download is active and update theme variations.
	var controller = ToolsControllerScript.new(null, "https://example.com/repository.json")
	var page_controller = ToolsPageController.new()
	
	var button_active = Button.new()
	var button_other = Button.new()
	
	page_controller._tools_controller = controller
	page_controller.tool_cards = {
		"godot_4.3": {"button": button_active, "tool_id": "godot", "version": "4.3"},
		"krita_5.2.15": {"button": button_other, "tool_id": "krita", "version": "5.2.15"}
	}
	
	controller._currently_downloading["godot_4.3"] = true
	page_controller.update_download_button_states()
	_expect(button_active.disabled == false, "active download button should be enabled", results)
	_expect(button_active.text == "Cancel", "active download button text should be Cancel", results)
	_expect(button_active.theme_type_variation == &"SecondaryButton", "Cancel download button should have SecondaryButton theme variation", results)
	_expect(button_other.disabled == true, "other download buttons should be disabled", results)
	_expect(button_other.text == "Download", "other download button text should be Download", results)
	_expect(button_other.theme_type_variation == &"PrimaryButton", "Download button should have PrimaryButton theme variation", results)
	
	button_active.free()
	button_other.free()

func _test_installed_empty_state_nodes_exist(results: Dictionary) -> void:
	## Verifies InstalledEmptyState and its child nodes exist in main.tscn.
	var instance = _instantiate_main_scene(results)
	if instance == null:
		return

	var empty_state: VBoxContainer = instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Installed/MarginContainer/InstalledEmptyState") as VBoxContainer
	_expect(empty_state != null, "InstalledEmptyState container should exist in main.tscn", results)
	if empty_state != null:
		var title_label: Label = empty_state.get_node_or_null("InstalledEmptyTitle") as Label
		_expect(title_label != null, "InstalledEmptyTitle label should exist", results)
		if title_label != null:
			_expect(title_label.text == "No Tools Installed Yet", "Empty state title should be 'No Tools Installed Yet' (was: %s)" % title_label.text, results)

		var desc_label: Label = empty_state.get_node_or_null("InstalledEmptyDescription") as Label
		_expect(desc_label != null, "InstalledEmptyDescription label should exist", results)
		if desc_label != null:
			_expect(desc_label.text.find("Central Library") != -1, "Empty state description should mention Central Library (was: %s)" % desc_label.text, results)

		var browse_button: Button = empty_state.get_node_or_null("BrowseAvailableToolsButton") as Button
		_expect(browse_button != null, "BrowseAvailableToolsButton should exist", results)
		if browse_button != null:
			_expect(browse_button.text == "Browse Available Tools", "Browse button text should be 'Browse Available Tools' (was: %s)" % browse_button.text, results)
			_expect(browse_button.theme_type_variation == &"PrimaryButton", "Browse button should have PrimaryButton variation", results)

	instance.free()

func _test_main_scene_tools_dynamic_collapse_and_empty_state(results: Dictionary) -> void:
	## Verifies that populating tools with 0 installed tools correctly hides InstalledContent,
	## shows InstalledEmptyState, hides empty category sections, and hides dividers.
	var instance = _instantiate_main_scene(results)
	if instance == null:
		return

	var empty_state: Control = instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Installed/MarginContainer/InstalledEmptyState") as Control
	var installed_content: Container = instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Installed/MarginContainer/InstalledContent") as Container

	_expect(empty_state != null, "InstalledEmptyState should exist", results)
	_expect(installed_content != null, "InstalledContent should exist", results)

	if instance.tools_page_controller != null:
		instance.tools_page_controller.populate_tools_ui()
		_expect(empty_state.visible == true, "InstalledEmptyState should be visible on fresh startup with 0 installed tools", results)
		_expect(installed_content.visible == false, "InstalledContent should be hidden when 0 tools installed", results)

		for child in installed_content.get_children():
			if child is HSeparator:
				_expect(not child.visible, "Category divider in InstalledContent should be hidden when empty: %s" % child.name, results)
			elif child is Container:
				_expect(not child.visible, "Category section in InstalledContent should be hidden when empty: %s" % child.name, results)

	instance.free()

func _test_remove_tool_dialog_compact_sizing_and_status_visibility(results: Dictionary) -> void:
	## Verifies RemoveToolDialog compact sizing, margin offsets, and status label visibility transitions.
	var instance = _instantiate_main_scene(results)
	if instance == null:
		return
	
	var remove_tool_dialog: ConfirmationDialog = instance.get_node_or_null("RemoveToolDialog") as ConfirmationDialog
	_expect(remove_tool_dialog != null, "RemoveToolDialog should exist", results)
	if remove_tool_dialog != null:
		_expect(remove_tool_dialog.min_size == Vector2i(420, 150), "RemoveToolDialog min_size should be 420x150, got %s" % str(remove_tool_dialog.min_size), results)
		_expect(remove_tool_dialog.size == Vector2i(420, 150), "RemoveToolDialog size should be 420x150, got %s" % str(remove_tool_dialog.size), results)
		
		var vbox: VBoxContainer = remove_tool_dialog.get_node_or_null("VBoxContainer") as VBoxContainer
		_expect(vbox != null, "RemoveToolDialog VBoxContainer should exist", results)
		if vbox != null:
			_expect(vbox.offset_left == 16.0, "RemoveToolDialog VBoxContainer offset_left should be 16px, got %f" % vbox.offset_left, results)
			_expect(vbox.offset_top == 12.0, "RemoveToolDialog VBoxContainer offset_top should be 12px, got %f" % vbox.offset_top, results)
			_expect(vbox.offset_right == -16.0, "RemoveToolDialog VBoxContainer offset_right should be -16px, got %f" % vbox.offset_right, results)
			
		var status_label: Label = remove_tool_dialog.get_node_or_null("VBoxContainer/StatusLabel") as Label
		var progress_bar: ProgressBar = remove_tool_dialog.get_node_or_null("VBoxContainer/ProgressBar") as ProgressBar
		_expect(status_label != null, "RemoveToolDialog StatusLabel should exist", results)
		_expect(progress_bar != null, "RemoveToolDialog ProgressBar should exist", results)
		
		if status_label != null:
			_expect(status_label.visible == false, "StatusLabel should default to hidden in scene", results)
		if progress_bar != null:
			_expect(progress_bar.visible == false, "ProgressBar should default to hidden in scene", results)
			
	# Test controller runtime behavior
	var page_controller = ToolsPageController.new()
	var deps = ToolsPageController.UIDeps.new()
	deps.remove_tool_dialog = remove_tool_dialog
	deps.remove_tool_confirmation_label = remove_tool_dialog.get_node_or_null("VBoxContainer/ConfirmationLabel") as Label
	deps.remove_tool_status_label = remove_tool_dialog.get_node_or_null("VBoxContainer/StatusLabel") as Label
	deps.remove_tool_progress_bar = remove_tool_dialog.get_node_or_null("VBoxContainer/ProgressBar") as ProgressBar
	page_controller.setup(deps, null, null, null, null)
	
	# Initial open: status and progress must be hidden
	page_controller._on_remove_tool_pressed("godot", "4.3")
	_expect(deps.remove_tool_status_label.visible == false, "StatusLabel must be hidden when dialog initially opens", results)
	_expect(deps.remove_tool_progress_bar.visible == false, "ProgressBar must be hidden when dialog initially opens", results)
	_expect(deps.remove_tool_dialog.get_ok_button().disabled == false, "OK button should be enabled when dialog opens", results)
	
	# Simulate underway confirmation: status and progress become visible
	page_controller.removal_tool_id = "godot"
	page_controller.removal_tool_version = "4.3"
	deps.remove_tool_status_label.visible = true
	deps.remove_tool_status_label.text = "Removing Godot 4.3..."
	deps.remove_tool_progress_bar.visible = true
	_expect(deps.remove_tool_status_label.visible == true, "StatusLabel should be visible while removal is underway", results)
	_expect(deps.remove_tool_progress_bar.visible == true, "ProgressBar should be visible while removal is underway", results)
	
	# Simulate removal failure: status label shows failure, progress bar hidden
	page_controller._on_tool_removal_finished({"success": false, "error_message": "Disk write failed"})
	_expect(deps.remove_tool_status_label.visible == true, "StatusLabel should remain visible on removal failure", results)
	_expect(deps.remove_tool_status_label.text == "Removal failed: Disk write failed", "StatusLabel should show failure message", results)
	_expect(deps.remove_tool_progress_bar.visible == false, "ProgressBar should be hidden after removal fails", results)
	_expect(deps.remove_tool_dialog.get_ok_button().disabled == false, "OK button should be re-enabled on failure", results)
	
	instance.free()

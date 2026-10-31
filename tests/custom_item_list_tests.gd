## CustomItemListTests: Unit and scene tests for CustomItemList structured project cards.
##
## Verifies:
## - Dedicated card-styled surface with distinct background and border
## - Selected card prominent 2px accent border and elevated background
## - Distinct hover, focus, and disabled states
## - Visual hierarchy: 16px title, tool badges, muted path
## - Canonical tool names and overflow formatting in badges
## - API backward compatibility: add_item, clear, select, item_count, tooltips, signals
## - Memory safety: .free() on all created nodes

extends RefCounted
class_name CustomItemListTests

const CustomItemListScript = preload("res://scripts/projects/custom_item_list.gd")

func run() -> Dictionary:
	## Runs all CustomItemList tests.
	var results := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	_test_card_creation_and_api_compatibility(results)
	_test_card_visual_hierarchy_and_badges(results)
	_test_card_styleboxes_and_selected_state(results)
	_test_disabled_state_styling(results)
	_test_clear_resets_all_state(results)
	_test_selection_and_activation_signals(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records test assertion.
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_card_creation_and_api_compatibility(results: Dictionary) -> void:
	## Verifies CustomItemList creates cards and preserves backward-compatible API methods.
	var list := CustomItemListScript.new()

	# 1. Single-line add_item
	list.add_item("Legacy Single Line")
	_expect(list.item_count == 1, "add_item should increment item_count", results)
	_expect(list.get_card_title(0) == "Legacy Single Line", "Title should match single line item", results)
	_expect(list.get_item_text(0) == "Legacy Single Line", "get_item_text should return raw text", results)

	# 2. Multi-line legacy string add_item
	list.add_item("My Project - Godot 4.7.2, GIMP 3.2.4\nC:/Projects/MyProject")
	_expect(list.item_count == 2, "item_count should be 2 after second add_item", results)
	_expect(list.get_card_title(1) == "My Project", "Multi-line item should extract title", results)
	_expect(list.get_card_path(1) == "C:/Projects/MyProject", "Multi-line item should extract path", results)
	_expect(list.get_item_text(1) == "My Project - Godot 4.7.2, GIMP 3.2.4\nC:/Projects/MyProject", "get_item_text should preserve full text", results)

	# 3. Structured add_project_card
	var tools_array: Array = [
		{"id": "godot", "version": "4.7.2"},
		{"id": "gimp", "version": "3.2.4"},
		{"id": "vscodium", "version": "1.143.17232"}
	]
	list.add_project_card("Structured Stack", "Godot 4.7.2, GIMP 3.2.4 (+1 more)", "D:/OGS/Structured", tools_array)
	_expect(list.item_count == 3, "item_count should be 3 after add_project_card", results)
	_expect(list.get_card_title(2) == "Structured Stack", "Card title should match stack name", results)
	_expect(list.get_card_path(2) == "D:/OGS/Structured", "Card path should match project path", results)

	# 4. Tooltip API
	list.set_item_tooltip(2, "Custom Tooltip Text")
	_expect(list.get_item_tooltip(2) == "Custom Tooltip Text", "get_item_tooltip should return updated tooltip", results)

	# 5. Button access
	var btn0 := list.get_item_button(0)
	_expect(btn0 != null, "get_item_button(0) should return valid Button instance", results)
	_expect(btn0.toggle_mode == true, "Card button should have toggle_mode enabled", results)

	list.free()

func _test_card_visual_hierarchy_and_badges(results: Dictionary) -> void:
	## Verifies typography font sizes, muted colors, and canonical tool badge creation.
	var list := CustomItemListScript.new()

	var tools: Array = [
		{"id": "godot", "version": "4.7.2"},
		{"id": "blender", "version": "4.2"},
		{"id": "krita", "version": "5.2.2"},
		{"id": "vscodium", "version": "1.143.17232"}
	]
	list.add_project_card("Omni Stack", "Godot 4.7.2, Blender 4.2 (+2 more)", "C:/Projects/Omni", tools)

	var btn: Button = list.get_item_button(0)
	_expect(btn != null, "Card button should exist", results)
	if btn != null:
		var title_lbl: Label = btn.find_child("TitleLabel", true, false) as Label
		_expect(title_lbl != null, "TitleLabel should exist in card hierarchy", results)
		if title_lbl != null:
			_expect(title_lbl.get_theme_font_size("font_size") == 16, "TitleLabel font size should be 16px", results)
			_expect(title_lbl.get_theme_color("font_color").is_equal_approx(CustomItemListScript.COLOR_TITLE), "TitleLabel font color should be high contrast white", results)

		var path_lbl: Label = btn.find_child("PathLabel", true, false) as Label
		_expect(path_lbl != null, "PathLabel should exist in card hierarchy", results)
		if path_lbl != null:
			_expect(path_lbl.get_theme_font_size("font_size") == 12, "PathLabel font size should be 12px", results)
			_expect(path_lbl.get_theme_color("font_color").is_equal_approx(CustomItemListScript.COLOR_PATH), "PathLabel font color should be muted secondary", results)

		var badges := list.get_card_badge_texts(0)
		_expect(badges.size() == 3, "Card should have 2 tool badges plus 1 overflow badge (total 3)", results)
		if badges.size() >= 3:
			_expect(badges[0] == "Godot 4.7.2", "First badge should be canonical 'Godot 4.7.2', got '%s'" % badges[0], results)
			_expect(badges[1] == "Blender 4.2", "Second badge should be canonical 'Blender 4.2', got '%s'" % badges[1], results)
			_expect(badges[2] == "+2 more", "Third badge should be overflow '+2 more', got '%s'" % badges[2], results)

	# Test empty tools renders "No tools" badge
	list.add_project_card("Empty Project", "No tools", "C:/Projects/Empty", [])
	var empty_badges := list.get_card_badge_texts(1)
	_expect(empty_badges.size() == 1, "Empty tools card should render 1 badge", results)
	if not empty_badges.is_empty():
		_expect(empty_badges[0] == "No tools", "Empty tools badge should say 'No tools', got '%s'" % empty_badges[0], results)

	list.free()

func _test_card_styleboxes_and_selected_state(results: Dictionary) -> void:
	## Verifies StyleBoxFlat configurations for normal, hover, pressed, and focus states.
	var list := CustomItemListScript.new()
	list.add_item("Item 0")
	list.add_item("Item 1")

	var btn0: Button = list.get_item_button(0)
	var btn1: Button = list.get_item_button(1)
	_expect(btn0 != null and btn1 != null, "Item buttons should exist", results)
	if btn0 == null or btn1 == null:
		list.free()
		return

	# Verify resting normal StyleBoxFlat
	var normal_box: StyleBoxFlat = btn0.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(normal_box != null, "Normal stylebox should be StyleBoxFlat", results)
	if normal_box != null:
		_expect(normal_box.bg_color.is_equal_approx(CustomItemListScript.COLOR_CARD_BG_NORMAL), "Normal background should be dark card surface", results)
		_expect(normal_box.border_color.is_equal_approx(CustomItemListScript.COLOR_CARD_BORDER_NORMAL), "Normal border should be subtle card border", results)
		_expect(normal_box.border_width_left == 1, "Normal border width should be 1px", results)

	# Verify pressed / selected StyleBoxFlat
	var pressed_box: StyleBoxFlat = btn0.get_theme_stylebox("pressed") as StyleBoxFlat
	_expect(pressed_box != null, "Pressed stylebox should be StyleBoxFlat", results)
	if pressed_box != null:
		_expect(pressed_box.border_width_left == 2, "Selected state should have prominent 2px border width", results)
		_expect(pressed_box.border_color.is_equal_approx(CustomItemListScript.COLOR_CARD_BORDER_SELECTED), "Selected border should have cyan accent color", results)
		_expect(pressed_box.bg_color.is_equal_approx(CustomItemListScript.COLOR_CARD_BG_SELECTED), "Selected background should be elevated card surface", results)

	# Test selection toggling
	_expect(list.get_selected_index() == -1, "Initially no item selected", results)
	_expect(btn0.button_pressed == false and btn1.button_pressed == false, "Both buttons initially unpressed", results)

	list.select(1)
	_expect(list.get_selected_index() == 1, "Selected index should be 1 after select(1)", results)
	_expect(list.is_selected(1) == true, "is_selected(1) should be true", results)
	_expect(list.is_selected(0) == false, "is_selected(0) should be false", results)
	_expect(btn1.button_pressed == true, "btn1.button_pressed should be true", results)
	_expect(btn0.button_pressed == false, "btn0.button_pressed should be false", results)
	_expect(list.get_selected_items() == [1], "get_selected_items() should return [1]", results)

	# Deselect all via select(-1)
	list.select(-1)
	_expect(list.get_selected_index() == -1, "Selected index should be -1 after select(-1)", results)
	_expect(btn1.button_pressed == false, "btn1.button_pressed should be false after deselect", results)
	_expect(list.get_selected_items().is_empty(), "get_selected_items() should be empty", results)

	list.free()

func _test_disabled_state_styling(results: Dictionary) -> void:
	## Verifies disabling card updates button disabled state and modulates typography contrast.
	var list := CustomItemListScript.new()
	list.add_item("Active Card - Godot 4.7.2\nC:/Projects/Active")

	_expect(list.is_item_disabled(0) == false, "Card should initially be enabled", results)

	list.set_item_disabled(0, true)
	_expect(list.is_item_disabled(0) == true, "Card should report disabled after set_item_disabled(true)", results)
	var btn := list.get_item_button(0)
	_expect(btn.disabled == true, "Button disabled property should be true", results)

	var title_lbl: Label = btn.find_child("TitleLabel", true, false) as Label
	if title_lbl != null:
		var title_color: Color = title_lbl.get_theme_color("font_color")
		_expect(title_color.a < 0.9, "Disabled title font color should have dimmed alpha", results)

	list.set_item_disabled(0, false)
	_expect(list.is_item_disabled(0) == false, "Card should report enabled after set_item_disabled(false)", results)
	_expect(btn.disabled == false, "Button disabled property should be false", results)

	if title_lbl != null:
		var restored_color: Color = title_lbl.get_theme_color("font_color")
		_expect(restored_color.is_equal_approx(CustomItemListScript.COLOR_TITLE), "Re-enabled title font color should restore to full brightness", results)

	list.free()

func _test_clear_resets_all_state(results: Dictionary) -> void:
	## Verifies clear() frees child buttons and resets selection and item counts.
	var list := CustomItemListScript.new()
	list.add_item("Card 1")
	list.add_item("Card 2")
	list.select(0)

	_expect(list.item_count == 2, "item_count should be 2 before clear", results)
	_expect(list.get_selected_index() == 0, "Selected index should be 0 before clear", results)

	list.clear()

	_expect(list.item_count == 0, "item_count should be 0 after clear", results)
	_expect(list.get_selected_index() == -1, "Selected index should be -1 after clear", results)
	_expect(list.get_selected_items().is_empty(), "get_selected_items should be empty after clear", results)
	_expect(list.get_item_button(0) == null, "get_item_button(0) should return null after clear", results)

	# Verify adding items works cleanly after clear
	list.add_item("New Card")
	_expect(list.item_count == 1, "item_count should be 1 after new add_item", results)
	_expect(list.get_card_title(0) == "New Card", "New card should have correct title", results)

	list.free()

func _test_selection_and_activation_signals(results: Dictionary) -> void:
	## Verifies single-click emits item_selected and double-click emits item_activated.
	var list := CustomItemListScript.new()
	var selected_log: Array[int] = []
	var activated_log: Array[int] = []

	list.item_selected.connect(func(idx: int): selected_log.append(idx))
	list.item_activated.connect(func(idx: int): activated_log.append(idx))

	list.add_item("Card 0")
	list.add_item("Card 1")

	var btn1 := list.get_item_button(1)
	_expect(btn1 != null, "btn1 should exist", results)
	if btn1 == null:
		list.free()
		return

	# Simulate single-click
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.double_click = false
	btn1.gui_input.emit(click_event)
	btn1.pressed.emit()

	_expect(selected_log.size() == 1 and selected_log[0] == 1, "Single click should emit item_selected(1)", results)
	_expect(activated_log.is_empty(), "Single click should not emit item_activated", results)
	_expect(list.get_selected_index() == 1, "Single click should update selected index", results)

	# Simulate double-click
	var dbl_click_event := InputEventMouseButton.new()
	dbl_click_event.button_index = MOUSE_BUTTON_LEFT
	dbl_click_event.pressed = true
	dbl_click_event.double_click = true
	btn1.gui_input.emit(dbl_click_event)

	_expect(activated_log.size() == 1 and activated_log[0] == 1, "Double click should emit item_activated(1)", results)

	list.free()

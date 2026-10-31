## CustomItemList: Scrollable list of selectable structured project cards.
##
## Renders project entries as dedicated cards with distinct surfaces,
## tool badges, and visual hierarchy. Emits item_selected on single-click
## and item_activated on double-click, maintaining API alignment with
## Godot's built-in ItemList.

extends ScrollContainer
class_name CustomItemList

const ToolCategoryMapper = preload("res://scripts/tools/tool_category_mapper.gd")

## Emitted when an item button is single-clicked / selected.
signal item_selected(index: int)

## Emitted when an item button is double-clicked / activated.
signal item_activated(index: int)

# Card surface colors
const COLOR_CARD_BG_NORMAL := Color(0.14, 0.16, 0.20, 1.0)
const COLOR_CARD_BORDER_NORMAL := Color(0.22, 0.26, 0.32, 1.0)

const COLOR_CARD_BG_HOVER := Color(0.16, 0.19, 0.24, 1.0)
const COLOR_CARD_BORDER_HOVER := Color(0.35, 0.44, 0.55, 1.0)

const COLOR_CARD_BG_SELECTED := Color(0.18, 0.22, 0.28, 1.0)
const COLOR_CARD_BORDER_SELECTED := Color(0.35, 0.68, 0.95, 1.0)

const COLOR_CARD_BG_DISABLED := Color(0.12, 0.13, 0.16, 0.6)
const COLOR_CARD_BORDER_DISABLED := Color(0.18, 0.20, 0.24, 0.5)

# Text and badge colors
const COLOR_TITLE := Color(0.95, 0.96, 0.98, 1.0)
const COLOR_PATH := Color(0.65, 0.70, 0.75, 1.0)

const COLOR_BADGE_BG := Color(0.18, 0.22, 0.28, 0.8)
const COLOR_BADGE_BORDER := Color(0.28, 0.35, 0.46, 0.8)
const COLOR_BADGE_TEXT := Color(0.78, 0.84, 0.92, 1.0)

const COLOR_OVERFLOW_BG := Color(0.15, 0.18, 0.23, 0.7)
const COLOR_OVERFLOW_BORDER := Color(0.26, 0.32, 0.40, 0.7)
const COLOR_OVERFLOW_TEXT := Color(0.65, 0.70, 0.78, 1.0)

const COLOR_NO_TOOLS_BG := Color(0.14, 0.16, 0.20, 0.6)
const COLOR_NO_TOOLS_BORDER := Color(0.22, 0.25, 0.30, 0.6)
const COLOR_NO_TOOLS_TEXT := Color(0.55, 0.60, 0.68, 1.0)

var _vbox: VBoxContainer = null
var _items: Array[Button] = []
var _raw_texts: Array[String] = []
var item_count: int = 0
var _selected_index: int = -1
var _last_click_times: Dictionary = {}

func _init() -> void:
	## Initializes the custom item list.
	_ensure_vbox()

func _ready() -> void:
	## Prepares scroll container properties and inner layout.
	_ensure_vbox()

func _ensure_vbox() -> void:
	## Guarantees the inner VBoxContainer exists and is properly configured.
	if _vbox == null:
		horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_vbox = VBoxContainer.new()
		_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_vbox.add_theme_constant_override("separation", 8)
		add_child(_vbox)

func clear() -> void:
	## Cleanly frees all card nodes and resets selection and item counts.
	_ensure_vbox()
	for child in _vbox.get_children():
		_vbox.remove_child(child)
		child.queue_free()
	_items.clear()
	_raw_texts.clear()
	_last_click_times.clear()
	item_count = 0
	_selected_index = -1

func add_item(text: String) -> void:
	## Adds an item, parsing text into card visual hierarchy for backward compatibility.
	var title := text
	var summary := ""
	var path := ""

	if text.contains("\n"):
		var lines := text.split("\n", false, 2)
		var line0 := lines[0]
		if lines.size() > 1:
			path = lines[1].strip_edges()

		if line0.contains(" - "):
			var parts := line0.split(" - ", false, 2)
			title = parts[0].strip_edges()
			summary = parts[1].strip_edges()
		elif line0.contains(" " + char(0x2014) + " "):
			var parts := line0.split(" " + char(0x2014) + " ", false, 2)
			title = parts[0].strip_edges()
			summary = parts[1].strip_edges()
		else:
			title = line0.strip_edges()
	elif text.contains(" - "):
		var parts := text.split(" - ", false, 2)
		title = parts[0].strip_edges()
		summary = parts[1].strip_edges()
	elif text.contains(" " + char(0x2014) + " "):
		var parts := text.split(" " + char(0x2014) + " ", false, 2)
		title = parts[0].strip_edges()
		summary = parts[1].strip_edges()

	_create_card(title, summary, path, [], text)

func add_project_card(stack_name: String, tools_summary: String, project_path: String, tools: Array = []) -> void:
	## Adds a structured project card entry with dedicated tool badges.
	var raw_label := "%s - %s\n%s" % [stack_name, tools_summary, project_path]
	_create_card(stack_name, tools_summary, project_path, tools, raw_label)

func _create_card(title: String, summary: String, path: String, tools: Array, raw_text: String) -> Button:
	## Constructs and configures a card Button with visual hierarchy and tool badges.
	_ensure_vbox()
	var btn := Button.new()
	btn.text = ""
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(0, 68)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_ALL

	# Apply dedicated card styleboxes
	btn.add_theme_stylebox_override("normal", create_card_style_normal())
	btn.add_theme_stylebox_override("hover", create_card_style_hover())
	btn.add_theme_stylebox_override("pressed", create_card_style_selected())
	btn.add_theme_stylebox_override("hover_pressed", create_card_style_hover_pressed())
	btn.add_theme_stylebox_override("focus", create_card_style_focus())
	btn.add_theme_stylebox_override("disabled", create_card_style_disabled())

	# Card inner padding container
	var margin := MarginContainer.new()
	margin.name = "CardMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	btn.add_child(margin)

	var card_vbox := VBoxContainer.new()
	card_vbox.name = "CardVBox"
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(card_vbox)

	# Row 1: Title and Tool Badges
	var header_row := HBoxContainer.new()
	header_row.name = "HeaderRow"
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_theme_constant_override("separation", 8)
	card_vbox.add_child(header_row)

	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = title
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", COLOR_TITLE)
	header_row.add_child(title_lbl)

	var badges_container := HBoxContainer.new()
	badges_container.name = "BadgesContainer"
	badges_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badges_container.size_flags_horizontal = Control.SIZE_SHRINK_END
	badges_container.alignment = BoxContainer.ALIGNMENT_END
	badges_container.add_theme_constant_override("separation", 6)
	header_row.add_child(badges_container)

	_populate_badges(badges_container, tools, summary)

	# Row 2: Project Path
	if not path.is_empty():
		var path_lbl := Label.new()
		path_lbl.name = "PathLabel"
		path_lbl.text = path
		path_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		path_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		path_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		path_lbl.add_theme_font_size_override("font_size", 12)
		path_lbl.add_theme_color_override("font_color", COLOR_PATH)
		card_vbox.add_child(path_lbl)

	var idx := _items.size()
	btn.pressed.connect(func(): _on_button_pressed(idx))
	btn.gui_input.connect(func(event: InputEvent): _on_button_gui_input(event, idx))

	_vbox.add_child(btn)
	_items.append(btn)
	_raw_texts.append(raw_text)
	item_count += 1
	return btn

func _populate_badges(container: HBoxContainer, tools: Array, summary: String) -> void:
	## Populates badges container with canonical tool badges, overflow pill, or no-tools pill.
	if not tools.is_empty():
		var shown_count := 0
		for tool in tools:
			if shown_count >= 2:
				break
			var tool_id: String = String(tool.get("id", "")).strip_edges()
			var tool_ver: String = String(tool.get("version", "")).strip_edges()
			var disp_name: String = ToolCategoryMapper.get_display_name(tool_id)
			var badge_text: String = disp_name
			if not tool_ver.is_empty() and tool_ver != "?":
				badge_text = "%s %s" % [disp_name, tool_ver]
			var badge := _create_badge_label(badge_text, COLOR_BADGE_BG, COLOR_BADGE_BORDER, COLOR_BADGE_TEXT)
			container.add_child(badge)
			shown_count += 1

		if tools.size() > 2:
			var overflow_count: int = tools.size() - 2
			var overflow_badge := _create_badge_label("+%d more" % overflow_count, COLOR_OVERFLOW_BG, COLOR_OVERFLOW_BORDER, COLOR_OVERFLOW_TEXT)
			container.add_child(overflow_badge)
	elif not summary.is_empty() and summary != "No tools":
		var tokens := summary.split(", ")
		for token in tokens:
			var stripped := token.strip_edges()
			if stripped.is_empty():
				continue
			if stripped.begins_with("(+") and stripped.ends_with(")"):
				var overflow_text := stripped.substr(1, stripped.length() - 2)
				var overflow_badge := _create_badge_label(overflow_text, COLOR_OVERFLOW_BG, COLOR_OVERFLOW_BORDER, COLOR_OVERFLOW_TEXT)
				container.add_child(overflow_badge)
			else:
				var badge := _create_badge_label(stripped, COLOR_BADGE_BG, COLOR_BADGE_BORDER, COLOR_BADGE_TEXT)
				container.add_child(badge)
	elif summary == "No tools":
		var no_tools_badge := _create_badge_label("No tools", COLOR_NO_TOOLS_BG, COLOR_NO_TOOLS_BORDER, COLOR_NO_TOOLS_TEXT)
		container.add_child(no_tools_badge)

func _create_badge_label(badge_text: String, bg_color: Color, border_color: Color, font_color: Color) -> Label:
	## Creates a rounded pill badge Label.
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0

	var lbl := Label.new()
	lbl.name = "Badge_" + badge_text.replace(" ", "_").replace("+", "plus")
	lbl.text = badge_text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", font_color)
	lbl.add_theme_stylebox_override("normal", style)
	return lbl

func set_item_tooltip(idx: int, tooltip: String) -> void:
	## Sets tooltip on the card button at index.
	if idx >= 0 and idx < _items.size():
		_items[idx].tooltip_text = tooltip

func get_item_tooltip(idx: int) -> String:
	## Returns tooltip of the card button at index.
	if idx >= 0 and idx < _items.size():
		return _items[idx].tooltip_text
	return ""

func set_item_disabled(idx: int, disabled: bool) -> void:
	## Sets disabled state on the card button at index and updates text colors.
	if idx >= 0 and idx < _items.size():
		var btn := _items[idx]
		btn.disabled = disabled
		var title_lbl: Label = btn.find_child("TitleLabel", true, false) as Label
		var path_lbl: Label = btn.find_child("PathLabel", true, false) as Label
		if disabled:
			if title_lbl != null:
				title_lbl.add_theme_color_override("font_color", Color(COLOR_TITLE.r, COLOR_TITLE.g, COLOR_TITLE.b, 0.5))
			if path_lbl != null:
				path_lbl.add_theme_color_override("font_color", Color(COLOR_PATH.r, COLOR_PATH.g, COLOR_PATH.b, 0.4))
		else:
			if title_lbl != null:
				title_lbl.add_theme_color_override("font_color", COLOR_TITLE)
			if path_lbl != null:
				path_lbl.add_theme_color_override("font_color", COLOR_PATH)

func is_item_disabled(idx: int) -> bool:
	## Returns whether the card button at index is disabled.
	if idx >= 0 and idx < _items.size():
		return _items[idx].disabled
	return false

func select(idx: int, _single: bool = true) -> void:
	## Visually highlights the selected card and unselects others.
	if idx < 0 or idx >= _items.size():
		deselect_all()
		return
	_selected_index = idx
	for i in range(_items.size()):
		_items[i].button_pressed = (i == idx)

func deselect(idx: int) -> void:
	## Deselects card at index.
	if idx >= 0 and idx < _items.size():
		_items[idx].button_pressed = false
		if _selected_index == idx:
			_selected_index = -1

func deselect_all() -> void:
	## Deselects all cards.
	_selected_index = -1
	for btn in _items:
		btn.button_pressed = false

func is_selected(idx: int) -> bool:
	## Returns whether card at index is currently selected.
	return _selected_index == idx

func get_item_count() -> int:
	## Returns total number of project cards in the list.
	return item_count

func get_selected_index() -> int:
	## Returns index of selected card, or -1 if none selected.
	return _selected_index

func get_selected_items() -> Array[int]:
	## Returns array with index of selected card for API compatibility.
	if _selected_index >= 0 and _selected_index < _items.size():
		return [_selected_index]
	return []

func get_item_button(idx: int) -> Button:
	## Returns card button at index.
	if idx >= 0 and idx < _items.size():
		return _items[idx]
	return null

func get_item_text(idx: int) -> String:
	## Returns raw text representation of item for backward compatibility.
	if idx >= 0 and idx < _raw_texts.size():
		return _raw_texts[idx]
	return ""

func get_card_title(idx: int) -> String:
	## Returns project title text of card at index.
	var btn := get_item_button(idx)
	if btn != null:
		var title_lbl: Label = btn.find_child("TitleLabel", true, false) as Label
		if title_lbl != null:
			return title_lbl.text
	return ""

func get_card_path(idx: int) -> String:
	## Returns project path text of card at index.
	var btn := get_item_button(idx)
	if btn != null:
		var path_lbl: Label = btn.find_child("PathLabel", true, false) as Label
		if path_lbl != null:
			return path_lbl.text
	return ""

func get_card_badges_container(idx: int) -> HBoxContainer:
	## Returns badges container node of card at index.
	var btn := get_item_button(idx)
	if btn != null:
		return btn.find_child("BadgesContainer", true, false) as HBoxContainer
	return null

func get_card_badge_texts(idx: int) -> Array[String]:
	## Returns list of badge label texts of card at index.
	var container := get_card_badges_container(idx)
	var texts: Array[String] = []
	if container != null:
		for child in container.get_children():
			if child is Label:
				texts.append((child as Label).text)
	return texts

func _on_button_pressed(idx: int) -> void:
	## Handles single-click card selection and emits item_selected.
	select(idx)
	item_selected.emit(idx)

func _on_button_gui_input(event: InputEvent, idx: int) -> void:
	## Handles mouse clicks and double-clicks to emit item_activated.
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var now := Time.get_ticks_msec()
			var prev_time: int = _last_click_times.get(idx, 0)
			if mb.double_click or (prev_time > 0 and (now - prev_time) < 400):
				_last_click_times[idx] = 0
				select(idx)
				item_activated.emit(idx)
			else:
				_last_click_times[idx] = now

# StyleBox Flat Factory Methods

static func create_card_style_normal() -> StyleBoxFlat:
	## Returns StyleBoxFlat for normal resting card surface.
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CARD_BG_NORMAL
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = COLOR_CARD_BORDER_NORMAL
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

static func create_card_style_hover() -> StyleBoxFlat:
	## Returns StyleBoxFlat for hovered card surface with subtle highlight.
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CARD_BG_HOVER
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = COLOR_CARD_BORDER_HOVER
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

static func create_card_style_selected() -> StyleBoxFlat:
	## Returns StyleBoxFlat for active/selected card with prominent 2px accent border.
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CARD_BG_SELECTED
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_CARD_BORDER_SELECTED
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

static func create_card_style_hover_pressed() -> StyleBoxFlat:
	## Returns StyleBoxFlat for hovered selected card surface.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.19, 0.23, 0.30, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.45, 0.75, 1.0, 1.0)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

static func create_card_style_focus() -> StyleBoxFlat:
	## Returns StyleBoxFlat for focused card outline.
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(COLOR_CARD_BORDER_SELECTED.r, COLOR_CARD_BORDER_SELECTED.g, COLOR_CARD_BORDER_SELECTED.b, 0.7)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

static func create_card_style_disabled() -> StyleBoxFlat:
	## Returns StyleBoxFlat for disabled card surface.
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CARD_BG_DISABLED
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = COLOR_CARD_BORDER_DISABLED
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

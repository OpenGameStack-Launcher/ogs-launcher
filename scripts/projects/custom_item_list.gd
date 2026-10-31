## CustomItemList: Scrollable list of selectable item buttons.
##
## Emits item_selected on single-click and item_activated on double-click,
## maintaining API alignment with Godot's built-in ItemList.

extends ScrollContainer
class_name CustomItemList

## Emitted when an item button is single-clicked / selected.
signal item_selected(index: int)

## Emitted when an item button is double-clicked / activated.
signal item_activated(index: int)

var _vbox: VBoxContainer
var _items: Array[Button] = []
var item_count: int = 0
var _selected_index: int = -1
var _last_click_times: Dictionary = {}

func _init() -> void:
	_ensure_vbox()

func _ready() -> void:
	_ensure_vbox()

func _ensure_vbox() -> void:
	if _vbox == null:
		_vbox = VBoxContainer.new()
		_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_vbox.add_theme_constant_override("separation", 8)
		add_child(_vbox)

func clear() -> void:
	_ensure_vbox()
	for child in _vbox.get_children():
		child.queue_free()
	_items.clear()
	_last_click_times.clear()
	item_count = 0
	_selected_index = -1

func add_item(text: String) -> void:
	_ensure_vbox()
	var btn := Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.toggle_mode = true
	var idx := _items.size()
	btn.pressed.connect(func(): _on_button_pressed(idx))
	btn.gui_input.connect(func(event: InputEvent): _on_button_gui_input(event, idx))
	_vbox.add_child(btn)
	_items.append(btn)
	item_count += 1

func set_item_tooltip(idx: int, tooltip: String) -> void:
	if idx >= 0 and idx < _items.size():
		_items[idx].tooltip_text = tooltip

func set_item_disabled(idx: int, disabled: bool) -> void:
	if idx >= 0 and idx < _items.size():
		_items[idx].disabled = disabled

func select(idx: int, _single: bool = true) -> void:
	_selected_index = idx
	for i in range(_items.size()):
		_items[i].button_pressed = (i == idx)

func get_selected_index() -> int:
	return _selected_index

func get_selected_items() -> Array[int]:
	if _selected_index >= 0 and _selected_index < _items.size():
		return [_selected_index]
	return []

func get_item_button(idx: int) -> Button:
	if idx >= 0 and idx < _items.size():
		return _items[idx]
	return null

func _on_button_pressed(idx: int) -> void:
	select(idx)
	item_selected.emit(idx)

func _on_button_gui_input(event: InputEvent, idx: int) -> void:
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

extends ScrollContainer
class_name CustomItemList

signal item_selected(index: int)
signal empty_clicked()

var _vbox: VBoxContainer
var _items: Array[Button] = []
var item_count: int = 0
var _selected_index: int = -1

func _ready() -> void:
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 8)
	add_child(_vbox)

func clear() -> void:
	for child in _vbox.get_children():
		child.queue_free()
	_items.clear()
	item_count = 0
	_selected_index = -1

func add_item(text: String) -> void:
	var btn = Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.toggle_mode = true
	var idx = _items.size()
	btn.pressed.connect(func(): _on_button_pressed(idx))
	_vbox.add_child(btn)
	_items.append(btn)
	item_count += 1

func set_item_tooltip(idx: int, tooltip: String) -> void:
	if idx >= 0 and idx < _items.size():
		_items[idx].tooltip_text = tooltip

func set_item_disabled(idx: int, disabled: bool) -> void:
	if idx >= 0 and idx < _items.size():
		_items[idx].disabled = disabled

func select(idx: int, single: bool = true) -> void:
	_selected_index = idx
	for i in range(_items.size()):
		_items[i].button_pressed = (i == idx)

func _on_button_pressed(idx: int) -> void:
	select(idx)
	item_selected.emit(idx)

## DownloadDialogController: Manages the active download UI popup.
extends RefCounted
class_name DownloadDialogController

const ToolCategoryMapper = preload("res://scripts/tools/tool_category_mapper.gd")

var dialog: ConfirmationDialog
var progress_bar: ProgressBar
var label: Label
var margin_container: MarginContainer
var _active_tool_id: String = ""
var _active_version: String = ""
var _tools_controller: ToolsController

## Initializes the download dialog, layout containers, and styled progress bar.
func setup(app_node: Node, tools_controller: ToolsController) -> void:
	_tools_controller = tools_controller
	dialog = ConfirmationDialog.new()
	dialog.exclusive = true
	dialog.unresizable = true
	dialog.min_size = Vector2(400, 120)
	dialog.get_ok_button().hide()
	dialog.get_cancel_button().text = "Cancel"
	dialog.canceled.connect(_on_canceled)
	
	margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_top", 12)
	margin_container.add_theme_constant_override("margin_bottom", 12)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	
	label = Label.new()
	label.text = "Initializing..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(360, 18)
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color("#1A1D24")
	bg_style.border_color = Color("#2A2F3A")
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(6)
	progress_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color("#3B82F6")
	fill_style.set_corner_radius_all(6)
	progress_bar.add_theme_stylebox_override("fill", fill_style)
	
	vbox.add_child(progress_bar)
	margin_container.add_child(vbox)
	dialog.add_child(margin_container)
	app_node.add_child(dialog)

## Displays the download dialog for a specific tool and version, wiring progress tracking.
func show_dialog(tool_id: String, version: String, progress_controller: ProgressController) -> void:
	_active_tool_id = tool_id
	_active_version = version
	dialog.title = "Downloading %s %s" % [ToolCategoryMapper.get_display_name(tool_id), version]
	dialog.get_cancel_button().text = "Cancel"
	dialog.get_cancel_button().disabled = false
	if progress_controller != null:
		progress_controller.track_inline_progress(tool_id, version, progress_bar, label, null)
		progress_bar.visible = true
		label.visible = true
	dialog.popup_centered()

## Hides the download dialog.
func hide_dialog() -> void:
	dialog.hide()

## Handles cancel button pressed, invoking cancellation in ToolsController.
func _on_canceled() -> void:
	if not _active_tool_id.is_empty() and _tools_controller != null:
		dialog.get_cancel_button().text = "Cancelling..."
		dialog.get_cancel_button().disabled = true
		_tools_controller.cancel_download(_active_tool_id, _active_version)


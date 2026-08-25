## DownloadDialogController: Manages the active download UI popup.
extends RefCounted
class_name DownloadDialogController

var dialog: ConfirmationDialog
var progress_bar: ProgressBar
var label: Label
var _active_tool_id: String = ""
var _active_version: String = ""
var _tools_controller: ToolsController

func setup(app_node: Node, tools_controller: ToolsController) -> void:
	_tools_controller = tools_controller
	dialog = ConfirmationDialog.new()
	dialog.exclusive = true
	dialog.unresizable = true
	dialog.min_size = Vector2(400, 120)
	dialog.get_ok_button().hide()
	dialog.get_cancel_button().text = "Cancel"
	dialog.canceled.connect(_on_canceled)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	label = Label.new()
	label.text = "Initializing..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size.y = 24
	vbox.add_child(progress_bar)
	
	dialog.add_child(vbox)
	app_node.add_child(dialog)

func show_dialog(tool_id: String, version: String, progress_controller: ProgressController) -> void:
	_active_tool_id = tool_id
	_active_version = version
	dialog.title = "Downloading %s %s" % [tool_id.capitalize(), version]
	dialog.get_cancel_button().text = "Cancel"
	dialog.get_cancel_button().disabled = false
	if progress_controller != null:
		progress_controller.track_inline_progress(tool_id, version, progress_bar, label, null)
	dialog.popup_centered()

func hide_dialog() -> void:
	dialog.hide()

func _on_canceled() -> void:
	if not _active_tool_id.is_empty() and _tools_controller != null:
		dialog.get_cancel_button().text = "Cancelling..."
		dialog.get_cancel_button().disabled = true
		_tools_controller.cancel_download(_active_tool_id, _active_version)

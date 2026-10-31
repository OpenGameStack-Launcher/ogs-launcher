## LayoutController: Manages app pages and navigation.
##
## Handles tab navigation, page visibility, and sidebar controls.
## Provides a clean separation between layout logic and business logic.
## Applies active page highlight styling with accent border to the active navigation button.
##
## Usage:
## var layout = LayoutController.new()
## layout.setup(
##     btn_projects, btn_tools, btn_settings,
##     page_projects, page_tools, page_settings,
##     status_label, version_label
## )

extends RefCounted
class_name LayoutController

## Emitted when user navigates to a page.
signal page_changed(page_name: String)

var _sidebar_buttons: Dictionary = {}
var _pages: Dictionary = {}
var _current_page: String = ""
var _status_label: Label = null
var _version_label: Label = null

var _active_style: StyleBoxFlat = null
var _normal_style: StyleBoxFlat = null
var _active_hover_style: StyleBoxFlat = null
var _normal_hover_style: StyleBoxFlat = null

## Initializes the default active and normal button styleboxes for sidebar navigation.
func _init_styles() -> void:
	# Active button style: elevated background with 3px primary blue left border
	_active_style = StyleBoxFlat.new()
	_active_style.bg_color = Color(0.18, 0.22, 0.28, 1.0)
	_active_style.border_width_left = 3
	_active_style.border_width_top = 0
	_active_style.border_width_right = 0
	_active_style.border_width_bottom = 0
	_active_style.border_color = Color(0.35, 0.68, 0.95, 1.0)
	_active_style.corner_radius_top_left = 0
	_active_style.corner_radius_bottom_left = 0
	_active_style.corner_radius_top_right = 4
	_active_style.corner_radius_bottom_right = 4
	_active_style.content_margin_left = 12.0
	_active_style.content_margin_right = 12.0
	_active_style.content_margin_top = 8.0
	_active_style.content_margin_bottom = 8.0

	_active_hover_style = _active_style.duplicate() as StyleBoxFlat
	_active_hover_style.bg_color = Color(0.22, 0.27, 0.34, 1.0)

	# Normal (inactive) button style: flat dark background without accent border
	_normal_style = StyleBoxFlat.new()
	_normal_style.bg_color = Color(0.12, 0.14, 0.18, 1.0)
	_normal_style.border_width_left = 0
	_normal_style.border_width_top = 0
	_normal_style.border_width_right = 0
	_normal_style.border_width_bottom = 0
	_normal_style.corner_radius_top_left = 4
	_normal_style.corner_radius_bottom_left = 4
	_normal_style.corner_radius_top_right = 4
	_normal_style.corner_radius_bottom_right = 4
	_normal_style.content_margin_left = 12.0
	_normal_style.content_margin_right = 12.0
	_normal_style.content_margin_top = 8.0
	_normal_style.content_margin_bottom = 8.0

	_normal_hover_style = _normal_style.duplicate() as StyleBoxFlat
	_normal_hover_style.bg_color = Color(0.16, 0.19, 0.24, 1.0)

## Sets up the layout controller with sidebar buttons, content pages, and optional footer labels.
## Parameters:
## btn_projects, btn_tools, btn_settings: Sidebar navigation buttons
## page_projects, page_tools, page_settings: Content pages
## status_label: Optional Label for global connectivity status display
## version_label: Optional Label for launcher version display
func setup(
	btn_projects: Button,
	btn_tools: Button,
	btn_settings: Button,
	page_projects: Control,
	page_tools: Control,
	page_settings: Control,
	status_label: Label = null,
	version_label: Label = null
) -> void:
	_init_styles()

	_sidebar_buttons = {
		"projects": btn_projects,
		"tools": btn_tools,
		"settings": btn_settings
	}
	
	_pages = {
		"projects": page_projects,
		"tools": page_tools,
		"settings": page_settings
	}

	_status_label = status_label
	_version_label = version_label
	
	# Connect button signals
	btn_projects.pressed.connect(_on_page_button_pressed.bind("projects"))
	btn_tools.pressed.connect(_on_page_button_pressed.bind("tools"))
	btn_settings.pressed.connect(_on_page_button_pressed.bind("settings"))
	
	# Start on projects page
	navigate_to("projects")

## Navigates to a specific page by name and updates sidebar button highlight styles.
## Parameters:
## page_name (String): One of "projects", "tools", "settings"
func navigate_to(page_name: String) -> void:
	if not _pages.has(page_name):
		return
	
	# Hide all pages
	for page: Control in _pages.values():
		if is_instance_valid(page):
			page.visible = false
	
	# Show requested page
	var active_page: Control = _pages[page_name] as Control
	if is_instance_valid(active_page):
		active_page.visible = true
	_current_page = page_name

	# Update active and normal styling across navigation buttons
	_update_button_styles()
	
	page_changed.emit(page_name)

## Updates button stylebox overrides to highlight the currently active page.
func _update_button_styles() -> void:
	for key: String in _sidebar_buttons:
		var btn: Button = _sidebar_buttons[key] as Button
		if not is_instance_valid(btn):
			continue
		if key == _current_page:
			if _active_style != null:
				btn.add_theme_stylebox_override("normal", _active_style)
				btn.add_theme_stylebox_override("pressed", _active_style)
			if _active_hover_style != null:
				btn.add_theme_stylebox_override("hover", _active_hover_style)
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
			btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
		else:
			if _normal_style != null:
				btn.add_theme_stylebox_override("normal", _normal_style)
				btn.add_theme_stylebox_override("pressed", _normal_style)
			else:
				btn.remove_theme_stylebox_override("normal")
				btn.remove_theme_stylebox_override("pressed")
			if _normal_hover_style != null:
				btn.add_theme_stylebox_override("hover", _normal_hover_style)
			else:
				btn.remove_theme_stylebox_override("hover")
			btn.add_theme_color_override("font_color", Color(0.70, 0.75, 0.82, 1.0))
			btn.add_theme_color_override("font_hover_color", Color(0.92, 0.94, 0.98, 1.0))
			btn.add_theme_color_override("font_pressed_color", Color(0.70, 0.75, 0.82, 1.0))

## Updates the sidebar status indicator to reflect global offline or online connectivity state.
## Parameters:
## is_online (bool): Whether online repository connection is available
func update_connectivity_status(is_online: bool) -> void:
	if _status_label == null or not is_instance_valid(_status_label):
		return
	if OfflineEnforcer.is_offline():
		_status_label.text = "● Offline"
		_status_label.modulate = Color(1.0, 0.6, 0.2, 1.0)
		_status_label.tooltip_text = "Offline Mode (enforced: %s)" % OfflineEnforcer.get_reason()
	elif is_online:
		_status_label.text = "● Online"
		_status_label.modulate = Color(0.3, 0.85, 0.45, 1.0)
		_status_label.tooltip_text = "Online: Connected to repository"
	else:
		_status_label.text = "● Offline"
		_status_label.modulate = Color(1.0, 0.6, 0.2, 1.0)
		_status_label.tooltip_text = "Offline: Cannot reach repository"

## Updates the launcher version label in the sidebar footer.
## Parameters:
## version_str (String): Formatted version string (e.g. "v0.1.0")
func update_version(version_str: String) -> void:
	if _version_label == null or not is_instance_valid(_version_label):
		return
	_version_label.text = version_str
	_version_label.tooltip_text = "OGS Launcher %s" % version_str

## Returns the active button stylebox.
func get_active_style() -> StyleBoxFlat:
	return _active_style

## Sets a custom active button stylebox.
func set_active_style(style: StyleBoxFlat) -> void:
	_active_style = style
	_update_button_styles()

## Returns the normal (inactive) button stylebox.
func get_normal_style() -> StyleBoxFlat:
	return _normal_style

## Sets a custom normal (inactive) button stylebox.
func set_normal_style(style: StyleBoxFlat) -> void:
	_normal_style = style
	_update_button_styles()

## Returns the navigation Button associated with the specified page name, or null.
func get_button(page_name: String) -> Button:
	return _sidebar_buttons.get(page_name, null) as Button

## Returns the configured connectivity status label, or null.
func get_status_label() -> Label:
	return _status_label

## Returns the configured version label, or null.
func get_version_label() -> Label:
	return _version_label

## Returns the name of the currently visible page.
func get_current_page() -> String:
	return _current_page

## Internal handler for page button presses.
func _on_page_button_pressed(page_name: String) -> void:
	navigate_to(page_name)

## Disconnects signals and clears references to prevent memory leaks.
func cleanup() -> void:
	for key: String in _sidebar_buttons:
		var btn: Button = _sidebar_buttons[key] as Button
		if is_instance_valid(btn):
			for conn: Dictionary in btn.pressed.get_connections():
				if conn["callable"].get_object() == self:
					btn.pressed.disconnect(conn["callable"])
			btn.remove_theme_stylebox_override("normal")
			btn.remove_theme_stylebox_override("hover")
			btn.remove_theme_stylebox_override("pressed")
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_color_override("font_hover_color")
			btn.remove_theme_color_override("font_pressed_color")
	_sidebar_buttons.clear()
	_pages.clear()
	_status_label = null
	_version_label = null

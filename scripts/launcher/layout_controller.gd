## LayoutController: Manages app pages and navigation.
##
## Handles tab navigation, page visibility, and sidebar controls.
## Provides a clean separation between layout logic and business logic.
##
## Usage:
## var layout = LayoutController.new()
## layout.setup(
## btn_projects, btn_tools, btn_settings,
## page_projects, page_tools, page_settings
## )

extends RefCounted
class_name LayoutController

## Emitted when user navigates to a page.
signal page_changed(page_name: String)

var _sidebar_buttons: Dictionary = {}
var _pages: Dictionary = {}
var _current_page: String = ""

## Sets up the layout controller with sidebar buttons and content pages.
## Parameters:
## btn_projects, btn_tools, btn_settings: Sidebar buttons
## page_projects, page_tools, page_settings: Content pages
func setup(
	btn_projects: Button,
	btn_tools: Button,
	btn_settings: Button,
	page_projects: Control,
	page_tools: Control,
	page_settings: Control
) -> void:
	## Configures the layout with buttons and pages.
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
	
	# Connect button signals
	btn_projects.pressed.connect(_on_page_button_pressed.bind("projects"))
	btn_tools.pressed.connect(_on_page_button_pressed.bind("tools"))
	btn_settings.pressed.connect(_on_page_button_pressed.bind("settings"))
	
	# Start on projects page
	navigate_to("projects")

## Navigates to a specific page by name.
## Parameters:
## page_name (String): One of "projects", "tools", "settings"
func navigate_to(page_name: String) -> void:
	## Shows the specified page and hides others.
	if not _pages.has(page_name):
		return
	
	# Hide all pages
	for page in _pages.values():
		page.visible = false
	
	# Show requested page
	_pages[page_name].visible = true
	_current_page = page_name
	
	page_changed.emit(page_name)

## Returns the name of the currently visible page.
func get_current_page() -> String:
	## Returns the current page name.
	return _current_page

## Internal handler for page button presses.
func _on_page_button_pressed(page_name: String) -> void:
	## Called when a sidebar button is pressed.
	navigate_to(page_name)

## Disconnects signals and clears references to prevent memory leaks.
func cleanup() -> void:
	for key in _sidebar_buttons:
		var btn = _sidebar_buttons[key]
		if is_instance_valid(btn):
			for conn in btn.pressed.get_connections():
				if conn["callable"].get_object() == self:
					btn.pressed.disconnect(conn["callable"])
	_sidebar_buttons.clear()
	_pages.clear()

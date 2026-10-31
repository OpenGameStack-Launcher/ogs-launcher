## LayoutControllerTests: Unit tests for LayoutController
##
## Verifies active button highlight styling, navigation switching,
## sidebar connectivity status updates, version display, and cleanup.

extends RefCounted
class_name LayoutControllerTests

const OgsConfigScript = preload("res://scripts/config/ogs_config.gd")

func run() -> Dictionary:
	var results := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	_test_setup_initializes_active_projects(results)
	_test_navigate_to_switches_active_highlight(results)
	_test_active_style_properties(results)
	_test_connectivity_status_indicator(results)
	_test_version_label_update(results)
	_test_cleanup_frees_overrides(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _create_test_environment() -> Dictionary:
	var btn_projects := Button.new()
	var btn_tools := Button.new()
	var btn_settings := Button.new()
	var page_projects := Control.new()
	var page_tools := Control.new()
	var page_settings := Control.new()
	var status_label := Label.new()
	var version_label := Label.new()

	var controller := LayoutController.new()
	controller.setup(
		btn_projects, btn_tools, btn_settings,
		page_projects, page_tools, page_settings,
		status_label, version_label
	)

	return {
		"controller": controller,
		"btn_projects": btn_projects,
		"btn_tools": btn_tools,
		"btn_settings": btn_settings,
		"page_projects": page_projects,
		"page_tools": page_tools,
		"page_settings": page_settings,
		"status_label": status_label,
		"version_label": version_label
	}

func _free_test_environment(env: Dictionary) -> void:
	var controller: LayoutController = env["controller"] as LayoutController
	if controller != null:
		controller.cleanup()
	for key: String in ["btn_projects", "btn_tools", "btn_settings", "page_projects", "page_tools", "page_settings", "status_label", "version_label"]:
		var node: Node = env[key] as Node
		if is_instance_valid(node):
			node.free()

func _test_setup_initializes_active_projects(results: Dictionary) -> void:
	var env := _create_test_environment()
	var controller: LayoutController = env["controller"] as LayoutController
	var btn_projects: Button = env["btn_projects"] as Button
	var btn_tools: Button = env["btn_tools"] as Button
	var page_projects: Control = env["page_projects"] as Control
	var page_tools: Control = env["page_tools"] as Control

	_expect(controller.get_current_page() == "projects", "Setup should default to projects page", results)
	_expect(page_projects.visible == true, "Projects page should be visible by default", results)
	_expect(page_tools.visible == false, "Tools page should be hidden by default", results)

	var active_style: StyleBoxFlat = btn_projects.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(active_style != null, "Projects button should have a normal stylebox", results)
	if active_style != null:
		_expect(active_style.border_width_left == 3, "Active projects button should have 3px left border", results)
		_expect(active_style.border_color.is_equal_approx(Color(0.35, 0.68, 0.95, 1.0)), "Active border color should be primary blue", results)

	var inactive_style: StyleBoxFlat = btn_tools.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(inactive_style != null, "Tools button should have a normal stylebox", results)
	if inactive_style != null:
		_expect(inactive_style.border_width_left == 0, "Inactive tools button should have 0px left border", results)

	_free_test_environment(env)

func _test_navigate_to_switches_active_highlight(results: Dictionary) -> void:
	var env := _create_test_environment()
	var controller: LayoutController = env["controller"] as LayoutController
	var btn_projects: Button = env["btn_projects"] as Button
	var btn_tools: Button = env["btn_tools"] as Button
	var btn_settings: Button = env["btn_settings"] as Button
	var page_projects: Control = env["page_projects"] as Control
	var page_tools: Control = env["page_tools"] as Control
	var page_settings: Control = env["page_settings"] as Control

	# Navigate to Tools
	controller.navigate_to("tools")
	_expect(controller.get_current_page() == "tools", "Current page should be tools after navigate_to", results)
	_expect(page_tools.visible == true, "Tools page should be visible", results)
	_expect(page_projects.visible == false, "Projects page should be hidden", results)

	var tools_style: StyleBoxFlat = btn_tools.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(tools_style != null and tools_style.border_width_left == 3, "Tools button should have 3px left border when active", results)

	var projects_style: StyleBoxFlat = btn_projects.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(projects_style != null and projects_style.border_width_left == 0, "Projects button should have 0px left border when inactive", results)

	# Navigate to Settings
	controller.navigate_to("settings")
	_expect(controller.get_current_page() == "settings", "Current page should be settings", results)
	_expect(page_settings.visible == true, "Settings page should be visible", results)
	_expect(page_tools.visible == false, "Tools page should be hidden", results)

	var settings_style: StyleBoxFlat = btn_settings.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(settings_style != null and settings_style.border_width_left == 3, "Settings button should have 3px left border when active", results)

	var tools_restored_style: StyleBoxFlat = btn_tools.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(tools_restored_style != null and tools_restored_style.border_width_left == 0, "Tools button should restore 0px left border", results)

	_free_test_environment(env)

func _test_active_style_properties(results: Dictionary) -> void:
	var env := _create_test_environment()
	var controller: LayoutController = env["controller"] as LayoutController

	var active_style: StyleBoxFlat = controller.get_active_style()
	_expect(active_style != null, "LayoutController should provide get_active_style()", results)
	if active_style != null:
		_expect(active_style.border_width_left == 3, "Active style should have 3px left border", results)
		_expect(active_style.border_color.is_equal_approx(Color(0.35, 0.68, 0.95, 1.0)), "Active border color should match primary blue", results)
		_expect(active_style.bg_color.is_equal_approx(Color(0.18, 0.22, 0.28, 1.0)), "Active bg color should be elevated dark", results)

	var normal_style: StyleBoxFlat = controller.get_normal_style()
	_expect(normal_style != null, "LayoutController should provide get_normal_style()", results)
	if normal_style != null:
		_expect(normal_style.border_width_left == 0, "Normal style should have no left border", results)
		_expect(normal_style.bg_color.is_equal_approx(Color(0.12, 0.14, 0.18, 1.0)), "Normal bg color should be dark surface", results)

	_free_test_environment(env)

func _test_connectivity_status_indicator(results: Dictionary) -> void:
	var env := _create_test_environment()
	var controller: LayoutController = env["controller"] as LayoutController
	var status_label: Label = env["status_label"] as Label

	# Test online when not offline enforced
	OfflineEnforcer.reset()
	controller.update_connectivity_status(true)
	_expect(status_label.text.contains("Online"), "Status should indicate Online when connected", results)
	_expect(status_label.modulate.is_equal_approx(Color(0.3, 0.85, 0.45, 1.0)), "Online status should be green", results)

	# Test offline when disconnected
	controller.update_connectivity_status(false)
	_expect(status_label.text.contains("Offline"), "Status should indicate Offline when disconnected", results)
	_expect(status_label.modulate.is_equal_approx(Color(1.0, 0.6, 0.2, 1.0)), "Offline status should be amber", results)

	# Test offline enforcement via config
	var config := OgsConfigScript.new()
	config.force_offline = true
	OfflineEnforcer.apply_config(config)
	controller.update_connectivity_status(true)
	_expect(status_label.text.contains("Offline"), "Enforced offline should remain Offline even if is_online is true", results)
	_expect(status_label.tooltip_text.contains("force_offline"), "Tooltip should explain enforcement reason", results)

	OfflineEnforcer.reset()
	_free_test_environment(env)

func _test_version_label_update(results: Dictionary) -> void:
	var env := _create_test_environment()
	var controller: LayoutController = env["controller"] as LayoutController
	var version_label: Label = env["version_label"] as Label

	controller.update_version("v0.1.0")
	_expect(version_label.text == "v0.1.0", "Version label text should update to v0.1.0", results)
	_expect(version_label.tooltip_text.contains("0.1.0"), "Version label tooltip should contain version", results)

	_free_test_environment(env)

func _test_cleanup_frees_overrides(results: Dictionary) -> void:
	var env := _create_test_environment()
	var controller: LayoutController = env["controller"] as LayoutController
	var btn_projects: Button = env["btn_projects"] as Button

	_expect(btn_projects.has_theme_stylebox_override("normal"), "Projects button should have stylebox override before cleanup", results)
	controller.cleanup()
	_expect(not btn_projects.has_theme_stylebox_override("normal"), "Cleanup should remove stylebox override from buttons", results)

	_free_test_environment(env)

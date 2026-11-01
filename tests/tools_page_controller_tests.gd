## ToolsPageControllerTests: Unit tests for ToolsPageController thread lifecycle and cleanup.
##
## Tests:
## - NOTIFICATION_PREDELETE joins an alive removal thread.
## - cleanup() is safe when removal_thread is null.
## - NOTIFICATION_PREDELETE joins a finished-but-started removal thread.
## - Main scene NOTIFICATION_PREQUIT_CLEANUP triggers tools_page_controller.cleanup().

extends RefCounted
class_name ToolsPageControllerTests

const ToolsPageControllerScript = preload("res://scripts/tools/tools_page_controller.gd")
const ToolsControllerScript = preload("res://scripts/tools/tools_controller.gd")
const PathResolverScript = preload("res://scripts/library/path_resolver.gd")
const PathUtils = preload("res://scripts/utils/path_utils.gd")

class MockToolsControllerForBadges extends ToolsController:
	var mock_tools: Dictionary = {}
	func _init() -> void:
		super(null, "")
	func get_categorized_tools() -> Dictionary:
		return mock_tools

func run() -> Dictionary:
	var results := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}

	_test_predelete_joins_alive_removal_thread(results)
	_test_predelete_no_crash_when_thread_null(results)
	_test_thread_reference_cleared_after_predelete(results)
	_test_main_notification_calls_cleanup(results)
	_test_dynamic_tab_title_count_badges(results)
	_test_installed_empty_state_visibility_toggles(results)
	_test_library_footer_visibility_and_path_resolution(results)
	_test_browse_available_tools_button_switches_tab(results)
	_test_category_sections_and_dividers_visibility(results)

	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_predelete_joins_alive_removal_thread(results: Dictionary) -> void:
	var controller = ToolsPageControllerScript.new()

	var sem = Semaphore.new()
	var thread = Thread.new()
	var start_err = thread.start(func() -> void: sem.wait())
	_expect(start_err == OK, "Thread.start() should succeed", results)
	if start_err != OK:
		return

	var deadline_msec = Time.get_ticks_msec() + 2000
	while not thread.is_alive() and Time.get_ticks_msec() < deadline_msec:
		OS.delay_msec(5)

	_expect(thread.is_alive(), "Thread should be alive and blocked on semaphore", results)

	controller.removal_thread = thread

	sem.post()
	controller.notification(NOTIFICATION_PREDELETE)

	_expect(controller.removal_thread == null, "NOTIFICATION_PREDELETE should null removal_thread", results)
	_expect(not thread.is_alive(), "Thread should not be alive after cleanup", results)

	if thread.is_started():
		thread.wait_to_finish()

func _test_predelete_no_crash_when_thread_null(results: Dictionary) -> void:
	var controller = ToolsPageControllerScript.new()
	controller.notification(NOTIFICATION_PREDELETE)
	_expect(true, "NOTIFICATION_PREDELETE with null removal_thread should not crash", results)

func _test_thread_reference_cleared_after_predelete(results: Dictionary) -> void:
	var controller = ToolsPageControllerScript.new()

	var thread = Thread.new()
	var start_err = thread.start(func() -> void: pass)
	_expect(start_err == OK, "Thread.start() should succeed", results)
	if start_err != OK:
		return

	var deadline_msec = Time.get_ticks_msec() + 2000
	while thread.is_alive() and Time.get_ticks_msec() < deadline_msec:
		OS.delay_msec(5)

	_expect(not thread.is_alive(), "Thread should finish before predelete", results)
	_expect(thread.is_started(), "Thread should be started before wait_to_finish", results)

	controller.removal_thread = thread
	controller.notification(NOTIFICATION_PREDELETE)

	_expect(controller.removal_thread == null, "removal_thread should be null after predelete", results)
	_expect(not thread.is_started(), "Thread should be joined during predelete", results)

func _test_main_notification_calls_cleanup(results: Dictionary) -> void:
	var scene = load("res://main.tscn")
	if scene == null:
		_expect(false, "main.tscn should load", results)
		return
	var main_instance = scene.instantiate()
	
	var mock_controller = ToolsPageControllerScript.new()
	var sem = Semaphore.new()
	var thread = Thread.new()
	var start_err = thread.start(func() -> void: sem.wait())
	if start_err == OK:
		var deadline_msec = Time.get_ticks_msec() + 2000
		while not thread.is_alive() and Time.get_ticks_msec() < deadline_msec:
			OS.delay_msec(5)
		mock_controller.removal_thread = thread
		sem.post()

	main_instance.tools_page_controller = mock_controller
	main_instance.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)

	_expect(mock_controller.removal_thread == null, "NOTIFICATION_WM_CLOSE_REQUEST in main should invoke tools_page_controller.cleanup()", results)
	if thread.is_started():
		thread.wait_to_finish()
	main_instance.free()

func _test_dynamic_tab_title_count_badges(results: Dictionary) -> void:
	var controller = ToolsPageControllerScript.new()
	var mock_tools_controller = MockToolsControllerForBadges.new()

	var deps = ToolsPageControllerScript.UIDeps.new()
	var tabs = TabContainer.new()
	var tab_installed = Control.new()
	var tab_download = Control.new()
	tabs.add_child(tab_installed)
	tabs.add_child(tab_download)
	deps.tools_tabs = tabs

	controller.setup(deps, mock_tools_controller, null, null, null)

	# 1. Empty catalog
	mock_tools_controller.mock_tools = {}
	controller.populate_tools_ui()
	_expect(tabs.get_tab_title(0) == "Installed (0)", "Tab 0 should show 'Installed (0)' when empty (was: %s)" % tabs.get_tab_title(0), results)
	_expect(tabs.get_tab_title(1) == "Download (0)", "Tab 1 should show 'Download (0)' when empty (was: %s)" % tabs.get_tab_title(1), results)

	# 2. 3 tools in catalog, 1 installed
	mock_tools_controller.mock_tools = {
		"Engine": [
			{"id": "godot", "version": "4.7.2", "installed": true}
		],
		"3D": [
			{"id": "blender", "version": "4.2", "installed": false}
		],
		"2D": [
			{"id": "krita", "version": "5.2", "installed": false}
		]
	}
	controller.populate_tools_ui()
	_expect(tabs.get_tab_title(0) == "Installed (1)", "Tab 0 should show 'Installed (1)' (was: %s)" % tabs.get_tab_title(0), results)
	_expect(tabs.get_tab_title(1) == "Download (3)", "Tab 1 should show 'Download (3)' (was: %s)" % tabs.get_tab_title(1), results)

	# 3. 2 tools installed, 3 total in catalog
	mock_tools_controller.mock_tools = {
		"Engine": [
			{"id": "godot", "version": "4.7.2", "installed": true}
		],
		"3D": [
			{"id": "blender", "version": "4.2", "installed": false}
		],
		"2D": [
			{"id": "krita", "version": "5.2", "installed": true}
		]
	}
	controller.populate_tools_ui()
	_expect(tabs.get_tab_title(0) == "Installed (2)", "Tab 0 should show 'Installed (2)' after second install (was: %s)" % tabs.get_tab_title(0), results)
	_expect(tabs.get_tab_title(1) == "Download (3)", "Tab 1 should show 'Download (3)' after second install (was: %s)" % tabs.get_tab_title(1), results)

	tabs.free()

func _test_installed_empty_state_visibility_toggles(results: Dictionary) -> void:
	var controller = ToolsPageControllerScript.new()
	var mock_tools_controller = MockToolsControllerForBadges.new()

	var deps = ToolsPageControllerScript.UIDeps.new()
	var tabs = TabContainer.new()
	var tab_installed = Control.new()
	var tab_download = Control.new()
	tabs.add_child(tab_installed)
	tabs.add_child(tab_download)
	deps.tools_tabs = tabs

	var installed_content = VBoxContainer.new()
	var empty_state = VBoxContainer.new()
	var footer = PanelContainer.new()
	var path_label = Label.new()
	var warning_label = Label.new()
	tab_installed.add_child(installed_content)
	tab_installed.add_child(empty_state)
	tab_installed.add_child(footer)
	footer.add_child(path_label)
	footer.add_child(warning_label)

	deps.installed_content = installed_content
	deps.installed_empty_state = empty_state
	deps.library_footer = footer
	deps.library_path_label = path_label
	deps.library_warning_label = warning_label

	controller.setup(deps, mock_tools_controller, null, null, null)

	var expected_path = PathUtils.format_for_display(PathResolverScript.new().get_library_root())

	# 1. 0 installed tools -> empty state visible, installed content hidden, footer visible
	mock_tools_controller.mock_tools = {}
	controller.populate_tools_ui()
	_expect(empty_state.visible == true, "InstalledEmptyState should be visible when 0 tools installed", results)
	_expect(installed_content.visible == false, "InstalledContent should be hidden when 0 tools installed", results)
	_expect(footer.visible == true, "LibraryFooter should be visible when 0 tools installed", results)
	_expect(path_label.text == expected_path, "LibraryPathLabel should show resolved path when 0 tools installed", results)
	_expect(warning_label.text.find("Central Library") != -1 or warning_label.text.find("manually") != -1, "LibraryWarningLabel should contain guidance against manual modifications", results)

	# 2. Add uninstalled tool in catalog (0 installed) -> still empty state visible, footer visible
	mock_tools_controller.mock_tools = {
		"Engine": [{"id": "godot", "version": "4.7.2", "installed": false}]
	}
	controller.populate_tools_ui()
	_expect(empty_state.visible == true, "InstalledEmptyState should remain visible when catalog tools are not installed", results)
	_expect(installed_content.visible == false, "InstalledContent should remain hidden when catalog tools are not installed", results)
	_expect(footer.visible == true, "LibraryFooter should remain visible when catalog tools are not installed", results)

	# 3. 1 installed tool -> empty state hidden, installed content visible, footer visible
	mock_tools_controller.mock_tools = {
		"Engine": [{"id": "godot", "version": "4.7.2", "installed": true}]
	}
	controller.populate_tools_ui()
	_expect(empty_state.visible == false, "InstalledEmptyState should be hidden when 1 tool installed", results)
	_expect(installed_content.visible == true, "InstalledContent should be visible when 1 tool installed", results)
	_expect(footer.visible == true, "LibraryFooter should remain visible when 1 tool installed", results)

	tabs.free()

func _test_library_footer_visibility_and_path_resolution(results: Dictionary) -> void:
	var controller = ToolsPageControllerScript.new()
	var mock_tools_controller = MockToolsControllerForBadges.new()

	var deps = ToolsPageControllerScript.UIDeps.new()
	var tabs = TabContainer.new()
	var tab_installed = Control.new()
	tabs.add_child(tab_installed)
	deps.tools_tabs = tabs

	var footer = PanelContainer.new()
	footer.name = "LibraryFooter"
	var path_label = Label.new()
	path_label.name = "LibraryPathLabel"
	var warning_label = Label.new()
	warning_label.name = "LibraryWarningLabel"
	tab_installed.add_child(footer)
	footer.add_child(path_label)
	footer.add_child(warning_label)

	# Verify fallback node resolution when deps footer is not explicitly bound
	controller.setup(deps, mock_tools_controller, null, null, null)

	var expected_path = PathUtils.format_for_display(PathResolverScript.new().get_library_root())
	_expect(footer.visible == true, "LibraryFooter should be resolved and made visible via fallback lookup", results)
	_expect(path_label.text == expected_path, "LibraryPathLabel should be populated via fallback lookup", results)
	_expect(not warning_label.text.is_empty(), "LibraryWarningLabel should be populated via fallback lookup", results)

	tabs.free()

func _test_browse_available_tools_button_switches_tab(results: Dictionary) -> void:
	var controller = ToolsPageControllerScript.new()
	var mock_tools_controller = MockToolsControllerForBadges.new()

	var deps = ToolsPageControllerScript.UIDeps.new()
	var tabs = TabContainer.new()
	var tab_installed = Control.new()
	var tab_download = Control.new()
	tabs.add_child(tab_installed)
	tabs.add_child(tab_download)
	tabs.current_tab = 0
	deps.tools_tabs = tabs

	var browse_btn = Button.new()
	deps.browse_available_tools_button = browse_btn

	controller.setup(deps, mock_tools_controller, null, null, null)

	_expect(tabs.current_tab == 0, "Current tab should initially be 0 (Installed)", results)
	browse_btn.pressed.emit()
	_expect(tabs.current_tab == 1, "Clicking Browse Available Tools button should switch to tab 1 (Download)", results)

	browse_btn.free()
	tabs.free()

func _test_category_sections_and_dividers_visibility(results: Dictionary) -> void:
	var controller = ToolsPageControllerScript.new()

	var content = VBoxContainer.new()
	var sections: Array[VBoxContainer] = []
	var tool_containers: Array[VBoxContainer] = []
	var dividers: Array[HSeparator] = []

	for i in range(5):
		var sec = VBoxContainer.new()
		sec.name = "Section_%d" % i
		var tools = VBoxContainer.new()
		tools.name = "Tools_%d" % i
		sec.add_child(tools)
		content.add_child(sec)
		sections.append(sec)
		tool_containers.append(tools)
		if i < 4:
			var div = HSeparator.new()
			div.name = "Divider_%d" % i
			content.add_child(div)
			dividers.append(div)

	# Case 1: All sections empty
	controller._update_category_sections_and_dividers(tool_containers, content)
	for i in range(5):
		_expect(not sections[i].visible, "Section %d should be hidden when empty" % i, results)
	for i in range(4):
		_expect(not dividers[i].visible, "Divider %d should be hidden when all sections empty" % i, results)

	# Case 2: Only Section 1 and Section 3 have cards
	var dummy_card1 = Control.new()
	tool_containers[1].add_child(dummy_card1)
	var dummy_card3 = Control.new()
	tool_containers[3].add_child(dummy_card3)

	controller._update_category_sections_and_dividers(tool_containers, content)
	_expect(not sections[0].visible, "Section 0 should be hidden", results)
	_expect(sections[1].visible, "Section 1 should be visible", results)
	_expect(not sections[2].visible, "Section 2 should be hidden", results)
	_expect(sections[3].visible, "Section 3 should be visible", results)
	_expect(not sections[4].visible, "Section 4 should be hidden", results)

	# Divider checks:
	# Divider 0 (before Section 1) must be hidden (no leading divider)
	_expect(not dividers[0].visible, "Divider 0 (leading before section 1) must be hidden", results)
	# One divider between Section 1 and Section 3 must be visible, but not both (no consecutive dividers)
	var middle_dividers_visible: int = 0
	if dividers[1].visible: middle_dividers_visible += 1
	if dividers[2].visible: middle_dividers_visible += 1
	_expect(middle_dividers_visible == 1, "Exactly one divider must be visible between section 1 and 3 (was: %d)" % middle_dividers_visible, results)
	# Divider 3 (after Section 3) must be hidden (no trailing divider)
	_expect(not dividers[3].visible, "Divider 3 (trailing after section 3) must be hidden", results)

	# Case 3: All sections have cards
	var dummy_card0 = Control.new()
	tool_containers[0].add_child(dummy_card0)
	var dummy_card2 = Control.new()
	tool_containers[2].add_child(dummy_card2)
	var dummy_card4 = Control.new()
	tool_containers[4].add_child(dummy_card4)

	controller._update_category_sections_and_dividers(tool_containers, content)
	for i in range(5):
		_expect(sections[i].visible, "Section %d should be visible when non-empty" % i, results)
	for i in range(4):
		_expect(dividers[i].visible, "Divider %d should be visible between non-empty sections" % i, results)

	# Case 4: Only Section 0 has cards (single visible section)
	dummy_card1.free()
	dummy_card2.free()
	dummy_card3.free()
	dummy_card4.free()

	controller._update_category_sections_and_dividers(tool_containers, content)
	_expect(sections[0].visible, "Section 0 should be visible", results)
	for i in range(1, 5):
		_expect(not sections[i].visible, "Section %d should be hidden" % i, results)
	for i in range(4):
		_expect(not dividers[i].visible, "Divider %d must be hidden when only 1 section visible" % i, results)

	dummy_card0.free()
	content.free()

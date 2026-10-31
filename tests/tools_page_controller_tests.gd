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

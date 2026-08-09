## ToolsPageSceneTests: Scene-style tests for Tools page UI.
##
## Verifies Tools page nodes exist and download button state handling.

extends RefCounted
class_name ToolsPageSceneTests

const ToolsControllerScript = preload("res://scripts/tools/tools_controller.gd")

func run() -> Dictionary:
	"""Runs Tools page scene tests.
	Returns:
	  Dictionary: {"passed": int, "failed": int, "failures": Array[String]}"""
	var results := {"passed": 0, "failed": 0, "failures": []}
	_test_tools_nodes_exist(results)
	_test_connectivity_status_label(results)
	_test_download_button_state(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	"""Records test assertion."""
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _instantiate_main_scene(results: Dictionary) -> Node:
	"""Loads and instantiates main scene."""
	var scene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for tools page tests", results)
	if scene == null:
		return null
	return scene.instantiate()

func _test_tools_nodes_exist(results: Dictionary) -> void:
	"""Verifies Tools page nodes for Download tab exist."""
	var instance = _instantiate_main_scene(results)
	if instance == null:
		return

	_expect(instance.get_node_or_null("AppLayout/Content/PageTools") != null, "Tools page should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs") != null, "Tools tabs should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Download") != null, "Download tab should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Download/DownloadContent") != null, "Download content should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Download/DownloadContent/EngineSection/EngineTools") != null, "Download Engine tools container should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Download/DownloadContent/2DSection/2DTools") != null, "Download 2D tools container should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Download/DownloadContent/3DSection/3DTools") != null, "Download 3D tools container should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Download/DownloadContent/AudioSection/AudioTools") != null, "Download Audio tools container should exist", results)

	instance.free()

func _test_connectivity_status_label(results: Dictionary) -> void:
	"""Verifies online/offline status updates the Tools status label."""
	var instance = _instantiate_main_scene(results)
	if instance == null:
		return

	var status_label = instance.get_node_or_null("AppLayout/Content/PageTools/ToolsStatusLabel")
	var offline_label = instance.get_node_or_null("AppLayout/Content/PageTools/OfflineMessage")
	_expect(status_label != null, "Tools status label should exist", results)
	_expect(offline_label != null, "Tools offline label should exist", results)
	if status_label != null:
		instance.tools_status_label = status_label
		instance.tools_offline_message = offline_label
		instance._update_tools_connectivity_status(true)
		_expect(status_label.text.find("Online") != -1, "Status label should show Online", results)
		instance._update_tools_connectivity_status(false)
		_expect(status_label.text.find("Offline") != -1, "Status label should show Offline", results)

	instance.free()

func _test_download_button_state(results: Dictionary) -> void:
	"""Verifies download buttons disable while a download is active."""
	var instance = _instantiate_main_scene(results)
	if instance == null:
		return

	var controller = ToolsControllerScript.new(null, "https://example.com/repository.json")
	instance.tools_controller = controller
	
	var button_active = Button.new()
	var button_other = Button.new()
	
	instance.tool_cards = {
		"godot_4.3": {"button": button_active, "tool_id": "godot", "version": "4.3"},
		"krita_5.2.15": {"button": button_other, "tool_id": "krita", "version": "5.2.15"}
	}
	
	controller._currently_downloading["godot_4.3"] = true
	instance._update_download_button_states()
	_expect(button_active.disabled == false, "active download button should be enabled", results)
	_expect(button_other.disabled == true, "other download buttons should be disabled", results)
	
	button_active.free()
	button_other.free()
	instance.free()

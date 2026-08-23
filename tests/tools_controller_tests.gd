## ToolsControllerTests: Unit tests for ToolsController download tracking.

extends RefCounted
class_name ToolsControllerTests

const ToolsControllerScript = preload("res://scripts/tools/tools_controller.gd")
const MirrorRepositoryScript = preload("res://scripts/mirror/mirror_repository.gd")

class DummyHydrator:
	extends RemoteMirrorHydrator
	var calls: Array = []

	func _init() -> void:
		## Overrides parent initializer to avoid network setup.
		pass

	func hydrate_async(tools_to_install: Array) -> void:
		## Records hydrate requests without performing network work.
		calls.append(tools_to_install)

func run() -> Dictionary:
	## Runs ToolsController unit tests.
	var results = {"passed": 0, "failed": 0, "failures": []}
	_test_download_tracking(results)
	_test_download_not_found(results)
	_test_download_already_active(results)
	_test_has_repository_data(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records test assertions.
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _make_controller() -> ToolsController:
	## Creates a ToolsController with a dummy hydrator.
	var controller = ToolsControllerScript.new(null, "https://example.com/repository.json")
	controller.remote_hydrator = DummyHydrator.new()
	return controller

func _make_valid_repo() -> MirrorRepository:
	## Builds a valid repository with one tool entry.
	var data = {
		"schema_version": 1,
		"mirror_name": "OGS",
		"tools": [
			{
				"id": "godot",
				"version": "4.3",
				"archive_url": "https://example.com/godot.zip",
				"sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
			}
		]
	}
	return MirrorRepositoryScript.from_dict(data)

func _test_download_tracking(results: Dictionary) -> void:
	## Download should mark tool as active and clear on completion.
	var controller = _make_controller()
	controller.repository = _make_valid_repo()

	controller.download_tool("godot", "4.3")
	_expect(controller.is_downloading("godot", "4.3"), "download should be active", results)
	_expect(controller.has_active_downloads(), "active downloads should be true", results)

	var dummy = controller.remote_hydrator as DummyHydrator
	_expect(dummy.calls.size() == 1, "hydrate_async should be called", results)

	controller._on_install_complete("godot", "4.3", true, "")
	_expect(not controller.is_downloading("godot", "4.3"), "download should clear after install", results)
	_expect(not controller.has_active_downloads(), "active downloads should be false", results)

func _test_download_not_found(results: Dictionary) -> void:
	## Download should not start when tool is missing.
	var controller = _make_controller()
	controller.repository = MirrorRepositoryScript.from_dict({
		"schema_version": 1,
		"mirror_name": "OGS",
		"tools": []
	})

	controller.download_tool("missing", "1.0")
	_expect(not controller.is_downloading("missing", "1.0"), "missing tool should not download", results)
	_expect(not controller.has_active_downloads(), "no active downloads expected", results)

	var dummy = controller.remote_hydrator as DummyHydrator
	_expect(dummy.calls.is_empty(), "hydrate_async should not be called", results)

func _test_download_already_active(results: Dictionary) -> void:
	## Second download request for same tool should be ignored.
	var controller = _make_controller()
	controller.repository = _make_valid_repo()
	controller._currently_downloading["godot_4.3"] = true

	controller.download_tool("godot", "4.3")
	var dummy = controller.remote_hydrator as DummyHydrator
	_expect(dummy.calls.is_empty(), "duplicate download should not call hydrate_async", results)

func _test_has_repository_data(results: Dictionary) -> void:
	## Repository data flag should reflect available tools list.
	var controller = _make_controller()
	controller._available_tools = []
	_expect(not controller.has_repository_data(), "empty repository should report no data", results)
	controller._available_tools = [{"id": "godot", "version": "4.3"}]
	_expect(controller.has_repository_data(), "non-empty repository should report data", results)

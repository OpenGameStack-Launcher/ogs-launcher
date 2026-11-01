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
	_test_get_categorized_tools_with_code_category(results)
	_test_get_categorized_tools_defensive_unknown_category(results)
	_test_scans_installed_tools_and_categorizes_offline(results)
	_test_init_and_refresh_scans_installed_tools(results)
	_test_cleanup_frees_http_requests(results)
	_test_on_repository_fetched_updates_online_and_emits(results)
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
				"executable_path": "godot.exe",
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

func _test_get_categorized_tools_with_code_category(results: Dictionary) -> void:
	## Categorization should include Code tools in Code category bucket.
	var controller = _make_controller()
	controller._available_tools = [
		{"id": "git", "version": "2.56.0.4", "category": "Code"},
		{"id": "vscodium", "version": "1.143.17232"}
	]
	var categorized = controller.get_categorized_tools()
	_expect(categorized.has("Code"), "categorized tools should contain Code bucket", results)
	_expect(categorized["Code"].size() == 2, "Code bucket should contain 2 tools", results)

func _test_get_categorized_tools_defensive_unknown_category(results: Dictionary) -> void:
	## Unknown category in tool entry should be dynamically initialized without crashing.
	var controller = _make_controller()
	controller._available_tools = [
		{"id": "custom_tool", "version": "1.0.0", "category": "FutureCategory"}
	]
	var categorized = controller.get_categorized_tools()
	_expect(categorized.has("FutureCategory"), "categorized tools should dynamically create FutureCategory bucket", results)
	_expect(categorized["FutureCategory"].size() == 1, "FutureCategory should contain 1 tool", results)

func _test_scans_installed_tools_and_categorizes_offline(results: Dictionary) -> void:
	## Verifies locally installed tools are included in get_categorized_tools even when _available_tools is empty.
	var controller = _make_controller()
	controller._available_tools = []
	controller._installed_tools = {
		"godot": ["4.7.2"],
		"blender": ["4.2.0"],
		"git": ["2.44.0"]
	}
	
	var categorized = controller.get_categorized_tools()
	_expect(categorized.has("Engine"), "categorized should contain Engine category", results)
	_expect(categorized["Engine"].size() == 1, "Engine category should have 1 installed tool", results)
	if categorized["Engine"].size() == 1:
		_expect(categorized["Engine"][0]["id"] == "godot", "Engine tool id should be godot", results)
		_expect(categorized["Engine"][0]["version"] == "4.7.2", "Engine tool version should be 4.7.2", results)
		_expect(categorized["Engine"][0]["installed"] == true, "Engine tool should be marked installed", results)
	
	_expect(categorized.has("3D"), "categorized should contain 3D category", results)
	_expect(categorized["3D"].size() == 1, "3D category should have 1 installed tool", results)
	if categorized["3D"].size() == 1:
		_expect(categorized["3D"][0]["id"] == "blender", "3D tool id should be blender", results)
		_expect(categorized["3D"][0]["installed"] == true, "3D tool should be marked installed", results)
	
	_expect(categorized.has("Code"), "categorized should contain Code category", results)
	_expect(categorized["Code"].size() == 1, "Code category should have 1 installed tool", results)
	if categorized["Code"].size() == 1:
		_expect(categorized["Code"][0]["id"] == "git", "Code tool id should be git", results)
		_expect(categorized["Code"][0]["installed"] == true, "Code tool should be marked installed", results)

	# Verify deduplication when tool is also in _available_tools
	controller._available_tools = [
		{
			"id": "godot",
			"version": "4.7.2",
			"size_bytes": 1000,
			"archive_url": "https://example.com/godot.zip"
		}
	]
	var deduplicated = controller.get_categorized_tools()
	_expect(deduplicated["Engine"].size() == 1, "godot 4.7.2 should not be duplicated when present in both available and installed", results)
	_expect(deduplicated["Engine"][0]["installed"] == true, "available tool should be marked installed when in installed_tools", results)

func _test_init_and_refresh_scans_installed_tools(results: Dictionary) -> void:
	## Verifies _scan_installed_tools is called during _init and in _finalize_refresh(false).
	var lib_root = PathResolver.new().get_library_root()
	var test_dir = lib_root.path_join("godot").path_join("4.7.2")
	DirAccess.make_dir_recursive_absolute(test_dir)
	
	var controller = ToolsControllerScript.new(null, "https://example.com/repository.json")
	_expect(controller._installed_tools.has("godot"), "controller._init should scan installed tools from library", results)
	if controller._installed_tools.has("godot"):
		_expect("4.7.2" in controller._installed_tools["godot"], "installed tools should contain version 4.7.2", results)
	
	# Simulate clearing and finalizing refresh with failure
	controller._installed_tools.clear()
	_expect(controller._installed_tools.is_empty(), "installed tools cleared manually", results)
	
	controller._finalize_refresh(false)
	_expect(controller._installed_tools.has("godot"), "_finalize_refresh(false) should rescan installed tools", results)
	
	# Cleanup test directory
	DirAccess.remove_absolute(test_dir)
	DirAccess.remove_absolute(lib_root.path_join("godot"))

func _test_cleanup_frees_http_requests(results: Dictionary) -> void:
	## Verifies ToolsController.cleanup() cancels and frees active HTTPRequest nodes.
	var tree = Engine.get_main_loop() as SceneTree
	var controller = ToolsControllerScript.new(tree, "https://example.com/repository.json")
	
	controller.check_connectivity()
	_expect(controller._active_http_requests.size() == 1, "active requests should have 1 item after check_connectivity", results)
	if not controller._active_http_requests.is_empty():
		var http: HTTPRequest = controller._active_http_requests[0]
		_expect(is_instance_valid(http), "http request node should be valid instance", results)
		_expect(not http.is_queued_for_deletion(), "http request node should not be queued for deletion before cleanup", results)
		
		controller.cleanup()
		_expect(controller._active_http_requests.is_empty(), "active requests array should be empty after cleanup", results)
		_expect(http.is_queued_for_deletion(), "http request node should be queued for deletion after cleanup", results)
	
	# Verify cleanup is idempotent
	controller.cleanup()
	_expect(controller._active_http_requests.is_empty(), "repeat cleanup should remain empty", results)

func _test_on_repository_fetched_updates_online_and_emits(results: Dictionary) -> void:
	## Verifies _on_repository_fetched updates _is_online and emits connectivity_checked(true).
	var tree = Engine.get_main_loop() as SceneTree
	var controller = ToolsControllerScript.new(tree, "https://example.com/repository.json")
	
	var signal_state = {"emitted": false, "value": false}
	controller.connectivity_checked.connect(func(online: bool):
		signal_state["emitted"] = true
		signal_state["value"] = online
	)
	
	var dummy_http = HTTPRequest.new()
	tree.root.add_child(dummy_http)
	controller._active_http_requests.append(dummy_http)
	
	# 1. Successful HTTP 200 with valid repository body
	var valid_json = JSON.stringify({
		"schema_version": 1,
		"mirror_name": "OGS",
		"tools": [
			{
				"id": "godot",
				"version": "4.3",
				"archive_url": "https://example.com/godot.zip",
				"executable_path": "godot.exe",
				"sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
			}
		]
	}).to_utf8_buffer()
	
	controller._on_repository_fetched(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), valid_json, dummy_http)
	_expect(controller.is_online() == true, "successful fetch should set _is_online to true", results)
	_expect(signal_state["emitted"] == true, "successful fetch should emit connectivity_checked", results)
	_expect(signal_state["value"] == true, "connectivity_checked signal value should be true", results)
	_expect(controller._active_http_requests.is_empty(), "active requests should no longer track completed http", results)
	
	# 2. Failed HTTP fetch
	var dummy_http2 = HTTPRequest.new()
	tree.root.add_child(dummy_http2)
	controller._active_http_requests.append(dummy_http2)
	controller._on_repository_fetched(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), dummy_http2)
	_expect(controller.is_online() == false, "failed fetch should set _is_online to false", results)



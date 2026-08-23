## Debug script to test offline enforcement

extends SceneTree

func _init() -> void:
	pass

func _process(_delta: float) -> bool:
	# Preload required classes
	load("res://scripts/config/ogs_config.gd")
	load("res://scripts/logging/logger.gd")
	load("res://scripts/network/offline_enforcer.gd")
	load("res://scripts/network/socket_blocker.gd")
	load("res://scripts/network/tool_downloader.gd")
	load("res://scripts/library/path_resolver.gd")
	load("res://scripts/library/library_manager.gd")
	load("res://scripts/library/tool_extractor.gd")
	
	print("\n=== DEBUG OFFLINE TEST ===")
	print("0. Cleaning library...")
	_cleanup_library()
	print("   cleanup complete")
	
	print("\n1. Initial state:")
	print("   offline_active: ", OfflineEnforcer.is_offline())
	
	print("\n2. Resetting OfflineEnforcer...")
	OfflineEnforcer.reset()
	print("   offline_active after reset: ", OfflineEnforcer.is_offline())
	
	print("\n3. Creating config with offline_mode: true...")
	var config = OgsConfig.from_dict({"offline_mode": true})
	print("   config.offline_mode: ", config.offline_mode)
	print("   config.force_offline: ", config.force_offline)
	print("   config.is_offline(): ", config.is_offline())
	
	print("\n4. Applying config to OfflineEnforcer...")
	OfflineEnforcer.apply_config(config)
	print("   offline_active after apply: ", OfflineEnforcer.is_offline())
	print("   offline reason: ", OfflineEnforcer.get_reason())
	
	print("\n5. Testing guard_network_call...")
	var guard = OfflineEnforcer.guard_network_call("test_context")
	print("   guard['allowed']: ", guard["allowed"])
	print("   guard['error_code']: ", guard.get("error_code", "MISSING"))
	print("   guard['error_message']: ", guard.get("error_message", "MISSING"))
	
	print("\n6. Creating ToolDownloader with mirror URL...")
	var downloader = ToolDownloader.new("https://mirror.ogs.io")
	print("   downloader.mirror_url: ", downloader.mirror_url)
	
	print("\n7. Calling download_tool...")
	var result = downloader.download_tool("godot", "4.3")
	print("   result['success']: ", result["success"])
	print("   result['error_code']: ", result.get("error_code", "MISSING"))
	print("   result['error_message']: ", result.get("error_message", "MISSING"))
	print("   result['already_exists']: ", result.get("already_exists", "MISSING"))
	
	print("\n8. Test assertion:")
	print("   Expected error_code: ", ToolDownloader.DownloadError.OFFLINE_BLOCKED)
	print("   Actual error_code: ", result.get("error_code", -1))
	print("   Match: ", result.get("error_code", -1) == ToolDownloader.DownloadError.OFFLINE_BLOCKED)
	
	print("\n=== END DEBUG ===\n")
	
	quit(0)
	return true

func _cleanup_library() -> void:
	## Removes test tool directories from the library.
	var appdata = OS.get_environment("LOCALAPPDATA")
	if appdata.is_empty():
		print("   LOCALAPPDATA not set, cannot cleanup")
		return
	var library_root = appdata.path_join("OGS").path_join("Library")
	print("   library_root: ", library_root)
	print("   library_root exists: ", DirAccess.dir_exists_absolute(library_root))
	if DirAccess.dir_exists_absolute(library_root):
		for tool_id in ["godot", "blender", "krita", "audacity"]:
			var tool_dir = library_root.path_join(tool_id)
			print("   checking tool_dir: ", tool_dir, " exists: ", DirAccess.dir_exists_absolute(tool_dir))
			if DirAccess.dir_exists_absolute(tool_dir):
				_recursive_remove_dir(tool_dir)
				print("   removed: ", tool_dir)

func _recursive_remove_dir(path: String) -> void:
	## Recursively removes a directory and all its contents.
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var full_path = path.path_join(file_name)
			if dir.current_is_dir():
				_recursive_remove_dir(full_path)
			else:
				DirAccess.remove_absolute(full_path)
			file_name = dir.get_next()
	DirAccess.remove_absolute(path)

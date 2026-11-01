## OnboardingWizardTests: Verifies onboarding wizard behavior, dialog layout, and brand visuals.
##
## Tests first-run detection, brand logo and preview cards, unified footer
## action buttons, and Start/Skip signal workflows.

extends RefCounted
class_name OnboardingWizardTests

func run() -> Dictionary:
	## Runs all onboarding wizard behavior and scene layout tests.
	var results: Dictionary = {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	
	var tests: Array = [
		{"name": "test_should_show_wizard_returns_false_when_library_has_visible_entry", "func": test_should_show_wizard_returns_false_when_library_has_visible_entry},
		{"name": "test_should_show_wizard_returns_true_when_library_only_has_hidden_entries", "func": test_should_show_wizard_returns_true_when_library_only_has_hidden_entries},
		{"name": "test_onboarding_dialog_scene_structure", "func": test_onboarding_dialog_scene_structure},
		{"name": "test_onboarding_wizard_start_action", "func": test_onboarding_wizard_start_action},
		{"name": "test_onboarding_wizard_skip_action", "func": test_onboarding_wizard_skip_action},
		{"name": "test_onboarding_wizard_add_button_fallback", "func": test_onboarding_wizard_add_button_fallback},
	]
	
	for test in tests:
		var result: Dictionary = test.func.call()
		if result["passed"]:
			results["passed"] += 1
		else:
			results["failed"] += 1
			results["failures"].append("%s: %s" % [test["name"], result["error"]])
	
	return results

func test_should_show_wizard_returns_false_when_library_has_visible_entry() -> Dictionary:
	## Verifies populated libraries skip the first-run wizard.
	var test_root: String = _create_temp_library_root("populated")
	var tool_dir: String = test_root.path_join("godot")
	DirAccess.make_dir_recursive_absolute(tool_dir)
	
	var wizard: OnboardingWizard = OnboardingWizard.new()
	wizard.library_root = test_root
	wizard.wizard_complete_flag_path = test_root.path_join("wizard_complete.txt")
	var should_show: bool = wizard.should_show_wizard()
	
	_remove_directory_recursive(test_root)
	if should_show:
		return {"passed": false, "error": "Wizard should not show when a visible tool directory exists"}
	return {"passed": true}

func test_should_show_wizard_returns_true_when_library_only_has_hidden_entries() -> Dictionary:
	## Verifies hidden-only library entries still count as first run.
	var test_root: String = _create_temp_library_root("hidden_only")
	var hidden_dir: String = test_root.path_join(".hidden")
	DirAccess.make_dir_recursive_absolute(hidden_dir)
	var hidden_file: FileAccess = FileAccess.open(test_root.path_join(".keep"), FileAccess.WRITE)
	if hidden_file != null:
		hidden_file.store_string("hidden marker")
	
	var wizard: OnboardingWizard = OnboardingWizard.new()
	wizard.library_root = test_root
	wizard.wizard_complete_flag_path = test_root.path_join("wizard_complete.txt")
	var should_show: bool = wizard.should_show_wizard()
	
	_remove_directory_recursive(test_root)
	if not should_show:
		return {"passed": false, "error": "Wizard should show when library has only hidden entries"}
	return {"passed": true}

func test_onboarding_dialog_scene_structure() -> Dictionary:
	## Verifies brand visuals, starter stack preview cards, and unified action buttons in main.tscn.
	var scene: PackedScene = load("res://main.tscn")
	if scene == null:
		return {"passed": false, "error": "Failed to load main.tscn"}
	
	var instance: Node = scene.instantiate()
	var dialog: AcceptDialog = instance.get_node_or_null("OnboardingWizardDialog") as AcceptDialog
	if dialog == null:
		instance.free()
		return {"passed": false, "error": "OnboardingWizardDialog not found as AcceptDialog in main.tscn"}
	
	# Verify dialog sizing
	if dialog.size.x < 540 or dialog.size.y < 380:
		var size_str: String = "%s" % dialog.size
		instance.free()
		return {"passed": false, "error": "Dialog size should be at least (540, 380), was: %s" % size_str}
	if dialog.min_size.x < 540 or dialog.min_size.y < 380:
		var min_size_str: String = "%s" % dialog.min_size
		instance.free()
		return {"passed": false, "error": "Dialog min_size should be at least (540, 380), was: %s" % min_size_str}
	
	# Verify BrandHeader and BrandLogo
	var brand_header: HBoxContainer = dialog.get_node_or_null("VBoxContainer/BrandHeader") as HBoxContainer
	if brand_header == null:
		instance.free()
		return {"passed": false, "error": "VBoxContainer/BrandHeader not found"}
	
	var brand_logo: TextureRect = brand_header.get_node_or_null("BrandLogo") as TextureRect
	if brand_logo == null:
		instance.free()
		return {"passed": false, "error": "BrandLogo TextureRect not found in BrandHeader"}
	if brand_logo.texture == null:
		instance.free()
		return {"passed": false, "error": "BrandLogo texture is null"}
	if not brand_logo.texture.resource_path.ends_with("logo.png"):
		var path_str: String = brand_logo.texture.resource_path
		instance.free()
		return {"passed": false, "error": "BrandLogo texture should point to logo.png, was: %s" % path_str}
	if brand_logo.custom_minimum_size.x < 48 or brand_logo.custom_minimum_size.y < 48:
		var logo_size_str: String = "%s" % brand_logo.custom_minimum_size
		instance.free()
		return {"passed": false, "error": "BrandLogo minimum size should be at least 48x48, was: %s" % logo_size_str}
	if brand_logo.expand_mode != TextureRect.EXPAND_IGNORE_SIZE:
		instance.free()
		return {"passed": false, "error": "BrandLogo expand_mode should be EXPAND_IGNORE_SIZE"}
	if brand_logo.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		instance.free()
		return {"passed": false, "error": "BrandLogo stretch_mode should be STRETCH_KEEP_ASPECT_CENTERED"}
	
	var header_title: Label = brand_header.get_node_or_null("HeaderTitle") as Label
	if header_title == null or header_title.text != "Welcome to Open Game Stack":
		instance.free()
		return {"passed": false, "error": "HeaderTitle label with text 'Welcome to Open Game Stack' not found"}
	
	# Verify StarterStackCard preview card
	var preview_card: PanelContainer = dialog.get_node_or_null("VBoxContainer/StarterStackCard") as PanelContainer
	if preview_card == null:
		instance.free()
		return {"passed": false, "error": "StarterStackCard PanelContainer not found"}
	
	var card_title: Label = preview_card.get_node_or_null("CardContent/CardHeader/StarterStackTitle") as Label
	if card_title == null or card_title.text != "Default Starter Stack":
		instance.free()
		return {"passed": false, "error": "StarterStackTitle label not found or text incorrect"}
	
	var card_subtitle: Label = preview_card.get_node_or_null("CardContent/CardHeader/StarterStackSubtitle") as Label
	if card_subtitle == null or card_subtitle.text.is_empty():
		instance.free()
		return {"passed": false, "error": "StarterStackSubtitle label not found or empty"}
	
	var tool_row: HBoxContainer = preview_card.get_node_or_null("CardContent/ToolPreviewRow") as HBoxContainer
	if tool_row == null:
		instance.free()
		return {"passed": false, "error": "ToolPreviewRow HBoxContainer not found"}
	
	var expected_tools: Array[String] = ["Godot", "Blender", "GIMP", "Audacity", "Krita", "VSCodium"]
	for tool_name in expected_tools:
		var tool_node: VBoxContainer = tool_row.get_node_or_null("Tool" + tool_name) as VBoxContainer
		if tool_node == null:
			instance.free()
			return {"passed": false, "error": "Preview container for tool '%s' not found" % tool_name}
		var icon: TextureRect = tool_node.get_node_or_null(tool_name + "Icon") as TextureRect
		if icon == null or icon.texture == null:
			instance.free()
			return {"passed": false, "error": "Preview icon for tool '%s' is missing or has null texture" % tool_name}
		if not icon.texture.resource_path.to_lower().contains(tool_name.to_lower()):
			var icon_path: String = icon.texture.resource_path
			instance.free()
			return {"passed": false, "error": "Preview icon path for '%s' does not match: %s" % [tool_name, icon_path]}
		var lbl: Label = tool_node.get_node_or_null(tool_name + "Label") as Label
		if lbl == null or lbl.text != tool_name:
			instance.free()
			return {"passed": false, "error": "Preview label for tool '%s' is missing or text mismatch" % tool_name}
	
	# Verify unified action buttons in ButtonContainer
	var btn_container: HBoxContainer = dialog.get_node_or_null("VBoxContainer/ButtonContainer") as HBoxContainer
	if btn_container == null:
		instance.free()
		return {"passed": false, "error": "ButtonContainer HBoxContainer not found"}
	
	var skip_btn: Button = btn_container.get_node_or_null("SkipButton") as Button
	var start_btn: Button = btn_container.get_node_or_null("StartButton") as Button
	if skip_btn == null or start_btn == null:
		instance.free()
		return {"passed": false, "error": "Both SkipButton and StartButton must exist within ButtonContainer"}
	
	if skip_btn.text != "Skip for Now":
		instance.free()
		return {"passed": false, "error": "SkipButton text should be 'Skip for Now', was: '%s'" % skip_btn.text}
	if start_btn.text != "Start":
		instance.free()
		return {"passed": false, "error": "StartButton text should be 'Start', was: '%s'" % start_btn.text}
	
	if skip_btn.theme_type_variation != &"SecondaryButton":
		instance.free()
		return {"passed": false, "error": "SkipButton should have SecondaryButton theme_type_variation"}
	if start_btn.theme_type_variation != &"PrimaryButton":
		instance.free()
		return {"passed": false, "error": "StartButton should have PrimaryButton theme_type_variation"}
	
	if skip_btn.custom_minimum_size != Vector2(130, 36):
		var size_str: String = "%s" % skip_btn.custom_minimum_size
		instance.free()
		return {"passed": false, "error": "SkipButton custom_minimum_size should be (130, 36), was: %s" % size_str}
	if start_btn.custom_minimum_size != Vector2(130, 36):
		var size_str: String = "%s" % start_btn.custom_minimum_size
		instance.free()
		return {"passed": false, "error": "StartButton custom_minimum_size should be (130, 36), was: %s" % size_str}
	
	instance.free()
	return {"passed": true}

func test_onboarding_wizard_start_action() -> Dictionary:
	## Verifies that pressing 'Start' creates default directories, marks wizard complete, and emits signal.
	var scene: PackedScene = load("res://main.tscn")
	if scene == null:
		return {"passed": false, "error": "Failed to load main.tscn"}
	
	var test_root: String = _create_temp_library_root("start_action")
	var instance: Node = scene.instantiate()
	var dialog: AcceptDialog = instance.get_node_or_null("OnboardingWizardDialog") as AcceptDialog
	if dialog == null:
		instance.free()
		_remove_directory_recursive(test_root)
		return {"passed": false, "error": "OnboardingWizardDialog not found in main.tscn"}
	
	var wizard: OnboardingWizard = OnboardingWizard.new()
	var library_path: String = test_root.path_join("Library")
	wizard.setup(instance.get_tree(), library_path, dialog, test_root)
	
	# Verify default AcceptDialog OK button is hidden
	var ok_btn: Button = dialog.get_ok_button()
	if ok_btn != null and ok_btn.visible:
		instance.free()
		_remove_directory_recursive(test_root)
		return {"passed": false, "error": "Default AcceptDialog OK button should be hidden when custom Start button exists"}
	
	var signal_data: Array = []
	wizard.wizard_completed.connect(func(success: bool, message: String):
		signal_data.append({"success": success, "message": message})
	)
	
	var start_btn: Button = dialog.get_node_or_null("VBoxContainer/ButtonContainer/StartButton") as Button
	if start_btn == null:
		instance.free()
		_remove_directory_recursive(test_root)
		return {"passed": false, "error": "StartButton not found in ButtonContainer"}
	
	start_btn.pressed.emit()
	
	# Verify signal emission
	if signal_data.size() != 1 or not signal_data[0]["success"]:
		instance.free()
		_remove_directory_recursive(test_root)
		return {"passed": false, "error": "wizard_completed signal not emitted with success=true"}
	
	# Verify completion flag written
	var flag_path: String = test_root.path_join("ogs_wizard_complete.txt")
	if not FileAccess.file_exists(flag_path):
		instance.free()
		_remove_directory_recursive(test_root)
		return {"passed": false, "error": "Completion flag file was not written: %s" % flag_path}
	
	# Verify default stack directories created
	var godot_dir: String = library_path.path_join("godot").path_join("4.7.2")
	var blender_dir: String = library_path.path_join("blender").path_join("4.2")
	if not DirAccess.dir_exists_absolute(godot_dir) or not DirAccess.dir_exists_absolute(blender_dir):
		instance.free()
		_remove_directory_recursive(test_root)
		return {"passed": false, "error": "Default tool directories (godot 4.7.2, blender 4.2) not created"}
	
	instance.free()
	_remove_directory_recursive(test_root)
	return {"passed": true}

func test_onboarding_wizard_skip_action() -> Dictionary:
	## Verifies that pressing 'Skip for Now' marks wizard complete, hides dialog, and emits signal.
	var scene: PackedScene = load("res://main.tscn")
	if scene == null:
		return {"passed": false, "error": "Failed to load main.tscn"}
	
	var test_root: String = _create_temp_library_root("skip_action")
	var instance: Node = scene.instantiate()
	var dialog: AcceptDialog = instance.get_node_or_null("OnboardingWizardDialog") as AcceptDialog
	if dialog == null:
		instance.free()
		_remove_directory_recursive(test_root)
		return {"passed": false, "error": "OnboardingWizardDialog not found in main.tscn"}
	
	var wizard: OnboardingWizard = OnboardingWizard.new()
	var library_path: String = test_root.path_join("Library")
	wizard.setup(instance.get_tree(), library_path, dialog, test_root)
	dialog.visible = true
	
	var signal_data: Array = []
	wizard.wizard_completed.connect(func(success: bool, message: String):
		signal_data.append({"success": success, "message": message})
	)
	
	var skip_btn: Button = dialog.get_node_or_null("VBoxContainer/ButtonContainer/SkipButton") as Button
	if skip_btn == null:
		instance.free()
		_remove_directory_recursive(test_root)
		return {"passed": false, "error": "SkipButton not found in ButtonContainer"}
	
	skip_btn.pressed.emit()
	
	# Verify signal emission
	if signal_data.size() != 1 or not signal_data[0]["success"]:
		instance.free()
		_remove_directory_recursive(test_root)
		return {"passed": false, "error": "wizard_completed signal not emitted with success=true on skip"}
	
	# Verify completion flag written
	var flag_path: String = test_root.path_join("ogs_wizard_complete.txt")
	if not FileAccess.file_exists(flag_path):
		instance.free()
		_remove_directory_recursive(test_root)
		return {"passed": false, "error": "Completion flag file was not written on skip: %s" % flag_path}
	
	# Verify dialog hidden
	if dialog.visible:
		instance.free()
		_remove_directory_recursive(test_root)
		return {"passed": false, "error": "Dialog should be hidden after skipping"}
	
	instance.free()
	_remove_directory_recursive(test_root)
	return {"passed": true}

func test_onboarding_wizard_add_button_fallback() -> Dictionary:
	## Verifies that fallback custom_action ('skip') works when using built-in add_button.
	var dialog: AcceptDialog = AcceptDialog.new()
	var test_root: String = _create_temp_library_root("fallback_action")
	var wizard: OnboardingWizard = OnboardingWizard.new()
	var library_path: String = test_root.path_join("Library")
	wizard.setup(null, library_path, dialog, test_root)
	
	var signal_data: Array = []
	wizard.wizard_completed.connect(func(success: bool, message: String):
		signal_data.append({"success": success, "message": message})
	)
	
	# Emit custom action simulating add_button("Skip for Now", true, "skip")
	dialog.custom_action.emit(&"skip")
	
	if signal_data.size() != 1 or not signal_data[0]["success"]:
		dialog.free()
		_remove_directory_recursive(test_root)
		return {"passed": false, "error": "custom_action 'skip' did not emit wizard_completed"}
	
	var flag_path: String = test_root.path_join("ogs_wizard_complete.txt")
	if not FileAccess.file_exists(flag_path):
		dialog.free()
		_remove_directory_recursive(test_root)
		return {"passed": false, "error": "Completion flag file not written by custom_action 'skip'"}
	
	dialog.free()
	_remove_directory_recursive(test_root)
	return {"passed": true}

func _create_temp_library_root(suffix: String) -> String:
	## Creates a unique temp library directory for a test case.
	var base_root: String = ProjectSettings.globalize_path("user://onboarding_wizard_tests")
	var test_root: String = base_root.path_join("%s_%d" % [suffix, Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(test_root)
	return test_root

func _remove_directory_recursive(path: String) -> void:
	## Removes a directory and all nested contents for test cleanup.
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var child_path: String = path.path_join(entry)
		if dir.current_is_dir():
			_remove_directory_recursive(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)

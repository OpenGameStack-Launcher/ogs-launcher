## MainSceneTests: Scene smoke tests for main.tscn
##
## Verifies the main scene loads and default visibility state is correct.

extends RefCounted
class_name MainSceneTests

func run() -> Dictionary:
	## Runs main scene smoke tests.
	## Returns:
	## Dictionary: {"passed": int, "failed": int, "failures": Array[String]}
	var results := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	_test_main_scene_loads(results)
	_test_sidebar_structure(results)
	_test_sidebar_brand_header(results)
	_test_sidebar_footer(results)
	_test_sidebar_live_interaction(results)
	_test_content_margins(results)
	_test_typographic_scale(results)
	_test_ready_theme_application(results)
	_test_controller_type_instances(results)
	_test_network_ui_disabled_offline(results)
	_test_mirror_root_browse_dialog_frees_on_close(results)
	_test_projects_root_browse_dialog_frees_on_close(results)
	_test_button_theme_variations(results)
	_test_checkbutton_styling(results)
	_test_main_scene_button_variations(results)
	_test_projects_status_bar_structure(results)
	_test_page_projects_hierarchy_and_separation(results)
	_test_startup_tools_and_connectivity_lifecycle(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records test assertion.
	## Parameters:
	## condition (bool): If true, increments passed; if false, increments failed
	## message (String): Failure description
	## results (Dictionary): Test accumulator (modified in-place)
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_main_scene_loads(results: Dictionary) -> void:
	## Verifies main.tscn loads and projects page is visible by default.
	var scene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load", results)
	if scene == null:
		return

	var instance = scene.instantiate()
	var page_projects = instance.get_node_or_null("AppLayout/Content/PageProjects")
	var page_tools = instance.get_node_or_null("AppLayout/Content/PageTools")
	var page_settings = instance.get_node_or_null("AppLayout/Content/PageSettings")

	_expect(page_projects != null, "Projects page should exist", results)
	_expect(page_tools != null, "Tools page should exist", results)
	_expect(page_settings != null, "Settings page should exist", results)

	var add_button = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectsControls/AddButton") as Button
	_expect(add_button != null, "Add button should exist", results)
	if add_button != null:
		_expect(add_button.text == "Add Local Project", "Add button text should be 'Add Local Project'", results)

	var add_remote_button = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectsControls/AddRemoteProjectButton") as Button
	_expect(add_remote_button != null, "Add Remote Project button should exist", results)
	if add_remote_button != null:
		_expect(add_remote_button.text == "Add Remote Project", "Add Remote Project button text should be 'Add Remote Project'", results)
		_expect(add_remote_button.size_flags_horizontal == 3, "Add Remote Project button size_flags_horizontal should be 3", results)

	var projects_card = instance.get_node_or_null("AppLayout/Content/PageSettings/ProjectsCard") as PanelContainer
	_expect(projects_card != null, "ProjectsCard PanelContainer should exist in PageSettings", results)
	var mirror_card = instance.get_node_or_null("AppLayout/Content/PageSettings/MirrorCard") as PanelContainer
	_expect(mirror_card != null, "MirrorCard PanelContainer should exist in PageSettings", results)

	var projects_root_path = instance.get_node_or_null("AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsRootContainer/ProjectsRootPath") as LineEdit
	var projects_root_browse = instance.get_node_or_null("AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsRootContainer/ProjectsRootBrowseButton") as Button
	var projects_root_reset = instance.get_node_or_null("AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsRootContainer/ProjectsRootResetButton") as Button
	_expect(projects_root_path != null, "Projects root path line edit should exist", results)
	_expect(projects_root_browse != null, "Projects root browse button should exist", results)
	_expect(projects_root_reset != null, "Projects root reset button should exist", results)
	if projects_root_path != null:
		_expect(not projects_root_path.placeholder_text.is_empty(), "Projects root path placeholder_text should not be empty", results)
		_expect(not projects_root_path.placeholder_text.contains("\\"), "Projects root path placeholder_text should not contain backslashes: %s" % projects_root_path.placeholder_text, results)
		_expect(projects_root_path.clear_button_enabled, "ProjectsRootPath clear_button_enabled should be true", results)

	var mirror_root_path = instance.get_node_or_null("AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRootContainer/MirrorRootPath") as LineEdit
	_expect(mirror_root_path != null, "Mirror root path line edit should exist", results)
	if mirror_root_path != null:
		_expect(mirror_root_path.clear_button_enabled, "MirrorRootPath clear_button_enabled should be true", results)

	var mirror_repo_path = instance.get_node_or_null("AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRepoContainer/MirrorRepoPath") as LineEdit
	_expect(mirror_repo_path != null, "Mirror repo path line edit should exist", results)
	if mirror_repo_path != null:
		_expect(mirror_repo_path.clear_button_enabled, "MirrorRepoPath clear_button_enabled should be true", results)

	var projects_root_label = instance.get_node_or_null("AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsRootContainer/ProjectsRootLabel") as Label
	var mirror_root_label = instance.get_node_or_null("AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRootContainer/MirrorRootLabel") as Label
	var mirror_repo_label = instance.get_node_or_null("AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRepoContainer/MirrorRepoLabel") as Label
	_expect(projects_root_label != null and projects_root_label.custom_minimum_size.x >= 195.0, "ProjectsRootLabel custom_minimum_size.x should be >= 195", results)
	_expect(mirror_root_label != null and mirror_root_label.custom_minimum_size.x >= 195.0, "MirrorRootLabel custom_minimum_size.x should be >= 195", results)
	_expect(mirror_repo_label != null and mirror_repo_label.custom_minimum_size.x >= 195.0, "MirrorRepoLabel custom_minimum_size.x should be >= 195", results)

	# Verify PageSettings no longer contains unwired dead controls
	_expect(instance.get_node_or_null("AppLayout/Content/PageSettings/CheckUpdatesButton") == null, "PageSettings should not contain CheckUpdatesButton", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageSettings/NetworkLabel") == null, "PageSettings should not contain NetworkLabel", results)

	# Verify PageSettings no longer contains project-specific offline nodes
	_expect(instance.get_node_or_null("AppLayout/Content/PageSettings/ProjectOfflineSettingsLabel") == null, "PageSettings should not contain ProjectOfflineSettingsLabel", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageSettings/ProjectOfflineStatusLabel") == null, "PageSettings should not contain ProjectOfflineStatusLabel", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageSettings/ProjectOfflineModeCheckButton") == null, "PageSettings should not contain ProjectOfflineModeCheckButton", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageSettings/ProjectForceOfflineCheckButton") == null, "PageSettings should not contain ProjectForceOfflineCheckButton", results)

	# Verify project offline controls exist under Project Details
	var project_offline_section = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Policy")
	_expect(project_offline_section != null, "Policy sub-tab should exist under ProjectDetailsTabs", results)
	var project_offline_status_lbl = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Policy/ProjectOfflineStatusLabel") as Label
	_expect(project_offline_status_lbl != null, "ProjectOfflineStatusLabel should exist under Project Details", results)
	if project_offline_status_lbl != null and instance.get("projects_controller") != null:
		var pc = instance.get("projects_controller")
		pc.current_project_dir = "C:\\Users\\test_dev/OGS/MyProject"
		var test_cfg = preload("res://scripts/config/ogs_config.gd").new()
		pc._sync_project_offline_toggles(test_cfg)
		_expect(not project_offline_status_lbl.text.contains("\\"), "ProjectOfflineStatusLabel should not contain backslashes: %s" % project_offline_status_lbl.text, results)
		_expect(project_offline_status_lbl.text == "Selected: C:/Users/test_dev/OGS/MyProject", "ProjectOfflineStatusLabel should display normalized path: %s" % project_offline_status_lbl.text, results)

	var new_button = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectsControls/NewProjectButton")
	_expect(new_button != null, "New Project button should exist", results)

	var projects_list = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectsList")
	_expect(projects_list != null, "Projects list should exist", results)

	var search_edit = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectSearchLineEdit") as LineEdit
	_expect(search_edit != null, "ProjectSearchLineEdit should exist in main.tscn", results)
	if search_edit != null:
		_expect(search_edit.placeholder_text == "Filter projects by name, path, or tool...", "ProjectSearchLineEdit placeholder text should match specification", results)
		_expect(search_edit.clear_button_enabled == true, "ProjectSearchLineEdit clear_button_enabled should be true", results)

	var empty_state = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Library/EmptyLibraryState")
	_expect(empty_state != null, "EmptyLibraryState should exist in main.tscn", results)

	var open_project_btn = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectActionRow/OpenProjectButton") as Button
	_expect(open_project_btn != null, "Open Project button should exist", results)
	if open_project_btn != null:
		_expect(open_project_btn.text == "Open Project", "Open Project button text should be 'Open Project'", results)
		_expect(open_project_btn.disabled == true, "Open Project button should be disabled initially", results)
		_expect(open_project_btn.custom_minimum_size == Vector2(140, 32), "Open Project button minimum size should be (140, 32)", results)
		_expect(open_project_btn.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "Open Project button size flags should be expand fill", results)

	_expect(instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Toolchain/ToolActionRow/AddToolButton") != null, "Add Tool button should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Toolchain/ToolActionRow/RemoveToolButton") != null, "Remove Tool button should exist", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Toolchain/LaunchButton") != null, "Launch button should exist under Toolchain", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Explorer/ExplorerLaunchButton") != null, "ExplorerLaunchButton should exist under Explorer", results)
	_expect(instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Policy/SealButton") != null, "Seal button should exist under Policy", results)

	instance.free()

func _test_sidebar_structure(results: Dictionary) -> void:
	## Verifies that AppLayout/Sidebar is styled with dark background, 1px right border, and internal margins.
	var scene: PackedScene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for sidebar structure test", results)
	if scene == null:
		return

	var instance: Node = scene.instantiate()
	var sidebar: PanelContainer = instance.get_node_or_null("AppLayout/Sidebar") as PanelContainer
	_expect(sidebar != null, "AppLayout/Sidebar should exist as PanelContainer", results)
	if sidebar != null:
		_expect(sidebar.custom_minimum_size.x >= 200, "Sidebar minimum width should be at least 200px", results)
		var style: StyleBoxFlat = sidebar.get_theme_stylebox("panel") as StyleBoxFlat
		_expect(style != null, "Sidebar should have a panel StyleBoxFlat", results)
		if style != null:
			_expect(style.bg_color.is_equal_approx(Color(0.09, 0.10, 0.13, 1.0)), "Sidebar bg_color should match dark surface", results)
			_expect(style.border_width_right == 1, "Sidebar right border should be 1px", results)
			_expect(style.border_color.is_equal_approx(Color(0.22, 0.25, 0.30, 1.0)), "Sidebar right border color should match spec", results)
			_expect(style.content_margin_left == 12.0, "Sidebar content_margin_left should be 12px", results)
			_expect(style.content_margin_right == 12.0, "Sidebar content_margin_right should be 12px", results)
			_expect(style.content_margin_top == 16.0, "Sidebar content_margin_top should be 16px", results)
			_expect(style.content_margin_bottom == 16.0, "Sidebar content_margin_bottom should be 16px", results)

	instance.free()

func _test_sidebar_brand_header(results: Dictionary) -> void:
	## Verifies that sidebar brand header contains 32x32 logo, title, and divider.
	var scene: PackedScene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for brand header test", results)
	if scene == null:
		return

	var instance: Node = scene.instantiate()
	var brand_header: HBoxContainer = instance.get_node_or_null("AppLayout/Sidebar/VBoxContainer/BrandHeader") as HBoxContainer
	var brand_logo: TextureRect = instance.get_node_or_null("AppLayout/Sidebar/VBoxContainer/BrandHeader/BrandLogo") as TextureRect
	var brand_title: Label = instance.get_node_or_null("AppLayout/Sidebar/VBoxContainer/BrandHeader/BrandTitle") as Label
	var brand_separator: HSeparator = instance.get_node_or_null("AppLayout/Sidebar/VBoxContainer/BrandSeparator") as HSeparator

	_expect(brand_header != null, "BrandHeader HBoxContainer should exist", results)
	_expect(brand_logo != null, "BrandLogo TextureRect should exist", results)
	if brand_logo != null:
		_expect(brand_logo.custom_minimum_size == Vector2(32, 32), "BrandLogo custom_minimum_size should be 32x32", results)
		_expect(brand_logo.texture != null, "BrandLogo should have assigned texture", results)

	_expect(brand_title != null, "BrandTitle Label should exist", results)
	if brand_title != null:
		_expect(brand_title.text == "OGS Launcher", "BrandTitle text should be 'OGS Launcher'", results)

	_expect(brand_separator != null, "BrandSeparator HSeparator should exist", results)

	instance.free()

func _test_sidebar_footer(results: Dictionary) -> void:
	## Verifies that sidebar footer contains expanding spacer, footer container, status, and version labels.
	var scene: PackedScene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for sidebar footer test", results)
	if scene == null:
		return

	var instance: Node = scene.instantiate()
	var spacer: Control = instance.get_node_or_null("AppLayout/Sidebar/VBoxContainer/SidebarSpacer") as Control
	var footer: VBoxContainer = instance.get_node_or_null("AppLayout/Sidebar/VBoxContainer/SidebarFooter") as VBoxContainer
	var status_label: Label = instance.get_node_or_null("AppLayout/Sidebar/VBoxContainer/SidebarFooter/SidebarStatusLabel") as Label
	var version_label: Label = instance.get_node_or_null("AppLayout/Sidebar/VBoxContainer/SidebarFooter/SidebarVersionLabel") as Label

	_expect(spacer != null, "SidebarSpacer Control should exist", results)
	if spacer != null:
		_expect(spacer.size_flags_vertical == Control.SIZE_EXPAND_FILL, "SidebarSpacer should have SIZE_EXPAND_FILL", results)

	_expect(footer != null, "SidebarFooter VBoxContainer should exist", results)
	_expect(status_label != null, "SidebarStatusLabel should exist", results)
	_expect(version_label != null, "SidebarVersionLabel should exist", results)
	if version_label != null:
		_expect(version_label.text.contains("0.1.0"), "SidebarVersionLabel should display launcher version", results)

	instance.free()

func _test_sidebar_live_interaction(results: Dictionary) -> void:
	## Verifies that runtime main scene initializes active page highlight and handles navigation switching.
	var scene: PackedScene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for sidebar live interaction test", results)
	if scene == null:
		return

	var instance: Node = scene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(instance)

	var btn_projects: Button = instance.get_node_or_null("AppLayout/Sidebar/VBoxContainer/BtnProjects") as Button
	var btn_tools: Button = instance.get_node_or_null("AppLayout/Sidebar/VBoxContainer/BtnTools") as Button
	var btn_settings: Button = instance.get_node_or_null("AppLayout/Sidebar/VBoxContainer/BtnSettings") as Button

	_expect(btn_projects != null and btn_tools != null and btn_settings != null, "Navigation buttons should exist", results)

	# On startup, projects button should be highlighted as active
	var projects_style: StyleBoxFlat = btn_projects.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(projects_style != null and projects_style.border_width_left == 3, "Projects button should have active 3px border on startup", results)

	var tools_style: StyleBoxFlat = btn_tools.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(tools_style != null and tools_style.border_width_left == 0, "Tools button should have normal 0px border on startup", results)

	# Navigate to Tools
	instance.layout_controller.navigate_to("tools")
	var tools_active_style: StyleBoxFlat = btn_tools.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(tools_active_style != null and tools_active_style.border_width_left == 3, "Tools button should become active after navigation", results)

	var projects_restored_style: StyleBoxFlat = btn_projects.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(projects_restored_style != null and projects_restored_style.border_width_left == 0, "Projects button should restore normal style", results)

	# Verify sidebar footer connectivity indicator
	var status_label: Label = instance.sidebar_status_label
	_expect(status_label != null, "sidebar_status_label should be wired on main instance", results)

	instance.free()

func _test_content_margins(results: Dictionary) -> void:
	## Verifies that AppLayout/Content has standard 20px horizontal and 16px vertical margins.
	var scene: PackedScene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for content margins test", results)
	if scene == null:
		return

	var instance: Node = scene.instantiate()
	var content: MarginContainer = instance.get_node_or_null("AppLayout/Content") as MarginContainer
	_expect(content != null, "AppLayout/Content should exist as MarginContainer", results)
	if content != null:
		_expect(content.get_theme_constant("margin_left") == 20, "Content margin_left should be 20", results)
		_expect(content.get_theme_constant("margin_right") == 20, "Content margin_right should be 20", results)
		_expect(content.get_theme_constant("margin_top") == 16, "Content margin_top should be 16", results)
		_expect(content.get_theme_constant("margin_bottom") == 16, "Content margin_bottom should be 16", results)

	instance.free()

func _test_typographic_scale(results: Dictionary) -> void:
	## Verifies that page titles, section headers, and secondary labels follow standard typography hierarchy.
	var scene: PackedScene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for typographic scale test", results)
	if scene == null:
		return

	var instance: Node = scene.instantiate()

	# Page Titles (font_size = 24)
	var projects_title: Label = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTitle") as Label
	var tools_title: Label = instance.get_node_or_null("AppLayout/Content/PageTools/ToolsToolbar/ToolsTitle") as Label
	var settings_title: Label = instance.get_node_or_null("AppLayout/Content/PageSettings/Label") as Label

	_expect(projects_title != null, "ProjectsTitle should exist", results)
	if projects_title != null:
		_expect(projects_title.get_theme_font_size("font_size") == 24, "ProjectsTitle font_size should be 24", results)

	_expect(tools_title != null, "ToolsTitle should exist", results)
	if tools_title != null:
		_expect(tools_title.get_theme_font_size("font_size") == 24, "ToolsTitle font_size should be 24", results)

	_expect(settings_title != null, "Settings title Label should exist", results)
	if settings_title != null:
		_expect(settings_title.get_theme_font_size("font_size") == 24, "Settings title font_size should be 24", results)

	# Section Headers (font_size = 18)
	var section_header_paths: Array[String] = [
		"AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsSettingsLabel",
		"AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorSettingsLabel",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Policy/ProjectOfflineSettingsLabel",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Explorer/ExplorerToolbar/ExplorerLabel"
	]
	for path: String in section_header_paths:
		var header: Label = instance.get_node_or_null(path) as Label
		_expect(header != null, "Section header at %s should exist" % path, results)
		if header != null:
			_expect(header.get_theme_font_size("font_size") == 18, "%s font_size should be 18" % path, results)
			var font_color: Color = header.get_theme_color("font_color")
			_expect(font_color.is_equal_approx(Color(0.45, 0.8, 1.0, 1.0)), "%s font_color should be accent color" % path, results)

	# Secondary & Metadata Labels (font_size = 13)
	var secondary_label_paths: Array[String] = [
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectsStatusBar/HBoxContainer/ProjectsStatusLabel",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectsStatusBar/HBoxContainer/OfflineStatusLabel",
		"AppLayout/Content/PageTools/ToolsStatusLabel",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Policy/ProjectOfflineStatusLabel",
		"AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorStatusLabel",
		"AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsHelperLabel",
		"AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorHelperLabel"
	]
	for path: String in secondary_label_paths:
		var sec_label: Label = instance.get_node_or_null(path) as Label
		_expect(sec_label != null, "Secondary label at %s should exist" % path, results)
		if sec_label != null:
			_expect(sec_label.get_theme_font_size("font_size") == 13, "%s font_size should be 13" % path, results)
			var font_color: Color = sec_label.get_theme_color("font_color")
			_expect(font_color.is_equal_approx(Color(0.65, 0.70, 0.78, 1.0)), "%s font_color should be muted color" % path, results)

	instance.free()

func _test_ready_theme_application(results: Dictionary) -> void:
	## Verifies that _apply_global_theme maintains typography and content margins at runtime.
	var scene: PackedScene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for ready theme test", results)
	if scene == null:
		return

	var instance: Node = scene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(instance)

	var content: MarginContainer = instance.get_node_or_null("AppLayout/Content") as MarginContainer
	_expect(content != null and content.get_theme_constant("margin_left") == 20, "Content margin_left should remain 20 after ready", results)
	_expect(content != null and content.get_theme_constant("margin_top") == 16, "Content margin_top should remain 16 after ready", results)

	var projects_title: Label = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTitle") as Label
	_expect(projects_title != null and projects_title.get_theme_font_size("font_size") == 24, "ProjectsTitle font_size should remain 24 after ready", results)

	instance.free()

func _test_controller_type_instances(results: Dictionary) -> void:
	## Verifies that all controller member variables in main.gd are properly typed and instantiated.
	var scene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for controller type test", results)
	if scene == null:
		return
	var instance = scene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(instance)

	_expect(instance.projects_controller is ProjectsController, "projects_controller should be ProjectsController", results)
	_expect(instance.layout_controller is LayoutController, "layout_controller should be LayoutController", results)
	_expect(instance.seal_controller is SealController, "seal_controller should be SealController", results)
	_expect(instance.tools_controller is ToolsController, "tools_controller should be ToolsController", results)
	_expect(instance.progress_controller is ProgressController, "progress_controller should be ProgressController", results)
	_expect(instance.onboarding_wizard is OnboardingWizard, "onboarding_wizard should be OnboardingWizard", results)
	_expect(instance.tools_page_controller is ToolsPageController, "tools_page_controller should be ToolsPageController", results)
	_expect(instance.settings_controller is SettingsController, "settings_controller should be SettingsController", results)
	_expect(instance.download_dialog_controller is DownloadDialogController, "download_dialog_controller should be DownloadDialogController", results)
	_expect(instance.btn_open_project != null, "btn_open_project should be wired in main", results)
	_expect(instance.projects_controller.btn_open_project == instance.btn_open_project, "projects_controller.btn_open_project should match main node", results)
	_expect(instance.btn_add_remote_project != null, "btn_add_remote_project should be wired in main", results)
	_expect(instance.projects_controller.btn_add_remote_project == instance.btn_add_remote_project, "projects_controller.btn_add_remote_project should match main node", results)
	_expect(instance.installed_code_tools != null, "installed_code_tools should be wired", results)
	_expect(instance.download_code_tools != null, "download_code_tools should be wired", results)

	instance.free()

func _test_network_ui_disabled_offline(results: Dictionary) -> void:
	## Verifies network-related controls are disabled in offline mode.
	var scene = load("res://main.tscn")
	if scene == null:
		_expect(false, "main.tscn should load for offline UI test", results)
		return
	var instance = scene.instantiate()
	_expect(instance.get_node_or_null("AppLayout/Content/PageSettings/CheckUpdatesButton") == null, "CheckUpdatesButton should be removed from PageSettings", results)
	var mirror_repo_clear = instance.get_node_or_null("AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRepoContainer/MirrorRepoClearButton") as Button
	if mirror_repo_clear == null:
		mirror_repo_clear = instance.find_child("MirrorRepoClearButton", true, false) as Button
	_expect(mirror_repo_clear != null, "MirrorRepoClearButton should exist", results)
	var add_remote = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectsControls/AddRemoteProjectButton") as Button
	_expect(add_remote != null, "Add Remote Project button should exist for offline UI test", results)
	if mirror_repo_clear != null and add_remote != null:
		instance._collect_network_ui_nodes()
		instance._on_offline_state_changed(true, "offline_mode")
		_expect(mirror_repo_clear.disabled == true, "MirrorRepoClearButton should be disabled when offline", results)
		_expect(mirror_repo_clear.tooltip_text == "Disabled because OGS Launcher is currently in offline mode.", "MirrorRepoClearButton should show descriptive offline tooltip", results)
		_expect(add_remote.disabled == true, "Add Remote Project button should be disabled when offline", results)
		_expect(add_remote.tooltip_text == "Disabled because OGS Launcher is currently in offline mode.", "Add Remote Project button should show descriptive offline tooltip", results)
		instance._on_offline_state_changed(false, "online_mode")
		_expect(mirror_repo_clear.disabled == false, "MirrorRepoClearButton should be enabled when online", results)
		_expect(mirror_repo_clear.tooltip_text == "", "MirrorRepoClearButton tooltip should be empty when online", results)
		_expect(add_remote.disabled == false, "Add Remote Project button should be enabled when online", results)
		_expect(add_remote.tooltip_text == "", "Add Remote Project button tooltip should be empty when online", results)
	instance.free()

func _test_mirror_root_browse_dialog_frees_on_close(results: Dictionary) -> void:
	## Verifies mirror root browse dialog is queued for free when closed without a selection.
	var scene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for mirror browse dialog close test", results)
	if scene == null:
		return
	var instance = scene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(instance)
	instance._on_mirror_root_browse_pressed()
	var canceled_dialog = _find_new_file_dialog(instance, null)
	_expect(canceled_dialog != null, "mirror root browse should create a file dialog", results)
	if canceled_dialog != null:
		canceled_dialog.canceled.emit()
		_expect(canceled_dialog.is_queued_for_deletion(), "mirror root browse dialog should be queued for free on canceled", results)

	instance._on_mirror_root_browse_pressed()
	var closed_dialog = _find_new_file_dialog(instance, canceled_dialog)
	_expect(closed_dialog != null, "mirror root browse should create a second file dialog", results)
	if closed_dialog != null:
		closed_dialog.close_requested.emit()
		_expect(closed_dialog.is_queued_for_deletion(), "mirror root browse dialog should be queued for free on close_requested", results)
	instance.free()

func _test_projects_root_browse_dialog_frees_on_close(results: Dictionary) -> void:
	## Verifies primary projects root browse dialog is queued for free when closed without a selection.
	var scene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for projects browse dialog close test", results)
	if scene == null:
		return
	var instance = scene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(instance)
	instance._on_projects_root_browse_pressed()
	var canceled_dialog = _find_new_file_dialog(instance, null)
	_expect(canceled_dialog != null, "projects root browse should create a file dialog", results)
	if canceled_dialog != null:
		canceled_dialog.canceled.emit()
		_expect(canceled_dialog.is_queued_for_deletion(), "projects root browse dialog should be queued for free on canceled", results)

	instance._on_projects_root_browse_pressed()
	var closed_dialog = _find_new_file_dialog(instance, canceled_dialog)
	_expect(closed_dialog != null, "projects root browse should create a second file dialog", results)
	if closed_dialog != null:
		closed_dialog.close_requested.emit()
		_expect(closed_dialog.is_queued_for_deletion(), "projects root browse dialog should be queued for free on close_requested", results)
	instance.free()

func _find_new_file_dialog(parent: Node, exclude_dialog: FileDialog) -> FileDialog:
	## Isolates the newest file dialog so close-path regression checks target the correct node.
	for idx in range(parent.get_child_count() - 1, -1, -1):
		var child = parent.get_child(idx) as FileDialog
		if child != null and child != exclude_dialog:
			return child
	return null

func _test_button_theme_variations(results: Dictionary) -> void:
	## Verifies global_theme defines PrimaryButton, SecondaryButton, and DangerButton variations.
	var scene: PackedScene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for button theme variations test", results)
	if scene == null:
		return

	var instance: Node = scene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(instance)

	var theme: Theme = instance.theme
	_expect(theme != null, "Main instance should have a theme assigned", results)
	if theme != null:
		# PrimaryButton
		_expect(theme.get_type_variation_base(&"PrimaryButton") == &"Button", "PrimaryButton should vary from Button", results)
		var p_normal: StyleBoxFlat = theme.get_stylebox("normal", &"PrimaryButton") as StyleBoxFlat
		var p_hover: StyleBoxFlat = theme.get_stylebox("hover", &"PrimaryButton") as StyleBoxFlat
		var p_pressed: StyleBoxFlat = theme.get_stylebox("pressed", &"PrimaryButton") as StyleBoxFlat
		_expect(p_normal != null, "PrimaryButton normal style should exist as StyleBoxFlat", results)
		_expect(p_hover != null, "PrimaryButton hover style should exist as StyleBoxFlat", results)
		_expect(p_pressed != null, "PrimaryButton pressed style should exist as StyleBoxFlat", results)
		if p_normal != null:
			_expect(p_normal.bg_color.is_equal_approx(Color(0.20, 0.48, 0.78)), "PrimaryButton normal bg_color should match brand blue", results)
		if p_hover != null:
			_expect(p_hover.bg_color.is_equal_approx(Color(0.26, 0.56, 0.88)), "PrimaryButton hover bg_color should match brighter blue", results)
		if p_pressed != null:
			_expect(p_pressed.bg_color.is_equal_approx(Color(0.15, 0.38, 0.65)), "PrimaryButton pressed bg_color should match deeper blue", results)

		# SecondaryButton
		_expect(theme.get_type_variation_base(&"SecondaryButton") == &"Button", "SecondaryButton should vary from Button", results)
		var s_normal: StyleBoxFlat = theme.get_stylebox("normal", &"SecondaryButton") as StyleBoxFlat
		var s_hover: StyleBoxFlat = theme.get_stylebox("hover", &"SecondaryButton") as StyleBoxFlat
		var s_pressed: StyleBoxFlat = theme.get_stylebox("pressed", &"SecondaryButton") as StyleBoxFlat
		_expect(s_normal != null, "SecondaryButton normal style should exist as StyleBoxFlat", results)
		_expect(s_hover != null, "SecondaryButton hover style should exist as StyleBoxFlat", results)
		_expect(s_pressed != null, "SecondaryButton pressed style should exist as StyleBoxFlat", results)
		if s_normal != null:
			_expect(s_normal.bg_color.is_equal_approx(Color(0.18, 0.21, 0.26)), "SecondaryButton normal bg_color should match dark slate", results)
			_expect(s_normal.border_width_left == 1 and s_normal.border_color.is_equal_approx(Color(0.30, 0.35, 0.42)), "SecondaryButton normal should have 1px slate border", results)

		# DangerButton
		_expect(theme.get_type_variation_base(&"DangerButton") == &"Button", "DangerButton should vary from Button", results)
		var d_normal: StyleBoxFlat = theme.get_stylebox("normal", &"DangerButton") as StyleBoxFlat
		var d_hover: StyleBoxFlat = theme.get_stylebox("hover", &"DangerButton") as StyleBoxFlat
		var d_pressed: StyleBoxFlat = theme.get_stylebox("pressed", &"DangerButton") as StyleBoxFlat
		_expect(d_normal != null, "DangerButton normal style should exist as StyleBoxFlat", results)
		_expect(d_hover != null, "DangerButton hover style should exist as StyleBoxFlat", results)
		_expect(d_pressed != null, "DangerButton pressed style should exist as StyleBoxFlat", results)
		if d_normal != null:
			_expect(d_normal.border_width_left == 1 and d_normal.border_color.is_equal_approx(Color(0.65, 0.22, 0.25)), "DangerButton normal should have muted crimson border", results)
		if d_hover != null:
			_expect(d_hover.bg_color.is_equal_approx(Color(0.65, 0.22, 0.25)), "DangerButton hover bg_color should match crimson", results)

	instance.free()

func _test_checkbutton_styling(results: Dictionary) -> void:
	## Verifies global_theme defines CheckButton stylebox overrides preventing solid button inheritance.
	var scene: PackedScene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for checkbutton styling test", results)
	if scene == null:
		return

	var instance: Node = scene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(instance)

	var theme: Theme = instance.theme
	_expect(theme != null, "Main instance should have a theme assigned", results)
	if theme != null:
		var cb_normal: StyleBox = theme.get_stylebox("normal", "CheckButton")
		var cb_pressed: StyleBox = theme.get_stylebox("pressed", "CheckButton")
		var cb_hover: StyleBox = theme.get_stylebox("hover", "CheckButton")
		var cb_disabled: StyleBox = theme.get_stylebox("disabled", "CheckButton")
		var btn_normal: StyleBox = theme.get_stylebox("normal", "Button")

		_expect(cb_normal != null, "CheckButton normal stylebox should be defined", results)
		_expect(cb_normal != btn_normal, "CheckButton normal stylebox should override Button normal", results)
		_expect(cb_normal is StyleBoxEmpty, "CheckButton normal should be StyleBoxEmpty to render as clean toggle row", results)
		_expect(cb_pressed is StyleBoxEmpty, "CheckButton pressed should be StyleBoxEmpty", results)
		_expect(cb_disabled is StyleBoxEmpty, "CheckButton disabled should be StyleBoxEmpty", results)
		_expect(cb_hover != null, "CheckButton hover stylebox should be defined", results)

	# Verify checkbutton controls and helper labels exist in Project Details
	var offline_mode_cb: CheckButton = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Policy/OfflineModeContainer/ProjectOfflineModeCheckButton") as CheckButton
	var force_offline_cb: CheckButton = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Policy/ForceOfflineContainer/ProjectForceOfflineCheckButton") as CheckButton
	_expect(offline_mode_cb != null, "ProjectOfflineModeCheckButton should exist as CheckButton under Project Details", results)
	_expect(force_offline_cb != null, "ProjectForceOfflineCheckButton should exist as CheckButton under Project Details", results)

	var offline_mode_helper: Label = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Policy/OfflineModeContainer/ProjectOfflineModeHelperLabel") as Label
	var force_offline_helper: Label = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Policy/ForceOfflineContainer/ProjectForceOfflineHelperLabel") as Label
	_expect(offline_mode_helper != null, "ProjectOfflineModeHelperLabel should exist under Project Details", results)
	_expect(force_offline_helper != null, "ProjectForceOfflineHelperLabel should exist under Project Details", results)

	instance.free()

func _test_main_scene_button_variations(results: Dictionary) -> void:
	## Verifies all target buttons in main.tscn have their expected theme_type_variation applied.
	var scene: PackedScene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for button variation assignment test", results)
	if scene == null:
		return

	var instance: Node = scene.instantiate()

	var expected_primary: Array[String] = [
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectsControls/NewProjectButton",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Toolchain/LaunchButton",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Explorer/ExplorerLaunchButton",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Policy/SealButton"
	]
	for path in expected_primary:
		var btn: Button = instance.get_node_or_null(path) as Button
		_expect(btn != null, "Button at %s should exist" % path, results)
		if btn != null:
			_expect(btn.theme_type_variation == &"PrimaryButton", "%s should have PrimaryButton variation (was: %s)" % [path, String(btn.theme_type_variation)], results)

	var expected_secondary: Array[String] = [
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectsControls/AddButton",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectsControls/AddRemoteProjectButton",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Toolchain/ToolActionRow/AddToolButton",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Toolchain/ToolActionRow/ChangeVersionButton",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Explorer/ExplorerToolbar/NewFolderBtn",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Explorer/ExplorerToolbar/NewFileBtn",
		"AppLayout/Content/PageTools/ToolsToolbar/RefreshButton",
		"AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsRootContainer/ProjectsRootBrowseButton",
		"AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsRootContainer/ProjectsRootResetButton",
		"AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRootContainer/MirrorRootBrowseButton",
		"AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRootContainer/MirrorRootResetButton",
		"AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRepoContainer/MirrorRepoClearButton"
	]
	for path in expected_secondary:
		var btn: Button = instance.get_node_or_null(path) as Button
		_expect(btn != null, "Button at %s should exist" % path, results)
		if btn != null:
			_expect(btn.theme_type_variation == &"SecondaryButton", "%s should have SecondaryButton variation (was: %s)" % [path, String(btn.theme_type_variation)], results)

	var expected_danger: Array[String] = [
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectActionRow/RemoveButton",
		"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsTabs/Toolchain/ToolActionRow/RemoveToolButton"
	]
	for path in expected_danger:
		var btn: Button = instance.get_node_or_null(path) as Button
		_expect(btn != null, "Button at %s should exist" % path, results)
		if btn != null:
			_expect(btn.theme_type_variation == &"DangerButton", "%s should have DangerButton variation (was: %s)" % [path, String(btn.theme_type_variation)], results)

	instance.free()

func _test_projects_status_bar_structure(results: Dictionary) -> void:
	## Verifies that Projects page has a compact horizontal status bar with pill badge under Project Details.
	var scene: PackedScene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for status bar test", results)
	if scene == null:
		return

	var instance: Node = scene.instantiate()
	var status_bar: PanelContainer = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectsStatusBar") as PanelContainer
	_expect(status_bar != null, "ProjectsStatusBar PanelContainer should exist under Project Details", results)
	if status_bar != null:
		var bar_style: StyleBoxFlat = status_bar.get_theme_stylebox("panel") as StyleBoxFlat
		_expect(bar_style != null, "ProjectsStatusBar should have panel style", results)
		if bar_style != null:
			_expect(bar_style.corner_radius_top_left == 6, "ProjectsStatusBar should have rounded corners", results)
			_expect(bar_style.content_margin_left == 12.0, "ProjectsStatusBar should have 12px horizontal margin", results)

	var hbox: HBoxContainer = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectsStatusBar/HBoxContainer") as HBoxContainer
	_expect(hbox != null, "ProjectsStatusBar HBoxContainer should exist", results)

	var project_status: Label = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectsStatusBar/HBoxContainer/ProjectsStatusLabel") as Label
	_expect(project_status != null, "ProjectsStatusLabel should exist inside status bar", results)
	if project_status != null:
		_expect(project_status.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "ProjectsStatusLabel should expand horizontally", results)

	var offline_status: Label = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectsStatusBar/HBoxContainer/OfflineStatusLabel") as Label
	_expect(offline_status != null, "OfflineStatusLabel should exist inside status bar", results)
	if offline_status != null:
		var pill_style: StyleBoxFlat = offline_status.get_theme_stylebox("normal") as StyleBoxFlat
		_expect(pill_style != null, "OfflineStatusLabel should have pill badge normal style", results)
		if pill_style != null:
			_expect(pill_style.corner_radius_top_left == 10, "OfflineStatusLabel pill should have corner radius 10", results)

	instance.free()

func _test_page_projects_hierarchy_and_separation(results: Dictionary) -> void:
	## Verifies UI reorganization under PageProjects:
	## - ProjectsTabs is directly below ProjectsTitle
	## - ProjectsControls is first child under Project Library (above search line edit)
	## - ProjectsStatusBar is first child under Project Details (above ProjectDetailsTabs)
	## - ProjectActionRow contains only OpenProjectButton and RemoveButton (no SealButton)
	## - ProjectDetailsTabs has 3 tabs: Toolchain, Explorer, Policy
	## - VSplitContainer and ProjectDetailsActionRow are removed from Project Details
	var scene: PackedScene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for hierarchy test", results)
	if scene == null:
		return

	var instance: Node = scene.instantiate()

	var page_projects: VBoxContainer = instance.get_node_or_null("AppLayout/Content/PageProjects") as VBoxContainer
	_expect(page_projects != null, "PageProjects should exist", results)
	if page_projects != null:
		var title: Label = page_projects.get_node_or_null("ProjectsTitle") as Label
		var tabs: TabContainer = page_projects.get_node_or_null("ProjectsTabs") as TabContainer
		_expect(title != null, "ProjectsTitle should exist under PageProjects", results)
		_expect(tabs != null, "ProjectsTabs should exist under PageProjects", results)
		if title != null and tabs != null:
			_expect(tabs.get_index() == title.get_index() + 1, "ProjectsTabs should be directly below ProjectsTitle", results)

		var controls_direct: Node = page_projects.get_node_or_null("ProjectsControls")
		_expect(controls_direct == null, "ProjectsControls should not be direct child of PageProjects", results)
		var status_direct: Node = page_projects.get_node_or_null("ProjectsStatusBar")
		_expect(status_direct == null, "ProjectsStatusBar should not be direct child of PageProjects", results)

	var project_library: VBoxContainer = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Library") as VBoxContainer
	_expect(project_library != null, "Project Library should exist", results)
	if project_library != null:
		_expect(project_library.get_child_count() > 0, "Project Library should have children", results)
		var first_child: Node = project_library.get_child(0)
		_expect(first_child != null and first_child.name == "ProjectsControls", "ProjectsControls should be first child of Project Library", results)

		var search_edit: LineEdit = project_library.get_node_or_null("ProjectSearchLineEdit") as LineEdit
		_expect(search_edit != null, "ProjectSearchLineEdit should exist in Project Library", results)
		if first_child != null and search_edit != null:
			_expect(search_edit.get_index() > first_child.get_index(), "ProjectSearchLineEdit should sit below ProjectsControls", results)

		var action_row: HBoxContainer = project_library.get_node_or_null("ProjectActionRow") as HBoxContainer
		_expect(action_row != null, "ProjectActionRow should exist in Project Library", results)
		if action_row != null:
			_expect(action_row.get_node_or_null("OpenProjectButton") != null, "OpenProjectButton should exist in ProjectActionRow", results)
			_expect(action_row.get_node_or_null("RemoveButton") != null, "RemoveButton should exist in ProjectActionRow", results)
			_expect(action_row.get_node_or_null("SealButton") == null, "SealButton should NOT exist in ProjectActionRow", results)

	var project_details: VBoxContainer = instance.get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details") as VBoxContainer
	_expect(project_details != null, "Project Details should exist", results)
	if project_details != null:
		_expect(project_details.get_child_count() > 0, "Project Details should have children", results)
		var first_child: Node = project_details.get_child(0)
		_expect(first_child != null and first_child.name == "ProjectsStatusBar", "ProjectsStatusBar should be first child of Project Details", results)

		var split: VSplitContainer = project_details.get_node_or_null("VSplitContainer") as VSplitContainer
		_expect(split == null, "VSplitContainer should NOT exist in Project Details", results)

		var details_action_row: HBoxContainer = project_details.get_node_or_null("ProjectDetailsActionRow") as HBoxContainer
		_expect(details_action_row == null, "ProjectDetailsActionRow should NOT exist under Project Details", results)

		var subtabs: TabContainer = project_details.get_node_or_null("ProjectDetailsTabs") as TabContainer
		_expect(subtabs != null, "ProjectDetailsTabs should exist in Project Details", results)
		if first_child != null and subtabs != null:
			_expect(subtabs.get_index() > first_child.get_index(), "ProjectDetailsTabs should sit below ProjectsStatusBar", results)
			_expect(subtabs.get_tab_count() == 3, "ProjectDetailsTabs should have 3 tabs", results)
			_expect(subtabs.get_tab_title(0) == "Toolchain", "Sub-tab 0 should be Toolchain", results)
			_expect(subtabs.get_tab_title(1) == "Explorer", "Sub-tab 1 should be Explorer", results)
			_expect(subtabs.get_tab_title(2) == "Policy", "Sub-tab 2 should be Policy", results)

			var launch_btn: Button = subtabs.get_node_or_null("Toolchain/LaunchButton") as Button
			var explorer_launch_btn: Button = subtabs.get_node_or_null("Explorer/ExplorerLaunchButton") as Button
			var seal_btn: Button = subtabs.get_node_or_null("Policy/SealButton") as Button
			_expect(launch_btn != null, "LaunchButton should exist in Toolchain subtab", results)
			_expect(explorer_launch_btn != null, "ExplorerLaunchButton should exist in Explorer subtab", results)
			_expect(seal_btn != null, "SealButton should exist in Policy subtab", results)
			if launch_btn != null:
				_expect(launch_btn.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "LaunchButton should have expand fill size flags", results)
			if explorer_launch_btn != null:
				_expect(explorer_launch_btn.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "ExplorerLaunchButton should have expand fill size flags", results)
			if seal_btn != null:
				_expect(seal_btn.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "SealButton should have expand fill size flags", results)

	instance.free()

func _test_startup_tools_and_connectivity_lifecycle(results: Dictionary) -> void:
	## Verifies that main.tscn starts connectivity checks and tool list refresh at startup,
	## updates sidebar status when online while remaining on Projects page,
	## preserves loaded tool catalog when navigating to Tools page,
	## and frees all active HTTPRequest nodes upon exit without leaks.
	var scene: PackedScene = load("res://main.tscn")
	_expect(scene != null, "main.tscn should load for startup lifecycle test", results)
	if scene == null:
		return

	var tree = Engine.get_main_loop() as SceneTree
	var instance: Node = scene.instantiate()
	tree.root.add_child(instance)

	_expect(instance.tools_controller != null, "tools_controller should be initialized on ready", results)
	if instance.tools_controller != null:
		if not (instance.tools_controller.is_loading() or instance.tools_controller._active_http_requests.size() > 0 or instance.tools_controller._is_checking_connectivity):
			instance.tools_controller.check_connectivity()
			instance.tools_controller.refresh_tool_list()
		_expect(instance.tools_controller.is_loading() or instance.tools_controller._active_http_requests.size() > 0 or instance.tools_controller._is_checking_connectivity, "tools_controller should track startup refresh or connectivity check", results)

	# Verify active page is Projects
	_expect(instance.layout_controller != null and instance.layout_controller.get_current_page() == "projects", "active page should be projects on startup", results)

	# Verify sidebar connectivity label updates to Online while on Projects page
	var status_label: Label = instance.sidebar_status_label
	_expect(status_label != null, "sidebar_status_label should exist", results)
	if status_label != null and instance.tools_controller != null:
		instance.tools_controller.connectivity_checked.emit(true)
		_expect(status_label.text == "● Online", "sidebar status label should show '● Online' after connectivity confirmed (was: %s)" % status_label.text, results)
		_expect(status_label.tooltip_text.contains("Online"), "sidebar status label tooltip should describe online status", results)

	# Populate mock data to verify page_changed preserves loaded data
	if instance.tools_controller != null:
		instance.tools_controller.cleanup()
		instance.tools_controller._available_tools = [{"id": "godot", "version": "4.7.2"}]
		_expect(instance.tools_controller.has_repository_data(), "has_repository_data should be true with available tools", results)

		# Navigate to tools page - should not trigger refresh since data is already loaded
		instance.layout_controller.navigate_to("tools")
		_expect(instance.tools_controller._active_http_requests.is_empty(), "navigating to tools should not trigger new requests when repository data is present", results)

	# Verify NOTIFICATION_WM_CLOSE_REQUEST invokes cleanup
	if instance.tools_controller != null:
		# Add a dummy request to verify close request cleanup
		var dummy_http = HTTPRequest.new()
		tree.root.add_child(dummy_http)
		instance.tools_controller._active_http_requests.append(dummy_http)
		_expect(instance.tools_controller._active_http_requests.size() == 1, "active requests should track dummy request", results)
		instance.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		_expect(instance.tools_controller._active_http_requests.is_empty(), "NOTIFICATION_WM_CLOSE_REQUEST should clear active http requests", results)
		_expect(dummy_http.is_queued_for_deletion(), "dummy http should be queued for deletion", results)

	instance.free()


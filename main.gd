extends Control
const OgsLogger = preload("res://scripts/logging/logger.gd")

const DEFAULT_REMOTE_REPO_URL := "https://raw.githubusercontent.com/OpenGameStack-Launcher/ogs-frozen-stacks/main/repository.json"
const LayoutControllerScript = preload("res://scripts/launcher/layout_controller.gd")
const ProjectsControllerScript = preload("res://scripts/projects/projects_controller.gd")
const SealControllerScript = preload("res://scripts/launcher/seal_controller.gd")
const ToolsControllerScript = preload("res://scripts/tools/tools_controller.gd")
const ProgressControllerScript = preload("res://scripts/tools/progress_controller.gd")
const OnboardingWizardScript = preload("res://scripts/onboarding/onboarding_wizard.gd")
const ToolsPageControllerScript = preload("res://scripts/tools/tools_page_controller.gd")
const SettingsControllerScript = preload("res://scripts/launcher/settings_controller.gd")
const DownloadDialogControllerScript = preload("res://scripts/tools/download_dialog_controller.gd")

# -- PRELOAD REFERENCES --
@onready var page_projects = $AppLayout/Content/PageProjects
@onready var page_tools = $AppLayout/Content/PageTools
@onready var page_settings = $AppLayout/Content/PageSettings

@onready var btn_projects = $AppLayout/Sidebar/VBoxContainer/BtnProjects
@onready var btn_tools = $AppLayout/Sidebar/VBoxContainer/BtnTools
@onready var btn_settings = $AppLayout/Sidebar/VBoxContainer/BtnSettings

# Tools page UI nodes
@onready var tools_toolbar = $AppLayout/Content/PageTools/ToolsToolbar
@onready var tools_refresh_button = $AppLayout/Content/PageTools/ToolsToolbar/RefreshButton
@onready var tools_status_label = $AppLayout/Content/PageTools/ToolsStatusLabel
@onready var tools_offline_message = $AppLayout/Content/PageTools/OfflineMessage
@onready var tools_tabs = $AppLayout/Content/PageTools/ToolsTabs

# Installed tab containers
@onready var installed_engine_tools = $AppLayout/Content/PageTools/ToolsTabs/Installed/InstalledContent/EngineSection/EngineTools
@onready var installed_2d_tools = $AppLayout/Content/PageTools/ToolsTabs/Installed/InstalledContent/"2DSection"/"2DTools"
@onready var installed_3d_tools = $AppLayout/Content/PageTools/ToolsTabs/Installed/InstalledContent/"3DSection"/"3DTools"
@onready var installed_audio_tools = $AppLayout/Content/PageTools/ToolsTabs/Installed/InstalledContent/AudioSection/AudioTools

# Download tab containers
@onready var download_engine_tools = $AppLayout/Content/PageTools/ToolsTabs/Download/DownloadContent/EngineSection/EngineTools
@onready var download_2d_tools = $AppLayout/Content/PageTools/ToolsTabs/Download/DownloadContent/"2DSection"/"2DTools"
@onready var download_3d_tools = $AppLayout/Content/PageTools/ToolsTabs/Download/DownloadContent/"3DSection"/"3DTools"
@onready var download_audio_tools = $AppLayout/Content/PageTools/ToolsTabs/Download/DownloadContent/AudioSection/AudioTools

@onready var btn_add_project = $AppLayout/Content/PageProjects/ProjectsControls/AddButton
@onready var btn_new_project = $AppLayout/Content/PageProjects/ProjectsControls/NewProjectButton
@onready var projects_tabs = $AppLayout/Content/PageProjects/ProjectsTabs
@onready var projects_list = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectsList"
@onready var lbl_project_status = $AppLayout/Content/PageProjects/ProjectsStatusLabel
@onready var lbl_offline_status = $AppLayout/Content/PageProjects/OfflineStatusLabel
@onready var project_tools_list = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectToolsList"
@onready var lbl_tools_list_title = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ExplorerToolbar/ExplorerLabel"
@onready var project_explorer_tree = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectExplorerTree"
@onready var new_folder_btn = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ExplorerToolbar/NewFolderBtn"
@onready var new_file_btn = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ExplorerToolbar/NewFileBtn"
@onready var new_file_dialog = $NewFileDialog
@onready var new_file_name_line_edit = $NewFileDialog/VBoxContainer/FileNameLineEdit
@onready var btn_add_tool = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ToolActionRow/AddToolButton"
@onready var btn_remove_tool = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ToolActionRow/RemoveToolButton"
@onready var btn_change_version = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ToolActionRow/ChangeVersionButton"
@onready var btn_launch_tool = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/LaunchButton"
@onready var btn_remove_project = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectActionRow/RemoveButton"
@onready var btn_seal_for_delivery = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectActionRow/SealButton"
@onready var project_dir_dialog = $ProjectDirDialog
@onready var remove_project_dialog = $RemoveProjectDialog
@onready var remove_tool_dialog = $RemoveToolDialog
@onready var remove_tool_confirmation_label = $RemoveToolDialog/VBoxContainer/ConfirmationLabel
@onready var remove_tool_status_label = $RemoveToolDialog/VBoxContainer/StatusLabel
@onready var remove_tool_progress_bar = $RemoveToolDialog/VBoxContainer/ProgressBar
@onready var new_project_dialog = $NewProjectDialog
@onready var new_project_name_line_edit = $NewProjectDialog/VBoxContainer/ProjectNameLineEdit
@onready var add_tool_dialog = $AddToolDialog
@onready var add_tool_option_list = $AddToolDialog/VBoxContainer/ToolOptionList

# Onboarding dialog
@onready var onboarding_dialog = $OnboardingWizardDialog

# Seal dialog nodes
@onready var seal_dialog = $SealDialog
@onready var seal_status_label = $SealDialog/VBoxContainer/StatusLabel
@onready var seal_output_label = $SealDialog/VBoxContainer/OutputLabel
@onready var seal_open_folder_button = $SealDialog/VBoxContainer/OpenFolderButton

# Settings nodes
@onready var mirror_root_path = $AppLayout/Content/PageSettings/MirrorRootContainer/MirrorRootPath
@onready var mirror_root_browse_button = $AppLayout/Content/PageSettings/MirrorRootContainer/MirrorRootBrowseButton
@onready var mirror_root_reset_button = $AppLayout/Content/PageSettings/MirrorRootContainer/MirrorRootResetButton
@onready var mirror_repo_path = $AppLayout/Content/PageSettings/MirrorRepoContainer/MirrorRepoPath
@onready var mirror_repo_clear_button = $AppLayout/Content/PageSettings/MirrorRepoContainer/MirrorRepoClearButton
@onready var mirror_status_label = $AppLayout/Content/PageSettings/MirrorStatusLabel
@onready var project_offline_status_label = $AppLayout/Content/PageSettings/ProjectOfflineStatusLabel
@onready var project_offline_mode_check_button = $AppLayout/Content/PageSettings/ProjectOfflineModeCheckButton
@onready var project_force_offline_check_button = $AppLayout/Content/PageSettings/ProjectForceOfflineCheckButton

var network_ui_nodes: Array = []

var projects_controller
var layout_controller
var seal_controller
var tools_controller
var progress_controller
var onboarding_wizard
var tools_page_controller
var settings_controller
var download_dialog_controller

func _resolve_ogs_root_path() -> String:
	var local_app_data = OS.get_environment("LOCALAPPDATA")
	if not local_app_data.is_empty():
		return local_app_data.path_join("OGS")
	return OS.get_user_data_dir().path_join("OGS")

func _apply_global_theme() -> void:
	var global_theme = Theme.new()
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.25, 0.3, 0.35)
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_left = 6
	normal_style.corner_radius_bottom_right = 6
	normal_style.content_margin_left = 12
	normal_style.content_margin_right = 12
	normal_style.content_margin_top = 8
	normal_style.content_margin_bottom = 8
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.32, 0.38, 0.45)
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.18, 0.22, 0.26)
	
	var disabled_style = normal_style.duplicate()
	disabled_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	
	global_theme.set_stylebox("normal", "Button", normal_style)
	global_theme.set_stylebox("hover", "Button", hover_style)
	global_theme.set_stylebox("pressed", "Button", pressed_style)
	global_theme.set_stylebox("disabled", "Button", disabled_style)
	
	var tree_panel = StyleBoxFlat.new()
	tree_panel.bg_color = Color(0.16, 0.16, 0.16, 1)
	tree_panel.border_width_bottom = 1
	tree_panel.border_width_top = 1
	tree_panel.border_width_left = 1
	tree_panel.border_width_right = 1
	tree_panel.border_color = Color(0.25, 0.25, 0.25, 1)
	tree_panel.corner_radius_top_left = 4
	tree_panel.corner_radius_top_right = 4
	tree_panel.corner_radius_bottom_left = 4
	tree_panel.corner_radius_bottom_right = 4
	project_explorer_tree.add_theme_stylebox_override("panel", tree_panel)
	project_tools_list.add_theme_stylebox_override("panel", tree_panel)
	global_theme.set_stylebox("panel", "Tree", tree_panel)
	
	self.theme = global_theme

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if projects_controller != null and projects_controller.has_meta("project_explorer_instance"):
			projects_controller.get_meta("project_explorer_instance").refresh()

func _ready() -> void:
	_apply_global_theme()
	OgsLogger.enable_console(true)
	OgsLogger.set_level(OgsLogger.Level.DEBUG)
	OgsLogger.info("launcher_started", {"component": "app"})
	
	var ogs_root_path = _resolve_ogs_root_path()
	var library_root_path = ogs_root_path.path_join("Library")
	onboarding_wizard = OnboardingWizardScript.new()
	onboarding_wizard.setup(get_tree(), library_root_path, onboarding_dialog, ogs_root_path)
	onboarding_wizard.wizard_completed.connect(func(success, message):
		if success: OgsLogger.info("wizard_startup_complete", {"component": "onboarding", "message": message})
		else: OgsLogger.warn("wizard_startup_failed", {"component": "onboarding", "message": message})
	)
	
	if onboarding_wizard.should_show_wizard():
		onboarding_wizard.show_wizard()
	
	layout_controller = LayoutControllerScript.new()
	layout_controller.setup(
		btn_projects, btn_tools, btn_settings,
		page_projects, page_tools, page_settings
	)

	projects_controller = ProjectsControllerScript.new()
	settings_controller = SettingsControllerScript.new()
	
	var settings_file_path = OS.get_user_data_dir().path_join("ogs_launcher_settings.json")
	var settings_deps = SettingsControllerScript.UIDeps.new()
	settings_deps.mirror_root_path = mirror_root_path
	settings_deps.mirror_repo_path = mirror_repo_path
	settings_deps.mirror_status_label = mirror_status_label
	settings_deps.project_offline_status_label = project_offline_status_label
	settings_deps.project_offline_mode_check_button = project_offline_mode_check_button
	settings_deps.project_force_offline_check_button = project_force_offline_check_button
	settings_deps.app_node = self
	
	settings_controller.setup(settings_deps, projects_controller, DEFAULT_REMOTE_REPO_URL, settings_file_path)

	tools_controller = ToolsControllerScript.new(get_tree(), settings_controller.get_mirror_repository_url())
	
	progress_controller = ProgressControllerScript.new()
	download_dialog_controller = DownloadDialogControllerScript.new()
	download_dialog_controller.setup(self, tools_controller)

	tools_page_controller = ToolsPageControllerScript.new()
	var tools_page_deps = ToolsPageControllerScript.UIDeps.new()
	tools_page_deps.tools_tabs = tools_tabs
	tools_page_deps.installed_engine_tools = installed_engine_tools
	tools_page_deps.installed_2d_tools = installed_2d_tools
	tools_page_deps.installed_3d_tools = installed_3d_tools
	tools_page_deps.installed_audio_tools = installed_audio_tools
	tools_page_deps.download_engine_tools = download_engine_tools
	tools_page_deps.download_2d_tools = download_2d_tools
	tools_page_deps.download_3d_tools = download_3d_tools
	tools_page_deps.download_audio_tools = download_audio_tools
	tools_page_deps.tools_status_label = tools_status_label
	tools_page_deps.tools_offline_message = tools_offline_message
	tools_page_deps.remove_tool_dialog = remove_tool_dialog
	tools_page_deps.remove_tool_confirmation_label = remove_tool_confirmation_label
	tools_page_deps.remove_tool_status_label = remove_tool_status_label
	tools_page_deps.remove_tool_progress_bar = remove_tool_progress_bar
	
	tools_page_controller.setup(tools_page_deps, tools_controller, progress_controller, projects_controller, download_dialog_controller)

	tools_controller.tool_list_updated.connect(func():
		tools_page_controller.update_connectivity_status(tools_controller.is_online())
		tools_page_controller.populate_tools_ui()
		projects_controller.refresh_project_tools_state()
	)
	tools_controller.tool_list_refresh_failed.connect(func(_err):
		tools_page_controller.update_connectivity_status(tools_controller.is_online())
	)
	tools_controller.tool_install_started.connect(func(tid, ver):
		if progress_controller: progress_controller.set_install_phase(tid, ver)
	)
	tools_controller.tool_install_progress.connect(func(tid, ver, c, t):
		if progress_controller: progress_controller.update_install_progress(tid, ver, c, t)
	)
	tools_controller.tool_download_complete.connect(func(tid, ver, succ, msg):
		download_dialog_controller.hide_dialog()
		if succ:
			if progress_controller: progress_controller.complete_progress(tid, ver)
			tools_page_controller.populate_tools_ui()
			projects_controller.refresh_project_tools_state()
		else:
			if progress_controller: progress_controller.cancel_progress(tid, ver)
			tools_page_controller.show_tool_download_error(tid, ver, msg)
		tools_page_controller.update_connectivity_status(tools_controller.is_online())
		tools_page_controller.update_download_button_states()
	)
	tools_controller.tool_download_progress.connect(func(tid, ver, d, t):
		if progress_controller: progress_controller.update_progress(tid, ver, d, t)
	)
	tools_controller.connectivity_checked.connect(func(is_on): tools_page_controller.update_connectivity_status(is_on))
	tools_refresh_button.pressed.connect(func(): tools_controller.refresh_tool_list())

	var deps = ProjectsControllerScript.UIDeps.new()
	deps.btn_add_project = btn_add_project
	deps.btn_new_project = btn_new_project
	deps.projects_list = projects_list
	deps.lbl_project_status = lbl_project_status
	deps.lbl_offline_status = lbl_offline_status
	deps.lbl_tools_for_project = lbl_tools_list_title
	deps.explorer_tree = project_explorer_tree
	deps.btn_new_folder = new_folder_btn
	deps.btn_new_file = new_file_btn
	deps.new_file_dialog = new_file_dialog
	deps.new_file_name_edit = new_file_name_line_edit
	deps.btn_add_tool = btn_add_tool
	deps.btn_remove_tool = btn_remove_tool
	deps.btn_remove_project = btn_remove_project
	deps.btn_launch_tool = btn_launch_tool
	deps.project_dir_dialog = project_dir_dialog
	deps.remove_project_dialog = remove_project_dialog
	deps.new_project_dialog = new_project_dialog
	deps.new_project_name_line_edit = new_project_name_line_edit
	deps.add_tool_dialog = add_tool_dialog
	deps.add_tool_option_list = add_tool_option_list
	deps.projects_tabs = projects_tabs
	deps.project_tools_list = project_tools_list
	deps.btn_change_version = btn_change_version
	
	projects_controller.setup(deps, tools_controller)
	projects_controller.offline_state_changed.connect(_on_offline_state_changed)
	projects_controller.project_selection_changed.connect(settings_controller.on_project_selection_changed)
	projects_controller.tool_view_requested.connect(func(t, v): tools_page_controller.navigate_to_tool(t, v); layout_controller.navigate_to("tools"))
	projects_controller.environment_incomplete.connect(func(_tools): btn_seal_for_delivery.disabled = true; btn_seal_for_delivery.tooltip_text = "Install missing tools from the Tools page before sealing.")
	projects_controller.environment_ready.connect(func(): btn_seal_for_delivery.disabled = false; btn_seal_for_delivery.tooltip_text = "")
	
	seal_controller = SealControllerScript.new()
	seal_controller.setup(seal_dialog, seal_status_label, seal_output_label, seal_open_folder_button)
	btn_seal_for_delivery.pressed.connect(func(): seal_controller.seal_for_delivery(projects_controller.current_project_dir))

	mirror_root_path.text_changed.connect(settings_controller.on_mirror_root_text_changed)
	mirror_root_browse_button.pressed.connect(settings_controller.on_mirror_root_browse_pressed)
	mirror_root_reset_button.pressed.connect(settings_controller.on_mirror_root_reset_pressed)
	mirror_repo_path.text_changed.connect(settings_controller.on_mirror_repo_text_changed)
	mirror_repo_clear_button.pressed.connect(settings_controller.on_mirror_repo_clear_pressed)
	project_offline_mode_check_button.toggled.connect(settings_controller.on_project_offline_setting_toggled)
	project_force_offline_check_button.toggled.connect(settings_controller.on_project_offline_setting_toggled)
	settings_controller.sync_project_offline_settings(projects_controller.current_project_dir, projects_controller.current_project_config)
	
	layout_controller.page_changed.connect(func(page):
		if page == "tools" and tools_controller:
			tools_controller.check_connectivity()
			if not tools_controller.has_repository_data():
				tools_controller.refresh_tool_list()
	)

	_collect_network_ui_nodes()
	_apply_offline_ui(false)
	btn_seal_for_delivery.disabled = false
	btn_seal_for_delivery.tooltip_text = ""
	
	layout_controller.navigate_to("projects")
	
func _collect_network_ui_nodes() -> void:
	var found: Array = []
	if is_inside_tree():
		found = get_tree().get_nodes_in_group("network_ui")
	var meta_found = _collect_network_ui_nodes_from(self)
	for node in meta_found:
		if not found.has(node):
			found.append(node)
	network_ui_nodes = found

func _collect_network_ui_nodes_from(root: Node) -> Array:
	var found: Array = []
	if root.has_meta("network_ui") and root.get_meta("network_ui") == true:
		found.append(root)
	for child in root.get_children():
		found.append_array(_collect_network_ui_nodes_from(child))
	return found

func _on_offline_state_changed(active: bool, _reason: String) -> void:
	_apply_offline_ui(active)

func _apply_offline_ui(active: bool) -> void:
	for node in network_ui_nodes:
		if node is BaseButton:
			var button := node as BaseButton
			button.disabled = active
			button.tooltip_text = "Disabled in offline mode." if active else ""

func _exit_tree() -> void:
	if layout_controller != null:
		layout_controller.cleanup()

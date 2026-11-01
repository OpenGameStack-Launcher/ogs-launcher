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

@onready var sidebar_panel: PanelContainer = $AppLayout/Sidebar
@onready var sidebar_brand_header: HBoxContainer = $AppLayout/Sidebar/VBoxContainer/BrandHeader
@onready var sidebar_brand_logo: TextureRect = $AppLayout/Sidebar/VBoxContainer/BrandHeader/BrandLogo
@onready var sidebar_brand_title: Label = $AppLayout/Sidebar/VBoxContainer/BrandHeader/BrandTitle
@onready var sidebar_brand_separator: HSeparator = $AppLayout/Sidebar/VBoxContainer/BrandSeparator
@onready var btn_projects: Button = $AppLayout/Sidebar/VBoxContainer/BtnProjects
@onready var btn_tools: Button = $AppLayout/Sidebar/VBoxContainer/BtnTools
@onready var btn_settings: Button = $AppLayout/Sidebar/VBoxContainer/BtnSettings
@onready var sidebar_spacer: Control = $AppLayout/Sidebar/VBoxContainer/SidebarSpacer
@onready var sidebar_footer: VBoxContainer = $AppLayout/Sidebar/VBoxContainer/SidebarFooter
@onready var sidebar_status_label: Label = $AppLayout/Sidebar/VBoxContainer/SidebarFooter/SidebarStatusLabel
@onready var sidebar_version_label: Label = $AppLayout/Sidebar/VBoxContainer/SidebarFooter/SidebarVersionLabel

# Tools page UI nodes
@onready var tools_toolbar = $AppLayout/Content/PageTools/ToolsToolbar
@onready var tools_refresh_button = $AppLayout/Content/PageTools/ToolsToolbar/RefreshButton
@onready var tools_status_label = $AppLayout/Content/PageTools/ToolsStatusLabel
@onready var tools_offline_message = $AppLayout/Content/PageTools/OfflineMessage
@onready var tools_tabs = $AppLayout/Content/PageTools/ToolsTabs
@onready var installed_content = $AppLayout/Content/PageTools/ToolsTabs/Installed/MarginContainer/InstalledContent
@onready var download_content = $AppLayout/Content/PageTools/ToolsTabs/Download/MarginContainer/DownloadContent
@onready var installed_empty_state = $AppLayout/Content/PageTools/ToolsTabs/Installed/MarginContainer/InstalledEmptyState
@onready var browse_available_tools_button = $AppLayout/Content/PageTools/ToolsTabs/Installed/MarginContainer/InstalledEmptyState/BrowseAvailableToolsButton

# Installed tab containers
@onready var installed_engine_tools = $AppLayout/Content/PageTools/ToolsTabs/Installed/MarginContainer/InstalledContent/EngineSection/EngineTools
@onready var installed_2d_tools = $AppLayout/Content/PageTools/ToolsTabs/Installed/MarginContainer/InstalledContent/"2DSection"/"2DTools"
@onready var installed_3d_tools = $AppLayout/Content/PageTools/ToolsTabs/Installed/MarginContainer/InstalledContent/"3DSection"/"3DTools"
@onready var installed_audio_tools = $AppLayout/Content/PageTools/ToolsTabs/Installed/MarginContainer/InstalledContent/AudioSection/AudioTools
@onready var installed_code_tools = $AppLayout/Content/PageTools/ToolsTabs/Installed/MarginContainer/InstalledContent/CodeSection/CodeTools

# Download tab containers
@onready var download_engine_tools = $AppLayout/Content/PageTools/ToolsTabs/Download/MarginContainer/DownloadContent/EngineSection/EngineTools
@onready var download_2d_tools = $AppLayout/Content/PageTools/ToolsTabs/Download/MarginContainer/DownloadContent/"2DSection"/"2DTools"
@onready var download_3d_tools = $AppLayout/Content/PageTools/ToolsTabs/Download/MarginContainer/DownloadContent/"3DSection"/"3DTools"
@onready var download_audio_tools = $AppLayout/Content/PageTools/ToolsTabs/Download/MarginContainer/DownloadContent/AudioSection/AudioTools
@onready var download_code_tools = $AppLayout/Content/PageTools/ToolsTabs/Download/MarginContainer/DownloadContent/CodeSection/CodeTools

@onready var btn_add_project = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectsControls/AddButton"
@onready var btn_add_remote_project = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectsControls/AddRemoteProjectButton"
@onready var btn_new_project = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectsControls/NewProjectButton"
@onready var projects_tabs = $AppLayout/Content/PageProjects/ProjectsTabs
@onready var project_search_line_edit: LineEdit = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectSearchLineEdit"
@onready var projects_list = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectsList"
@onready var empty_library_state: Control = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/EmptyLibraryState"
@onready var empty_title_label: Label = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/EmptyLibraryState/EmptyStateContent/EmptyTitleLabel"
@onready var empty_message_label: Label = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/EmptyLibraryState/EmptyStateContent/EmptyMessageLabel"
@onready var empty_new_project_btn: Button = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/EmptyLibraryState/EmptyStateContent/EmptyActionsContainer/EmptyNewProjectButton"
@onready var empty_add_local_btn: Button = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/EmptyLibraryState/EmptyStateContent/EmptyActionsContainer/EmptyAddLocalButton"
@onready var empty_add_remote_btn: Button = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/EmptyLibraryState/EmptyStateContent/EmptyActionsContainer/EmptyAddRemoteButton"
@onready var empty_clear_filter_btn: Button = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/EmptyLibraryState/EmptyStateContent/EmptyActionsContainer/EmptyClearFilterButton"
@onready var projects_status_bar = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectsStatusBar"
@onready var lbl_project_status = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectsStatusBar/HBoxContainer/ProjectsStatusLabel"
@onready var lbl_offline_status = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectsStatusBar/HBoxContainer/OfflineStatusLabel"
@onready var toolchain_header_label: Label = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/VSplitContainer/ToolchainSection/ToolchainHeaderLabel"
@onready var project_tools_list = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/VSplitContainer/ToolchainSection/ProjectToolsList"
@onready var lbl_tools_list_title = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/VSplitContainer/ExplorerSection/ExplorerToolbar/ExplorerLabel"
@onready var project_explorer_tree = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/VSplitContainer/ExplorerSection/ProjectExplorerTree"
@onready var new_folder_btn = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/VSplitContainer/ExplorerSection/ExplorerToolbar/NewFolderBtn"
@onready var new_file_btn = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/VSplitContainer/ExplorerSection/ExplorerToolbar/NewFileBtn"
@onready var new_file_dialog = $NewFileDialog
@onready var new_file_name_line_edit = $NewFileDialog/VBoxContainer/FileNameLineEdit
@onready var btn_add_tool = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/VSplitContainer/ToolchainSection/ToolActionRow/AddToolButton"
@onready var btn_remove_tool = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/VSplitContainer/ToolchainSection/ToolActionRow/RemoveToolButton"
@onready var btn_change_version = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/VSplitContainer/ToolchainSection/ToolActionRow/ChangeVersionButton"
@onready var btn_launch_tool = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsActionRow/LaunchButton"
@onready var btn_open_project = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectActionRow/OpenProjectButton"
@onready var btn_remove_project = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Library/ProjectActionRow/RemoveButton"
@onready var btn_seal_for_delivery = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectDetailsActionRow/SealButton"
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
@onready var seal_progress_bar = $SealDialog/VBoxContainer/SealProgressBar
@onready var seal_output_label = $SealDialog/VBoxContainer/OutputLabel
@onready var seal_open_folder_button = $SealDialog/VBoxContainer/OpenFolderButton

# Settings nodes
@onready var projects_root_path = ($AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsRootContainer/ProjectsRootPath if has_node("AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsRootContainer/ProjectsRootPath") else find_child("ProjectsRootPath", true, false)) as LineEdit
@onready var projects_root_browse_button = ($AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsRootContainer/ProjectsRootBrowseButton if has_node("AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsRootContainer/ProjectsRootBrowseButton") else find_child("ProjectsRootBrowseButton", true, false)) as Button
@onready var projects_root_reset_button = ($AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsRootContainer/ProjectsRootResetButton if has_node("AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsRootContainer/ProjectsRootResetButton") else find_child("ProjectsRootResetButton", true, false)) as Button
@onready var mirror_root_path = ($AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRootContainer/MirrorRootPath if has_node("AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRootContainer/MirrorRootPath") else find_child("MirrorRootPath", true, false)) as LineEdit
@onready var mirror_root_browse_button = ($AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRootContainer/MirrorRootBrowseButton if has_node("AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRootContainer/MirrorRootBrowseButton") else find_child("MirrorRootBrowseButton", true, false)) as Button
@onready var mirror_root_reset_button = ($AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRootContainer/MirrorRootResetButton if has_node("AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRootContainer/MirrorRootResetButton") else find_child("MirrorRootResetButton", true, false)) as Button
@onready var mirror_repo_path = ($AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRepoContainer/MirrorRepoPath if has_node("AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRepoContainer/MirrorRepoPath") else find_child("MirrorRepoPath", true, false)) as LineEdit
@onready var mirror_repo_clear_button = ($AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRepoContainer/MirrorRepoClearButton if has_node("AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorRepoContainer/MirrorRepoClearButton") else find_child("MirrorRepoClearButton", true, false)) as Button
@onready var mirror_status_label = ($AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorStatusLabel if has_node("AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorStatusLabel") else find_child("MirrorStatusLabel", true, false)) as Label
@onready var project_offline_section = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection"
@onready var project_offline_settings_label = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/ProjectOfflineSettingsLabel"
@onready var project_offline_status_label = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/ProjectOfflineStatusLabel"
@onready var project_offline_mode_check_button = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/OfflineModeContainer/ProjectOfflineModeCheckButton"
@onready var project_offline_mode_helper_label = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/OfflineModeContainer/ProjectOfflineModeHelperLabel"
@onready var project_force_offline_check_button = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/ForceOfflineContainer/ProjectForceOfflineCheckButton"
@onready var project_force_offline_helper_label = $"AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/ForceOfflineContainer/ProjectForceOfflineHelperLabel"

var network_ui_nodes: Array = []

var projects_controller: ProjectsController
var layout_controller: LayoutController
var seal_controller: SealController
var tools_controller: ToolsController
var progress_controller: ProgressController
var onboarding_wizard: OnboardingWizard
var tools_page_controller: ToolsPageController
var settings_controller: SettingsController
var download_dialog_controller: DownloadDialogController

func _resolve_ogs_root_path() -> String:
	var local_app_data = OS.get_environment("LOCALAPPDATA")
	if not local_app_data.is_empty():
		return local_app_data.path_join("OGS")
	return OS.get_user_data_dir().path_join("OGS")

func _apply_global_theme() -> void:
	var global_theme: Theme = Theme.new()
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.25, 0.3, 0.35)
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_left = 6
	normal_style.corner_radius_bottom_right = 6
	normal_style.content_margin_left = 12
	normal_style.content_margin_right = 12
	normal_style.content_margin_top = 8
	normal_style.content_margin_bottom = 8
	
	var hover_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.32, 0.38, 0.45)
	
	var pressed_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.18, 0.22, 0.26)
	
	var disabled_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	
	global_theme.set_stylebox("normal", "Button", normal_style)
	global_theme.set_stylebox("hover", "Button", hover_style)
	global_theme.set_stylebox("pressed", "Button", pressed_style)
	global_theme.set_stylebox("disabled", "Button", disabled_style)

	# PrimaryButton Theme Variation
	global_theme.set_type_variation(&"PrimaryButton", &"Button")
	var primary_normal: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	primary_normal.bg_color = Color(0.20, 0.48, 0.78)

	var primary_hover: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	primary_hover.bg_color = Color(0.26, 0.56, 0.88)

	var primary_pressed: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	primary_pressed.bg_color = Color(0.15, 0.38, 0.65)

	var primary_disabled: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	primary_disabled.bg_color = Color(0.20, 0.30, 0.40, 0.5)

	var primary_focus: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	primary_focus.draw_center = false
	primary_focus.border_width_left = 1
	primary_focus.border_width_top = 1
	primary_focus.border_width_right = 1
	primary_focus.border_width_bottom = 1
	primary_focus.border_color = Color(0.45, 0.80, 1.0, 0.8)

	global_theme.set_stylebox("normal", &"PrimaryButton", primary_normal)
	global_theme.set_stylebox("hover", &"PrimaryButton", primary_hover)
	global_theme.set_stylebox("pressed", &"PrimaryButton", primary_pressed)
	global_theme.set_stylebox("disabled", &"PrimaryButton", primary_disabled)
	global_theme.set_stylebox("focus", &"PrimaryButton", primary_focus)

	# SecondaryButton Theme Variation
	global_theme.set_type_variation(&"SecondaryButton", &"Button")
	var secondary_normal: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	secondary_normal.bg_color = Color(0.18, 0.21, 0.26)
	secondary_normal.border_width_left = 1
	secondary_normal.border_width_top = 1
	secondary_normal.border_width_right = 1
	secondary_normal.border_width_bottom = 1
	secondary_normal.border_color = Color(0.30, 0.35, 0.42)

	var secondary_hover: StyleBoxFlat = secondary_normal.duplicate() as StyleBoxFlat
	secondary_hover.bg_color = Color(0.24, 0.28, 0.35)
	secondary_hover.border_color = Color(0.38, 0.45, 0.54)

	var secondary_pressed: StyleBoxFlat = secondary_normal.duplicate() as StyleBoxFlat
	secondary_pressed.bg_color = Color(0.14, 0.16, 0.20)
	secondary_pressed.border_color = Color(0.30, 0.35, 0.42)

	var secondary_disabled: StyleBoxFlat = secondary_normal.duplicate() as StyleBoxFlat
	secondary_disabled.bg_color = Color(0.15, 0.17, 0.20, 0.5)
	secondary_disabled.border_color = Color(0.25, 0.28, 0.32, 0.5)

	var secondary_focus: StyleBoxFlat = secondary_normal.duplicate() as StyleBoxFlat
	secondary_focus.draw_center = false
	secondary_focus.border_color = Color(0.45, 0.80, 1.0, 0.8)

	global_theme.set_stylebox("normal", &"SecondaryButton", secondary_normal)
	global_theme.set_stylebox("hover", &"SecondaryButton", secondary_hover)
	global_theme.set_stylebox("pressed", &"SecondaryButton", secondary_pressed)
	global_theme.set_stylebox("disabled", &"SecondaryButton", secondary_disabled)
	global_theme.set_stylebox("focus", &"SecondaryButton", secondary_focus)

	# DangerButton Theme Variation
	global_theme.set_type_variation(&"DangerButton", &"Button")
	var danger_normal: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	danger_normal.bg_color = Color(0.18, 0.14, 0.15)
	danger_normal.border_width_left = 1
	danger_normal.border_width_top = 1
	danger_normal.border_width_right = 1
	danger_normal.border_width_bottom = 1
	danger_normal.border_color = Color(0.65, 0.22, 0.25)

	var danger_hover: StyleBoxFlat = danger_normal.duplicate() as StyleBoxFlat
	danger_hover.bg_color = Color(0.65, 0.22, 0.25)
	danger_hover.border_color = Color(0.78, 0.28, 0.32)

	var danger_pressed: StyleBoxFlat = danger_normal.duplicate() as StyleBoxFlat
	danger_pressed.bg_color = Color(0.48, 0.15, 0.18)
	danger_pressed.border_color = Color(0.65, 0.22, 0.25)

	var danger_disabled: StyleBoxFlat = danger_normal.duplicate() as StyleBoxFlat
	danger_disabled.bg_color = Color(0.15, 0.14, 0.14, 0.5)
	danger_disabled.border_color = Color(0.40, 0.20, 0.22, 0.4)

	var danger_focus: StyleBoxFlat = danger_normal.duplicate() as StyleBoxFlat
	danger_focus.draw_center = false
	danger_focus.border_color = Color(0.85, 0.35, 0.38, 0.8)

	global_theme.set_stylebox("normal", &"DangerButton", danger_normal)
	global_theme.set_stylebox("hover", &"DangerButton", danger_hover)
	global_theme.set_stylebox("pressed", &"DangerButton", danger_pressed)
	global_theme.set_stylebox("disabled", &"DangerButton", danger_disabled)
	global_theme.set_stylebox("focus", &"DangerButton", danger_focus)

	# CheckButton Styling
	var check_normal: StyleBoxEmpty = StyleBoxEmpty.new()
	check_normal.content_margin_left = 6.0
	check_normal.content_margin_right = 6.0
	check_normal.content_margin_top = 4.0
	check_normal.content_margin_bottom = 4.0

	var check_hover: StyleBoxFlat = StyleBoxFlat.new()
	check_hover.bg_color = Color(1.0, 1.0, 1.0, 0.04)
	check_hover.corner_radius_top_left = 4
	check_hover.corner_radius_top_right = 4
	check_hover.corner_radius_bottom_left = 4
	check_hover.corner_radius_bottom_right = 4
	check_hover.content_margin_left = 6.0
	check_hover.content_margin_right = 6.0
	check_hover.content_margin_top = 4.0
	check_hover.content_margin_bottom = 4.0

	var check_pressed: StyleBoxEmpty = check_normal.duplicate() as StyleBoxEmpty
	var check_disabled: StyleBoxEmpty = check_normal.duplicate() as StyleBoxEmpty

	var check_focus: StyleBoxFlat = StyleBoxFlat.new()
	check_focus.draw_center = false
	check_focus.border_width_left = 1
	check_focus.border_width_top = 1
	check_focus.border_width_right = 1
	check_focus.border_width_bottom = 1
	check_focus.border_color = Color(0.45, 0.80, 1.0, 0.6)
	check_focus.corner_radius_top_left = 4
	check_focus.corner_radius_top_right = 4
	check_focus.corner_radius_bottom_left = 4
	check_focus.corner_radius_bottom_right = 4
	check_focus.content_margin_left = 6.0
	check_focus.content_margin_right = 6.0
	check_focus.content_margin_top = 4.0
	check_focus.content_margin_bottom = 4.0

	global_theme.set_stylebox("normal", "CheckButton", check_normal)
	global_theme.set_stylebox("hover", "CheckButton", check_hover)
	global_theme.set_stylebox("pressed", "CheckButton", check_pressed)
	global_theme.set_stylebox("hover_pressed", "CheckButton", check_hover)
	global_theme.set_stylebox("disabled", "CheckButton", check_disabled)
	global_theme.set_stylebox("focus", "CheckButton", check_focus)
	
	var tree_panel: StyleBoxFlat = StyleBoxFlat.new()
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
	if project_explorer_tree != null:
		project_explorer_tree.add_theme_stylebox_override("panel", tree_panel)
	if project_tools_list != null:
		project_tools_list.add_theme_stylebox_override("panel", tree_panel)
	global_theme.set_stylebox("panel", "Tree", tree_panel)
	
	var content_margin: MarginContainer = get_node_or_null("AppLayout/Content") as MarginContainer
	if content_margin != null:
		content_margin.add_theme_constant_override("margin_left", 20)
		content_margin.add_theme_constant_override("margin_top", 16)
		content_margin.add_theme_constant_override("margin_right", 20)
		content_margin.add_theme_constant_override("margin_bottom", 16)
	
	const TITLE_FONT_SIZE: int = 24
	const SECTION_FONT_SIZE: int = 18
	const SECONDARY_FONT_SIZE: int = 13
	const SECTION_ACCENT_COLOR: Color = Color(0.45, 0.8, 1.0, 1.0)
	const MUTED_LABEL_COLOR: Color = Color(0.65, 0.70, 0.78, 1.0)
	
	var page_titles: Array[Label] = [
		get_node_or_null("AppLayout/Content/PageProjects/ProjectsTitle") as Label,
		get_node_or_null("AppLayout/Content/PageTools/ToolsToolbar/ToolsTitle") as Label,
		get_node_or_null("AppLayout/Content/PageSettings/Label") as Label
	]
	for title: Label in page_titles:
		if title != null:
			title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	
	var section_headers: Array[Label] = [
		(get_node_or_null("AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsSettingsLabel") as Label if get_node_or_null("AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsSettingsLabel") != null else find_child("ProjectsSettingsLabel", true, false) as Label),
		(get_node_or_null("AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorSettingsLabel") as Label if get_node_or_null("AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorSettingsLabel") != null else find_child("MirrorSettingsLabel", true, false) as Label),
		(get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/ProjectOfflineSettingsLabel") as Label if get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/ProjectOfflineSettingsLabel") != null else find_child("ProjectOfflineSettingsLabel", true, false) as Label),
		(get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/VSplitContainer/ToolchainSection/ToolchainHeaderLabel") as Label if get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/VSplitContainer/ToolchainSection/ToolchainHeaderLabel") != null else find_child("ToolchainHeaderLabel", true, false) as Label),
		(get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/VSplitContainer/ExplorerSection/ExplorerToolbar/ExplorerLabel") as Label if get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/VSplitContainer/ExplorerSection/ExplorerToolbar/ExplorerLabel") != null else find_child("ExplorerLabel", true, false) as Label),
		get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Library/EmptyLibraryState/EmptyStateContent/EmptyTitleLabel") as Label,
		(get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Installed/MarginContainer/InstalledEmptyState/InstalledEmptyTitle") as Label if get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Installed/MarginContainer/InstalledEmptyState/InstalledEmptyTitle") != null else find_child("InstalledEmptyTitle", true, false) as Label)
	]
	for header: Label in section_headers:
		if header != null:
			header.add_theme_font_size_override("font_size", SECTION_FONT_SIZE)
			header.add_theme_color_override("font_color", SECTION_ACCENT_COLOR)
	
	var project_status_node := get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectsStatusBar/HBoxContainer/ProjectsStatusLabel") as Label
	if project_status_node == null:
		project_status_node = get_node_or_null("AppLayout/Content/PageProjects/ProjectsStatusBar/HBoxContainer/ProjectsStatusLabel") as Label
	if project_status_node == null:
		project_status_node = get_node_or_null("AppLayout/Content/PageProjects/ProjectsStatusLabel") as Label
	var offline_status_node := get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectsStatusBar/HBoxContainer/OfflineStatusLabel") as Label
	if offline_status_node == null:
		offline_status_node = get_node_or_null("AppLayout/Content/PageProjects/ProjectsStatusBar/HBoxContainer/OfflineStatusLabel") as Label
	if offline_status_node == null:
		offline_status_node = get_node_or_null("AppLayout/Content/PageProjects/OfflineStatusLabel") as Label
	var secondary_labels: Array[Label] = [
		project_status_node,
		offline_status_node,
		get_node_or_null("AppLayout/Content/PageTools/ToolsStatusLabel") as Label,
		(get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/ProjectOfflineStatusLabel") as Label if get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/ProjectOfflineStatusLabel") != null else find_child("ProjectOfflineStatusLabel", true, false) as Label),
		(get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/OfflineModeContainer/ProjectOfflineModeHelperLabel") as Label if get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/OfflineModeContainer/ProjectOfflineModeHelperLabel") != null else find_child("ProjectOfflineModeHelperLabel", true, false) as Label),
		(get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/ForceOfflineContainer/ProjectForceOfflineHelperLabel") as Label if get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Details/ProjectOfflineSection/ForceOfflineContainer/ProjectForceOfflineHelperLabel") != null else find_child("ProjectForceOfflineHelperLabel", true, false) as Label),
		(get_node_or_null("AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorStatusLabel") as Label if get_node_or_null("AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorStatusLabel") != null else find_child("MirrorStatusLabel", true, false) as Label),
		(get_node_or_null("AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsHelperLabel") as Label if get_node_or_null("AppLayout/Content/PageSettings/ProjectsCard/VBoxContainer/ProjectsHelperLabel") != null else find_child("ProjectsHelperLabel", true, false) as Label),
		(get_node_or_null("AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorHelperLabel") as Label if get_node_or_null("AppLayout/Content/PageSettings/MirrorCard/VBoxContainer/MirrorHelperLabel") != null else find_child("MirrorHelperLabel", true, false) as Label),
		get_node_or_null("AppLayout/Content/PageProjects/ProjectsTabs/Project Library/EmptyLibraryState/EmptyStateContent/EmptyMessageLabel") as Label,
		(get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Installed/MarginContainer/InstalledEmptyState/InstalledEmptyDescription") as Label if get_node_or_null("AppLayout/Content/PageTools/ToolsTabs/Installed/MarginContainer/InstalledEmptyState/InstalledEmptyDescription") != null else find_child("InstalledEmptyDescription", true, false) as Label)
	]
	for sec_label: Label in secondary_labels:
		if sec_label != null:
			sec_label.add_theme_font_size_override("font_size", SECONDARY_FONT_SIZE)
			sec_label.add_theme_color_override("font_color", MUTED_LABEL_COLOR)
	
	var sidebar: PanelContainer = get_node_or_null("AppLayout/Sidebar") as PanelContainer
	if sidebar != null:
		var sidebar_style: StyleBoxFlat = StyleBoxFlat.new()
		sidebar_style.bg_color = Color(0.09, 0.10, 0.13, 1.0)
		sidebar_style.border_width_right = 1
		sidebar_style.border_color = Color(0.22, 0.25, 0.30, 1.0)
		sidebar_style.content_margin_left = 12.0
		sidebar_style.content_margin_right = 12.0
		sidebar_style.content_margin_top = 16.0
		sidebar_style.content_margin_bottom = 16.0
		sidebar.add_theme_stylebox_override("panel", sidebar_style)

	var brand_title: Label = get_node_or_null("AppLayout/Sidebar/VBoxContainer/BrandHeader/BrandTitle") as Label
	if brand_title != null:
		brand_title.add_theme_font_size_override("font_size", 16)
		brand_title.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 1.0))

	var side_status: Label = get_node_or_null("AppLayout/Sidebar/VBoxContainer/SidebarFooter/SidebarStatusLabel") as Label
	if side_status != null:
		side_status.add_theme_font_size_override("font_size", 12)

	var side_ver: Label = get_node_or_null("AppLayout/Sidebar/VBoxContainer/SidebarFooter/SidebarVersionLabel") as Label
	if side_ver != null:
		side_ver.add_theme_font_size_override("font_size", 11)
		side_ver.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70, 1.0))
	
	self.theme = global_theme

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if projects_controller != null and projects_controller.has_meta("project_explorer_instance"):
			projects_controller.get_meta("project_explorer_instance").refresh()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if tools_controller != null:
			tools_controller.cleanup()
		if tools_page_controller != null:
			tools_page_controller.cleanup()
		if projects_controller != null:
			projects_controller.cleanup()

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
		page_projects, page_tools, page_settings,
		sidebar_status_label, sidebar_version_label
	)
	var app_ver: String = String(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	var formatted_ver: String = "v%s" % app_ver if not app_ver.begins_with("v") else app_ver
	layout_controller.update_version(formatted_ver)
	_update_sidebar_connectivity_status(false)

	projects_controller = ProjectsControllerScript.new()
	settings_controller = SettingsControllerScript.new()
	
	var settings_file_path = OS.get_user_data_dir().path_join("ogs_launcher_settings.json")
	var settings_deps = SettingsControllerScript.UIDeps.new()
	settings_deps.projects_root_path = projects_root_path
	settings_deps.projects_root_browse_button = projects_root_browse_button
	settings_deps.projects_root_reset_button = projects_root_reset_button
	settings_deps.mirror_root_path = mirror_root_path
	settings_deps.mirror_repo_path = mirror_repo_path
	settings_deps.mirror_status_label = mirror_status_label
	settings_deps.app_node = self
	
	settings_controller.setup(settings_deps, projects_controller, DEFAULT_REMOTE_REPO_URL, settings_file_path)

	tools_controller = ToolsControllerScript.new(get_tree(), settings_controller.get_mirror_repository_url())
	
	progress_controller = ProgressControllerScript.new()
	download_dialog_controller = DownloadDialogControllerScript.new()
	download_dialog_controller.setup(self, tools_controller)

	tools_page_controller = ToolsPageControllerScript.new()
	var tools_page_deps = ToolsPageControllerScript.UIDeps.new()
	tools_page_deps.tools_tabs = tools_tabs
	tools_page_deps.installed_content = installed_content
	tools_page_deps.download_content = download_content
	tools_page_deps.installed_empty_state = installed_empty_state
	tools_page_deps.browse_available_tools_button = browse_available_tools_button
	tools_page_deps.installed_engine_tools = installed_engine_tools
	tools_page_deps.installed_2d_tools = installed_2d_tools
	tools_page_deps.installed_3d_tools = installed_3d_tools
	tools_page_deps.installed_audio_tools = installed_audio_tools
	tools_page_deps.installed_code_tools = installed_code_tools
	tools_page_deps.download_engine_tools = download_engine_tools
	tools_page_deps.download_2d_tools = download_2d_tools
	tools_page_deps.download_3d_tools = download_3d_tools
	tools_page_deps.download_audio_tools = download_audio_tools
	tools_page_deps.download_code_tools = download_code_tools
	tools_page_deps.tools_status_label = tools_status_label
	tools_page_deps.tools_offline_message = tools_offline_message
	tools_page_deps.remove_tool_dialog = remove_tool_dialog
	tools_page_deps.remove_tool_confirmation_label = remove_tool_confirmation_label
	tools_page_deps.remove_tool_status_label = remove_tool_status_label
	tools_page_deps.remove_tool_progress_bar = remove_tool_progress_bar
	
	tools_page_controller.setup(tools_page_deps, tools_controller, progress_controller, projects_controller, download_dialog_controller)

	tools_controller.tool_list_updated.connect(func():
		tools_page_controller.update_connectivity_status(tools_controller.is_online())
		_update_sidebar_connectivity_status(tools_controller.is_online())
		tools_page_controller.populate_tools_ui()
		projects_controller.refresh_project_tools_state()
	)
	tools_controller.tool_list_refresh_failed.connect(func(_err):
		tools_page_controller.update_connectivity_status(tools_controller.is_online())
		_update_sidebar_connectivity_status(tools_controller.is_online())
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
		_update_sidebar_connectivity_status(tools_controller.is_online())
		tools_page_controller.update_download_button_states()
	)
	tools_controller.tool_download_progress.connect(func(tid, ver, d, t):
		if progress_controller: progress_controller.update_progress(tid, ver, d, t)
	)
	tools_controller.connectivity_checked.connect(func(is_on):
		tools_page_controller.update_connectivity_status(is_on)
		_update_sidebar_connectivity_status(is_on)
	)
	tools_refresh_button.pressed.connect(func(): tools_controller.refresh_tool_list())

	var deps = ProjectsControllerScript.UIDeps.new()
	deps.btn_add_project = btn_add_project
	deps.btn_add_remote_project = btn_add_remote_project
	deps.btn_new_project = btn_new_project
	deps.app_node = self
	deps.projects_list = projects_list
	deps.project_search_line_edit = project_search_line_edit
	deps.empty_library_state = empty_library_state
	deps.empty_title_label = empty_title_label
	deps.empty_message_label = empty_message_label
	deps.empty_new_project_button = empty_new_project_btn
	deps.empty_add_local_button = empty_add_local_btn
	deps.empty_add_remote_button = empty_add_remote_btn
	deps.empty_clear_filter_button = empty_clear_filter_btn
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
	deps.btn_open_project = btn_open_project
	deps.btn_remove_project = btn_remove_project
	deps.btn_seal_project = btn_seal_for_delivery
	deps.btn_launch_tool = btn_launch_tool
	deps.project_dir_dialog = project_dir_dialog
	deps.remove_project_dialog = remove_project_dialog
	deps.new_project_dialog = new_project_dialog
	deps.new_project_name_line_edit = new_project_name_line_edit
	deps.add_tool_dialog = add_tool_dialog
	deps.add_tool_option_list = add_tool_option_list
	deps.projects_tabs = projects_tabs
	deps.toolchain_header_label = toolchain_header_label
	deps.project_tools_list = project_tools_list
	deps.btn_change_version = btn_change_version
	deps.project_offline_mode_check_button = project_offline_mode_check_button
	deps.project_force_offline_check_button = project_force_offline_check_button
	deps.project_offline_status_label = project_offline_status_label
	deps.project_offline_mode_helper_label = project_offline_mode_helper_label
	deps.project_force_offline_helper_label = project_force_offline_helper_label
	
	projects_controller.setup(deps, tools_controller)
	projects_controller.set_settings_controller(settings_controller)
	settings_controller.projects_root_changed.connect(func(new_root: String):
		projects_controller.registry_manager.set_configured_projects_root(new_root)
	)
	projects_controller.offline_state_changed.connect(_on_offline_state_changed)
	projects_controller.tool_view_requested.connect(func(t, v): tools_page_controller.navigate_to_tool(t, v); layout_controller.navigate_to("tools"))
	projects_controller.environment_incomplete.connect(func(_tools): btn_seal_for_delivery.disabled = true; btn_seal_for_delivery.tooltip_text = "Install missing tools from the Tools page before sealing.")
	projects_controller.environment_ready.connect(func(): btn_seal_for_delivery.disabled = false; btn_seal_for_delivery.tooltip_text = "")
	
	seal_controller = SealControllerScript.new()
	seal_controller.setup(seal_dialog, seal_status_label, seal_output_label, seal_open_folder_button, seal_progress_bar)
	btn_seal_for_delivery.pressed.connect(func(): seal_controller.seal_for_delivery(projects_controller.current_project_dir))

	projects_root_path.text_changed.connect(settings_controller.on_projects_root_text_changed)
	projects_root_browse_button.pressed.connect(settings_controller.on_projects_root_browse_pressed)
	projects_root_reset_button.pressed.connect(settings_controller.on_projects_root_reset_pressed)
	mirror_root_path.text_changed.connect(settings_controller.on_mirror_root_text_changed)
	mirror_root_browse_button.pressed.connect(settings_controller.on_mirror_root_browse_pressed)
	mirror_root_reset_button.pressed.connect(settings_controller.on_mirror_root_reset_pressed)
	mirror_repo_path.text_changed.connect(settings_controller.on_mirror_repo_text_changed)
	mirror_repo_clear_button.pressed.connect(settings_controller.on_mirror_repo_clear_pressed)
	
	layout_controller.page_changed.connect(func(page):
		if page == "tools" and tools_controller:
			if not tools_controller.has_repository_data():
				tools_controller.check_connectivity()
				tools_controller.refresh_tool_list()
	)

	_collect_network_ui_nodes()
	_apply_offline_ui(false)
	btn_seal_for_delivery.disabled = projects_controller.current_project_dir.is_empty()
	btn_seal_for_delivery.tooltip_text = ""
	
	layout_controller.navigate_to("projects")
	
	if tools_controller != null:
		tools_controller.check_connectivity.call_deferred()
		tools_controller.refresh_tool_list.call_deferred()
	
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
	_update_sidebar_connectivity_status(not active and (tools_controller.is_online() if tools_controller else false))

func _apply_offline_ui(active: bool) -> void:
	for node in network_ui_nodes:
		if node is BaseButton:
			var button := node as BaseButton
			button.disabled = active
			button.tooltip_text = "Disabled because OGS Launcher is currently in offline mode." if active else ""

func _update_tools_connectivity_status(is_online: bool) -> void:
	## Helper delegating connectivity status updates to tools_page_controller or direct fallback.
	if tools_page_controller != null:
		tools_page_controller.update_connectivity_status(is_online)
	elif tools_status_label != null and tools_offline_message != null:
		if OfflineEnforcer.is_offline():
			tools_status_label.text = "Status: Offline (enforced: %s)" % OfflineEnforcer.get_reason()
			tools_status_label.modulate = Color(1, 0.6, 0.2, 1)
			tools_offline_message.visible = true
		elif is_online:
			tools_status_label.text = "Status: Online ✓"
			tools_status_label.modulate = Color.GREEN
			tools_offline_message.visible = false
		else:
			tools_status_label.text = "Status: Offline ⚠️"
			tools_status_label.modulate = Color(1, 0.6, 0.2, 1)
			tools_offline_message.visible = true
	_update_sidebar_connectivity_status(is_online)

func _update_sidebar_connectivity_status(is_online: bool) -> void:
	## Helper updating the sidebar footer connectivity indicator.
	if layout_controller != null:
		layout_controller.update_connectivity_status(is_online)
	elif sidebar_status_label != null:
		if OfflineEnforcer.is_offline():
			sidebar_status_label.text = "● Offline"
			sidebar_status_label.modulate = Color(1.0, 0.6, 0.2, 1.0)
			sidebar_status_label.tooltip_text = "Offline Mode (enforced: %s)" % OfflineEnforcer.get_reason()
		elif is_online:
			sidebar_status_label.text = "● Online"
			sidebar_status_label.modulate = Color(0.3, 0.85, 0.45, 1.0)
			sidebar_status_label.tooltip_text = "Online: Connected to repository"
		else:
			sidebar_status_label.text = "● Offline"
			sidebar_status_label.modulate = Color(1.0, 0.6, 0.2, 1.0)
			sidebar_status_label.tooltip_text = "Offline: Cannot reach repository"

func _on_mirror_root_browse_pressed() -> void:
	## Helper forwarding mirror root browse action to SettingsController.
	if settings_controller != null:
		settings_controller.on_mirror_root_browse_pressed()

func _on_projects_root_browse_pressed() -> void:
	## Helper forwarding projects root browse action to SettingsController.
	if settings_controller != null:
		settings_controller.on_projects_root_browse_pressed()

func _exit_tree() -> void:
	if tools_controller != null:
		tools_controller.cleanup()
	if layout_controller != null:
		layout_controller.cleanup()
	if tools_page_controller != null:
		tools_page_controller.cleanup()
	if projects_controller != null:
		projects_controller.cleanup()

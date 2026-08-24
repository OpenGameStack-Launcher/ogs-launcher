## OnboardingWizard: First-run welcome and default stack bootstrap.
##
## Manages the first-run experience:
## 1. Detects if this is a first run
## 2. Shows welcome screen with default stack information
## 3. Handles one-click initialization of Godot 4.7.2 + Blender 4.2
## 4. Marks wizard as complete
##
## Usage:
## var wizard = OnboardingWizard.new()
## wizard.setup(scene_tree, library_root, onboarding_dialog, ogs_root_path)
## if wizard.should_show_wizard():
## wizard.show_wizard()

extends RefCounted
class_name OnboardingWizard

const OgsLogger = preload("res://scripts/logging/logger.gd")

signal wizard_completed(success: bool, message: String)

var wizard_complete_flag_path: String = ""
var library_root: String = ""
var dialog: AcceptDialog = null
var status_label: Label = null
var skip_button: Button = null
var scene_tree: SceneTree = null

## Initializes the onboarding wizard.
## Parameters:
## tree (SceneTree): Scene tree for creating nodes
## library_root_path (String): Path where libraries are stored
## onboarding_dialog (AcceptDialog): The wizard dialog from the scene
## ogs_root_path (String): Base OGS data directory
func setup(tree: SceneTree, library_root_path: String, onboarding_dialog: AcceptDialog, ogs_root_path: String) -> void:
	## Sets up the wizard with required references.
	scene_tree = tree
	library_root = library_root_path
	dialog = onboarding_dialog
	var resolved_root = ogs_root_path
	if resolved_root.is_empty():
		resolved_root = OS.get_user_data_dir().path_join("OGS")
	wizard_complete_flag_path = resolved_root.path_join("ogs_wizard_complete.txt")
	
	# Get references to UI elements
	if dialog:
		status_label = dialog.get_node_or_null("VBoxContainer/StatusLabel")
		skip_button = dialog.get_node_or_null("VBoxContainer/ButtonContainer/SkipButton")
		OgsLogger.debug("wizard_nodes", {"component": "onboarding", "status_label": status_label != null, "skip_button": skip_button != null})
		
		# Wire signal handlers
		if skip_button:
			skip_button.pressed.connect(_on_skip_pressed)
		else:
			OgsLogger.warn("wizard_skip_button_missing", {"component": "onboarding"})
		dialog.confirmed.connect(_on_start_pressed)

## Returns true if the wizard should be shown (first run).
func should_show_wizard() -> bool:
	## Returns true if this is a first run and wizard hasn't been completed.
	# Check if wizard completion flag exists
	if FileAccess.file_exists(wizard_complete_flag_path):
		return false
	
	# Check if library root exists and has tools
	if DirAccess.dir_exists_absolute(library_root):
		var lib_dir = DirAccess.open(library_root)
		if lib_dir != null:
			lib_dir.list_dir_begin()
			var file_name = lib_dir.get_next()
			while file_name != "":
				if not file_name.begins_with("."):
					lib_dir.list_dir_end()
					return false  # Found a tool directory, not first run
				file_name = lib_dir.get_next()
			lib_dir.list_dir_end()
	
	return true

## Shows the wizard dialog.
func show_wizard() -> void:
	## Displays the wizard dialog.
	if dialog:
		dialog.popup_centered()
		OgsLogger.info("wizard_shown", {"component": "onboarding", "dialog_visible": dialog.visible})

## Marks the wizard as complete (won't show again).
func mark_complete() -> void:
	## Writes completion flag to disk.
	var file = FileAccess.open(wizard_complete_flag_path, FileAccess.WRITE)
	if file != null:
		file.store_string("completed")
		OgsLogger.info("onboarding_wizard_completed", {"component": "onboarding"})

## Signal handler: skip button pressed.
func _on_skip_pressed() -> void:
	## User chose to skip wizard.
	if dialog:
		dialog.hide()
	mark_complete()
	OgsLogger.info("wizard_skipped", {"component": "onboarding"})
	wizard_completed.emit(true, "Wizard skipped. You can always configure tools later.")

## Signal handler: start button pressed.
func _on_start_pressed() -> void:
	## User chose to initialize default stack.
	OgsLogger.info("wizard_start_pressed", {"component": "onboarding"})
	if status_label:
		status_label.text = "Initializing default stack..."
		status_label.modulate = Color.YELLOW
	
	# For now, just mark as complete and close
	# In Phase 3, this would trigger actual tool downloads
	_initialize_default_stack()

## Initializes the default Stack (Godot 4.7.2 + Blender 4.2).
func _initialize_default_stack() -> void:
	## Prepares the library for default stack tools.
	# Create library directory structure
	var lib_dir = library_root
	if not DirAccess.dir_exists_absolute(lib_dir):
		DirAccess.make_dir_recursive_absolute(lib_dir)
	
	# Create tool subdirectories
	var godot_dir = lib_dir.path_join("godot").path_join("4.7.2")
	var blender_dir = lib_dir.path_join("blender").path_join("4.2")
	
	# Ensure directories exist
	DirAccess.make_dir_recursive_absolute(godot_dir)
	DirAccess.make_dir_recursive_absolute(blender_dir)
	
	# Mark wizard complete
	mark_complete()
	
	if status_label:
		status_label.text = "Default stack initialized successfully!"
		status_label.modulate = Color.GREEN
	
	if dialog:
		dialog.hide()
	
	wizard_completed.emit(true, "Default stack initialized. Tools can be added via the mirror or repair workflow.")
	OgsLogger.info("default_stack_initialized", {"component": "onboarding"})

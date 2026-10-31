## RemoteProjectDialogController: Modular controller for Add Remote Project cloning workflow.
##
## Encapsulates URL input validation, destination folder override, subfolder collision
## detection and resolution, live clone progress tracking, non-blocking cancellation,
## and guided PortableGit installation prompts.
extends RefCounted
class_name RemoteProjectDialogController

const OgsLogger = preload("res://scripts/logging/logger.gd")
const RemoteProjectCloner = preload("res://scripts/projects/remote_project_cloner.gd")
const OfflineEnforcer = preload("res://scripts/network/offline_enforcer.gd")
const PathUtils = preload("res://scripts/utils/path_utils.gd")
const LibraryManager = preload("res://scripts/library/library_manager.gd")

## Emitted when cloning completes successfully and the project folder is ready for registration.
signal clone_completed(cloned_project_dir: String)

## Emitted when the user chooses "Go to Tools" from the missing-Git guided prompt.
signal tool_view_requested(tool_id: String, tool_version: String)

## UI Nodes for Main Clone Dialog
var dialog: ConfirmationDialog
var header_label: Label
var url_label: Label
var url_edit: LineEdit
var dest_label: Label
var dest_container: HBoxContainer
var dest_edit: LineEdit
var btn_browse: Button
var lbl_status: Label
var progress_bar: ProgressBar

## UI Nodes for Missing-Git Prompt
var missing_git_dialog: ConfirmationDialog

## UI Nodes for Folder Collision Prompt
var collision_dialog: ConfirmationDialog
var collision_label: Label
var collision_folder_edit: LineEdit
var collision_error_label: Label

## Controller state
var _parent_node: Node = null
var _library_manager: LibraryManager = null
var _cloner: RemoteProjectCloner = null
var _primary_projects_folder: String = ""
var _active_url: String = ""
var _active_dest_root: String = ""
var _active_target_dir_name: String = ""

func _init() -> void:
	## Initializes UI controls and sub-dialog hierarchies.
	_build_ui()

func setup(parent_node: Node = null, library_manager: LibraryManager = null, cloner: RemoteProjectCloner = null) -> void:
	## Configures parent attachment, library manager, and cloner instance.
	_parent_node = parent_node
	_library_manager = library_manager if library_manager != null else LibraryManager.new()
	
	if cloner != null:
		set_cloner(cloner)
	elif _cloner == null:
		set_cloner(RemoteProjectCloner.new(_library_manager))
	
	if _parent_node != null:
		if dialog.get_parent() == null:
			_parent_node.add_child(dialog)
		if missing_git_dialog.get_parent() == null:
			_parent_node.add_child(missing_git_dialog)
		if collision_dialog.get_parent() == null:
			_parent_node.add_child(collision_dialog)

func set_cloner(cloner: RemoteProjectCloner) -> void:
	## Sets and connects the RemoteProjectCloner instance.
	if _cloner != null:
		if _cloner.phase_changed.is_connected(_on_cloner_phase_changed):
			_cloner.phase_changed.disconnect(_on_cloner_phase_changed)
		if _cloner.progress_updated.is_connected(_on_cloner_progress_updated):
			_cloner.progress_updated.disconnect(_on_cloner_progress_updated)
		if _cloner.clone_failed.is_connected(_on_cloner_clone_failed):
			_cloner.clone_failed.disconnect(_on_cloner_clone_failed)
		if _cloner.clone_completed.is_connected(_on_cloner_clone_completed):
			_cloner.clone_completed.disconnect(_on_cloner_clone_completed)
	
	_cloner = cloner
	if _cloner != null:
		_cloner.phase_changed.connect(_on_cloner_phase_changed)
		_cloner.progress_updated.connect(_on_cloner_progress_updated)
		_cloner.clone_failed.connect(_on_cloner_clone_failed)
		_cloner.clone_completed.connect(_on_cloner_clone_completed)

func set_library_manager(library_manager: LibraryManager) -> void:
	## Sets the LibraryManager reference for Git resolution.
	_library_manager = library_manager

func open(primary_projects_folder: String = "") -> void:
	## Opens the Add Remote Project workflow, checking offline and Git prerequisites.
	if not primary_projects_folder.is_empty():
		_primary_projects_folder = primary_projects_folder
	
	if OfflineEnforcer.is_offline():
		OgsLogger.warn("remote_clone_blocked_offline", {"component": "remote_dialog"})
		return

	if not RemoteProjectCloner.is_git_installed(_library_manager):
		show_missing_git_dialog()
		return

	show_clone_dialog(_primary_projects_folder)

func show_missing_git_dialog() -> void:
	## Displays the guided dialog when PortableGit is not installed.
	_ensure_dialog_in_tree(missing_git_dialog)
	missing_git_dialog.size = Vector2i(480, 160)
	missing_git_dialog.popup_centered(Vector2i(480, 160))

func show_clone_dialog(primary_projects_folder: String = "") -> void:
	## Displays the main Add Remote Project input modal dialog.
	if not primary_projects_folder.is_empty():
		_primary_projects_folder = primary_projects_folder
	
	OgsLogger.info("remote_clone_dialog_opened", {"component": "remote_dialog"})
	_set_busy_ui(false)
	url_edit.text = ""
	lbl_status.text = ""
	progress_bar.visible = false
	progress_bar.value = 0.0
	dest_edit.text = _primary_projects_folder
	var ok_btn = dialog.get_ok_button()
	if ok_btn != null:
		ok_btn.disabled = true
	_ensure_dialog_in_tree(dialog)
	dialog.size = Vector2i(540, 280)
	dialog.popup_centered(Vector2i(540, 280))
	if url_edit.is_inside_tree():
		url_edit.grab_focus()

func _ensure_dialog_in_tree(w: Window) -> void:
	## Ensures window has a valid parent in the SceneTree before pop-up.
	if w == null or w.is_inside_tree():
		return
	if w.get_parent() != null:
		w.get_parent().remove_child(w)
	if _parent_node != null and is_instance_valid(_parent_node) and _parent_node.is_inside_tree():
		_parent_node.add_child(w)
		return
	var tree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.add_child(w)

func _build_ui() -> void:
	## Constructs the internal dialog node tree.
	if dialog != null:
		return
	
	# 1. Main Clone Dialog
	dialog = ConfirmationDialog.new()
	dialog.title = "Add Remote Project"
	dialog.exclusive = true
	dialog.unresizable = true
	dialog.min_size = Vector2(540, 280)
	dialog.ok_button_text = "Clone"
	dialog.cancel_button_text = "Cancel"
	dialog.dialog_hide_on_ok = false
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	header_label = Label.new()
	header_label.text = "Clone a remote Git repository. The repository must be an OGS project containing a valid stack.json at its root."
	header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(header_label)
	
	url_label = Label.new()
	url_label.text = "Remote Git Repository URL:"
	vbox.add_child(url_label)
	
	url_edit = LineEdit.new()
	url_edit.placeholder_text = "https://github.com/user/repo.git or git@github.com:user/repo.git"
	url_edit.text_changed.connect(_on_url_text_changed)
	url_edit.text_submitted.connect(func(_t: String): _on_clone_pressed())
	vbox.add_child(url_edit)
	
	dest_label = Label.new()
	dest_label.text = "Destination Folder:"
	vbox.add_child(dest_label)
	
	dest_container = HBoxContainer.new()
	dest_container.add_theme_constant_override("separation", 8)
	
	dest_edit = LineEdit.new()
	dest_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dest_container.add_child(dest_edit)
	
	btn_browse = Button.new()
	btn_browse.text = "Browse..."
	btn_browse.pressed.connect(_on_browse_pressed)
	dest_container.add_child(btn_browse)
	vbox.add_child(dest_container)
	
	lbl_status = Label.new()
	lbl_status.text = ""
	lbl_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl_status)
	
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0, 20)
	progress_bar.value = 0.0
	progress_bar.visible = false
	vbox.add_child(progress_bar)
	
	dialog.add_child(vbox)
	
	dialog.confirmed.connect(_on_clone_pressed)
	dialog.canceled.connect(_on_dialog_canceled)
	
	var ok_btn = dialog.get_ok_button()
	if ok_btn != null:
		ok_btn.disabled = true
	
	# 2. Missing-Git Prompt
	missing_git_dialog = ConfirmationDialog.new()
	missing_git_dialog.title = "Git Required"
	missing_git_dialog.min_size = Vector2(480, 160)
	missing_git_dialog.exclusive = true
	missing_git_dialog.unresizable = true
	missing_git_dialog.dialog_text = "PortableGit must be installed in OGS Launcher to clone remote Git repositories.\n\nWould you like to go to the Tools page to install Git?"
	missing_git_dialog.ok_button_text = "Go to Tools"
	missing_git_dialog.cancel_button_text = "Cancel"
	missing_git_dialog.confirmed.connect(_on_missing_git_confirmed)
	missing_git_dialog.canceled.connect(_on_missing_git_canceled)
	
	# 3. Collision Prompt
	collision_dialog = ConfirmationDialog.new()
	collision_dialog.title = "Folder Name Collision"
	collision_dialog.min_size = Vector2(480, 160)
	collision_dialog.exclusive = true
	collision_dialog.unresizable = true
	collision_dialog.ok_button_text = "Continue"
	collision_dialog.cancel_button_text = "Cancel"
	collision_dialog.dialog_hide_on_ok = false
	
	var coll_vbox = VBoxContainer.new()
	coll_vbox.add_theme_constant_override("separation", 8)
	
	collision_label = Label.new()
	collision_label.text = "A folder with this name already exists in the destination folder. Choose a new name for the project folder:"
	coll_vbox.add_child(collision_label)
	
	collision_folder_edit = LineEdit.new()
	collision_folder_edit.text_changed.connect(_on_collision_text_changed)
	collision_folder_edit.text_submitted.connect(func(_t: String): _on_collision_confirmed())
	coll_vbox.add_child(collision_folder_edit)
	
	collision_error_label = Label.new()
	collision_error_label.text = ""
	coll_vbox.add_child(collision_error_label)
	
	collision_dialog.add_child(coll_vbox)
	collision_dialog.confirmed.connect(_on_collision_confirmed)
	collision_dialog.canceled.connect(_on_collision_canceled)

func _on_url_text_changed(new_text: String) -> void:
	## Updates Clone button enable/disable state based on URL input.
	var ok_btn = dialog.get_ok_button()
	if ok_btn != null:
		ok_btn.disabled = new_text.strip_edges().is_empty()
	lbl_status.text = ""

func _on_browse_pressed() -> void:
	## Opens folder picker for selecting destination folder override.
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Select Destination Folder"
	var current_dir = dest_edit.text.strip_edges()
	if DirAccess.dir_exists_absolute(current_dir):
		file_dialog.current_dir = current_dir
	elif DirAccess.dir_exists_absolute(_primary_projects_folder):
		file_dialog.current_dir = _primary_projects_folder
	
	file_dialog.dir_selected.connect(func(dir: String):
		dest_edit.text = dir
		file_dialog.queue_free()
	)
	file_dialog.canceled.connect(func(): file_dialog.queue_free())
	file_dialog.close_requested.connect(func(): file_dialog.queue_free())
	
	_ensure_dialog_in_tree(file_dialog)
	file_dialog.popup_centered_ratio(0.7)

func _on_clone_pressed() -> void:
	## Handles Clone button or URL text submission.
	if _cloner != null and _cloner.is_busy():
		return
	
	var raw_url = url_edit.text.strip_edges()
	var val = RemoteProjectCloner.validate_remote_url(raw_url)
	if not val.get("valid", false):
		lbl_status.text = val.get("error_message", "Invalid repository URL.")
		return
	
	var dest_root = dest_edit.text.strip_edges()
	if dest_root.is_empty():
		lbl_status.text = "Destination folder cannot be empty."
		return
	
	if not DirAccess.dir_exists_absolute(dest_root):
		var make_err = DirAccess.make_dir_recursive_absolute(dest_root)
		if make_err != OK and not DirAccess.dir_exists_absolute(dest_root):
			lbl_status.text = "Could not create destination directory."
			return
	
	var slug = RemoteProjectCloner.extract_repo_slug(raw_url)
	if slug.is_empty():
		lbl_status.text = "Unable to determine repository name from URL."
		return
	
	_active_url = raw_url
	_active_dest_root = dest_root
	
	var candidate_path = dest_root.path_join(slug)
	if DirAccess.dir_exists_absolute(candidate_path) or FileAccess.file_exists(candidate_path):
		_show_collision_dialog(dest_root, slug)
		return
	
	_active_target_dir_name = slug
	_start_clone(raw_url, slug, dest_root)

func _show_collision_dialog(dest_root: String, slug: String) -> void:
	## Shows folder name collision resolution prompt.
	collision_label.text = "A folder named '%s' already exists in the destination folder. Choose a new name for the project folder:" % slug
	var suggested = RemoteProjectCloner.suggest_next_available_folder_name(dest_root, slug)
	collision_folder_edit.text = suggested
	collision_error_label.text = ""
	var ok_btn = collision_dialog.get_ok_button()
	if ok_btn != null:
		ok_btn.disabled = false
	_ensure_dialog_in_tree(collision_dialog)
	collision_dialog.size = Vector2i(480, 160)
	collision_dialog.popup_centered(Vector2i(480, 160))
	if collision_folder_edit.is_inside_tree():
		collision_folder_edit.grab_focus()
		collision_folder_edit.select_all()

func _on_collision_text_changed(new_text: String) -> void:
	## Validates collision folder name on text change.
	var trimmed = new_text.strip_edges()
	var ok_btn = collision_dialog.get_ok_button()
	if trimmed.is_empty():
		collision_error_label.text = "Folder name cannot be empty."
		if ok_btn != null:
			ok_btn.disabled = true
		return
	
	var val = RemoteProjectCloner.validate_target_path(trimmed, _active_dest_root)
	if not val.get("valid", false):
		collision_error_label.text = val.get("error", "Invalid folder name.")
		if ok_btn != null:
			ok_btn.disabled = true
		return
	
	var target_path = _active_dest_root.path_join(trimmed)
	if DirAccess.dir_exists_absolute(target_path) or FileAccess.file_exists(target_path):
		collision_error_label.text = "Folder '%s' already exists." % trimmed
		if ok_btn != null:
			ok_btn.disabled = true
		return
	
	collision_error_label.text = ""
	if ok_btn != null:
		ok_btn.disabled = false

func _on_collision_confirmed() -> void:
	## Confirms collision resolution and starts clone.
	var chosen_name = collision_folder_edit.text.strip_edges()
	var val = RemoteProjectCloner.validate_target_path(chosen_name, _active_dest_root)
	if not val.get("valid", false):
		collision_error_label.text = val.get("error", "Invalid folder name.")
		return
	
	var target_path = _active_dest_root.path_join(chosen_name)
	if DirAccess.dir_exists_absolute(target_path) or FileAccess.file_exists(target_path):
		collision_error_label.text = "Folder '%s' already exists." % chosen_name
		return
	
	collision_dialog.hide()
	_active_target_dir_name = chosen_name
	_start_clone(_active_url, chosen_name, _active_dest_root)

func _on_collision_canceled() -> void:
	## Returns to the main clone dialog on collision cancel.
	collision_dialog.hide()

func _start_clone(url: String, target_dir_name: String, dest_root: String) -> void:
	## Initiates the asynchronous two-phase clone operation.
	if OfflineEnforcer.is_offline():
		lbl_status.text = "Cannot clone in offline mode."
		return
	
	_set_busy_ui(true)
	progress_bar.visible = true
	progress_bar.value = 0.0
	lbl_status.text = "Verifying OGS project (stack.json)..."
	OgsLogger.info("remote_clone_started", {
		"component": "remote_dialog",
		"repo_slug": target_dir_name
	})
	_cloner.clone_project_async(url, target_dir_name, dest_root)

func _set_busy_ui(busy: bool) -> void:
	## Updates dialog controls according to busy/idle cloning state.
	url_edit.editable = not busy
	dest_edit.editable = not busy
	btn_browse.disabled = busy
	dialog.dialog_close_on_escape = not busy
	var ok_btn = dialog.get_ok_button()
	if ok_btn != null:
		ok_btn.disabled = busy if busy else url_edit.text.strip_edges().is_empty()
	var cancel_btn = dialog.get_cancel_button()
	if cancel_btn != null:
		cancel_btn.text = "Cancel"
		cancel_btn.disabled = false

func _on_cancel_pressed() -> void:
	## Helper forwarding Cancel button press to cancellation handler.
	_on_dialog_canceled()

func _on_dialog_canceled() -> void:
	## Handles Cancel button press or escape on main clone dialog.
	if _cloner != null and _cloner.is_busy():
		dialog.show()
		var cancel_btn = dialog.get_cancel_button()
		if cancel_btn != null:
			cancel_btn.text = "Cancelling..."
			cancel_btn.disabled = true
		lbl_status.text = "Cancelling clone operation..."
		OgsLogger.info("remote_clone_cancelled", {"component": "remote_dialog"})
		_cloner.cancel()
	else:
		dialog.hide()

func _on_missing_git_confirmed() -> void:
	## Emits tool view request to navigate to Git download page.
	missing_git_dialog.hide()
	tool_view_requested.emit("git", "")

func _on_missing_git_canceled() -> void:
	## Dismisses missing-Git dialog without side effects.
	missing_git_dialog.hide()

func _on_cloner_phase_changed(phase: String) -> void:
	## Updates status label when cloner changes operational phase.
	if phase == "verifying":
		lbl_status.text = "Verifying OGS project (stack.json)..."
	elif phase == "cloning":
		lbl_status.text = "Cloning repository..."

func _on_cloner_progress_updated(percent: float, message: String) -> void:
	## Updates progress bar and status message during clone.
	progress_bar.value = percent
	if not message.is_empty():
		lbl_status.text = message

func _on_cloner_clone_failed(error_code: String, error_message: String) -> void:
	## Handles cloner error or cancellation by restoring idle UI state.
	OgsLogger.warn("remote_clone_failed", {
		"component": "remote_dialog",
		"error_code": error_code,
		"error_message": error_message
	})
	_set_busy_ui(false)
	progress_bar.visible = false
	progress_bar.value = 0.0
	lbl_status.text = error_message

func _on_cloner_clone_completed(cloned_project_dir: String) -> void:
	## Handles successful cloning: closes dialog and notifies listener.
	OgsLogger.info("remote_clone_completed", {
		"component": "remote_dialog",
		"project_dir": cloned_project_dir
	})
	_set_busy_ui(false)
	progress_bar.visible = false
	progress_bar.value = 0.0
	dialog.hide()
	clone_completed.emit(cloned_project_dir)

func cleanup() -> void:
	## Safely cancels any active cloning process and joins worker threads.
	if _cloner != null and _cloner.is_busy():
		_cloner.cancel()
		_cloner.wait_for_finish()

func free_nodes() -> void:
	## Explicitly frees instantiated UI dialog nodes to prevent ObjectDB leaks in tests.
	cleanup()
	if dialog != null and is_instance_valid(dialog) and not dialog.is_queued_for_deletion():
		if dialog.get_parent() != null:
			dialog.get_parent().remove_child(dialog)
		dialog.free()
		dialog = null
	if missing_git_dialog != null and is_instance_valid(missing_git_dialog) and not missing_git_dialog.is_queued_for_deletion():
		if missing_git_dialog.get_parent() != null:
			missing_git_dialog.get_parent().remove_child(missing_git_dialog)
		missing_git_dialog.free()
		missing_git_dialog = null
	if collision_dialog != null and is_instance_valid(collision_dialog) and not collision_dialog.is_queued_for_deletion():
		if collision_dialog.get_parent() != null:
			collision_dialog.get_parent().remove_child(collision_dialog)
		collision_dialog.free()
		collision_dialog = null

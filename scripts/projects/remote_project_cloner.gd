## RemoteProjectCloner: Headless Git cloner with URL validation, two-phase manifest verification, and async execution.
##
## Manages Git discovery in the Central Library, air-gap and URL security validation,
## repo slug extraction, destination collision resolution, two-phase cloning
## (blobless pre-checkout check for stack.json followed by working tree checkout),
## non-blocking execution, and safe cancellation/cleanup.
extends RefCounted
class_name RemoteProjectCloner

const OgsLogger = preload("res://scripts/logging/logger.gd")
const OfflineEnforcer = preload("res://scripts/network/offline_enforcer.gd")
const PathUtils = preload("res://scripts/utils/path_utils.gd")
const StackManifest = preload("res://scripts/manifest/stack_manifest.gd")
const OgsConfig = preload("res://scripts/config/ogs_config.gd")
const LibraryManager = preload("res://scripts/library/library_manager.gd")

## Emitted when cloning transitions between lifecycle phases ("verifying", "cloning").
signal phase_changed(phase: String)

## Emitted periodically as Git reports operation progress percentage.
signal progress_updated(percent: float, message: String)

## Emitted when cloning fails due to network, validation, missing manifest, or cancellation.
signal clone_failed(error_code: String, error_message: String)

## Emitted when cloning and manifest verification complete successfully.
signal clone_completed(cloned_project_dir: String)

## Hardened Git security arguments passed to every Git invocation.
const HARDENED_GIT_ARGS: Array[String] = [
	"-c", "protocol.ext.allow=never",
	"-c", "protocol.file.allow=never",
	"-c", "core.symlinks=false",
	"-c", "core.fsmonitor=false"
]

var _library_manager: LibraryManager = null
var _thread: Thread = null
var _mutex: Mutex = Mutex.new()
var _is_running: bool = false
var _cancelled: bool = false
var _current_pid: int = -1
var _last_percent: float = 0.0

## Pluggable command runner for testing: func(exe: String, args: PackedStringArray, on_progress: Callable) -> Dictionary
var custom_command_runner: Callable = Callable()

func _init(p_library_manager: LibraryManager = null) -> void:
	## Initializes RemoteProjectCloner with an optional LibraryManager instance.
	_library_manager = p_library_manager

func _notification(what: int) -> void:
	## Cleans up active child processes and worker threads on destruction.
	if what == NOTIFICATION_PREDELETE:
		_cancelled = true
		if _current_pid > 0 and OS.is_process_running(_current_pid):
			OS.kill(_current_pid)
		if _thread != null and _thread.is_started():
			_thread.wait_to_finish()
			_thread = null

## Checks whether PortableGit is installed in the Central Library.
static func is_git_installed(library_manager: LibraryManager = null) -> bool:
	return not resolve_git_executable(library_manager).is_empty()

## Resolves the PortableGit executable from the Central Library.
## Queries LibraryManager.get_available_versions("git") and selects the highest installed version.
## Logs a structured warning via OgsLogger and returns empty string if not installed.
static func resolve_git_executable(library_manager: LibraryManager = null) -> String:
	var lib: LibraryManager = library_manager if library_manager != null else LibraryManager.new()
	var exe: String = lib.resolve_git_executable()
	if exe.is_empty():
		OgsLogger.warn("git_not_installed", {
			"component": "cloner",
			"reason": "portable_git_not_found"
		})
		return ""
	OgsLogger.debug("git_cli_resolved", {
		"component": "cloner",
		"executable": exe
	})
	return exe

## Returns true if the given URL is safe and valid for remote cloning.
static func is_valid_remote_url(url: String) -> bool:
	return validate_remote_url(url).get("valid", false)

## Validates a remote repository URL against air-gap, protocol, and command injection restrictions.
## Returns a Dictionary with "valid" (bool), "error_code" (String), and "error_message" (String).
static func validate_remote_url(url: String) -> Dictionary:
	var trimmed: String = url.strip_edges()
	if trimmed.is_empty():
		return {
			"valid": false,
			"error_code": "empty_url",
			"error_message": "Repository URL cannot be empty.",
			"error": "Repository URL cannot be empty."
		}
	
	# Guard against CLI argument/flag injection (e.g., --upload-pack)
	if trimmed.begins_with("-"):
		return {
			"valid": false,
			"error_code": "argument_injection",
			"error_message": "URL cannot begin with a dash or hyphen.",
			"error": "URL cannot begin with a dash or hyphen."
		}
	
	var lower: String = trimmed.to_lower()
	
	# Reject local filesystem schemes and custom protocol helpers
	if lower.begins_with("file://") or lower.begins_with("file:"):
		return {
			"valid": false,
			"error_code": "disallowed_protocol",
			"error_message": "Local file:// protocol is disallowed.",
			"error": "Local file:// protocol is disallowed."
		}
	
	if lower.begins_with("ext::") or lower.contains("ext::"):
		return {
			"valid": false,
			"error_code": "disallowed_protocol",
			"error_message": "Custom protocol helper ext:: is disallowed.",
			"error": "Custom protocol helper ext:: is disallowed."
		}
	
	# Reject shell metacharacters
	var metachars: Array[String] = [";", "&", "|", "`", "$", "\n", "\r", "<", ">", "\"", "'"]
	for mc in metachars:
		if trimmed.contains(mc):
			return {
				"valid": false,
				"error_code": "shell_metacharacters",
				"error_message": "URL contains disallowed shell metacharacters.",
				"error": "URL contains disallowed shell metacharacters."
			}
	
	# Reject whitespace and control characters (ASCII <= 32 or ASCII 127)
	for i in range(trimmed.length()):
		var c = trimmed.unicode_at(i)
		if c <= 32 or c == 127:
			return {
				"valid": false,
				"error_code": "illegal_characters",
				"error_message": "URL contains whitespace or control characters.",
				"error": "URL contains whitespace or control characters."
			}
	
	# Reject local Windows drive paths (e.g. C:\... or C:/...)
	if trimmed.length() >= 2 and trimmed[1] == ":":
		var drive_char: String = trimmed[0].to_upper()
		if drive_char >= "A" and drive_char <= "Z":
			return {
				"valid": false,
				"error_code": "local_path",
				"error_message": "Local Windows filesystem paths are disallowed.",
				"error": "Local Windows filesystem paths are disallowed."
			}
	
	# Reject absolute and relative filesystem paths
	if trimmed.begins_with("/") or trimmed.begins_with("\\") or trimmed.begins_with("./") or trimmed.begins_with(".\\") or trimmed.begins_with("../") or trimmed.begins_with("..\\") or trimmed == "." or trimmed == "..":
		return {
			"valid": false,
			"error_code": "local_path",
			"error_message": "Local filesystem paths are disallowed.",
			"error": "Local filesystem paths are disallowed."
		}
	
	if trimmed.contains("/../") or trimmed.contains("\\..\\") or trimmed.contains("/..") or trimmed.contains("\\.."):
		return {
			"valid": false,
			"error_code": "local_path",
			"error_message": "Directory traversal sequences are disallowed.",
			"error": "Directory traversal sequences are disallowed."
		}
	
	# Validate allowed remote schemes: https, http, ssh, or SCP syntax
	if trimmed.contains("://"):
		var scheme_end: int = trimmed.find("://")
		var scheme: String = trimmed.substr(0, scheme_end).to_lower()
		if scheme != "https" and scheme != "http" and scheme != "ssh":
			return {
				"valid": false,
				"error_code": "unsupported_scheme",
				"error_message": "Unsupported URL scheme: " + scheme,
				"error": "Unsupported URL scheme: " + scheme
			}
		
		var remainder: String = trimmed.substr(scheme_end + 3)
		if remainder.is_empty():
			return {
				"valid": false,
				"error_code": "invalid_url_format",
				"error_message": "URL host is missing.",
				"error": "URL host is missing."
			}
		if remainder.contains("://"):
			return {
				"valid": false,
				"error_code": "nested_scheme",
				"error_message": "Nested URL schemes are disallowed.",
				"error": "Nested URL schemes are disallowed."
			}
		if remainder.begins_with("-") or remainder.begins_with("/"):
			return {
				"valid": false,
				"error_code": "invalid_url_format",
				"error_message": "Invalid URL authority structure.",
				"error": "Invalid URL authority structure."
			}
		
		var slash_pos: int = remainder.find("/")
		if slash_pos == -1 or slash_pos == remainder.length() - 1:
			return {
				"valid": false,
				"error_code": "invalid_url_format",
				"error_message": "URL must include repository path.",
				"error": "URL must include repository path."
			}
		
		var host_part: String = remainder.substr(0, slash_pos)
		if host_part.is_empty() or host_part.begins_with("-"):
			return {
				"valid": false,
				"error_code": "invalid_url_format",
				"error_message": "Invalid URL host.",
				"error": "Invalid URL host."
			}
		
		return {
			"valid": true,
			"error_code": "",
			"error_message": "",
			"error": ""
		}
	else:
		# SCP-style SSH syntax: [user@]host:path/repo.git
		var colon_pos: int = trimmed.find(":")
		if colon_pos == -1:
			return {
				"valid": false,
				"error_code": "invalid_url_format",
				"error_message": "URL lacks a valid remote scheme or SCP separator.",
				"error": "URL lacks a valid remote scheme or SCP separator."
			}
		if trimmed.find(":", colon_pos + 1) != -1:
			return {
				"valid": false,
				"error_code": "invalid_url_format",
				"error_message": "Multiple colons in SCP-style URL are disallowed.",
				"error": "Multiple colons in SCP-style URL are disallowed."
			}
		
		var host_part: String = trimmed.substr(0, colon_pos)
		var path_part: String = trimmed.substr(colon_pos + 1)
		
		if host_part.is_empty() or path_part.is_empty():
			return {
				"valid": false,
				"error_code": "invalid_url_format",
				"error_message": "Invalid SCP-style SSH URL structure.",
				"error": "Invalid SCP-style SSH URL structure."
			}
		
		if host_part.begins_with("-") or path_part.begins_with("-") or path_part.begins_with("/") or path_part.begins_with("\\"):
			return {
				"valid": false,
				"error_code": "invalid_url_format",
				"error_message": "Invalid SCP host or path format.",
				"error": "Invalid SCP host or path format."
			}
		
		var scp_regex := RegEx.new()
		scp_regex.compile("^(?:[a-zA-Z0-9_\\-\\.]+@)?[a-zA-Z0-9_\\-\\.]+$")
		if not scp_regex.search(host_part):
			return {
				"valid": false,
				"error_code": "invalid_url_format",
				"error_message": "Invalid characters in SCP host.",
				"error": "Invalid characters in SCP host."
			}
		
		var path_regex := RegEx.new()
		path_regex.compile("^[a-zA-Z0-9_\\-\\.\\/]+$")
		if not path_regex.search(path_part):
			return {
				"valid": false,
				"error_code": "invalid_url_format",
				"error_message": "Invalid characters in SCP repository path.",
				"error": "Invalid characters in SCP repository path."
			}
		
		return {
			"valid": true,
			"error_code": "",
			"error_message": "",
			"error": ""
		}

## Extracts and sanitizes the repository slug name from a remote URL.
## Strips trailing slashes, whitespace, and .git suffix.
## Returns sanitized slug or empty string on failure.
static func extract_repo_slug(repo_url: String) -> String:
	var s: String = repo_url.strip_edges()
	if s.is_empty():
		return ""
	
	while s.ends_with("/") or s.ends_with("\\"):
		s = s.substr(0, s.length() - 1).strip_edges()
	
	if s.is_empty():
		return ""
	
	var last_slash: int = s.rfind("/")
	var last_backslash: int = s.rfind("\\")
	var last_colon: int = s.rfind(":")
	var cut_idx: int = maxi(last_slash, maxi(last_backslash, last_colon))
	
	var last_segment: String = s
	if cut_idx != -1 and cut_idx < s.length() - 1:
		last_segment = s.substr(cut_idx + 1)
	
	last_segment = last_segment.strip_edges()
	if last_segment.to_lower().ends_with(".git"):
		last_segment = last_segment.substr(0, last_segment.length() - 4).strip_edges()
	
	if last_segment.is_empty() or last_segment.begins_with(".") or last_segment.contains("/") or last_segment.contains("\\") or last_segment == "..":
		return ""
	
	var safe_regex := RegEx.new()
	safe_regex.compile("^[a-zA-Z0-9_\\-\\.]+$")
	if not safe_regex.search(last_segment):
		return ""
	
	var upper_slug: String = last_segment.to_upper()
	var base_name: String = upper_slug.get_basename()
	var reserved: Array[String] = [
		"CON", "PRN", "AUX", "NUL",
		"COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
		"LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
	]
	if base_name in reserved:
		return ""
	
	return last_segment

## Suggests the next available directory name under dest_root to prevent folder collision.
## Returns base_slug if available, otherwise base_slug-1, base_slug-2, etc.
static func suggest_next_available_folder_name(dest_root: String, base_slug: String) -> String:
	var clean_root: String = dest_root.simplify_path()
	var candidate: String = base_slug
	var path: String = clean_root.path_join(candidate)
	if not DirAccess.dir_exists_absolute(path) and not FileAccess.file_exists(path):
		return candidate
	
	var counter: int = 1
	while true:
		candidate = "%s-%d" % [base_slug, counter]
		path = clean_root.path_join(candidate)
		if not DirAccess.dir_exists_absolute(path) and not FileAccess.file_exists(path):
			return candidate
		counter += 1
	return candidate

## Validates that a target directory name resolves strictly under destination root.
## Rejects empty names, traversal attempts, or paths equal to root.
static func is_target_path_valid(target_dir_name: String, dest_root: String) -> bool:
	var trimmed: String = target_dir_name.strip_edges()
	if trimmed.is_empty() or dest_root.strip_edges().is_empty():
		return false
	if trimmed.contains("/") or trimmed.contains("\\") or trimmed.contains(".."):
		return false
	var full_path: String = dest_root.path_join(trimmed)
	if full_path.simplify_path() == dest_root.simplify_path():
		return false
	return PathUtils.is_path_under_root(full_path, dest_root)

## Validates target path and returns a Dictionary result.
static func validate_target_path(target_dir_name: String, dest_root: String) -> Dictionary:
	if not is_target_path_valid(target_dir_name, dest_root):
		return {"valid": false, "error": "Target path must resolve strictly under destination root."}
	return {"valid": true, "error": ""}

## Starts asynchronous two-phase clone operation on a background thread.
func clone_project_async(repo_url: String, target_dir_name: String, dest_root: String) -> void:
	_mutex.lock()
	if _is_running:
		_mutex.unlock()
		OgsLogger.warn("clone_already_running", {"component": "cloner"})
		clone_failed.emit.call_deferred("already_running", "A clone operation is already in progress.")
		return
	_is_running = true
	_cancelled = false
	_last_percent = 0.0
	_mutex.unlock()
	
	# Air-Gap Enforcement: check before executing any network process
	if OfflineEnforcer.is_offline():
		_mutex.lock()
		_is_running = false
		_mutex.unlock()
		OgsLogger.warn("clone_failed", {
			"component": "cloner",
			"error_code": "offline",
			"error_message": "Network operations are blocked in offline mode."
		})
		clone_failed.emit.call_deferred("offline", "Network operations are blocked in offline mode.")
		return
	
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	
	var resolved_target_name: String = target_dir_name.strip_edges()
	if resolved_target_name.is_empty():
		resolved_target_name = extract_repo_slug(repo_url)
	
	_thread = Thread.new()
	var thread_args: Dictionary = {
		"repo_url": repo_url,
		"target_dir_name": resolved_target_name,
		"dest_root": dest_root
	}
	var err: Error = _thread.start(Callable(self, "_worker_thread_func").bind(thread_args))
	if err != OK:
		_mutex.lock()
		_is_running = false
		_mutex.unlock()
		OgsLogger.error("clone_thread_start_failed", {"component": "cloner", "error": err})
		clone_failed.emit.call_deferred("thread_error", "Failed to start clone worker thread.")

## Cancels an active clone operation, killing active Git child processes and cleaning partial state.
func cancel() -> void:
	_mutex.lock()
	if not _is_running or _cancelled:
		_mutex.unlock()
		return
	_cancelled = true
	var pid: int = _current_pid
	_mutex.unlock()
	
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)
	
	OgsLogger.info("clone_cancelled", {
		"component": "cloner"
	})

## Returns true if an async clone operation is actively running.
func is_busy() -> bool:
	_mutex.lock()
	var busy: bool = _is_running
	_mutex.unlock()
	return busy

## Waits for the active background worker thread to finish.
func wait_for_finish() -> void:
	_join_thread()
	_mutex.lock()
	_is_running = false
	_current_pid = -1
	_mutex.unlock()

func _join_thread() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
		_thread = null

func _is_cancelled() -> bool:
	_mutex.lock()
	var c: bool = _cancelled
	_mutex.unlock()
	return c

func _deferred_finish() -> void:
	_mutex.lock()
	_is_running = false
	_current_pid = -1
	_mutex.unlock()
	_join_thread()

func _handle_git_progress(line: String) -> void:
	var trimmed: String = line.strip_edges()
	if trimmed.is_empty():
		return
	
	var regex := RegEx.new()
	regex.compile("(\\d{1,3})%")
	var match := regex.search(trimmed)
	if match:
		_last_percent = float(match.get_string(1))
	
	progress_updated.emit.call_deferred(_last_percent, trimmed)

func _run_command(executable: String, args: PackedStringArray, on_progress: Callable) -> Dictionary:
	if custom_command_runner.is_valid():
		return custom_command_runner.call(executable, args, on_progress)
	return _execute_git_command(executable, args, on_progress)

func _execute_git_command(executable: String, args: PackedStringArray, on_progress: Callable) -> Dictionary:
	var result_dict: Dictionary = {
		"exit_code": -1,
		"stdout": "",
		"stderr": "",
		"cancelled": false
	}
	
	OS.set_environment("GIT_TERMINAL_PROMPT", "0")
	
	var pipe_res: Dictionary = OS.execute_with_pipe(executable, args)
	if pipe_res.is_empty() or not pipe_res.has("pid"):
		result_dict["stderr"] = "Failed to spawn process: %s" % executable
		return result_dict
	
	var pid: int = pipe_res["pid"]
	_mutex.lock()
	_current_pid = pid
	var already_cancelled: bool = _cancelled
	_mutex.unlock()
	
	if already_cancelled:
		if OS.is_process_running(pid):
			OS.kill(pid)
		result_dict["cancelled"] = true
		return result_dict
	
	var stdio: FileAccess = pipe_res.get("stdio")
	var stderr: FileAccess = pipe_res.get("stderr")
	
	var stdout_acc: String = ""
	var stderr_acc: String = ""
	
	while true:
		if _is_cancelled():
			if OS.is_process_running(pid):
				OS.kill(pid)
			result_dict["cancelled"] = true
			break
		
		var has_data: bool = false
		if stdio != null:
			var out_line: String = stdio.get_line()
			if not out_line.is_empty():
				stdout_acc += out_line + "\n"
				has_data = true
		
		if stderr != null:
			var err_line: String = stderr.get_line()
			if not err_line.is_empty():
				stderr_acc += err_line + "\n"
				has_data = true
				if on_progress.is_valid():
					on_progress.call(err_line)
		
		if not has_data:
			if not OS.is_process_running(pid):
				break
			OS.delay_msec(5)
	
	var exit_code: int = OS.get_process_exit_code(pid)
	_mutex.lock()
	_current_pid = -1
	_mutex.unlock()
	
	result_dict["exit_code"] = exit_code
	result_dict["stdout"] = stdout_acc
	result_dict["stderr"] = stderr_acc
	return result_dict

func _worker_thread_func(args: Dictionary) -> void:
	var repo_url: String = args.get("repo_url", "")
	var target_dir_name: String = args.get("target_dir_name", "")
	var dest_root: String = args.get("dest_root", "")
	
	if OfflineEnforcer.is_offline():
		OgsLogger.warn("clone_failed", {
			"component": "cloner",
			"error_code": "offline",
			"error_message": "Network operations are blocked in offline mode."
		})
		clone_failed.emit.call_deferred("offline", "Network operations are blocked in offline mode.")
		_deferred_finish.call_deferred()
		return
	
	var url_res: Dictionary = validate_remote_url(repo_url)
	if not url_res.get("valid", false):
		var err_msg: String = url_res.get("error_message", "Invalid remote repository URL.")
		var err_code: String = url_res.get("error_code", "invalid_url")
		OgsLogger.warn("clone_failed", {
			"component": "cloner",
			"error_code": err_code,
			"error_message": err_msg
		})
		clone_failed.emit.call_deferred(err_code, err_msg)
		_deferred_finish.call_deferred()
		return
	
	if not is_target_path_valid(target_dir_name, dest_root):
		OgsLogger.warn("clone_failed", {
			"component": "cloner",
			"error_code": "invalid_target_dir",
			"error_message": "Target directory escapes destination root or contains invalid characters."
		})
		clone_failed.emit.call_deferred("invalid_target_dir", "Target directory escapes destination root or contains invalid characters.")
		_deferred_finish.call_deferred()
		return
	
	var target_dir: String = dest_root.path_join(target_dir_name)
	if DirAccess.dir_exists_absolute(target_dir) or FileAccess.file_exists(target_dir):
		OgsLogger.warn("clone_failed", {
			"component": "cloner",
			"error_code": "target_dir_exists",
			"error_message": "Target directory already exists: " + target_dir_name
		})
		clone_failed.emit.call_deferred("target_dir_exists", "Target directory already exists: " + target_dir_name)
		_deferred_finish.call_deferred()
		return
	
	var git_exe: String = resolve_git_executable(_library_manager)
	if git_exe.is_empty():
		OgsLogger.warn("clone_failed", {
			"component": "cloner",
			"error_code": "git_not_found",
			"error_message": "PortableGit is not installed in the Central Library."
		})
		clone_failed.emit.call_deferred("git_not_found", "PortableGit is not installed in the Central Library.")
		_deferred_finish.call_deferred()
		return
	
	if not DirAccess.dir_exists_absolute(dest_root):
		DirAccess.make_dir_recursive_absolute(dest_root)
	
	OgsLogger.info("clone_started", {
		"component": "cloner",
		"repo_slug": target_dir_name
	})
	
	# Phase A: Pre-Checkout Manifest Verification
	phase_changed.emit.call_deferred("verifying")
	
	var base_args: Array[String] = []
	base_args.append_array(HARDENED_GIT_ARGS)
	base_args.append("clone")
	
	var clone_blob_args := PackedStringArray(base_args)
	clone_blob_args.append_array(["--filter=blob:none", "--no-checkout", "--progress", "--", repo_url, target_dir])
	
	var clone_res: Dictionary = _run_command(git_exe, clone_blob_args, Callable(self, "_handle_git_progress"))
	if clone_res.get("cancelled", false) or _is_cancelled():
		_safe_remove_directory(target_dir, dest_root)
		OgsLogger.info("clone_cancelled", {"component": "cloner"})
		clone_failed.emit.call_deferred("cancelled", "Clone operation was cancelled by user.")
		_deferred_finish.call_deferred()
		return
	
	if clone_res.get("exit_code", -1) != 0:
		# Fallback to standard --no-checkout clone if server does not support partial clone filters
		_safe_remove_directory(target_dir, dest_root)
		var clone_fallback_args := PackedStringArray(base_args)
		clone_fallback_args.append_array(["--no-checkout", "--progress", "--", repo_url, target_dir])
		clone_res = _run_command(git_exe, clone_fallback_args, Callable(self, "_handle_git_progress"))
		if clone_res.get("cancelled", false) or _is_cancelled():
			_safe_remove_directory(target_dir, dest_root)
			OgsLogger.info("clone_cancelled", {"component": "cloner"})
			clone_failed.emit.call_deferred("cancelled", "Clone operation was cancelled by user.")
			_deferred_finish.call_deferred()
			return
		if clone_res.get("exit_code", -1) != 0:
			_safe_remove_directory(target_dir, dest_root)
			var err_text: String = clone_res.get("stderr", "").strip_edges()
			if err_text.is_empty():
				err_text = "Git clone failed with exit code %d" % clone_res.get("exit_code", -1)
			OgsLogger.warn("clone_failed", {
				"component": "cloner",
				"error_code": "clone_failed",
				"error_message": err_text
			})
			clone_failed.emit.call_deferred("clone_failed", err_text)
			_deferred_finish.call_deferred()
			return
	
	var show_args := PackedStringArray()
	show_args.append_array(HARDENED_GIT_ARGS)
	show_args.append_array(["-C", target_dir, "show", "HEAD:stack.json"])
	
	var show_res: Dictionary = _run_command(git_exe, show_args, Callable())
	if show_res.get("cancelled", false) or _is_cancelled():
		_safe_remove_directory(target_dir, dest_root)
		OgsLogger.info("clone_cancelled", {"component": "cloner"})
		clone_failed.emit.call_deferred("cancelled", "Clone operation was cancelled by user.")
		_deferred_finish.call_deferred()
		return
	
	if show_res.get("exit_code", -1) != 0:
		_safe_remove_directory(target_dir, dest_root)
		OgsLogger.warn("clone_failed", {
			"component": "cloner",
			"error_code": "missing_stack_json",
			"error_message": "Repository does not contain a root stack.json manifest."
		})
		clone_failed.emit.call_deferred("missing_stack_json", "Repository does not contain a root stack.json manifest.")
		_deferred_finish.call_deferred()
		return
	
	var manifest_text: String = show_res.get("stdout", "")
	var manifest: StackManifest = StackManifest.parse_json_string(manifest_text)
	var manifest_valid: bool = manifest.is_valid() or (manifest.errors == ["tools_empty"] and not manifest.stack_name.is_empty())
	if not manifest_valid:
		_safe_remove_directory(target_dir, dest_root)
		var err_detail: String = ", ".join(manifest.errors)
		OgsLogger.warn("clone_failed", {
			"component": "cloner",
			"error_code": "invalid_stack_json",
			"error_message": "Repository stack.json manifest is invalid: " + err_detail
		})
		clone_failed.emit.call_deferred("invalid_stack_json", "Repository stack.json manifest is invalid: " + err_detail)
		_deferred_finish.call_deferred()
		return
	
	OgsLogger.info("manifest_prechecked", {
		"component": "cloner",
		"repo_slug": target_dir_name,
		"stack_name": manifest.stack_name
	})
	
	# Phase B: Working Tree Checkout
	phase_changed.emit.call_deferred("cloning")
	
	var checkout_args := PackedStringArray()
	checkout_args.append_array(HARDENED_GIT_ARGS)
	checkout_args.append_array(["-C", target_dir, "checkout", "--progress", "HEAD"])
	
	var checkout_res: Dictionary = _run_command(git_exe, checkout_args, Callable(self, "_handle_git_progress"))
	if checkout_res.get("cancelled", false) or _is_cancelled():
		_safe_remove_directory(target_dir, dest_root)
		OgsLogger.info("clone_cancelled", {"component": "cloner"})
		clone_failed.emit.call_deferred("cancelled", "Clone operation was cancelled by user.")
		_deferred_finish.call_deferred()
		return
	
	if checkout_res.get("exit_code", -1) != 0:
		_safe_remove_directory(target_dir, dest_root)
		var chk_err: String = checkout_res.get("stderr", "").strip_edges()
		if chk_err.is_empty():
			chk_err = "Git checkout failed with exit code %d" % checkout_res.get("exit_code", -1)
		OgsLogger.warn("clone_failed", {
			"component": "cloner",
			"error_code": "checkout_failed",
			"error_message": chk_err
		})
		clone_failed.emit.call_deferred("checkout_failed", chk_err)
		_deferred_finish.call_deferred()
		return
	
	OgsLogger.info("checkout_completed", {
		"component": "cloner",
		"repo_slug": target_dir_name
	})
	
	# Inspect checked-out project root for ogs_config.json
	var config_path: String = target_dir.path_join("ogs_config.json")
	if not FileAccess.file_exists(config_path):
		var default_config: Dictionary = OgsConfig.new().to_dict()
		var file = FileAccess.open(config_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(default_config, "\t") + "\n")
			file.close()
			OgsLogger.info("project_config_auto_generated", {
				"component": "cloner",
				"project": target_dir.get_file()
			})
	
	clone_completed.emit.call_deferred(target_dir)
	_deferred_finish.call_deferred()

## Recursively deletes target_dir safely guarded by PathUtils.is_path_under_root.
static func _safe_remove_directory(target_dir: String, dest_root: String) -> bool:
	var clean_target: String = target_dir.simplify_path()
	var clean_root: String = dest_root.simplify_path()
	if clean_target.is_empty() or clean_root.is_empty():
		return false
	if clean_target == clean_root:
		return false
	if not PathUtils.is_path_under_root(clean_target, clean_root):
		return false
	if not DirAccess.dir_exists_absolute(clean_target):
		return true
	return _remove_dir_recursive(clean_target) == OK

static func _remove_dir_recursive(dir_path: String) -> int:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return DirAccess.get_open_error()
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while not file_name.is_empty():
		if file_name != "." and file_name != "..":
			var item_path = dir_path.path_join(file_name)
			if dir.current_is_dir():
				var err = _remove_dir_recursive(item_path)
				if err != OK:
					dir.list_dir_end()
					return err
			else:
				var err = DirAccess.remove_absolute(item_path)
				if err != OK:
					dir.list_dir_end()
					return err
		file_name = dir.get_next()
	dir.list_dir_end()
	return DirAccess.remove_absolute(dir_path)

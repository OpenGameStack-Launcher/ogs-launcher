## Logger: Structured logging utility for OGS Launcher.
##
## Writes JSON lines to user://logs/ogs_launcher.log with optional rotation.
## Use this for operational events; avoid logging sensitive file paths.

extends RefCounted

const LOG_DIR := "user://logs"
const LOG_FILE := "ogs_launcher.log"
const MAX_BYTES := 1024 * 1024
const MAX_BACKUPS := 3
const CREATE_LOCK_SUFFIX := ".create_lock"
const CREATE_LOCK_TIMEOUT_MSEC := 250
const CREATE_LOCK_RETRY_MSEC := 5
const CREATE_LOCK_STALE_MSEC := 5000
const CREATE_LOCK_TIMESTAMP_FILE := "lock_time"
const CREATE_LOCK_OWNER_FILE := "lock_owner"

## Log levels for filtering.
enum Level {
	DEBUG = 0,
	INFO = 1,
	WARN = 2,
	ERROR = 3,
}

static var _level := Level.INFO
static var _enabled := true
static var _console_enabled := Engine.is_editor_hint()
static var _dir_ensured := false
static var _write_mutex: Mutex = Mutex.new()
static var _test_open_error_overrides: Dictionary = {}
static var _test_open_error_override_uses: Dictionary = {}
static var _test_lock_refresh_fail_on_call := -1
static var _test_lock_refresh_call_count := 0
static var _test_write_fail_on_call := -1
static var _test_write_call_count := 0
static var _last_open_error: int = OK

static func set_level(level: int) -> void:
	## Sets the minimum log level for writing entries.
## Parameters:
## level (int): OgsLogger.Level value
## 
	_level = level as Level

static func enable(enabled: bool) -> void:
	## Enables or disables logging at runtime.
## Parameters:
## enabled (bool): True to enable logging
## 
	_enabled = enabled

static func enable_console(enabled: bool) -> void:
	## Enables or disables console logging (editor Output panel).
## Parameters:
## enabled (bool): True to write logs to console
## 
	_console_enabled = enabled

static func debug(message: String, context: Dictionary = {}) -> void:
	## Writes a debug log entry.
## Parameters:
## message (String): Log message
## context (Dictionary): Structured context fields
## 
	write(Level.DEBUG, message, context)

static func info(message: String, context: Dictionary = {}) -> void:
	## Writes an info log entry.
## Parameters:
## message (String): Log message
## context (Dictionary): Structured context fields
## 
	write(Level.INFO, message, context)

static func warn(message: String, context: Dictionary = {}) -> void:
	## Writes a warning log entry.
## Parameters:
## message (String): Log message
## context (Dictionary): Structured context fields
## 
	write(Level.WARN, message, context)

static func error(message: String, context: Dictionary = {}) -> void:
	## Writes an error log entry.
## Parameters:
## message (String): Log message
## context (Dictionary): Structured context fields
## 
	write(Level.ERROR, message, context)

static func write(level: int, message: String, context: Dictionary = {}) -> void:
	## Writes a structured log entry as JSON.
	## Parameters:
	##   level (int): OgsLogger.Level value
	##   message (String): Log message
	##   context (Dictionary): Structured context fields
	if not _enabled or level < _level:
		return
		
	if not _dir_ensured:
		_ensure_log_dir()
		_dir_ensured = true
		
	var entry = {
		"ts": Time.get_datetime_string_from_system(false),
		"level": _level_name(level),
		"message": message,
		"context": _sanitize_context(context)
	}
	if _console_enabled:
		print(JSON.stringify(entry))
		
	var log_path = _get_log_path()
	_write_mutex.lock()
	var open_result = _open_log_file_for_append(log_path)
	var file: FileAccess = open_result["file"]
	var creation_lock_path: String = open_result["lock_path"]
	var creation_lock_owner: String = open_result["lock_owner"]
	if file == null:
		if not creation_lock_path.is_empty():
			_release_log_create_lock(creation_lock_path, creation_lock_owner)
		_write_mutex.unlock()
		return

	if not creation_lock_path.is_empty() and not _refresh_log_create_lock_timestamp(creation_lock_path, creation_lock_owner):
		file.close()
		_release_log_create_lock(creation_lock_path, creation_lock_owner)
		_write_mutex.unlock()
		return

	var pre_length = file.get_length()
	if pre_length > MAX_BYTES:
		if not creation_lock_path.is_empty() and not _refresh_log_create_lock_timestamp(creation_lock_path, creation_lock_owner):
			file.close()
			_release_log_create_lock(creation_lock_path, creation_lock_owner)
			_write_mutex.unlock()
			return
		file.close()
		if _rotate_if_needed():
			if not creation_lock_path.is_empty() and not _refresh_log_create_lock_timestamp(creation_lock_path, creation_lock_owner):
				_release_log_create_lock(creation_lock_path, creation_lock_owner)
				_write_mutex.unlock()
				return
			file = _open_log_file(log_path, FileAccess.WRITE)
		else:
			file = _open_log_file(log_path, FileAccess.READ_WRITE)
		if file == null:
			if not creation_lock_path.is_empty():
				_release_log_create_lock(creation_lock_path, creation_lock_owner)
			_write_mutex.unlock()
			return

	if not creation_lock_path.is_empty() and not _refresh_log_create_lock_timestamp(creation_lock_path, creation_lock_owner):
		file.close()
		_release_log_create_lock(creation_lock_path, creation_lock_owner)
		_write_mutex.unlock()
		return
	file.seek_end()
	file.store_string(JSON.stringify(entry) + "\n")
	file.close()
	if _get_file_length(log_path) > MAX_BYTES:
		if not creation_lock_path.is_empty() and not _refresh_log_create_lock_timestamp(creation_lock_path, creation_lock_owner):
			_release_log_create_lock(creation_lock_path, creation_lock_owner)
			_write_mutex.unlock()
			return
		_rotate_if_needed()
	if not creation_lock_path.is_empty():
		_release_log_create_lock(creation_lock_path, creation_lock_owner)
	_write_mutex.unlock()

static func clear_logs_for_tests() -> void:
	## Removes log files for test isolation.
	clear_open_error_overrides_for_tests()
	clear_lock_refresh_failure_override_for_tests()
	clear_write_failure_override_for_tests()
	var base = _get_log_path()
	_delete_file(base)
	for index in range(1, MAX_BACKUPS + 1):
		_delete_file(base + "." + str(index))
	var lock_path = _get_log_create_lock_path()
	_remove_lock_directory_contents(lock_path)
	DirAccess.remove_absolute(lock_path)

static func set_open_error_override_for_tests(mode: int, error_code: int, remaining_uses: int = -1) -> void:
	## Overrides logger file-open results during tests.
	if error_code == OK:
		_test_open_error_overrides.erase(mode)
		_test_open_error_override_uses.erase(mode)
	else:
		_test_open_error_overrides[mode] = error_code
		_test_open_error_override_uses[mode] = remaining_uses

static func clear_open_error_overrides_for_tests() -> void:
	## Clears logger file-open overrides after tests.
	_test_open_error_overrides.clear()
	_test_open_error_override_uses.clear()
	_last_open_error = OK

static func set_lock_refresh_failure_call_for_tests(call_index: int) -> void:
	## Forces the Nth lock-refresh attempt to fail during tests.
	_test_lock_refresh_fail_on_call = call_index
	_test_lock_refresh_call_count = 0

static func clear_lock_refresh_failure_override_for_tests() -> void:
	## Clears lock-refresh failure overrides after tests.
	_test_lock_refresh_fail_on_call = -1
	_test_lock_refresh_call_count = 0

static func set_write_failure_call_for_tests(call_index: int) -> void:
	## Forces the Nth WRITE-mode open attempt to fail during tests.
	_test_write_fail_on_call = call_index
	_test_write_call_count = 0

static func clear_write_failure_override_for_tests() -> void:
	## Clears write-open failure overrides after tests.
	_test_write_fail_on_call = -1
	_test_write_call_count = 0

static func _get_log_path() -> String:
	## Returns the user:// log file path.
	return LOG_DIR + "/" + LOG_FILE

static func _open_log_file_for_append(log_path: String) -> Dictionary:
	## Opens the active log file without truncating an existing log.
	## Returns {file, lock_path, lock_owner}. The caller must always release
	## lock_path after appending so cross-process writes remain serialized.
	var lock_path = _get_log_create_lock_path()
	var lock_result = _acquire_log_create_lock_for_append(lock_path)
	var lock_owner: String = lock_result["owner"]
	if lock_owner.is_empty():
		return {"file": null, "lock_path": "", "lock_owner": ""}
	var file = _open_log_file(log_path, FileAccess.READ_WRITE)
	if file == null and _last_open_error == ERR_FILE_NOT_FOUND:
		if not _refresh_log_create_lock_timestamp(lock_path, lock_owner):
			_release_log_create_lock(lock_path, lock_owner)
			return {"file": null, "lock_path": "", "lock_owner": ""}
		if _create_log_file_if_missing(log_path, lock_path, lock_owner):
			file = _open_log_file(log_path, FileAccess.READ_WRITE)
	if file == null:
		_release_log_create_lock(lock_path, lock_owner)
		return {"file": null, "lock_path": "", "lock_owner": ""}
	return {"file": file, "lock_path": lock_path, "lock_owner": lock_owner}

static func _ensure_log_dir() -> void:
	## Ensures the log directory exists.
	var absolute = ProjectSettings.globalize_path(LOG_DIR)
	DirAccess.make_dir_recursive_absolute(absolute)

static func _open_log_file(log_path: String, mode: int) -> FileAccess:
	## Opens a log file while honoring test-only failure overrides.
	if mode == FileAccess.WRITE:
		_test_write_call_count += 1
		if _test_write_fail_on_call == _test_write_call_count:
			_last_open_error = ERR_CANT_CREATE
			return null
	if _test_open_error_overrides.has(mode):
		_last_open_error = _test_open_error_overrides[mode]
		_consume_open_error_override(mode)
		return null
	var file = FileAccess.open(log_path, mode)
	_last_open_error = FileAccess.get_open_error()
	return file

static func _get_log_create_lock_path() -> String:
	## Returns the absolute path for the cross-process log creation lock.
	return ProjectSettings.globalize_path(_get_log_path()) + CREATE_LOCK_SUFFIX

static func _acquire_log_create_lock(lock_path: String) -> Dictionary:
	## Claims the cross-process lock used while creating the log file.
	## Returns {"owner": String, "should_wait": bool} so callers can distinguish
	## hard failures from real lock contention while still recovering stale locks.
	var deadline = Time.get_ticks_msec() + CREATE_LOCK_TIMEOUT_MSEC
	var stale_recovered := false
	while true:
		var err = DirAccess.make_dir_absolute(lock_path)
		if err == OK:
			var owner_token = _build_lock_owner_token()
			var ts_path = lock_path + "/" + CREATE_LOCK_TIMESTAMP_FILE
			var owner_path = lock_path + "/" + CREATE_LOCK_OWNER_FILE
			var ts_ok = _atomic_write_text_file(ts_path, str(int(Time.get_unix_time_from_system() * 1000.0)))
			var owner_ok = _atomic_write_text_file(owner_path, owner_token)
			if not ts_ok or not owner_ok:
				_remove_lock_directory_contents(lock_path)
				DirAccess.remove_absolute(lock_path)
				return {"owner": "", "should_wait": false}
			if _read_log_create_lock_owner(lock_path) != owner_token:
				return {"owner": "", "should_wait": false}
			return {"owner": owner_token, "should_wait": false}
		if err != ERR_ALREADY_EXISTS:
			return {"owner": "", "should_wait": false}
		if not DirAccess.dir_exists_absolute(lock_path):
			if FileAccess.file_exists(lock_path):
				return {"owner": "", "should_wait": false}
			if Time.get_ticks_msec() >= deadline:
				return {"owner": "", "should_wait": false}
			OS.delay_msec(CREATE_LOCK_RETRY_MSEC)
			continue
		if Time.get_ticks_msec() >= deadline:
			if not stale_recovered and _is_log_create_lock_stale(lock_path):
				stale_recovered = true
				var stale_owner = _read_log_create_lock_owner(lock_path)
				_force_remove_stale_lock(lock_path, stale_owner)
				continue
			return {"owner": "", "should_wait": true}
		OS.delay_msec(CREATE_LOCK_RETRY_MSEC)
	return {"owner": "", "should_wait": false}

static func _release_log_create_lock(lock_path: String, owner_token: String) -> void:
	## Releases the cross-process lock used while creating the log file.
	if owner_token.is_empty():
		return
	var claimed_lock_path = _claim_lock_for_cleanup(lock_path, owner_token)
	if claimed_lock_path.is_empty():
		return
	_remove_lock_directory_contents(claimed_lock_path)
	DirAccess.remove_absolute(claimed_lock_path)

static func _refresh_log_create_lock_timestamp(lock_path: String, owner_token: String) -> bool:
	## Renews lock timestamp only when the expected owner still holds the lock.
	if owner_token.is_empty():
		return false
	_test_lock_refresh_call_count += 1
	if _test_lock_refresh_fail_on_call == _test_lock_refresh_call_count:
		return false
	if _read_log_create_lock_owner(lock_path) != owner_token:
		return false
	var ts_path = lock_path + "/" + CREATE_LOCK_TIMESTAMP_FILE
	var refreshed = _atomic_write_text_file(ts_path, str(int(Time.get_unix_time_from_system() * 1000.0)))
	if not refreshed:
		return false
	return _read_log_create_lock_owner(lock_path) == owner_token

static func _atomic_write_text_file(path: String, value: String) -> bool:
	## Atomically updates a text file by writing a temp file then replacing.
	var temp_path = path + ".tmp." + str(OS.get_process_id()) + "." + str(Time.get_ticks_usec())
	var temp_file = _open_log_file(temp_path, FileAccess.WRITE)
	if temp_file == null:
		return false
	temp_file.store_string(value)
	temp_file.flush()
	var write_ok = temp_file.get_error() == OK
	temp_file.close()
	if not write_ok:
		DirAccess.remove_absolute(temp_path)
		return false
	var rename_err = DirAccess.rename_absolute(temp_path, path)
	if rename_err != OK:
		DirAccess.remove_absolute(temp_path)
		return false
	return true

static func _is_log_create_lock_stale(lock_path: String) -> bool:
	## Returns true when the lock directory has no valid timestamp or its
	## recorded age exceeds CREATE_LOCK_STALE_MSEC, indicating a crash-orphaned lock.
	var ts_path = lock_path + "/" + CREATE_LOCK_TIMESTAMP_FILE
	var ts_file = FileAccess.open(ts_path, FileAccess.READ)
	if ts_file == null:
		return _is_log_create_lock_older_than_stale_window(lock_path)
	var ts_text = ts_file.get_as_text().strip_edges()
	ts_file.close()
	if not ts_text.is_valid_int():
		return _is_log_create_lock_older_than_stale_window(lock_path)
	var lock_age = int(Time.get_unix_time_from_system() * 1000.0) - ts_text.to_int()
	return lock_age >= CREATE_LOCK_STALE_MSEC

static func _is_log_create_lock_older_than_stale_window(lock_path: String) -> bool:
	## Guards the metadata-initialization window by using lock dir mtime as fallback.
	var lock_modified_unix = FileAccess.get_modified_time(lock_path)
	if lock_modified_unix <= 0:
		return true
	var lock_age = int(Time.get_unix_time_from_system() * 1000.0) - int(lock_modified_unix * 1000.0)
	return lock_age >= CREATE_LOCK_STALE_MSEC

static func _force_remove_stale_lock(lock_path: String, expected_owner: String = "") -> void:
	## Removes a stale cross-process creation lock directory and its timestamp file.
	if not DirAccess.dir_exists_absolute(lock_path):
		return
	var cleanup_path = lock_path
	var owner = expected_owner
	if owner.is_empty():
		if not _is_log_create_lock_stale(lock_path):
			return
		owner = _read_log_create_lock_owner(lock_path)
		if owner.is_empty():
			cleanup_path = lock_path + ".cleanup." + str(OS.get_process_id()) + "." + str(Time.get_ticks_usec())
			if DirAccess.rename_absolute(lock_path, cleanup_path) != OK:
				return
			if not _read_log_create_lock_owner(cleanup_path).is_empty() or not _is_log_create_lock_stale(cleanup_path):
				_restore_claimed_lock_directory(cleanup_path, lock_path)
				return
			_remove_lock_directory_contents(cleanup_path)
			DirAccess.remove_absolute(cleanup_path)
			return
	cleanup_path = _claim_lock_for_cleanup(lock_path, owner)
	if cleanup_path.is_empty():
		return
	if not _is_log_create_lock_stale(cleanup_path):
		_restore_claimed_lock_directory(cleanup_path, lock_path)
		return
	_remove_lock_directory_contents(cleanup_path)
	DirAccess.remove_absolute(cleanup_path)

static func _wait_for_log_create_lock_release(lock_path: String) -> bool:
	## Waits for a contended lock to clear or be recovered before retrying ownership.
	var deadline = Time.get_ticks_msec() + CREATE_LOCK_STALE_MSEC
	var stale_recovered := false
	while true:
		if not DirAccess.dir_exists_absolute(lock_path):
			return true
		if Time.get_ticks_msec() >= deadline:
			if not stale_recovered and _is_log_create_lock_stale(lock_path):
				stale_recovered = true
				var stale_owner = _read_log_create_lock_owner(lock_path)
				_force_remove_stale_lock(lock_path, stale_owner)
				continue
			return false
		OS.delay_msec(CREATE_LOCK_RETRY_MSEC)
	return false

static func _acquire_log_create_lock_for_append(lock_path: String) -> Dictionary:
	## Acquires the cross-process append lock, waiting through bounded contention.
	## Guarantees one acquisition retry after a successful stale-lock recovery,
	## even when the outer deadline has elapsed during the wait.
	var deadline = Time.get_ticks_msec() + CREATE_LOCK_STALE_MSEC
	while Time.get_ticks_msec() < deadline:
		var lock_result = _acquire_log_create_lock(lock_path)
		var lock_owner: String = lock_result["owner"]
		var should_wait: bool = lock_result["should_wait"]
		if not lock_owner.is_empty():
			return lock_result
		if not should_wait:
			return {"owner": "", "should_wait": false}
		if not _wait_for_log_create_lock_release(lock_path):
			return {"owner": "", "should_wait": true}
		return _acquire_log_create_lock(lock_path)
	return {"owner": "", "should_wait": true}

static func _create_log_file_if_missing(log_path: String, lock_path: String, lock_owner: String) -> bool:
	## Creates a missing log without truncating a replacement owner's newer file.
	if not _refresh_log_create_lock_timestamp(lock_path, lock_owner):
		return false
	if FileAccess.file_exists(log_path):
		return true
	var absolute_log_path = ProjectSettings.globalize_path(log_path)
	var temp_path = lock_path + "/log_create." + str(OS.get_process_id()) + "." + str(Time.get_ticks_usec())
	var temp_file = _open_log_file(temp_path, FileAccess.WRITE)
	if temp_file == null:
		return false
	temp_file.close()
	# Refresh immediately before the rename to minimise the gap where a
	# contender could reclaim an expired lock and create the log file between
	# our last existence check and the rename.
	if not _refresh_log_create_lock_timestamp(lock_path, lock_owner):
		DirAccess.remove_absolute(temp_path)
		return false
	var rename_err = DirAccess.rename_absolute(temp_path, absolute_log_path)
	if rename_err != OK:
		DirAccess.remove_absolute(temp_path)
		return rename_err == ERR_ALREADY_EXISTS
	return true

static func _build_lock_owner_token() -> String:
	## Returns a best-effort unique token for lock ownership checks.
	return str(OS.get_process_id()) + ":" + str(int(Time.get_unix_time_from_system() * 1000.0)) + ":" + str(Time.get_ticks_usec())

static func _read_log_create_lock_owner(lock_path: String) -> String:
	## Returns the current lock owner token or an empty string when unavailable.
	var owner_path = lock_path + "/" + CREATE_LOCK_OWNER_FILE
	var owner_file = FileAccess.open(owner_path, FileAccess.READ)
	if owner_file == null:
		return ""
	var owner = owner_file.get_as_text().strip_edges()
	owner_file.close()
	return owner

static func _claim_lock_for_cleanup(lock_path: String, expected_owner: String) -> String:
	## Atomically moves a lock directory to a private cleanup path when owner matches.
	if expected_owner.is_empty():
		return ""
	if _read_log_create_lock_owner(lock_path) != expected_owner:
		return ""
	var cleanup_path = lock_path + ".cleanup." + str(OS.get_process_id()) + "." + str(Time.get_ticks_usec())
	if DirAccess.rename_absolute(lock_path, cleanup_path) != OK:
		return ""
	if _read_log_create_lock_owner(cleanup_path) != expected_owner:
		_restore_claimed_lock_directory(cleanup_path, lock_path)
		return ""
	return cleanup_path

static func _restore_claimed_lock_directory(cleanup_path: String, lock_path: String) -> void:
	## Restores a claimed lock directory when ownership revalidation fails.
	if DirAccess.dir_exists_absolute(lock_path):
		return
	DirAccess.rename_absolute(cleanup_path, lock_path)

static func _remove_lock_directory_contents(lock_path: String) -> void:
	## Removes all files/directories inside a lock directory before deleting it.
	var lock_dir = DirAccess.open(lock_path)
	if lock_dir == null:
		return
	lock_dir.list_dir_begin()
	while true:
		var entry = lock_dir.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue
		var absolute_entry_path = lock_path + "/" + entry
		if lock_dir.current_is_dir():
			_remove_lock_directory_contents(absolute_entry_path)
			DirAccess.remove_absolute(absolute_entry_path)
		else:
			DirAccess.remove_absolute(absolute_entry_path)
	lock_dir.list_dir_end()

static func _consume_open_error_override(mode: int) -> void:
	## Decrements and clears one-shot open error overrides during tests.
	if not _test_open_error_override_uses.has(mode):
		return
	var remaining_uses = _test_open_error_override_uses[mode]
	if remaining_uses < 0:
		return
	remaining_uses -= 1
	if remaining_uses <= 0:
		_test_open_error_override_uses.erase(mode)
		_test_open_error_overrides.erase(mode)
		return
	_test_open_error_override_uses[mode] = remaining_uses

static func _rotate_if_needed() -> bool:
	## Rotates logs when the active log exceeds the size threshold.
	var log_path = _get_log_path()
	if not FileAccess.file_exists(log_path):
		return true
	if _get_file_length(log_path) <= MAX_BYTES:
		return true
	var absolute = ProjectSettings.globalize_path(log_path)
	for index in range(MAX_BACKUPS, 0, -1):
		var older_user = log_path + "." + str(index)
		var older = absolute + "." + str(index)
		var newer = absolute + "." + str(index + 1)
		if FileAccess.file_exists(older_user):
			if DirAccess.rename_absolute(older, newer) != OK:
				return false
	var first = absolute + ".1"
	if DirAccess.rename_absolute(absolute, first) != OK:
		return false
	return not FileAccess.file_exists(log_path)

static func _get_file_length(user_path: String) -> int:
	## Returns the file length for a user:// path or 0 if missing.
	if not FileAccess.file_exists(user_path):
		return 0
	var file = FileAccess.open(user_path, FileAccess.READ)
	if file == null:
		return 0
	var length = file.get_length()
	file.close()
	return length

static func _sanitize_context(context: Dictionary) -> Dictionary:
	## Redacts sensitive keys from context before logging.
	var sanitized: Dictionary = {}
	var sensitive_keys = ["system_path", "absolute_path", "local_path"]
	for key in context.keys():
		var key_str = String(key)
		if sensitive_keys.has(key_str.to_lower()):
			sanitized[key_str] = "<redacted>"
		else:
			sanitized[key_str] = context[key]
	return sanitized

static func _level_name(level: int) -> String:
	## Returns a human-readable level name.
	match level:
		Level.DEBUG:
			return "debug"
		Level.INFO:
			return "info"
		Level.WARN:
			return "warn"
		Level.ERROR:
			return "error"
		_:
			return "unknown"

static func _delete_file(user_path: String) -> void:
	## Deletes a user:// file if it exists.
	if not FileAccess.file_exists(user_path):
		return
	var absolute = ProjectSettings.globalize_path(user_path)
	if FileAccess.file_exists(user_path):
		DirAccess.remove_absolute(absolute)

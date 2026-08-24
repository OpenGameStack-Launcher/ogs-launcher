## Logger: Structured logging utility for OGS Launcher.
##
## Writes JSON lines to user://logs/ogs_launcher.log with optional rotation.
## Use this for operational events; avoid logging sensitive file paths.

extends RefCounted

const LOG_DIR := "user://logs"
const LOG_FILE := "ogs_launcher.log"
const MAX_BYTES := 1024 * 1024
const MAX_BACKUPS := 3

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
	var file = _open_log_file_for_append(log_path)
	if file == null:
		_write_mutex.unlock()
		return
			
	file.seek_end()
	file.store_string(JSON.stringify(entry) + "\n")
	var current_length = file.get_length()
	file.close()
	
	if current_length > MAX_BYTES:
		_rotate_if_needed()
	_write_mutex.unlock()

static func clear_logs_for_tests() -> void:
	## Removes log files for test isolation.
	clear_open_error_overrides_for_tests()
	var base = _get_log_path()
	_delete_file(base)
	for index in range(1, MAX_BACKUPS + 1):
		_delete_file(base + "." + str(index))

static func set_open_error_override_for_tests(mode: int, error_code: int) -> void:
	## Overrides logger file-open results during tests.
	if error_code == OK:
		_test_open_error_overrides.erase(mode)
	else:
		_test_open_error_overrides[mode] = error_code

static func clear_open_error_overrides_for_tests() -> void:
	## Clears logger file-open overrides after tests.
	_test_open_error_overrides.clear()
	_last_open_error = OK

static func _get_log_path() -> String:
	## Returns the user:// log file path.
	return LOG_DIR + "/" + LOG_FILE

static func _open_log_file_for_append(log_path: String) -> FileAccess:
	## Opens the active log file without truncating an existing log.
	var file = _open_log_file(log_path, FileAccess.READ_WRITE)
	if file != null:
		return file
	if _last_open_error != ERR_FILE_NOT_FOUND:
		return null
	return _open_log_file(log_path, FileAccess.WRITE)

static func _ensure_log_dir() -> void:
	## Ensures the log directory exists.
	var absolute = ProjectSettings.globalize_path(LOG_DIR)
	DirAccess.make_dir_recursive_absolute(absolute)

static func _open_log_file(log_path: String, mode: int) -> FileAccess:
	## Opens a log file while honoring test-only failure overrides.
	if _test_open_error_overrides.has(mode):
		_last_open_error = _test_open_error_overrides[mode]
		return null
	var file = FileAccess.open(log_path, mode)
	_last_open_error = FileAccess.get_open_error()
	return file

static func _rotate_if_needed() -> void:
	## Rotates logs when the active log exceeds the size threshold.
	var log_path = _get_log_path()
	if not FileAccess.file_exists(log_path):
		return
	if _get_file_length(log_path) <= MAX_BYTES:
		return
	var absolute = ProjectSettings.globalize_path(log_path)
	for index in range(MAX_BACKUPS, 0, -1):
		var older_user = log_path + "." + str(index)
		var older = absolute + "." + str(index)
		var newer = absolute + "." + str(index + 1)
		if FileAccess.file_exists(older_user):
			DirAccess.rename_absolute(older, newer)
	var first = absolute + ".1"
	DirAccess.rename_absolute(absolute, first)

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

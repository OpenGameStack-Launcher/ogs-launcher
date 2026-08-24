## LoggerTests: Unit tests for Logger behavior.

extends RefCounted
class_name OgsLoggerTests

const OgsLogger = preload("res://scripts/logging/logger.gd")

func run() -> Dictionary:
	## Runs Logger unit tests.
## Returns:
## Dictionary: {"passed": int, "failed": int, "failures": Array[String]}
	var results := {"passed": 0, "failed": 0, "failures": []}
	_test_write_and_level_filter(results)
	_test_existing_log_survives_failed_append_open(results)
	_test_missing_log_is_created_after_file_not_found(results)
	_test_stale_lock_is_recovered_and_log_created(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records test assertions.
## Parameters:
## condition (bool): Pass/fail condition
## message (String): Failure message
## results (Dictionary): Aggregated results
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_write_and_level_filter(results: Dictionary) -> void:
	## Verifies log writes and level filtering.
	OgsLogger.clear_logs_for_tests()
	OgsLogger.set_level(OgsLogger.Level.WARN)
	OgsLogger.info("info message", {"component": "test"})
	OgsLogger.warn("warn message", {"component": "test"})
	var log_path = "user://logs/ogs_launcher.log"
	_expect(FileAccess.file_exists(log_path), "log file should exist", results)
	var file = FileAccess.open(log_path, FileAccess.READ)
	if file:
		var contents = file.get_as_text()
		file.close()
		_expect(contents.find("info message") == -1, "info should be filtered", results)
		_expect(contents.find("warn message") != -1, "warn should be logged", results)

func _test_existing_log_survives_failed_append_open(results: Dictionary) -> void:
	## Verifies failed append opens do not truncate an existing log file.
	OgsLogger.clear_logs_for_tests()
	OgsLogger.set_level(OgsLogger.Level.INFO)
	var log_dir = ProjectSettings.globalize_path("user://logs")
	DirAccess.make_dir_recursive_absolute(log_dir)
	var log_path = "user://logs/ogs_launcher.log"
	var existing = FileAccess.open(log_path, FileAccess.WRITE)
	if existing == null:
		_expect(false, "existing log should be creatable", results)
		return
	existing.store_string("existing entry\n")
	existing.close()
	OgsLogger.set_open_error_override_for_tests(FileAccess.READ_WRITE, ERR_CANT_OPEN)
	OgsLogger.info("blocked write", {"component": "test"})
	OgsLogger.clear_open_error_overrides_for_tests()
	var file = FileAccess.open(log_path, FileAccess.READ)
	if file == null:
		_expect(false, "existing log should remain readable", results)
		return
	var contents = file.get_as_text()
	file.close()
	_expect(contents == "existing entry\n", "existing log contents should remain intact", results)
	_expect(contents.find("blocked write") == -1, "failed append should not write a partial entry", results)

func _test_missing_log_is_created_after_file_not_found(results: Dictionary) -> void:
	## Verifies a missing log is created after a file-not-found append failure.
	OgsLogger.clear_logs_for_tests()
	OgsLogger.set_level(OgsLogger.Level.INFO)
	var log_path = "user://logs/ogs_launcher.log"
	OgsLogger.set_open_error_override_for_tests(FileAccess.READ_WRITE, ERR_FILE_NOT_FOUND, 1)
	OgsLogger.info("created after missing file", {"component": "test"})
	OgsLogger.clear_open_error_overrides_for_tests()
	_expect(FileAccess.file_exists(log_path), "missing log should be created", results)
	var file = FileAccess.open(log_path, FileAccess.READ)
	if file == null:
		_expect(false, "created log should be readable", results)
		return
	var contents = file.get_as_text()
	file.close()
	_expect(contents.find("created after missing file") != -1, "created log should contain the new entry", results)

func _test_stale_lock_is_recovered_and_log_created(results: Dictionary) -> void:
	## Verifies a crash-orphaned lock directory is recovered and the log is created.
	OgsLogger.clear_logs_for_tests()
	OgsLogger.set_level(OgsLogger.Level.INFO)
	var log_path = "user://logs/ogs_launcher.log"
	var lock_path = ProjectSettings.globalize_path(log_path) + ".create_lock"
	var log_dir = ProjectSettings.globalize_path("user://logs")
	DirAccess.make_dir_recursive_absolute(log_dir)
	DirAccess.make_dir_absolute(lock_path)
	var ts_path = lock_path + "/lock_time"
	var ts_file = FileAccess.open(ts_path, FileAccess.WRITE)
	if ts_file == null:
		_expect(false, "stale lock timestamp should be writable", results)
		return
	ts_file.store_string(str(Time.get_ticks_msec() - 10000))
	ts_file.close()
	OgsLogger.set_open_error_override_for_tests(FileAccess.READ_WRITE, ERR_FILE_NOT_FOUND, 1)
	OgsLogger.info("after stale lock recovery", {"component": "test"})
	OgsLogger.clear_open_error_overrides_for_tests()
	_expect(FileAccess.file_exists(log_path), "log should be created after stale lock recovery", results)
	var read_file = FileAccess.open(log_path, FileAccess.READ)
	if read_file == null:
		_expect(false, "log created after stale lock should be readable", results)
		return
	var contents = read_file.get_as_text()
	read_file.close()
	_expect(contents.find("after stale lock recovery") != -1, "log should contain entry written after stale lock recovery", results)

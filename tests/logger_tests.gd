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
	_test_existing_log_waits_for_pending_create_lock(results)
	_test_hard_lock_acquire_failure_is_not_treated_as_contention(results)
	_test_stale_lock_cleanup_removes_temp_files(results)
	_test_claimed_lock_cleanup_does_not_touch_replacement_owner(results)
	_test_ownerless_stale_cleanup_removes_stale_lock(results)
	_test_ownerless_stale_cleanup_does_not_delete_live_lock(results)
	_test_write_aborts_when_lock_refresh_fails(results)
	_test_rotation_runs_after_pending_create_lock(results)
	_test_rotation_runs_after_append_crosses_threshold(results)
	_test_rotation_path_aborts_when_lock_refresh_fails(results)
	_test_partial_metadata_init_failure_removes_lock_directory(results)
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
	var owner_path = lock_path + "/lock_owner"
	var ts_file = FileAccess.open(ts_path, FileAccess.WRITE)
	if ts_file == null:
		_expect(false, "stale lock timestamp should be writable", results)
		return
	ts_file.store_string(str(int(Time.get_unix_time_from_system() * 1000.0) - 10000))
	ts_file.close()
	var owner_file = FileAccess.open(owner_path, FileAccess.WRITE)
	if owner_file == null:
		_expect(false, "stale lock owner should be writable", results)
		return
	owner_file.store_string("stale-owner")
	owner_file.close()
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

func _test_existing_log_waits_for_pending_create_lock(results: Dictionary) -> void:
	## Verifies an existing log waits for a pending create lock before appending.
	OgsLogger.clear_logs_for_tests()
	OgsLogger.set_level(OgsLogger.Level.INFO)
	var log_path = "user://logs/ogs_launcher.log"
	var log_dir = ProjectSettings.globalize_path("user://logs")
	DirAccess.make_dir_recursive_absolute(log_dir)
	var existing = FileAccess.open(log_path, FileAccess.WRITE)
	if existing == null:
		_expect(false, "existing log should be creatable for pending-lock test", results)
		return
	existing.store_string("existing entry\n")
	existing.close()
	var lock_path = ProjectSettings.globalize_path(log_path) + ".create_lock"
	DirAccess.make_dir_absolute(lock_path)
	var ts_file = FileAccess.open(lock_path + "/lock_time", FileAccess.WRITE)
	if ts_file == null:
		_expect(false, "pending-lock timestamp should be writable", results)
		return
	ts_file.store_string(str(int(Time.get_unix_time_from_system() * 1000.0)))
	ts_file.close()
	var owner_file = FileAccess.open(lock_path + "/lock_owner", FileAccess.WRITE)
	if owner_file == null:
		_expect(false, "pending-lock owner should be writable", results)
		return
	owner_file.store_string("active-owner")
	owner_file.close()
	var release_delay_msec = OgsLogger.CREATE_LOCK_TIMEOUT_MSEC + 100
	var releaser := Thread.new()
	var start_err = releaser.start(_release_pending_create_lock.bind(lock_path, release_delay_msec))
	if start_err != OK:
		_expect(false, "pending-lock releaser thread should start", results)
		return
	var started_at = Time.get_ticks_msec()
	OgsLogger.info("after pending create lock", {"component": "test"})
	var elapsed_msec = Time.get_ticks_msec() - started_at
	releaser.wait_to_finish()
	var file = FileAccess.open(log_path, FileAccess.READ)
	if file == null:
		_expect(false, "existing log should remain readable after pending-lock recovery", results)
		return
	var contents = file.get_as_text()
	file.close()
	_expect(contents.find("existing entry") != -1, "existing log contents should remain after pending-lock recovery", results)
	_expect(contents.find("after pending create lock") != -1, "new entry should be appended after pending-lock recovery", results)
	_expect(elapsed_msec >= OgsLogger.CREATE_LOCK_TIMEOUT_MSEC, "pending-lock append should wait through the contention path", results)

func _test_hard_lock_acquire_failure_is_not_treated_as_contention(results: Dictionary) -> void:
	## Verifies lock-acquire errors do not masquerade as lock contention.
	var unique_root = "user://missing_lock_parent_%s" % str(Time.get_ticks_usec())
	var lock_path = ProjectSettings.globalize_path(unique_root + "/child/ogs_launcher.log.create_lock")
	var lock_result: Dictionary = OgsLogger._acquire_log_create_lock(lock_path)
	var owner: String = lock_result["owner"]
	var should_wait: bool = lock_result["should_wait"]
	_expect(owner.is_empty(), "hard lock-acquire failure should not return an owner", results)
	_expect(not should_wait, "hard lock-acquire failure should not trigger lock-contention waiting", results)

func _test_stale_lock_cleanup_removes_temp_files(results: Dictionary) -> void:
	## Verifies stale-lock cleanup removes temp files so orphaned lock dirs are deleted.
	OgsLogger.clear_logs_for_tests()
	var log_path = "user://logs/ogs_launcher.log"
	var lock_path = ProjectSettings.globalize_path(log_path) + ".create_lock"
	var log_dir = ProjectSettings.globalize_path("user://logs")
	DirAccess.make_dir_recursive_absolute(log_dir)
	DirAccess.make_dir_absolute(lock_path)
	var owner = "stale-owner"
	var ts_file = FileAccess.open(lock_path + "/lock_time", FileAccess.WRITE)
	if ts_file == null:
		_expect(false, "stale-lock cleanup test timestamp should be writable", results)
		return
	ts_file.store_string(str(int(Time.get_unix_time_from_system() * 1000.0) - 10000))
	ts_file.close()
	var owner_file = FileAccess.open(lock_path + "/lock_owner", FileAccess.WRITE)
	if owner_file == null:
		_expect(false, "stale-lock cleanup test owner should be writable", results)
		return
	owner_file.store_string(owner)
	owner_file.close()
	var temp_file = FileAccess.open(lock_path + "/lock_time.tmp.orphan", FileAccess.WRITE)
	if temp_file == null:
		_expect(false, "stale-lock cleanup test temp file should be writable", results)
		return
	temp_file.store_string("orphan")
	temp_file.close()
	OgsLogger._force_remove_stale_lock(lock_path, owner)
	_expect(not DirAccess.dir_exists_absolute(lock_path), "stale-lock cleanup should remove lock directory even with temp files", results)

func _test_claimed_lock_cleanup_does_not_touch_replacement_owner(results: Dictionary) -> void:
	## Verifies claimed-lock cleanup does not delete a replacement owner directory.
	OgsLogger.clear_logs_for_tests()
	var log_path = "user://logs/ogs_launcher.log"
	var lock_path = ProjectSettings.globalize_path(log_path) + ".create_lock"
	var log_dir = ProjectSettings.globalize_path("user://logs")
	DirAccess.make_dir_recursive_absolute(log_dir)
	DirAccess.make_dir_absolute(lock_path)
	var owner = "owner-a"
	var owner_file = FileAccess.open(lock_path + "/lock_owner", FileAccess.WRITE)
	if owner_file == null:
		_expect(false, "claimed-lock cleanup owner should be writable", results)
		return
	owner_file.store_string(owner)
	owner_file.close()
	var ts_file = FileAccess.open(lock_path + "/lock_time", FileAccess.WRITE)
	if ts_file == null:
		_expect(false, "claimed-lock cleanup timestamp should be writable", results)
		return
	ts_file.store_string(str(int(Time.get_unix_time_from_system() * 1000.0)))
	ts_file.close()
	var claimed_path = OgsLogger._claim_lock_for_cleanup(lock_path, owner)
	if claimed_path.is_empty():
		_expect(false, "claimed-lock cleanup should move owned lock directory", results)
		return
	DirAccess.make_dir_absolute(lock_path)
	var replacement_owner = FileAccess.open(lock_path + "/lock_owner", FileAccess.WRITE)
	if replacement_owner == null:
		_expect(false, "replacement owner file should be writable", results)
		return
	replacement_owner.store_string("owner-b")
	replacement_owner.close()
	OgsLogger._remove_lock_directory_contents(claimed_path)
	DirAccess.remove_absolute(claimed_path)
	_expect(DirAccess.dir_exists_absolute(lock_path), "replacement owner directory should remain after claimed-lock cleanup", results)
	var replacement_owner_read = OgsLogger._read_log_create_lock_owner(lock_path)
	_expect(replacement_owner_read == "owner-b", "replacement owner token should remain intact", results)
	OgsLogger._force_remove_stale_lock(lock_path)

func _test_ownerless_stale_cleanup_does_not_delete_live_lock(results: Dictionary) -> void:
	## Verifies ownerless stale cleanup avoids deleting a lock with no owner token.
	OgsLogger.clear_logs_for_tests()
	var log_path = "user://logs/ogs_launcher.log"
	var lock_path = ProjectSettings.globalize_path(log_path) + ".create_lock"
	var log_dir = ProjectSettings.globalize_path("user://logs")
	DirAccess.make_dir_recursive_absolute(log_dir)
	DirAccess.make_dir_absolute(lock_path)
	var ts_file = FileAccess.open(lock_path + "/lock_time", FileAccess.WRITE)
	if ts_file == null:
		_expect(false, "ownerless lock timestamp should be writable", results)
		return
	ts_file.store_string(str(int(Time.get_unix_time_from_system() * 1000.0)))
	ts_file.close()
	OgsLogger._force_remove_stale_lock(lock_path)
	_expect(DirAccess.dir_exists_absolute(lock_path), "ownerless lock should remain when owner token is missing", results)
	OgsLogger._remove_lock_directory_contents(lock_path)
	DirAccess.remove_absolute(lock_path)

func _test_ownerless_stale_cleanup_removes_stale_lock(results: Dictionary) -> void:
	## Verifies ownerless stale cleanup removes a validated stale lock directory.
	OgsLogger.clear_logs_for_tests()
	var log_path = "user://logs/ogs_launcher.log"
	var lock_path = ProjectSettings.globalize_path(log_path) + ".create_lock"
	var log_dir = ProjectSettings.globalize_path("user://logs")
	DirAccess.make_dir_recursive_absolute(log_dir)
	DirAccess.make_dir_absolute(lock_path)
	var ts_file = FileAccess.open(lock_path + "/lock_time", FileAccess.WRITE)
	if ts_file == null:
		_expect(false, "stale ownerless lock timestamp should be writable", results)
		return
	ts_file.store_string(str(int(Time.get_unix_time_from_system() * 1000.0) - 10000))
	ts_file.close()
	OgsLogger._force_remove_stale_lock(lock_path)
	_expect(not DirAccess.dir_exists_absolute(lock_path), "stale ownerless lock should be removed after validation", results)

func _test_write_aborts_when_lock_refresh_fails(results: Dictionary) -> void:
	## Verifies lock ownership loss aborts append before writing.
	OgsLogger.clear_logs_for_tests()
	OgsLogger.set_level(OgsLogger.Level.INFO)
	var log_path = "user://logs/ogs_launcher.log"
	var existing = FileAccess.open(log_path, FileAccess.WRITE)
	if existing == null:
		_expect(false, "existing log should be creatable for refresh-failure test", results)
		return
	existing.store_string("existing entry\n")
	existing.close()
	OgsLogger.set_lock_refresh_failure_call_for_tests(1)
	OgsLogger.info("should not be written after refresh failure", {"component": "test"})
	OgsLogger.clear_lock_refresh_failure_override_for_tests()
	var file = FileAccess.open(log_path, FileAccess.READ)
	if file == null:
		_expect(false, "existing log should remain readable after refresh failure", results)
		return
	var contents = file.get_as_text()
	file.close()
	_expect(contents == "existing entry\n", "refresh failure should abort append without modifying existing log", results)
	_expect(contents.find("should not be written after refresh failure") == -1, "refresh failure should not write the aborted entry", results)

func _test_rotation_runs_after_pending_create_lock(results: Dictionary) -> void:
	## Verifies an oversized log still rotates after waiting on a pending create lock.
	OgsLogger.clear_logs_for_tests()
	OgsLogger.set_level(OgsLogger.Level.INFO)
	var log_path = "user://logs/ogs_launcher.log"
	var log_dir = ProjectSettings.globalize_path("user://logs")
	DirAccess.make_dir_recursive_absolute(log_dir)
	var existing = FileAccess.open(log_path, FileAccess.WRITE)
	if existing == null:
		_expect(false, "oversized log should be creatable for rotation contention test", results)
		return
	var original_contents = "oversized entry\n" + "x".repeat(OgsLogger.MAX_BYTES + 16)
	existing.store_string(original_contents)
	existing.close()
	var lock_path = ProjectSettings.globalize_path(log_path) + ".create_lock"
	DirAccess.make_dir_absolute(lock_path)
	var ts_file = FileAccess.open(lock_path + "/lock_time", FileAccess.WRITE)
	if ts_file == null:
		_expect(false, "rotation contention timestamp should be writable", results)
		return
	ts_file.store_string(str(int(Time.get_unix_time_from_system() * 1000.0)))
	ts_file.close()
	var owner_file = FileAccess.open(lock_path + "/lock_owner", FileAccess.WRITE)
	if owner_file == null:
		_expect(false, "rotation contention owner should be writable", results)
		return
	owner_file.store_string("active-owner")
	owner_file.close()
	var release_delay_msec = OgsLogger.CREATE_LOCK_TIMEOUT_MSEC + 100
	var releaser := Thread.new()
	var start_err = releaser.start(_release_pending_create_lock.bind(lock_path, release_delay_msec))
	if start_err != OK:
		_expect(false, "rotation contention releaser thread should start", results)
		return
	OgsLogger.info("entry after rotation contention", {"component": "test"})
	releaser.wait_to_finish()
	var rotated_path = log_path + ".1"
	_expect(FileAccess.file_exists(rotated_path), "oversized log should rotate after the pending lock clears", results)
	var rotated = FileAccess.open(rotated_path, FileAccess.READ)
	if rotated == null:
		_expect(false, "rotated backup should be readable after contention", results)
		return
	var rotated_contents = rotated.get_as_text()
	rotated.close()
	_expect(rotated_contents == original_contents, "rotation backup should preserve the pre-append oversized contents", results)
	var active = FileAccess.open(log_path, FileAccess.READ)
	if active == null:
		_expect(false, "active log should remain readable after rotation contention", results)
		return
	var active_contents = active.get_as_text()
	active.close()
	_expect(active_contents.find("entry after rotation contention") != -1, "active log should contain the new post-rotation entry", results)
	_expect(active_contents.find("oversized entry") == -1, "active log should only contain the new entry after rotation", results)

func _test_rotation_runs_after_append_crosses_threshold(results: Dictionary) -> void:
	## Verifies append-triggered growth beyond MAX_BYTES rotates immediately.
	OgsLogger.clear_logs_for_tests()
	OgsLogger.set_level(OgsLogger.Level.INFO)
	var log_path = "user://logs/ogs_launcher.log"
	var log_dir = ProjectSettings.globalize_path("user://logs")
	DirAccess.make_dir_recursive_absolute(log_dir)
	var existing = FileAccess.open(log_path, FileAccess.WRITE)
	if existing == null:
		_expect(false, "near-threshold log should be creatable for post-append rotation test", results)
		return
	existing.store_string("near-threshold entry\n" + "y".repeat(OgsLogger.MAX_BYTES - 128))
	existing.close()
	OgsLogger.info("entry crossing threshold " + "z".repeat(512), {"component": "test"})
	var rotated_path = log_path + ".1"
	_expect(FileAccess.file_exists(rotated_path), "append crossing MAX_BYTES should rotate immediately", results)
	var rotated = FileAccess.open(rotated_path, FileAccess.READ)
	if rotated == null:
		_expect(false, "post-append rotated backup should be readable", results)
		return
	var rotated_contents = rotated.get_as_text()
	rotated.close()
	_expect(rotated_contents.find("entry crossing threshold") != -1, "post-append rotation backup should include the appended entry", results)

func _test_rotation_path_aborts_when_lock_refresh_fails(results: Dictionary) -> void:
	## Verifies the pre-rotation ownership refresh aborts without appending.
	OgsLogger.clear_logs_for_tests()
	OgsLogger.set_level(OgsLogger.Level.INFO)
	var log_path = "user://logs/ogs_launcher.log"
	var log_dir = ProjectSettings.globalize_path("user://logs")
	DirAccess.make_dir_recursive_absolute(log_dir)
	var existing = FileAccess.open(log_path, FileAccess.WRITE)
	if existing == null:
		_expect(false, "oversized log should be creatable for rotation refresh-failure test", results)
		return
	existing.store_string("oversized entry\n" + "y".repeat(OgsLogger.MAX_BYTES + 16))
	existing.close()
	OgsLogger.set_lock_refresh_failure_call_for_tests(2)
	OgsLogger.info("entry before skipped rotation", {"component": "test"})
	OgsLogger.clear_lock_refresh_failure_override_for_tests()
	_expect(not FileAccess.file_exists(log_path + ".1"), "rotation backup should not be created after a pre-rotation refresh failure", results)
	var active = FileAccess.open(log_path, FileAccess.READ)
	if active == null:
		_expect(false, "active log should remain readable after pre-rotation refresh failure", results)
		return
	var contents = active.get_as_text()
	active.close()
	_expect(contents.find("oversized entry") != -1, "pre-rotation refresh failure should keep oversized contents in active log", results)
	_expect(contents.find("entry before skipped rotation") == -1, "pre-rotation refresh failure should abort the append", results)

func _test_partial_metadata_init_failure_removes_lock_directory(results: Dictionary) -> void:
	## Verifies a failed metadata write during lock acquisition removes the claimed directory.
	OgsLogger.clear_logs_for_tests()
	OgsLogger.set_level(OgsLogger.Level.INFO)
	var lock_path = ProjectSettings.globalize_path("user://logs/ogs_launcher.log") + ".create_lock"
	OgsLogger.set_open_error_override_for_tests(FileAccess.WRITE, ERR_FILE_NOT_FOUND, 1)
	OgsLogger.info("should not be written due to lock init failure", {"component": "test"})
	OgsLogger.clear_open_error_overrides_for_tests()
	_expect(not DirAccess.dir_exists_absolute(lock_path), "lock directory should be removed after failed metadata init", results)
	OgsLogger.info("should be written after lock init failure recovery", {"component": "test"})
	var log_path = "user://logs/ogs_launcher.log"
	_expect(FileAccess.file_exists(log_path), "log should be written after recovery from lock init failure", results)
	var file = FileAccess.open(log_path, FileAccess.READ)
	if file == null:
		_expect(false, "log should be readable after recovery", results)
		return
	var contents = file.get_as_text()
	file.close()
	_expect(contents.find("should not be written due to lock init failure") == -1, "failed-init entry should not appear in log", results)
	_expect(contents.find("should be written after lock init failure recovery") != -1, "recovery entry should appear in log", results)

func _release_pending_create_lock(lock_path: String, delay_msec: int) -> void:
	## Releases a synthetic pending create-lock after a caller-controlled delay.
	OS.delay_msec(delay_msec)
	DirAccess.remove_absolute(lock_path + "/lock_time")
	DirAccess.remove_absolute(lock_path + "/lock_owner")
	DirAccess.remove_absolute(lock_path)

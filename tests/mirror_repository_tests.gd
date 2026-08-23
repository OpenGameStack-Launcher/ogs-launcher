## MirrorRepositoryTests: Unit tests for MirrorRepository schema validation.

extends RefCounted
class_name MirrorRepositoryTests

const MirrorRepositoryScript = preload("res://scripts/mirror/mirror_repository.gd")

func run() -> Dictionary:
	"""Runs MirrorRepository unit tests."""
	var results = {"passed": 0, "failed": 0, "failures": []}
	_test_valid_repository(results)
	_test_missing_required_fields(results)
	_test_archive_url_repository(results)
	_test_missing_archive_source(results)
	_test_missing_sha256(results)
	_test_invalid_sha256(results)
	_test_valid_category(results)
	_test_invalid_category(results)
	_test_missing_category(results)
	_test_valid_info_url(results)
	_test_invalid_info_url(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	"""Records test assertions."""
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_valid_repository(results: Dictionary) -> void:
	"""Valid repository should pass validation."""
	var data = {
		"schema_version": 1,
		"mirror_name": "OGS Standard Profile",
		"tools": [
			{"id": "godot", "version": "4.3", "archive_path": "tools/godot/4.3/godot.zip", "executable_path": "godot.exe", "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}
		]
	}
	var repo = MirrorRepositoryScript.from_dict(data)
	_expect(repo.is_valid(), "valid repository should pass", results)

func _test_missing_required_fields(results: Dictionary) -> void:
	"""Repository missing required fields should fail validation."""
	var data = {"schema_version": 1, "mirror_name": "", "tools": []}
	var errors = MirrorRepositoryScript.validate_data(data)
	_expect(errors.has("mirror_name_empty"), "should flag empty mirror_name", results)
	_expect(errors.has("tools_empty"), "should flag empty tools array", results)

func _test_archive_url_repository(results: Dictionary) -> void:
	"""Repository with archive_url should pass validation."""
	var data = {
		"schema_version": 1,
		"mirror_name": "OGS Remote",
		"tools": [
			{"id": "godot", "version": "4.3", "archive_url": "https://example.com/godot.zip", "executable_path": "godot.exe", "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}
		]
	}
	var repo = MirrorRepositoryScript.from_dict(data)
	_expect(repo.is_valid(), "archive_url repository should pass", results)

func _test_missing_archive_source(results: Dictionary) -> void:
	"""Repository entries missing archive_path and archive_url should fail."""
	var data = {
		"schema_version": 1,
		"mirror_name": "OGS",
		"tools": [
			{"id": "godot", "version": "4.3"}
		]
	}
	var errors = MirrorRepositoryScript.validate_data(data)
	_expect(errors.has("tool_archive_source_missing:0"), "should flag missing archive source", results)

func _test_missing_sha256(results: Dictionary) -> void:
	"""Missing sha256 should be rejected."""
	var data = {
		"schema_version": 1,
		"mirror_name": "OGS",
		"tools": [
			{"id": "godot", "version": "4.3", "archive_path": "tools/godot/4.3/godot.zip", "executable_path": "godot.exe"}
		]
	}
	var errors = MirrorRepositoryScript.validate_data(data)
	_expect(errors.has("tool_sha256_missing:0"), "should flag missing sha256", results)

func _test_invalid_sha256(results: Dictionary) -> void:
	"""Invalid sha256 should be rejected when present."""
	var data = {
		"schema_version": 1,
		"mirror_name": "OGS",
		"tools": [
			{"id": "godot", "version": "4.3", "archive_path": "tools/godot/4.3/godot.zip", "executable_path": "godot.exe", "sha256": "bad"}
		]
	}
	var errors = MirrorRepositoryScript.validate_data(data)
	_expect(errors.has("tool_sha256_invalid:0"), "should flag invalid sha256", results)

func _test_valid_category(results: Dictionary) -> void:
	"""Valid category field should be accepted."""
	var data = {
		"schema_version": 1,
		"mirror_name": "OGS",
		"tools": [
			{"id": "godot", "version": "4.3", "category": "Engine", "archive_path": "tools/godot/4.3/godot.zip", "executable_path": "godot.exe", "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}
		]
	}
	var repo = MirrorRepositoryScript.from_dict(data)
	_expect(repo.is_valid(), "valid category should be accepted", results)

func _test_invalid_category(results: Dictionary) -> void:
	"""Empty category string should be rejected."""
	var data = {
		"schema_version": 1,
		"mirror_name": "OGS",
		"tools": [
			{"id": "godot", "version": "4.3", "category": "", "archive_path": "tools/godot/4.3/godot.zip", "executable_path": "godot.exe", "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}
		]
	}
	var errors = MirrorRepositoryScript.validate_data(data)
	_expect(errors.has("tool_category_invalid:0"), "should flag empty category", results)

func _test_missing_category(results: Dictionary) -> void:
	"""Missing category field should be allowed (optional field)."""
	var data = {
		"schema_version": 1,
		"mirror_name": "OGS",
		"tools": [
			{"id": "godot", "version": "4.3", "archive_path": "tools/godot/4.3/godot.zip", "executable_path": "godot.exe", "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}
		]
	}
	var repo = MirrorRepositoryScript.from_dict(data)
	_expect(repo.is_valid(), "missing category should be allowed", results)

func _test_valid_info_url(results: Dictionary) -> void:
	"""Valid info_url field should be accepted."""
	var data = {
		"schema_version": 1,
		"mirror_name": "OGS",
		"tools": [
			{"id": "godot", "version": "4.3", "info_url": "https://godotengine.org/releases/4.3/", "archive_path": "tools/godot/4.3/godot.zip", "executable_path": "godot.exe", "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}
		]
	}
	var repo = MirrorRepositoryScript.from_dict(data)
	_expect(repo.is_valid(), "valid info_url should be accepted", results)

func _test_invalid_info_url(results: Dictionary) -> void:
	"""Empty info_url string should be rejected."""
	var data = {
		"schema_version": 1,
		"mirror_name": "OGS",
		"tools": [
			{"id": "godot", "version": "4.3", "info_url": "", "archive_path": "tools/godot/4.3/godot.zip", "executable_path": "godot.exe", "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}
		]
	}
	var errors = MirrorRepositoryScript.validate_data(data)
	_expect(errors.has("tool_info_url_invalid:0"), "should flag empty info_url", results)

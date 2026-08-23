## MirrorPathResolverTests: Unit tests for MirrorPathResolver path validation.

extends RefCounted
class_name MirrorPathResolverTests

const MirrorPathResolverScript = preload("res://scripts/mirror/mirror_path_resolver.gd")

func run() -> Dictionary:
	## Runs MirrorPathResolver unit tests.
	var results = {"passed": 0, "failed": 0, "failures": []}
	_test_get_mirror_root(results)
	_test_reject_absolute_path(results)
	_test_reject_traversal(results)
	_test_accept_relative(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records test assertions.
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_get_mirror_root(results: Dictionary) -> void:
	## Mirror root should be non-empty when environment variables exist.
	var resolver = MirrorPathResolverScript.new()
	var root = resolver.get_mirror_root()
	_expect(not root.is_empty(), "mirror root should not be empty", results)

func _test_reject_absolute_path(results: Dictionary) -> void:
	## Absolute archive paths should be rejected.
	var resolver = MirrorPathResolverScript.new()
	var result = resolver.resolve_archive_path("C:/Mirror", "C:/bad.zip")
	_expect(not result["success"], "absolute path should be rejected", results)

func _test_reject_traversal(results: Dictionary) -> void:
	## Archive paths that escape mirror root should be rejected.
	var resolver = MirrorPathResolverScript.new()
	var result = resolver.resolve_archive_path("C:/Mirror", "../bad.zip")
	_expect(not result["success"], "path traversal should be rejected", results)

func _test_accept_relative(results: Dictionary) -> void:
	## Relative archive paths should resolve under mirror root.
	var resolver = MirrorPathResolverScript.new()
	var result = resolver.resolve_archive_path("C:/Mirror", "tools/godot/4.3/godot.zip")
	_expect(result["success"], "relative path should resolve", results)

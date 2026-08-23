## MirrorHydratorTests: Unit tests for MirrorHydrator behavior.

extends RefCounted
class_name MirrorHydratorTests

const MirrorHydratorScript = preload("res://scripts/mirror/mirror_hydrator.gd")

func run() -> Dictionary:
	## Runs MirrorHydrator unit tests.
## Returns:
## Dictionary: {"passed": int, "failed": int, "failures": Array[String]}
	var results = {"passed": 0, "failed": 0, "failures": []}
	_test_missing_repository(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records test assertions.
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_missing_repository(results: Dictionary) -> void:
	## Hydration should fail if repository.json is missing.
	var temp_root = OS.get_user_data_dir().path_join("mirror_test_missing")
	if not DirAccess.dir_exists_absolute(temp_root):
		DirAccess.make_dir_recursive_absolute(temp_root)
	var hydrator = MirrorHydratorScript.new(temp_root)
	var result = hydrator.hydrate([
		{"tool_id": "godot", "version": "4.3"}
	])
	_expect(result["success"] == false, "hydration should fail without repository.json", results)
	_expect(result["failed_count"] == 1, "failed_count should be 1", results)
	DirAccess.remove_absolute(temp_root)

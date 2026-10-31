## PathUtilsTests: Unit tests for PathUtils path normalization and validation
##
## Verifies path separator normalization, whitespace trimming,
## redundant slash removal, and root confinement validation.

extends RefCounted
class_name PathUtilsTests

func run() -> Dictionary:
	## Runs all PathUtils test cases and aggregates results.
	var results := {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	_test_format_mixed_separators(results)
	_test_format_pure_backslashes(results)
	_test_format_pure_forward_slashes(results)
	_test_format_repeated_and_trailing_slashes(results)
	_test_format_empty_and_whitespace(results)
	_test_format_relative_paths(results)
	_test_format_godot_uris(results)
	_test_is_path_under_root(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records assertion outcome.
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_format_mixed_separators(results: Dictionary) -> void:
	## Verifies that mixed Windows backslashes and Unix forward slashes are normalized.
	var input1: String = "C:\\Users\\kevin\\AppData\\Local/OGS/Projects/MyGame"
	var expected1: String = "C:/Users/kevin/AppData/Local/OGS/Projects/MyGame"
	var actual1: String = PathUtils.format_for_display(input1)
	_expect(actual1 == expected1, "Mixed slashes input1 should normalize to forward slashes: got %s" % actual1, results)

	var input2: String = "C:\\Users/kevin/OGS_Projects"
	var expected2: String = "C:/Users/kevin/OGS_Projects"
	var actual2: String = PathUtils.format_for_display(input2)
	_expect(actual2 == expected2, "Mixed slashes input2 should normalize to forward slashes: got %s" % actual2, results)

	var input3: String = "C:\\Users\\name/OGS/Projects"
	var expected3: String = "C:/Users/name/OGS/Projects"
	var actual3: String = PathUtils.format_for_display(input3)
	_expect(actual3 == expected3, "Mixed slashes input3 should normalize to forward slashes: got %s" % actual3, results)

func _test_format_pure_backslashes(results: Dictionary) -> void:
	## Verifies that Windows-style backslash paths are converted to forward slashes.
	var input1: String = "C:\\Users\\kevin\\AppData\\Local\\OGS\\Projects"
	var expected1: String = "C:/Users/kevin/AppData/Local/OGS/Projects"
	var actual1: String = PathUtils.format_for_display(input1)
	_expect(actual1 == expected1, "Pure backslashes should convert to forward slashes: got %s" % actual1, results)

	var input2: String = "C:\\"
	var expected2: String = "C:/"
	var actual2: String = PathUtils.format_for_display(input2)
	_expect(actual2 == expected2, "Root drive backslash should convert to root forward slash: got %s" % actual2, results)

func _test_format_pure_forward_slashes(results: Dictionary) -> void:
	## Verifies that already-forward-slashed paths are preserved.
	var input1: String = "C:/Users/kevin/AppData/Local/OGS/Projects"
	var expected1: String = "C:/Users/kevin/AppData/Local/OGS/Projects"
	var actual1: String = PathUtils.format_for_display(input1)
	_expect(actual1 == expected1, "Pure forward slashes should be preserved: got %s" % actual1, results)

	var input2: String = "/unix/root/path/to/project"
	var expected2: String = "/unix/root/path/to/project"
	var actual2: String = PathUtils.format_for_display(input2)
	_expect(actual2 == expected2, "Unix path should be preserved: got %s" % actual2, results)

	var input3: String = "/"
	var expected3: String = "/"
	var actual3: String = PathUtils.format_for_display(input3)
	_expect(actual3 == expected3, "Unix root slash should be preserved: got %s" % actual3, results)

func _test_format_repeated_and_trailing_slashes(results: Dictionary) -> void:
	## Verifies that repeated slashes are collapsed and non-root trailing slashes are removed.
	var input1: String = "C:\\Users\\\\name///OGS//Projects//"
	var expected1: String = "C:/Users/name/OGS/Projects"
	var actual1: String = PathUtils.format_for_display(input1)
	_expect(actual1 == expected1, "Repeated and trailing slashes should be collapsed: got %s" % actual1, results)

	var input2: String = "some//path///with////multiple/////slashes/"
	var expected2: String = "some/path/with/multiple/slashes"
	var actual2: String = PathUtils.format_for_display(input2)
	_expect(actual2 == expected2, "Multiple slashes should collapse into single slashes: got %s" % actual2, results)

func _test_format_empty_and_whitespace(results: Dictionary) -> void:
	## Verifies that empty strings and whitespace are handled safely.
	_expect(PathUtils.format_for_display("") == "", "Empty string should return empty string", results)
	_expect(PathUtils.format_for_display("   ") == "", "Whitespace string should return empty string", results)
	_expect(PathUtils.format_for_display("\t  \n  ") == "", "Whitespace with tabs and newlines should return empty string", results)

	var input: String = "   C:\\Users\\name/OGS/Projects   "
	var expected: String = "C:/Users/name/OGS/Projects"
	var actual: String = PathUtils.format_for_display(input)
	_expect(actual == expected, "Leading and trailing whitespace should be trimmed: got %s" % actual, results)

func _test_format_relative_paths(results: Dictionary) -> void:
	## Verifies that relative paths with mixed or repeated slashes normalize cleanly.
	var input1: String = "relative\\path/to\\project"
	var expected1: String = "relative/path/to/project"
	var actual1: String = PathUtils.format_for_display(input1)
	_expect(actual1 == expected1, "Relative path should normalize: got %s" % actual1, results)

	var input2: String = "./relative/path/to/project"
	var expected2: String = "relative/path/to/project"
	var actual2: String = PathUtils.format_for_display(input2)
	_expect(actual2 == expected2, "Leading dot-slash should simplify: got %s" % actual2, results)

	var input3: String = "some/nested/../path"
	var expected3: String = "some/path"
	var actual3: String = PathUtils.format_for_display(input3)
	_expect(actual3 == expected3, "Parent traversal in relative path should simplify: got %s" % actual3, results)

func _test_format_godot_uris(results: Dictionary) -> void:
	## Verifies that Godot URIs (res:// and user://) preserve scheme formatting.
	var input1: String = "res://tests\\test_runner.gd"
	var expected1: String = "res://tests/test_runner.gd"
	var actual1: String = PathUtils.format_for_display(input1)
	_expect(actual1 == expected1, "res:// URI with backslashes should normalize: got %s" % actual1, results)

	var input2: String = "user://test_projects\\my-game"
	var expected2: String = "user://test_projects/my-game"
	var actual2: String = PathUtils.format_for_display(input2)
	_expect(actual2 == expected2, "user:// URI with backslashes should normalize: got %s" % actual2, results)

func _test_is_path_under_root(results: Dictionary) -> void:
	## Verifies that existing is_path_under_root functionality remains intact.
	_expect(PathUtils.is_path_under_root("C:/app/projects/game", "C:/app/projects"), "Child path under root should return true", results)
	_expect(PathUtils.is_path_under_root("C:\\app\\projects\\game", "C:/app/projects"), "Child path with backslashes under root should return true", results)
	_expect(PathUtils.is_path_under_root("C:/app/other/game", "C:/app/projects") == false, "Disjoint path under root should return false", results)
	_expect(PathUtils.is_path_under_root("", "C:/app/projects") == false, "Empty path should return false", results)
	_expect(PathUtils.is_path_under_root("C:/app/projects", "") == false, "Empty root should return false", results)

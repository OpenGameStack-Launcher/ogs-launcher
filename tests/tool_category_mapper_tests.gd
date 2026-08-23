## ToolCategoryMapperTests: Unit tests for ToolCategoryMapper fallback logic.

extends RefCounted
class_name ToolCategoryMapperTests

const ToolCategoryMapperScript = preload("res://scripts/tools/tool_category_mapper.gd")

func run() -> Dictionary:
	## Runs ToolCategoryMapper unit tests.
	var results = {"passed": 0, "failed": 0, "failures": []}
	_test_fallback_mapping(results)
	_test_unknown_tool(results)
	_test_category_from_tool_entry(results)
	_test_fallback_when_category_missing(results)
	_test_fallback_when_category_empty(results)
	_test_get_all_categories(results)
	_test_is_valid_category(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	## Records test assertions.
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_fallback_mapping(results: Dictionary) -> void:
	## Fallback mapping should return correct categories for known tools.
	_expect(ToolCategoryMapperScript.get_category("godot") == "Engine", "godot should map to Engine", results)
	_expect(ToolCategoryMapperScript.get_category("blender") == "3D", "blender should map to 3D", results)
	_expect(ToolCategoryMapperScript.get_category("krita") == "2D", "krita should map to 2D", results)
	_expect(ToolCategoryMapperScript.get_category("audacity") == "Audio", "audacity should map to Audio", results)

func _test_unknown_tool(results: Dictionary) -> void:
	## Unknown tools should return 'Unknown' category.
	_expect(ToolCategoryMapperScript.get_category("unknown_tool") == "Unknown", "unknown tool should return Unknown", results)

func _test_category_from_tool_entry(results: Dictionary) -> void:
	## Should use category field from tool entry when present.
	var tool_entry = {"id": "godot", "version": "4.3", "category": "CustomCategory"}
	_expect(ToolCategoryMapperScript.get_category_for_tool(tool_entry) == "CustomCategory", "should use category field", results)

func _test_fallback_when_category_missing(results: Dictionary) -> void:
	## Should fall back to ID-based mapping when category field missing.
	var tool_entry = {"id": "godot", "version": "4.3"}
	_expect(ToolCategoryMapperScript.get_category_for_tool(tool_entry) == "Engine", "should fall back to ID mapping", results)

func _test_fallback_when_category_empty(results: Dictionary) -> void:
	## Should fall back to ID-based mapping when category field is empty.
	var tool_entry = {"id": "blender", "version": "4.2", "category": ""}
	_expect(ToolCategoryMapperScript.get_category_for_tool(tool_entry) == "3D", "should fall back when category empty", results)

func _test_get_all_categories(results: Dictionary) -> void:
	## Should return all supported categories.
	var categories = ToolCategoryMapperScript.get_all_categories()
	_expect(categories.size() == 4, "should have 4 categories", results)
	_expect("Engine" in categories, "should include Engine", results)
	_expect("2D" in categories, "should include 2D", results)
	_expect("3D" in categories, "should include 3D", results)
	_expect("Audio" in categories, "should include Audio", results)

func _test_is_valid_category(results: Dictionary) -> void:
	## Should validate category names correctly.
	_expect(ToolCategoryMapperScript.is_valid_category("Engine"), "Engine should be valid", results)
	_expect(ToolCategoryMapperScript.is_valid_category("2D"), "2D should be valid", results)
	_expect(ToolCategoryMapperScript.is_valid_category("3D"), "3D should be valid", results)
	_expect(ToolCategoryMapperScript.is_valid_category("Audio"), "Audio should be valid", results)
	_expect(not ToolCategoryMapperScript.is_valid_category("Unknown"), "Unknown should be invalid", results)
	_expect(not ToolCategoryMapperScript.is_valid_category("CustomCategory"), "CustomCategory should be invalid", results)

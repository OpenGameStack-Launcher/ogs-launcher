## FileTypeMapperTests: Automated unit tests for FileTypeMapper extension mapping and exclusions.

extends RefCounted
class_name FileTypeMapperTests

const FileTypeMapperScript = preload("res://scripts/tools/file_type_mapper.gd")

func run() -> Dictionary:
	## Runs all FileTypeMapper automated tests.
	var results: Dictionary = {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	_test_vscodium_supported_extensions(results)
	_test_metadata_exclusions(results)
	_test_get_tool_for_file_with_active_tools(results)
	_test_get_extension_for_tool(results)
	return results

func _expect(condition: bool, message: String, results: Dictionary) -> void:
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

func _test_vscodium_supported_extensions(results: Dictionary) -> void:
	var expected_exts: Array[String] = [
		"gd", "cs", "gdshader", "shader", "txt", "md", "csv", "json", "yaml", "yml", "toml"
	]
	for ext: String in expected_exts:
		_expect(FileTypeMapperScript.is_vscodium_extension(ext), "ext '%s' should be recognized as vscodium extension" % ext, results)
		_expect(FileTypeMapperScript.is_vscodium_extension(ext.to_upper()), "uppercase ext '%s' should be recognized" % ext, results)

	_expect(not FileTypeMapperScript.is_vscodium_extension("png"), "png should not be vscodium extension", results)
	_expect(not FileTypeMapperScript.is_vscodium_extension("exe"), "exe should not be vscodium extension", results)
	_expect(not FileTypeMapperScript.is_vscodium_extension("tscn"), "tscn should not be vscodium extension", results)
	_expect(not FileTypeMapperScript.is_vscodium_extension("tres"), "tres should not be vscodium extension", results)
	_expect(not FileTypeMapperScript.is_vscodium_extension(""), "empty ext should not be vscodium extension", results)

func _test_metadata_exclusions(results: Dictionary) -> void:
	var excluded_files: Array[String] = [
		"stack.json", "STACK.JSON", "C:/path/stack.json",
		"ogs_config.json", "OGS_CONFIG.JSON", "res://ogs_config.json",
		"ogs_metadata.json", "C:/tool/ogs_metadata.json",
		"sprite.png.import", ".import",
		"player.gd.uid", ".uid",
		"export_presets.cfg", "config.cfg",
		"main_scene.tscn", "gui.tscn",
		"theme.tres", "material.tres"
	]
	for f: String in excluded_files:
		_expect(FileTypeMapperScript.is_excluded_file(f), "file '%s' should be excluded as metadata" % f, results)
		_expect(FileTypeMapperScript.get_tool_for_file(f, ["vscodium", "godot"]) == "", "excluded file '%s' should return empty tool ID even with tools active" % f, results)

	var allowed_files: Array[String] = [
		"custom.json", "notes.txt", "player.gd", "hero.xcf", "model.blend", "project.godot"
	]
	for f: String in allowed_files:
		_expect(not FileTypeMapperScript.is_excluded_file(f), "file '%s' should not be excluded" % f, results)

func _test_get_tool_for_file_with_active_tools(results: Dictionary) -> void:
	# Direct query (empty active_tool_ids)
	_expect(FileTypeMapperScript.get_tool_for_file("notes.txt") == "vscodium", "direct query should map txt to vscodium", results)
	_expect(FileTypeMapperScript.get_tool_for_file("player.gd") == "vscodium", "direct query should map gd to vscodium", results)
	_expect(FileTypeMapperScript.get_tool_for_file("data.json") == "vscodium", "direct query should map json to vscodium", results)
	_expect(FileTypeMapperScript.get_tool_for_file("project.godot") == "godot", "direct query should map project.godot to godot", results)
	_expect(FileTypeMapperScript.get_tool_for_file("hero.xcf") == "gimp", "direct query should map xcf to gimp", results)
	_expect(FileTypeMapperScript.get_tool_for_file("model.blend") == "blender", "direct query should map blend to blender", results)

	# Active tools without vscodium
	var godot_only: Array = ["godot"]
	_expect(FileTypeMapperScript.get_tool_for_file("notes.txt", godot_only) == "", "txt should return empty when vscodium not in stack", results)
	_expect(FileTypeMapperScript.get_tool_for_file("player.gd", godot_only) == "", "gd should return empty when vscodium not in stack", results)
	_expect(FileTypeMapperScript.get_tool_for_file("data.json", godot_only) == "", "json should return empty when vscodium not in stack", results)
	_expect(FileTypeMapperScript.get_tool_for_file("project.godot", godot_only) == "godot", "project.godot should map to godot", results)
	_expect(FileTypeMapperScript.get_tool_for_file("hero.xcf", godot_only) == "gimp", "hero.xcf should map to gimp", results)

	# Active tools with vscodium
	var with_codium: Array = ["godot", "vscodium"]
	_expect(FileTypeMapperScript.get_tool_for_file("notes.txt", with_codium) == "vscodium", "txt should return vscodium when in stack", results)
	_expect(FileTypeMapperScript.get_tool_for_file("player.gd", with_codium) == "vscodium", "gd should return vscodium when in stack", results)
	_expect(FileTypeMapperScript.get_tool_for_file("data.json", with_codium) == "vscodium", "json should return vscodium when in stack", results)
	_expect(FileTypeMapperScript.get_tool_for_file("shader.gdshader", with_codium) == "vscodium", "gdshader should return vscodium when in stack", results)
	_expect(FileTypeMapperScript.get_tool_for_file("config.toml", with_codium) == "vscodium", "toml should return vscodium when in stack", results)
	_expect(FileTypeMapperScript.get_tool_for_file("project.godot", with_codium) == "godot", "project.godot should map to godot", results)
	_expect(FileTypeMapperScript.get_tool_for_file("hero.xcf", with_codium) == "gimp", "hero.xcf should map to gimp", results)

func _test_get_extension_for_tool(results: Dictionary) -> void:
	_expect(FileTypeMapperScript.get_extension_for_tool("vscodium") == "txt", "vscodium extension should be txt", results)
	_expect(FileTypeMapperScript.get_extension_for_tool("VSCODIUM") == "txt", "VSCODIUM case-insensitive should return txt", results)
	_expect(FileTypeMapperScript.get_extension_for_tool("gimp") == "xcf", "gimp extension should be xcf", results)
	_expect(FileTypeMapperScript.get_extension_for_tool("blender") == "blend", "blender extension should be blend", results)
	_expect(FileTypeMapperScript.get_extension_for_tool("krita") == "kra", "krita extension should be kra", results)
	_expect(FileTypeMapperScript.get_extension_for_tool("audacity") == "aup3", "audacity extension should be aup3", results)
	_expect(FileTypeMapperScript.get_extension_for_tool("godot") == "", "godot extension should be empty", results)

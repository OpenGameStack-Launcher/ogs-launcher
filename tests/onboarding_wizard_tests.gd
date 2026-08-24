## OnboardingWizardTests: Verifies first-run detection behavior.
##
## Covers both should_show_wizard() branches introduced for directory
## iteration cleanup behavior.

extends RefCounted
class_name OnboardingWizardTests

func run() -> Dictionary:
	## Runs all onboarding wizard behavior tests.
	var results = {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	
	var tests = [
		{"name": "test_should_show_wizard_returns_false_when_library_has_visible_entry", "func": test_should_show_wizard_returns_false_when_library_has_visible_entry},
		{"name": "test_should_show_wizard_returns_true_when_library_only_has_hidden_entries", "func": test_should_show_wizard_returns_true_when_library_only_has_hidden_entries},
	]
	
	for test in tests:
		var result = test.func.call()
		if result["passed"]:
			results["passed"] += 1
		else:
			results["failed"] += 1
			results["failures"].append("%s: %s" % [test["name"], result["error"]])
	
	return results

func test_should_show_wizard_returns_false_when_library_has_visible_entry() -> Dictionary:
	## Verifies populated libraries skip the first-run wizard.
	var test_root = _create_temp_library_root("populated")
	var tool_dir = test_root.path_join("godot")
	DirAccess.make_dir_recursive_absolute(tool_dir)
	
	var wizard = OnboardingWizard.new()
	wizard.library_root = test_root
	wizard.wizard_complete_flag_path = test_root.path_join("wizard_complete.txt")
	var should_show = wizard.should_show_wizard()
	
	_remove_directory_recursive(test_root)
	if should_show:
		return {"passed": false, "error": "Wizard should not show when a visible tool directory exists"}
	return {"passed": true}

func test_should_show_wizard_returns_true_when_library_only_has_hidden_entries() -> Dictionary:
	## Verifies hidden-only library entries still count as first run.
	var test_root = _create_temp_library_root("hidden_only")
	var hidden_dir = test_root.path_join(".hidden")
	DirAccess.make_dir_recursive_absolute(hidden_dir)
	var hidden_file = FileAccess.open(test_root.path_join(".keep"), FileAccess.WRITE)
	if hidden_file != null:
		hidden_file.store_string("hidden marker")
	
	var wizard = OnboardingWizard.new()
	wizard.library_root = test_root
	wizard.wizard_complete_flag_path = test_root.path_join("wizard_complete.txt")
	var should_show = wizard.should_show_wizard()
	
	_remove_directory_recursive(test_root)
	if not should_show:
		return {"passed": false, "error": "Wizard should show when library has only hidden entries"}
	return {"passed": true}

func _create_temp_library_root(suffix: String) -> String:
	## Creates a unique temp library directory for a test case.
	var base_root = ProjectSettings.globalize_path("user://onboarding_wizard_tests")
	var test_root = base_root.path_join("%s_%d" % [suffix, Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(test_root)
	return test_root

func _remove_directory_recursive(path: String) -> void:
	## Removes a directory and all nested contents for test cleanup.
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var child_path = path.path_join(entry)
		if dir.current_is_dir():
			_remove_directory_recursive(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)

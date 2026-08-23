## LibraryHydrator Tests
##
## Unit tests for the LibraryHydrator module.
## Tests cover the hydration workflow, signal handling, and error cases.

extends RefCounted
class_name LibraryHydratorTests

func run() -> Dictionary:
	var results = {
		"passed": 0,
		"failed": 0,
		"failures": []
	}
	
	var tests = [
		{"name": "test_hydrator_initializes", "func": test_hydrator_initializes},
		{"name": "test_hydrate_empty_list_returns_success", "func": test_hydrate_empty_list_returns_success},
		{"name": "test_hydrate_returns_dict", "func": test_hydrate_returns_dict},
		{"name": "test_count_already_installed_returns_int", "func": test_count_already_installed_returns_int},
		{"name": "test_is_mirror_configured_false_when_empty", "func": test_is_mirror_configured_false_when_empty},
		{"name": "test_is_mirror_configured_true_when_set", "func": test_is_mirror_configured_true_when_set},
	]
	
	for test in tests:
		var result = test.func.call()
		if result["passed"]:
			results.passed += 1
		else:
			results.failed += 1
			if result.has("error"):
				results.failures.append("%s: %s" % [test.name, result["error"]])
			else:
				results.failures.append("%s: unknown error" % test.name)
	
	return results

func test_hydrator_initializes() -> Dictionary:
	## Verifies hydrator initializes properly.
	var hydrator = LibraryHydrator.new("https://mirror.ogs.io")
	
	if hydrator == null:
		return {"passed": false, "error": "Hydrator should not be null"}
	
	if hydrator.mirror_url != "https://mirror.ogs.io":
		return {"passed": false, "error": "Mirror URL not set"}
	
	if hydrator.downloader == null:
		return {"passed": false, "error": "ToolDownloader should be initialized"}
	
	if hydrator.library == null:
		return {"passed": false, "error": "LibraryManager should be initialized"}
	
	return {"passed": true}

func test_hydrate_empty_list_returns_success() -> Dictionary:
	## Verifies hydration returns success for empty tool list.
	var hydrator = LibraryHydrator.new("https://mirror.ogs.io")
	var result = hydrator.hydrate([])
	
	if not result["success"]:
		return {"passed": false, "error": "Empty list should return success"}
	
	if result["downloaded_count"] != 0:
		return {"passed": false, "error": "Downloaded count should be 0"}
	
	if result["failed_count"] != 0:
		return {"passed": false, "error": "Failed count should be 0"}
	
	return {"passed": true}

func test_hydrate_returns_dict() -> Dictionary:
	## Verifies hydrate return structure.
	var hydrator = LibraryHydrator.new()
	var result = hydrator.hydrate([])
	
	if not result.has("success"):
		return {"passed": false, "error": "Result missing 'success'"}
	
	if not result.has("downloaded_count"):
		return {"passed": false, "error": "Result missing 'downloaded_count'"}
	
	if not result.has("failed_count"):
		return {"passed": false, "error": "Result missing 'failed_count'"}
	
	if not result.has("failed_tools"):
		return {"passed": false, "error": "Result missing 'failed_tools'"}
	
	return {"passed": true}

func test_count_already_installed_returns_int() -> Dictionary:
	## Verifies count_already_installed returns an integer.
	var hydrator = LibraryHydrator.new()
	var count = hydrator.count_already_installed([])
	
	if not count is int:
		return {"passed": false, "error": "Should return int"}
	
	if count != 0:
		return {"passed": false, "error": "Empty list should return 0"}
	
	return {"passed": true}

func test_is_mirror_configured_false_when_empty() -> Dictionary:
	## Verifies mirror check returns false when empty.
	var hydrator = LibraryHydrator.new("")
	
	if hydrator.is_mirror_configured():
		return {"passed": false, "error": "Empty mirror should return false"}
	
	return {"passed": true}

func test_is_mirror_configured_true_when_set() -> Dictionary:
	## Verifies mirror check returns true when configured.
	var hydrator = LibraryHydrator.new("https://mirror.ogs.io")
	
	if not hydrator.is_mirror_configured():
		return {"passed": false, "error": "Configured mirror should return true"}
	
	return {"passed": true}

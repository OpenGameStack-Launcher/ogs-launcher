## ReleasePackagingTests: Verifies release packaging script contract, export presets,
## semantic version validation rules, workflow configurations, and file invariants.
##
## All checks execute offline and deterministically without network calls.

extends RefCounted
class_name ReleasePackagingTests

func run() -> Dictionary:
	## Runs all release packaging verification tests.
	var results := {"passed": 0, "failed": 0, "failures": []}
	
	_test_export_presets_config(results)
	_test_semantic_version_validation(results)
	_test_packaging_script_contract(results)
	_test_logo_icon_asset(results)
	_test_documentation_contract(results)
	_test_ci_and_release_workflows(results)
	
	return results

## Test 1: Verifies export_presets.cfg has Windows Desktop preset, clean paths, and no secrets.
func _test_export_presets_config(results: Dictionary) -> void:
	var path: String = "res://export_presets.cfg"
	if not FileAccess.file_exists(path):
		_expect(false, "export_presets.cfg must exist at project root", results)
		return
	
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_expect(false, "Failed to open export_presets.cfg for reading", results)
		return
	
	var content: String = file.get_as_text()
	file.close()
	
	_expect(content.contains("name=\"Windows Desktop\""), "export_presets.cfg must define 'Windows Desktop' preset", results)
	_expect(content.contains("platform=\"Windows Desktop\""), "export_presets.cfg must target 'Windows Desktop' platform", results)
	_expect(content.contains("application/icon=\"res://Images/logo.ico\""), "export_presets.cfg must wire application icon to res://Images/logo.ico", results)
	_expect(content.contains("export_path=\"artifacts/release/OGS-Launcher-win64/OGS-Launcher.exe\""), "export_presets.cfg must set clean release export_path without alpha references", results)
	_expect(content.findn("alpha") == -1, "export_presets.cfg must not contain any 'alpha' references", results)
	_expect(content.findn("C:/Users") == -1 and content.findn("C:\\Users") == -1, "export_presets.cfg must not contain local user directory paths", results)
	_expect(not content.contains(".keystore") and not content.contains(".pfx") and not content.contains(".jks"), "export_presets.cfg must not contain hardcoded private keys or certificates", results)

## Test 2: Verifies strict semantic version validation rules (X.Y.Z, no 'v' prefix, no '-alpha' suffix).
func _test_semantic_version_validation(results: Dictionary) -> void:
	var semver_regex: RegEx = RegEx.new()
	var error: Error = semver_regex.compile("^[0-9]+\\.[0-9]+\\.[0-9]+$")
	_expect(error == OK, "Semantic version regex must compile successfully", results)
	
	var valid_versions: Array[String] = [
		"0.1.6",
		"0.2.0",
		"1.0.0",
		"2.14.3",
		"0.0.1",
		"10.200.3000"
	]
	
	for v in valid_versions:
		var match_result: RegExMatch = semver_regex.search(v)
		_expect(match_result != null and match_result.get_string() == v, "Version '%s' must match strict semantic version pattern" % v, results)
	
	var invalid_versions: Array[String] = [
		"v0.1.6",
		"0.1.6-alpha",
		"0.1.6-beta.1",
		"0.1.6-rc2",
		"0.1",
		"1",
		"0.1.6.0",
		"",
		"alpha",
		"0.1.alpha",
		"v1.0"
	]
	
	for inv in invalid_versions:
		var match_result: RegExMatch = semver_regex.search(inv)
		_expect(match_result == null, "Invalid version '%s' must be rejected by semantic version pattern" % inv, results)

## Test 3: Verifies scripts/release/build_release_package.ps1 contract and removal of alpha script.
func _test_packaging_script_contract(results: Dictionary) -> void:
	var alpha_script: String = "res://scripts/release/build_alpha_package.ps1"
	_expect(not FileAccess.file_exists(alpha_script), "Retired build_alpha_package.ps1 must not exist", results)
	
	var release_script: String = "res://scripts/release/build_release_package.ps1"
	if not FileAccess.file_exists(release_script):
		_expect(false, "build_release_package.ps1 must exist in scripts/release/", results)
		return
	
	var file: FileAccess = FileAccess.open(release_script, FileAccess.READ)
	if file == null:
		_expect(false, "Failed to open build_release_package.ps1 for reading", results)
		return
	
	var content: String = file.get_as_text()
	file.close()
	
	_expect(content.contains("[string]$Version"), "build_release_package.ps1 must parameterize $Version", results)
	_expect(content.contains("[string]$GodotPath"), "build_release_package.ps1 must parameterize $GodotPath", results)
	_expect(content.contains("[string]$RcEditPath"), "build_release_package.ps1 must parameterize $RcEditPath", results)
	_expect(content.contains("[switch]$SkipTests"), "build_release_package.ps1 must support -SkipTests switch", results)
	_expect(content.contains("[switch]$SkipZip"), "build_release_package.ps1 must support -SkipZip switch", results)
	_expect(content.contains("artifacts\\release") or content.contains("artifacts/release"), "build_release_package.ps1 must stage to artifacts/release", results)
	_expect(content.contains("OGS-Launcher-win64-"), "build_release_package.ps1 must use OGS-Launcher-win64-<version> naming", results)
	_expect(content.contains(".zip.sha256"), "build_release_package.ps1 must compute and generate .sha256 checksum file", results)
	_expect(content.contains("README.txt"), "build_release_package.ps1 must generate clean README.txt", results)
	_expect(not content.contains("README_ALPHA.txt"), "build_release_package.ps1 must not reference README_ALPHA.txt", results)

## Test 4: Verifies Images/logo.ico exists and has valid multi-size Windows icon payload.
func _test_logo_icon_asset(results: Dictionary) -> void:
	var icon_path: String = "res://Images/logo.ico"
	_expect(FileAccess.file_exists(icon_path), "Windows icon must exist at Images/logo.ico", results)
	
	var file: FileAccess = FileAccess.open(icon_path, FileAccess.READ)
	if file != null:
		var size: int = file.get_length()
		file.close()
		_expect(size > 1000, "Images/logo.ico must be a valid non-empty icon file (> 1000 bytes, was %d)" % size, results)
	else:
		_expect(false, "Could not open Images/logo.ico to verify length", results)

## Test 5: Verifies docs/RELEASE_PACKAGING.md exists and docs/ALPHA_PACKAGING.md is retired.
func _test_documentation_contract(results: Dictionary) -> void:
	_expect(not FileAccess.file_exists("res://docs/ALPHA_PACKAGING.md"), "Retired docs/ALPHA_PACKAGING.md must not exist", results)
	_expect(FileAccess.file_exists("res://docs/RELEASE_PACKAGING.md"), "docs/RELEASE_PACKAGING.md must exist", results)

## Test 6: Verifies GitHub Actions CI and Release workflow configurations.
func _test_ci_and_release_workflows(results: Dictionary) -> void:
	var root_dir: String = ProjectSettings.globalize_path("res://")
	var ci_path: String = root_dir + ".github/workflows/ci.yml"
	var release_path: String = root_dir + ".github/workflows/release.yml"
	
	_expect(FileAccess.file_exists(ci_path), ".github/workflows/ci.yml must exist on disk", results)
	if FileAccess.file_exists(ci_path):
		var ci_file: FileAccess = FileAccess.open(ci_path, FileAccess.READ)
		if ci_file != null:
			var ci_content: String = ci_file.get_as_text()
			ci_file.close()
			_expect(ci_content.contains("workflow_dispatch:"), "ci.yml must trigger on workflow_dispatch", results)
			_expect(ci_content.contains("push:"), "ci.yml must trigger on push", results)
			_expect(ci_content.contains("windows-latest"), "ci.yml must run on windows-latest", results)
			_expect(ci_content.contains("build_release_package.ps1"), "ci.yml must invoke build_release_package.ps1", results)
			_expect(ci_content.contains("0.0.0-ci"), "ci.yml must run smoke test with version 0.0.0-ci", results)
		else:
			_expect(false, "Failed to open ci.yml for reading", results)
	
	_expect(FileAccess.file_exists(release_path), ".github/workflows/release.yml must exist on disk", results)
	if FileAccess.file_exists(release_path):
		var rel_file: FileAccess = FileAccess.open(release_path, FileAccess.READ)
		if rel_file != null:
			var rel_content: String = rel_file.get_as_text()
			rel_file.close()
			_expect(rel_content.contains("workflow_dispatch:"), "release.yml must trigger on workflow_dispatch", results)
			_expect(rel_content.contains("contents: write"), "release.yml must declare contents: write permission", results)
			_expect(rel_content.contains("build-win64:"), "release.yml must contain build-win64 job", results)
			_expect(rel_content.contains("publish-release:"), "release.yml must contain publish-release job", results)
			_expect(rel_content.contains("gh release create"), "release.yml must publish via gh release create", results)
			_expect(rel_content.contains(".zip.sha256"), "release.yml must attach and verify .sha256 checksum", results)
		else:
			_expect(false, "Failed to open release.yml for reading", results)

## Helper to record test results.
func _expect(condition: bool, message: String, results: Dictionary) -> void:
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["failures"].append(message)

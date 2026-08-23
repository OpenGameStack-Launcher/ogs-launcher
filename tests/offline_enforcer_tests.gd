## OfflineEnforcerTests: Unit tests for OfflineEnforcer behavior.
##
## Verifies offline state transitions and network guard responses.

extends RefCounted
class_name OfflineEnforcerTests
const OgsConfigScript = preload("res://scripts/config/ogs_config.gd")

func run() -> Dictionary:
	## Runs OfflineEnforcer unit tests.
## Returns:
## Dictionary: {"passed": int, "failed": int, "failures": Array[String]}
	var results := {"passed": 0, "failed": 0, "failures": []}
	_test_null_config(results)
	_test_offline_mode(results)
	_test_force_offline(results)
	_test_disabled(results)
	_test_guard_allows_when_online(results)
	_test_apply_allowlist_defaults(results)
	_test_apply_allowlist_from_config(results)
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

func _test_null_config(results: Dictionary) -> void:
	## Verifies null config disables offline enforcement.
	OfflineEnforcer.reset()
	OfflineEnforcer.apply_config(null)
	_expect(not OfflineEnforcer.is_offline(), "null config should disable offline", results)
	_expect(OfflineEnforcer.get_reason() == "unknown", "null config reason should be unknown", results)

func _test_offline_mode(results: Dictionary) -> void:
	## Verifies offline_mode=true enables offline enforcement.
	OfflineEnforcer.reset()
	var config = OgsConfigScript.from_dict({"offline_mode": true})
	OfflineEnforcer.apply_config(config)
	_expect(OfflineEnforcer.is_offline(), "offline_mode should enable offline", results)
	_expect(OfflineEnforcer.get_reason() == "offline_mode", "offline_mode reason should be set", results)
	var result = OfflineEnforcer.guard_network_call("unit_test")
	_expect(not result["allowed"], "offline should block network guard", results)
	_expect(result["error_code"] == OfflineEnforcer.BLOCKED_ERROR_CODE, "offline guard should return error code", results)

func _test_force_offline(results: Dictionary) -> void:
	## Verifies force_offline=true enables offline enforcement.
	OfflineEnforcer.reset()
	var config = OgsConfigScript.from_dict({"force_offline": true})
	OfflineEnforcer.apply_config(config)
	_expect(OfflineEnforcer.is_offline(), "force_offline should enable offline", results)
	_expect(OfflineEnforcer.get_reason() == "force_offline", "force_offline reason should be set", results)

func _test_disabled(results: Dictionary) -> void:
	## Verifies offline_mode=false keeps enforcement disabled.
	OfflineEnforcer.reset()
	var config = OgsConfigScript.from_dict({"offline_mode": false, "force_offline": false})
	OfflineEnforcer.apply_config(config)
	_expect(not OfflineEnforcer.is_offline(), "disabled config should not enable offline", results)
	_expect(OfflineEnforcer.get_reason() == "disabled", "disabled reason should be set", results)

func _test_guard_allows_when_online(results: Dictionary) -> void:
	## Verifies guard allows network operations when offline is false.
	OfflineEnforcer.reset()
	var result = OfflineEnforcer.guard_network_call("unit_test")
	_expect(result["allowed"], "online guard should allow network", results)
	_expect(result["error_code"] == "", "online guard should return no error code", results)

func _test_apply_allowlist_defaults(results: Dictionary) -> void:
	## Verifies reset/default config restores localhost-only allowlist.
	OfflineEnforcer.reset()
	SocketBlocker.set_allowlist(["example.com"])
	OfflineEnforcer.apply_config(null)
	var localhost_result = SocketBlocker.open_tcp_client("localhost", 80, false)
	var external_result = SocketBlocker.open_tcp_client("example.com", 80, false)
	_expect(localhost_result["success"], "default allowlist should permit localhost", results)
	_expect(not external_result["success"], "default allowlist should block external hosts", results)

func _test_apply_allowlist_from_config(results: Dictionary) -> void:
	## Verifies config allowlist is applied to socket policy.
	OfflineEnforcer.reset()
	var config = OgsConfigScript.from_dict({
		"offline_mode": false,
		"allowed_hosts": ["example.com"],
		"allowed_ports": [443]
	})
	OfflineEnforcer.apply_config(config)
	var allowed_result = SocketBlocker.open_tcp_client("example.com", 443, false)
	var blocked_port_result = SocketBlocker.open_tcp_client("example.com", 80, false)
	var blocked_host_result = SocketBlocker.open_tcp_client("localhost", 443, false)
	_expect(allowed_result["success"], "config allowlist should allow listed host/port", results)
	_expect(not blocked_port_result["success"], "config allowlist should block unlisted port", results)
	_expect(not blocked_host_result["success"], "config allowlist should block unlisted host", results)

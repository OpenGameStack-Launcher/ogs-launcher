## SocketBlockerTests: Unit tests for socket blocking.

extends RefCounted
class_name SocketBlockerTests
const OgsConfigScript = preload("res://scripts/config/ogs_config.gd")

func run() -> Dictionary:
	## Runs SocketBlocker unit tests.
## Returns:
## Dictionary: {"passed": int, "failed": int, "failures": Array[String]}
	var results := {"passed": 0, "failed": 0, "failures": []}
	_test_offline_blocks_socket(results)
	_test_online_allows_socket_creation(results)
	_test_online_blocks_disallowed_host(results)
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

func _test_offline_blocks_socket(results: Dictionary) -> void:
	## Verifies offline mode blocks socket creation attempts.
	OfflineEnforcer.reset()
	SocketBlocker.reset_allowlist()
	var config = OgsConfigScript.from_dict({"offline_mode": true})
	OfflineEnforcer.apply_config(config)
	var result = SocketBlocker.open_tcp_client("example.com", 80)
	_expect(not result["success"], "offline socket should fail", results)
	_expect(result["error_code"] == SocketBlocker.SocketError.OFFLINE_BLOCKED, "offline socket should be blocked", results)

func _test_online_allows_socket_creation(results: Dictionary) -> void:
	## Verifies online mode creates sockets without connecting.
	OfflineEnforcer.reset()
	var config = OgsConfigScript.from_dict({
		"offline_mode": false,
		"allowed_hosts": ["example.com"]
	})
	OfflineEnforcer.apply_config(config)
	var result = SocketBlocker.open_tcp_client("example.com", 80, false)
	_expect(result["success"], "online socket creation should succeed", results)
	_expect(result["error_code"] == SocketBlocker.SocketError.SUCCESS, "online socket should return SUCCESS", results)
	_expect(result["client"] != null, "online socket should return a client", results)

func _test_online_blocks_disallowed_host(results: Dictionary) -> void:
	## Verifies online mode blocks hosts not on the allowlist.
	OfflineEnforcer.reset()
	var config = OgsConfigScript.from_dict({
		"offline_mode": false,
		"allowed_hosts": ["example.com"]
	})
	OfflineEnforcer.apply_config(config)
	var result = SocketBlocker.open_tcp_client("not-allowed.com", 80, false)
	_expect(not result["success"], "disallowed host should be blocked", results)
	_expect(result["error_message"].find("Host not allowed") != -1, "blocked host should report allowlist error", results)

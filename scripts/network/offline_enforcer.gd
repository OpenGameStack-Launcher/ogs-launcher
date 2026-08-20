## OfflineEnforcer: Centralized Offline Mode Enforcement
##
## Applies offline configuration and provides guardrails for launcher-level
## network operations. This does not modify tool-specific configs; it only
## enforces launcher behavior in air-gapped mode.
##
## Usage:
##   OfflineEnforcer.apply_config(config)
##   if OfflineEnforcer.is_offline():
##       var result = OfflineEnforcer.guard_network_call("tool_download")
##
## Notes:
##   - When offline, sets OGS_OFFLINE=1 in the current process environment.
##   - Guard methods return structured errors for consistent UI handling.

extends RefCounted
class_name OfflineEnforcer

const OgsLogger = preload("res://scripts/logging/logger.gd")

const BLOCKED_ERROR_CODE := "network_blocked_offline"
const SOCKET_BLOCKER = preload("res://scripts/network/socket_blocker.gd")

static var _offline_active := false
static var _reason := "unknown"

static func apply_config(config: OgsConfig) -> void:
	"""Applies offline state from config and updates environment.
	Parameters:
	  config (OgsConfig): Loaded config or null
	"""
	if config == null:
		SOCKET_BLOCKER.reset_allowlist()
		_set_offline(false, "unknown")
		return
	_apply_allowlist_config(config)
	if config.force_offline:
		_set_offline(true, "force_offline")
		return
	if config.offline_mode:
		_set_offline(true, "offline_mode")
		return
	_set_offline(false, "disabled")

static func is_offline() -> bool:
	"""Returns true when offline enforcement is active."""
	return _offline_active

static func get_reason() -> String:
	"""Returns the current offline enforcement reason."""
	return _reason

static func guard_network_call(context: String) -> Dictionary:
	"""Blocks network operations when offline.
	Parameters:
	  context (String): Short description for logging/UI
	Returns:
	  Dictionary: {"allowed": bool, "error_code": String, "error_message": String}
	"""
	if not _offline_active:
		return {
			"allowed": true,
			"error_code": "",
			"error_message": ""
		}
	return {
		"allowed": false,
		"error_code": BLOCKED_ERROR_CODE,
		"error_message": "Network blocked (offline mode). Context: %s" % context
	}

static func reset() -> void:
	"""Resets offline enforcement state for tests."""
	SOCKET_BLOCKER.reset_allowlist()
	_set_offline(false, "reset")

static func _apply_allowlist_config(config: OgsConfig) -> void:
	"""Applies config-based socket allowlist with secure defaults.
	Parameters:
	  config (OgsConfig): Loaded config containing allowed hosts/ports
	"""
	if config.allowed_hosts.is_empty() and config.allowed_ports.is_empty():
		SOCKET_BLOCKER.reset_allowlist()
		return
	SOCKET_BLOCKER.set_allowlist(config.allowed_hosts, config.allowed_ports)

static func _set_offline(active: bool, reason: String) -> void:
	"""Updates internal state and environment flag.
	Parameters:
	  active (bool): Whether offline is active
	  reason (String): Reason label for status displays
	"""
	_offline_active = active
	_reason = reason
	OS.set_environment("OGS_OFFLINE", "1" if active else "0")
	OgsLogger.info("offline_state", {"component": "network", "active": active, "reason": reason})

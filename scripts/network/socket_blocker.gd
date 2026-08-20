## SocketBlocker: Guarded socket access for the launcher.
##
## Provides a single entry point for creating sockets. When offline is active,
## it blocks all socket creation attempts. Online behavior returns a real
## socket object and optionally attempts a connection.

extends RefCounted
class_name SocketBlocker

const OgsLogger = preload("res://scripts/logging/logger.gd")

## Default allowlist for outbound connections.
const DEFAULT_ALLOWED_HOSTS: Array[String] = ["localhost", "127.0.0.1"]
const DEFAULT_ALLOWED_PORTS: Array[int] = []
static var _allowed_hosts: Array[String] = DEFAULT_ALLOWED_HOSTS.duplicate()
static var _allowed_ports: Array[int] = DEFAULT_ALLOWED_PORTS.duplicate()

## Error codes for socket operations.
enum SocketError {
	SUCCESS = 0,
	OFFLINE_BLOCKED = 1,
	CONNECT_FAILED = 2,
}

static func open_tcp_client(host: String, port: int, auto_connect: bool = true) -> Dictionary:
	"""Guards TCP client creation based on offline state.
	Parameters:
	  host (String): Target host
	  port (int): Target port
	  auto_connect (bool): If true, attempt a connection immediately
	Returns:
	  Dictionary: {"success": bool, "error_code": int, "error_message": String, "client": StreamPeerTCP}
	"""
	var guard = OfflineEnforcer.guard_network_call("tcp:%s:%d" % [host, port])
	if not guard["allowed"]:
		OgsLogger.warn("socket_blocked", {"component": "network", "reason": "offline", "host": host, "port": port})
		return {
			"success": false,
			"error_code": SocketError.OFFLINE_BLOCKED,
			"error_message": guard["error_message"],
			"client": null
		}
	var allow_check = _is_allowed(host, port)
	if not allow_check["allowed"]:
		OgsLogger.warn("socket_blocked", {"component": "network", "reason": "allowlist", "host": host, "port": port})
		return {
			"success": false,
			"error_code": SocketError.CONNECT_FAILED,
			"error_message": allow_check["error_message"],
			"client": null
		}
	var peer = StreamPeerTCP.new()
	if not auto_connect:
		return {
			"success": true,
			"error_code": SocketError.SUCCESS,
			"error_message": "",
			"client": peer
		}
	var err = peer.connect_to_host(host, port)
	if err != OK:
		OgsLogger.error("socket_connect_failed", {"component": "network", "host": host, "port": port})
		return {
			"success": false,
			"error_code": SocketError.CONNECT_FAILED,
			"error_message": "Failed to connect (%s:%d). Error: %d" % [host, port, err],
			"client": peer
		}
	OgsLogger.info("socket_connected", {"component": "network", "host": host, "port": port})
	return {
		"success": true,
		"error_code": SocketError.SUCCESS,
		"error_message": "",
		"client": peer
	}

## Sets an explicit allowlist for outbound connections.
static func set_allowlist(hosts: Array[String], ports: Array[int] = []) -> void:
	_allowed_hosts.clear()
	for host in hosts:
		_allowed_hosts.append(String(host).strip_edges().to_lower())
	_allowed_ports.clear()
	for port in ports:
		_allowed_ports.append(int(port))

## Resets the allowlist to defaults.
static func reset_allowlist() -> void:
	_allowed_hosts = DEFAULT_ALLOWED_HOSTS.duplicate()
	_allowed_ports = DEFAULT_ALLOWED_PORTS.duplicate()

static func _is_allowed(host: String, port: int) -> Dictionary:
	var normalized_host = host.strip_edges().to_lower()
	if _allowed_hosts.size() > 0 and not _allowed_hosts.has(normalized_host):
		return {
			"allowed": false,
			"error_message": "Host not allowed: %s" % host
		}
	if _allowed_ports.size() > 0 and not _allowed_ports.has(port):
		return {
			"allowed": false,
			"error_message": "Port not allowed: %d" % port
		}
	return {"allowed": true, "error_message": ""}

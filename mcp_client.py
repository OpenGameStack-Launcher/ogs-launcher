#!/usr/bin/env python3
"""Zero-dependency CLI client for Godot's McpInteractionServer TCP bridge."""

from __future__ import annotations

import base64
import json
import os
import socket
import sys
from pathlib import Path
from typing import Any


DEFAULT_HOST = os.environ.get("GODOT_MCP_HOST", "127.0.0.1")
DEFAULT_PORT = int(os.environ.get("GODOT_MCP_PORT", "9090"))
DEFAULT_TIMEOUT = float(os.environ.get("GODOT_MCP_TIMEOUT", "15.0"))


def send_command(
    cmd: dict[str, Any],
    *,
    host: str = DEFAULT_HOST,
    port: int = DEFAULT_PORT,
    timeout: float = DEFAULT_TIMEOUT,
) -> dict[str, Any] | None:
    """Send a JSON command payload to McpInteractionServer and return the decoded response."""
    try:
        with socket.create_connection((host, port), timeout=timeout) as sock:
            sock.settimeout(timeout)
            msg = json.dumps(cmd) + "\n"
            sock.sendall(msg.encode("utf-8"))

            chunks: list[bytes] = []
            while True:
                chunk = sock.recv(65536)
                if not chunk:
                    break
                chunks.append(chunk)
                if b"\n" in chunk:
                    break

            raw_bytes = b"".join(chunks).strip()
            if not raw_bytes:
                print("Error: Empty response from McpInteractionServer", file=sys.stderr)
                return None
            return json.loads(raw_bytes.decode("utf-8"))
    except Exception as exc:
        print(f"Error connecting to McpInteractionServer ({host}:{port}): {exc}", file=sys.stderr)
        return None


def _parse_json_or_string(raw: str) -> Any:
    """Parse a CLI token as JSON if valid, otherwise return the raw string."""
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


def _print_usage() -> None:
    print("Usage: python mcp_client.py <command> [args...]")
    print("")
    print("Core Visual QA & Inspection Commands:")
    print("  ping                                      - Check if McpInteractionServer is reachable")
    print("  screenshot [output.png]                   - Save viewport snapshot (default: screenshot.png)")
    print("  get_scene_tree                            - Output full SceneTree hierarchy as JSON")
    print("  get_ui_elements                           - List visible Control nodes with positions/sizes")
    print("  get_node_info <node_path>                 - Inspect node properties, signals, methods, children")
    print("  get_property <node_path> <property>       - Read a property from a node")
    print("  set_property <node_path> <property> <val> - Set a property on a node (JSON or string value)")
    print("  call_method <node_path> <method> [args]   - Call a method on a node (optional JSON array args)")
    print("")
    print("Input & Runtime Control Commands:")
    print("  click <x> <y> [button]                    - Send mouse click at (x, y) (default button=1)")
    print("  key_press <key_or_action>                 - Press and release a key (e.g. ENTER, ESC) or action")
    print("  change_scene <res://path/to/scene.tscn>   - Switch active scene")
    print("  pause [true|false]                        - Pause or unpause the SceneTree")
    print("  wait [frames]                             - Wait N frames (default: 1)")
    print("  get_performance                           - Read FPS, frame times, and object/orphan counts")
    print("  eval <gdscript_code>                      - Execute runtime GDScript (or: eval --file <path>)")
    print("  raw <json_string>                         - Send raw JSON payload (or: raw --file <path>)")
    print("")
    print("Environment Variables:")
    print("  GODOT_MCP_HOST (default: 127.0.0.1)")
    print("  GODOT_MCP_PORT (default: 9090)")
    print("  GODOT_MCP_TIMEOUT (default: 15.0)")


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if not args or args[0] in {"-h", "--help", "help"}:
        _print_usage()
        return 0

    cmd_name = args[0]
    rest = args[1:]

    if cmd_name == "ping":
        resp = send_command({"command": "os_info"})
        if resp and resp.get("success"):
            print(json.dumps({"status": "ok", "os_info": resp}, indent=2))
            return 0
        return 1

    if cmd_name == "screenshot":
        out_path = Path(rest[0]) if rest else Path("screenshot.png")
        resp = send_command({"command": "screenshot"})
        if resp and "data" in resp:
            out_path.write_bytes(base64.b64decode(resp["data"]))
            width = resp.get("width", "?")
            height = resp.get("height", "?")
            print(f"Screenshot saved to {out_path} ({width}x{height})")
            return 0
        if resp:
            print(json.dumps(resp, indent=2), file=sys.stderr)
        return 1

    if cmd_name == "click":
        if len(rest) < 2:
            print("Usage: python mcp_client.py click <x> <y> [button]", file=sys.stderr)
            return 1
        params: dict[str, Any] = {"x": float(rest[0]), "y": float(rest[1])}
        if len(rest) >= 3:
            params["button"] = int(rest[2])
        resp = send_command({"command": "click", "params": params})
    elif cmd_name == "key_press":
        if not rest:
            print("Usage: python mcp_client.py key_press <key_or_action>", file=sys.stderr)
            return 1
        resp = send_command({"command": "key_press", "params": {"key": rest[0]}})
    elif cmd_name == "get_scene_tree":
        resp = send_command({"command": "get_scene_tree"})
    elif cmd_name == "get_ui_elements":
        resp = send_command({"command": "get_ui_elements"})
    elif cmd_name == "get_node_info":
        if not rest:
            print("Usage: python mcp_client.py get_node_info <node_path>", file=sys.stderr)
            return 1
        resp = send_command({"command": "get_node_info", "params": {"node_path": rest[0]}})
    elif cmd_name == "get_property":
        if len(rest) < 2:
            print("Usage: python mcp_client.py get_property <node_path> <property>", file=sys.stderr)
            return 1
        resp = send_command(
            {"command": "get_property", "params": {"node_path": rest[0], "property": rest[1]}}
        )
    elif cmd_name == "set_property":
        if len(rest) < 3:
            print(
                "Usage: python mcp_client.py set_property <node_path> <property> <value>",
                file=sys.stderr,
            )
            return 1
        resp = send_command(
            {
                "command": "set_property",
                "params": {
                    "node_path": rest[0],
                    "property": rest[1],
                    "value": _parse_json_or_string(rest[2]),
                },
            }
        )
    elif cmd_name == "call_method":
        if len(rest) < 2:
            print(
                "Usage: python mcp_client.py call_method <node_path> <method> [json_args_array]",
                file=sys.stderr,
            )
            return 1
        method_args: list[Any] = []
        if len(rest) >= 3:
            parsed = _parse_json_or_string(rest[2])
            method_args = parsed if isinstance(parsed, list) else [parsed]
        resp = send_command(
            {
                "command": "call_method",
                "params": {"node_path": rest[0], "method": rest[1], "args": method_args},
            }
        )
    elif cmd_name == "change_scene":
        if not rest:
            print("Usage: python mcp_client.py change_scene <scene_path>", file=sys.stderr)
            return 1
        resp = send_command({"command": "change_scene", "params": {"scene_path": rest[0]}})
    elif cmd_name == "pause":
        paused = True if not rest else rest[0].lower() not in {"false", "0", "no"}
        resp = send_command({"command": "pause", "params": {"paused": paused}})
    elif cmd_name == "wait":
        frames = int(rest[0]) if rest else 1
        resp = send_command({"command": "wait", "params": {"frames": frames}})
    elif cmd_name == "get_performance":
        resp = send_command({"command": "get_performance"})
    elif cmd_name == "eval":
        if not rest:
            print("Usage: python mcp_client.py eval <code | --file path>", file=sys.stderr)
            return 1
        if rest[0] == "--file" and len(rest) >= 2:
            code = Path(rest[1]).read_text(encoding="utf-8")
        else:
            code = " ".join(rest)
        resp = send_command({"command": "eval", "params": {"code": code}})
    elif cmd_name == "raw":
        if not rest:
            print("Usage: python mcp_client.py raw <json_string | --file path>", file=sys.stderr)
            return 1
        if rest[0] == "--file" and len(rest) >= 2:
            raw_payload = json.loads(Path(rest[1]).read_text(encoding="utf-8"))
        else:
            raw_payload = json.loads(rest[0])
        resp = send_command(raw_payload)
    else:
        # Allow invoking any McpInteractionServer command directly with optional JSON params
        params = json.loads(rest[0]) if rest else {}
        resp = send_command({"command": cmd_name, "params": params})

    if resp is None:
        return 1
    print(json.dumps(resp, indent=2))
    return 1 if "error" in resp else 0


if __name__ == "__main__":
    raise SystemExit(main())

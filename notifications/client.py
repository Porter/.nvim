#!/usr/bin/env python3
"""Notification Client CLI and Python API for Socket Daemon.

Provides methods and CLI commands to interact with the Notification Daemon over Unix domain socket or TCP socket:
- log_notification(tmux_window_id, nvim_buf_id, description=None)
- list_all_notifications()
- clear_notification(tmux_window_id, nvim_buf_id)
"""

import argparse
import json
import socket
import sys

DEFAULT_SOCKET_PATH = "/tmp/notification_daemon.sock"
DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 9876


class NotificationClient:

    def __init__(self, socket_path=DEFAULT_SOCKET_PATH, host=None, port=None):
        self.socket_path = socket_path
        self.host = host
        self.port = port

    def _connect(self):
        if self.host is not None and self.port is not None:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.connect((self.host, self.port))
            return s
        else:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(self.socket_path)
            return s

    def _send_request(self, payload):
        try:
            with self._connect() as sock:
                msg = json.dumps(payload).encode("utf-8") + b"\n"
                sock.sendall(msg)
                f = sock.makefile("r", encoding="utf-8")
                response_line = f.readline()
                if not response_line:
                    raise RuntimeError("No response from daemon")
                res = json.loads(response_line)
                if res.get("status") == "error":
                    raise RuntimeError(res.get("error", "Unknown server error"))
                return res
        except (socket.error, FileNotFoundError) as e:
            target = f"{self.host}:{self.port}" if self.host else self.socket_path
            raise RuntimeError(f"Failed to connect to daemon at {target}: {e}") from e

    def log_notification(self, tmux_window_id, nvim_buf_id, description=None):
        payload = {
            "action": "log",
            "tmux_window_id": str(tmux_window_id),
            "nvim_buf_id": str(nvim_buf_id),
        }
        if description is not None:
            payload["description"] = description
        res = self._send_request(payload)
        return res.get("notification")

    def list_all_notifications(self):
        payload = {"action": "list"}
        res = self._send_request(payload)
        return res.get("notifications", [])

    def clear_notification(self, tmux_window_id, nvim_buf_id):
        payload = {
            "action": "clear",
            "tmux_window_id": str(tmux_window_id),
            "nvim_buf_id": str(nvim_buf_id),
        }
        res = self._send_request(payload)
        return res.get("cleared", False)


def main():
    parser = argparse.ArgumentParser(description="Notification Socket Daemon Client")
    parser.add_argument("--socket", default=DEFAULT_SOCKET_PATH, help="Unix domain socket path")
    parser.add_argument("--tcp", action="store_true", help="Use TCP connection")
    parser.add_argument("--host", default=DEFAULT_HOST, help="TCP Host")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="TCP Port")

    subparsers = parser.add_subparsers(dest="command", required=True)

    # Log command
    log_parser = subparsers.add_parser("log", help="Log a new notification")
    log_parser.add_argument("--tmux-window-id", required=True, help="Tmux window ID")
    log_parser.add_argument("--nvim-buf-id", required=True, help="Neovim buffer ID")
    log_parser.add_argument("--description", help="Optional description")

    # List command
    subparsers.add_parser("list", help="List all notifications")

    # Clear command
    clear_parser = subparsers.add_parser("clear", help="Clear a notification")
    clear_parser.add_argument("--tmux-window-id", required=True, help="Tmux window ID")
    clear_parser.add_argument("--nvim-buf-id", required=True, help="Neovim buffer ID")

    args = parser.parse_args()

    if args.tcp:
        client = NotificationClient(host=args.host, port=args.port)
    else:
        client = NotificationClient(socket_path=args.socket)

    try:
        if args.command == "log":
            notification = client.log_notification(
                args.tmux_window_id, args.nvim_buf_id, args.description
            )
            print("Notification logged successfully:")
            print(json.dumps(notification, indent=2))

        elif args.command == "list":
            notifications = client.list_all_notifications()
            print(f"Active Notifications ({len(notifications)}):")
            print(json.dumps(notifications, indent=2))

        elif args.command == "clear":
            cleared = client.clear_notification(args.tmux_window_id, args.nvim_buf_id)
            if cleared:
                print(
                    f"Cleared notification for tmux_window_id={args.tmux_window_id}, nvim_buf_id={args.nvim_buf_id}"
                )
            else:
                print(
                    f"No matching notification found for tmux_window_id={args.tmux_window_id}, nvim_buf_id={args.nvim_buf_id}"
                )

    except RuntimeError as err:
        print(f"Error: {err}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

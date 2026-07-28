#!/usr/bin/env python3
"""Notification Daemon using Unix Domain Sockets.

Accepts requests to log, list, and clear notifications for (tmux_window_id, nvim_buf_id).
Persists notifications to a text file in /tmp/notifications.txt.
Communicates via Unix Domain Socket at /tmp/notification_daemon.sock (or TCP socket).
"""

import json
import os
import signal
import socketserver
import sys
import threading

DEFAULT_FILE_PATH = "/tmp/notifications.txt"
DEFAULT_SOCKET_PATH = "/tmp/notification_daemon.sock"
DEFAULT_PORT = 9876
DEFAULT_HOST = "127.0.0.1"


class NotificationStore:
    """Thread-safe store for notifications with text file persistence."""

    def __init__(self, file_path=DEFAULT_FILE_PATH):
        self.file_path = file_path
        self.lock = threading.Lock()
        self._notifications = {}
        self._load()

    def _make_key(self, tmux_window_id, nvim_buf_id):
        return (str(tmux_window_id), str(nvim_buf_id))

    def _load(self):
        with self.lock:
            if not os.path.exists(self.file_path):
                self._notifications = {}
                return

            try:
                if os.path.getsize(self.file_path) == 0:
                    self._notifications = {}
                    return
                with open(self.file_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    self._notifications = {
                        self._make_key(item["tmux_window_id"], item["nvim_buf_id"]): item
                        for item in data
                    }
            except Exception as e:
                print(f"Warning: Failed to load storage file {self.file_path}: {e}", file=sys.stderr)
                self._notifications = {}

    def _save_unlocked(self):
        temp_path = self.file_path + ".tmp"
        data_to_write = list(self._notifications.values())
        try:
            with open(temp_path, "w", encoding="utf-8") as f:
                json.dump(data_to_write, f, indent=2)
            os.replace(temp_path, self.file_path)
        except Exception as e:
            print(f"Error saving notifications to {self.file_path}: {e}", file=sys.stderr)

    def log_notification(self, tmux_window_id, nvim_buf_id, description=None):
        key = self._make_key(tmux_window_id, nvim_buf_id)
        notification = {
            "tmux_window_id": str(tmux_window_id),
            "nvim_buf_id": str(nvim_buf_id),
            "description": description if description is not None else "",
        }
        with self.lock:
            self._notifications[key] = notification
            self._save_unlocked()
        return notification

    def list_all_notifications(self):
        with self.lock:
            return list(self._notifications.values())

    def clear_notification(self, tmux_window_id, nvim_buf_id):
        key = self._make_key(tmux_window_id, nvim_buf_id)
        with self.lock:
            if key in self._notifications:
                del self._notifications[key]
                self._save_unlocked()
                return True
            return False


class NotificationSocketHandler(socketserver.StreamRequestHandler):
    """Handler for socket connections (Unix domain or TCP stream)."""

    store = None  # Class property set before starting server

    def handle(self):
        line = self.rfile.readline()
        if not line:
            return
        try:
            request = json.loads(line.decode("utf-8"))
            response = self.process_request(request)
        except json.JSONDecodeError:
            response = {"status": "error", "error": "Invalid JSON request"}

        self.wfile.write(json.dumps(response).encode("utf-8") + b"\n")
        self.wfile.flush()

    def process_request(self, req):
        action = req.get("action") or req.get("method")
        if action in ("log", "LogNotification"):
            tmux_window_id = req.get("tmux_window_id")
            nvim_buf_id = req.get("nvim_buf_id")
            if tmux_window_id is None or nvim_buf_id is None:
                return {"status": "error", "error": "tmux_window_id and nvim_buf_id are required"}
            description = req.get("description")
            notification = self.store.log_notification(tmux_window_id, nvim_buf_id, description)
            return {"status": "ok", "notification": notification}

        elif action in ("list", "ListAllNotifications"):
            notifications = self.store.list_all_notifications()
            return {"status": "ok", "notifications": notifications}

        elif action in ("clear", "ClearNotification"):
            tmux_window_id = req.get("tmux_window_id")
            nvim_buf_id = req.get("nvim_buf_id")
            if tmux_window_id is None or nvim_buf_id is None:
                return {"status": "error", "error": "tmux_window_id and nvim_buf_id are required"}
            cleared = self.store.clear_notification(tmux_window_id, nvim_buf_id)
            return {"status": "ok", "cleared": cleared}

        else:
            return {"status": "error", "error": f"Unknown action: {action}"}


class ThreadedUnixServer(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    daemon_threads = True


class ThreadedTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    daemon_threads = True


def run_unix_daemon(socket_path=DEFAULT_SOCKET_PATH, file_path=DEFAULT_FILE_PATH):
    store = NotificationStore(file_path=file_path)
    NotificationSocketHandler.store = store

    if os.path.exists(socket_path):
        try:
            os.remove(socket_path)
        except OSError as e:
            print(f"Error removing existing socket file {socket_path}: {e}", file=sys.stderr)

    server = ThreadedUnixServer(socket_path, NotificationSocketHandler)
    print(f"Notification Daemon running on Unix Socket: {socket_path}")
    print(f"Persisting data to: {file_path}")

    def shutdown_handler(signum, frame):
        print("\nShutting down daemon...")
        server.server_close()
        if os.path.exists(socket_path):
            os.remove(socket_path)
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown_handler)
    signal.signal(signal.SIGTERM, shutdown_handler)

    try:
        server.serve_forever()
    finally:
        server.server_close()
        if os.path.exists(socket_path):
            os.remove(socket_path)


def run_tcp_daemon(host=DEFAULT_HOST, port=DEFAULT_PORT, file_path=DEFAULT_FILE_PATH):
    store = NotificationStore(file_path=file_path)
    NotificationSocketHandler.store = store

    server = ThreadedTCPServer((host, port), NotificationSocketHandler)
    print(f"Notification Daemon running on TCP Socket: {host}:{port}")
    print(f"Persisting data to: {file_path}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down daemon...")
        server.server_close()


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Notification Socket Daemon")
    parser.add_argument("--socket", default=DEFAULT_SOCKET_PATH, help="Unix domain socket path")
    parser.add_argument("--tcp", action="store_true", help="Use TCP socket instead of Unix domain socket")
    parser.add_argument("--host", default=DEFAULT_HOST, help="TCP Host to bind to")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="TCP Port to listen on")
    parser.add_argument("--file", default=DEFAULT_FILE_PATH, help="File path to persist notifications")
    args = parser.parse_args()

    if args.tcp:
        run_tcp_daemon(host=args.host, port=args.port, file_path=args.file)
    else:
        run_unix_daemon(socket_path=args.socket, file_path=args.file)

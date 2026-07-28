#!/usr/bin/env python3
"""Unit and Integration Tests for Notification Socket Daemon and Client."""

import json
import os
import tempfile
import threading
import time
import unittest

from daemon import (
    NotificationStore,
    NotificationSocketHandler,
    ThreadedUnixServer,
    ThreadedTCPServer,
)
from client import NotificationClient


class TestNotificationStore(unittest.TestCase):

    def setUp(self):
        self.temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".txt")
        self.temp_file.close()
        self.file_path = self.temp_file.name

    def tearDown(self):
        if os.path.exists(self.file_path):
            os.remove(self.file_path)
        if os.path.exists(self.file_path + ".tmp"):
            os.remove(self.file_path + ".tmp")

    def test_log_and_list(self):
        store = NotificationStore(file_path=self.file_path)
        self.assertEqual(store.list_all_notifications(), [])

        n1 = store.log_notification(tmux_window_id="win1", nvim_buf_id=1, description="First buffer")
        self.assertEqual(n1["tmux_window_id"], "win1")
        self.assertEqual(n1["nvim_buf_id"], "1")
        self.assertEqual(n1["description"], "First buffer")

        n2 = store.log_notification(tmux_window_id="win1", nvim_buf_id=2)
        self.assertEqual(n2["description"], "")

        notifications = store.list_all_notifications()
        self.assertEqual(len(notifications), 2)

    def test_overwrite_existing(self):
        store = NotificationStore(file_path=self.file_path)
        store.log_notification(tmux_window_id="win1", nvim_buf_id=1, description="Initial")
        store.log_notification(tmux_window_id="win1", nvim_buf_id=1, description="Updated")

        notifications = store.list_all_notifications()
        self.assertEqual(len(notifications), 1)
        self.assertEqual(notifications[0]["description"], "Updated")

    def test_clear_notification(self):
        store = NotificationStore(file_path=self.file_path)
        store.log_notification(tmux_window_id="win1", nvim_buf_id=10, description="To clear")
        store.log_notification(tmux_window_id="win2", nvim_buf_id=10, description="Keep")

        cleared = store.clear_notification(tmux_window_id="win1", nvim_buf_id=10)
        self.assertTrue(cleared)

        notifications = store.list_all_notifications()
        self.assertEqual(len(notifications), 1)
        self.assertEqual(notifications[0]["tmux_window_id"], "win2")

        cleared_again = store.clear_notification(tmux_window_id="win1", nvim_buf_id=10)
        self.assertFalse(cleared_again)

    def test_file_persistence(self):
        store1 = NotificationStore(file_path=self.file_path)
        store1.log_notification(tmux_window_id="w1", nvim_buf_id=5, description="Persistent test")

        with open(self.file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            self.assertEqual(len(data), 1)
            self.assertEqual(data[0]["tmux_window_id"], "w1")
            self.assertEqual(data[0]["nvim_buf_id"], "5")

        store2 = NotificationStore(file_path=self.file_path)
        loaded = store2.list_all_notifications()
        self.assertEqual(len(loaded), 1)
        self.assertEqual(loaded[0]["description"], "Persistent test")


class TestUnixSocketIntegration(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".txt")
        cls.temp_file.close()
        cls.file_path = cls.temp_file.name

        cls.socket_file = tempfile.NamedTemporaryFile(delete=False, suffix=".sock")
        cls.socket_file.close()
        cls.socket_path = cls.socket_file.name
        os.remove(cls.socket_path)

        cls.store = NotificationStore(file_path=cls.file_path)

        class CustomHandler(NotificationSocketHandler):
            store = cls.store

        cls.server = ThreadedUnixServer(cls.socket_path, CustomHandler)
        cls.server_thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.server_thread.start()
        time.sleep(0.1)

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        for path in (cls.file_path, cls.file_path + ".tmp", cls.socket_path):
            if os.path.exists(path):
                os.remove(path)

    def test_client_unix_socket_interaction(self):
        client = NotificationClient(socket_path=self.socket_path)

        self.assertEqual(client.list_all_notifications(), [])

        n1 = client.log_notification(tmux_window_id="w_sock", nvim_buf_id=101, description="Unix socket notification")
        self.assertEqual(n1["tmux_window_id"], "w_sock")
        self.assertEqual(n1["nvim_buf_id"], "101")
        self.assertEqual(n1["description"], "Unix socket notification")

        all_notifs = client.list_all_notifications()
        self.assertEqual(len(all_notifs), 1)
        self.assertEqual(all_notifs[0]["description"], "Unix socket notification")

        cleared = client.clear_notification(tmux_window_id="w_sock", nvim_buf_id=101)
        self.assertTrue(cleared)

        self.assertEqual(client.list_all_notifications(), [])


class TestTCPSocketIntegration(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".txt")
        cls.temp_file.close()
        cls.file_path = cls.temp_file.name

        cls.port = 9899
        cls.host = "127.0.0.1"

        cls.store = NotificationStore(file_path=cls.file_path)

        class CustomHandler(NotificationSocketHandler):
            store = cls.store

        cls.server = ThreadedTCPServer((cls.host, cls.port), CustomHandler)
        cls.server_thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.server_thread.start()
        time.sleep(0.1)

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        for path in (cls.file_path, cls.file_path + ".tmp"):
            if os.path.exists(path):
                os.remove(path)

    def test_client_tcp_socket_interaction(self):
        client = NotificationClient(host=self.host, port=self.port)

        self.assertEqual(client.list_all_notifications(), [])

        n1 = client.log_notification(tmux_window_id="w_tcp", nvim_buf_id=202, description="TCP socket test")
        self.assertEqual(n1["description"], "TCP socket test")

        all_notifs = client.list_all_notifications()
        self.assertEqual(len(all_notifs), 1)

        cleared = client.clear_notification(tmux_window_id="w_tcp", nvim_buf_id=202)
        self.assertTrue(cleared)

        self.assertEqual(client.list_all_notifications(), [])


if __name__ == "__main__":
    unittest.main()

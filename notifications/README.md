# Notification Socket Daemon

A lightweight daemon that manages notifications keyed on `(tmux_window_id, nvim_buf_id)` using Unix Domain Sockets or TCP Sockets.

## Features
- **Log Notification**: Accepts requests containing `tmux_window_id`, `nvim_buf_id`, and an optional `description`.
- **List All Notifications**: Retrieves all active notifications stored in the system.
- **Clear Notification**: Clears a notification keyed on `(tmux_window_id, nvim_buf_id)`.
- **IPC Transports**: Unix Domain Sockets (default) or TCP Sockets.
- **Persistence**: Persists data to `/tmp/notifications.txt` (or a custom path).

## Project Structure
- [daemon.py](file:///usr/local/google/home/phaet/notification_daemon/daemon.py): Unix / TCP socket daemon implementation & data store handling persistence.
- [client.py](file:///usr/local/google/home/phaet/notification_daemon/client.py): Python client library and CLI interface over sockets.
- [notify.sh](file:///usr/local/google/home/phaet/notification_daemon/notify.sh): Bash script to log notifications from long-running terminal tasks.
- [daemon_test.py](file:///usr/local/google/home/phaet/notification_daemon/daemon_test.py): Unit and integration tests for socket communications.
- [notification-daemon.service](file:///usr/local/google/home/phaet/notification_daemon/notification-daemon.service): Systemd user service unit file.
- [lua/telescope/_extensions/notifications.lua](file:///usr/local/google/home/phaet/notification_daemon/lua/telescope/_extensions/notifications.lua): Telescope provider for listing, clearing, and jumping to notifications.

---

## Neovim Setup (`init.lua`)

### 1. Register `$NVIM` RPC Socket & Tmux Window ID
Add this autocmd to your `init.lua` to register each Neovim instance's RPC server socket (`v:servername` / `$NVIM`) in `/tmp/nvim_sockets.json`:

```lua
local function register_nvim_socket()
  local servername = vim.v.servername
  if not servername or servername == "" then return end

  local tmux_pane = os.getenv("TMUX_PANE") or ""
  local tmux_win = ""
  if tmux_pane ~= "" then
    tmux_win = vim.fn.system({"tmux", "display-message", "-p", "-F", "#{window_index}", "-t", tmux_pane}):gsub("%s+", "")
  else
    tmux_win = vim.fn.system({"tmux", "display-message", "-p", "-F", "#{window_index}"}):gsub("%s+", "")
  end

  if tmux_win == "" then return end

  local file_path = "/tmp/nvim_sockets.json"
  local sockets = {}

  local f = io.open(file_path, "r")
  if f then
    local content = f:read("*a")
    f:close()
    if content and content ~= "" then
      pcall(function() sockets = vim.fn.json_decode(content) or {} end)
    end
  end

  sockets[tmux_win] = servername

  f = io.open(file_path, "w")
  if f then
    f:write(vim.fn.json_encode(sockets))
    f:close()
  end
end

vim.api.nvim_create_autocmd({"VimEnter", "FocusGained"}, {
  callback = register_nvim_socket
})
```

### 2. Async Alert Count Polling (Sets `vim.g.alert_count` every 1 second)
Add this snippet to your `init.lua` to continuously update `vim.g.alert_count` in the background (useful for statuslines like lualine):

```lua
local SOCKET_PATH = "/tmp/notification_daemon.sock"
local LIST_PAYLOAD = '{"action": "list"}\n'
local timer = (vim.uv or vim.loop).new_timer()
vim.g.alert_count = 0

local function parse_count(stdout)
  if not stdout or stdout == "" then return 0 end
  local ok, data = pcall(vim.json.decode, stdout)
  if ok and data and data.status == "ok" and data.notifications then
    return #data.notifications
  end
  return 0
end

local function check_notifications()
  if vim.system then
    -- Neovim 0.10+ async vim.system
    vim.system({ "nc", "-N", "-U", SOCKET_PATH }, {
      stdin = LIST_PAYLOAD,
      text = true,
    }, function(out)
      local count = (out.code == 0) and parse_count(out.stdout) or 0
      vim.schedule(function()
        vim.g.alert_count = count
      end)
    end)
  else
    -- Fallback for Neovim 0.9 and earlier using jobstart
    local stdout_data = {}
    vim.fn.jobstart({ "nc", "-N", "-U", SOCKET_PATH }, {
      stdout_buffered = true,
      on_stdout = function(_, data)
        if data then
          for _, line in ipairs(data) do
            if line ~= "" then table.insert(stdout_data, line) end
          end
        end
      end,
      on_exit = function()
        local raw = table.concat(stdout_data, "")
        local count = parse_count(raw)
        vim.schedule(function()
          vim.g.alert_count = count
        end)
      end,
    }):send(LIST_PAYLOAD)
  end
end

-- Run every 1000ms (1 second)
timer:start(100, 1000, vim.schedule_wrap(check_notifications))
```

---

## Telescope Integration (Neovim)

Add `~/notification_daemon/lua` to your Neovim `runtimepath` or load via your plugin manager (e.g. lazy.nvim, packer.nvim):

```lua
-- Add runtimepath if not using a plugin manager:
vim.opt.runtimepath:append("~/notification_daemon")

-- Load the Telescope extension:
require("telescope").load_extension("notifications")

-- Keymap example:
vim.keymap.set("n", "<leader>fn", function()
  require("telescope").extensions.notifications.notifications()
end, { desc = "Find Notifications" })
```

---

## Long-Running Task Notification Helper (`notify.sh`)

```bash
~/notification_daemon/notify.sh "Long running task complete!"
```

---

## Systemd Setup (Always-Running Background Daemon)

```bash
mkdir -p ~/.config/systemd/user
cp ~/notification_daemon/notification-daemon.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now notification-daemon.service
```

---

## Direct Unix Socket Commands (via `nc` / `socat` / `cat`)

### Log Notification
```bash
echo '{"action": "log", "tmux_window_id": "1", "nvim_buf_id": "42", "description": "LSP alert"}' | nc -N -U /tmp/notification_daemon.sock
```

### List Notifications
```bash
echo '{"action": "list"}' | nc -N -U /tmp/notification_daemon.sock
```

### Clear Notification
```bash
echo '{"action": "clear", "tmux_window_id": "1", "nvim_buf_id": "42"}' | nc -N -U /tmp/notification_daemon.sock
```

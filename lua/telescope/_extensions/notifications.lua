-- Telescope Extension for Notification Daemon
-- Usage in Neovim:
--   require('telescope').load_extension('notifications')
--   require('telescope').extensions.notifications.notifications()
-- Or via command: :Telescope notifications

local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  error("This extension requires nvim-telescope/telescope.nvim")
end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local SOCKET_PATH = "/tmp/notification_daemon.sock"
local NVIM_SOCKETS_FILE = "/tmp/nvim_sockets.json"

local function get_notifications()
  local payload = vim.fn.json_encode({ action = "list" })
  local res_str = vim.fn.system({"nc", "-N", "-U", SOCKET_PATH}, payload .. "\n")
  if vim.v.shell_error ~= 0 or res_str == "" then
    return {}
  end
  local ok, data = pcall(vim.fn.json_decode, res_str)
  if ok and data and data.status == "ok" then
    return data.notifications or {}
  end
  return {}
end

local function clear_notification(tmux_win, buf_id)
  local payload = vim.fn.json_encode({
    action = "clear",
    tmux_window_id = tostring(tmux_win),
    nvim_buf_id = tostring(buf_id)
  })
  vim.fn.system({"nc", "-N", "-U", SOCKET_PATH}, payload .. "\n")
end

local function get_nvim_socket(tmux_win)
  local f = io.open(NVIM_SOCKETS_FILE, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  if not content or content == "" then return nil end
  local ok, sockets = pcall(vim.fn.json_decode, content)
  if ok and type(sockets) == "table" then
    return sockets[tostring(tmux_win)]
  end
  return nil
end

local function goto_or_open_tab_for_buf(bufnr)
  bufnr = tonumber(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end

  -- 1. Search all tabs and windows for the target buffer
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if vim.api.nvim_win_get_buf(win) == bufnr then
        vim.api.nvim_set_current_tabpage(tab)
        vim.api.nvim_set_current_win(win)
        return
      end
    end
  end

  -- 2. If not found in any tab, open a new tab and display buffer
  vim.cmd("tabnew")
  pcall(vim.api.nvim_set_current_buf, bufnr)
end

local function list_notifications_picker(opts)
  opts = opts or {}
  local notifications = get_notifications()

  if #notifications == 0 then
    vim.notify("No active notifications", vim.log.levels.INFO)
    return
  end

  pickers.new(opts, {
    prompt_title = "Notifications",
    finder = finders.new_table({
      results = notifications,
      entry_maker = function(entry)
        local desc = (entry.description and entry.description ~= "") and (" - " .. entry.description) or ""
        local display = string.format("%s", desc)
        return {
          value = entry,
          display = display,
          ordinal = display,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if not selection then return end

        local item = selection.value
        local tmux_win = tostring(item.tmux_window_id)
        local buf_id = tostring(item.nvim_buf_id)
        local bufnr = tonumber(buf_id)

        -- 1. Clear the notification in daemon
        clear_notification(tmux_win, buf_id)

        -- 2. Switch tmux window
        if tmux_win ~= "" then
          vim.fn.system({"tmux", "select-window", "-t", tmux_win})
        end

        -- 3. Switch to buffer (tab search or new tab) in target Neovim instance
        local target_socket = get_nvim_socket(tmux_win)
        if target_socket and vim.fn.filereadable(target_socket) == 1 then
          -- Send remote Lua snippet to target Neovim RPC socket
          local remote_lua = string.format(
            "<Cmd>lua (function(b) for _,t in ipairs(vim.api.nvim_list_tabpages()) do for _,w in ipairs(vim.api.nvim_tabpage_list_wins(t)) do if vim.api.nvim_win_get_buf(w)==b then vim.api.nvim_set_current_tabpage(t) vim.api.nvim_set_current_win(w) return end end end vim.cmd('tabnew') pcall(vim.api.nvim_set_current_buf,b) end)(%d)<CR>",
            bufnr
          )
          vim.fn.system({"nvim", "--server", target_socket, "--remote-send", remote_lua})
        else
          -- Fallback for local Neovim instance
          goto_or_open_tab_for_buf(bufnr)
        end
      end)
      return true
    end,
  }):find()
end

return telescope.register_extension({
  exports = {
    notifications = list_notifications_picker,
  },
})



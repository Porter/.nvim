local M = {}

local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local builtin = require('telescope.builtin')
local extensions = require('telescope').extensions
local conf = require("telescope.config").values
local finders = require "telescope.finders"
local pickers = require "telescope.pickers"

function M.setup() 
        -- Bindings in the Telescope UI.
        R('telescope').setup({
                defaults = {
                        mappings = {
                                i = {
                                        ["<c-j>"] = actions.move_selection_next,
                                        ["<m-i>"] = function(prompt_bufnr)
                                                actions.close(prompt_bufnr)
                                                local selection = action_state.get_selected_entry()
                                                addImport(selection.ordinal)
                                        end,
                                        ["<c-k>"] = actions.move_selection_previous,
                                        ["<c-s>"] = function(prompt_bufnr)
                                                -- IDK
                                                action_state.get_current_picker(prompt_bufnr):refresh()
                                        end
                                },
                                n = {
                                        ["<leader>c"] = actions.close,
                                },
                        }
                }
        })

        -- Use telescope to switch between tmux windows.
        R("telescope").load_extension("tmux")
        vim.keymap.set('n', '<leader>tm', '<cmd>Telescope tmux windows<cr>', {noremap=true})

        -- Bindings to open telescope.
        vim.keymap.set('n', '<leader>tt', builtin.treesitter, {})
        vim.keymap.set('n', '<leader>tf', function ()
                return builtin.treesitter({
                        symbols = {"function", "method"},
                })
        end, {})
        vim.keymap.set('n', '<leader>th', builtin.help_tags, {})
        vim.keymap.set('n', '<leader>tr', builtin.registers, {})
        vim.keymap.set('n', '<leader>tb', builtin.buffers, {})
        vim.keymap.set('n', '<leader>tp', builtin.planets, {})
        vim.keymap.set('n', '<leader>ts', M.siblings, {})

        require("telescope").load_extension("notifications")
        vim.keymap.set("n", "<leader>ta", extensions.notifications.notifications, {})

        local SOCKET_PATH = "/tmp/notification_daemon.sock"
        local timer = (vim.uv or vim.loop).new_timer()
        vim.g.alert_count = 0
        local function check_notifications()
                local payload = vim.fn.json_encode({ action = "list" })
                vim.system({ "nc", "-N", "-U", SOCKET_PATH }, {
                        stdin = payload .. "\n",
                        text = true,
                }, function(out)
                                local count = 0
                                if out.code == 0 and out.stdout and out.stdout ~= "" then
                                        local ok, data = pcall(vim.json.decode, out.stdout)
                                        if ok and data and data.status == "ok" and data.notifications then
                                                count = #data.notifications
                                        end
                                end
                                vim.g.alert_count = count
                        end)
        end

        -- Start timer: delay 100ms, repeat every 1000ms (1 second)
        timer:start(100, 1000, vim.schedule_wrap(check_notifications))


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
end

function M.run(cmd)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result
end

-- Returns a list of all files in the same dir as the current buffer's file.
function M.siblings(opts)
    opts = opts or {}
    local dir = vim.fn.expand("%:h")
    pickers.new(opts, {
        prompt_title = "sibling files",
        finder = finders.new_table {
            results = vim.split(M.run("ls " .. dir), "\n"),
        },

        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                vim.cmd("edit " .. dir .. "/" .. selection[1])
            end)
            return true
        end,
    }):find()
end

return M

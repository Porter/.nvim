local M = {}

local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local builtin = require('telescope.builtin')
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

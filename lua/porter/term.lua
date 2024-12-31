local M = {}

-- Run the given command in a NeoVim integrated terminal.
function M.run(cmd)
        tab, buf, channel = M.findOrCreateTerm()
        if channel ~= 0 then
                vim.fn.chansend(channel, cmd .. '\n')
                local num = vim.api.nvim_tabpage_get_number(tab)
                vim.api.nvim_exec("normal " .. num .. "gtG", true) -- go to tab #num.

                M.lastTabWithTermHandle = tab
                M.lastTerminalBuffer = buf
        end
end

-- Returns the tab, buffer, and channel for an integrated terminal.
-- Tries to find an existing terminal first, otherwise creates a new one.
function M.findOrCreateTerm()
        -- Look for a tab that has a window with an open buffer that has channel option set.
        -- Check the current tab first.
        local current_tab = vim.api.nvim_get_current_tabpage()
        local tabs = {current_tab}
        for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
                table.insert(tabs, tab)
        end
        for _, tab in ipairs(tabs) do
                for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
                        local buf = vim.api.nvim_win_get_buf(win)
                        success, channel = pcall(function() return vim.bo[buf].channel end)
                        if success and channel ~= 0 then
                                return tab, buf, channel
                        end
                end
        end

        -- Look at the last tab a terminal command was run. Switch to the terminal if there is only
        -- one window open.
        local tab = M.lastTabWithTermHandle
        local buf = M.lastTerminalBuffer
        if tab ~= nil and vim.api.nvim_tabpage_is_valid(tab) then
                local winCount = 0
                local win = nil
                for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
                        winCount = winCount + 1
                        win = w
                end

                success, channel = pcall(function() return vim.bo[buf].channel end)
                if winCount == 1 and success and channel ~= 0 then
                        vim.api.nvim_exec("normal " .. tab .. "gtG", true) -- go to the tab.
                        vim.api.nvim_win_set_buf(win, buf) -- set the terminal buffer
                        return tab, buf, channel
                end
        end


        -- Create a new tab, and start a terminal if neccessary.
        vim.api.nvim_exec("tabnew", true) -- create a new tab.
        buf = M.findTerminalBuffer()
        if buf == nil then
                vim.api.nvim_exec("terminal", true) -- start a new terminal.
                buf = vim.api.nvim_win_get_buf(0)
        end
        vim.api.nvim_win_set_buf(0, buf)
        success, channel = pcall(function() return vim.bo[buf].channel end)
        if not success then
                print("Unable to start a new terminal")
                return
        end
        return vim.api.nvim_win_get_tabpage(0), buf, channel
end

function M.findTerminalBuffer()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_valid(buf) then
                        success, channel = pcall(function() return vim.bo[buf].channel end)
                        if success and channel ~= 0 then
                                return buf
                        end
                end
        end
end

function M.setup()
end

return M


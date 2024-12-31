local M = {}

function M.setup()
end

-- Intended for use in the status line.
function M.status()
        local clients = vim.lsp.get_clients({bufnr = 0})
        if #clients == 0 then
                return "No LSP"
        end
        if #clients ~= 1 then
                return #clients .. " LSPs"
        end
        return clients[1].name
end

return M

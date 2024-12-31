local M = {}

function M.setup(opts)
        for _, ft in ipairs(opts['filetypes']) do
                vim.filetype.add(ft)
        end
end

return M

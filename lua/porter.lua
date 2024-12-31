local M = {}

function M.setup(opts)
        R("porter.clipboard").setup(opts)
        R("porter.term").setup(opts)
        R("porter.bindings").setup(opts)
        R("porter.telescope").setup(opts)
        R("porter.treesitter").setup(opts)
        R("porter.lsp").setup(opts)
        R("porter.filetypes").setup(opts)
end

return M

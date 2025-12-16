local M = {}

function M.setup(opts)
        opts['filetypes'] = opts['filetypes'] or {}
        for _, ft in ipairs(opts['filetypes']) do
                vim.filetype.add(ft)
        end

        opts['filetypeOpts'] = opts['filetypeOpts'] or {}
        for _, fto in ipairs(opts['filetypeOpts']) do
                for file, opts in pairs(fto) do
                        local optsGroup = vim.api.nvim_create_augroup(file .. "Opts", {
                                clear = true
                        })
                        vim.api.nvim_create_autocmd("FileType", {
                                callback = function ()
                                        if opts['spaces'] ~= nil and opts['spaces'] == false then
                                                vim.opt_local.expandtab = false
                                        end
                                        if opts['tabs'] ~= nil and opts['tabs'] == true then
                                                vim.opt_local.expandtab = false
                                        end
                                        if opts['shiftwidth'] ~= nil then
                                                vim.opt_local.shiftwidth = opts['shiftwidth']
                                        end
                                end,
                                pattern = file,
                                group = optsGroup,
                        })
                end
        end
end

return M

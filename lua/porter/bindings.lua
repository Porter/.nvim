local M = {}

function M.setup()
        -- Options.
        vim.o.relativenumber = true
        vim.o.number = true
        vim.o.incsearch = true
        vim.o.hlsearch = false
        vim.o.showcmd = true
        vim.o.foldcolumn = "auto"
        vim.o.mouse = ""
        vim.o.expandtab = true
        vim.o.completeopt = "menu,menuone,noselect"
        vim.o.path = ".,..,,"
        vim.o.splitright = true

        vim.keymap.set('n', '<c-q>', '<cmd>q<cr>', {noremap=true})

        -- Open and source this file.
        vim.keymap.set('n', '<leader>ev', ':e ~/.config/nvim/init.lua<cr>', {noremap = true})
        vim.keymap.set('n', '<leader>ebi', ':e ~/.nvim/lua/porter/bindings.lua<cr>', {noremap = true})
        vim.keymap.set('n', '<leader>eg', ':e ~/google.nvim<cr>', {noremap = true})
        vim.keymap.set('n', '<leader>es', ':e ~/.config/nvim/snippets<cr>', {noremap = true})
        vim.keymap.set('n', '<leader>sv', ':source ~/.config/nvim/init.lua<cr>', {noremap = true})
        vim.keymap.set('n', '<leader>sf', ':source %<cr>', {noremap = true})

        vim.keymap.set('n', '<leader>ep', ':Explore ~/.config/nvim/lua/plugins<cr>', {noremap = true})
        vim.keymap.set('n', '<leader>eba', ':e ~/.bashrc<cr>', {noremap = true})

        vim.keymap.set('n', '<leader>et', '<cmd>e ~/todo.txt<cr><cmd>colorscheme init<cr>', {noremap = true})

        vim.keymap.set('n', '<leader>fg', '<cmd>lua gofmt()<cr>', {noremap = true})

        -- Use control+dir to move between windows.
        local dirs = {'h', 'j', 'k', 'l'}
        for _, dir in ipairs(dirs) do
                vim.keymap.set('n', '<c-' .. dir .. '>', '<c-w>' .. dir, {noremap = true})
        end

        -- Movement
        vim.keymap.set('n', '<c-d>', '<c-d>zz', {noremap = true})
        vim.keymap.set('n', '<c-u>', '<c-u>zz', {noremap = true})

        -- Leave insert mode quickly.
        vim.keymap.set('i', 'jk', '<esc>', {noremap = true})
        vim.keymap.set('t', 'jk', '<c-\\><c-n>', {noremap = true})
        vim.keymap.set('t', '<m-l>', '<c-\\><c-n><cmd>tabnext<cr>', {noremap = true})
        vim.keymap.set('t', '¬', '<c-\\><c-n><cmd>tabnext<cr>', {noremap = true})
        vim.keymap.set('t', '<m-h>', '<c-\\><c-n><cmd>tabprevious<cr>', {noremap = true})
        vim.keymap.set('t', '˙', '<c-\\><c-n><cmd>tabprevious<cr>', {noremap = true})
        vim.keymap.set('i', 'jl', '<esc>:w<cr>', {noremap = true})
        vim.keymap.set('i', 'j;', '<esc>:w<cr>:so<cr>', {noremap = true})

        -- Tabs.
        vim.keymap.set('n', '<m-l>', '<cmd>tabnext<cr>', {noremap = true})
        vim.keymap.set('n', '¬', '<cmd>tabnext<cr>', {noremap = true})
        vim.keymap.set('n', '<m-h>', '<cmd>tabprevious<cr>', {noremap = true})
        vim.keymap.set('n', '˙', '<cmd>tabprev<cr>', {noremap = true})
        vim.keymap.set('n', '<leader>tn', '<cmd>tabnew<cr>', {noremap = true})
        function duplicateTab()
                local buf = vim.api.nvim_buf_get_number(0)
                local cur = vim.api.nvim_win_get_cursor(0)
                vim.cmd("tabnew")
                vim.api.nvim_win_set_buf(0, buf)
                vim.api.nvim_win_set_cursor(0, cur)
        end
        vim.keymap.set('n', '<leader>td', '<cmd>lua duplicateTab()<cr>', {noremap = true})

        -- Show and hide blank space.
        vim.keymap.set('n', '<leader>sws', ':set listchars=space:_,tab:>~ list<cr>', {noremap = true})
        vim.keymap.set('n', '<leader>hws', ':set listchars=eol:$ nolist<cr>', {noremap = true})

        -- Quick open files
        vim.keymap.set('n', '<leader>on', ':e ~/notes.txt<cr>', {noremap = true}) -- open notes

        -- Copy
        vim.keymap.set('n', '<leader>fy', ':lua R("porter.clipboard").CopyTo(vim.fn.expand("%"), true)<cr>', {noremap = true}) -- filename to clipboard
        vim.keymap.set('v', '<leader>y', '"+y:lua R("porter.clipboard").CopyTo(vim.fn.getreg("+"))<cr>', {noremap = true}) -- visual mode contents to clipboard

        -- Paste Mode toggle
        vim.keymap.set('n', '<leader>p', ':set paste!<cr>:echo "paste mode: ". &paste<cr>', {noremap = true})

        -- Terminal stuff
        local termGroup = vim.api.nvim_create_augroup("term", {
                clear = true
        })
        vim.api.nvim_create_autocmd("TermOpen", {
                command = "match Visual /^phaet:.*/",
                group = termGroup,
        })

        -- Buffer
        vim.keymap.set({'n'}, '<leader>bd', function() vim.api.nvim_buf_delete(0, {force = true}) end, {})
end

return M

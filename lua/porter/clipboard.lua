local M = {}

function M.setup()
end

-- Copy text to clipboard.
-- Refactored this into its own function so that if it needs to be tweaked, it
-- only needs to be tweaked in one place.
-- Works on OS X but for a chromebook you'd likely need to do something like
-- https://sunaku.github.io/tmux-yank-osc52.html
function M.CopyTo(text)
        vim.cmd([[let @+=]] .. vim.fn.shellescape(text))
end

return M


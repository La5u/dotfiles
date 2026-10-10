vim.keymap.set('v', '<C-S-C>', '"+y', { noremap = true, silent = true, desc = 'Copy to system clipboard' })

-- Ctrl+Shift+V to paste from system clipboard
vim.keymap.set({'n', 'i'}, '<C-S-V>', '"+p', { noremap = true, silent = true, desc = 'Paste from system clipboard' })
-- Also map in insert mode without leaving insert mode
vim.keymap.set('i', '<C-S-V>', '<C-r>+', { noremap = true, silent = true, desc = 'Paste from system clipboard' })

-- --------------------------------------------
-- Line numbers
-- --------------------------------------------
vim.opt.number = true          -- Show current line number
vim.opt.relativenumber = true  -- Show relative line numbers

-- --------------------------------------------
-- Indentation (tabs as 4 spaces)
-- --------------------------------------------
vim.opt.tabstop = 4        -- Number of spaces that a <Tab> counts for
vim.opt.shiftwidth = 4     -- Number of spaces to use for each step of (auto)indent
vim.opt.softtabstop = 4    -- Number of spaces that a <Tab> counts for while editing
vim.opt.expandtab = true   -- Convert tabs to spaces

-- Minimal init for plenary test runner
-- Usage: nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

-- Add current config to runtimepath
vim.opt.runtimepath:prepend(vim.fn.expand("~/.config/nvim"))

-- Add plenary to runtimepath (lazy.nvim location)
vim.opt.runtimepath:append(vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim"))

-- Minimal settings for testing
vim.opt.swapfile = false
vim.opt.backup = false

-- Load plenary
vim.cmd("runtime plugin/plenary.vim")

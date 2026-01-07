local ufo = require("ufo")

vim.o.foldcolumn = "0" -- hide + sign from gutter
vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
vim.o.foldlevelstart = 99
vim.o.foldenable = true
vim.o.foldmethod = "expr"

-- Map using the actual key notation Neovim sees
vim.keymap.set("n", "<S-D-=>", ufo.openAllFolds, { noremap = true, silent = true })
vim.keymap.set("n", "<S-D-->", ufo.closeAllFolds, { noremap = true, silent = true })
-- Alt combinations for single fold
vim.keymap.set("n", "<M-=>", "zo", { noremap = true, silent = true })
vim.keymap.set("n", "<M-->", "zc", { noremap = true, silent = true })

local function provider(_, _, _)
	return { "treesitter", "indent" }
end

-- https://github.com/kevinhwang91/nvim-ufo#customize-fold-text
local function handler(virtText, lnum, endLnum, width, truncate)
	local filetype = vim.bo.filetype

	if filetype == "go" then
		virtText = require("gleb.folding.go"):handle(virtText, lnum, endLnum, width, truncate)
	elseif filetype == "lua" then
		virtText = require("gleb.folding.lua"):handle(virtText, lnum, endLnum, width, truncate)
	else
		table.insert(virtText, { " ... " }) -- default text
	end

	return virtText
end

ufo.setup({
	provider_selector = provider,
	fold_virt_text_handler = handler,
})

require("foldsigns").setup()

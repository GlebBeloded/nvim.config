local ufo = require("ufo")

vim.o.foldcolumn = "0" -- hide + sign from gutter
vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
vim.o.foldlevelstart = 99
vim.o.foldenable = true
vim.o.foldmethod = "expr"

vim.keymap.set("n", "<A-+>", ufo.openAllFolds)
vim.keymap.set("n", "<A-_>", ufo.closeAllFolds)
vim.keymap.set("n", "<A-=>", "zo<CR>")
vim.keymap.set("n", "<A-->", "zc<CR>")

local function provider(bufnr, filetype, buftype)
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

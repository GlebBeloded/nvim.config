local ufo = require("ufo")

vim.cmd([[ set foldlevel=20 ]])
vim.cmd([[ set foldmethod=expr ]])

vim.o.foldcolumn = "0" -- hide + sign from gutter
vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
vim.o.foldlevelstart = 99
vim.o.foldenable = true

vim.keymap.set("n", "<A-+>", ufo.openAllFolds)
vim.keymap.set("n", "<A-_>", ufo.closeAllFolds)
vim.keymap.set("n", "<A-=>", "zo<CR>")
vim.keymap.set("n", "<A-->", "zc<CR>")

local function provider(bufnr, filetype, buftype)
	return { "treesitter", "indent" }
end

-- https://github.com/kevinhwang91/nvim-ufo#customize-fold-text
local function handler(virtText, lnum, endLnum, width, truncate)
	local newVirtText = {}
	local suffix = ("  %d "):format(endLnum - lnum)
	local sufWidth = vim.fn.strdisplaywidth(suffix)
	local targetWidth = width - sufWidth
	local curWidth = 0
	for _, chunk in ipairs(virtText) do
		local chunkText = chunk[1]
		print(chunkText)

		local chunkWidth = vim.fn.strdisplaywidth(chunkText)
		if targetWidth > curWidth + chunkWidth then
			table.insert(newVirtText, chunk)
		else
			chunkText = truncate(chunkText, targetWidth - curWidth)
			local hlGroup = chunk[2]
			table.insert(newVirtText, { chunkText, hlGroup })
			chunkWidth = vim.fn.strdisplaywidth(chunkText)
			-- str width returned from truncate() may less than 2nd argument, need padding
			if curWidth + chunkWidth < targetWidth then
				suffix = suffix .. (" "):rep(targetWidth - curWidth - chunkWidth)
			end
			break
		end
		curWidth = curWidth + chunkWidth
	end
	table.insert(newVirtText, { suffix, "MoreMsg" })
	return newVirtText
end

ufo.setup({
	provider_selector = provider,
	fold_virt_text_handler = handler,
})

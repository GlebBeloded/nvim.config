local M = {}

local function set_prompt_keymaps(event)
	vim.keymap.set({ "n", "i" }, "<S-CR>", "<Cmd>write<CR>", {
		buffer = event.buf,
		desc = "99: Submit prompt",
	})
end

function M.setup()
	local group = vim.api.nvim_create_augroup("gleb_ai_prompt_keymaps", { clear = true })
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = "99",
		callback = set_prompt_keymaps,
	})
end

return M

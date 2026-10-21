local M = {}

local palette = require("gleb.colors.gruvbox-material.palette")

local function apply()
	vim.api.nvim_set_hl(0, "GitCommittedSign", { fg = palette.foreground.purple })
end

---@return nil
function M.setup()
	apply()
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("gleb_git_committed_sign_highlights", { clear = true }),
		callback = apply,
	})
end

return M

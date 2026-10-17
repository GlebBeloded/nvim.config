-- Toggle basedpyright's type-checking mode on the fly.
-- Registers :PyTypeCheckOn (basic) and :PyTypeCheckOff (off).
local M = {}

local function restart_basedpyright()
	vim.lsp.enable("basedpyright", false)
	vim.lsp.enable("basedpyright", true)
end

local function set_type_checking(mode)
	vim.lsp.config("basedpyright", {
		settings = { basedpyright = { analysis = { typeCheckingMode = mode } } },
	})
	restart_basedpyright()
end

function M.setup()
	vim.api.nvim_create_user_command("PyTypeCheckOn", function()
		set_type_checking("basic")
	end, { desc = "basedpyright: enable type checking (basic)" })

	vim.api.nvim_create_user_command("PyTypeCheckOff", function()
		set_type_checking("off")
	end, { desc = "basedpyright: disable type checking" })
end

return M

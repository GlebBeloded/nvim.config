-- Toggle basedpyright's type-checking mode on the fly.
-- Registers :PyTypeCheckOn (basic) and :PyTypeCheckOff (off).
local M = {}

local function restart_basedpyright()
	for _, client in ipairs(vim.lsp.get_clients({ name = "basedpyright" })) do
		vim.lsp.stop_client(client.id)
	end
	vim.cmd("edit") -- reattach the LSP to the current buffer
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

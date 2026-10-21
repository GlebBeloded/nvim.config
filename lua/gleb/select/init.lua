---@param items any[]
---@param opts? table
---@param on_choice fun(item: any?, index: integer?)
---@return any
local function select(items, opts, on_choice)
	if not _G.MiniPick then
		require("gleb.picker.frame").setup()
	end
	require("gleb.picker.select")
	return vim.ui.select(items, opts, on_choice)
end

vim.ui.select = select

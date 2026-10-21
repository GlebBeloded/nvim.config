local default_select = vim.ui.select

---@param items any[]
---@param opts? table
---@param on_choice fun(item: any?, index: integer?)
---@return any
local function select(items, opts, on_choice)
	if not _G.MiniPick then
		require("gleb.picker.select")
		if vim.ui.select == select then
			vim.ui.select = default_select
			return default_select(items, opts, on_choice)
		end
		require("gleb.picker.frame").setup()
	else
		require("gleb.picker.select")
	end
	return vim.ui.select(items, opts, on_choice)
end

vim.ui.select = select

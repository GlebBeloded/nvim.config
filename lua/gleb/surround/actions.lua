-- Surround actions bind nvim-surround's `<Plug>` targets; its default keys are off (plugins.lua).

---@param plug string
---@return fun()
local function feed(plug)
	return function()
		vim.api.nvim_feedkeys(vim.keycode(plug), "m", false)
	end
end

---@param id string
---@param title string
---@param mode string
---@param target string `<Plug>(nvim-surround-…)` suffix
---@return gleb.Action
local function surround_action(id, title, mode, target)
	local plug = ("<Plug>(nvim-surround-%s)"):format(target)
	return {
		id = "surround." .. id,
		title = title,
		category = "Surround",
		modes = { mode },
		plug = plug,
		run = feed(plug),
	}
end

---@type gleb.Action[]
local actions = {
	surround_action("insert", "Insert Surrounding", "i", "insert"),
	surround_action("insert_line", "Insert Surrounding on Line", "i", "insert-line"),
	surround_action("add", "Add Surrounding", "n", "normal"),
	surround_action("add_line", "Add Surrounding on Current Line", "n", "normal-cur"),
	surround_action("add_on_lines", "Add Surrounding on Lines", "n", "normal-line"),
	surround_action("add_current_on_lines", "Add Surrounding on Current Lines", "n", "normal-cur-line"),
	surround_action("delete", "Delete Surrounding", "n", "delete"),
	surround_action("change", "Change Surrounding...", "n", "change"),
	surround_action("change_on_lines", "Change Surrounding on Lines...", "n", "change-line"),
	surround_action("visual", "Add Surrounding to Selection", "x", "visual"),
	surround_action("visual_line", "Add Surrounding to Selected Lines", "x", "visual-line"),
}

return actions

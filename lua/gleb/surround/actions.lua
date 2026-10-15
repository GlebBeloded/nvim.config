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
	surround_action("insert", "Insert", "i", "insert"),
	surround_action("insert_line", "Insert line", "i", "insert-line"),
	surround_action("add", "Add", "n", "normal"),
	surround_action("add_line", "Add line", "n", "normal-cur"),
	surround_action("add_on_lines", "Add on lines", "n", "normal-line"),
	surround_action("add_current_on_lines", "Add current on lines", "n", "normal-cur-line"),
	surround_action("delete", "Delete", "n", "delete"),
	surround_action("change", "Change", "n", "change"),
	surround_action("change_on_lines", "Change on lines", "n", "change-line"),
	surround_action("visual", "Visual", "x", "visual"),
	surround_action("visual_line", "Visual line", "x", "visual-line"),
}

return actions

local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	child.cmd("edit " .. vim.fn.fnameescape(vim.fn.tempname() .. ".lua"))
	child.wait_very_lazy()
	child.lua([[
		vim.wo.foldmethod = "manual"
		vim.api.nvim_buf_set_lines(0, 0, -1, false, {
			"local first = {",
			"  value = 1,",
			"}",
			"local second = {",
			"  value = 2,",
			"}",
		})
		vim.cmd("1,3fold")
		vim.cmd("4,6fold")
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
	]])
end

local T = H.child_set(child, start)

local function fold_state()
	return child.lua_get([[{ vim.fn.foldclosed(1), vim.fn.foldclosed(4) }]])
end

---@param lhs string
---@param desc string
local function expect_action_mapping(lhs, desc)
	eq(child.lua_get(([[vim.fn.maparg(%q, "n", false, true).desc]]):format(lhs)), desc)
end

T["folding: Fold keys invoke registered actions"] = function()
	eq(fold_state(), { 1, 4 })

	expect_action_mapping("<M-=>", "Fold: Expand Fold")
	child.type_keys("<M-=>")
	eq(fold_state(), { -1, 4 })

	expect_action_mapping("<M-->", "Fold: Collapse Fold")
	child.type_keys("<M-->")
	eq(fold_state(), { 1, 4 })

	expect_action_mapping("<S-D-=>", "Fold: Expand All Folds")
	child.type_keys("<S-D-=>")
	eq(fold_state(), { -1, -1 })

	expect_action_mapping("<S-D-->", "Fold: Collapse All Folds")
	child.type_keys("<S-D-->")
	eq(fold_state(), { 1, 4 })
end

T["folding: Fold keys without a fold do nothing"] = function()
	child.cmd("normal! zE")
	local lines = child.lua_get([[vim.api.nvim_buf_get_lines(0, 0, -1, false)]])
	local cursor = child.lua_get([[vim.api.nvim_win_get_cursor(0)]])

	for _, lhs in ipairs({ "<M-=>", "<M-->" }) do
		child.lua([[vim.v.errmsg = ""]])
		child.type_keys(lhs)

		eq(child.lua_get([[vim.api.nvim_buf_get_lines(0, 0, -1, false)]]), lines)
		eq(child.lua_get([[vim.api.nvim_win_get_cursor(0)]]), cursor)
		eq(child.lua_get([[vim.v.errmsg]]), "")
	end
end

return T

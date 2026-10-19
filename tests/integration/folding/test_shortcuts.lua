local MiniTest = require("mini.test")
local F = require("tests.fixtures")
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

local function open_billing_changes()
	local root = F.copy("billing", vim.fn.tempname() .. "/billing")
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("enew")
	child.lua([[
		local catalog = require("gleb.actions").state.applicator.catalog
		local action = assert(catalog:get("changes.toggle"), "changes.toggle is not registered")
		action.run(require("gleb.actions.context").capture())
	]])
	assert(
		child.wait(
			[[(function()
			local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return view ~= nil and #view.rows > 0
		end)()]],
			3000
		),
		"Changes panel did not draw its initial rows"
	)
end

---@param text string
---@return boolean
local function select_changes_row(text)
	return child.lua_get(
		[[(function(text)
			for row, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
				if line:find(text, 1, true) then
					vim.api.nvim_win_set_cursor(0, { row, 0 })
					return true
				end
			end
			return false
		end)(...)]],
		{ text }
	)
end

---@param text string
---@return boolean
local function changes_has(text)
	return child.lua_get(
		[[(function(text)
			return vim.iter(vim.api.nvim_buf_get_lines(0, 0, -1, false)):any(function(line)
				return line:find(text, 1, true) ~= nil
			end)
		end)(...)]],
		{ text }
	)
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

T["folding: Collapse Fold key folds the group under the tree cursor"] = function()
	open_billing_changes()
	assert(select_changes_row("web/src 1"), "Changes row not found: web/src 1")
	child.lua([[vim.v.errmsg = ""]])

	local close_ok = pcall(child.type_keys, "<M-->")
	local after_close = { changes_has("price.ts"), close_ok, child.lua_get([[vim.v.errmsg]]) }
	local open_ok = pcall(child.type_keys, "<M-=>")
	local after_open = { changes_has("price.ts"), open_ok, child.lua_get([[vim.v.errmsg]]) }

	eq({ after_close, after_open }, {
		{ false, true, "" },
		{ true, true, "" },
	})
end

return T

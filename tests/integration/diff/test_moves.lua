local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local root
local manifest

local function start()
	root, manifest = F.copy("diffgo", vim.fn.tempname())
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
end

local T = H.child_set(child, start)

local function open_ids()
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(manifest.ids))
	child.lua([[
		local actions = require("gleb.actions")
		local action = assert(actions.state.applicator.catalog:get("diff.open_file"))
		assert(require("gleb.actions.context").execute(action, require("gleb.actions.context").capture()))
	]])
end

---@param side "left"|"right"
---@param line integer
local function focus(side, line)
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	local win = side == "left" and view.left_win or view.right_win
	child.api.nvim_set_current_win(win)
	child.api.nvim_win_set_cursor(win, { line, 0 })
end

T["diff: Diff view marks both ends of a moved block"] = function()
	open_ids()

	local moved = child.lua_get([[(function()
		local view = require("gleb.diff.view").current()
		local layout = require("gleb.diff.view.layout")
		local function line_groups(buf, first, last)
			local result = {}
			for line = first, last do
				local groups = {}
				for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, view.ns, { line - 1, 0 }, { line - 1, -1 }, { details = true })) do
					if mark[4].hl_group then groups[mark[4].hl_group] = true end
				end
				result[#result + 1] = groups.DiffViewMoved == true
			end
			return result
		end
		local gutters = {}
		for _, row in ipairs(view.layout.rows) do
			if (row.left == 3 and not row.right) or (row.right == 11 and not row.left) then
				gutters[#gutters + 1] = layout.gutter(row)
			end
		end
		return {
			left = line_groups(view.left_buf, 3, 9),
			right = line_groups(view.right_buf, 11, 17),
			gutters = gutters,
		}
	end)()]])

	eq(moved.left, { true, true, true, true, true, true, true })
	eq(moved.right, { true, true, true, true, true, true, true })
	eq(moved.gutters, { "»  3 →11  ╱╱╱╱󰄱 ", "»╱╱╱╱←3    11 󰄱 " })
end

T["diff: Diff view gm jumps between the ends of a move"] = function()
	open_ids()
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	focus("right", 13)

	child.type_keys("gm")
	eq(child.api.nvim_get_current_win(), view.left_win)
	eq(child.api.nvim_win_get_cursor(view.left_win)[1], 3)

	child.type_keys("gm")
	eq(child.api.nvim_get_current_win(), view.right_win)
	eq(child.api.nvim_win_get_cursor(view.right_win)[1], 11)
end

T["diff: Diff view gm off a move does nothing"] = function()
	open_ids()
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	focus("right", 1)
	eq(child.lua_get([[vim.fn.maparg("gm", "n", false, true).desc]]), "Git | Diff: Jump to Other End of Move")

	child.type_keys("gm")

	eq(child.api.nvim_get_current_win(), view.right_win)
	eq(child.api.nvim_win_get_cursor(view.right_win)[1], 1)
end

T["diff: Diff view move colours"] = function()
	child.cmd("colorscheme gruvbox-material")
	local colours = child.lua_get([[(function()
		local p = require("gleb.colors.gruvbox-material.palette")
		local blend = require("gleb.colors.gruvbox-material.util").blend
		return {
			aqua = p.foreground.aqua,
			grey = p.foreground.grey1,
			tint = blend(p.foreground.aqua, p.background.bg0, 0.72),
		}
	end)()]])

	H.expect_hl_colors(child, "DiffViewMoved", { bg = colours.tint })
	H.expect_hl_colors(child, "DiffViewGutterMoved", { fg = colours.grey, bg = colours.tint })
	H.expect_hl_colors(child, "DiffViewMovedMarker", { fg = colours.aqua, bg = colours.tint })
end

return T

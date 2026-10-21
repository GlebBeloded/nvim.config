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

---@param path string
local function edit(path)
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(path))
end

local function open_diff()
	child.lua([[
		local actions = require("gleb.actions")
		local action = assert(actions.state.applicator.catalog:get("diff.open_file"))
		assert(require("gleb.actions.context").execute(action, require("gleb.actions.context").capture()))
	]])
end

local function open_controller()
	edit(manifest.controller)
	open_diff()
end

local function fold_state()
	return child.lua_get([[(function()
		local view = require("gleb.diff.view").current()
		local result = {}
		for _, win in ipairs({ view.left_win, view.right_win }) do
			result[#result + 1] = vim.api.nvim_win_call(win, function()
				return { vim.fn.foldclosed(1), vim.fn.foldclosed(70) }
			end)
		end
		return result
	end)()]])
end

T["diff: Diff view zo opens a fold in both windows"] = function()
	open_controller()
	child.api.nvim_win_set_cursor(child.lua_get([[require("gleb.diff.view").current().right_win]]), { 1, 0 })
	child.type_keys("zo")

	eq(fold_state(), { { -1, 70 }, { -1, 70 } })
end

T["diff: Diff view zR toggles every fold"] = function()
	open_controller()
	child.type_keys("zR")
	eq(fold_state(), { { -1, -1 }, { -1, -1 } })

	child.type_keys("zR")
	eq(fold_state(), { { 1, 70 }, { 1, 70 } })
end

T["diff: Diff view scrolls both windows together"] = function()
	open_controller()
	child.type_keys("zR", "62zt")

	local view = child.lua_get([[require("gleb.diff.view").current()]])
	eq(
		child.lua_get(
			[[vim.api.nvim_win_call(..., function() return vim.fn.winsaveview().topline end)]],
			{ view.right_win }
		),
		62
	)
	eq(
		child.lua_get(
			[[vim.api.nvim_win_call(..., function() return vim.fn.winsaveview().topline end)]],
			{ view.left_win }
		),
		61
	)
end

T["diff: Diff view maps the cursor across changes"] = function()
	open_controller()
	local view = child.lua_get([[require("gleb.diff.view").current()]])

	child.api.nvim_win_set_cursor(view.right_win, { 58, 0 })
	child.api.nvim_exec_autocmds("CursorMoved", { buffer = view.right_buf })
	eq(child.api.nvim_win_get_cursor(view.left_win)[1], 58)
	child.api.nvim_win_set_cursor(view.right_win, { 59, 0 })
	child.api.nvim_exec_autocmds("CursorMoved", { buffer = view.right_buf })
	eq(child.api.nvim_win_get_cursor(view.left_win)[1], 58)
	child.api.nvim_set_current_win(view.left_win)
	child.api.nvim_win_set_cursor(view.left_win, { 65, 0 })
	child.api.nvim_exec_autocmds("CursorMoved", { buffer = view.left_buf })
	eq(child.api.nvim_win_get_cursor(view.right_win)[1], 66)
end

T["diff: Diff view gf opens the file at the cursor line"] = function()
	open_controller()
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	child.api.nvim_set_current_win(view.left_win)
	child.api.nvim_win_set_cursor(view.left_win, { 65, 0 })

	child.type_keys("gf")

	eq(child.api.nvim_list_tabpages(), { child.api.nvim_get_current_tabpage() })
	eq(
		vim.uv.fs_realpath(child.api.nvim_buf_get_name(0)),
		vim.uv.fs_realpath(vim.fs.joinpath(root, manifest.controller))
	)
	eq(child.api.nvim_win_get_cursor(0)[1], 66)
	eq(
		child.lua_get([[vim.iter(vim.api.nvim_list_wins()):any(function(win)
		return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "gleb-diff"
	end)]]),
		false
	)
end

T["diff: Diff view gf on a read-only right side"] = function()
	local path = vim.fs.joinpath(root, "c.txt")
	vim.fn.writefile({ "one", "two" }, path)
	local view = child.lua_get(
		[[(function(path)
		vim.cmd("only")
		local first = vim.api.nvim_get_current_win()
		vim.cmd("vsplit")
		local second = vim.api.nvim_get_current_win()
		vim.api.nvim_set_current_win(first)
		local view = assert(require("gleb.diff.view").show(second, {
			path = path,
			left = { "one", "two" },
			right = { "one", "too", "three" },
			labels = { left = "parent", right = "commit" },
			committed = true,
		}))
		vim.api.nvim_set_current_win(view.right_win)
		vim.api.nvim_win_set_cursor(view.right_win, { 3, 0 })
		return { right_win = view.right_win }
	end)(...)]],
		{ path }
	)

	child.type_keys("gf")

	eq(child.api.nvim_get_current_win(), view.right_win)
	eq(vim.uv.fs_realpath(child.api.nvim_buf_get_name(0)), vim.uv.fs_realpath(path))
	eq(child.api.nvim_win_get_cursor(0)[1], 2)
	eq(
		child.lua_get([[vim.iter(vim.api.nvim_list_wins()):any(function(win)
		return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "gleb-diff"
	end)]]),
		false
	)
end

T["diff: Diff view keys stay native outside view windows"] = function()
	edit(manifest.controller)
	child.lua([[vim.keymap.set("n", "]c", function() vim.g.shadowed_next_change = true end, { buffer = true })]])
	open_diff()
	local origin = child.lua_get([[require("gleb.diff.view").current().origin_win]])
	child.api.nvim_set_current_win(origin)
	child.cmd("setlocal foldmethod=manual | 1,10fold")
	child.api.nvim_win_set_cursor(origin, { 1, 0 })
	eq(child.fn.foldclosed(1), 1)

	child.type_keys("zo")
	eq(child.fn.foldclosed(1), -1)
	child.type_keys("]c")
	eq(child.g.shadowed_next_change, true)
end

T["diff: Diff view ]c and [c walk the changes"] = function()
	open_controller()
	local view = child.lua_get([[require("gleb.diff.view").current()]])

	child.type_keys("]c")
	eq(child.api.nvim_win_get_cursor(view.right_win)[1], 58)
	child.type_keys("]c")
	eq(child.api.nvim_win_get_cursor(view.right_win)[1], 66)
	child.type_keys("]c")
	eq(child.api.nvim_win_get_cursor(view.right_win)[1], 66)
	child.type_keys("[c")
	eq(child.api.nvim_win_get_cursor(view.right_win)[1], 58)
end

T["diff: Diff view ]c on the left side"] = function()
	open_controller()
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	child.api.nvim_set_current_win(view.left_win)
	child.api.nvim_win_set_cursor(view.left_win, { 53, 0 })

	child.type_keys("]c")
	eq(child.api.nvim_win_get_cursor(view.left_win)[1], 58)
	child.type_keys("]c")
	eq(child.api.nvim_win_get_cursor(view.left_win)[1], 65)
end

T["diff: Diff view left window is read-only"] = function()
	open_controller()
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	local before = child.api.nvim_buf_get_lines(view.left_buf, 0, -1, false)
	child.api.nvim_set_current_win(view.left_win)
	child.api.nvim_win_set_cursor(view.left_win, { 53, 0 })

	pcall(child.type_keys, "x")

	eq(child.api.nvim_buf_get_lines(view.left_buf, 0, -1, false), before)
	eq(child.lua_get("vim.bo[...].modifiable", { view.left_buf }), false)
end

T["diff: Diff view re-diffs after an edit"] = function()
	open_controller()
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	child.api.nvim_win_set_cursor(view.right_win, { 58, 0 })

	child.type_keys(10, "dd")
	local redrawn = child.wait([[#require("gleb.diff.view").current().fragments == 2]], 1000 * H.load_factor())
	eq(redrawn, true)
	eq(
		child.lua_get([[(function()
		local view = require("gleb.diff.view").current()
		for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(view.left_buf, view.ns, 0, -1, { details = true })) do
			if mark[4].virt_lines then return true end
		end
		return false
	end)()]]),
		false
	)

	child.type_keys(10, "u")
	eq(child.wait([[#require("gleb.diff.view").current().fragments == 3]], 1000 * H.load_factor()), true)
end

T["diff: Diff view marks an approximate comparison"] = function()
	edit(manifest.controller)
	child.lua([[require("gleb.diff.view").config.timeout_ms = 0]])
	open_diff()

	local view = child.lua_get([[require("gleb.diff.view").current()]])
	eq(child.lua_get("vim.wo[...].winbar", { view.right_win }), "                Your version · approximate diff")
end

return T

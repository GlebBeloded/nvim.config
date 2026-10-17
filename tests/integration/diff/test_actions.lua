local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local root
local manifest

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

---@param fixture string
---@param path string
local function open_view(fixture, path)
	root, manifest = F.copy(fixture, vim.fn.tempname())
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(path))
	child.lua([[
		local actions = require("gleb.actions")
		local action = assert(actions.state.applicator.catalog:get("diff.open_file"))
		assert(require("gleb.actions.context").execute(action, require("gleb.actions.context").capture()))
	]])
end

local function open_controller()
	root, manifest = F.copy("diffgo", vim.fn.tempname())
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(manifest.controller))
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

---@param line integer right-side line
---@return string?
local function checkbox(line)
	return child.lua_get(
		[[(function(...)
		local line = ...
		for _, row in ipairs(require("gleb.diff.view").current().layout.rows) do
			if row.right == line and row.first then return row.checkbox end
		end
	end)(...)]],
		{ line }
	)
end

T["diff: Diff view do reverts a changed line"] = function()
	open_controller()
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	local disk = vim.fn.readfile(vim.fs.joinpath(root, manifest.controller))[53]
	focus("right", 53)

	child.type_keys("do")

	eq(child.api.nvim_buf_get_lines(view.right_buf, 52, 53, false), { "\t\treturn err" })
	eq(child.lua_get("vim.bo[...].modified", { view.right_buf }), true)
	eq(vim.fn.readfile(vim.fs.joinpath(root, manifest.controller))[53], disk)
	eq(#child.lua_get([[require("gleb.diff.view").current().fragments]]), 2)
end

T["diff: Diff view dp reverts a deletion from the left window"] = function()
	open_controller()
	focus("left", 65)
	local left_win = child.api.nvim_get_current_win()

	child.type_keys("dp")

	local right_buf = child.lua_get([[require("gleb.diff.view").current().right_buf]])
	eq(child.api.nvim_buf_get_lines(right_buf, 65, 67, false), {
		"\tc.stats.LastRun.Touch()",
		"\treturn nil",
	})
	eq(child.api.nvim_get_current_win(), left_win)
end

T["diff: Diff view reverts an insertion as one undo step"] = function()
	open_controller()
	focus("right", 58)

	child.type_keys("do")
	local right_buf = child.lua_get([[require("gleb.diff.view").current().right_buf]])
	eq(child.api.nvim_buf_line_count(right_buf), 150)
	eq(child.fn.search("c.stats.Skipped.Inc()", "nw"), 0)

	child.type_keys("u")
	eq(child.api.nvim_buf_line_count(right_buf), 151)
	eq(child.wait([[#require("gleb.diff.view").current().fragments == 3]], 1000 * H.load_factor()), true)
end

T["diff: Diff view revert off a change does nothing"] = function()
	open_controller()
	local notifications = H.record_notify(child)
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	focus("right", 50)
	local changedtick = child.lua_get("vim.b[...].changedtick", { view.right_buf })

	child.type_keys("do")

	eq(child.lua_get("vim.b[...].changedtick", { view.right_buf }), changedtick)
	eq(notifications(), {})
end

T["diff: Diff view checkboxes follow the index"] = function()
	open_view("dirty", "d.txt")

	eq(checkbox(1), "󰄲")
	eq(checkbox(3), "󰄱")
end

T["diff: Diff view checkbox of a partly staged change"] = function()
	open_controller()
	focus("right", 53)
	child.type_keys("<Space>")
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	child.api.nvim_buf_set_lines(view.right_buf, 52, 53, false, { "\t\treturn wrap(err, id)" })

	eq(
		child.wait([[require("gleb.diff.view").current().layout.rows[6].checkbox == "󰡖"]], 1000 * H.load_factor()),
		true
	)
end

T["diff: Diff view Space stages one change"] = function()
	open_controller()
	focus("right", 53)

	child.type_keys("<Space>")

	local staged = H.git(root, { "diff", "--cached", "-U0" }):gsub("index [^\n]+", "index <blobs>")
	eq(
		staged,
		table.concat({
			"diff --git a/internal/user/controller.go b/internal/user/controller.go",
			"index <blobs>",
			"--- a/internal/user/controller.go",
			"+++ b/internal/user/controller.go",
			"@@ -53 +53 @@ func (c *Ctl) Drop(id string) error {",
			"-\t\treturn err",
			"+\t\treturn wrap(err)",
			"",
		}, "\n")
	)
	local working = H.git(root, { "diff", "-U0" })
	eq(working:find("+\t\tc.stats.Skipped.Inc()", 1, true) ~= nil, true)
	eq(working:find("-\tc.stats.LastRun.Touch()", 1, true) ~= nil, true)
	eq(checkbox(53), "󰄲")
end

T["diff: Diff view Space unstages a staged change"] = function()
	open_controller()
	focus("right", 53)

	child.type_keys("<Space>")
	child.type_keys("<Space>")

	eq(H.git(root, { "diff", "--cached" }), "")
	eq(checkbox(53), "󰄱")
end

T["diff: Diff view stages an insertion and a deletion separately"] = function()
	open_controller()
	focus("right", 58)
	child.type_keys("<Space>")
	focus("right", 66)

	child.type_keys("<Space>")

	local staged = H.git(root, { "diff", "--cached", "-U0" })
	eq(staged:find("+\t\tc.stats.Skipped.Inc()", 1, true) ~= nil, true)
	eq(staged:find("-\tc.stats.LastRun.Touch()", 1, true) ~= nil, true)
	eq(staged:find("return wrap(err)", 1, true), nil)
end

T["diff: Diff view reports a staging failure"] = function()
	open_controller()
	local notifications = H.record_notify(child)
	H.write_files(root, { [".git/index.lock"] = "" })
	focus("right", 53)

	child.type_keys("<Space>")

	eq(notifications()[1].msg:sub(1, 14), "Stage failed: ")
	eq(notifications()[1].level, vim.log.levels.ERROR)
	eq(H.git(root, { "diff", "--cached" }), "")
	eq(checkbox(53), "󰄱")
end

return T

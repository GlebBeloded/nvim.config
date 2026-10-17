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

T["diff: Diff view actions reject a file absent from HEAD"] = function()
	root = F.copy("diffgo", vim.fn.tempname())
	local path = "internal/user/new.go"
	H.write_files(root, { [path] = "package user\n\nvar x = 1\n" })
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(path))
	local notifications = H.record_notify(child)
	child.lua([[
		local actions = require("gleb.actions")
		local action = assert(actions.state.applicator.catalog:get("diff.open_file"))
		assert(require("gleb.actions.context").execute(action, require("gleb.actions.context").capture()))
	]])
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	local before = child.api.nvim_buf_get_lines(view.right_buf, 0, -1, false)

	child.type_keys("do")
	child.type_keys("<Space>")

	eq(child.api.nvim_buf_get_lines(view.right_buf, 0, -1, false), before)
	eq(H.git(root, { "diff", "--cached" }), "")
	eq(notifications(), {
		{ msg = "Revert unavailable: file cannot be compared with HEAD", level = vim.log.levels.WARN },
		{ msg = "Stage unavailable: file cannot be compared with HEAD", level = vim.log.levels.WARN },
	})
end

T["diff: Diff view reverting the last change keeps the view open"] = function()
	root, manifest = F.copy("diffgo", vim.fn.tempname())
	H.git(root, { "checkout", "--", manifest.controller })
	local lines = vim.fn.readfile(vim.fs.joinpath(root, manifest.controller))
	lines[53] = "\t\treturn wrap(err)"
	vim.fn.writefile(lines, vim.fs.joinpath(root, manifest.controller))
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(manifest.controller))
	child.lua([[
		local actions = require("gleb.actions")
		local action = assert(actions.state.applicator.catalog:get("diff.open_file"))
		assert(require("gleb.actions.context").execute(action, require("gleb.actions.context").capture()))
	]])
	focus("right", 53)

	child.type_keys("do")

	eq(child.lua_get([[require("gleb.diff.view").current() ~= nil]]), true)
	eq(child.lua_get([[#require("gleb.diff.view").current().fragments]]), 0)
	eq(child.lua_get([[#require("gleb.diff.view").current().layout.folds]]), 0)
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

T["diff: Diff view stages a final line without a newline"] = function()
	open_view("dirty", "d.txt")
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	child.lua([[vim.bo[...].eol = false; vim.bo[...].fixeol = false]], { view.right_buf })
	focus("right", 3)

	child.type_keys("<Space>")

	eq(H.git(root, { "show", ":d.txt" }), "FIRST\nsecond\nTHIRD")
	eq(checkbox(3), "󰄲")
end

T["diff: Diff view unstages a final line with a different newline"] = function()
	open_view("dirty", "d.txt")
	H.git(root, { "reset", "HEAD" })
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	child.lua([[vim.bo[...].eol = false; vim.bo[...].fixeol = false]], { view.right_buf })
	focus("right", 3)

	child.type_keys("<Space>")
	child.type_keys("<Space>")

	eq(H.git(root, { "diff", "--cached" }), "")
	eq(checkbox(3), "󰄱")
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

T["diff: Diff view refuses staging over other staged lines"] = function()
	open_controller()
	local path = manifest.controller
	local staged = vim.fn.readfile(vim.fs.joinpath(root, path))
	staged[53] = "\t\treturn staged(err)"
	staged[54] = "\t} // staged"
	vim.fn.writefile(staged, vim.fs.joinpath(root, path))
	H.git(root, { "add", path })
	H.git(root, { "checkout", "--", path })
	local before = H.git(root, { "diff", "--cached" })
	local notifications = H.record_notify(child)
	focus("right", 53)

	child.type_keys("<Space>")

	eq(H.git(root, { "diff", "--cached" }), before)
	eq(notifications(), { { msg = "Stage failed: overlaps other staged lines", level = vim.log.levels.ERROR } })
end

local function install_leader_mapping()
	child.lua([[
		_G.diff_leader_hits = 0
		vim.keymap.set("n", "<leader>x", function() _G.diff_leader_hits = _G.diff_leader_hits + 1 end)
	]])
end

T["diff: Diff view leader mapping works inside the view"] = function()
	open_controller()
	install_leader_mapping()

	child.type_keys("<Space>x")

	eq(child.lua_get([[_G.diff_leader_hits]]), 1)
	eq(H.git(root, { "diff", "--cached" }), "")
end

T["diff: Diff view leader mapping works in another window of the same file"] = function()
	open_controller()
	install_leader_mapping()
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	child.api.nvim_set_current_win(view.origin_win)

	child.type_keys("<Space>x")

	eq(child.lua_get([[_G.diff_leader_hits]]), 1)
	eq(H.git(root, { "diff", "--cached" }), "")
end

return T

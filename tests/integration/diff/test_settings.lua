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

local function open_controller()
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(manifest.controller))
	child.lua([[
		local actions = require("gleb.actions")
		local action = assert(actions.state.applicator.catalog:get("diff.open_file"))
		assert(require("gleb.actions.context").execute(action, require("gleb.actions.context").capture()))
	]])
end

---@param line integer
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

---@param id string
---@param title string
local function choose_setting(id, title)
	child.lua([[vim.schedule(function() require("gleb.find_action").open() end)]])
	assert(child.wait("MiniPick.is_picker_active()", 5000), "Find Action did not open")
	child.lua(
		[[
		local id, title = ...
		for index, item in ipairs(MiniPick.get_picker_items()) do
			if item.action and item.action.id == id then
				assert(item.text == title)
				MiniPick.set_picker_match_inds({ index }, "current")
				return
			end
		end
		error(id .. " was not available")
	]],
		{ id, title }
	)
	child.type_keys("<CR>")
	child.type_keys("<Esc>")
end

---@param id string
---@return boolean
local function find_action_toggle(id)
	child.lua([[vim.schedule(function() require("gleb.find_action").open() end)]])
	assert(child.wait("MiniPick.is_picker_active()", 5000), "Find Action did not open")
	local value = child.lua_get(
		[[(function(...)
			for _, item in ipairs(MiniPick.get_picker_items()) do
				if item.action and item.action.id == ... then return item.glyph end
			end
		end)(...)]],
		{ id }
	)
	child.type_keys("<Esc>")
	return value
end

T["diff: Diff view trim policy hides a trailing space"] = function()
	open_controller()
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	local line = child.api.nvim_buf_get_lines(view.right_buf, 49, 50, false)[1]
	child.api.nvim_buf_set_lines(view.right_buf, 49, 50, false, { line .. " " })
	child.lua([[vim.wait(300)]])
	eq(child.lua_get([[#require("gleb.diff.view").current().fragments]]), 4)
	eq(
		child.lua_get(
			[[require("gleb.diff.view.layout").change_at(require("gleb.diff.view").current().layout, "right", 50) ~= nil]]
		),
		true
	)

	choose_setting("diff.ignore_trim", "Trim Whitespaces")

	eq(child.lua_get([[#require("gleb.diff.view").current().fragments]]), 3)
	eq(
		child.lua_get(
			[[require("gleb.diff.view.layout").change_at(require("gleb.diff.view").current().layout, "right", 50) ~= nil]]
		),
		false
	)
end

T["diff: Diff view trim policy shows a staged checkbox"] = function()
	root = H.git_repo({ ["f.txt"] = "a\nb\nc\nd\n" })
	H.write_files(root, { ["f.txt"] = "A\nb \nc\nd\n" })
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit f.txt")
	child.lua([[
		local actions = require("gleb.actions")
		local action = assert(actions.state.applicator.catalog:get("diff.open_file"))
		assert(require("gleb.actions.context").execute(action, require("gleb.actions.context").capture()))
	]])
	choose_setting("diff.ignore_trim", "Trim Whitespaces")
	local view = child.lua_get([[require("gleb.diff.view").current()]])
	child.api.nvim_set_current_win(view.right_win)
	child.api.nvim_win_set_cursor(view.right_win, { 1, 0 })

	child.type_keys("<Space>")

	eq(H.git(root, { "show", ":f.txt" }), "A\nb \nc\nd\n")
	eq(checkbox(1), "󰄲")
end

T["diff: Diff view policy hiding every change keeps the view open"] = function()
	open_controller()
	choose_setting("diff.ignore_whitespaces", "Ignore Whitespaces")
	child.lua([[require("gleb.diff.view").close(require("gleb.diff.view").current())]])
	H.git(root, { "checkout", "--", manifest.controller })
	local lines = vim.fn.readfile(vim.fs.joinpath(root, manifest.controller))
	lines[53] = lines[53]:gsub("return err", "return  err")
	vim.fn.writefile(lines, vim.fs.joinpath(root, manifest.controller))
	child.cmd("edit! " .. vim.fn.fnameescape(manifest.controller))

	open_controller()

	eq(child.lua_get([[require("gleb.diff.view").current() ~= nil]]), true)
	eq(child.lua_get([[#require("gleb.diff.view").current().fragments]]), 0)
	eq(child.lua_get([[#require("gleb.diff.view").current().layout.folds]]), 0)
end

T["diff: Diff view whitespace policy persists"] = function()
	open_controller()
	choose_setting("diff.ignore_whitespaces", "Ignore Whitespaces")
	eq(
		child.lua_get(
			[[vim.json.decode(table.concat(vim.fn.readfile(vim.fs.joinpath(vim.fn.stdpath("state"), "diff.json")), "\n")).policy]]
		),
		"ignore_whitespaces"
	)

	child.restart_config(nil, { env = F.go_env() })
	child.wait_very_lazy()
	open_controller()

	eq(child.lua_get([[require("gleb.diff.view").config.policy]]), "ignore_whitespaces")
	eq(find_action_toggle("diff.ignore_whitespaces"), true)
end

T["diff: Diff view line mode drops word highlights"] = function()
	open_controller()
	choose_setting("diff.highlight_lines", "Highlight Lines")

	local marks = child.lua_get([[(function()
		local view = require("gleb.diff.view").current()
		local function groups(buf)
			local result = {}
			for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, view.ns, { 52, 0 }, { 52, -1 }, { details = true })) do
				result[mark[4].hl_group] = true
			end
			return result
		end
		return { left = groups(view.left_buf), right = groups(view.right_buf) }
	end)()]])
	eq(marks.left.DiffViewWord, nil)
	eq(marks.right.DiffViewWord, nil)
	eq(marks.left.DiffViewChange, true)
	eq(marks.right.DiffViewChange, true)
end

T["diff: Diff view no-highlight mode shows plain texts"] = function()
	open_controller()
	choose_setting("diff.highlight_none", "Do Not Highlight")
	local before = child.api.nvim_win_get_cursor(0)
	child.type_keys("]c")

	local plain = child.lua_get([[(function()
		local view = require("gleb.diff.view").current()
		local marked = false
		for _, buf in ipairs({ view.left_buf, view.right_buf }) do
			for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, view.ns, 0, -1, { details = true })) do
				local details = mark[4]
				if details.hl_group and details.hl_group:find("^DiffView") then marked = true end
			end
		end
		local arrows = false
		for _, row in ipairs(view.layout.rows) do
			if require("gleb.diff.view.layout").gutter(row):find("»", 1, true) then arrows = true end
		end
		return {
			folds = #view.layout.folds,
			fragments = #view.fragments,
			rows = #view.layout.rows,
			wanted_rows = math.max(#view.left, #view.right),
			marked = marked,
			arrows = arrows,
		}
	end)()]])
	eq(plain, {
		folds = 0,
		fragments = 0,
		rows = plain.wanted_rows,
		wanted_rows = plain.wanted_rows,
		marked = false,
		arrows = false,
	})
	eq(child.api.nvim_win_get_cursor(0), before)

	child.lua([[require("gleb.diff.view").close(require("gleb.diff.view").current())]])
	open_controller()
	eq(child.lua_get([[require("gleb.diff.view").current() ~= nil]]), true)
end

T["diff: Diff view highlight mode persists"] = function()
	open_controller()
	choose_setting("diff.highlight_chars", "Highlight Symbols")
	eq(
		child.lua_get(
			[[vim.json.decode(table.concat(vim.fn.readfile(vim.fs.joinpath(vim.fn.stdpath("state"), "diff.json")), "\n")).highlight]]
		),
		"by_char"
	)

	child.restart_config(nil, { env = F.go_env() })
	child.wait_very_lazy()
	open_controller()

	eq(child.lua_get([[require("gleb.diff.view").config.highlight]]), "by_char")
	eq(find_action_toggle("diff.highlight_chars"), true)
end

return T

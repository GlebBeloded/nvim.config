local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local root
local manifest

local function start()
	local name = "diff-view-test-" .. vim.fn.getpid() .. "-" .. vim.fn.fnamemodify(vim.fn.tempname(), ":t")
	root, manifest = F.copy("diffgo", "/tmp/" .. name)
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
end

local T = H.child_set(child, start)
local opens_scenario = "diff: Diff view opens on the current file"
T[opens_scenario] = MiniTest.new_set()

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

local function state()
	return child.lua_get([[require("gleb.diff.view").current()]])
end

T[opens_scenario]["opens HEAD beside the real file buffer"] = function()
	edit(manifest.controller)
	local original_buf = child.api.nvim_get_current_buf()
	local expected = vim.split(H.git(root, { "show", "HEAD:" .. manifest.controller }), "\n", { plain = true })
	table.remove(expected)

	open_diff()

	local view = state()
	eq(#child.api.nvim_list_tabpages(), 2)
	eq(#child.api.nvim_tabpage_list_wins(0), 2)
	eq(child.api.nvim_win_get_buf(view.right_win), original_buf)
	eq(child.lua_get("vim.bo[...].filetype", { view.left_buf }), "gleb-diff")
	eq(child.lua_get("vim.bo[...].modifiable", { view.left_buf }), false)
	eq(child.api.nvim_buf_get_lines(view.left_buf, 0, -1, false), expected)
	eq(child.api.nvim_get_current_win(), view.right_win)
	eq(child.api.nvim_win_get_cursor(view.right_win)[1], 53)
end

T["diff: Diff view of an unchanged file opens nothing"] = function()
	H.git(root, { "checkout", "--", manifest.controller })
	edit(manifest.controller)
	local notifications = H.record_notify(child)

	open_diff()

	eq(notifications(), { { msg = "No changes", level = vim.log.levels.INFO } })
	eq(#child.api.nvim_list_tabpages(), 1)
end

T["diff: Diff view outside a repository opens nothing"] = function()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	vim.fn.writefile({ "outside" }, dir .. "/outside.txt")
	child.cmd("edit " .. vim.fn.fnameescape(dir .. "/outside.txt"))
	local notifications = H.record_notify(child)

	open_diff()

	eq(notifications(), { { msg = "Not in a git repository", level = vim.log.levels.WARN } })
	eq(#child.api.nvim_list_tabpages(), 1)
end

T["diff: Diff view of a file absent from HEAD"] = function()
	local path = "internal/user/new.go"
	vim.fn.writefile({ "package user", "", "var x = 1" }, root .. "/" .. path)
	local source_data = child.lua_get([[require("gleb.diff.view.source").current(...)]], {
		root .. "/" .. path,
		child.api.nvim_get_current_buf(),
	})
	eq(source_data.relpath, path)
	edit(path)

	open_diff()

	local view = state()
	eq(child.api.nvim_buf_get_lines(view.left_buf, 0, -1, false), { "" })
	eq(view.fragments, { { start1 = 0, end1 = 0, start2 = 0, end2 = 3 } })
end

T["diff: Diff view focuses an open view of the same file"] = function()
	edit(manifest.controller)
	open_diff()
	local view_tab = child.api.nvim_get_current_tabpage()
	child.cmd("tabfirst")

	open_diff()

	eq(#child.api.nvim_list_tabpages(), 2)
	eq(child.api.nvim_get_current_tabpage(), view_tab)
end

T[opens_scenario]["renders aligned padding rows"] = function()
	edit(manifest.controller)
	open_diff()
	local pads = child.lua_get([[(function()
		local view = require("gleb.diff.view").current()
		local marks = {}
		for _, item in ipairs({ { view.left_buf, view.left_win }, { view.right_buf, view.right_win } }) do
			local found = {}
			for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(item[1], view.ns, 0, -1, { details = true })) do
				if mark[4].virt_lines then found[#found + 1] = { mark[2], mark[4].virt_lines_above } end
			end
			marks[#marks + 1] = found
		end
		return marks
	end)()]])
	eq(pads, { { { 57, true } }, { { 65, true } } })
end

T[opens_scenario]["renders the centre gutter"] = function()
	edit(manifest.controller)
	open_diff()
	local view = state()
	local gutters = child.lua_get([[(function()
		local view = require("gleb.diff.view").current()
		local layout = require("gleb.diff.view.layout")
		local result = {}
		for _, wanted in ipairs({ 52, 53, 58 }) do
			for _, row in ipairs(view.layout.rows) do
				if row.right == wanted then result[#result + 1] = layout.gutter(row); break end
			end
		end
		return result
	end)()]])
	eq(gutters, { "  52       52   ", "» 53       53 󰄱 ", "»╱╱╱╱      58 󰄱 " })
	eq(
		child.lua_get(
			[[(function(...)
		local win = ...
		return vim.api.nvim_eval_statusline(vim.wo[win].statuscolumn, {
			winid = win, use_statuscol_lnum = 53,
		}).str
	end)(...)]],
			{ view.right_win }
		),
		"» 53       53 󰄱 "
	)
end

T[opens_scenario]["installs paired context folds"] = function()
	edit(manifest.controller)
	open_diff()
	local folds = child.lua_get([[(function()
		local view = require("gleb.diff.view").current()
		local result = {}
		for _, win in ipairs({ view.left_win, view.right_win }) do
			result[#result + 1] = vim.api.nvim_win_call(win, function()
				return { vim.fn.foldclosed(1), vim.fn.foldclosedend(1), vim.fn.foldclosed(70), vim.fn.foldclosedend(70) }
			end)
		end
		return result
	end)()]])
	eq(folds, { { 1, 48, 70, 151 }, { 1, 48, 70, 151 } })
end

T["diff: Diff view highlights changed words"] = function()
	edit(manifest.controller)
	open_diff()
	local marks = child.lua_get([[(function()
		local view = require("gleb.diff.view").current()
		local function words(buf, line)
			local result = {}
			for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, view.ns, { line - 1, 0 }, { line - 1, -1 }, { details = true })) do
				if mark[4].hl_group == "DiffViewWord" then
					result[#result + 1] = { mark[3], mark[4].end_col }
				end
			end
			return result
		end
		return { words(view.right_buf, 53), words(view.left_buf, 53), words(view.right_buf, 58) }
	end)()]])
	eq(marks, { { { 9, 14 }, { 17, 18 } }, {}, {} })
end

T["diff: Diff view show starts on the first change"] = function()
	child.cmd("edit a.txt | rightbelow vnew")
	local target = child.api.nvim_get_current_win()
	child.cmd("wincmd p")
	local current = child.api.nvim_get_current_win()
	local lines = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l" }
	local right = vim.deepcopy(lines)
	right[10] = "J"

	local view = child.lua_get(
		[[(function(win, left, right)
		return require("gleb.diff.view").show(win, {
			path = "d.txt",
			left = left,
			right = right,
			labels = { left = "HEAD", right = "Working tree" },
		})
	end)(...)]],
		{ target, lines, right }
	)

	eq(child.api.nvim_get_current_win(), current)
	eq(child.api.nvim_win_get_cursor(view.right_win)[1], 10)
	eq(child.api.nvim_win_get_cursor(view.left_win)[1], 10)
end

T["diff: Diff view highlight colours"] = function()
	child.cmd("colorscheme gruvbox-material")
	local colours = child.lua_get([[(function()
		local p = require("gleb.colors.gruvbox-material.palette")
		local blend = require("gleb.colors.gruvbox-material.util").blend
		local function hex(value) return value and string.format("#%06x", value) or nil end
		local function group(name)
			local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
			return { fg = hex(hl.fg), bg = hex(hl.bg) }
		end
		return {
			change = { group("DiffViewChange"), blend(p.foreground.blue, p.background.bg0, 0.72) },
			word = { group("DiffViewWord"), blend(p.foreground.blue, p.background.bg0, 0.5) },
			gutter_add = group("DiffViewGutterAdd"),
			arrow_delete = group("DiffViewArrowDelete"),
			padding = group("DiffViewPadding"),
			fold = group("DiffViewFold"),
			expected_add = blend(p.foreground.green, p.background.bg0, 0.72),
			palette = p,
		}
	end)()]])
	eq(colours.change, { { bg = colours.change[2] }, colours.change[2] })
	eq(colours.word, { { bg = colours.word[2] }, colours.word[2] })
	eq(colours.gutter_add, {
		fg = colours.palette.foreground.grey1,
		bg = colours.expected_add,
	})
	eq(colours.arrow_delete.fg, colours.palette.foreground.red)
	eq(colours.padding.fg, colours.palette.background.bg3)
	eq(colours.fold.fg, colours.palette.background.bg5)
end

return T

local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local root

local function start()
	root = F.copy("diffgo", vim.fn.tempname())
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
end

local T = H.child_set(child, start)

---@param spec table
---@return table
local function show_diff(spec)
	child.cmd("edit host.txt | rightbelow vnew")
	local target = child.api.nvim_get_current_win()
	child.cmd("wincmd p")
	return child.lua_get([[require("gleb.diff.view").show(...)]], { target, spec })
end

---@param buf integer
---@param row integer
---@return table<string, boolean>
local function line_groups(buf, row)
	return child.lua_get(
		[[(function(buf, row)
			local groups = {}
			for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })) do
				if mark[2] == row - 1 then
					local group = mark[4].hl_group
					if group then groups[group] = true end
				end
			end
			return groups
		end)(...)]],
		{ buf, row }
	)
end

---@param win integer
---@param row integer
---@return { text: string, groups: table<string, boolean> }
local function gutter(win, row)
	return child.lua_get(
		[[(function(win, row)
			local evaluated = vim.api.nvim_eval_statusline(vim.wo[win].statuscolumn, {
				winid = win,
				use_statuscol_lnum = row,
				highlights = true,
			})
			local groups = {}
			for _, highlight in ipairs(evaluated.highlights or {}) do groups[highlight.group] = true end
			return { text = evaluated.str, groups = groups }
		end)(...)]],
		{ win, row }
	)
end

T["diff: Diff view draws a committed spec in purple"] = function()
	local view = show_diff({
		path = "c.txt",
		left = { "one", "two" },
		right = { "one", "too", "three" },
		labels = { left = "4ccefde · main", right = "e325463 · HEAD" },
		committed = true,
	})

	local changed = line_groups(view.right_buf, 2)
	local added = line_groups(view.right_buf, 3)
	eq(view.actionable, false)
	eq(changed.DiffViewChange, true)
	eq(changed.DiffViewWord, true)
	eq(added.DiffViewAdd, true)
	for group in pairs(vim.tbl_extend("force", changed, added)) do
		eq(group:find("^DiffViewCommitted"), nil)
	end
	local changed_gutter = gutter(view.right_win, 2)
	local added_gutter = gutter(view.right_win, 3)
	eq(changed_gutter.groups.DiffViewGutterChange, true)
	eq(added_gutter.groups.DiffViewGutterAdd, true)
	for _, rendered in ipairs({ changed_gutter, added_gutter }) do
		eq(rendered.text:find("󰄱", 1, true), nil)
		eq(rendered.text:find("󰄲", 1, true), nil)
		eq(rendered.text:find("󰡖", 1, true), nil)
	end
	eq(child.lua_get("vim.bo[...].modifiable", { view.left_buf }), false)
	eq(child.lua_get("vim.bo[...].modifiable", { view.right_buf }), false)
	local before = child.api.nvim_buf_get_lines(view.right_buf, 0, -1, false)
	child.api.nvim_set_current_win(view.right_win)
	child.type_keys("do")
	eq(child.api.nvim_buf_get_lines(view.right_buf, 0, -1, false), before)
end

T["diff: Diff view committed colours"] = function()
	child.cmd("colorscheme gruvbox-material")
	for _, group in ipairs({
		"DiffViewCommitted",
		"DiffViewCommittedWord",
		"DiffViewGutterCommitted",
		"DiffViewArrowCommitted",
	}) do
		eq(child.lua_get([[vim.api.nvim_get_hl(0, { name = ..., link = false })]], { group }), {})
	end
	local colours = child.lua_get([[(function()
		local p = require("gleb.colors.gruvbox-material.palette")
		local blend = require("gleb.colors.gruvbox-material.util").blend
		return {
			actual = vim.api.nvim_get_hl(0, { name = "DiffViewChange", link = false }).bg,
			expected = tonumber(blend(p.foreground.blue, p.background.bg0, 0.72):sub(2), 16),
		}
	end)()]])
	eq(colours.actual, colours.expected)
end

T["diff: Diff view without committed keeps its kind colours"] = function()
	local view = show_diff({
		path = "c.txt",
		left = { "one", "two" },
		right = { "one", "too", "three" },
		labels = { left = "HEAD", right = "Working tree" },
	})

	eq(line_groups(view.right_buf, 2).DiffViewChange, true)
	eq(line_groups(view.right_buf, 3).DiffViewAdd, true)
	local changed_gutter = gutter(view.right_win, 2)
	eq(changed_gutter.groups.DiffViewGutterChange, true)
	assert(changed_gutter.text:find("󰄱", 1, true), "include checkbox was not drawn")
end

T["diff: Diff view committed spec keeps a given buffer editable"] = function()
	local path = root .. "/c.txt"
	local view = child.lua_get(
		[[(function(path)
			local buf = vim.fn.bufadd(path)
			vim.fn.bufload(buf)
			vim.bo[buf].modifiable = true
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "too", "three" })
			vim.cmd("edit host.txt | rightbelow vnew")
			local target = vim.api.nvim_get_current_win()
			vim.cmd("wincmd p")
			return require("gleb.diff.view").show(target, {
				path = path,
				left = { "one", "two" },
				right = { "one", "too", "three" },
				right_buf = buf,
				labels = { left = "4ccefde · main", right = "Your version" },
				committed = true,
			})
		end)(...)]],
		{ path }
	)

	child.lua([[vim.api.nvim_win_call(..., function() vim.cmd("3delete") end)]], { view.right_win })
	assert(
		child.wait(
			string.format(
				[[(function()
					local fragments = require("gleb.diff.view").state.by_win[%d].fragments
					local fragment = fragments[1]
					return #fragments == 1 and fragment.start1 == 1 and fragment.end1 == 2
						and fragment.start2 == 1 and fragment.end2 == 2
				end)()]],
				view.right_win
			),
			1000 * H.load_factor()
		),
		"view did not re-diff the edited buffer"
	)
	eq(child.api.nvim_win_get_buf(view.right_win), view.right_buf)
	eq(child.lua_get("vim.bo[...].modifiable", { view.right_buf }), true)
	eq(child.api.nvim_buf_get_lines(view.right_buf, 0, -1, false), { "one", "too" })
	eq(gutter(view.right_win, 2).text:find("󰄱", 1, true), nil)
end

T["diff: Diff view committed read-only side has syntax"] = function()
	local view = show_diff({
		path = "c.go",
		filetype = "go",
		left = { "package c" },
		right = { "package c", "", "var x = 1" },
		labels = { left = "parent", right = "commit" },
		committed = true,
	})

	local syntax = child.lua_get(
		[[(function(buf)
			local highlighter = vim.treesitter.highlighter.active[buf]
			return { active = highlighter ~= nil, language = highlighter and highlighter.tree:lang() or nil }
		end)(...)]],
		{ view.right_buf }
	)
	eq(child.lua_get("vim.bo[...].modifiable", { view.right_buf }), false)
	eq(syntax, { active = true, language = "go" })
end

return T

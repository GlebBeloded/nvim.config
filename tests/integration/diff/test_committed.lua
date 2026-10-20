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

---@param relpath string
---@param committed? boolean
local function open_diff(relpath, committed)
	local left = vim.split(H.git(root, { "show", "HEAD:" .. relpath }), "\n", { plain = true })
	table.remove(left)
	local right = vim.fn.readfile(root .. "/" .. relpath)
	child.lua(
		[[require("gleb.diff.view").open({
			path = ...,
			relpath = select(2, ...),
			root = select(3, ...),
			left = select(4, ...),
			right = select(5, ...),
			labels = { left = "base", right = "head" },
			actionable = false,
			committed = select(6, ...),
		})]],
		{ root .. "/" .. relpath, relpath, root, left, right, committed }
	)
end

local function drawn_groups()
	return child.lua_get([[(function()
		local view = require("gleb.diff.view").current()
		local groups = {}
		for _, buf in ipairs({ view.left_buf, view.right_buf }) do
			for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, view.ns, 0, -1, { details = true })) do
				local details = mark[4]
				local group = details.hl_group
				if group then groups[group] = true end
				for _, line in ipairs(details.virt_lines or {}) do
					for _, chunk in ipairs(line) do
						local chunk_group = chunk[2]
						groups[chunk_group] = true
					end
				end
			end
		end
		return groups
	end)()]])
end

T["diff: Diff view draws a committed spec in purple"] = function()
	open_diff(manifest.controller, true)

	local committed = child.lua_get([[require("gleb.diff.view").current().committed]])
	local groups = drawn_groups()
	eq(committed, true)
	eq(groups.DiffViewCommitted, true)
	eq(groups.DiffViewCommittedWord, true)
	eq(groups.DiffViewAdd, nil)
	eq(groups.DiffViewChange, nil)
	eq(groups.DiffViewDelete, nil)

	local gutters = child.lua_get([[(function()
		local view = require("gleb.diff.view").current()
		local result = { groups = {}, text = {} }
		for _, item in ipairs({ { win = view.left_win, side = "left" }, { win = view.right_win, side = "right" } }) do
			for _, row in ipairs(view.layout.rows) do
				local line = row[item.side]
				if row.kind and line then
					local evaluated = vim.api.nvim_eval_statusline(vim.wo[item.win].statuscolumn, {
						winid = item.win,
						use_statuscol_lnum = line,
						highlights = true,
					})
				result.text[#result.text + 1] = evaluated.str
				for _, highlight in ipairs(evaluated.highlights or {}) do
					result.groups[highlight.group] = true
				end
				end
			end
		end
		return result
	end)()]])
	eq(gutters.groups.DiffViewArrowCommitted, true)
	eq(gutters.groups.DiffViewGutterCommitted, true)
	eq(gutters.groups.DiffViewAdd, nil)
	eq(gutters.groups.DiffViewChange, nil)
	eq(gutters.groups.DiffViewDelete, nil)
	for _, text in ipairs(gutters.text) do
		eq(text:find("󰄱", 1, true), nil)
		eq(text:find("󰄲", 1, true), nil)
		eq(text:find("󰡖", 1, true), nil)
	end

	child.lua([[require("gleb.diff.view").close(require("gleb.diff.view").current())]])
	open_diff(manifest.ids, true)
	eq(drawn_groups().DiffViewMoved, true)
end

T["diff: Diff view committed colours"] = function()
	child.cmd("colorscheme gruvbox-material")
	local colours = child.lua_get([[(function()
		local p = require("gleb.colors.gruvbox-material.palette")
		local blend = require("gleb.colors.gruvbox-material.util").blend
		return {
			purple = p.foreground.purple,
			grey = p.foreground.grey1,
			tint = blend(p.foreground.purple, p.background.bg0, 0.74),
			word = blend(p.foreground.purple, p.background.bg0, 0.5),
		}
	end)()]])

	H.expect_hl_colors(child, "DiffViewCommitted", { bg = colours.tint })
	H.expect_hl_colors(child, "DiffViewGutterCommitted", { fg = colours.grey, bg = colours.tint })
	H.expect_hl_colors(child, "DiffViewArrowCommitted", { fg = colours.purple, bg = colours.tint })
	H.expect_hl_colors(child, "DiffViewCommittedWord", { bg = colours.word })
end

T["diff: Diff view without committed keeps its kind colours"] = function()
	open_diff(manifest.controller)

	local groups = drawn_groups()
	eq(groups.DiffViewAdd, true)
	eq(groups.DiffViewChange, true)
	eq(groups.DiffViewDelete, true)
	eq(groups.DiffViewWord, true)
	eq(groups.DiffViewCommitted, nil)
	eq(groups.DiffViewCommittedWord, nil)
end

return T

local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		ChangesModel = require("gleb.git.changes.model")
		ChangesRender = require("gleb.git.changes.render")
		ChangesBuffer = vim.api.nvim_create_buf(false, true)
	]])
end

local T = H.child_set(child, start)

local function draw(porcelain, numstat, width)
	child.lua(
		[[
		local porcelain, numstat, width = ...
		local rows = ChangesModel.rows(porcelain, {}, numstat)
		ChangesRender.draw(ChangesBuffer, rows, width or 35)
	]],
		{ porcelain, numstat, width }
	)
end

local function rendered_names(porcelain)
	draw(porcelain)
	return child.lua_get([[
		(function()
			local result = {}
			local lines = vim.api.nvim_buf_get_lines(ChangesBuffer, 0, -1, false)
			for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(
				ChangesBuffer, ChangesRender.namespace, 0, -1, { details = true }
			)) do
				local details = mark[4]
				if details.hl_group:find("^FileTreeGit") then
					result[lines[mark[2] + 1]:sub(mark[3] + 1, details.end_col)] = details.hl_group
				end
			end
			return result
		end)()
	]])
end

local function rendered_lines(porcelain, numstat, width)
	draw(porcelain, numstat, width)
	return child.lua_get([[vim.api.nvim_buf_get_lines(ChangesBuffer, 0, -1, false)]])
end

local function rendered_stat_groups()
	return child.lua_get([[
		(function()
			local result = {}
			local lines = vim.api.nvim_buf_get_lines(ChangesBuffer, 0, -1, false)
			for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(
				ChangesBuffer, ChangesRender.namespace, 0, -1, { details = true }
			)) do
				local details = mark[4]
				if details.hl_group:find("^ChangesStat") then
					result[details.hl_group] = lines[mark[2] + 1]:sub(mark[3] + 1, details.end_col)
				end
			end
			return result
		end)()
	]])
end

T["git: Changes panel colours names by status"] = MiniTest.new_set()

T["git: Changes panel colours names by status"]["uses each status group on the file name"] = function()
	local porcelain = table.concat({
		"1 .M N... 100644 100644 100644 abcdef1 abcdef2 m.txt",
		"1 A. N... 000000 100644 100644 0000000 abcdef2 n.txt",
		"1 D. N... 100644 000000 000000 abcdef1 0000000 d.txt",
		"2 R. N... 100644 100644 100644 abcdef1 abcdef2 R100 moved.txt",
		"old.txt",
		"? u.txt",
	}, "\0") .. "\0"

	eq(rendered_names(porcelain), {
		["d.txt"] = "FileTreeGitDeleted",
		["m.txt"] = "FileTreeGitModified",
		["moved.txt"] = "FileTreeGitRenamed",
		["n.txt"] = "FileTreeGitAdded",
		["u.txt"] = "FileTreeGitUntracked",
	})
end

T["git: Changes panel treats copies as renamed"] = MiniTest.new_set()

T["git: Changes panel treats copies as renamed"]["renders the destination and preserves the origin"] = function()
	local porcelain = table.concat({
		"2 C. N... 100644 100644 100644 abcdef1 abcdef2 C100 copy.txt",
		"old.txt",
	}, "\0") .. "\0"

	eq(rendered_names(porcelain), { ["copy.txt"] = "FileTreeGitRenamed" })
	eq(child.lua_get([[ChangesModel.rows(..., {})[2].orig]], { porcelain }), "old.txt")
	eq(
		child.lua_get([[vim.iter(vim.api.nvim_buf_get_lines(ChangesBuffer, 0, -1, false)):any(function(line)
		return line:find("old.txt", 1, true) ~= nil
	end)]]),
		false
	)
end

T["git: Changes panel cuts a long name before the stats"] = MiniTest.new_set()

T["git: Changes panel cuts a long name before the stats"]["right aligns populated stats and leaves untracked rows plain"] = function()
	local porcelain = table.concat({
		"1 .M N... 100644 100644 100644 abcdef1 abcdef2 invoice.go",
		"? notes.md",
	}, "\0") .. "\0"
	local lines = rendered_lines(porcelain, "12\t3\tinvoice.go\0", 35)

	eq(lines[2], "     󰄱  invoice.go         +12 -3")
	eq(lines[4], "     󰄱  notes.md")
	eq(rendered_stat_groups(), { ChangesStatAdded = "+12", ChangesStatRemoved = "-3" })
end

T["git: Changes panel cuts a long name before the stats"]["uses an ellipsis and keeps stats in the approved columns"] = function()
	local porcelain = table.concat({
		"1 .M N... 100644 100644 100644 abcdef1 abcdef2 internal/billing/invoice_test.go",
		"1 .M N... 100644 100644 100644 abcdef1 abcdef2 internal/other/helper.go",
	}, "\0") .. "\0"
	local numstat = table.concat({
		"20\t1\tinternal/billing/invoice_test.go",
		"1\t0\tinternal/other/helper.go",
	}, "\0") .. "\0"
	local lines = rendered_lines(porcelain, numstat, 35)

	eq(lines[4], "         󰄱  invoice_test.… +20 -1")
end

return T

local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local root

local function start()
	root = F.copy("treeproj", vim.fn.tempname() .. "/billing")
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
	child.lua(
		[[
		local fs = require("gleb.file_tree.fs")
		local model = require("gleb.file_tree.model")
		local render = require("gleb.file_tree.render")
		fs.reset()
		ProjectTreeBuf = vim.api.nvim_create_buf(false, true)
		local rows = model.rows(fs.tree(...), {
			internal = true,
			["internal/billing"] = true,
		}, {})
		render.draw(ProjectTreeBuf, rows)
	]],
		{ root }
	)
end

local T = H.child_set(child, start)

local function lines()
	return child.lua_get([[vim.api.nvim_buf_get_lines(ProjectTreeBuf, 0, -1, false)]])
end

---@param needle string
---@return string[]
local function groups_for(needle)
	return child.lua_get(
		[[(function(needle)
		for row, line in ipairs(vim.api.nvim_buf_get_lines(ProjectTreeBuf, 0, -1, false)) do
			if line:find(needle, 1, true) then
				local groups = {}
				for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(
					ProjectTreeBuf,
					-1,
					{ row - 1, 0 },
					{ row - 1, -1 },
					{ details = true }
				)) do
					groups[#groups + 1] = mark[4].hl_group
				end
				return groups
			end
		end
		return {}
	end)(...)]],
		{ needle }
	)
end

T["file-tree: Project tree root row names the project"] = function()
	local expected = "  billing  " .. vim.fn.fnamemodify(root, ":~")
	eq(lines()[1], expected)
	eq(groups_for("billing"), { "FileTreeExpander", "FileTreeFolderIcon", "FileTreeRoot", "FileTreeRootPath" })
end

T["file-tree: Project tree rows have icons and no guides"] = function()
	local rendered = lines()
	local invoice
	for _, line in ipairs(rendered) do
		if line:find("invoice.go", 1, true) then
			invoice = line
		end
		for _, guide in ipairs({ "│", "├", "└" }) do
			assert(not line:find(guide, 1, true), "project tree drew an indent guide")
		end
	end
	eq(invoice, "          invoice.go")
	eq(groups_for("invoice.go"), { "DevIconGo", "FileTreeFileName" })
end

T["file-tree: Project tree highlight colours come from the palette"] = function()
	child.api.nvim_set_hl(0, "FileTreeRoot", { fg = "#000000" })
	child.api.nvim_exec_autocmds("ColorScheme", {})

	H.expect_hl_colors(child, "FileTreeGitModified", { fg = "#7daea3" })
	H.expect_hl_colors(child, "FileTreeGitAdded", { fg = "#a9b665" })
	H.expect_hl_colors(child, "FileTreeGitUntracked", { fg = "#e78a4e" })
	H.expect_hl_colors(child, "FileTreeGitRenamed", { fg = "#89b482" })
	H.expect_hl_colors(child, "FileTreeGitConflict", { fg = "#ea6962" })
	H.expect_hl_colors(child, "FileTreeRoot", { fg = "#ddc7a1", bold = true })
	H.expect_hl_colors(child, "FileTreeRootPath", { fg = "#928374" })
	H.expect_hl_colors(child, "FileTreeCursorLine", { bg = "#32302f" })
end

return T

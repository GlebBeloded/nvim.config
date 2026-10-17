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

---@param relative string
local function edit(relative)
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, relative)))
end

local function run_toggle()
	child.lua([[
		local catalog = require("gleb.actions").state.applicator.catalog
		local action = assert(catalog:get("file_tree.toggle"), "file_tree.toggle is not registered")
		action.run(require("gleb.actions.context").capture())
	]])
end

---@return integer[]
local function project_tree_windows()
	return child.lua_get([[(function()
		return vim.iter(vim.api.nvim_tabpage_list_wins(0)):filter(function(win)
			return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "gleb-file-tree"
		end):totable()
	end)()]])
end

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

T["file-tree: Project tree opens on the left at width 35"] = function()
	edit("README.md")
	run_toggle()

	local win = child.api.nvim_get_current_win()
	eq(child.bo.filetype, "gleb-file-tree")
	eq(child.lua_get([[vim.fn.win_getid(1)]]), win)
	eq(child.api.nvim_win_get_width(win), 35)
	eq(child.wo.winfixwidth, true)
	eq(#child.api.nvim_tabpage_list_wins(0), 2)
end

T["file-tree: Project tree toggle closes a focused tree"] = function()
	edit("README.md")
	run_toggle()
	run_toggle()

	eq(project_tree_windows(), {})
end

T["file-tree: Project tree toggle focuses an open tree"] = function()
	edit("README.md")
	run_toggle()
	local tree_win = child.api.nvim_get_current_win()
	child.cmd("wincmd l")
	run_toggle()

	eq(child.api.nvim_get_current_win(), tree_win)
	eq(#child.api.nvim_tabpage_list_wins(0), 2)
end

T["file-tree: Project tree toggle reveals the current file"] = function()
	edit("internal/money/money.go")
	run_toggle()

	local cursor = child.api.nvim_win_get_cursor(0)
	local line = child.api.nvim_buf_get_lines(0, cursor[1] - 1, cursor[1], false)[1]
	eq(line:match("[^ ]+$"), "money.go")
end

T["file-tree: Project tree closes with the last window"] = function()
	edit("README.md")
	run_toggle()
	child.cmd("wincmd l")

	local job = child.job.id
	child.api_notify.nvim_command("q")
	eq(vim.fn.jobwait({ job }, 5000)[1], 0)
end

return T

-- Reference screenshots of the bufferline tabline row (tests/screenshots/).
-- Update with `make screenshots` (UPDATE_SCREENSHOTS=1) after an intended change.
local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local TAB = "[No Name]"
local TAB_INSET = 8 -- indicator, padding, icon and space before the label in the fixed-width (tab_size) tab
local TREE_COLUMNS = 36 -- sidebar width 35 plus the window separator

local CHANGES_MASK = {
	"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabcbbbbbbbbbbbbbddddddddddddddddddddddddddddddddddddddddddddddddd",
	"aeafagggggggahhhhhhhaaaaaaaaaaaaaaaijjjjjkkkkkkk....................................................",
	"aaaealammmmmmmmmmmmmmmmahaaaaaaaaaainnnnn...........................................................",
	"oooooeofocoppppppppppoooooooqqqorroinnnnnkkkkkk.....................................................",
}

local CHANGES_LEGEND = {
	a = "FileTreeNormal",
	b = "BufferLineBufferSelected",
	c = "DevIconGo",
	d = "BufferLineFill",
	e = "FileTreeExpander",
	f = "ChangesCheckbox",
	g = "ChangesRoot",
	h = "ChangesCount",
	i = "WinSeparator",
	j = "CursorLineNr",
	k = "@keyword",
	l = "FileTreeFolderIcon",
	m = "FileTreeFolderName",
	n = "LineNr",
	o = "FileTreeCursorLine",
	p = "FileTreeGitModified",
	q = "ChangesStatAdded",
	r = "ChangesStatRemoved",
}

local PANEL_GROUPS = {
	"ChangesCheckbox",
	"ChangesCount",
	"ChangesRoot",
	"ChangesStatAdded",
	"ChangesStatRemoved",
	"DevIconGo",
	"DevIconMd",
	"DevIconTypeScript",
	"FileTreeExpander",
	"FileTreeFolderIcon",
	"FileTreeFolderName",
	"FileTreeGitAdded",
	"FileTreeGitModified",
	"FileTreeGitUntracked",
}

--- An empty buffer in a fresh temp dir on a 100x12 screen.
local function start()
	child.start_config()
	child.wait_very_lazy()
	child.o.lines, child.o.columns = 12, 100
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	child.cmd("cd " .. dir .. " | enew")
end

local function open_project_tree()
	child.lua([[
		local catalog = require("gleb.actions").state.applicator.catalog
		local action = assert(catalog:get("file_tree.toggle"), "file_tree.toggle is not registered")
		action.run(require("gleb.actions.context").capture())
	]])
	assert(child.wait([[vim.bo.filetype == "gleb-file-tree"]], 3000), "project tree window did not open")
end

local function run_action(id)
	child.lua(
		[[
		local action = assert(require("gleb.actions").state.applicator.catalog:get(...))
		action.run(require("gleb.actions.context").capture())
	]],
		{ id }
	)
end

local function wait_for_changes()
	assert(
		child.wait(
			[[(function()
			local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			return view and #view.rows > 0
		end)()]],
			5000
		),
		"changes panel did not open"
	)
end

local function open_changes()
	run_action("changes.toggle")
	wait_for_changes()
end

---@return string[] cells of row 1 of the screen, one per display column
local function tabline_cells()
	return H.screen_rows(child, 1).text[1]
end

--- Display column where `text` starts in `cells` (cells may hold multibyte glyphs).
---@param cells string[]
---@param text string
---@return integer?
local function cell_column(cells, text)
	for col = 1, #cells - #text + 1 do
		if table.concat(cells, "", col, col + #text - 1) == text then
			return col
		end
	end
end

--- Display column where the `[No Name]` tab (not its centred label) starts in the tabline row.
---@return integer?
local function tab_column()
	local label = cell_column(tabline_cells(), TAB)
	return label and label - TAB_INSET
end

--- Wait until bufferline (redrawn asynchronously) draws the tab at `col`.
---@param col integer
local function wait_for_tab(col)
	local ok = vim.wait(2000, function()
		return tab_column() == col
	end, 20)
	assert(ok, ("%s at column %s, expected %d"):format(TAB, tostring(tab_column()), col))
end

local function wait_for_sidebar_offset()
	local ok = vim.wait(2000, function()
		return table.concat(tabline_cells(), "", 1, TREE_COLUMNS) == (" "):rep(TREE_COLUMNS)
	end, 20)
	assert(ok, "bufferline did not leave the sidebar columns blank")
end

---@return string[]
local function approved_changes_text()
	local lines =
		vim.fn.readfile(vim.fs.joinpath(H.root, "tests/screen/bufferline/proposed_changes_panel_tabline.ansi"))
	return vim.tbl_map(function(line)
		return line:gsub("\27%[[0-9;]*m", "")
	end, lines)
end

---@return string[]
local function changes_text()
	return vim.tbl_map(table.concat, H.screen_rows(child, 1, 4).text)
end

---@return string[]
local function panel_extmark_groups()
	return child.lua([[
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local groups = {}
		for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(view.buf, -1, 0, -1, { details = true })) do
			if mark[4].hl_group then groups[mark[4].hl_group] = true end
		end
		local sorted = vim.tbl_keys(groups)
		table.sort(sorted)
		return sorted
	]])
end

local T = H.child_set(child, start)

T["bufferline: tabs start after the open project tree"] = function()
	open_project_tree()
	vim.wait(2000, function()
		return tab_column() == TREE_COLUMNS + 1
	end, 20)
	eq(table.concat(tabline_cells(), "", 1, TREE_COLUMNS), (" "):rep(TREE_COLUMNS))
	eq(tab_column(), TREE_COLUMNS + 1)
end

T["bufferline: tabs start after the open changes panel"] = function()
	local repo = H.git_repo({ ["tracked.txt"] = "base\n" })
	H.write_files(repo, { ["tracked.txt"] = "changed\n" })
	child.cmd("cd " .. vim.fn.fnameescape(repo) .. " | enew")
	open_changes()
	wait_for_tab(TREE_COLUMNS + 1)

	eq(table.concat(tabline_cells(), "", 1, TREE_COLUMNS), (" "):rep(TREE_COLUMNS))
	eq(tab_column(), TREE_COLUMNS + 1)
end

T["bufferline: tabline over the changes panel matches the approved render"] = function()
	local root = F.copy("billing", vim.fn.tempname() .. "/billing")
	child.o.lines = 30
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
	child.wo.relativenumber = false
	child.wo.numberwidth = 5
	child.wo.signcolumn = "no"
	open_changes()
	assert(
		child.wait([[#require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()].rows == 10]], 5000)
	)
	wait_for_sidebar_offset()
	child.cmd("redrawtabline | redraw!")

	eq(changes_text(), approved_changes_text())
	H.expect_screen_colors(child, 1, CHANGES_MASK, CHANGES_LEGEND)
	eq(panel_extmark_groups(), PANEL_GROUPS)
end

T["bufferline: tabline with tree open matches reference screenshot"] = function()
	open_project_tree()
	wait_for_tab(TREE_COLUMNS + 1)
	H.expect_screenshot(H.screen_rows(child, 1, 1))
end

T["bufferline: tabline without tree matches reference screenshot"] = function()
	open_project_tree()
	run_action("file_tree.toggle")
	wait_for_tab(1)
	H.expect_screenshot(H.screen_rows(child, 1, 1))
end

return T

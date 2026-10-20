-- Approved Changes panel renders: the panel columns match design.md's masks and the
-- byte-identical render copies here; the editor pane, drawn by Tree-sitter, indent
-- guides and the diff view, matches the same content in a regular window.
local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

-- The 35-column panel and its window separator.
local PANEL_COLUMNS = 36

local PANEL_LEGEND = {
	b = "DevIconGo",
	d = "ChangesTabLocal",
	e = "WinSeparator",
	g = "ChangesCount",
	h = "ChangesRoot",
	l = "FileTreeFolderIcon",
	m = "FileTreeCursorLine",
	o = "ChangesStatAdded",
	p = "ChangesStatRemoved",
	y = "DevIconMd",
	z = "FileTreeGitUntracked",
	T = "DevIconTypeScript",
}

local DIFF_LEGEND = vim.tbl_extend("force", PANEL_LEGEND, {
	f = "DiffViewHeader",
	i = "DiffViewFold",
	j = "DiffViewLineNr",
	k = "DiffViewPadding",
	n = "@string",
	q = "DiffViewChange",
	r = "@comment",
	s = "DiffViewArrowChange",
	t = "DiffViewGutterChange",
	u = "@keyword",
	v = "@type.definition",
	w = "DiffViewWord",
	x = "@function.call",
	A = "@function",
	B = "DiffViewArrowAdd",
	C = "DiffViewAdd",
	D = "DiffViewGutterAdd",
	E = "@property",
})

local DIFF_MASK = {
	".ddddddddd.........................efffffffffffffffffffffffff.ffffffffffffffffffffffffffffffffffffff",
	".g.g.hhhhhhh.ggggggg...............eiijjjjjjjjjjjjjjjjjjjiiiikiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii",
	"...g.l..................g..........e.........................k.jjjj.....jjjj..i.....................",
	"mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmme...nnnnnnnnnnnnnnnnnnnnnnk.jjjj.....jjjj..iinnnnnnnnnnnnnnnnnnnn",
	".........g.b.lllllllllllllg.ooo.pp.e.........................k.jjjj.....jjjj........................",
	".....g.g.b.oooooo...........ooo.pp.e.........................k.jjjj.....jjjj........................",
	".........g.b.ooooooooooo....ooo.pp.eqrrrrrrrrrrrrrrrrrrrrrrrrksttttqqqqqttttttrrrrrrrrrrrrrrrrrrrrrr",
	"...g.l.........g...................e.uuuu.vvvvvvv.uuuuuu.....k.jjjj.....jjjj..uuuu.vvvvvvv.uuuuuu...",
	".......g.T.llllllll..........oo.pp.eqqqqqqqqqqqqqqqqqqqqqqqqqksttttqqqqqttttttqqqqqqqqqqqqqqwrrrrrrr",
	".g.g.hhhhhhhhhhhhhhhhh.gggggg......e...vvvvv...xxx...........k.jjjj.....jjjj..iivvvvv...xxx.........",
	".....g.y.zzzzzzzz..................e...vvv...xxxx............k.jjjj.....jjjj..iivvv...xxxx..........",
	"...................................e.........................k.jjjj.....jjjj........................",
	"...................................e.........................k.jjjj.....jjjj........................",
	"...................................e.rrrrrrrrrrrrrrrrrrrrrrrrk.jjjj.....jjjj..rrrrrrrrrrrrrrrrrrrrrr",
	"...................................e.uuuu....xxxxxxx..AAAAA..k.jjjj.....jjjj..uuuu....xxxxxxx..AAAAA",
	"...................................eqqqqqqqqqwwwwqqqqqqqqqqqqksttttqqqqqttttttqqwwwwqqqqqqwwwqqqqqqq",
	"...................................e...uuu.vn.vvvvv.uu.uuuuu.k.jjjj.....jjjj..iiuuu.vn.vvvvv.uu.uuuu",
	"...................................e.....vvvvv.uu.vvvvv......k.jjjj.....jjjj..iiiivvvvv.uu.vvvvv....",
	"...................................e.........................k.jjjj.....jjjj..ii....................",
	"...................................ekkkkkkkkkkkkkkkkkkkkkkkkkkBkkkkCCCCCDDDDDDCCCCCCCCCCCCCCCCCCCCCC",
	"...................................ekkkkkkkkkkkkkkkkkkkkkkkkkk.kkkkCCCCCDDDDDDCCCCCCCCCCCCCCCCCCCCCC",
	"...................................ekkkkkkkkkkkkkkkkkkkkkkkkkk.kkkkCCCCCDDDDDDCCCCCCCCCCCCCCCCCCCCCC",
	"...................................e...uuuuuu.vnEEEnAAAAA.vvvk.jjjj.....jjjj..iiuuuuuu.vnEEEnAAAAA.v",
	"...................................e.........................k.jjjj.....jjjj........................",
	"...................................e.........................k.jjjj.....jjjj........................",
	"...................................e.rrrrrrrrrrrrrrrrrrrrrrrrk.jjjj.....jjjj..rrrrrrrrrrrrrrrrrrrrrr",
	"...................................e.uuuu....xxxxxxx..AAA...xk.jjjj.....jjjj..uuuu....xxxxxxx..AAA..",
	"...................................e...uuuuuu.vvvnAAAAAAA.nnnk.jjjj.....jjjj..iiuuuuuu.vvvnAAAAAAA.n",
}

local PANEL_MASK = vim.tbl_map(function(line)
	return line:sub(1, PANEL_COLUMNS) .. ("."):rep(100 - PANEL_COLUMNS)
end, DIFF_MASK)

local function run_action(id)
	child.lua(
		[[
		local action = assert(require("gleb.actions").state.applicator.catalog:get(...))
		action.run(require("gleb.actions.context").capture())
	]],
		{ id }
	)
end

local function start()
	local home = vim.fn.tempname()
	local root = F.copy("billing", vim.fs.joinpath(home, "work", "billing"))
	child.start_config()
	child.o.lines, child.o.columns = 30, 100
	child.wait_very_lazy()
	child.lua(
		[[
		vim.env.HOME = ...
		vim.lsp.enable("gopls", false)
		require("null-ls").disable({})
		vim.diagnostic.enable(false)
	]],
		{ home }
	)
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
end

local function wait_for_panel()
	assert(
		child.wait(
			[[(function()
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view ~= nil and #view.rows == 10
	end)()]],
			5000
		),
		"Changes panel did not load"
	)
	child.cmd("redraw")
end

--- Gitsigns marks the edited file asynchronously; both screens of a case need its signs.
local function wait_for_signs()
	assert(
		child.wait("next(require('gitsigns').get_hunks(vim.api.nvim_get_current_buf()) or {}) ~= nil", 5000),
		"Gitsigns did not mark the edited file"
	)
end

--- Tree-sitter highlights asynchronously: capture a screen once every highlighted
--- buffer of the tab is parsed, so both screens of a case carry their syntax colours.
---@return test.ScreenCell[][] cells of screen rows 2-29
local function parsed_screen_cells()
	assert(
		child.wait(
			[[(function()
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			local highlighter = vim.treesitter.highlighter.active[vim.api.nvim_win_get_buf(win)]
			if highlighter and not highlighter.tree:is_valid(true) then
				return false
			end
		end
		return true
	end)()]],
			5000
		),
		"Tree-sitter did not parse the shown buffers"
	)
	return H.screen_cells(child, 2, 28)
end

--- The approved Local-only panel text of rows 2-29.
---@return string[]
local function approved_panel_text()
	local lines = {
		"  Local 6                          ┃",
		"  󰡖 Changes 5 files               ┃",
		"     internal/billing 4          ┃",
		"      󰄱  invoice.go       +12 -3 ┃",
		"         󰄱  invoice_test.… +20 -1 ┃",
		"      󰄲  tax.go           +41 -0 ┃",
		"         󰄲  tax_test.go    +33 -0 ┃",
		"     web/src 1                   ┃",
		"       󰄱  price.ts          +4 -4 ┃",
		"  󰄱 Unversioned Files 1 file      ┃",
		"     󰄱  notes.md                  ┃",
	}
	vim.list_extend(lines, vim.fn["repeat"]({ (" "):rep(35) .. "┃" }, 17))
	return lines
end

---@return string[] drawn panel text of rows 2-29
local function panel_text()
	return vim.tbl_map(function(cells)
		return table.concat(vim.list_slice(cells, 1, PANEL_COLUMNS))
	end, vim.list_slice(child.get_screenshot().text, 2, 29))
end

---@param cells test.ScreenCell[]
---@return string
local function row_text(cells)
	return table.concat(vim.tbl_map(function(cell)
		return cell.text
	end, cells))
end

-- Groups the panel's own extmarks draw on the billing fixture (the masks cover their colours).
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

---@return string[] sorted highlight groups of the panel buffer's extmarks
local function panel_extmark_groups()
	return child.lua([[
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local groups = {}
		for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(view.buf, -1, 0, -1, { details = true })) do
			if mark[4].hl_group then
				groups[mark[4].hl_group] = true
			end
		end
		local sorted = vim.tbl_keys(groups)
		table.sort(sorted)
		return sorted
	]])
end

---@param shown test.ScreenCell[][]
---@param regular test.ScreenCell[][]
---@return string? first editor-pane cell that differs between the two screens
local function editor_difference(shown, regular)
	for row, line in ipairs(shown) do
		for col = PANEL_COLUMNS + 1, #line do
			local cell, expected = line[col], regular[row][col]
			if cell.text ~= expected.text or not vim.deep_equal(cell.attrs, expected.attrs) then
				return ("row %d, column %d: drawn %q %s, regular window %q %s\ndrawn:   %s\nregular: %s"):format(
					row + 1,
					col,
					cell.text,
					vim.inspect(cell.attrs, { newline = " ", indent = "" }),
					expected.text,
					vim.inspect(expected.attrs, { newline = " ", indent = "" }),
					row_text(line),
					row_text(regular[row])
				)
			end
		end
	end
end

--- Put a plain 35-column window where the panel goes, so the editor window has the
--- panel layout's width without the panel. Like the panel, it keeps its width when
--- the diff view splits the editor window.
local function open_regular_left_window()
	child.cmd("topleft 35vnew")
	child.wo.winfixwidth = true
end

---@return test.ScreenCell[][] the editor window before any panel opened, at the panel layout's width
local function regular_editor_cells()
	open_regular_left_window()
	local cells = parsed_screen_cells()
	child.cmd("bwipeout")
	return cells
end

--- Close the focused panel and put a plain window in its place.
local function replace_panel_with_regular_window()
	run_action("changes.toggle")
	open_regular_left_window()
end

---@return gleb.diff.view.Spec spec the panel's diff view shows (without its callbacks)
local function panel_diff_spec()
	return child.lua([[
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()].diff_view
		return {
			path = view.path,
			relpath = view.relpath,
			root = view.root,
			left = view.left,
			right = view.right,
			right_buf = view.right_buf,
			labels = view.labels,
			filetype = view.filetype,
			actionable = view.actionable,
			head_final_newline = view.head_final_newline,
		}
	]])
end

---@param spec gleb.diff.view.Spec
local function show_diff_in_editor(spec)
	child.lua(
		[[
		local editor = vim.fn.win_getid(vim.fn.winnr("l"))
		assert(require("gleb.diff.view").show(editor, ...), "diff view did not open")
	]],
		{ spec }
	)
end

local T = H.child_set(child, start)

T["git: Changes panel matches the approved render"] = function()
	wait_for_signs()
	local regular = regular_editor_cells()
	run_action("changes.toggle")
	wait_for_panel()
	H.expect_screen_colors(child, 2, PANEL_MASK, PANEL_LEGEND, { columns = PANEL_COLUMNS })
	eq(panel_text(), approved_panel_text())
	eq(panel_extmark_groups(), PANEL_GROUPS)
	eq(editor_difference(parsed_screen_cells(), regular), nil)
end

T["git: Changes panel with the diff view matches the approved render"] = function()
	wait_for_signs()
	run_action("changes.review")
	wait_for_panel()
	assert(
		child.wait(
			[[(function()
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view ~= nil and view.diff_view ~= nil
	end)()]],
			5000
		),
		"Changes diff view did not load"
	)
	child.cmd("redraw")
	H.expect_screen_colors(child, 2, DIFF_MASK, DIFF_LEGEND, { columns = PANEL_COLUMNS })
	eq(panel_text(), approved_panel_text())
	eq(panel_extmark_groups(), PANEL_GROUPS)
	local shown = parsed_screen_cells()
	local spec = panel_diff_spec()

	replace_panel_with_regular_window()
	show_diff_in_editor(spec)
	eq(editor_difference(shown, parsed_screen_cells()), nil)
end

return T

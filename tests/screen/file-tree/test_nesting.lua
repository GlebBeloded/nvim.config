-- Approved nested project-tree render through the real tree, fixture and mappings.
local F = require("tests.fixtures")
local H = require("tests.helpers")
local MiniTest = require("mini.test")

local child = H.new_child()
local eq = MiniTest.expect.equality
local root

local LEGEND = {
	a = "BufferLineFill",
	b = "BufferLineBufferSelected",
	c = "DevIconGo",
	d = "FileTreeExpander",
	e = "FileTreeFolderIcon",
	f = "FileTreeRoot",
	g = "FileTreeRootPath",
	h = "WinSeparator",
	i = "LineNr",
	j = "@keyword",
	k = "FileTreeFolderName",
	l = "FileTreeFileName",
	m = "@string",
	n = "FileTreeGitModified",
	o = "FileTreeCursorLine",
	p = "@comment",
	q = "FileTreeGitAdded",
	r = "@type",
	s = "DevIconTsx",
	t = "DevIconTypeScript",
	u = "DevIconPackageJson",
	v = "DevIconGitIgnore",
	w = "CursorLineNr",
	x = "@function.call",
	y = "DevIconGoMod",
	z = "@number",
	A = "DevIconMakefile",
	B = "DevIconMd",
	C = "FileTreeGitUntracked",
	D = "DevIconReadme",
	E = "lualine_a_normal",
	F = "lualine_c_normal",
	G = "lualine_b_normal",
	["."] = "Normal",
}

local MASK = {
	"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabcabbbbbbbbbbbbaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
	"dd.e.fffffff..gggggggggggggg.......hiiiiijjjjjjj....................................................",
	"...d.e.kkkkkkkkkkkkkkkkk...........hiiiii...........................................................",
	"...d.e.kkkkkkkkkk..................hiiiiijjjjjj.....................................................",
	".......c.lllllll...................hiiiii....mmmmm..................................................",
	"...d.e.nnnnnnnn....................hiiiii...........................................................",
	".....d.e.nnnnnnn...................hiiiii....mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm...................",
	".......d.c.lllllllllll.............hiiiii...........................................................",
	"ooooooodoconnnnnnnnnnoooooooooooooohiiiii...........................................................",
	"...........c.nnnnnnnnnnnnnnn.......hiiiiipp.ppppppp.pp.p.pppp.pp.pppp.ppppppp.pp.pppppp.............",
	".......d.c.qqqqqq..................hiiiiijjjj.rrrrrrr.jjjjjj........................................",
	".....d.e.kkkkk.....................hiiiii....rr....rrrrrr...........................................",
	"...d.e.nnn.........................hiiiii....rrrrr...rrr............................................",
	".....d.e.nnn.......................hiiiii....rrr...rrrr.............................................",
	".........s.llllllll................hiiiii...........................................................",
	".......d.t.nnnnnnnn................hiiiii...........................................................",
	".....d.u.llllllllllll..............hiiiiipp.ppppp.pppp.ppp.ppppp.ppp.ppppppp.ppp.ppp.ppppp..........",
	".....v.llllllllll..................hwwwwwjjjj....rrrrrrr..xxxxx...rrr...............................",
	"...d.y.llllll......................hiiiii.............z.............................................",
	".....A.llllllll....................hiiiii....jjj.............jjjjj...rrrrr..........................",
	".....B.CCCCCCCC....................hiiiii...........................................................",
	".....D.lllllllll...................hiiiii...........................................................",
	"...................................hiiiii....jjjjjj...rrr.xxxxx.....................................",
	"...................................hiiiii...........................................................",
	"...................................hiiiii...........................................................",
	"...................................hiiiiipp.ppp.ppppppp.ppp.ppppp.pp.pppppppp.......................",
	"...................................hiiiiijjjj....rrrrrrr..xxx...rrrrrr..............................",
	"...................................hiiiii....jjjjjj.....xxxxxxx.mmmm.mmm........xxxxxx...xxxxx......",
	"...................................hiiiii...........................................................",
	"EEEEEEEEFGGGGGGGGGGGFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFGGGGGGGGGGGGGGGGF",
}

local function run_toggle()
	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("file_tree.toggle"))
		action.run(require("gleb.actions.context").capture())
	]])
end

---@param name string
local function focus_tree_row(name)
	local result = child.lua_get(
		[[(function(needle)
			local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
			vim.api.nvim_set_current_win(view.win)
			local labels = {}
			for index, row in ipairs(view.rows) do
				labels[#labels + 1] = row.label
				if row.label == needle then
					vim.api.nvim_win_set_cursor(view.win, { index, 0 })
					return { found = true, labels = labels }
				end
			end
			return { found = false, labels = labels, expanded = view.expanded }
		end)(...)]],
		{ name }
	)
	assert(
		result.found,
		"tree row not found: " .. name .. " in " .. vim.inspect(result.labels) .. "; expanded " .. vim.inspect(result.expanded)
	)
end

---@param name string
local function open_tree_row(name)
	focus_tree_row(name)
	child.type_keys("<CR>")
end

local function ensure_billing_open()
	local opened = child.lua_get([[
(function()
	local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
	if vim.iter(view.rows):any(function(row) return row.label == "invoice.go" end) then
		return true
	end
	for index = #view.rows, 1, -1 do
		local row = view.rows[index]
		if row.kind == "directory" and row.label == "billing" then
			vim.api.nvim_set_current_win(view.win)
			vim.api.nvim_win_set_cursor(view.win, { index, 0 })
			return false
		end
	end
	error("internal/billing row not found")
end)()
]])
	if not opened then
		child.type_keys("<CR>")
		assert(
			child.wait([[
(function()
	local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
	return vim.iter(view.rows):any(function(row) return row.label == "invoice.go" end)
end)()
]], 1000),
			"internal/billing did not expand"
		)
	end
end

local function start()
	local home = vim.fn.tempname()
	root = F.copy("treeproj", vim.fs.joinpath(home, "work", "billing"))
	vim.fn.delete(vim.fs.joinpath(root, "bin"), "rf")
	vim.fn.delete(vim.fs.joinpath(root, "web", "node_modules"), "rf")
	vim.fn.delete(vim.fs.joinpath(root, ".env"))
	H.git(root, { "branch", "-m", "feat/tax" })

	child.start_config({ env = F.go_env() })
	child.o.lines = 30
	child.o.columns = 100
	child.wait_very_lazy()
	child.lua(
		[[
		local home, settings_path = ...
		vim.env.HOME = home
		vim.lsp.enable("gopls", false)
		require("null-ls").disable({})
		vim.diagnostic.enable(false)
		require("gleb.file_tree.settings").setup({ path = settings_path })
	]],
		{ home, vim.fs.joinpath(H.root, "settings", "file_tree.json") }
	)
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
	child.api.nvim_win_set_cursor(0, { 17, 0 })
	assert(child.wait([[vim.b.gitsigns_head == "feat/tax"]], 5000), "gitsigns branch did not load")
	run_toggle()
	assert(
		child.wait(
			[[(function()
				local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
				if not view or next(require("gleb.file_tree.git").status(view.root)) == nil then
					return false
				end
				local git_state = require("gleb.file_tree.git").state.roots[view.root]
				if not git_state or git_state.in_flight or git_state.dirty or git_state.timer then
					return false
				end
				local watch_state = require("gleb.file_tree.watch").state.roots[view.root]
				if watch_state and vim.iter(watch_state.timers):any(function(timer) return timer:is_active() end) then
					return false
				end
				return vim.iter(view.rows):any(function(row)
					return row.label == "invoice.go" and row.status == "modified"
				end)
			end)()]],
			5000
		),
		"project-tree git status did not load"
	)
	open_tree_row("cmd/server")
	open_tree_row("web")
	open_tree_row("src")
	ensure_billing_open()
	focus_tree_row("invoice.go")
	child.type_keys("za")
	child.lua([[
		local tree = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			if win ~= tree.win then
				local buf = vim.api.nvim_win_get_buf(win)
				vim.bo[buf].tabstop = 4
				vim.wo[win].number = true
				vim.wo[win].relativenumber = false
				vim.wo[win].numberwidth = 5
				vim.wo[win].signcolumn = "no"
				vim.wo[win].foldcolumn = "0"
				vim.wo[win].statuscolumn = ""
				require("ibl").setup_buffer(buf, { enabled = false })
			end
		end
		require("lualine").hide({ place = { "statusline" } })
		vim.o.statusline = table.concat({
			"%#lualine_a_normal# NORMAL ",
			"%#lualine_c_normal# ",
			"%#lualine_b_normal# feat/tax ",
			"%#lualine_c_normal#" .. string.rep(" ", 64),
			"%#lualine_b_normal#gleb-file-tree ",
			"%#lualine_c_normal# ",
		})
		vim.o.tabline = table.concat({
			"%#BufferLineFill#" .. string.rep(" ", 36),
			"%#BufferLineBufferSelected# ",
			"%#DevIconGo#",
			"%#BufferLineFill# ",
			"%#BufferLineBufferSelected#invoice.go  ",
			"%#BufferLineFill#" .. string.rep(" ", 49),
		})
	]])
	child.cmd("redraw")
end

local T = H.child_set(child, start)

local function approved_lines()
	local path = vim.fs.joinpath(H.root, "tests/screen/file-tree/nest_proposed.ansi")
	return vim.tbl_map(function(line)
		return (line:gsub("\27%[[0-9;]*m", ""))
	end, vim.fn.readfile(path))
end

T["file-tree: File tree nests match the approved render"] = function()
	local actual = vim.tbl_map(table.concat, child.get_screenshot().text)
	eq(actual, approved_lines())

	local groups = child.lua_get([[
(function()
	local view = assert(require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()])
	local result = {}
	for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(view.buf, -1, 0, -1, { details = true })) do
		local group = mark[4].hl_group
		if group then result[group] = true end
	end
	return result
end)()
]])
	for _, group in ipairs({
		"FileTreeExpander",
		"FileTreeFolderIcon",
		"FileTreeFolderName",
		"FileTreeFileName",
		"FileTreeGitModified",
		"FileTreeGitAdded",
		"FileTreeGitUntracked",
	}) do
		eq(groups[group], true)
	end

	H.expect_screen_colors(child, 1, MASK, LEGEND)
end

return T

-- Reference screenshot of the approved project-tree render (tests/screenshots/).
local F = require("tests.fixtures")
local H = require("tests.helpers")
local MiniTest = require("mini.test")

local child = H.new_child()
local eq = MiniTest.expect.equality
local root

local LEGEND = {
	a = "FileTreeNormal",
	b = "FileTreeExpander",
	c = "FileTreeFolderIcon",
	d = "FileTreeRoot",
	e = "FileTreeRootPath",
	f = "WinSeparator",
	g = "FileTreeFolderName",
	h = "DevIconGo",
	i = "FileTreeFileName",
	j = "FileTreeGitModified",
	k = "FileTreeCursorLine",
	l = "FileTreeGitAdded",
	m = "DevIconTsx",
	n = "DevIconTypeScriptDeclaration",
	o = "DevIconTestTs",
	p = "DevIconTypeScript",
	q = "DevIconPackageLockJson",
	r = "DevIconPackageJson",
	s = "DevIconGitIgnore",
	t = "DevIconGoMod",
	u = "DevIconGoSum",
	v = "DevIconMakefile",
	w = "DevIconMd",
	x = "FileTreeGitUntracked",
	y = "DevIconReadme",
}

local MASK = {
	"....................................................................................................",
	"abacadddddddaaeeeeeeeeeeeeeeaaaaaaaf................................................................",
	"aaabacagggggggggggggggggaaaaaaaaaaaf................................................................",
	"aaabacaggggggggggaaaaaaaaaaaaaaaaaaf................................................................",
	"aaaaaaahaiiiiiiiaaaaaaaaaaaaaaaaaaaf................................................................",
	"aaabacajjjjjjjjaaaaaaaaaaaaaaaaaaaaf................................................................",
	"aaaaabacajjjjjjjaaaaaaaaaaaaaaaaaaaf................................................................",
	"aaaaaaaaahaiiiiiiiiiiiaaaaaaaaaaaaaf................................................................",
	"aaaaaaaaahaiiiiiiiiiiiiiiiiaaaaaaaaf................................................................",
	"kkkkkkkkkhkjjjjjjjjjjkkkkkkkkkkkkkkf................................................................",
	"aaaaaaaaahajjjjjjjjjjjjjjjaaaaaaaaaf................................................................",
	"aaaaaaaaahallllllaaaaaaaaaaaaaaaaaaf................................................................",
	"aaaaaaaaahalllllllllllaaaaaaaaaaaaaf................................................................",
	"aaaaabacagggggaaaaaaaaaaaaaaaaaaaaaf................................................................",
	"aaabacajjjaaaaaaaaaaaaaaaaaaaaaaaaaf................................................................",
	"aaaaabacajjjaaaaaaaaaaaaaaaaaaaaaaaf................................................................",
	"aaaaaaaaamaiiiiiiiiaaaaaaaaaaaaaaaaf................................................................",
	"aaaaaaaaanaiiiiiiiiiiaaaaaaaaaaaaaaf................................................................",
	"aaaaaaaaaoaiiiiiiiiiiiiiaaaaaaaaaaaf................................................................",
	"aaaaaaaaapajjjjjjjjaaaaaaaaaaaaaaaaf................................................................",
	"aaaaaaaqaiiiiiiiiiiiiiiiiiaaaaaaaaaf................................................................",
	"aaaaaaaraiiiiiiiiiiiiaaaaaaaaaaaaaaf................................................................",
	"aaaaasaiiiiiiiiiiaaaaaaaaaaaaaaaaaaf................................................................",
	"aaaaataiiiiiiaaaaaaaaaaaaaaaaaaaaaaf................................................................",
	"aaaaauaiiiiiiaaaaaaaaaaaaaaaaaaaaaaf................................................................",
	"aaaaavaiiiiiiiiaaaaaaaaaaaaaaaaaaaaf................................................................",
	"aaaaawaxxxxxxxxaaaaaaaaaaaaaaaaaaaaf................................................................",
	"aaaaayaiiiiiiiiiaaaaaaaaaaaaaaaaaaaf................................................................",
	"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaf................................................................",
	"....................................................................................................",
}

local function run_toggle()
	child.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("file_tree.toggle"))
		action.run(require("gleb.actions.context").capture())
	]])
end

---@param name string
local function press_enter_on(name)
	local found = child.lua_get(
		[[(function(needle)
			for row, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
				if line:find(needle, 1, true) then
					vim.api.nvim_win_set_cursor(0, { row, 0 })
					return true
				end
			end
			return false
		end)(...)]],
		{ name }
	)
	assert(found, "tree row not found: " .. name)
	child.type_keys("<CR>")
end

local function start()
	local home = vim.fn.tempname()
	root = F.copy("treeproj", vim.fs.joinpath(home, "work", "billing"))
	vim.fn.delete(vim.fs.joinpath(root, "bin"), "rf")
	vim.fn.delete(vim.fs.joinpath(root, "web", "node_modules"), "rf")
	vim.fn.delete(vim.fs.joinpath(root, ".env"))

	child.start_config()
	child.o.lines = 30
	child.o.columns = 100
	child.wait_very_lazy()
	F.disable_file_tree_nesting(child)
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
	assert(child.wait([[vim.b.gitsigns_head == "main"]], 5000), "gitsigns branch did not load")
	-- the render's change bars: gitsigns draws them from hunks it diffs after loading the branch
	assert(
		child.wait("next(require('gitsigns').get_hunks(vim.api.nvim_get_current_buf()) or {}) ~= nil", 5000),
		"gitsigns hunks did not load"
	)
	run_toggle()
	assert(
		child.wait(
			[[(function()
		local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view and next(require("gleb.file_tree.git").status(view.root)) ~= nil
	end)()]],
			5000
		),
		"project-tree git status did not load"
	)
	press_enter_on("cmd/server")
	press_enter_on("web")
	press_enter_on("src")
	child.lua([[vim.fn.search("invoice.go", "w")]])
	child.cmd("redraw")
end

local T = H.child_set(child, start)

local function approved_tree_lines()
	local path = vim.fs.joinpath(H.root, "tests/screen/file-tree/f1_proposed.ansi")
	local artifact = vim.fn.readfile(path)
	local expected = {}
	for row = 2, 28 do
		local plain = artifact[row]:gsub("\27%[[0-9;]*m", "")
		expected[#expected + 1] = vim.fn.strcharpart(plain, 0, 35):gsub(" +$", "")
	end
	return expected
end

T["file-tree: Project tree matches the approved render"] = function()
	H.expect_screenshot(H.screen_rows(child, 1, 29))
	child.lua([[
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			if vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "gleb-file-tree" then
				vim.api.nvim_win_call(win, function()
					vim.cmd("enew")
					vim.wo.number = false
					vim.wo.relativenumber = false
					vim.wo.signcolumn = "no"
					vim.wo.winhighlight = "Normal:Normal,EndOfBuffer:Normal"
					vim.opt_local.fillchars = { eob = " " }
				end)
			end
		end
		vim.cmd("redraw")
	]])
	H.expect_screen_colors(child, 2, vim.list_slice(MASK, 2, 29), LEGEND)
	H.expect_no_neo_tree(child)
end

T["file-tree: Project tree render text matches the ANSI artifact"] = function()
	eq(child.api.nvim_buf_get_lines(0, 0, -1, false), approved_tree_lines())
end

return T

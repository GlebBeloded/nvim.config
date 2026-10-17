local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()
local TIMEOUT_MS = H.lsp_timeout(10000)

local root
local manifest

local function start()
	root, manifest = F.copy("gomod", vim.fn.tempname())
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
	child.lua([[require("null-ls").disable({ name = "golangci_lint" })]])
	child.o.lines, child.o.columns = 30, 100
end

local T = H.child_set(child, start)

local function open_format()
	local declaration = manifest.references.Format[1]
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(declaration.path))
	child.api.nvim_win_set_cursor(0, { declaration.line, declaration.col - 1 })
	eq(child.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) > 0]], TIMEOUT_MS), true)
	child.type_keys("gr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], TIMEOUT_MS), true)
	eq(child.wait([[not require("gleb.references.view").state.classifying]], TIMEOUT_MS), true)
end

---@return string[]
local function tree_lines()
	return child.api.nvim_buf_get_lines(0, 0, -1, false)
end

---@return string
local function hint_line()
	return child.lua_get([[
vim.api.nvim_buf_get_lines(require("gleb.references.view").state.hint_buf, 0, 1, false)[1]
]])
end

---@param label string
local function select_row(label)
	local row = child.lua_get(
		[[(function(label)
	for index, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
		if line:find(label, 1, true) then return index end
	end
end)(...)]],
		{ label }
	)
	child.api.nvim_win_set_cursor(0, { row, 0 })
end

local function add_test_only_reference()
	vim.fn.writefile({ "", 'func OnlyInTests() string { return "only" }' }, root .. "/internal/money/money.go", "a")
	vim.fn.writefile(
		{ "", "func TestOnlyInTests(t *testing.T) {", "\t_ = OnlyInTests()", "}" },
		root .. "/internal/money/money_test.go",
		"a"
	)
end

T["references: Tests key cycles grouped, hidden and mixed"] = function()
	open_format()
	local default = tree_lines()

	child.type_keys("t")
	eq(child.lua_get([[require("gleb.references.view").state.tree.count]]), 3)
	eq(table.concat(tree_lines(), "\n"):find("Test", 1, true), nil)
	eq(hint_line():find("Tests: hidden t", 1, true) ~= nil, true)

	child.type_keys("t")
	local mixed = table.concat(tree_lines(), "\n")
	eq(mixed:find("Production", 1, true), nil)
	eq(mixed:find("Test  ", 1, true), nil)
	eq(mixed:find("money_test.go:6", 1, true) ~= nil, true)
	eq(mixed:find("test", 1, true) ~= nil, true)
	eq(hint_line():find("Tests: mixed t", 1, true) ~= nil, true)

	child.type_keys("t")
	eq(tree_lines(), default)
end

T["references: Tests filter can leave the tree empty"] = function()
	add_test_only_reference()
	child.o.lines, child.o.columns = 30, 100
	child.cmd("edit " .. vim.fn.fnameescape(root .. "/internal/money/money.go"))
	child.api.nvim_win_set_cursor(0, { 10, 6 })
	eq(child.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) > 0]], TIMEOUT_MS), true)
	child.type_keys("gr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], TIMEOUT_MS), true)

	child.type_keys("t")
	local empty = child.lua_get([[
(function()
	local state = require("gleb.references.view").state
	return {
		count = state.tree.count,
		title = vim.api.nvim_win_get_config(state.tree_win).title[1][1],
		height = vim.api.nvim_win_get_height(state.tree_win),
		lines = vim.api.nvim_buf_get_lines(state.preview_buf, 0, -1, false),
		empty_selection = state.preview_usage == nil,
	}
end)()
]])
	eq(empty.count, 0)
	eq(empty.title, " Usages of OnlyInTests · 0 ")
	eq(empty.height, 24)
	eq(empty.lines, { "" })
	eq(empty.empty_selection, true)

	child.type_keys("PP")
	child.o.columns = 70
	child.cmd("doautocmd VimResized")
	eq(child.lua_get([[require("gleb.references.view").state.preview_win == nil]]), true)
	eq(child.lua_get([[vim.api.nvim_win_get_height(require("gleb.references.view").state.tree_win)]]), 1)

	child.o.columns = 140
	child.cmd("doautocmd VimResized")
	eq(child.lua_get([[vim.api.nvim_win_get_width(require("gleb.references.view").state.tree_win)]]), 60)

	child.type_keys("qgr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], TIMEOUT_MS), true)
	eq(child.lua_get([[require("gleb.references.view").state.tree.count]]), 0)
end

T["references: Mixed tests without folders is a flat list"] = function()
	open_format()
	child.type_keys("ttf")

	eq(tree_lines(), {
		" billing/invoice.go:16",
		" billing/invoice.go:23",
		" internal/money/money_test.go:6   test",
		" report/summary.go:7",
	})
	eq(hint_line():find("Tests: mixed t · ○ Folders f", 1, true) ~= nil, true)
end

T["references: Grouping persists across sessions"] = function()
	open_format()
	child.type_keys("tf")
	child.stop()

	child.restart_config({ "--cmd", "cd " .. root }, { env = F.go_env() })
	child.wait_very_lazy()
	child.lua([[require("null-ls").disable({ name = "golangci_lint" })]])
	open_format()

	eq(hint_line():find("Tests: hidden t · ○ Folders f", 1, true) ~= nil, true)
	eq(table.concat(tree_lines(), "\n"):find("Test", 1, true), nil)
end

T["references: Return opens a usage at its position"] = function()
	open_format()
	select_row("summary.go:7")
	child.type_keys("<CR>")

	local summary = vim.iter(manifest.references.Format):find(function(location)
		return location.path == "report/summary.go"
	end)
	eq(child.fn.expand("%:p"), vim.uv.fs_realpath(vim.fs.joinpath(root, "report/summary.go")))
	eq(child.api.nvim_win_get_cursor(0), { summary.line, summary.col - 1 })
	eq(child.lua_get([[next(require("gleb.references.view").state) == nil]]), true)
end

T["references: UTF-16 usage columns are converted to byte columns"] = function()
	local summary_path = root .. "/report/summary.go"
	local lines = vim.fn.readfile(summary_path)
	lines[7] = '\treturn "total: \u{20ac}" + money.Format(total)'
	vim.fn.writefile(lines, summary_path)
	open_format()
	select_row("summary.go:7")
	eq(child.wait([[require("gleb.references.view").state.preview_usage.path == "report/summary.go"]]), true)
	local expected_col = assert(lines[7]:find("Format", 1, true))

	local marked_col = child.lua_get([[
(function()
	local state = require("gleb.references.view").state
	for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(state.preview_buf, -1, { 6, 0 }, { 6, -1 }, { details = true })) do
		if mark[4].hl_group == "Search" then return mark[3] + 1 end
	end
end)()
]])
	eq(marked_col, expected_col)
	child.type_keys("<CR>")
	eq(child.api.nvim_win_get_cursor(0), { 7, expected_col - 1 })
end

T["references: za folds a group"] = function()
	open_format()
	select_row("billing  2")
	child.type_keys("za")

	local folded = table.concat(tree_lines(), "\n")
	eq(folded:find("invoice.go:16", 1, true), nil)
	eq(folded:find("invoice.go:23", 1, true), nil)
	child.type_keys("za")
	local unfolded = table.concat(tree_lines(), "\n")
	eq(unfolded:find("invoice.go:16", 1, true) ~= nil, true)
	eq(unfolded:find("invoice.go:23", 1, true) ~= nil, true)
end

T["references: Escape returns to the origin window"] = function()
	local declaration = manifest.references.Format[1]
	open_format()
	child.type_keys("<Esc>")

	eq(child.fn.expand("%:p"), vim.uv.fs_realpath(vim.fs.joinpath(root, declaration.path)))
	eq(child.api.nvim_win_get_cursor(0), { declaration.line, declaration.col - 1 })
	eq(
		child.lua_get([[#vim.tbl_filter(function(win)
	return vim.bo[vim.api.nvim_win_get_buf(win)].filetype:match("^gleb%-references") ~= nil
end, vim.api.nvim_list_wins())]]),
		0
	)
end

T["references: Built-in close returns to the origin window"] = function()
	local declaration = manifest.references.Format[1]
	open_format()
	child.cmd("quit")
	child.o.columns = 120
	child.cmd("doautocmd VimResized")

	eq(child.fn.expand("%:p"), vim.uv.fs_realpath(vim.fs.joinpath(root, declaration.path)))
	eq(child.api.nvim_win_get_cursor(0), { declaration.line, declaration.col - 1 })
	eq(child.lua_get([[next(require("gleb.references.view").state) == nil]]), true)
	eq(
		child.lua_get([[#vim.tbl_filter(function(win)
	return vim.bo[vim.api.nvim_win_get_buf(win)].filetype:match("^gleb%-references") ~= nil
end, vim.api.nvim_list_wins())]]),
		0
	)
end

T["references: View keys come from the keymap file"] = function()
	open_format()
	local actual = child.lua_get([[
(function()
	local wanted = { "<CR>", "za", "t", "f", "P", "q", "<Esc>" }
	local maps = {}
	for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do maps[map.lhs] = map.desc end
	local shortcuts = vim.json.decode(table.concat(vim.fn.readfile(
		vim.fs.joinpath(vim.fn.stdpath("config"), "settings/keymap.json")), "\n"))
	local result = {}
	for _, lhs in ipairs(wanted) do
		local normalized = vim.keycode(lhs)
		local desc = maps[lhs] or maps[normalized]
		local action = desc and desc:match("^References: (.+)$")
		result[lhs] = { desc = desc, action = action }
	end
	return { result, shortcuts }
end)()
]])
	local expected = {
		["<CR>"] = "Open Usage",
		za = "Fold Group",
		t = "Cycle Tests",
		f = "Toggle Folders",
		P = "Toggle Preview",
		q = "Close",
		["<Esc>"] = "Close",
	}
	for lhs, title in pairs(expected) do
		eq(actual[1][lhs].desc, "References: " .. title)
	end
	eq(actual[2]["references.open"], { "<CR>" })
	eq(actual[2]["references.fold"], { "za" })
	eq(actual[2]["references.cycle_tests"], { "t" })
	eq(actual[2]["references.toggle_folders"], { "f" })
	eq(actual[2]["references.toggle_preview"], { "P" })
	eq(actual[2]["references.close"], { "q", "<Esc>" })

	child.lua([[
local actions = require("gleb.actions")
local shortcuts = vim.deepcopy(actions.state.store.last_good)
shortcuts["references.cycle_tests"] = { "T" }
shortcuts["references.toggle_folders"] = { "F" }
shortcuts["references.open"] = { "o" }
local path = vim.fn.tempname()
vim.fn.writefile({ vim.json.encode(shortcuts) }, path)
actions.state.store.path = path
assert(actions.apply())
]])
	child.type_keys("T")
	eq(child.lua_get([[require("gleb.references.view").state.tree.count]]), 3)
	eq(hint_line():find("Tests: hidden T · ● Folders F · Preview P · Open o", 1, true) ~= nil, true)
end

return T

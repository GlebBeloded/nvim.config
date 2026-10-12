local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

--- Full config with a scratch file instead of the alpha dashboard. A named
--- file (not `:enew`) because auto-save writes modified buffers (E32 otherwise).
local function start()
	child.start_config()
	child.cmd("edit " .. vim.fn.tempname() .. ".txt")
end

---@param lines string[]
local function set_lines(lines)
	child.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

---@return string[]
local function get_lines()
	return child.api.nvim_buf_get_lines(0, 0, -1, false)
end

---@return integer
local function cursor_line()
	return child.api.nvim_win_get_cursor(0)[1]
end

---@param split "split"|"vsplit"
---@return integer first top/left window
---@return integer second bottom/right window
local function two_windows(split)
	child.cmd(split)
	local wins = child.api.nvim_tabpage_list_wins(0)
	return wins[1], wins[2]
end

--- Does the mapping's callback equal the given Lua expression in the child?
---@param lhs string
---@param mode string
---@param expr string
---@return boolean
local function callback_is(lhs, mode, expr)
	return child.lua_get(string.format("vim.fn.maparg(%q, %q, false, true).callback == %s", lhs, mode, expr))
end

--- Wait budget for async plugins (neo-tree, telescope, differ).
local ASYNC_MS = 3000

--- Lua expression: number of neo-tree windows in all tabs.
local TREE_WIN_COUNT = [[#vim.tbl_filter(function(win)
	return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree"
end, vim.api.nvim_list_wins())]]

--- Wait until the current window is the neo-tree window of `source`.
---@param source "filesystem"|"git_status"
---@return boolean
local function wait_tree_focused(source)
	local expr = [[vim.bo.filetype == "neo-tree" and vim.api.nvim_buf_get_name(0):find("neo-tree %s", 1, true) ~= nil]]
	return child.wait(expr:format(source), ASYNC_MS)
end

---@return boolean
local function wait_no_tree()
	return child.wait(TREE_WIN_COUNT .. " == 0", ASYNC_MS)
end

--- `cd` the child into a temp git repo and edit its `foo.lua`.
---@return string repo
local function edit_repo_file()
	local repo = H.git_repo({ ["foo.lua"] = "return 1\n" })
	child.cmd("cd " .. repo .. " | edit foo.lua")
	return repo
end

---@param source "filesystem"|"git_status"
local function focus_tree(source)
	child.cmd("Neotree focus " .. source)
	assert(wait_tree_focused(source), "neo-tree " .. source .. " not focused")
end

--- Path of the filesystem tree node under the cursor (nil if none).
---@return string?
local function tree_cursor_path()
	return child.lua_get([[(function()
		local state = require("neo-tree.sources.manager").get_state("filesystem")
		local node = state.tree and state.tree:get_node()
		return node and node.path or vim.NIL
	end)()]])
end

local function set_diagnostics_on_lines_2_and_4()
	set_lines({ "1", "2", "3", "4", "5" })
	child.lua([[
		local ns = vim.api.nvim_create_namespace("test")
		vim.diagnostic.set(ns, 0, {
			{ lnum = 1, col = 0, message = "first", severity = vim.diagnostic.severity.ERROR },
			{ lnum = 3, col = 0, message = "second", severity = vim.diagnostic.severity.ERROR },
		})
	]])
end

local T = H.child_set(child, start)

-- Mapping options and leaders -------------------------------------------------

T["keymaps: Core mappings are noremap and silent"] = function()
	local map = child.fn.maparg("gb", "n", false, true)

	eq({ map.noremap, map.silent }, { 1, 1 })
end

T["keymaps: Leader values after startup"] = function()
	eq({ child.g.mapleader, child.g.maplocalleader }, { "<D->", "\\" })
end

-- Window navigation ----------------------------------------------------------

T["keymaps: Move to left window"] = function()
	local left, right = two_windows("vsplit")
	child.api.nvim_set_current_win(right)
	child.type_keys("<C-h>")

	eq(child.api.nvim_get_current_win(), left)
end

T["keymaps: Move to window below"] = function()
	local top, bottom = two_windows("split")
	child.api.nvim_set_current_win(top)
	child.type_keys("<A-j>")

	eq(child.api.nvim_get_current_win(), bottom)
end

T["keymaps: Move to window above"] = function()
	local top, bottom = two_windows("split")
	child.api.nvim_set_current_win(bottom)
	child.type_keys("<A-k>")

	eq(child.api.nvim_get_current_win(), top)
end

T["keymaps: Move to right window"] = function()
	local left, right = two_windows("vsplit")
	child.api.nvim_set_current_win(left)
	child.type_keys("<C-l>")

	eq(child.api.nvim_get_current_win(), right)
end

T["keymaps: Navigation stops at edge"] = function()
	local win = child.api.nvim_get_current_win()
	child.type_keys("<C-l>")

	eq(child.api.nvim_get_current_win(), win)
end

-- Window resizing ------------------------------------------------------------

T["keymaps: Increase height"] = function()
	local top = two_windows("split")
	child.api.nvim_set_current_win(top)
	local before = child.api.nvim_win_get_height(top)
	child.type_keys("<C-Up>")

	eq(child.api.nvim_win_get_height(top), before + 2)
end

T["keymaps: Decrease height"] = function()
	local top = two_windows("split")
	child.api.nvim_set_current_win(top)
	local before = child.api.nvim_win_get_height(top)
	child.type_keys("<C-Down>")

	eq(child.api.nvim_win_get_height(top), before - 2)
end

T["keymaps: Decrease width"] = function()
	local left = two_windows("vsplit")
	child.api.nvim_set_current_win(left)
	local before = child.api.nvim_win_get_width(left)
	child.type_keys("<C-Left>")

	eq(child.api.nvim_win_get_width(left), before - 2)
end

T["keymaps: Increase width"] = function()
	local left = two_windows("vsplit")
	child.api.nvim_set_current_win(left)
	local before = child.api.nvim_win_get_width(left)
	child.type_keys("<C-Right>")

	eq(child.api.nvim_win_get_width(left), before + 2)
end

T["keymaps: Smart-splits resize changes window size"] = function()
	local left = two_windows("vsplit")
	child.api.nvim_set_current_win(left)
	local before = child.api.nvim_win_get_width(left)
	child.type_keys("<A-L>")

	eq(child.api.nvim_win_get_width(left) ~= before, true)
end

-- Jump list and buffers ------------------------------------------------------

T["keymaps: gb jumps back"] = function()
	set_lines(vim.fn["repeat"]({ "x" }, 100))
	child.type_keys("gg", "G", "gb")

	eq(cursor_line(), 1)
end

T["keymaps: gB jumps forward"] = function()
	set_lines(vim.fn["repeat"]({ "x" }, 100))
	child.type_keys("gg", "G", "gb", "gB")

	eq(cursor_line(), 100)
end

T["keymaps: Close current buffer"] = function()
	local dir = vim.fn.tempname()
	child.cmd("edit " .. dir .. "/a | edit " .. dir .. "/b")
	local current = child.api.nvim_get_current_buf()
	child.type_keys("<C-q>")

	eq(child.fn.buflisted(current), 0)
end

-- Insert and visual helpers --------------------------------------------------

T["keymaps: jk leaves insert mode"] = function()
	child.type_keys("i", "jk")

	eq({ child.fn.mode(), get_lines() }, { "n", { "" } })
end

T["keymaps: Indent keeps selection"] = function()
	set_lines({ "a", "b" })
	child.type_keys("gg", "Vj", ">")

	eq({ get_lines(), child.fn.mode() }, { { "  a", "  b" }, "V" })
end

T["keymaps: Outdent keeps selection"] = function()
	set_lines({ "  a", "  b" })
	child.type_keys("gg", "Vj", "<")

	eq({ get_lines(), child.fn.mode() }, { { "a", "b" }, "V" })
end

T["keymaps: Paste over selection keeps register"] = function()
	-- yank instead of setreg: with 'clipboard=unnamedplus' the unnamed register is "+"
	set_lines({ "foo", "bar" })
	child.type_keys("gg", "yiw", "j", "viw", "p")

	eq({ get_lines(), child.fn.getreg('"') }, { { "foo", "foo" }, "foo" })
end

T["keymaps: Move selected lines down"] = function()
	set_lines({ "a", "b", "c" })
	child.type_keys("gg", "V", "J")

	eq({ get_lines(), child.fn.mode() }, { { "b", "a", "c" }, "V" })
end

T["keymaps: Move selected lines up"] = function()
	set_lines({ "a", "b", "c" })
	child.type_keys("G", "V", "K")

	eq({ get_lines(), child.fn.mode() }, { { "a", "c", "b" }, "V" })
end

T["keymaps: Alt-j moves selected lines down"] = function()
	set_lines({ "a", "b", "c" })
	child.type_keys("gg", "V", "<A-j>")

	eq({ get_lines(), child.fn.mode() }, { { "b", "a", "c" }, "V" })
end

T["keymaps: Alt-k moves selected lines up"] = function()
	set_lines({ "a", "b", "c" })
	child.type_keys("G", "V", "<A-k>")

	eq({ get_lines(), child.fn.mode() }, { { "a", "c", "b" }, "V" })
end

-- LSP and diagnostics --------------------------------------------------------

T["keymaps: LSP mappings bound to vim.lsp.buf"] = function()
	local expected = {
		gD = "vim.lsp.buf.declaration",
		gd = "vim.lsp.buf.definition",
		K = "vim.lsp.buf.hover",
		gi = "vim.lsp.buf.implementation",
		["<A-r>"] = "vim.lsp.buf.rename",
		["<C-CR>"] = "vim.lsp.buf.code_action",
	}
	for lhs, expr in pairs(expected) do
		eq({ lhs, callback_is(lhs, "n", expr) }, { lhs, true })
	end
end

T["keymaps: Code action in visual mode"] = function()
	eq(callback_is("<C-CR>", "x", "vim.lsp.buf.code_action"), true)
end

T["keymaps: gr bound to Telescope references"] = function()
	eq(callback_is("gr", "n", [[require("telescope.builtin").lsp_references]]), true)
end

T["keymaps: ge jumps to next diagnostic"] = function()
	set_diagnostics_on_lines_2_and_4()
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys("ge")

	eq(cursor_line(), 2)
end

T["keymaps: Alt-w jumps to next diagnostic"] = function()
	set_diagnostics_on_lines_2_and_4()
	child.api.nvim_win_set_cursor(0, { 2, 0 })
	child.type_keys("<A-w>")

	eq(cursor_line(), 4)
end

T["keymaps: [d jumps to previous diagnostic"] = function()
	set_diagnostics_on_lines_2_and_4()
	child.api.nvim_win_set_cursor(0, { 4, 0 })
	child.type_keys("[d")

	eq(cursor_line(), 2)
end

-- Neo-tree, Differ, Telescope ------------------------------------------------

T["keymaps: Alt-e reveals current file"] = function()
	local repo = edit_repo_file()
	child.type_keys("<M-e>")

	eq(wait_tree_focused("filesystem"), true)
	eq(child.wait([[vim.api.nvim_get_current_line():find("foo.lua", 1, true) ~= nil]], ASYNC_MS), true)
	eq(tree_cursor_path(), vim.fs.joinpath(repo, "foo.lua"))
end

T["keymaps: Alt-e on URI buffer focuses filesystem"] = H.xfail(
	"fix-neotree-uri-reveal: follow_current_file prompts to change cwd to vscodediff:",
	function()
		edit_repo_file()
		child.cmd("enew | file vscodediff://x | messages clear")
		child.type_keys("<M-e>")

		eq(wait_tree_focused("filesystem"), true)
		eq({ child.v.errmsg, child.cmd_capture("messages") }, { "", "" })
	end
)

T["keymaps: Alt-e closes focused filesystem tree"] = function()
	edit_repo_file()
	focus_tree("filesystem")
	child.type_keys("<M-e>")

	eq(wait_no_tree(), true)
end

T["keymaps: Alt-G switches tree to git status"] = function()
	edit_repo_file()
	focus_tree("filesystem")
	child.type_keys("<M-G>")

	eq(wait_tree_focused("git_status"), true)
end

T["keymaps: Alt-G closes focused git status tree"] = function()
	edit_repo_file()
	focus_tree("git_status")
	child.type_keys("<M-G>")

	eq(wait_no_tree(), true)
end

T["keymaps: Alt-g opens Differ"] = function()
	local repo = edit_repo_file()
	H.write_files(repo, { ["foo.lua"] = "return 2\n" })
	child.type_keys("<M-g>")

	-- :Differ opens its own tab with the file panel leftmost
	eq(child.wait([[vim.api.nvim_buf_get_name(vim.fn.winbufnr(1)) == "differ://panel"]], ASYNC_MS), true)
	eq(#child.api.nvim_list_tabpages(), 2)
end

T["keymaps: Alt-F opens live grep"] = function()
	edit_repo_file()
	child.type_keys("<M-F>")

	eq(child.wait([[vim.bo.filetype == "TelescopePrompt"]], ASYNC_MS), true)
	eq(
		child.lua_get(
			[[require("telescope.actions.state").get_current_picker(vim.api.nvim_get_current_buf()).prompt_title]]
		),
		"Live Grep"
	)
end

return T

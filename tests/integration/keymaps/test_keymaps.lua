local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

--- Full config with a scratch file instead of the alpha dashboard. A named
--- file (not `:enew`) because auto-save writes modified buffers (E32 otherwise).
local function start()
	child.start_config()
	child.wait_very_lazy()
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

--- Does `gr` start the Find Usages request?
---@return boolean
local function gr_opens_references_view()
	child.lua([[
local references = require("gleb.references")
local original = references.open
local called = false
references.open = function() called = true end
local ok, err = pcall(vim.fn.maparg("gr", "n", false, true).callback)
references.open = original
if not ok then error(err) end
GrOpensReferencesView = called
]])
	return child.lua_get("GrOpensReferencesView")
end

--- Wait budget for asynchronous views and plugins.
---@return integer
local function async_ms()
	return math.ceil(10000 * H.load_factor())
end

--- Wait until the populated project tree has focus.
---@return boolean
local function wait_project_tree_focused()
	return child.wait(
		[[(function()
		local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view ~= nil
			and vim.api.nvim_win_is_valid(view.win)
			and vim.api.nvim_get_current_win() == view.win
			and #view.rows > 0
	end)()]],
		async_ms()
	)
end

--- Path of the project-tree row under the cursor.
---@return string
local function project_tree_cursor_path()
	return child.lua_get([=[(function()
		local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view.rows[vim.api.nvim_win_get_cursor(view.win)[1]].path
	end)()]=])
end

--- Wait until the populated Changes panel has focus.
---@return boolean
local function wait_changes_focused()
	return child.wait(
		[[(function()
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view ~= nil
			and vim.api.nvim_win_is_valid(view.win)
			and vim.api.nvim_get_current_win() == view.win
			and #view.rows > 0
	end)()]],
		async_ms()
	)
end

--- `cd` the child into a temp git repo and edit its `foo.lua`.
---@return string repo
local function edit_repo_file()
	local repo = H.git_repo({ ["foo.lua"] = "return 1\n" })
	child.cmd("cd " .. repo .. " | edit foo.lua")
	return repo
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

--- Lua run via `--cmd` before init.lua: wraps `require("lazy").setup` so it
--- records `vim.g.mapleader` at call time in `_G.leader_at_lazy_setup`.
local RECORD_LEADER_AT_LAZY_SETUP = [[lua package.preload.lazy = function()
	package.preload.lazy = nil
	package.loaded.lazy = nil
	local lazy = require("lazy")
	local setup = lazy.setup
	lazy.setup = function(...)
		_G.leader_at_lazy_setup = vim.g.mapleader
		return setup(...)
	end
	return lazy
end]]

--- Lua run via `--cmd` before init.lua: wraps `require("gleb.nvim_debug_log").setup`
--- so each call appends `vim.g.mapleader` to `_G.leaders_at_debug_log_setup`.
local RECORD_LEADER_AT_DEBUG_LOG_SETUP = [[lua package.preload["gleb.nvim_debug_log"] = function()
	package.preload["gleb.nvim_debug_log"] = nil
	package.loaded["gleb.nvim_debug_log"] = nil
	local debug_log = require("gleb.nvim_debug_log")
	local setup = debug_log.setup
	debug_log.setup = function(...)
		_G.leaders_at_debug_log_setup = _G.leaders_at_debug_log_setup or {}
		table.insert(_G.leaders_at_debug_log_setup, vim.g.mapleader)
		return setup(...)
	end
	return debug_log
end]]

--- Restart the child like `child.start_config`, running `hook` via `--cmd` before init.lua.
---@param hook string
local function start_with_cmd_hook(hook)
	H.isolate()
	child.restart(vim.list_extend({ "--cmd", hook }, H.config_args()))
	vim.iter(H.DISABLED_PLUGINS):each(child.disable_plugin)
end

local T = H.child_set(child, start)

-- Mapping options and leaders -------------------------------------------------

T["keymaps: Core mappings are noremap and silent"] = function()
	local map = child.lua_get([[(function()
		local value = vim.fn.maparg("gb", "n", false, true)
		return { noremap = value.noremap, silent = value.silent }
	end)()]])

	eq({ map.noremap, map.silent }, { 1, 1 })
end

--- Every `{ mode, lhs }` defined in lua/gleb/keymaps.lua.
local core_maps = {
	{ "n", "<C-h>" },
	{ "n", "<A-j>" },
	{ "n", "<A-k>" },
	{ "n", "<C-l>" },
	{ "n", "gb" },
	{ "n", "gB" },
	{ "n", "<C-Up>" },
	{ "n", "<C-Down>" },
	{ "n", "<C-Left>" },
	{ "n", "<C-Right>" },
	{ "n", "<A-H>" },
	{ "n", "<A-J>" },
	{ "n", "<A-K>" },
	{ "n", "<A-L>" },
	{ "n", "<C-q>" },
	{ "n", "<A-e>" },
	{ "n", "<A-g>" },
	{ "n", "<A-G>" },
	{ "n", "<A-F>" },
	{ "n", "<C-CR>" },
	{ "n", "gD" },
	{ "n", "gd" },
	{ "n", "K" },
	{ "n", "gi" },
	{ "n", "gr" },
	{ "n", "<A-r>" },
	{ "n", "<A-w>" },
	{ "n", "[d" },
	{ "n", "ge" },
	{ "i", "jk" },
	{ "x", "<" },
	{ "x", ">" },
	{ "x", "p" },
	{ "x", "J" },
	{ "x", "K" },
	{ "x", "<A-j>" },
	{ "x", "<A-k>" },
	{ "x", "<C-CR>" },
}

T["keymaps: Every core mapping has an area-action desc"] = function()
	local offenders = child.lua_get(
		[[vim.iter(...):filter(function(m)
            local desc = vim.fn.maparg(m[2], m[1], false, true).desc
			return desc == nil or not desc:match("^%u[%w |]*: %S.*$")
        end):totable()]],
		{ core_maps }
	)

	eq(offenders, {})
end

T["keymaps: Core mappings resolve through actions"] = function()
	child.wait_very_lazy()
	local expected = {
		{ "window.move_left", "n", "<C-h>", "Window: Focus Left Window" },
		{ "window.move_down", "n", "<A-j>", "Window: Focus Down Window" },
		{ "window.move_up", "n", "<A-k>", "Window: Focus Up Window" },
		{ "window.move_right", "n", "<C-l>", "Window: Focus Right Window" },
		{ "jump.back", "n", "gb", "Jump: Navigate Back" },
		{ "jump.forward", "n", "gB", "Jump: Navigate Forward" },
		{ "window.increase_height", "n", "<C-Up>", "Window: Increase Window Height" },
		{ "window.decrease_height", "n", "<C-Down>", "Window: Decrease Window Height" },
		{ "window.decrease_width", "n", "<C-Left>", "Window: Decrease Window Width" },
		{ "window.increase_width", "n", "<C-Right>", "Window: Increase Window Width" },
		{ "window.resize_left", "n", "<A-H>", "Window: Resize Window Left" },
		{ "window.resize_down", "n", "<A-J>", "Window: Resize Window Down" },
		{ "window.resize_up", "n", "<A-K>", "Window: Resize Window Up" },
		{ "window.resize_right", "n", "<A-L>", "Window: Resize Window Right" },
		{ "buffer.close", "n", "<C-q>", "Buffer: Close Buffer" },
		{ "edit.leave_insert", "i", "jk", "Edit: Leave Insert Mode" },
		{ "edit.outdent_selection", "x", "<", "Edit: Outdent Selection" },
		{ "edit.indent_selection", "x", ">", "Edit: Indent Selection" },
		{ "edit.paste_without_yanking", "x", "p", "Edit: Paste Without Yanking" },
		{ "edit.move_selection_down", "x", "J", "Edit: Move Selection Down" },
		{ "edit.move_selection_up", "x", "K", "Edit: Move Selection Up" },
		{ "edit.move_selection_down", "x", "<A-j>", "Edit: Move Selection Down" },
		{ "edit.move_selection_up", "x", "<A-k>", "Edit: Move Selection Up" },
		{ "file_tree.toggle", "n", "<A-e>", "Project: Toggle Project Tree" },
		{ "changes.review", "n", "<A-g>", "View | Tool Windows: Review Changes" },
		{ "changes.toggle", "n", "<A-G>", "View | Tool Windows: Toggle Changes" },
		{ "search.live_grep", "n", "<A-F>", "Edit | Find: Find in Files..." },
		{ "lsp.code_action", "n", "<C-CR>", "LSP: Show Code Actions..." },
		{ "lsp.code_action", "x", "<C-CR>", "LSP: Show Code Actions..." },
		{ "lsp.go_to_declaration", "n", "gD", "LSP: Go to Declaration" },
		{ "lsp.go_to_definition", "n", "gd", "LSP: Go to Definition" },
		{ "lsp.hover", "n", "K", "LSP: Show Hover Info" },
		{ "lsp.go_to_implementation", "n", "gi", "LSP: Go to Implementation" },
		{ "lsp.references", "n", "gr", "LSP: Find References" },
		{ "lsp.rename", "n", "<A-r>", "LSP: Rename Symbol..." },
		{ "diag.next", "n", "<A-w>", "Diagnostics: Next Diagnostic" },
		{ "diag.next", "n", "ge", "Diagnostics: Next Diagnostic" },
		{ "diag.previous", "n", "[d", "Diagnostics: Previous Diagnostic" },
	}

	local offenders = child.lua_get(
		[[(function(expected)
		local catalog = require("gleb.actions").state.applicator.catalog
		local found = {}
		for _, item in ipairs(expected) do
			local id, mode, lhs, desc = unpack(item)
			local action = catalog:get(id)
			local map = vim.fn.maparg(lhs, mode, false, true)
			if not action or type(map.callback) ~= "function" or map.desc ~= desc
				or map.noremap ~= 1 or map.silent ~= 1
			then
				table.insert(found, id)
			elseif action.mapping then
				if map.callback ~= action.mapping then table.insert(found, id) end
			else
				local original = action.run
				local invoked = false
				action.run = function() invoked = true end
				map.callback()
				action.run = original
				if not invoked then table.insert(found, id) end
			end
		end
		return found
	end)(...)]],
		{ expected }
	)

	eq(offenders, {})
end

T["keymaps: Unadopted built-in mappings are removed"] = function()
	local defaults = { "grn", "gra", "grr", "gri", "grt", "gO", "]d", "[q", "]q" }
	local mappings = vim.tbl_map(function(lhs)
		return child.fn.maparg(lhs, "n")
	end, defaults)

	eq(mappings, { "", "", "", "", "", "", "", "", "" })
end

T["keymaps: Adopted built-in mappings are registry actions"] = function()
	local map = child.lua_get([[(function()
		local value = vim.fn.maparg("[d", "n", false, true)
		return { desc = value.desc, callback_type = type(value.callback) }
	end)()]])
	local action_id = child.lua_get([[require("gleb.actions").state.applicator.catalog:get("diag.previous").id]])

	eq({ map.desc, map.callback_type, action_id }, { "Diagnostics: Previous Diagnostic", "function", "diag.previous" })
end

T["keymaps: Surround mappings use registered actions"] = function()
	local expected = {
		{ "i", "<C-g>s", "<Plug>(nvim-surround-insert)", "Surround: Insert Surrounding" },
		{ "i", "<C-g>S", "<Plug>(nvim-surround-insert-line)", "Surround: Insert Surrounding on Line" },
		{ "n", "ys", "<Plug>(nvim-surround-normal)", "Surround: Add Surrounding" },
		{ "n", "yss", "<Plug>(nvim-surround-normal-cur)", "Surround: Add Surrounding on Current Line" },
		{ "n", "yS", "<Plug>(nvim-surround-normal-line)", "Surround: Add Surrounding on Lines" },
		{ "n", "ySS", "<Plug>(nvim-surround-normal-cur-line)", "Surround: Add Surrounding on Current Lines" },
		{ "n", "ds", "<Plug>(nvim-surround-delete)", "Surround: Delete Surrounding" },
		{ "n", "cs", "<Plug>(nvim-surround-change)", "Surround: Change Surrounding..." },
		{ "n", "cS", "<Plug>(nvim-surround-change-line)", "Surround: Change Surrounding on Lines..." },
		{ "x", "S", "<Plug>(nvim-surround-visual)", "Surround: Add Surrounding to Selection" },
		{ "x", "gS", "<Plug>(nvim-surround-visual-line)", "Surround: Add Surrounding to Selected Lines" },
	}
	local actual = vim.tbl_map(function(item)
		local map = child.fn.maparg(item[2], item[1], false, true)
		return { item[1], item[2], map.rhs, map.desc }
	end, expected)

	eq(actual, expected)
	eq(child.g.nvim_surround_no_mappings, true)
end

T["keymaps: Leader values after startup"] = function()
	eq({ child.g.mapleader, child.g.maplocalleader }, { " ", "\\" })
end

T["keymaps: Leader is set before lazy.nvim loads plugins"] = function()
	start_with_cmd_hook(RECORD_LEADER_AT_LAZY_SETUP)

	eq(child.lua_get("_G.leader_at_lazy_setup"), " ")
end

T["keymaps: Leader is set before the debug log starts"] = function()
	start_with_cmd_hook(RECORD_LEADER_AT_DEBUG_LOG_SETUP)

	eq(child.lua_get("_G.leaders_at_debug_log_setup"), { " " })
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

T["keymaps: Command maps do not enter the command line"] = function()
	two_windows("split")
	child.g.cmdline_enters = 0
	child.lua([[vim.api.nvim_create_autocmd("CmdlineEnter", {
        callback = function()
            vim.g.cmdline_enters = vim.g.cmdline_enters + 1
        end,
    })]])
	child.type_keys("<C-Up>", "<C-Down>", "<C-Left>", "<C-Right>")

	eq(child.g.cmdline_enters, 0)
end

T["keymaps: Smart-splits resize changes window size"] = function()
	local left = two_windows("vsplit")
	child.api.nvim_set_current_win(left)
	local before = child.api.nvim_win_get_width(left)
	child.type_keys("<A-L>")

	eq(child.api.nvim_win_get_width(left) ~= before, true)
end

T["keymaps: Smart-splits resize keys are not remapped"] = function()
	child.wait_very_lazy() -- after every startup and VeryLazy mapping
	local resize = { ["<A-H>"] = "left", ["<A-J>"] = "down", ["<A-K>"] = "up", ["<A-L>"] = "right" }
	for lhs, direction in pairs(resize) do
		eq({ lhs, callback_is(lhs, "n", ('require("smart-splits").resize_%s'):format(direction)) }, { lhs, true })
	end
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

T["keymaps: Close buffer keeps split layout"] = function()
	local dir = vim.fn.tempname()
	child.cmd("edit " .. dir .. "/a | edit " .. dir .. "/b | vsplit")
	local b = child.api.nvim_get_current_buf()
	child.type_keys("<C-q>")
	local wins = child.api.nvim_tabpage_list_wins(0)
	local shown = vim.tbl_map(child.api.nvim_win_get_buf, wins)

	eq({ #wins, vim.tbl_contains(shown, b), child.fn.buflisted(b) }, { 2, false, 0 })
end

T["keymaps: Close modified buffer is refused"] = function()
	local dir = vim.fn.tempname()
	-- gitcommit: the auto-save condition skips it, so it stays modified
	child.cmd("edit " .. dir .. "/a | edit " .. dir .. "/b | setlocal filetype=gitcommit")
	local b = child.api.nvim_get_current_buf()
	set_lines({ "changed" })
	-- the refusal is reported as an error (E89), which type_keys rethrows
	pcall(child.type_keys, "<C-q>")

	eq({
		child.api.nvim_get_current_buf(),
		child.fn.buflisted(b),
		child.api.nvim_get_option_value("modified", { buf = b }),
	}, { b, 1, true })
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

T["keymaps: Counts preserve mapped operations"] = function()
	set_lines({ "a", "b", "c" })
	child.type_keys("gg", "V", "2>")
	eq(get_lines()[1], "    a")

	child.type_keys("<Esc>")
	child.bo.commentstring = "-- %s"
	child.type_keys("gg", "3<A-/>")
	-- `3gcc`: one block at the lines' minimum indent, as the pre-migration `<A-/>` → `gcc` remap did
	eq(get_lines(), { "--     a", "-- b", "-- c" })

	set_lines({ "outer", "inner", "body", "body", "inner end", "outer end" })
	child.lua([[
		vim.wo.foldmethod = "manual"
		vim.cmd("2,5fold")
		vim.cmd("1,6fold")
		-- inside both folds: a count reaches only folds that contain the cursor line
		vim.api.nvim_win_set_cursor(0, { 3, 0 })
	]])
	child.type_keys("2<M-=>")
	eq({ child.fn.foldclosed(1), child.fn.foldclosed(2) }, { -1, -1 })
	child.type_keys("2<M-->")
	eq(child.fn.foldclosed(1), 1)
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

T["keymaps: Visual helpers are not mapped in select mode"] = function()
	local lhs = { "<", ">", "p", "<A-j>", "<A-k>", "<C-CR>" }
	local select_maps = vim.tbl_map(function(key)
		return child.fn.maparg(key, "s")
	end, lhs)

	eq(select_maps, { "", "", "", "", "", "" })
end

T["keymaps: Typing p in select mode inserts p"] = function()
	-- Yank because clipboard=unnamedplus makes direct setreg setup misleading.
	set_lines({ "foo", "bar baz" })
	child.type_keys("gg", "yiw", "j", "0", "v", "<C-g>", "p")

	eq({ get_lines(), child.fn.mode() }, { { "foo", "par baz" }, "i" })
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
	eq(gr_opens_references_view(), true)

	local gr_maps = child.lua_get([[
vim.tbl_map(function(mapping)
	return mapping.lhs
end, vim.tbl_filter(function(mapping)
	return mapping.lhs:match("^gr") ~= nil
end, vim.api.nvim_get_keymap("n")))
]])
	table.sort(gr_maps)
	eq(gr_maps, { "gr" })
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

T["keymaps: Diagnostic jump is not deprecated"] = function()
	child.lua([[
		_G.deprecations = {}
		vim.deprecate = function(name)
			table.insert(_G.deprecations, name)
		end
	]])
	set_diagnostics_on_lines_2_and_4()
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys("ge", "<A-w>", "[d")

	eq(child.lua_get("_G.deprecations"), {})
	eq(child.cmd_capture("messages"):find("deprecated"), nil)
end

--- Is there a floating window whose buffer contains `text`? (child Lua expression)
local FLOAT_WITH_FIRST = [[vim.iter(vim.api.nvim_list_wins()):any(function(win)
	local buf = vim.api.nvim_win_get_buf(win)
	local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
	return vim.api.nvim_win_get_config(win).relative ~= "" and text:find("first") ~= nil
end)]]

T["keymaps: Diagnostic jump opens float"] = function()
	set_diagnostics_on_lines_2_and_4()
	child.api.nvim_win_set_cursor(0, { 1, 0 })
	child.type_keys("ge")

	eq(child.wait(FLOAT_WITH_FIRST, 1000), true)
end

-- Project tree, Changes, Telescope -----------------------------------------

T["keymaps: Alt-e reveals current file"] = function()
	local repo = edit_repo_file()
	child.type_keys("<M-e>")

	eq(wait_project_tree_focused(), true)
	eq(project_tree_cursor_path(), vim.fs.joinpath(repo, "foo.lua"))
end

T["keymaps: Alt-e on URI buffer focuses the project tree"] = function()
	local repo = edit_repo_file()
	child.cmd("enew | file diffview:///x | messages clear")
	child.type_keys("<M-e>")

	eq(wait_project_tree_focused(), true)
	eq(project_tree_cursor_path(), repo)
	eq({ child.v.errmsg, child.cmd_capture("messages") }, { "", "" })
end

T["keymaps: Alt-e tolerates a deleted current file"] = function()
	local repo = edit_repo_file()
	vim.fn.delete(vim.fs.joinpath(repo, "foo.lua"))
	child.cmd("messages clear")
	child.type_keys("<M-e>")

	eq(wait_project_tree_focused(), true)
	eq(project_tree_cursor_path(), repo)
	eq({ child.v.errmsg, child.cmd_capture("messages") }, { "", "" })
end

T["keymaps: Alt-e closes the focused project tree"] = function()
	edit_repo_file()
	child.type_keys("<M-e>")
	eq(wait_project_tree_focused(), true)
	child.type_keys("<M-e>")

	eq(child.wait([[require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()] == nil]]), true)
end

T["keymaps: Alt-G replaces the project tree with the changes panel"] = function()
	local repo = edit_repo_file()
	H.write_files(repo, { ["foo.lua"] = "return 2\n" })
	child.type_keys("<M-e>")
	eq(wait_project_tree_focused(), true)
	child.type_keys("<M-G>")

	eq(wait_changes_focused(), true)
	eq(
		child.lua_get([[vim.iter(vim.api.nvim_list_wins()):any(function(win)
		return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "gleb-file-tree"
	end)]]),
		false
	)
end

T["keymaps: Alt-G closes the focused changes panel"] = function()
	local repo = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	child.cmd("cd " .. vim.fn.fnameescape(repo) .. " | enew")
	child.type_keys("<M-G>")
	eq(wait_changes_focused(), true)
	child.type_keys("<M-G>")

	eq(child.wait([[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()] == nil]]), true)
end

T["keymaps: Toggle wins over a pending tree refresh"] = function()
	local repo = F.copy("treeproj", vim.fn.tempname() .. "/treeproj")
	child.cmd("cd " .. vim.fn.fnameescape(repo) .. " | edit README.md")
	local editor_win = child.api.nvim_get_current_win()
	child.type_keys("<M-e>")
	eq(wait_project_tree_focused(), true)
	for _, relative in ipairs({ "internal", "internal/billing" }) do
		child.lua(
			[[
		local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
		local path = vim.fs.joinpath(view.root, ...)
		for index, row in ipairs(view.rows) do
			if row.path == path then
				vim.api.nvim_win_set_cursor(view.win, { index, 0 })
				return
			end
		end
		error("tree path not found: " .. ...)
	]],
			{ relative }
		)
		child.type_keys("<CR>")
	end
	vim.system({ "touch", vim.fs.joinpath(repo, "internal/billing/fee.go") }):wait()
	child.type_keys("<M-e>")
	child.lua([[vim.wait(1000)]])

	eq(
		child.lua_get([[vim.iter(vim.api.nvim_list_wins()):all(function(win)
		return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "gleb-file-tree"
	end)]]),
		true
	)
	eq(child.api.nvim_get_current_win(), editor_win)
end

T["keymaps: Toggle wins over a pending changes refresh"] = function()
	local repo = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	child.cmd("cd " .. vim.fn.fnameescape(repo) .. " | enew")
	child.type_keys("<M-G>")
	eq(wait_changes_focused(), true)
	child.api.nvim_exec_autocmds("FocusGained", {})
	child.type_keys("<M-G>")
	child.lua([[vim.wait(1000)]])

	eq(
		child.lua_get([[vim.iter(vim.api.nvim_list_wins()):all(function(win)
		return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "gleb-changes"
	end)]]),
		true
	)
end

T["keymaps: Alt-g opens the changes review"] = function()
	local repo = F.copy("billing", vim.fn.tempname() .. "/billing")
	local invoice = vim.fs.joinpath(repo, "internal/billing/invoice.go")
	child.cmd("cd " .. vim.fn.fnameescape(repo) .. " | edit " .. vim.fn.fnameescape(invoice))
	child.type_keys("<M-g>")

	eq(
		child.wait(
			[=[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		if not panel or not panel.diff_view then
			return false
		end
		local row = panel.rows[vim.api.nvim_win_get_cursor(panel.win)[1]]
		return vim.api.nvim_get_current_win() == panel.win
			and row ~= nil
			and row.path == "internal/billing/invoice.go"
			and panel.diff_view.relpath == "internal/billing/invoice.go"
	end)()]=],
			async_ms()
		),
		true
	)
end

T["git: Cmd+G with the project tree open replaces it"] = function()
	local repo = F.copy("billing", vim.fn.tempname() .. "/billing")
	local invoice = vim.fs.joinpath(repo, "internal/billing/invoice.go")
	child.cmd("cd " .. vim.fn.fnameescape(repo) .. " | edit " .. vim.fn.fnameescape(invoice))
	child.type_keys("<M-e>")
	eq(wait_project_tree_focused(), true)
	child.cmd("wincmd l")
	child.type_keys("<M-g>")

	eq(
		child.wait(
			[[(function()
				local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				if not panel or not panel.diff_view then
					return false
				end
				return vim.iter(vim.api.nvim_tabpage_list_wins(0)):all(function(win)
					return vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= "gleb-file-tree"
				end)
			end)()]],
			async_ms()
		),
		true
	)
end

T["keymaps: Alt-F opens live grep"] = function()
	edit_repo_file()
	child.type_keys("<M-F>")

	eq(child.wait([[require("mini.pick").is_picker_active()]], async_ms()), true)
	eq(child.lua_get([[require("mini.pick").get_picker_opts().source.name]]), "Live Grep")
end

T["keymaps: Live grep renders matching rows"] = function()
	local repo = H.git_repo({ ["matched.lua"] = "local pickerneedle = true\n" })
	child.cmd("cd " .. repo .. " | edit matched.lua")
	child.type_keys("<M-F>", "pickerneedle")

	local rendered_match = [[(function()
		local MiniPick = require("mini.pick")
		if not MiniPick.is_picker_active() then return false end
		local buf = MiniPick.get_picker_state().buffers.main
		local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
		return text:find("matched.lua", 1, true) ~= nil
			and text:find("1", 1, true) ~= nil
			and text:find("local pickerneedle = true", 1, true) ~= nil
	end)()]]
	eq(child.wait(rendered_match, async_ms()), true)
end

return T

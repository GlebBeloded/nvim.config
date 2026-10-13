-- Shared helpers for mini.test cases. Runs inside the runner Neovim.
--
-- Child Neovims never touch the user's real state: every XDG directory points
-- into a temp sandbox. `stdpath("config")` is a symlink to this checkout and
-- the cache is shared per run; data/state are fresh for every child start
-- (no sessions, shada, undo files carried over). Only installed plugins
-- (`lazy/`) and treesitter parsers (`site/`) are linked from NVIM_TEST_DATA_DIR.

local MiniTest = require("mini.test")

local M = {}

---@type string Absolute path of the config checkout (worktree root).
M.root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

---@type string Data dir holding installed plugins (`lazy/`) and parsers (`site/`).
M.data_dir = vim.env.NVIM_TEST_DATA_DIR or vim.fs.joinpath(vim.env.HOME, ".local/share/nvim")

--- Env vars that make plugins talk to a terminal multiplexer (smart-splits).
local MULTIPLEXER_ENV = {
	"ZELLIJ",
	"ZELLIJ_SESSION_NAME",
	"ZELLIJ_PANE_ID",
	"TMUX",
	"TMUX_PANE",
	"WEZTERM_PANE",
	"KITTY_LISTEN_ON",
	"KITTY_WINDOW_ID",
}

---@type string?
local sandbox

---@param target string
---@param link string
local function symlink(target, link)
	vim.fn.mkdir(vim.fs.dirname(link), "p")
	if vim.uv.fs_stat(target) then
		assert(vim.uv.fs_symlink(target, link))
	end
end

--- Point XDG_DATA_HOME/XDG_STATE_HOME at fresh dirs so each child starts
--- without sessions, shada or undo history left by earlier children.
local function fresh_state()
	local dir = vim.fn.tempname()
	symlink(vim.fs.joinpath(M.data_dir, "lazy"), vim.fs.joinpath(dir, "data/nvim/lazy"))
	symlink(vim.fs.joinpath(M.data_dir, "site"), vim.fs.joinpath(dir, "data/nvim/site"))
	vim.fn.mkdir(vim.fs.joinpath(dir, "state"), "p")
	vim.env.XDG_DATA_HOME = vim.fs.joinpath(dir, "data")
	vim.env.XDG_STATE_HOME = vim.fs.joinpath(dir, "state")
end

--- Point this process's env (inherited by children) at a sandbox: shared
--- config symlink and cache per run, fresh data/state per call.
---@return string sandbox directory
function M.isolate()
	if not sandbox then
		sandbox = vim.fn.tempname()
		symlink(M.root, vim.fs.joinpath(sandbox, "config/nvim"))
		-- vim.loader's mkdir("cache/nvim/luac", "p") races when two Neovims
		-- start at once (E739), so the cache tree exists before any child runs
		vim.fn.mkdir(vim.fs.joinpath(sandbox, "cache/nvim/luac"), "p")
		vim.env.XDG_CONFIG_HOME = vim.fs.joinpath(sandbox, "config")
		vim.env.XDG_CACHE_HOME = vim.fs.joinpath(sandbox, "cache")
		vim.env.NVIM_APPNAME = nil
		for _, name in ipairs(MULTIPLEXER_ENV) do
			vim.env[name] = nil
		end
	end
	fresh_state()
	return sandbox
end

---@class test.Child: MiniTest.child
---@field start_config fun() Restart with the real config (init.lua); copilot.lua disabled.
---@field start_bare fun(plugins?: string[]) Restart with tests/minimal_init.lua plus the named lazy plugins on rtp.
---@field disable_plugin fun(name: string) Remove lazy.nvim load handlers of a plugin.
---@field wait_very_lazy fun() Fire UIEnter (absent headless) and wait for VeryLazy.
---@field wait fun(expr: string, timeout?: integer): boolean Wait until Lua `expr` is truthy in the child.

--- Lua run in a full-config Neovim to remove lazy.nvim load handlers of the
--- plugin named by its first argument.
M.DISABLE_PLUGIN_LUA = [[local plugin = require("lazy.core.config").plugins[...]
if plugin then require("lazy.core.handler").disable(plugin) end]]

--- Plugins disabled in every full-config Neovim (copilot.lua lazy-loads on
--- InsertEnter and talks to the network).
M.DISABLED_PLUGINS = { "copilot.lua" }

--- nvim-debug-log writes /tmp/nvim/<time>_<pid>.txt (hard-coded path).
---@param pid integer
function M.delete_debug_log(pid)
	for _, file in ipairs(vim.fn.glob("/tmp/nvim/*_" .. pid .. ".txt", false, true)) do
		vim.fn.delete(file)
	end
end

---@param child MiniTest.child
local function delete_child_debug_log(child)
	local ok, pid = pcall(function()
		return child.fn.getpid() -- indexing child.fn already talks to the child
	end)
	if ok then
		M.delete_debug_log(pid)
	end
end

--- Neovim arguments that load the real config from the sandbox symlink
--- (needed because mini.test and the render harness pass --clean).
---@return string[]
function M.config_args()
	local config = vim.fs.joinpath(vim.env.XDG_CONFIG_HOME, "nvim")
	return {
		"--cmd",
		"set rtp^=" .. config,
		"--cmd",
		"luafile " .. vim.fs.joinpath(M.root, "tests/child_init.lua"),
		"-u",
		vim.fs.joinpath(config, "init.lua"),
	}
end

--- New child Neovim with config/bare start helpers.
---@return test.Child
function M.new_child()
	M.isolate()
	local child = MiniTest.new_child_neovim() --[[@as test.Child]]
	local stop = child.stop

	function child.stop()
		if child.is_running() then
			delete_child_debug_log(child)
		end
		stop()
	end

	function child.start_config()
		-- mini.test always passes --clean, which drops stdpath("config") from rtp
		M.isolate()
		child.restart(M.config_args())
		vim.iter(M.DISABLED_PLUGINS):each(child.disable_plugin)
	end

	function child.disable_plugin(name)
		child.lua(M.DISABLE_PLUGIN_LUA, { name })
	end

	function child.start_bare(plugins)
		M.isolate()
		local args = { "-u", vim.fs.joinpath(M.root, "tests/minimal_init.lua") }
		for _, plugin in ipairs(plugins or {}) do
			vim.list_extend(args, { "--cmd", "set rtp+=" .. vim.fs.joinpath(M.data_dir, "lazy", plugin) })
		end
		child.restart(args)
	end

	function child.wait(expr, timeout)
		local ok = vim.wait(timeout or 2000, function()
			return child.lua_get(expr) and true or false
		end, 20)
		return ok
	end

	function child.wait_very_lazy()
		child.lua([[if not vim.g.did_very_lazy then vim.api.nvim_exec_autocmds("UIEnter", {}) end]])
		assert(child.wait("vim.g.did_very_lazy"), "VeryLazy did not fire")
	end

	return child
end

--- Test set whose cases each get a fresh child started by `start`.
---@param child test.Child
---@param start fun()
---@return table
function M.child_set(child, start)
	return MiniTest.new_set({
		hooks = {
			pre_case = start,
			post_once = child.stop,
		},
	})
end

--- Expected failure: wrap a case that documents a known bug (see
--- its queued change in openspec/changes/). It is reported as a skipped case with an XFAIL note
--- while it fails, and fails loudly (XPASS) once the bug is fixed.
---@param reason string finding reference shown in the note
---@param case fun()
---@return fun()
function M.xfail(reason, case)
	return function()
		if pcall(case) then
			error("XPASS (bug fixed? remove H.xfail): " .. reason)
		end
		MiniTest.skip("XFAIL: " .. reason)
	end
end

--- Re-encode attr codes of a screenshot slice so it is independent of rows
--- outside the slice (mini.test numbers attrs in order of appearance).
---@param attr string[][]
---@return string[][]
local function encode_attr(attr)
	local codes, next_code = {}, 48
	return vim.tbl_map(function(line)
		return vim.tbl_map(function(code)
			if not codes[code] then
				codes[code] = string.char(next_code)
				next_code = next_code + 1
			end
			return codes[code]
		end, line)
	end, attr)
end

--- Screenshot of rows `from..to` (negative counts from the bottom).
---@param child MiniTest.child
---@param from integer
---@param to? integer
---@return table screenshot usable with expect.reference_screenshot
function M.screen_rows(child, from, to)
	local full = child.get_screenshot()
	local n = #full.text
	from = from < 0 and n + from + 1 or from
	to = to and (to < 0 and n + to + 1 or to) or from
	local text, attr = {}, {}
	for row = from, to do
		table.insert(text, full.text[row])
		table.insert(attr, full.attr[row])
	end
	full.text, full.attr = text, encode_attr(attr)
	return full
end

---@type string Highlight group of unmasked cells in design-render masks.
M.DEFAULT_GROUP = "Normal"

---@type table<string, true> Mask letters that mean `M.DEFAULT_GROUP`.
M.UNMASKED = { ["."] = true, [" "] = true }

---@class test.CellAttrs
---@field fg? integer
---@field bg? integer
---@field sp? integer
---@field bold? boolean
---@field italic? boolean
---@field underline? boolean
---@field undercurl? boolean
---@field strikethrough? boolean
---@field reverse? boolean

---@class test.ScreenCell
---@field text string
---@field attrs test.CellAttrs

---@class test.ScreenCells
---@field cells test.ScreenCell[][]
---@field hls table<string, test.CellAttrs|vim.NIL>

local CELL_FLAGS = { "bold", "italic", "underline", "undercurl", "strikethrough", "reverse" }
local CELL_COLORS = { "fg", "bg", "sp" }

--- Child-side: the drawn cells of `count` rows from screen row `row` (as in
--- `M.screen_rows`) and the resolved highlights of `groups` (vim.NIL when
--- undefined). Without a UI the first `nvim__inspect_cell` call remaps the
--- attr table, so it is primed once and the screen redrawn before reading.
local SCREEN_CELLS_LUA = [[
local row, count, groups = ...
local first = row < 0 and vim.o.lines + row or row - 1
vim.api.nvim__inspect_cell(1, 0, 0)
vim.cmd("redraw!")
local cells = {}
for r = first, first + count - 1 do
	local line = {}
	for col = 0, vim.o.columns - 1 do
		local cell = vim.api.nvim__inspect_cell(1, r, col)
		local attrs = cell[2]
		attrs.fg, attrs.bg, attrs.sp = attrs.foreground, attrs.background, attrs.special
		attrs.foreground, attrs.background, attrs.special = nil, nil, nil
		table.insert(line, { text = cell[1], attrs = attrs })
	end
	table.insert(cells, line)
end
local hls = {}
for _, name in ipairs(groups) do
	hls[name] = vim.fn.hlexists(name) == 1 and vim.api.nvim_get_hl(0, { name = name, link = false }) or vim.NIL
end
return { cells = cells, hls = hls }]]

---@param mask string[]
---@param columns integer
local function check_width(mask, columns)
	for index, row in ipairs(mask) do
		local width = vim.fn.strchars(row)
		if width ~= columns then
			error(("mask row %d is %d cells wide, screen has %d columns"):format(index, width, columns), 0)
		end
	end
end

---@param mask string[]
---@param legend table<string, string>
local function check_letters(mask, legend)
	for index, row in ipairs(mask) do
		for _, letter in ipairs(vim.fn.split(row, [[\zs]])) do
			if not M.UNMASKED[letter] and not legend[letter] then
				error(("mask row %d: letter %s is not in the legend"):format(index, letter), 0)
			end
		end
	end
end

---@param hls table<string, test.CellAttrs|vim.NIL>
---@param legend table<string, string>
local function check_groups(hls, legend)
	for _, letter in ipairs(vim.tbl_keys(legend)) do
		if hls[legend[letter]] == vim.NIL then
			error(("legend %s: unknown highlight group [%s]"):format(letter, legend[letter]), 0)
		end
	end
end

--- Whether a drawn cell shows `hl`: colors only where `hl` sets them (missing
--- drawn colors are Normal's), flags always (absent = false).
---@param attrs test.CellAttrs
---@param hl test.CellAttrs
---@param normal test.CellAttrs
---@return boolean
local function cell_matches(attrs, hl, normal)
	for _, key in ipairs(CELL_COLORS) do
		if hl[key] and hl[key] ~= (attrs[key] or normal[key]) then
			return false
		end
	end
	for _, flag in ipairs(CELL_FLAGS) do
		if (hl[flag] or false) ~= (attrs[flag] or false) then
			return false
		end
	end
	return true
end

---@param cells test.ScreenCell[][]
---@param legend table<string, string>
---@param hls table<string, test.CellAttrs>
---@param normal test.CellAttrs
---@return string[] mask of the first matching letter per cell, `.` for Normal, else `?`
local function actual_mask(cells, legend, hls, normal)
	local letters = vim.tbl_keys(legend)
	table.sort(letters)
	local mask = {}
	for _, line in ipairs(cells) do
		local row = {}
		for _, cell in ipairs(line) do
			local found = vim.iter(letters):find(function(letter)
				return cell_matches(cell.attrs, hls[legend[letter]], normal)
			end)
			table.insert(row, found or (cell_matches(cell.attrs, normal, normal) and ".") or "?")
		end
		table.insert(mask, table.concat(row))
	end
	return mask
end

---@param attrs test.CellAttrs
---@return string
local function format_attrs(attrs)
	local parts = {}
	for _, key in ipairs(CELL_COLORS) do
		if attrs[key] then
			table.insert(parts, ("%s=#%06x"):format(key, attrs[key]))
		end
	end
	for _, flag in ipairs(CELL_FLAGS) do
		if attrs[flag] then
			table.insert(parts, flag)
		end
	end
	return "{ " .. table.concat(parts, " ") .. " }"
end

---@class test.CellMismatch
---@field row integer 1-based index into the mask
---@field col integer 1-based column
---@field letter string
---@field group string

---@param cells test.ScreenCell[][]
---@param mask string[]
---@param groups table<string, string> mask letter (and unmasked) -> group
---@param hls table<string, test.CellAttrs>
---@return test.CellMismatch?
local function first_mismatch(cells, mask, groups, hls)
	local normal = hls[M.DEFAULT_GROUP]
	for row, line in ipairs(cells) do
		local letters = vim.fn.split(mask[row], [[\zs]])
		for col, cell in ipairs(line) do
			local group = groups[letters[col]]
			if not cell_matches(cell.attrs, hls[group], normal) then
				return { row = row, col = col, letter = letters[col], group = group }
			end
		end
	end
end

---@param mask string[]
---@param actual string[]
---@param cells test.ScreenCell[][]
---@param hls table<string, test.CellAttrs>
---@param bad test.CellMismatch
---@return string
local function mismatch_message(mask, actual, cells, hls, bad)
	local lines = { "screen colors differ from the mask:" }
	for row in ipairs(mask) do
		table.insert(lines, "expected: " .. mask[row])
		table.insert(lines, "actual:   " .. actual[row])
	end
	local cell = cells[bad.row][bad.col]
	table.insert(
		lines,
		('mask row %d, column %d "%s": expected %s [%s] %s, drawn %s'):format(
			bad.row,
			bad.col,
			cell.text,
			bad.letter,
			bad.group,
			format_attrs(hls[bad.group]),
			format_attrs(cell.attrs)
		)
	)
	return table.concat(lines, "\n")
end

---@param legend table<string, string>
---@return string[] legend groups plus `M.DEFAULT_GROUP`, once each
local function legend_groups(legend)
	local groups = { [M.DEFAULT_GROUP] = true }
	for _, group in pairs(legend) do
		groups[group] = true
	end
	return vim.tbl_keys(groups)
end

--- Assert the drawn colors of screen rows `row ..` against a design-render
--- mask (one string per row, `columns` cells) and legend (letter -> group).
--- `.` and space are `M.DEFAULT_GROUP`.
---@param child MiniTest.child
---@param row integer as in `M.screen_rows` (negative counts from the bottom)
---@param mask string[]
---@param legend table<string, string>
function M.expect_screen_colors(child, row, mask, legend)
	check_width(mask, child.o.columns)
	check_letters(mask, legend)
	local screen = child.lua(SCREEN_CELLS_LUA, { row, #mask, legend_groups(legend) }) --[[@as test.ScreenCells]]
	check_groups(screen.hls, legend)
	local hls = screen.hls --[[@as table<string, test.CellAttrs>]]
	if hls[M.DEFAULT_GROUP] == vim.NIL then
		hls[M.DEFAULT_GROUP] = {}
	end
	local letter_groups = vim.tbl_extend("force", { ["."] = M.DEFAULT_GROUP, [" "] = M.DEFAULT_GROUP }, legend)
	local bad = first_mismatch(screen.cells, mask, letter_groups, hls)
	if bad then
		local actual = actual_mask(screen.cells, legend, hls, hls[M.DEFAULT_GROUP])
		error(mismatch_message(mask, actual, screen.cells, hls, bad), 0)
	end
end

---@class test.HlColors
---@field fg? string `#rrggbb`
---@field bg? string `#rrggbb`
---@field bold? boolean

---@param hl test.CellAttrs
---@return test.HlColors
local function hl_colors(hl)
	---@param color integer?
	local function hex(color)
		return color and ("#%06x"):format(color)
	end
	return { fg = hex(hl.fg), bg = hex(hl.bg), bold = hl.bold or false }
end

--- Pin the resolved colors of highlight `group`: only the keys `expected` sets.
--- Masks compare cells with their own group, so this is what catches a wrong
--- palette color.
---@param child MiniTest.child
---@param group string
---@param expected test.HlColors
function M.expect_hl_colors(child, group, expected)
	local hl = child.lua_get("vim.api.nvim_get_hl(0, { name = ..., link = false })", { group }) --[[@as test.CellAttrs]]
	local actual = hl_colors(hl)
	for key, value in pairs(expected) do
		if actual[key] ~= value then
			error(("[%s] %s: expected %s, got %s"):format(group, key, tostring(value), tostring(actual[key])), 0)
		end
	end
end

--- `expect.reference_screenshot` that honours UPDATE_SCREENSHOTS=1.
---@param screenshot table
function M.expect_screenshot(screenshot)
	MiniTest.expect.reference_screenshot(screenshot, nil, { force = vim.env.UPDATE_SCREENSHOTS == "1" })
end

return M

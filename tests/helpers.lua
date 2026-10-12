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

---@class test.Colors
---@field fg? string "#rrggbb"
---@field bg? string "#rrggbb"
---@field bold? boolean
---@field italic? boolean

--- Child-side: the combined highlight of the statusline segment that holds
--- the first occurrence of the text given as first argument (vim.NIL when the
--- text is not in the statusline). Groups stack like Neovim draws them
--- (StatusLine, then the segment's group), resolved through links.
local STATUSLINE_HL_LUA = [[
local status = vim.api.nvim_eval_statusline(vim.o.statusline, { highlights = true })
local start = status.str:find(..., 1, true)
if not start then return vim.NIL end
local groups = {}
for _, segment in ipairs(status.highlights) do
	if segment.start < start then groups = segment.groups end
end
local combined = {}
for _, group in ipairs(groups) do
	combined = vim.tbl_extend("force", combined, vim.api.nvim_get_hl(0, { name = group, link = false }))
end
return combined]]

---@param color? integer
---@return string?
local function hex(color)
	return color and ("#%06x"):format(color)
end

--- Colors of the statusline segment that shows `text`, so screen tests catch
--- color regressions that the attribute-identity screenshots cannot.
---@param child MiniTest.child
---@param text string
---@return test.Colors?
function M.statusline_colors(child, text)
	local hl = child.lua(STATUSLINE_HL_LUA, { text })
	if hl == vim.NIL then
		return nil
	end
	return { fg = hex(hl.fg), bg = hex(hl.bg), bold = hl.bold or false, italic = hl.italic or false }
end

--- Assert the given fields of `expected` (others are ignored).
---@param actual? test.Colors
---@param expected test.Colors
function M.expect_colors(actual, expected)
	local subset = {}
	for key in pairs(expected) do
		subset[key] = (actual or {})[key]
	end
	MiniTest.expect.equality(subset, expected)
end

--- `expect.reference_screenshot` that honours UPDATE_SCREENSHOTS=1.
---@param screenshot table
function M.expect_screenshot(screenshot)
	MiniTest.expect.reference_screenshot(screenshot, nil, { force = vim.env.UPDATE_SCREENSHOTS == "1" })
end

return M

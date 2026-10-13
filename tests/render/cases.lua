-- Render cases for `make render CASE=<name>` and the highlight priming of
-- `make colorize`. Add a case: one entry with a description and a setup that
-- drives a full-config Neovim through the render.Driver interface (a mini.test
-- child in MONO=1 mode, an RPC connection to the Neovim inside tmux otherwise).

local H = require("tests.helpers")

---@class render.Driver
---@field lua fun(code: string, args?: any[]): any Run Lua in the Neovim and return its result.
---@field cmd fun(command: string) Run an Ex command.
---@field type_keys fun(keys: string) Feed keys as typed (nvim_input).
---@field wait fun(expr: string, timeout?: integer): boolean Wait until Lua `expr` is truthy.

---@class render.Case
---@field description string
---@field setup fun(driver: render.Driver)

--- Startup screen: alpha dashboard of a bare `nvim`.
---@param _ render.Driver
local function dashboard(_) end

--- A small Lua file in Normal mode (no LSP, outside git): buffer, bufferline, statusline.
---@param driver render.Driver
local function lua_file(driver)
	driver.lua([[vim.lsp.enable("lua_ls", false)]])
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	vim.fn.writefile(
		{ "local M = {}", "", "function M.hello()", '  return "world"', "end", "", "return M" },
		dir .. "/sample.lua"
	)
	driver.cmd("cd " .. dir .. " | edit sample.lua")
	driver.wait([[vim.bo.filetype == "lua"]])
end

--- Neo-tree filesystem tree of this checkout next to an empty buffer.
---@param driver render.Driver
local function neo_tree(driver)
	driver.cmd("cd " .. H.root .. " | enew | Neotree filesystem")
	driver.wait([[vim.bo.filetype == "neo-tree"]], 3000)
end

--- `<C-q>` on `sample.lua` shown in two `:vsplit` windows, `init.lua` the other listed buffer (no LSP).
---@param driver render.Driver
local function close_buffer_split(driver)
	driver.lua([[vim.lsp.enable("lua_ls", false)]])
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	vim.fn.writefile({ 'require("sample")' }, dir .. "/init.lua")
	vim.fn.writefile({ "local M = {}", "", "return M" }, dir .. "/sample.lua")
	driver.cmd("cd " .. dir .. " | edit init.lua | edit sample.lua | vsplit")
	driver.wait([[vim.bo.filetype == "lua"]])
	driver.type_keys("<C-q>")
	driver.wait([[vim.iter(vim.api.nvim_tabpage_list_wins(0)):all(function(win)
		return vim.fs.basename(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))) ~= "sample.lua"
	end)]])
end

---@type table<string, render.Case>
return {
	dashboard = { description = "alpha dashboard of a bare nvim", setup = dashboard },
	["lua-file"] = { description = "small Lua file, Normal mode, no LSP, outside git", setup = lua_file },
	["close-buffer-split"] = {
		description = "<C-q> on a buffer shown in two vsplit windows",
		setup = close_buffer_split,
	},
	["neo-tree"] = { description = "neo-tree filesystem tree of this checkout", setup = neo_tree },
}

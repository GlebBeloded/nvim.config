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

--- Run git in `dir` with a fixed identity and no hooks or signing.
---@param dir string
---@param args string[]
local function git(dir, args)
	local cmd = {
		"git",
		"-C",
		dir,
		"-c",
		"user.name=test",
		"-c",
		"user.email=test@example.com",
		"-c",
		"commit.gpgsign=false",
		"-c",
		"core.hooksPath=/dev/null",
	}
	local result = vim.system(vim.list_extend(cmd, args)):wait()
	assert(result.code == 0, result.stderr)
end

--- Temp git repo with `sample.lua` committed and line 2 added in the working copy.
---@return string dir
local function make_hunk_repo()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local file = dir .. "/sample.lua"
	vim.fn.writefile({ "local M = {}", "", "return M" }, file)
	git(dir, { "init", "--quiet" })
	git(dir, { "add", "sample.lua" })
	git(dir, { "commit", "--quiet", "-m", "sample" })
	vim.fn.writefile({ "local M = {}", "M.x = 1", "", "return M" }, file)
	return dir
end

--- Lua run in the Neovim: whether a gitsigns sign extmark exists on line 2.
local GITSIGNS_LINE2_LUA = [[(function()
	for name, ns in pairs(vim.api.nvim_get_namespaces()) do
		if name:find("^gitsigns_signs_") and #vim.api.nvim_buf_get_extmarks(0, ns, { 1, 0 }, { 1, -1 }, {}) > 0 then
			return true
		end
	end
	return false
end)()]]

--- `sample.lua` in a temp git repo with an added, uncommitted line 2 (no LSP).
---@param driver render.Driver
local function git_hunk(driver)
	driver.lua([[vim.lsp.enable("lua_ls", false)]])
	driver.cmd("cd " .. make_hunk_repo() .. " | edit sample.lua")
	assert(driver.wait(GITSIGNS_LINE2_LUA, 3000), "no gitsigns sign on line 2")
end

---@type table<string, render.Case>
return {
	dashboard = { description = "alpha dashboard of a bare nvim", setup = dashboard },
	["git-hunk"] = { description = "sample.lua in a temp git repo, added line 2, no LSP", setup = git_hunk },
	["lua-file"] = { description = "small Lua file, Normal mode, no LSP, outside git", setup = lua_file },
	["neo-tree"] = { description = "neo-tree filesystem tree of this checkout", setup = neo_tree },
}

-- Render cases for `make render CASE=<name>` and the highlight priming of
-- `make colorize`. Add a case: one entry with a description and a setup that
-- drives a full-config Neovim through the render.Driver interface (a mini.test
-- child in MONO=1 mode, an RPC connection to the Neovim inside tmux otherwise).

local H = require("tests.helpers")
local F = require("tests.fixtures")

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

--- TypeScript class usages grouped by their query-backed usage types.
---@param driver render.Driver
local function ts_p1_class(driver)
	local root, manifest = F.copy("tsproj", vim.fn.tempname())
	local declaration = manifest.references.Money[1]
	driver.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(declaration.path))
	driver.lua([[
vim.wo.number = true
vim.wo.relativenumber = false
vim.wo.numberwidth = 3
require("ibl").setup_buffer(0, { enabled = false })
vim.o.showtabline = 0
vim.o.laststatus = 2
vim.wo.winbar = "%#Normal#▎ money.ts"
]])
	driver.lua([[vim.api.nvim_win_set_cursor(0, ...)]], { { declaration.line, declaration.col - 1 } })
	assert(driver.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "vtsls" }) > 0]], H.lsp_timeout(10000)))
	driver.lua(
		[[
		local minimum, timeout = ...
_G.references_ready = nil
local bufnr = vim.api.nvim_get_current_buf()
local started = vim.uv.hrtime()
local populated = 0
local function request()
	local client = vim.lsp.get_clients({ bufnr = bufnr, name = "vtsls" })[1]
	local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
	params.context = { includeDeclaration = false }
	client:request("textDocument/references", params, function(_, result)
		populated = result and #result >= minimum and populated + 1 or 0
		if populated >= 2 then
			_G.references_ready = true
		elseif (vim.uv.hrtime() - started) / 1e6 < timeout then
			vim.defer_fn(request, 10)
		end
	end, bufnr)
end
request()
]],
		{ #manifest.references.Money - 1, H.lsp_timeout(10000) }
	)
	assert(driver.wait("_G.references_ready == true", H.lsp_timeout(10000)))
	driver.type_keys("gr")
	assert(driver.wait([[vim.bo.filetype == "gleb-references"]], H.lsp_timeout(10000)))
	assert(driver.wait([[not require("gleb.references.view").state.classifying]], H.lsp_timeout(10000)))
	driver.lua([[
local state = require("gleb.references.view").state
for index, node in ipairs(state.visible_nodes) do
	if node.kind == "usage" then
		vim.api.nvim_win_set_cursor(state.tree_win, { index, 0 })
		break
	end
end
local win = state.origin_win
require("lualine").hide({ place = { "statusline" } })
vim.o.statusline = "%#Normal# NORMAL  ⎇ main%=typescript "
vim.wo[win].statusline = "%#Normal# NORMAL  ⎇ main%=typescript "
]])
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
	["close-buffer-split"] = {
		description = "<C-q> on a buffer shown in two vsplit windows",
		setup = close_buffer_split,
	},
	["neo-tree"] = { description = "neo-tree filesystem tree of this checkout", setup = neo_tree },
	["ts_p1_class"] = { description = "TypeScript class usages grouped by usage type", setup = ts_p1_class },
}

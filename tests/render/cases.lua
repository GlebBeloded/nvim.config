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

--- Approved project-tree render on the populated billing fixture.
---@param driver render.Driver
local function project_tree(driver)
	local home = vim.fn.tempname()
	local root = F.copy("treeproj", vim.fs.joinpath(home, "work", "billing"))
	vim.fn.delete(vim.fs.joinpath(root, "bin"), "rf")
	vim.fn.delete(vim.fs.joinpath(root, "web", "node_modules"), "rf")
	vim.fn.delete(vim.fs.joinpath(root, ".env"))
	driver.lua(
		[[
		vim.env.HOME = ...
		vim.lsp.enable("gopls", false)
		require("null-ls").disable({})
		vim.diagnostic.enable(false)
	]],
		{ home }
	)
	driver.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit internal/billing/invoice.go")
	assert(driver.wait([[vim.b.gitsigns_head == "main"]], 5000), "gitsigns branch did not load")
	driver.lua([[
		local action = assert(require("gleb.actions").state.applicator.catalog:get("file_tree.toggle"))
		action.run(require("gleb.actions.context").capture())
	]])
	assert(
		driver.wait(
			[[(function()
		local view = require("gleb.file_tree.view").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return view and next(require("gleb.file_tree.git").status(view.root)) ~= nil
	end)()]],
			5000
		),
		"project-tree git status did not load"
	)
	for _, name in ipairs({ "cmd/server", "web", "src" }) do
		driver.lua(
			[[
			for row, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
				if line:find(..., 1, true) then
					vim.api.nvim_win_set_cursor(0, { row, 0 })
					return
				end
			end
		]],
			{ name }
		)
		driver.type_keys("<CR>")
	end
	driver.lua([[vim.fn.search("invoice.go", "w")]])
end

--- Owned aligned diff of the changed Go controller fixture.
---@param driver render.Driver
local function diff_view(driver)
	local root, manifest = F.copy("diffgo", vim.fn.tempname())
	driver.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(manifest.controller))
	driver.lua([[
vim.bo.tabstop = 4
require("ibl").setup_buffer(0, { enabled = false })
local actions = require("gleb.actions")
local action = assert(actions.state.applicator.catalog:get("diff.open_file"))
assert(require("gleb.actions.context").execute(action, require("gleb.actions.context").capture()))
]])
	assert(driver.wait([[require("gleb.diff.view").current() ~= nil]]))
end

--- Owned aligned diff after staging the changed return line.
---@param driver render.Driver
local function diff_view_staged(driver)
	diff_view(driver)
	driver.lua([[
local view = assert(require("gleb.diff.view").current())
vim.api.nvim_set_current_win(view.right_win)
vim.api.nvim_win_set_cursor(view.right_win, { 53, 0 })
]])
	driver.type_keys("<Space>")
	assert(driver.wait([[(function()
		for _, row in ipairs(require("gleb.diff.view").current().layout.rows) do
			if row.right == 53 and row.first then return row.checkbox == "󰄲" end
		end
		return false
	end)()]]))
end

--- Owned aligned diff of a moved Go block, focused on its new first line.
---@param driver render.Driver
local function diff_view_moved(driver)
	local root, manifest = F.copy("diffgo", vim.fn.tempname())
	driver.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(manifest.ids))
	driver.lua([[
vim.bo.tabstop = 4
require("ibl").setup_buffer(0, { enabled = false })
local actions = require("gleb.actions")
local action = assert(actions.state.applicator.catalog:get("diff.open_file"))
assert(require("gleb.actions.context").execute(action, require("gleb.actions.context").capture()))
]])
	assert(driver.wait([[require("gleb.diff.view").current() ~= nil]]))
	driver.lua([[
local view = assert(require("gleb.diff.view").current())
vim.api.nvim_set_current_win(view.right_win)
vim.api.nvim_win_set_cursor(view.right_win, { 11, 0 })
]])
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

--- Python class usages grouped by their query-backed usage types.
---@param driver render.Driver
local function py_p1_class(driver)
	local root, manifest = F.copy("pyproj", vim.fn.tempname())
	local declaration = manifest.references.Money[1]
	driver.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(declaration.path))
	driver.lua([[
vim.wo.number = true
vim.wo.relativenumber = false
vim.wo.numberwidth = 3
require("ibl").setup_buffer(0, { enabled = false })
vim.o.showtabline = 0
vim.o.laststatus = 2
vim.wo.winbar = "%#Normal#▎ money.py"
]])
	driver.lua([[vim.api.nvim_win_set_cursor(0, ...)]], { { declaration.line, declaration.col - 1 } })
	assert(driver.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "basedpyright" }) > 0]], H.lsp_timeout(10000)))
	driver.lua(
		[[
		local minimum, timeout = ...
_G.references_ready = nil
local bufnr = vim.api.nvim_get_current_buf()
local started = vim.uv.hrtime()
local populated = 0
local function request()
	local client = vim.lsp.get_clients({ bufnr = bufnr, name = "basedpyright" })[1]
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
vim.o.statusline = "%#Normal# NORMAL  ⎇ main%=python "
vim.wo[win].statusline = "%#Normal# NORMAL  ⎇ main%=python "
]])
end

--- Lua function usages grouped as calls and a function declaration.
---@param driver render.Driver
local function lua_l1_apply(driver)
	local root, manifest = F.copy("luaproj", vim.fn.tempname())
	local declaration = manifest.references.apply[1]
	driver.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(declaration.path))
	driver.lua([[
vim.wo.number = true
vim.wo.relativenumber = false
vim.wo.numberwidth = 3
require("ibl").setup_buffer(0, { enabled = false })
vim.o.showtabline = 0
vim.o.laststatus = 2
vim.wo.winbar = "%#Normal#▎ discount.lua"
]])
	driver.lua([[vim.api.nvim_win_set_cursor(0, ...)]], { { declaration.line, declaration.col - 1 } })
	assert(driver.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "lua_ls" }) > 0]], H.lsp_timeout(10000)))
	driver.lua([[vim.diagnostic.enable(false, { bufnr = 0 })]])
	driver.lua(
		[[
		local minimum, timeout = ...
_G.references_ready = nil
local bufnr = vim.api.nvim_get_current_buf()
local started = vim.uv.hrtime()
local populated = 0
local function request()
	local client = vim.lsp.get_clients({ bufnr = bufnr, name = "lua_ls" })[1]
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
		{ #manifest.references.apply - 2, H.lsp_timeout(10000) }
	)
	assert(driver.wait("_G.references_ready == true", H.lsp_timeout(10000)))
	driver.type_keys("gr")
	assert(driver.wait([[vim.bo.filetype == "gleb-references"]], H.lsp_timeout(10000)))
	assert(driver.wait([[not require("gleb.references.view").state.classifying]], H.lsp_timeout(10000)))
	driver.lua([[
local state = require("gleb.references.view").state
local origin_buf = vim.api.nvim_win_get_buf(state.origin_win)
vim.api.nvim_buf_set_lines(origin_buf, -1, -1, false, {
	"", "", "", "", "", "", "", "", "",
})
require("gitsigns").detach(origin_buf)
vim.wo[state.origin_win].signcolumn = "yes:1"
for index, node in ipairs(state.visible_nodes) do
	if node.kind == "usage" then
		vim.api.nvim_win_set_cursor(state.tree_win, { index, 0 })
		break
	end
end
local win = state.origin_win
require("lualine").hide({ place = { "statusline" } })
vim.o.statusline = "%#Normal# NORMAL  ⎇ main%=lua "
vim.wo[win].statusline = "%#Normal# NORMAL  ⎇ main%=lua "
]])
end

--- Bash variable usages grouped as export, read and write.
---@param driver render.Driver
local function bash_b1_rate(driver)
	local root, manifest = F.copy("bashproj", vim.fn.tempname())
	local declaration = manifest.references.rate[1]
	driver.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(declaration.path))
	driver.lua([[
vim.wo.number = true
vim.wo.relativenumber = false
vim.wo.numberwidth = 3
require("ibl").setup_buffer(0, { enabled = false })
vim.o.showtabline = 0
vim.o.laststatus = 2
vim.wo.winbar = "%#Normal#▎ tax.sh"
]])
	driver.lua([[vim.api.nvim_win_set_cursor(0, ...)]], { { declaration.line, declaration.col - 1 } })
	assert(driver.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "bashls" }) > 0]], H.lsp_timeout(10000)))
	driver.lua(
		[[
		local minimum, timeout = ...
_G.references_ready = nil
local bufnr = vim.api.nvim_get_current_buf()
local started = vim.uv.hrtime()
local populated = 0
local function request()
	local client = vim.lsp.get_clients({ bufnr = bufnr, name = "bashls" })[1]
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
		{ #manifest.references.rate - 1, H.lsp_timeout(10000) }
	)
	assert(driver.wait("_G.references_ready == true", H.lsp_timeout(10000)))
	driver.type_keys("gr")
	assert(driver.wait([[vim.bo.filetype == "gleb-references"]], H.lsp_timeout(10000)))
	assert(driver.wait([[not require("gleb.references.view").state.classifying]], H.lsp_timeout(10000)))
	driver.lua([[
local state = require("gleb.references.view").state
local origin_buf = vim.api.nvim_win_get_buf(state.origin_win)
vim.api.nvim_buf_set_lines(origin_buf, 5, 6, false, { "" })
vim.api.nvim_buf_set_lines(origin_buf, -1, -1, false, {
	"", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
})
require("gitsigns").detach(origin_buf)
vim.wo[state.origin_win].signcolumn = "yes:1"
for index, node in ipairs(state.visible_nodes) do
	if node.kind == "usage" then
		vim.api.nvim_win_set_cursor(state.tree_win, { index, 0 })
		break
	end
end
local win = state.origin_win
require("lualine").hide({ place = { "statusline" } })
vim.o.statusline = "%#Normal# NORMAL  ⎇ main%=sh "
vim.wo[win].statusline = "%#Normal# NORMAL  ⎇ main%=sh "
	]])
end

--- Terraform module usages grouped as dependency, module reference and output value.
---@param driver render.Driver
local function terraform_h1_vpc(driver)
	local root, manifest = F.copy("tfproj", vim.fn.tempname())
	local declaration = manifest.references.vpc[1]
	driver.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(declaration.path))
	driver.lua([[
vim.wo.number = true
vim.wo.relativenumber = false
vim.wo.numberwidth = 3
require("ibl").setup_buffer(0, { enabled = false })
vim.o.showtabline = 0
vim.o.laststatus = 2
vim.wo.winbar = "%#Normal#▎ network.tf"
]])
	driver.lua([[vim.api.nvim_win_set_cursor(0, ...)]], { { declaration.line, declaration.col - 1 } })
	assert(driver.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "terraformls" }) > 0]], H.lsp_timeout(10000)))
	driver.lua([[vim.diagnostic.enable(false, { bufnr = 0 })]])
	driver.lua(
		[[
		local minimum, timeout = ...
_G.references_ready = nil
local bufnr = vim.api.nvim_get_current_buf()
local started = vim.uv.hrtime()
local populated = 0
local function request()
	local client = vim.lsp.get_clients({ bufnr = bufnr, name = "terraformls" })[1]
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
		{ #manifest.references.vpc - 1, H.lsp_timeout(10000) }
	)
	assert(driver.wait("_G.references_ready == true", H.lsp_timeout(10000)))
	driver.type_keys("gr")
	assert(driver.wait([[vim.bo.filetype == "gleb-references"]], H.lsp_timeout(10000)))
	assert(driver.wait([[not require("gleb.references.view").state.classifying]], H.lsp_timeout(10000)))
	driver.lua([[
local state = require("gleb.references.view").state
local origin_buf = vim.api.nvim_win_get_buf(state.origin_win)
vim.lsp.codelens.clear(nil, origin_buf)
require("gitsigns").detach(origin_buf)
vim.wo[state.origin_win].signcolumn = "yes:1"
for index, node in ipairs(state.visible_nodes) do
	if node.kind == "usage" then
		vim.api.nvim_win_set_cursor(state.tree_win, { index, 0 })
		break
	end
end
local win = state.origin_win
require("lualine").hide({ place = { "statusline" } })
vim.o.statusline = "%#Normal# NORMAL  ⎇ main%=terraform "
vim.wo[win].statusline = "%#Normal# NORMAL  ⎇ main%=terraform "
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
	["diff-view"] = { description = "aligned diff of the changed Go controller fixture", setup = diff_view },
	["diff-view-staged"] = { description = "aligned diff with its first change staged", setup = diff_view_staged },
	["diff-view-moved"] = { description = "aligned diff of a moved Go block", setup = diff_view_moved },
	["git-hunk"] = { description = "sample.lua in a temp git repo, added line 2, no LSP", setup = git_hunk },
	["lua-file"] = { description = "small Lua file, Normal mode, no LSP, outside git", setup = lua_file },
	["close-buffer-split"] = {
		description = "<C-q> on a buffer shown in two vsplit windows",
		setup = close_buffer_split,
	},
	["neo-tree"] = { description = "neo-tree filesystem tree of this checkout", setup = neo_tree },
	["f1-proposed"] = { description = "approved project-tree render", setup = project_tree },
	["lua_l1_apply"] = { description = "Lua function usages grouped by usage type", setup = lua_l1_apply },
	["bash_b1_rate"] = { description = "Bash variable usages grouped by usage type", setup = bash_b1_rate },
	["terraform_h1_vpc"] = { description = "Terraform module usages grouped by usage type", setup = terraform_h1_vpc },
	["py_p1_class"] = { description = "Python class usages grouped by usage type", setup = py_p1_class },
	["ts_p1_class"] = { description = "TypeScript class usages grouped by usage type", setup = ts_p1_class },
}

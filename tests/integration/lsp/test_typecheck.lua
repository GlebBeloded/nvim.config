local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()
local TIMEOUT_MS = H.lsp_timeout(10000)
local LOAD_FACTOR = H.load_factor()
local ATTACHMENT_TIMEOUT_MS = math.ceil(TIMEOUT_MS * LOAD_FACTOR)
local attachment_deadlines = {}

local function start()
	child.start_config()
	child.wait_very_lazy()
end

local function basedpyright_attached(bufnr)
	return child.wait(
		([[#vim.lsp.get_clients({ bufnr = %d, name = "basedpyright" }) > 0]]):format(bufnr),
		ATTACHMENT_TIMEOUT_MS
	)
end

local function basedpyright_mode(bufnrs, mode)
	table.insert(attachment_deadlines, ATTACHMENT_TIMEOUT_MS)
	return child.wait(
		([[vim.iter({ %s }):all(function(bufnr)
		local client = vim.lsp.get_clients({ bufnr = bufnr, name = "basedpyright" })[1]
		return client and client.config.settings.basedpyright.analysis.typeCheckingMode == %q
	end)]]):format(table.concat(bufnrs, ", "), mode),
		ATTACHMENT_TIMEOUT_MS
	)
end

local T = H.child_set(child, start)

T["lsp: Type-check toggle reattaches every Python buffer without reloading"] = function()
	local dir = H.tempdir(child)
	local first = vim.fs.joinpath(dir, "first.py")
	local second = vim.fs.joinpath(dir, "second.py")
	vim.fn.writefile({ "first: int = 1" }, first)
	vim.fn.writefile({ "second: int = 2" }, second)
	vim.fn.writefile(
		{ "[project]", 'name = "typecheck-toggle"', 'version = "0.1.0"' },
		vim.fs.joinpath(dir, "pyproject.toml")
	)

	child.cmd("edit " .. vim.fn.fnameescape(first))
	local first_buf = child.api.nvim_get_current_buf()
	eq(basedpyright_attached(first_buf), true)

	child.cmd("edit " .. vim.fn.fnameescape(second))
	local second_buf = child.api.nvim_get_current_buf()
	eq(basedpyright_attached(second_buf), true)
	child.lua([[require("auto-save").off()]])
	child.api.nvim_buf_set_lines(second_buf, 0, -1, false, { "second: int = 3" })

	child.lua([[_G.typecheck_ok, _G.typecheck_err = pcall(vim.cmd, "PyTypeCheckOn")]])
	local result = child.lua_get([[{ ok = _G.typecheck_ok, err = _G.typecheck_err }]])
	eq(result.ok, true)
	eq(child.bo.modified, true)
	eq(basedpyright_mode({ first_buf, second_buf }, "basic"), true)
	eq(attachment_deadlines, { math.ceil(TIMEOUT_MS * LOAD_FACTOR) })
end

return T

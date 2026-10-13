local MiniTest = require("mini.test")
local H = require("tests.helpers")

local child = H.new_child()

---@type integer Bound from `:edit` to the first non-error documentSymbol answer.
local BOUND_MS = 1000

---@type integer How long to wait for the answer before failing.
local TIMEOUT_MS = 10000

local function start()
	child.start_config()
	child.wait_very_lazy()
end

--- Child-side: start the clock, `:edit` the file and send documentSymbol to the
--- named client until it answers without error; the elapsed ms land in
--- `_G.ready_ms` (or the last error in `_G.ready_err`).
local PROBE_LUA = [[
local file, server = ...
_G.ready_ms, _G.ready_err = nil, nil
local started = vim.uv.hrtime()
vim.cmd.edit(vim.fn.fnameescape(file))
local bufnr = vim.api.nvim_get_current_buf()

local function request()
	local client = vim.lsp.get_clients({ bufnr = bufnr, name = server })[1]
	if not client then
		return vim.defer_fn(request, 10)
	end
	local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
	client:request("textDocument/documentSymbol", params, function(err)
		if err then
			_G.ready_err = err.message
			return vim.defer_fn(request, 10)
		end
		_G.ready_ms = math.floor((vim.uv.hrtime() - started) / 1e6)
	end, bufnr)
end

request()]]

--- Relative path -> content, written into a fresh temp dir.
---@param files table<string, string>
---@return string dir
local function write_fixture(files)
	local dir = vim.fn.tempname()
	for path, content in pairs(files) do
		local file = vim.fs.joinpath(dir, path)
		vim.fn.mkdir(vim.fs.dirname(file), "p")
		vim.fn.writefile(vim.split(content, "\n"), file)
	end
	return dir
end

--- Ms from `:edit file` (cwd at `cwd`) to the first non-error documentSymbol
--- answer of `server` in the running full-config child.
---@param cwd string
---@param file string
---@param server string
---@return integer
local function ready_ms(cwd, file, server)
	local cmd = child.lua_get("(vim.lsp.config[...].cmd or {})[1]", { server })
	if type(cmd) ~= "string" or child.fn.executable(cmd) == 0 then
		error(("%s not executable"):format(tostring(cmd)), 0)
	end
	child.cmd("cd " .. vim.fn.fnameescape(cwd))
	local started = vim.uv.hrtime()
	child.lua(PROBE_LUA, { file, server })
	if not child.wait("_G.ready_ms ~= nil", TIMEOUT_MS) then
		local waited = math.floor((vim.uv.hrtime() - started) / 1e6)
		error(("%s not ready after %d ms (last error: %s)"):format(server, waited, child.lua_get("_G.ready_err")), 0)
	end
	return child.lua_get("_G.ready_ms")
end

--- Start the server once, so the measured run sees warm caches, then restart the child.
---@param cwd string
---@param file string
---@param server string
local function warm(cwd, file, server)
	ready_ms(cwd, file, server)
	start()
end

---@param cwd string
---@param file string
---@param server string
local function expect_ready(cwd, file, server)
	warm(cwd, file, server)
	local ms = ready_ms(cwd, file, server)
	if ms >= BOUND_MS then
		error(("%s ready after %d ms, bound %d ms"):format(server, ms, BOUND_MS), 0)
	end
	MiniTest.expect.equality(ms < BOUND_MS, true)
end

local T = H.child_set(child, start)

T["lsp: gopls ready within 1 s in a small module"] = function()
	local dir = write_fixture({
		["go.mod"] = "module example.com/ready\n\ngo 1.22",
		["greet/greet.go"] = 'package greet\n\nfunc Hello() string { return "hello" }',
		["main.go"] = table.concat({
			"package main",
			"",
			'import (\n\t"fmt"\n\n\t"example.com/ready/greet"\n)',
			"",
			"func main() { fmt.Println(greet.Hello()) }",
		}, "\n"),
	})
	expect_ready(dir, "main.go", "gopls")
end

T["lsp: basedpyright ready within 1 s in a small project"] = function()
	local dir = write_fixture({
		["pyproject.toml"] = '[project]\nname = "ready"',
		["ready.py"] = 'def hello() -> str:\n    return "hello"',
	})
	expect_ready(dir, "ready.py", "basedpyright")
end

T["lsp: vtsls ready within 1 s in a small project"] = function()
	local dir = write_fixture({
		["package.json"] = '{"name":"ready"}',
		["tsconfig.json"] = '{"compilerOptions":{"strict":true}}',
		["index.ts"] = 'export function hello(): string {\n  return "hello";\n}',
	})
	expect_ready(dir, "index.ts", "vtsls")
end

return T

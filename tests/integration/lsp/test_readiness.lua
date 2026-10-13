local MiniTest = require("mini.test")
local H = require("tests.helpers")

local child = H.new_child()

---@type integer How long to wait for the answer before failing.
local TIMEOUT_MS = 10000

local function start()
	child.start_config()
	child.wait_very_lazy()
end

--- Child-side: request the LuaLS hover for `vim.lsp.enable` and normalize its
--- markup into `_G.hover_text`.
local HOVER_LUA = [[
local file = ...
_G.hover_text, _G.hover_err = nil, nil
vim.cmd.edit(vim.fn.fnameescape(file))
local bufnr = vim.api.nvim_get_current_buf()
local row, column
for index, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
	local start = line:find("vim.lsp.enable", 1, true)
	if start then
		row = index
		column = start - 1 + #"vim.lsp."
		break
	end
end
assert(row and column, "vim.lsp.enable not found")
vim.api.nvim_win_set_cursor(0, { row, column })

local function request()
	local client = vim.lsp.get_clients({ bufnr = bufnr, name = "lua_ls" })[1]
	if not client then
		return vim.defer_fn(request, 10)
	end
	local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
	client:request("textDocument/hover", params, function(err, result)
		if err then
			_G.hover_err = err.message
			return
		end
		local contents = result and result.contents
		local lines = vim.lsp.util.convert_input_to_markdown_lines(contents or {})
		local text = table.concat(lines, "\n")
		if text:match("^Workspace loading:") then
			return vim.defer_fn(request, 100)
		end
		_G.hover_text = text
	end, bufnr)
end

request()]]

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
---@param bound_ms integer
---@return integer
local function ready_ms(cwd, file, server, bound_ms)
	local cmd = child.lua_get("(vim.lsp.config[...].cmd or {})[1]", { server })
	if type(cmd) ~= "string" or child.fn.executable(cmd) == 0 then
		error(("%s not executable"):format(tostring(cmd)), 0)
	end
	child.cmd("cd " .. vim.fn.fnameescape(cwd))
	local started = vim.uv.hrtime()
	child.lua(PROBE_LUA, { file, server })
	if not child.wait("_G.ready_ms ~= nil", TIMEOUT_MS) then
		local waited = math.floor((vim.uv.hrtime() - started) / 1e6)
		error(
			("%s not ready after %d ms, bound %d ms (last error: %s)"):format(
				server,
				waited,
				bound_ms,
				child.lua_get("_G.ready_err")
			),
			0
		)
	end
	return child.lua_get("_G.ready_ms")
end

--- Start the server once, so the measured run sees warm caches, then restart the child.
---@param cwd string
---@param file string
---@param server string
---@param bound_ms integer
local function warm(cwd, file, server, bound_ms)
	ready_ms(cwd, file, server, bound_ms)
	start()
end

---@param cwd string
---@param file string
---@param server string
---@param bound_ms integer
local function expect_ready(cwd, file, server, bound_ms)
	warm(cwd, file, server, bound_ms)
	local ms = ready_ms(cwd, file, server, bound_ms)
	if ms >= bound_ms then
		error(("%s ready after %d ms, bound %d ms"):format(server, ms, bound_ms), 0)
	end
	MiniTest.expect.equality(ms < bound_ms, true)
end

---@return string
local function hover_vim_lsp_enable()
	child.cmd("cd " .. vim.fn.fnameescape(H.root))
	child.lua(HOVER_LUA, { "lua/gleb/lsp/config/init.lua" })
	if not child.wait("_G.hover_text ~= nil or _G.hover_err ~= nil", TIMEOUT_MS) then
		error("lua_ls hover did not answer", 0)
	end
	local err = child.lua_get("_G.hover_err")
	if err ~= vim.NIL then
		error("lua_ls hover failed: " .. err, 0)
	end
	return child.lua_get("_G.hover_text")
end

local T = H.child_set(child, start)

T["lsp: lua_ls ready within 2.5 s in this config"] = function()
	expect_ready(H.root, "lua/gleb/lsp/config/init.lua", "lua_ls", 2500)
end

T["lsp: lua_ls exposes typed vim API signatures"] = function()
	local hover = hover_vim_lsp_enable()
	MiniTest.expect.equality(hover:find("function lsp%.enable%([^)]*name: [^,]+, [^)]*enable%?: [^)]*%)") ~= nil, true)
end

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
	expect_ready(dir, "main.go", "gopls", 1000)
end

T["lsp: basedpyright ready within 1 s in a small project"] = function()
	local dir = write_fixture({
		["pyproject.toml"] = '[project]\nname = "ready"',
		["ready.py"] = 'def hello() -> str:\n    return "hello"',
	})
	expect_ready(dir, "ready.py", "basedpyright", 1000)
end

T["lsp: vtsls ready within 1 s in a small project"] = function()
	local dir = write_fixture({
		["package.json"] = '{"name":"ready"}',
		["tsconfig.json"] = '{"compilerOptions":{"strict":true}}',
		["index.ts"] = 'export function hello(): string {\n  return "hello";\n}',
	})
	expect_ready(dir, "index.ts", "vtsls", 1000)
end

return T

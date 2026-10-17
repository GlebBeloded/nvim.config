local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()
local TIMEOUT_MS = H.lsp_timeout(15000)
local RUST_TIMEOUT_MS = H.lsp_timeout(30000)

local function start()
	child.start_config()
	child.wait_very_lazy()
end

local T = H.child_set(child, start)

local function run_go(root, args)
	local result = vim.system(args, { cwd = root, env = F.go_env(), text = true }):wait(300000)
	eq(result.code, 0)
	eq(result.stderr, "")
end

---@param server string
---@param command? string
local function require_server(server, command)
	command = command or child.lua_get("(vim.lsp.config[...].cmd or {})[1]", { server })
	if type(command) ~= "string" or child.fn.executable(command) == 0 then
		MiniTest.skip((command or server) .. " is not executable")
	end
end

---@param root string
---@param path string
---@param line integer
---@param col integer
---@param server string
---@param client_name? string
---@param timeout? integer
---@param minimum? integer
---@param collect_highlights? boolean
---@return table[]
local function classify(root, path, line, col, server, client_name, timeout, minimum, collect_highlights)
	client_name = client_name or server
	timeout = timeout or TIMEOUT_MS
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(path))
	child.api.nvim_win_set_cursor(0, { line, col - 1 })
	eq(child.wait(([[#vim.lsp.get_clients({ bufnr = 0, name = %q }) > 0]]):format(client_name), timeout), true)

	child.lua(
		[[
		local server, timeout, minimum, collect_highlights = ...
_G.usage_kinds, _G.usage_kind_error = nil, nil
local bufnr = vim.api.nvim_get_current_buf()
local client = vim.lsp.get_clients({ bufnr = bufnr, name = server })[1]
local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
params.context = { includeDeclaration = false }
local started = vim.uv.hrtime()
local function request()
	local method = collect_highlights and "textDocument/documentHighlight" or "textDocument/references"
	client:request(method, params, function(err, locations)
		if err then
			if err.message == "content modified" and (vim.uv.hrtime() - started) / 1e6 < timeout then
				vim.defer_fn(request, 10)
			else
				_G.usage_kind_error = err.message
			end
			return
		end
		locations = vim.tbl_filter(function(location)
			local start = location.range.start
			return not collect_highlights or start.line ~= params.position.line or start.character ~= params.position.character
		end, locations or {})
		if #locations < minimum then
			if (vim.uv.hrtime() - started) / 1e6 < timeout then
				vim.defer_fn(request, 10)
			end
			return
		end
		local cwd = vim.fn.getcwd()
		local usages = vim.tbl_map(function(location)
			location.uri = location.uri or params.textDocument.uri
			return {
				uri = location.uri,
				path = vim.fs.relpath(cwd, vim.uri_to_fname(location.uri)) or vim.uri_to_fname(location.uri),
				lnum = location.range.start.line + 1,
				col = location.range.start.character + 1,
				filetype = vim.filetype.match({ filename = vim.uri_to_fname(location.uri) }),
				range = location.range,
				client_id = client.id,
			}
		end, locations)
		require("gleb.references.kind").classify(usages, function(classified)
			_G.usage_kinds = vim.tbl_map(function(usage)
				return { usage.path, usage.lnum, usage.col, usage.kind }
			end, classified)
			table.sort(_G.usage_kinds, function(left, right)
				if left[1] ~= right[1] then return left[1] < right[1] end
				if left[2] ~= right[2] then return left[2] < right[2] end
				return left[3] < right[3]
			end)
		end)
	end, bufnr)
end
request()
]],
		{ client_name, timeout, minimum or 1, collect_highlights or false }
	)
	eq(child.wait("_G.usage_kinds ~= nil or _G.usage_kind_error ~= nil", timeout), true)
	eq(child.lua_get("_G.usage_kind_error"), vim.NIL)
	return child.lua_get("_G.usage_kinds")
end

local go_scenario = "references: gopls kinds classify a Go variable"
T[go_scenario] = MiniTest.new_set()
T[go_scenario]["fixture contains the exact usages"] = function()
	local root, manifest = F.copy("gomod", vim.fn.tempname())

	eq(vim.fn.readfile(root .. "/report/calls.go"), {
		"package report",
		"",
		"// Calls counts rendered summaries.",
		"var Calls int",
		"",
		"// Count records one rendered summary.",
		"func Count() {",
		"\tCalls++",
		"}",
	})
	eq(vim.fn.readfile(root .. "/report/calls_test.go"), {
		"package report",
		"",
		'import "testing"',
		"",
		"func TestCount(t *testing.T) {",
		"\tCalls = 0",
		"\tCount()",
		"\tif Calls != 1 {",
		'\t\tt.Fatalf("Calls = %d, want 1", Calls)',
		"\t}",
		"}",
	})
	eq(manifest.references.Calls, {
		{ path = "report/calls.go", line = 4, col = 5 },
		{ path = "report/calls.go", line = 8, col = 2 },
		{ path = "report/calls_test.go", line = 6, col = 2 },
		{ path = "report/calls_test.go", line = 8, col = 5 },
		{ path = "report/calls_test.go", line = 9, col = 34 },
	})
	eq(manifest.references.Format, {
		{ path = "internal/money/money.go", line = 6, col = 6 },
		{ path = "internal/money/money_test.go", line = 6, col = 12 },
		{ path = "billing/invoice.go", line = 16, col = 15 },
		{ path = "billing/invoice.go", line = 23, col = 31 },
		{ path = "report/summary.go", line = 7, col = 27 },
	})
	run_go(root, { "go", "build", "./..." })
	run_go(root, { "go", "vet", "./..." })
end
T[go_scenario]["classifies every usage"] = function()
	require_server("gopls")
	local root, manifest = F.copy("gomod", vim.fn.tempname())
	local declaration = manifest.references.Calls[1]
	eq(classify(root, declaration.path, declaration.line, declaration.col, "gopls"), {
		{ "report/calls.go", 8, 2, "write" },
		{ "report/calls_test.go", 6, 2, "write" },
		{ "report/calls_test.go", 8, 5, "read" },
		{ "report/calls_test.go", 9, 34, "read" },
	})
end

local lua_scenario = "references: lua_ls kinds classify a Lua local"
T[lua_scenario] = MiniTest.new_set()
T[lua_scenario]["classifies every usage"] = function()
	require_server("lua_ls")
	local root = H.git_repo({
		[".luarc.json"] = [[{"workspace":{"checkThirdParty":false}}]],
		["main.lua"] = "local count = 0\ncount = count + 1\nprint(count)\n",
	})
	eq(classify(root, "main.lua", 1, 7, "lua_ls", nil, nil, 3, true), {
		{ "main.lua", 2, 1, "write" },
		{ "main.lua", 2, 9, "read" },
		{ "main.lua", 3, 7, "read" },
	})
end

local python_scenario = "references: basedpyright kinds classify a Python variable"
T[python_scenario] = MiniTest.new_set()
T[python_scenario]["classifies every usage"] = function()
	require_server("basedpyright")
	local root = H.git_repo({
		["pyproject.toml"] = '[project]\nname = "usage-kinds"\nversion = "0.1.0"\n',
		["main.py"] = "total = 0\ntotal += 1\nprint(total)\n",
	})
	eq(classify(root, "main.py", 1, 1, "basedpyright"), {
		{ "main.py", 2, 1, "write" },
		{ "main.py", 3, 7, "read" },
	})
end

local typescript_scenario = "references: tsserver kinds classify a TypeScript variable"
T[typescript_scenario] = MiniTest.new_set()
T[typescript_scenario]["classifies every usage"] = function()
	require_server("vtsls")
	local root = H.git_repo({
		["package.json"] = [[{"private":true}]],
		["tsconfig.json"] = [[{"compilerOptions":{"strict":true}}]],
		["main.ts"] = "let hits = 0;\nhits++;\nconsole.log(hits);\n",
	})
	eq(classify(root, "main.ts", 1, 5, "vtsls"), {
		{ "main.ts", 2, 1, "write" },
		{ "main.ts", 3, 13, "read" },
	})
end

local rust_scenario = "references: rust-analyzer kinds classify a Rust variable"
T[rust_scenario] = MiniTest.new_set()
T[rust_scenario]["classifies every usage"] = function()
	require_server("rust_analyzer", "rust-analyzer")
	local root = H.git_repo({
		["Cargo.toml"] = '[package]\nname = "usage-kinds"\nversion = "0.1.0"\nedition = "2024"\n',
		["src/main.rs"] = 'fn main() { let mut n = 0;\n    n += 1;\n    println!("{n}");\n}\n',
	})
	eq(classify(root, "src/main.rs", 1, 21, "rust_analyzer", "rust-analyzer", RUST_TIMEOUT_MS, 2), {
		{ "src/main.rs", 2, 5, "write" },
		{ "src/main.rs", 3, 16, "read" },
	})
end

return T

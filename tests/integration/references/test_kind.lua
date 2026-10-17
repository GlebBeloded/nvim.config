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
	assert(type(command) == "string", server .. " has no configured command")
	assert(child.fn.executable(command) == 1, command .. " is not executable")
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

---@param root string
---@param path string
---@param line integer
---@param col integer
---@param server string
---@param client_name? string
---@param timeout? integer
---@param parser? string
---@param before_open? fun()
---@param minimum? integer
---@return table[]
local function open_references(root, path, line, col, server, client_name, timeout, parser, before_open, minimum)
	client_name = client_name or server
	timeout = timeout or TIMEOUT_MS
	require_server(server)
	if client_name == "rust-analyzer" then
		child.lua([[
			_G.rust_analyzer_quiescent = nil
			local server = require("rustaceanvim.config.internal").server
			server.handlers = server.handlers or {}
			_G.previous_server_status_handler = server.handlers["experimental/serverStatus"]
			server.handlers["experimental/serverStatus"] = function(err, result, context, config)
				if result and result.quiescent then _G.rust_analyzer_quiescent = true end
				local handler = _G.previous_server_status_handler or require("rustaceanvim.server_status").handler
				return handler(err, result, context, config)
			end
		]])
	end
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(path))
	child.api.nvim_win_set_cursor(0, { line, col - 1 })
	assert(
		child.wait(([[#vim.lsp.get_clients({ bufnr = 0, name = %q }) > 0]]):format(client_name), timeout),
		client_name .. " did not attach"
	)
	if client_name == "rust-analyzer" then
		assert(child.wait("_G.rust_analyzer_quiescent == true", timeout), "rust-analyzer did not become quiescent")
		child.lua([[
			require("rustaceanvim.config.internal").server.handlers["experimental/serverStatus"] =
				_G.previous_server_status_handler
			_G.previous_server_status_handler = nil
		]])
	end
	if before_open then
		before_open()
	end
	if parser then
		assert(
			child.lua_get(
				[[(function(language) local ok = pcall(vim.treesitter.get_parser, 0, language); return ok end)(...)]],
				{ parser }
			),
			parser .. " parser is not installed"
		)
	end
	child.lua(
		[[
		local server, timeout, minimum = ...
_G.references_ready = nil
local bufnr = vim.api.nvim_get_current_buf()
local started = vim.uv.hrtime()
local populated = 0
local function request()
	local client = vim.lsp.get_clients({ bufnr = bufnr, name = server })[1]
	local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
	params.context = { includeDeclaration = false }
	client:request("textDocument/references", params, function(_, result)
		if result and #result >= minimum then
			populated = populated + 1
		else
			populated = 0
		end
		if populated >= 2 then
			_G.references_ready = true
		elseif (vim.uv.hrtime() - started) / 1e6 < timeout then
			vim.defer_fn(request, 10)
		end
	end, bufnr)
end
request()
]],
		{ client_name, timeout, minimum or 1 }
	)
	assert(child.wait("_G.references_ready == true", timeout), "references did not become ready")

	child.type_keys("gr")
	assert(child.wait([[vim.bo.filetype == "gleb-references"]], timeout), "gr did not open the references view")
	assert(
		child.wait([[not require("gleb.references.view").state.classifying]], timeout),
		"usage classification did not finish"
	)

	return child.lua_get([[
(function()
	local state = require("gleb.references.view").state
	local rows = vim.api.nvim_buf_get_lines(state.tree_buf, 0, -1, false)
	local usages = {}
	for index, node in ipairs(state.visible_nodes) do
		assert(rows[index]:find(node.label, 1, true), "rendered row does not contain " .. node.label)
		if node.kind == "usage" then
			table.insert(usages, { node.path, node.lnum, node.col, node.usage_type })
		end
	end
	table.sort(usages, function(left, right)
		if left[1] ~= right[1] then return left[1] < right[1] end
		if left[2] ~= right[2] then return left[2] < right[2] end
		return left[3] < right[3]
	end)
	return usages
end)()
]])
end

local go_scenario = "references: gr classifies every Go variable usage"
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

local go_struct_scenario = "references: gr classifies struct usages"
T[go_struct_scenario] = MiniTest.new_set()
T[go_struct_scenario]["renders every struct usage type"] = function()
	local root, manifest = F.copy("gomod", vim.fn.tempname())
	local declaration = manifest.references.Invoice[1]
	local actual = open_references(root, declaration.path, declaration.line, declaration.col, "gopls", nil, nil, "go")
	eq(actual, {
		{ "billing/batch.go", 5, 10, "field_declaration" },
		{ "billing/batch.go", 6, 13, "field_declaration" },
		{ "billing/batch.go", 10, 29, "return_type" },
		{ "billing/batch.go", 11, 10, "struct_initialization" },
		{ "billing/batch.go", 15, 16, "parameter_declaration" },
		{ "billing/batch.go", 15, 38, "return_type" },
		{ "billing/invoice.go", 11, 9, "receiver" },
		{ "billing/invoice.go", 20, 9, "receiver" },
		{ "billing/invoice_test.go", 6, 9, "struct_initialization" },
	})
end

local go_function_scenario = "references: gr classifies function usages as calls"
T[go_function_scenario] = MiniTest.new_set()
T[go_function_scenario]["renders every function usage as a call"] = function()
	local root, manifest = F.copy("gomod", vim.fn.tempname())
	local declaration = manifest.references.Format[1]
	local actual = open_references(root, declaration.path, declaration.line, declaration.col, "gopls", nil, nil, "go")
	eq(actual, {
		{ "billing/invoice.go", 16, 15, "call" },
		{ "billing/invoice.go", 23, 31, "call" },
		{ "internal/money/money_test.go", 6, 12, "call" },
		{ "report/summary.go", 7, 27, "call" },
	})
end

local go_field_scenario = "references: Composite literal keys are field writes"
T[go_field_scenario] = MiniTest.new_set()
T[go_field_scenario]["renders every field read and write"] = function()
	local root = F.copy("gomod", vim.fn.tempname())
	local actual = open_references(root, "billing/invoice.go", 7, 2, "gopls", nil, nil, "go")
	eq(actual, {
		{ "billing/batch.go", 11, 18, "write" },
		{ "billing/batch.go", 16, 6, "write" },
		{ "billing/batch.go", 16, 25, "read" },
		{ "billing/invoice.go", 13, 26, "read" },
		{ "billing/invoice.go", 22, 26, "read" },
		{ "billing/invoice_test.go", 6, 17, "write" },
	})
end
T[go_scenario]["renders every usage kind"] = function()
	local root, manifest = F.copy("gomod", vim.fn.tempname())
	local declaration = manifest.references.Calls[1]
	local actual = open_references(root, declaration.path, declaration.line, declaration.col, "gopls", nil, nil, "go")
	eq(actual, {
		{ "report/calls.go", 8, 2, "write" },
		{ "report/calls_test.go", 6, 2, "write" },
		{ "report/calls_test.go", 8, 5, "read" },
		{ "report/calls_test.go", 9, 34, "read" },
	})
end

local go_direct_scenario = "references: gopls kinds classify a Go variable"
T[go_direct_scenario] = MiniTest.new_set()
T[go_direct_scenario]["classifies every usage"] = function()
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

local lua_gr_scenario = "references: gr classifies every Lua local usage"
T[lua_gr_scenario] = MiniTest.new_set()
T[lua_gr_scenario]["renders every usage kind"] = function()
	local root = H.git_repo({
		[".luarc.json"] = [[{"workspace":{"checkThirdParty":false}}]],
		["main.lua"] = "local count = 0\ncount = count + 1\nprint(count)\n",
	})
	local actual = open_references(root, "main.lua", 1, 7, "lua_ls", nil, nil, "lua")
	eq(actual, {
		{ "main.lua", 2, 1, "write" },
		{ "main.lua", 2, 9, "read" },
		{ "main.lua", 3, 7, "read" },
	})
end

local python_scenario = "references: gr classifies every Python variable usage"
T[python_scenario] = MiniTest.new_set()
T[python_scenario]["renders every usage kind"] = function()
	local root = H.git_repo({
		["pyproject.toml"] = '[project]\nname = "usage-kinds"\nversion = "0.1.0"\n',
		["main.py"] = "total = 0\ntotal += 1\nprint(total)\n",
	})
	local actual = open_references(root, "main.py", 1, 1, "basedpyright", nil, nil, "python")
	eq(actual, {
		{ "main.py", 2, 1, "write" },
		{ "main.py", 3, 7, "read" },
	})
end

local python_direct_scenario = "references: basedpyright kinds classify a Python variable"
T[python_direct_scenario] = MiniTest.new_set()
T[python_direct_scenario]["classifies every usage"] = function()
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

local typescript_scenario = "references: gr classifies every TypeScript variable usage"
T[typescript_scenario] = MiniTest.new_set()
T[typescript_scenario]["renders every usage kind"] = function()
	local root = H.git_repo({
		["package.json"] = [[{"private":true}]],
		["tsconfig.json"] = [[{"compilerOptions":{"strict":true}}]],
		["main.ts"] = "let hits = 0;\nhits++;\nconsole.log(hits);\n",
	})
	local actual = open_references(root, "main.ts", 1, 5, "vtsls", nil, nil, "typescript")
	eq(actual, {
		{ "main.ts", 2, 1, "write" },
		{ "main.ts", 3, 13, "read" },
	})
end
T[typescript_scenario]["falls back when the tsserver command is unavailable"] = function()
	local root = H.git_repo({
		["package.json"] = [[{"private":true}]],
		["tsconfig.json"] = [[{"compilerOptions":{"strict":true}}]],
		["main.ts"] = "let hits = 0;\nhits++;\nconsole.log(hits);\n",
	})
	local actual = open_references(root, "main.ts", 1, 5, "vtsls", nil, nil, "typescript", function()
		child.lua([[
local client = assert(vim.lsp.get_clients({ bufnr = 0, name = "vtsls" })[1])
local provider = assert(client.server_capabilities.executeCommandProvider)
provider.commands = vim.tbl_filter(function(command)
	return command ~= "typescript.tsserverRequest"
end, provider.commands)
vim.treesitter.query.set("ecma", "usages", "")
vim.treesitter.query.set("javascript", "usages", "")
vim.treesitter.query.set("typescript", "usages", "")
]])
	end)
	eq(actual, {
		{ "main.ts", 2, 1, "read" },
		{ "main.ts", 3, 13, "unclassified" },
	})
end

local typescript_direct_scenario = "references: tsserver kinds classify a TypeScript variable"
T[typescript_direct_scenario] = MiniTest.new_set()
T[typescript_direct_scenario]["classifies every usage"] = function()
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

local typescript_alias_scenario = "references: TypeScript type alias targets keep their usage types"
T[typescript_alias_scenario] = MiniTest.new_set()
T[typescript_alias_scenario]["classifies alias annotations through gr"] = function()
	local root = H.git_repo({
		["package.json"] = [[{"private":true}]],
		["tsconfig.json"] = [[{"compilerOptions":{"strict":true}}]],
		["main.ts"] = table.concat({
			"type Amount = number;",
			"const rate: Amount = 1;",
			"function convert(a: Amount): Amount {",
			"  return a * rate;",
			"}",
			"convert(2);",
		}, "\n"),
	})
	local actual = open_references(root, "main.ts", 1, 6, "vtsls", nil, nil, "typescript")
	eq(actual, {
		{ "main.ts", 2, 13, "variable_declaration" },
		{ "main.ts", 3, 21, "parameter_declaration" },
		{ "main.ts", 3, 30, "return_type" },
	})
end

local typescript_class_scenario = "references: gr classifies TypeScript class usages"
T[typescript_class_scenario] = MiniTest.new_set()
T[typescript_class_scenario]["fixture contains the exact class usages"] = function()
	local root, manifest = F.copy("tsproj", vim.fn.tempname())

	eq(vim.fn.readfile(root .. "/src/money.ts"), {
		"// An amount in cents.",
		"export class Money {",
		"  cents: number;",
		"",
		"  constructor(cents: number) {",
		"    this.cents = cents;",
		"  }",
		"",
		'  // Reads a decimal amount such as "19.99".',
		"  static parse(text: string): Money {",
		"    return new Money(Math.round(Number(text) * 100));",
		"  }",
		"}",
		"",
		"// Narrows an unknown value to an amount.",
		"export function isMoney(value: unknown): value is Money {",
		"  return value instanceof Money;",
		"}",
	})
	eq(vim.fn.readfile(root .. "/src/wallet.ts"), {
		'import { Money, isMoney } from "./money";',
		"",
		"export class Coin extends Money {}",
		"",
		"export class Wallet {",
		"  items: Money[] = [];",
		"",
		"  add(item: Money): Wallet {",
		"    this.items.push(item);",
		"    return this;",
		"  }",
		"",
		"  latest(): Money {",
		"    return this.items.at(-1) as Money;",
		"  }",
		"",
		"  restore(json: string): Wallet {",
		"    const value: unknown = JSON.parse(json);",
		"    const item: Money = isMoney(value) ? value : Money.parse(json);",
		"    return this.add(item);",
		"  }",
		"}",
	})
	eq(vim.fn.readfile(root .. "/src/money.test.ts"), {
		'import { Money } from "./money";',
		"",
		'export const amounts: Array<Money> = [Money.parse("19.99")];',
	})
	eq(manifest.references.Money, {
		{ path = "src/money.ts", line = 2, col = 14 },
		{ path = "src/money.ts", line = 10, col = 31 },
		{ path = "src/money.ts", line = 11, col = 16 },
		{ path = "src/money.ts", line = 16, col = 51 },
		{ path = "src/money.ts", line = 17, col = 27 },
		{ path = "src/wallet.ts", line = 1, col = 10 },
		{ path = "src/wallet.ts", line = 3, col = 27 },
		{ path = "src/wallet.ts", line = 6, col = 10 },
		{ path = "src/wallet.ts", line = 8, col = 13 },
		{ path = "src/wallet.ts", line = 13, col = 13 },
		{ path = "src/wallet.ts", line = 14, col = 33 },
		{ path = "src/wallet.ts", line = 19, col = 17 },
		{ path = "src/wallet.ts", line = 19, col = 50 },
		{ path = "src/money.test.ts", line = 1, col = 10 },
		{ path = "src/money.test.ts", line = 3, col = 29 },
		{ path = "src/money.test.ts", line = 3, col = 39 },
	})
end
T[typescript_class_scenario]["renders every class usage type"] = function()
	local root, manifest = F.copy("tsproj", vim.fn.tempname())
	local declaration = manifest.references.Money[1]
	local actual = open_references(
		root,
		declaration.path,
		declaration.line,
		declaration.col,
		"vtsls",
		nil,
		nil,
		"typescript",
		nil,
		#manifest.references.Money - 1
	)
	eq(actual, {
		{ "src/money.test.ts", 1, 10, "import" },
		{ "src/money.test.ts", 3, 29, "type_instantiation" },
		{ "src/money.test.ts", 3, 39, "static_member" },
		{ "src/money.ts", 10, 31, "return_type" },
		{ "src/money.ts", 11, 16, "new" },
		{ "src/money.ts", 16, 51, "instanceof" },
		{ "src/money.ts", 17, 27, "instanceof" },
		{ "src/wallet.ts", 1, 10, "import" },
		{ "src/wallet.ts", 3, 27, "extends" },
		{ "src/wallet.ts", 6, 10, "field_declaration" },
		{ "src/wallet.ts", 8, 13, "parameter_declaration" },
		{ "src/wallet.ts", 13, 13, "return_type" },
		{ "src/wallet.ts", 14, 33, "cast" },
		{ "src/wallet.ts", 19, 17, "variable_declaration" },
		{ "src/wallet.ts", 19, 50, "static_member" },
	})
end

local typescript_method_scenario = "references: gr classifies TypeScript method usages as calls"
T[typescript_method_scenario] = MiniTest.new_set()
T[typescript_method_scenario]["renders every method usage as a call"] = function()
	local root = F.copy("tsproj", vim.fn.tempname())
	local actual = open_references(root, "src/money.ts", 10, 10, "vtsls", nil, nil, "typescript", nil, 2)
	eq(actual, {
		{ "src/money.test.ts", 3, 45, "call" },
		{ "src/wallet.ts", 19, 56, "call" },
	})
end

local rust_scenario = "references: gr classifies every Rust variable usage"
T[rust_scenario] = MiniTest.new_set()
T[rust_scenario]["renders every usage kind"] = function()
	local root = H.git_repo({
		["Cargo.toml"] = '[package]\nname = "usage-kinds"\nversion = "0.1.0"\nedition = "2024"\n',
		["src/main.rs"] = 'fn main() { let mut n = 0;\n    n += 1;\n    println!("{n}");\n}\n',
	})
	local actual =
		open_references(root, "src/main.rs", 1, 21, "rust_analyzer", "rust-analyzer", RUST_TIMEOUT_MS, "rust")
	eq(actual, {
		{ "src/main.rs", 2, 5, "write" },
		{ "src/main.rs", 3, 16, "read" },
	})
end

local rust_struct_scenario = "references: gr classifies Rust struct usages"
T[rust_struct_scenario] = MiniTest.new_set()
T[rust_struct_scenario]["renders every struct usage type"] = function()
	local root, manifest = F.copy("rustproj", vim.fn.tempname())
	local declaration = manifest.references.Money[1]
	local actual = open_references(
		root,
		declaration.path,
		declaration.line,
		declaration.col,
		"rust_analyzer",
		"rust-analyzer",
		RUST_TIMEOUT_MS,
		"rust",
		nil,
		10
	)
	eq(actual, {
		{ "src/ledger.rs", 1, 19, "import" },
		{ "src/ledger.rs", 4, 36, "return_type" },
		{ "src/ledger.rs", 5, 5, "call" },
		{ "src/ledger.rs", 9, 25, "parameter_declaration" },
		{ "src/ledger.rs", 11, 9, "pattern" },
		{ "src/money.rs", 6, 6, "impl" },
		{ "src/money.rs", 7, 38, "return_type" },
		{ "src/money.rs", 8, 9, "struct_initialization" },
		{ "tests/money.rs", 1, 22, "import" },
		{ "tests/money.rs", 5, 18, "call" },
	})
end

local rust_field_scenario = "references: gr classifies Rust field usages"
T[rust_field_scenario] = MiniTest.new_set()
T[rust_field_scenario]["renders every field usage type"] = function()
	local root = F.copy("rustproj", vim.fn.tempname())
	local actual =
		open_references(root, "src/money.rs", 3, 9, "rust_analyzer", "rust-analyzer", RUST_TIMEOUT_MS, "rust", nil, 3)
	eq(actual, {
		{ "src/ledger.rs", 11, 17, "pattern" },
		{ "src/money.rs", 8, 17, "field_initialization" },
		{ "tests/money.rs", 6, 23, "macro_argument" },
	})
end

local rust_direct_scenario = "references: rust-analyzer kinds classify a Rust variable"
T[rust_direct_scenario] = MiniTest.new_set()
T[rust_direct_scenario]["classifies every usage"] = function()
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

local bash_scenario = "references: gr classifies every Bash variable usage"
T[bash_scenario] = MiniTest.new_set()
T[bash_scenario]["renders every usage kind"] = function()
	local root = H.git_repo({
		["main.sh"] = "count=0\ncount=$((count + 1))\nprintf '%s\\n' \"$count\"\n",
	})
	local actual = open_references(root, "main.sh", 1, 1, "bashls", nil, nil, "bash")
	eq(actual, {
		{ "main.sh", 2, 1, "write" },
		{ "main.sh", 2, 10, "read" },
		{ "main.sh", 3, 17, "read" },
	})
end

local terraform_scenario = "references: gr classifies every Terraform variable usage"
T[terraform_scenario] = MiniTest.new_set()
T[terraform_scenario]["renders every usage kind"] = function()
	local root, manifest = F.copy("tfproj", vim.fn.tempname())
	local declaration = manifest.references.region[1]
	local actual =
		open_references(root, declaration.path, declaration.line, declaration.col, "terraformls", nil, nil, "hcl")
	eq(actual, {
		{ "main.tf", 2, 21, "read" },
		{ "outputs.tf", 2, 11, "read" },
	})
end

local python_class_scenario = "references: gr classifies Python class usages"
T[python_class_scenario] = MiniTest.new_set()
T[python_class_scenario]["classifies every class usage through the picker"] = function()
	local root, manifest = F.copy("pyproj", vim.fn.tempname())
	local declaration = manifest.references.Money[1]
	local actual = open_references(
		root,
		declaration.path,
		declaration.line,
		declaration.col,
		"basedpyright",
		nil,
		nil,
		"python",
		nil,
		5
	)
	eq(actual, {
		{ "shop/pricing.py", 1, 24, "import" },
		{ "shop/pricing.py", 3, 8, "new" },
		{ "shop/pricing.py", 6, 13, "extends" },
		{ "shop/pricing.py", 10, 21, "parameter_declaration" },
		{ "tests/test_pricing.py", 5, 43, "instanceof" },
	})
end

return T

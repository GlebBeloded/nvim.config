local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()
local TIMEOUT_MS = H.lsp_timeout(15000)
local RUST_TIMEOUT_MS = H.lsp_timeout(30000)

local function start()
	child.start_config({ env = F.go_env() })
	child.wait_very_lazy()
	child.o.lines, child.o.columns = 30, 100
end

local T = H.child_set(child, start)

local LANGUAGE_CLIENTS = {
	rust = { server = "rust_analyzer", attached = { "rust-analyzer" }, timeout = RUST_TIMEOUT_MS },
}

---@param command string
local function require_command(command)
	if child.fn.executable(command) == 0 then
		MiniTest.skip(command .. " is not executable")
	end
end

---@param server string
local function require_server(server)
	local command = child.lua_get("(vim.lsp.config[...].cmd or {})[1]", { server })
	if type(command) ~= "string" or child.fn.executable(command) == 0 then
		MiniTest.skip((command or server) .. " is not executable")
	end
end

---@param fixture string
---@param symbol string
---@param server string
---@param attached string[]
---@param timeout? integer
---@return string
---@return fixtures.Manifest
local function open_references(fixture, symbol, server, attached, timeout)
	require_server(server)
	local root, manifest = F.copy(fixture, vim.fn.tempname())
	local declaration = manifest.references[symbol][1]
	child.cmd("cd " .. vim.fn.fnameescape(root) .. " | edit " .. vim.fn.fnameescape(declaration.path))
	child.api.nvim_win_set_cursor(0, { declaration.line, declaration.col - 1 })

	for _, name in ipairs(attached) do
		eq(
			child.wait(([[#vim.lsp.get_clients({ bufnr = 0, name = %q }) > 0]]):format(name), timeout or TIMEOUT_MS),
			true
		)
	end

	child.lua(
		[[
local server, timeout = ...
_G.references_ready, _G.references_error = nil, nil
local bufnr = vim.api.nvim_get_current_buf()
local started = vim.uv.hrtime()
local function request()
	local client = vim.lsp.get_clients({ bufnr = bufnr, name = server })[1]
	local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
	params.context = { includeDeclaration = false }
	client:request("textDocument/references", params, function(err, result)
		if err then _G.references_error = err.message end
		if result and #result > 0 then
			_G.references_ready = true
		elseif (vim.uv.hrtime() - started) / 1e6 < timeout then
			vim.defer_fn(request, 10)
		end
	end, bufnr)
end
request()
]],
		{ attached[1], timeout or TIMEOUT_MS }
	)
	eq(child.wait("_G.references_ready == true", timeout or TIMEOUT_MS), true)

	child.type_keys("gr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], timeout or TIMEOUT_MS), true)
	eq(child.wait([[not require("gleb.references.view").state.classifying]], timeout or TIMEOUT_MS), true)
	return root, manifest
end

---@param expected string[]
local function expect_tree_rows(expected)
	local actual = child.lua_get([[
(function()
	local state = require("gleb.references.view").state
	local rows = vim.api.nvim_buf_get_lines(state.tree_buf, 0, -1, false)
	local result = {}
	for index, node in ipairs(state.visible_nodes) do
		assert(rows[index]:find(node.label, 1, true), "rendered row does not contain " .. node.label)
		table.insert(result, node.kind .. ":" .. node.label)
	end
	return result
end)()
]])
	eq(actual, expected)
end

---@param manifest fixtures.Manifest
---@param symbol string
---@param path string
---@param occurrence? integer
---@return string
local function usage_label(manifest, symbol, path, occurrence)
	local seen = 0
	for _, location in ipairs(manifest.references[symbol]) do
		if location.path == path then
			seen = seen + 1
			if seen == (occurrence or 1) then
				return path:match("([^/]+)$") .. ":" .. location.line
			end
		end
	end
	error("missing manifest usage " .. path)
end

---@param fixture string
---@param symbol string
---@param paths string[]
local function expect_fixture(fixture, symbol, paths)
	local root, manifest = F.copy(fixture, vim.fn.tempname())
	local locations = manifest.references[symbol]

	eq(
		vim.tbl_map(function(location)
			return location.path
		end, locations),
		paths
	)

	for _, location in ipairs(locations) do
		local line = vim.fn.readfile(vim.fs.joinpath(root, location.path))[location.line]
		eq(line:sub(location.col, location.col + #symbol - 1), symbol)
	end
end

local language_scenario = "languages: Each references facet gets a gr run"
T[language_scenario] = MiniTest.new_set()
for _, entry in ipairs(require("gleb.languages").facet("references")) do
	local language = entry.language
	local references = entry.config
	local client = LANGUAGE_CLIENTS[language.name]
		or { server = language.lsp.servers[1], attached = { language.lsp.servers[1] } }
	T[language_scenario][language.name] = function()
		open_references(
			references.fixture.project,
			references.fixture.symbol,
			client.server,
			client.attached,
			client.timeout
		)
	end
end

local lua_scenario = "references: Lua usages in production and spec files"
T[lua_scenario] = MiniTest.new_set()
T[lua_scenario]["fixture manifest"] = function()
	expect_fixture("luaproj", "total", { "lua/shop/price.lua", "lua/shop/cart.lua", "spec/price_spec.lua" })
end
T[lua_scenario]["gr opens usages"] = function()
	local _, manifest = open_references("luaproj", "total", "lua_ls", { "lua_ls" })
	expect_tree_rows({
		"scope:Production",
		"type:Call",
		"folder:lua/shop",
		"usage:" .. usage_label(manifest, "total", "lua/shop/cart.lua"),
		"scope:Test",
		"type:Call",
		"folder:spec",
		"usage:" .. usage_label(manifest, "total", "spec/price_spec.lua"),
	})
end

local python_scenario = "references: Python usages in production and test files"
T[python_scenario] = MiniTest.new_set()
T[python_scenario]["fixture manifest"] = function()
	expect_fixture("pyproj", "total", { "shop/price.py", "shop/cart.py", "tests/test_price.py" })
end
T[python_scenario]["gr opens usages"] = function()
	require_command("python3")
	local _, manifest = open_references("pyproj", "total", "basedpyright", { "basedpyright", "ruff" })
	expect_tree_rows({
		"scope:Production",
		"type:Call",
		"folder:shop",
		"usage:" .. usage_label(manifest, "total", "shop/cart.py"),
		"scope:Test",
		"type:Call",
		"folder:tests",
		"usage:" .. usage_label(manifest, "total", "tests/test_price.py"),
	})
end

local typescript_scenario = "references: TypeScript usages in production and test files"
T[typescript_scenario] = MiniTest.new_set()
T[typescript_scenario]["fixture manifest"] = function()
	expect_fixture("tsproj", "total", { "src/price.ts", "src/cart.ts", "src/price.test.ts" })
end
T[typescript_scenario]["gr opens usages"] = function()
	require_command("node")
	require_command("vscode-eslint-language-server")
	local _, manifest = open_references("tsproj", "total", "vtsls", { "vtsls", "eslint" })
	expect_tree_rows({
		"scope:Production",
		"type:Call",
		"folder:src",
		"usage:" .. usage_label(manifest, "total", "src/cart.ts"),
		"scope:Test",
		"type:Call",
		"folder:src",
		"usage:" .. usage_label(manifest, "total", "src/price.test.ts"),
	})
end

local rust_scenario = "references: Rust usages in production and test code"
T[rust_scenario] = MiniTest.new_set()
T[rust_scenario]["fixture manifest"] = function()
	expect_fixture("rustproj", "total", { "src/price.rs", "src/price.rs", "src/main.rs", "tests/price.rs" })
end
T[rust_scenario]["gr opens usages"] = function()
	require_command("cargo")
	local _, manifest = open_references("rustproj", "total", "rust_analyzer", { "rust-analyzer" }, RUST_TIMEOUT_MS)
	local inline = "usage:" .. usage_label(manifest, "total", "src/price.rs", 2)
	local main = "usage:" .. usage_label(manifest, "total", "src/main.rs")
	local integration = "usage:" .. usage_label(manifest, "total", "tests/price.rs")
	local has_parser = child.lua_get([[vim.treesitter.language.add("rust") == true]])
	if has_parser then
		expect_tree_rows({
			"scope:Production",
			"type:Macro argument",
			"folder:src",
			main,
			"scope:Test",
			"type:Macro argument",
			"folder:src",
			inline,
			"folder:tests",
			integration,
		})
	else
		expect_tree_rows({
			"scope:Production",
			"folder:src",
			main,
			inline,
			"scope:Test",
			"folder:tests",
			integration,
		})
	end
end

local bash_scenario = "references: Bash usages in production and test scripts"
T[bash_scenario] = MiniTest.new_set()
T[bash_scenario]["fixture manifest"] = function()
	expect_fixture("bashproj", "total", { "lib/price.sh", "bin/run.sh", "test/price_test.sh" })
end
T[bash_scenario]["gr opens usages"] = function()
	require_command("bash")
	local _, manifest = open_references("bashproj", "total", "bashls", { "bashls" })
	expect_tree_rows({
		"scope:Production",
		"type:Call",
		"folder:bin",
		"usage:" .. usage_label(manifest, "total", "bin/run.sh"),
		"scope:Test",
		"type:Call",
		"folder:test",
		"usage:" .. usage_label(manifest, "total", "test/price_test.sh"),
	})
end

local terraform_scenario = "references: Terraform variable usages"
T[terraform_scenario] = MiniTest.new_set()
T[terraform_scenario]["fixture manifest"] = function()
	expect_fixture("tfproj", "region", { "variables.tf", "main.tf", "outputs.tf" })
end
T[terraform_scenario]["gr opens usages"] = function()
	local _, manifest = open_references("tfproj", "region", "terraformls", { "terraformls" })
	expect_tree_rows({
		"scope:Production",
		"type:Value read",
		"folder:.",
		"usage:" .. usage_label(manifest, "region", "main.tf"),
		"usage:" .. usage_label(manifest, "region", "outputs.tf"),
	})
end

return T

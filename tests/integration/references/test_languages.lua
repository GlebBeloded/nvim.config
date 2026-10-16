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
	child.o.lines, child.o.columns = 30, 100
end

local T = H.child_set(child, start)

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
		eq(child.wait(([[#vim.lsp.get_clients({ bufnr = 0, name = %q }) > 0]]):format(name), timeout or TIMEOUT_MS), true)
	end

	child.lua([[
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
]], { attached[1], timeout or TIMEOUT_MS })
	eq(child.wait("_G.references_ready == true", timeout or TIMEOUT_MS), true)

	child.type_keys("gr")
	eq(child.wait([[vim.bo.filetype == "gleb-references"]], timeout or TIMEOUT_MS), true)
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

T["references: Lua usages in production and spec files"] = function()
	local _, manifest = open_references("luaproj", "total", "lua_ls", { "lua_ls" })
	expect_tree_rows({
		"scope:Production",
		"folder:lua/shop",
		"usage:" .. usage_label(manifest, "total", "lua/shop/cart.lua"),
		"scope:Test",
		"folder:spec",
		"usage:" .. usage_label(manifest, "total", "spec/price_spec.lua"),
	})
end

T["references: Python usages in production and test files"] = function()
	require_command("python3")
	local _, manifest = open_references("pyproj", "total", "basedpyright", { "basedpyright", "ruff" })
	expect_tree_rows({
		"scope:Production",
		"folder:shop",
		"usage:" .. usage_label(manifest, "total", "shop/cart.py"),
		"scope:Test",
		"folder:tests",
		"usage:" .. usage_label(manifest, "total", "tests/test_price.py"),
	})
end

T["references: TypeScript usages in production and test files"] = function()
	require_command("node")
	require_command("vscode-eslint-language-server")
	local _, manifest = open_references("tsproj", "total", "vtsls", { "vtsls", "eslint" })
	expect_tree_rows({
		"scope:Production",
		"folder:src",
		"usage:" .. usage_label(manifest, "total", "src/cart.ts"),
		"scope:Test",
		"folder:src",
		"usage:" .. usage_label(manifest, "total", "src/price.test.ts"),
	})
end

T["references: Rust usages in production and test code"] = function()
	require_command("cargo")
	local _, manifest = open_references("rustproj", "total", "rust_analyzer", { "rust-analyzer" }, RUST_TIMEOUT_MS)
	local inline = "usage:" .. usage_label(manifest, "total", "src/price.rs", 2)
	local main = "usage:" .. usage_label(manifest, "total", "src/main.rs")
	local integration = "usage:" .. usage_label(manifest, "total", "tests/price.rs")
	local has_parser = child.lua_get([[vim.treesitter.language.add("rust") == true]])
	if has_parser then
		expect_tree_rows({
			"scope:Production",
			"folder:src",
			main,
			"scope:Test",
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

T["references: Bash usages in production and test scripts"] = function()
	require_command("bash")
	local _, manifest = open_references("bashproj", "total", "bashls", { "bashls" })
	expect_tree_rows({
		"scope:Production",
		"folder:bin",
		"usage:" .. usage_label(manifest, "total", "bin/run.sh"),
		"scope:Test",
		"folder:test",
		"usage:" .. usage_label(manifest, "total", "test/price_test.sh"),
	})
end

T["references: Terraform variable usages"] = function()
	local _, manifest = open_references("tfproj", "region", "terraformls", { "terraformls" })
	expect_tree_rows({
		"scope:Production",
		"folder:.",
		"usage:" .. usage_label(manifest, "region", "main.tf"),
		"usage:" .. usage_label(manifest, "region", "outputs.tf"),
	})
end

return T

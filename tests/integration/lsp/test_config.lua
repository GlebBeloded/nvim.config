local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	child.wait_very_lazy()
end

local T = H.child_set(child, start)

T["lsp: JavaScript config enables vtsls and eslint"] = function()
	local file = vim.fn.tempname() .. ".js"
	vim.fn.writefile({ "const answer = 42" }, file)
	child.cmd("edit " .. vim.fn.fnameescape(file))

	eq(child.bo.filetype, "javascript")
	eq(
		child.lua_get([[vim.fn.sort(vim.iter(vim.lsp.get_configs({ enabled = true, filetype = vim.bo.filetype }))
			:map(function(config) return config.name end):totable())]]),
		{ "eslint", "vtsls" }
	)
end

T["lsp: Ranged Lua code action does not log generator failure"] = function()
	local file = vim.fn.tempname() .. ".lua"
	vim.fn.writefile({ "local answer = 42", "print(answer)" }, file)
	child.cmd("edit " .. vim.fn.fnameescape(file))

	local attached = child.wait([[#vim.lsp.get_clients({ bufnr = 0, name = "null-ls" }) > 0]])
	eq(attached, true)
	child.lua([[
		local client = vim.lsp.get_clients({ bufnr = 0, name = "null-ls" })[1]
		local params = vim.lsp.util.make_given_range_params({ 1, 0 }, { 2, 0 }, 0, client.offset_encoding)
		params.context = { diagnostics = {} }
		_G.code_action_done = false
		client:request("textDocument/codeAction", params, function() _G.code_action_done = true end, 0)
	]])
	eq(child.wait("_G.code_action_done"), true)

	local log = child.lua_get([[(function()
		local path = require("null-ls.logger"):get_path()
		return vim.fn.filereadable(path) == 1 and table.concat(vim.fn.readfile(path), "\n") or ""
	end)()]])
	eq(log:find("failed to run generator", 1, true), nil)
end

T["lsp: Terraform files use terraformls"] = function()
	local file = vim.fn.tempname() .. ".tf"
	vim.fn.writefile({ "terraform {}" }, file)
	child.cmd("edit " .. vim.fn.fnameescape(file))

	eq(child.bo.filetype, "terraform")
	eq(
		child.lua_get([[vim.iter(vim.lsp.get_configs({ enabled = true, filetype = vim.bo.filetype }))
			:map(function(config) return config.name end):totable()]]),
		{ "terraformls" }
	)
end

T["lsp: Terraform formatter is omitted when Terraform is unavailable"] = function()
	local empty_path = H.tempdir(child)
	child.restart_config({}, { env = { PATH = empty_path } })
	child.wait_very_lazy()

	eq(child.fn.executable("terraform"), 0)
	eq(
		child.lua_get([[vim.iter(require("null-ls.sources").get_all())
			:any(function(source) return source.name == "terraform_fmt" end)]]),
		false
	)
end

return T

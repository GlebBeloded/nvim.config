local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, function()
	child.start_config()
end)

T["languages: Test patterns come from the facet"] = function()
	child.lua([[
		local registry = require("gleb.languages")
		registry.for_filetype("go").references.test_patterns = { "_check%.go$" }
		registry.reset()
	]])

	eq(child.lua_get([[require("gleb.references.scope").is_test("pkg/a_check.go", "go")]]), true)
	eq(child.lua_get([[require("gleb.references.scope").is_test("pkg/a_test.go", "go")]]), false)
end

T["languages: Terraform queries inherit the HCL query"] = function()
	local path = child.fn.tempname() .. ".tf"
	child.lua(
		[[
		local path = ...
		local source = 'variable "region" {}\nvalue = var.region'
		vim.fn.writefile(vim.split(source, "\n", { plain = true }), path)
		vim.cmd.edit(vim.fn.fnameescape(path))
		vim.bo.filetype = "terraform"
		assert(vim.treesitter.query.get("terraform", "usages"))
		vim.treesitter.query.set("hcl", "usages", "(identifier) @usage.hcl_override")

		local uri = vim.uri_from_fname(path)
		_G.terraform_kinds = nil
		require("gleb.references.kind").classify({
			{
				uri = uri,
				path = path,
				lnum = 1,
				col = 11,
				filetype = vim.bo.filetype,
			},
			{
				uri = uri,
				path = path,
				lnum = 2,
				col = 13,
				filetype = vim.bo.filetype,
			},
		}, function(usages)
			_G.terraform_kinds = vim.tbl_map(function(usage) return usage.kind end, usages)
		end)
	]],
		{ path }
	)
	eq(child.wait([[type(_G.terraform_kinds) == "table"]]), true)

	eq(child.lua_get("_G.terraform_kinds"), { "write", "read" })
end

local server_kinds_scenario = "languages: Filetypes without an enabled references facet use server kinds"
T[server_kinds_scenario] = MiniTest.new_set()

local function expect_server_write(filetype, disable_facet)
	child.lua(
		[[
		local filetype, disable_facet = ...
		if disable_facet then
			require("gleb.languages").for_filetype(filetype).references = { disabled = "not configured" }
		end
		local path = vim.fn.tempname()
		vim.fn.writefile({ "value" }, path)
		local position = { line = 0, character = 0 }
		local range = { start = position, ["end"] = position }
		local client = { id = 991, name = "server-kinds-test", offset_encoding = "utf-8" }
		function client:supports_method(method)
			return method == "textDocument/documentHighlight"
		end
		function client:request(_, _, callback)
			vim.schedule(function() callback(nil, { { kind = 3, range = range } }) end)
			return true
		end
		vim.lsp.get_client_by_id = function(id) return id == client.id and client or nil end
		_G.server_kinds = nil
		require("gleb.references.kind").classify({ {
			uri = vim.uri_from_fname(path),
			path = path,
			lnum = 1,
			col = 1,
			filetype = filetype,
			range = range,
			client_id = client.id,
		} }, function(usages)
			_G.server_kinds = { usages[1].kind or vim.NIL }
		end)
	]],
		{ filetype, disable_facet }
	)
	eq(child.wait("_G.server_kinds ~= nil", 1000), true)
	eq(child.lua_get("_G.server_kinds"), { "write" })
end

T[server_kinds_scenario]["unregistered filetype"] = function()
	expect_server_write("unregistered", false)
end

T[server_kinds_scenario]["disabled facet"] = function()
	expect_server_write("css", true)
end

return T

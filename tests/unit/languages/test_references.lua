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

return T

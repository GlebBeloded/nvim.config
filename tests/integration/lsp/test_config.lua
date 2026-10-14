local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	child.wait_very_lazy()
end

local T = H.child_set(child, start)

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

return T

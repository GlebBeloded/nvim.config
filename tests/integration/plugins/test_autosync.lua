local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_config)

T["plugins: Writing plugins.lua runs no Lazy command"] = function()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local file = vim.fs.joinpath(dir, "plugins.lua")
	child.cmd("edit " .. vim.fn.fnameescape(file))
	child.api.nvim_buf_set_lines(0, 0, -1, false, { "-- plugin specification" })
	child.lua([[
LazyCommands = {}
vim.api.nvim_del_user_command("Lazy")
vim.api.nvim_create_user_command("Lazy", function(opts)
	table.insert(LazyCommands, opts.args)
end, { nargs = "*" })
]])

	child.cmd("write")

	eq(child.lua_get("LazyCommands"), {})
end

return T

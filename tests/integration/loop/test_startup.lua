local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local RECORD_STARTUP_ORDER = [[lua _G.config_startup_order = {}
local enable = vim.loader.enable
vim.loader.enable = function(...)
	table.insert(_G.config_startup_order, "loader")
	return enable(...)
end
local original_require = require
_G.require = function(name)
	if type(name) == "string" and name:match("^gleb%.") and not _G.first_config_require then
		_G.first_config_require = name
		table.insert(_G.config_startup_order, "require:" .. name)
	end
	return original_require(name)
end]]

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

T["loop: Cached loader precedes configuration modules"] = function()
	H.isolate()
	child.restart(vim.list_extend({ "--cmd", RECORD_STARTUP_ORDER }, H.config_args()))

	eq(
		{ "loader", "require:gleb.nvim_debug_log" },
		child.lua_get("{ _G.config_startup_order[1], _G.config_startup_order[2] }")
	)
end

return T

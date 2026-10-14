-- Neotest summary actions; lua/gleb/testing/init.lua hands their keys to the summary window mappings.

local replay = require("gleb.actions.adapters").replay

---@type gleb.Action[]
local actions = {
	{ id = "neotest.run", title = "Run test", category = "Test", plugin = "neotest", run = replay("neotest.run") },
}

return actions

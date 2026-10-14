local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[Registry = require("gleb.actions.registry")]])
end

local T = H.child_set(child, start)

T["actions: Ex commands become humanized hidden actions"] = function()
	child.lua([[
		Catalog = Registry.new({}, {
			complete_commands = function() return { "DiffviewOpen" } end,
		})
		Hidden = Catalog:hidden()
	]])

	eq(
		child.lua_get([[(function()
			local action = Hidden[1]
			return {
				id = action.id,
				title = action.title,
				category = action.category,
				hidden = action.hidden,
			}
		end)()]]),
		{
			id = "ex.diffview_open",
			title = "Diffview Open",
			category = "Command",
			hidden = true,
		}
	)
end

T["actions: Registered commands are not duplicated"] = function()
	child.lua([[
		Catalog = Registry.new({ {
			{ id = "ex.diffview_open", title = "Open Diffview", category = "Git", run = function() end },
		} }, {
			complete_commands = function() return { "DiffviewOpen" } end,
		})
		Hidden = Catalog:hidden()
	]])

	eq(child.lua_get([[#Hidden]]), 0)
end

T["actions: Hidden command discovery is cached"] = function()
	child.lua([[
		CompletionCalls = 0
		Catalog = Registry.new({}, {
			complete_commands = function()
				CompletionCalls = CompletionCalls + 1
				return { "DiffviewOpen" }
			end,
		})
		FirstHidden = Catalog:hidden()
		SecondHidden = Catalog:hidden()
	]])

	eq(child.lua_get([[CompletionCalls]]), 1)
	eq(child.lua_get([[rawequal(FirstHidden, SecondHidden)]]), true)
end

return T

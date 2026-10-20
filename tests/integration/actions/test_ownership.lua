local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	child.wait_very_lazy()
end

local T = H.child_set(child, start, { reuse = true })

T["actions: Feature actions contain no shortcut keys"] = function()
	local offenders = child.lua_get([[(function()
		local found = {}
		for _, action in ipairs(require("gleb.actions").state.applicator.catalog.actions) do
			if type(action.id) ~= "string" or type(action.run) ~= "function"
				or action.lhs ~= nil or action.shortcut ~= nil
			then
				table.insert(found, tostring(action.id))
			end
		end
		return found
	end)()]])

	eq(offenders, {})
end

T["actions: Every configured action is registered"] = function()
	local unknown = child.lua_get([[(function()
		local actions = require("gleb.actions")
		local shortcuts = vim.json.decode(table.concat(vim.fn.readfile(vim.fs.joinpath(vim.fn.stdpath("config"), "settings/keymap.json")), "\n"))
		local found = {}
		for id in pairs(shortcuts) do
			if not actions.state.applicator.catalog:get(id) then
				table.insert(found, id)
			end
		end
		table.sort(found)
		return found
	end)()]])

	eq(unknown, {})
end

T["actions: Every configured mapping is action-owned"] = function()
	eq(child.lua_get([[require("gleb.actions").audit()]]), {})
	eq(
		child.lua_get([[(function()
			local retired_prefixes = { "tree.", "neo_tree.", "differ.", "codediff." }
			local shortcuts = require("gleb.actions").state.store.last_good
			local found = {}
			for id in pairs(shortcuts) do
				if id == "git.open_differ"
					or vim.iter(retired_prefixes):any(function(prefix) return vim.startswith(id, prefix) end)
				then
					table.insert(found, id)
				end
			end
			table.sort(found)
			return found
		end)()]]),
		{}
	)
end

return T

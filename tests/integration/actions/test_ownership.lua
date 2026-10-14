local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_config()
	child.wait_very_lazy()
end

local T = H.child_set(child, start)

T["actions: Feature actions contain no shortcut keys"] = function()
	local offenders = child.lua_get([[(function()
		local modules = {
			"gleb.keymaps.actions",
			"gleb.comments.actions",
			"gleb.folding.actions",
			"gleb.ai.actions",
			"gleb.git.actions",
			"gleb.file_tree.actions",
			"gleb.autocommands.actions",
		}
		local found = {}
		for _, module in ipairs(modules) do
			local ok, actions = pcall(require, module)
			if not ok then
				table.insert(found, module .. ": missing")
			else
				for _, action in ipairs(actions) do
					if type(action.id) ~= "string" or type(action.run) ~= "function"
						or action.lhs ~= nil or action.shortcut ~= nil
					then
						table.insert(found, module .. ": " .. tostring(action.id))
					end
				end
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
end

return T

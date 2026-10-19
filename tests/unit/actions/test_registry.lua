local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[Registry = require("gleb.actions.registry")]])
end

local T = H.child_set(child, start)

T["actions: Valid actions are available by id"] = function()
	child.lua([[
		Catalog = Registry.new({
			{
				{
					id = "git.open_review",
					title = "Open Review",
					category = "Git | Diff",
					aliases = { "git.review" },
					run = function() end,
				},
			},
		})
	]])

	eq(
		child.lua_get([[(function() local action = Catalog:get("git.open_review"); return {
		id = action.id,
		title = action.title,
		category = action.category,
		has_run = type(action.run) == "function",
		has_shortcuts = action.keys ~= nil,
	} end)()]]),
		{
			id = "git.open_review",
			title = "Open Review",
			category = "Git | Diff",
			has_run = true,
			has_shortcuts = false,
		}
	)
	eq(child.lua_get([[Catalog:get("git.review").id]]), "git.open_review")
end

T["actions: Invalid action ids are rejected"] = function()
	local error_message = child.lua_get([[(function()
		local ok, err = pcall(Registry.new, { {
			{ id = "Open Review", title = "Open Review", category = "Git", run = function() end },
		} })
		return ok and "" or tostring(err)
	end)()]])

	eq(error_message:match("invalid action id: Open Review"), "invalid action id: Open Review")
end

T["actions: Duplicate action ids are rejected"] = function()
	local error_message = child.lua_get([[(function()
		local ok, err = pcall(Registry.new, {
			{ { id = "git.open_review", title = "First", category = "Git", run = function() end } },
			{ { id = "git.open_review", title = "Second", category = "Git", run = function() end } },
		})
		return ok and "" or tostring(err)
	end)()]])

	eq(error_message:match("duplicate action id: git.open_review"), "duplicate action id: git.open_review")
	local alias_error_message = child.lua_get([[(function()
		local ok, err = pcall(Registry.new, { {
			{ id = "edit.open", title = "Open", category = "Edit", run = function() end },
			{
				id = "edit.close",
				title = "Close",
				category = "Edit",
				aliases = { "edit.open" },
				run = function() end,
			},
		} })
		return ok and "" or tostring(err)
	end)()]])

	eq(alias_error_message:match("duplicate action id: edit.open"), "duplicate action id: edit.open")
end

T["actions: Scoped actions are filtered by context"] = function()
	child.lua([[
		Catalog = Registry.new({ {
			{ id = "edit.always", title = "Always", category = "Edit", run = function() end },
			{ id = "edit.visual", title = "Visual", category = "Edit", modes = { "x" }, run = function() end },
			{ id = "git.commit", title = "Commit", category = "Git", ft = "gitcommit", run = function() end },
			{
				id = "edit.available",
				title = "Available",
				category = "Edit",
				when = function(ctx) return ctx.enabled end,
				run = function() end,
			},
		} })
	]])

	eq(
		child.lua_get([[(function()
		return vim.tbl_map(function(action) return action.id end, Catalog:filter("n", "lua", {
			enabled = true,
		}))
	end)()]]),
		{ "edit.always", "edit.available" }
	)
end

return T

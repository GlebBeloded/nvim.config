local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	child.start_bare()
	child.lua([[
		Registry = require("gleb.actions.registry")
		Store = require("gleb.actions.store")
		Catalog = Registry.new({ {
			{ id = "edit.alpha", title = "Alpha", category = "Edit", run = function() end },
			{ id = "git.zebra", title = "Zebra", category = "Git", run = function() end },
			{
				id = "command.hidden",
				title = "Hidden",
				category = "Command",
				hidden = true,
				run = function() end,
			},
		} })
		Path = vim.fn.tempname()
		ShortcutStore = Store.new(Path, Catalog)
	]])
end

local T = H.child_set(child, start)

T["actions: Shortcut file round-trips deterministically"] = function()
	child.lua([[
		ShortcutStore:save({
			["git.zebra"] = { "z" },
			["edit.alpha"] = { "a", "<M-a>" },
		})
	]])

	eq(child.lua_get([[ShortcutStore:load()]]), {
		["edit.alpha"] = { "a", "<M-a>" },
		["git.zebra"] = { "z" },
	})
	eq(
		child.lua_get([[table.concat(vim.fn.readfile(Path), "\n")]]),
		'{\n  "edit.alpha": [\n    "a",\n    "<M-a>"\n  ],\n  "git.zebra": [\n    "z"\n  ]\n}'
	)
	child.lua([[EmptySaveOk = ShortcutStore:save({})]])
	eq(child.lua_get([[EmptySaveOk]]), true)
	eq(child.lua_get([[ShortcutStore:load()]]), {})
	eq(child.lua_get([[table.concat(vim.fn.readfile(Path), "\n")]]), "{}")
end

T["actions: Invalid shortcut JSON preserves bindings"] = function()
	child.lua([[
		Notifications = {}
		vim.notify = function(msg, level) table.insert(Notifications, { msg = msg, level = level }) end
		ShortcutStore:save({ ["edit.alpha"] = { "a" } })
		vim.fn.writefile({ "not json" }, Path)
	]])

	eq(child.lua_get([[ShortcutStore:load()]]), { ["edit.alpha"] = { "a" } })
	eq(child.lua_get([[#Notifications]]), 1)
	eq(child.lua_get([[Notifications[1].level]]), vim.log.levels.ERROR)
end

T["actions: Unknown action ids are skipped once"] = function()
	child.lua([[
		Notifications = {}
		vim.notify = function(msg, level) table.insert(Notifications, { msg = msg, level = level }) end
		vim.fn.writefile({ '{"edit.alpha":["a"],"missing.action":["m"]}' }, Path)
		FirstLoad = ShortcutStore:load()
		SecondLoad = ShortcutStore:load()
	]])

	eq(child.lua_get([[FirstLoad]]), { ["edit.alpha"] = { "a" } })
	eq(child.lua_get([[SecondLoad]]), { ["edit.alpha"] = { "a" } })
	eq(child.lua_get([[#Notifications]]), 1)
	eq(child.lua_get([[Notifications[1].level]]), vim.log.levels.WARN)
	eq(child.lua_get([[Notifications[1].msg:match("missing.action")]]), "missing.action")
end

T["actions: Hidden actions cannot receive shortcuts"] = function()
	child.lua([[
		Notifications = {}
		vim.notify = function(msg, level) table.insert(Notifications, { msg = msg, level = level }) end
		SaveOk = ShortcutStore:save({ ["command.hidden"] = { "h" } })
	]])

	eq(child.lua_get([[SaveOk]]), false)
	eq(child.lua_get([[vim.uv.fs_stat(Path) == nil]]), true)
	eq(child.lua_get([[Notifications[1].level]]), vim.log.levels.ERROR)
	eq(child.lua_get([[Notifications[1].msg:match("command.hidden")]]), "command.hidden")
end

T["actions: Undiscovered Ex actions are rejected consistently"] = function()
	child.lua([[
		Notifications = {}
		vim.notify = function(msg, level) table.insert(Notifications, { msg = msg, level = level }) end
		vim.fn.writefile({ '{"ex.diffview_open":["g"]}' }, Path)
		BeforeDiscovery, BeforeOk = ShortcutStore:load()
		Catalog:hidden()
		AfterDiscovery, AfterOk = ShortcutStore:load()
	]])

	eq(child.lua_get([[BeforeOk]]), false)
	eq(child.lua_get([[AfterOk]]), false)
	eq(child.lua_get([[BeforeDiscovery]]), {})
	eq(child.lua_get([[AfterDiscovery]]), {})
	eq(child.lua_get([[Notifications[1].msg:match("Hidden action")]]), "Hidden action")
	eq(child.lua_get([[Notifications[2].msg:match("Hidden action")]]), "Hidden action")
end

return T

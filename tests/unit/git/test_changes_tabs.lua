local MiniTest = require("mini.test")

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

T["git: Cycle rules"] = MiniTest.new_set()

T["git: Cycle rules"]["advances through available tabs and then closes"] = function()
	local ok, tabs = pcall(require, "gleb.git.changes.tabs")
	eq(ok, true)
	eq(tabs.next({ active = "local", available = { "local", "branch" }, local_count = 3 }), "branch")
	eq(tabs.next({ active = "branch", available = { "local", "branch" }, local_count = 3 }), "close")
	eq(tabs.next({ active = "local", available = { "local" }, local_count = 3 }), "close")
end

T["git: Cycle rules"]["starts on Branch only when Local is empty and Branch is available"] = function()
	local tabs = require("gleb.git.changes.tabs")
	eq(tabs.first({ active = "local", available = { "local", "branch" }, local_count = 0 }), "branch")
	eq(tabs.first({ active = "local", available = { "local", "branch" }, local_count = 3 }), "local")
	eq(tabs.first({ active = "local", available = { "local" }, local_count = 0 }), "local")
end

return T

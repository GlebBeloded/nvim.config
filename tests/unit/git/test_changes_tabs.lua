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

T["git: Branch summary wording"] = MiniTest.new_set()

T["git: Branch summary wording"]["uses singular and plural commit counts with a short merge-base"] = function()
	local branch = require("gleb.git.changes.branch")
	eq(branch.summary(1, "4ccefde78a71"), "1 commit · merge-base 4ccefde")
	eq(branch.summary(3, "4ccefde78a71"), "3 commits · merge-base 4ccefde")
end

T["git: Branch summary wording"]["parses added modified deleted and renamed paths"] = function()
	local branch = require("gleb.git.changes.branch")
	local output =
		table.concat({ "A", "added.txt", "M", "changed.txt", "D", "deleted.txt", "R100", "old.txt", "new.txt" }, "\0")

	eq(branch.parse_name_status(output), {
		{ status = "added", path = "added.txt" },
		{ status = "modified", path = "changed.txt" },
		{ status = "deleted", path = "deleted.txt" },
		{ status = "renamed", path = "new.txt", orig = "old.txt" },
	})
end

return T

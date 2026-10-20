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

T["git: Commit ages are short relative times"] = MiniTest.new_set()

T["git: Commit ages are short relative times"]["formats each age range at its boundary"] = function()
	local branch = require("gleb.git.changes.branch")
	local seconds = { 30, 3599, 3600, 86399, 86400, 1209599, 1209600, 5183999, 5184000, 31536000 }
	local ages = {}
	for _, value in ipairs(seconds) do
		table.insert(ages, branch.age(value))
	end

	eq(ages, { "now", "59m", "1h", "23h", "1d", "13d", "2w", "8w", "2mo", "1y" })
end

T["git: Commit ages are short relative times"]["parses the commit fields used to calculate ages"] = function()
	local branch = require("gleb.git.changes.branch")
	local output = table.concat({
		"e3254630123456789",
		"07cb52e0123456789",
		"1767312000",
		"wire tax into Total",
		"",
		"07cb52e0123456789",
		"b5435c50123456789 deadbee0123456789",
		"1767301200",
		"add Rate and tax tests",
		"",
	}, "\0")

	eq(branch.parse_commits(output), {
		{
			hash = "e3254630123456789",
			parents = { "07cb52e0123456789" },
			timestamp = 1767312000,
			subject = "wire tax into Total",
		},
		{
			hash = "07cb52e0123456789",
			parents = { "b5435c50123456789", "deadbee0123456789" },
			timestamp = 1767301200,
			subject = "add Rate and tax tests",
		},
	})
	eq(type(branch.now()), "number")
end

return T

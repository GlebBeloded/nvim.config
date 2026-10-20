local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

T["git: Branch base rules pick the default branch"] = function()
	local rows = {
		{ "origin/develop", { ["origin/develop"] = "a", ["origin/main"] = "b" }, "develop" },
		{ vim.NIL, { ["origin/main"] = "a", ["origin/master"] = "b" }, "main" },
		{ vim.NIL, { ["origin/master"] = "a" }, "master" },
		{ vim.NIL, {}, vim.NIL },
	}
	eq(
		child.lua(
			[[local rules = require("gleb.git.base.rules")
		local out = {}
		for i, row in ipairs(...) do
			local origin_head = row[1] ~= vim.NIL and row[1] or nil
			out[i] = rules.default_branch(origin_head, row[2]) or vim.NIL
		end
		return out]],
			{ rows }
		),
		{ "develop", "main", "master", vim.NIL }
	)
end

T["git: Branch base rules parse remote hosts"] = function()
	local urls = {
		"git@pgw.dev:finteqhub/billing.git",
		"ssh://git@pgw.dev:2222/finteqhub/billing.git",
		"https://user@pgw.dev/finteqhub/billing",
		"https://github.com/GlebBeloded/nvim.config.git",
		"/tmp/origin.git",
		"file:///tmp/origin.git",
		"../origin.git",
	}
	eq(
		child.lua(
			[[local rules = require("gleb.git.base.rules")
		local out = {}
		for i, url in ipairs(...) do out[i] = rules.remote_host(url) or vim.NIL end
		return out]],
			{ urls }
		),
		{ "pgw.dev", "pgw.dev", "pgw.dev", "github.com", vim.NIL, vim.NIL, vim.NIL }
	)
end

T["git: Branch base rules list the no-base cases"] = function()
	local oid = string.rep("a", 40)
	local rows = {
		{ vim.NIL, oid, "main" },
		{ "feat/tax", vim.NIL, "main" },
		{ "develop", oid, "develop" },
		{ "main", oid, "develop" },
		{ "master", oid, "main" },
		{ "feat/tax", oid, vim.NIL },
		{ "feat/tax", oid, "main" },
	}
	eq(
		child.lua(
			[[local rules = require("gleb.git.base.rules")
		local out = {}
		for i, row in ipairs(...) do
			local branch = row[1] ~= vim.NIL and row[1] or nil
			local head = row[2] ~= vim.NIL and row[2] or nil
			local default = row[3] ~= vim.NIL and row[3] or nil
			out[i] = rules.skip_reason(branch, head, default) or vim.NIL
		end
		return out]],
			{ rows }
		),
		{
			"detached",
			"unborn",
			"default branch",
			"default branch",
			"default branch",
			"no default",
			vim.NIL,
		}
	)
	local canned = vim.json.encode({ number = 482, state = "OPEN", baseRefName = "release/1.4" })
	eq(
		child.lua(
			[[local rules, canned = require("gleb.git.base.rules"), ...
		return {
			rules.pr_outcome(0, canned, "").kind,
			rules.pr_outcome(0, canned:gsub("OPEN", "MERGED"), "").kind,
			rules.pr_outcome(0, "{", "").kind,
			rules.pr_outcome(1, "", 'no pull requests found for branch "feat/tax"').kind,
			rules.pr_outcome(1, "", "error connecting to pgw.dev").kind,
			rules.pr_outcome(124, "", "").kind,
		}]],
			{ canned }
		),
		{ "open", "none", "none", "none", "failed", "failed" }
	)
end

return T

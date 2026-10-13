local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

local FOLLOWUP = vim.fs.joinpath(H.root, ".archon/scripts/followup.py")
local BRANCH = "loop/x-20260101"
local REASONS = "- new reason"

---@param cmd string[]
---@param cwd string
---@return test.SystemResult
local function git_ok(cmd, cwd)
	local result = H.system(child, vim.list_extend({ "git" }, cmd), cwd, H.GIT_ENV)
	eq(result.code, 0, { fail_reason = table.concat(cmd, " ") .. "\n" .. result.stderr })
	return result
end

--- Repo on branch `auto`; with `proposal`, it holds the active change `x` with that proposal.
---@param proposal? string[]
---@return string
local function make_repo(proposal)
	local repo = H.tempdir(child)
	git_ok({ "init", "-q", "-b", "auto" }, repo)
	if proposal then
		local dir = vim.fs.joinpath(repo, "openspec/changes/x")
		child.fn.mkdir(dir, "p")
		child.fn.writefile(proposal, vim.fs.joinpath(dir, "proposal.md"))
		git_ok({ "add", "-A" }, repo)
	end
	git_ok({ "commit", "-q", "--allow-empty", "-m", "init" }, repo)
	return repo
end

--- Runs followup.py for change `x` in a worktree of `repo` on the rejected branch; returns its JSON.
---@param repo string
---@return { queued: boolean, change: string }
local function followup(repo)
	local worktree = vim.fs.joinpath(H.tempdir(child), "run")
	git_ok({ "worktree", "add", "-q", "-b", BRANCH, worktree, "auto" }, repo)
	local env =
		vim.tbl_extend("force", H.GIT_ENV, { BASE_BRANCH = "auto", INPUTS_CHANGE = "x", INPUTS_REASONS = REASONS })
	local result = H.system(child, { "python3", FOLLOWUP }, worktree, env)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	return vim.json.decode(result.stdout)
end

---@param repo string
---@param path string
---@return string[]
local function read_auto(repo, path)
	return vim.split(git_ok({ "show", "auto:" .. path }, repo).stdout, "\n", { trimempty = true })
end

---@param lines string[]
---@param pattern string
---@return string[]
local function matching(lines, pattern)
	return vim.tbl_filter(function(line)
		return line:find(pattern) ~= nil
	end, lines)
end

---@param repo string
---@param name string
---@return boolean
local function exists(repo, name)
	return child.lua_get("vim.uv.fs_stat(...) ~= nil", { vim.fs.joinpath(repo, name) })
end

T["loop: Rejected active change is re-queued in place"] = function()
	local repo = make_repo({
		"## Why",
		"w",
		"",
		"Kind: bug",
		"Adopt: loop/x",
		"",
		"## What Changes",
		"- c",
		"",
		"## Rejected run",
		"- old reason",
		"",
		"## Impact",
		"- i",
	})
	eq(followup(repo), { queued = true, change = "x" })
	eq(exists(repo, "openspec/changes/followup-x"), false)
	local proposal = read_auto(repo, "openspec/changes/x/proposal.md")
	eq(matching(proposal, "^Adopt:"), { "Adopt: " .. BRANCH })
	eq(#matching(proposal, "^## Rejected run$"), 1)
	eq(#matching(proposal, "^%- new reason$"), 1)
	eq(#matching(proposal, "old reason"), 0)
	eq(#matching(proposal, "^## Impact$"), 1)
	eq(
		vim.trim(git_ok({ "log", "-1", "--format=%s", "auto" }, repo).stdout),
		"chore(openspec): re-queue x from " .. BRANCH
	)
	eq(git_ok({ "status", "--porcelain", "--untracked-files=no" }, repo).stdout, "")
	eq(exists(repo, ".git/nvim-ship.lock"), false)
end

--- Index of the first line equal to `wanted`, or nil.
---@param lines string[]
---@param wanted string
---@return integer?
local function index_of(lines, wanted)
	return vim.iter(ipairs(lines)):find(function(_, line)
		return line == wanted
	end)
end

T["loop: Adopt line is added to a proposal without one"] = function()
	local adopt = "Adopt: " .. BRANCH
	local repo = make_repo({ "## Why", "w", "", "Kind: bug", "", "## What Changes", "- c" })
	followup(repo)
	local proposal = read_auto(repo, "openspec/changes/x/proposal.md")
	eq(proposal[index_of(proposal, "Kind: bug") + 1], adopt)

	repo = make_repo({ "## Why", "w", "", "## What Changes", "- c" })
	followup(repo)
	proposal = read_auto(repo, "openspec/changes/x/proposal.md")
	local at = index_of(proposal, adopt)
	eq(at ~= nil and at > index_of(proposal, "## Why") and at < index_of(proposal, "## What Changes"), true, {
		fail_reason = table.concat(proposal, "\n"),
	})
end

T["loop: Rejected archived change gets a follow-up change"] = function()
	local repo = make_repo()
	eq(followup(repo), { queued = true, change = "followup-x" })
	local proposal = read_auto(repo, "openspec/changes/followup-x/proposal.md")
	eq(matching(proposal, "^Adopt:"), { "Adopt: " .. BRANCH })
	eq(#matching(proposal, "^%- new reason$"), 1)
end

return T

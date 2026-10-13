-- Fixture repos for the e2e workflows: tests/fixtures/build.sh builds (or
-- reuses) a cached fixture, copy() gives each test file its own copy plus the
-- manifest of facts the tests assert.
local H = require("tests.helpers")

local M = {}

---@class fixtures.Location
---@field path string repo-relative
---@field line integer 1-based
---@field col integer 1-based byte column of the identifier

---@class fixtures.Entry
---@field path string repo-relative
---@field staged boolean
---@field untracked boolean

---@class fixtures.Manifest
---@field references? table<string, fixtures.Location[]> by identifier, declaration first
---@field files? fixtures.Entry[] one entry per changed-file listing (staged and unstaged apart)
---@field hunks? table<string, integer[]> worktree start lines of unstaged hunks, by path

--- Offline Go env with caches that outlive the stack's temp HOME (warm gopls).
---@return table<string, string>
function M.go_env()
	local go = vim.fs.joinpath(H.root, ".tests/go")
	return {
		GOCACHE = vim.fs.joinpath(go, "cache"),
		GOMODCACHE = vim.fs.joinpath(go, "mod"),
		GOPLSCACHE = vim.fs.joinpath(go, "gopls"),
		GOTOOLCHAIN = "local",
		GOPROXY = "off",
		GOFLAGS = "-mod=mod",
		GOTELEMETRY = "off",
	}
end

---@param cmd string[]
---@param env? table<string, string>
---@return string stdout
local function run(cmd, env)
	local result = vim.system(cmd, { text = true, env = env }):wait(300000)
	assert(result.code == 0, table.concat(cmd, " ") .. " failed: " .. (result.stderr or ""))
	return result.stdout
end

--- Cache dir of fixture `name` (built on a miss).
---@param name string
---@return string
local function build(name)
	return vim.trim(run({ vim.fs.joinpath(H.root, "tests/fixtures/build.sh"), name }, M.go_env()))
end

--- Copy fixture `name` to `dest` (must not exist).
---@param name string
---@param dest string
---@return string root the copy
---@return fixtures.Manifest
function M.copy(name, dest)
	local cache = build(name)
	vim.fn.mkdir(vim.fs.dirname(dest), "p")
	run({ "cp", "-R", vim.fs.joinpath(cache, "repo"), dest })
	local manifest = table.concat(vim.fn.readfile(vim.fs.joinpath(cache, "manifest.json")), "\n")
	return dest, vim.json.decode(manifest)
end

return M

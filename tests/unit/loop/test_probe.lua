local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality

local T = MiniTest.new_set()

local ASYNC = "LSP restart and tree and panel renders are async: wait for the end state, not for attachment."

--- `make -s probe` in this checkout with `env` (outer make's jobserver flags dropped).
---@param env table<string, string>
---@return vim.SystemCompleted
local function probe(env)
	env = vim.tbl_extend("force", { MAKEFLAGS = "", MFLAGS = "", MAKELEVEL = "" }, env)
	return vim.system({ "make", "-s", "probe" }, { cwd = H.root, env = env, text = true }):wait(90000)
end

---@param path string
---@return string
local function read(path)
	return table.concat(vim.fn.readfile(path), "\n")
end

---@param text string
---@param needle string
local function has(text, needle)
	eq(text:find(needle, 1, true) ~= nil, true, { fail_reason = "missing: " .. needle })
end

T["loop: Probe prints the snippet's return value"] = function()
	local result = probe({ PROBE = "return vim.g.mapleader" })
	eq(result.code, 0, { fail_reason = result.stderr })
	local lines = vim.split(vim.trim(result.stdout), "\n")
	eq(lines[#lines], '" "')
end

T["loop: Probe exits non-zero on an error"] = function()
	local script = vim.fn.tempname() .. ".lua"
	vim.fn.writefile({ 'print("before")', 'error("probe-boom")' }, script)
	local result = probe({ SCRIPT = script })
	vim.fn.delete(script)
	eq(result.code ~= 0, true)
	has(result.stdout, "before")
	has(result.stderr, "probe-boom")
end

T["loop: Agent prompts and context pack point probes at make probe"] = function()
	for _, name in ipairs({ "implement.md", "fix.md", "explore-bug.md" }) do
		local prompt = read(vim.fs.joinpath(H.root, ".archon/commands", name))
		has(prompt, "make probe SCRIPT=")
		has(prompt, ASYNC)
	end

	local repo, artifacts = vim.fn.tempname(), vim.fn.tempname()
	H.write_files(repo, {
		["docs/workflow.md"] = "## Loop lessons\n\n## The loop\n",
		["openspec/changes/c/tasks.md"] = "## 1. Task\n- [ ] 1.1 todo",
	})
	vim.fn.mkdir(artifacts, "p")
	local cmd = { "python3", vim.fs.joinpath(H.root, ".archon/scripts/context_pack.py") }
	local env = { INPUTS_CHANGE = "c", ARTIFACTS_DIR = artifacts }
	local result = vim.system(cmd, { cwd = repo, env = env, text = true }):wait(30000)
	eq(result.code, 0, { fail_reason = result.stderr })
	local pack = read(vim.fs.joinpath(artifacts, "context.md"))
	has(pack, "make probe SCRIPT=")
	has(pack, ASYNC)
end

return T

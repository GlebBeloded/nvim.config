local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

local SCRIPTS = vim.fs.joinpath(H.root, ".archon/scripts")

---@param path string
---@return string
local function read(path)
	return table.concat(vim.fn.readfile(path), "\n")
end

---@param root string
---@param files table<string, string>
local function write(root, files)
	for path, content in pairs(files) do
		local target = vim.fs.joinpath(root, path)
		vim.fn.mkdir(vim.fs.dirname(target), "p")
		vim.fn.writefile(vim.split(content, "\n", { plain = true }), target)
	end
end

--- `bin/<name>` in `dir`: an executable shell script.
---@param dir string
---@param name string
---@param body string
---@return string bin directory to prepend to PATH
local function fake_tool(dir, name, body)
	local bin = vim.fs.joinpath(dir, "bin")
	write(bin, { [name] = "#!/bin/sh\n" .. body })
	vim.fn.setfperm(vim.fs.joinpath(bin, name), "rwxr-xr-x")
	return bin
end

---@param text string
---@param needle string
local function has(text, needle)
	eq(text:find(needle, 1, true) ~= nil, true, { fail_reason = ("missing %q in:\n%s"):format(needle, text) })
end

---@return string red check log as tests/check.sh prints it: lint first, a long test section after it
local function red_check_log()
	local lines = {
		"FAIL lint             0.2 s",
		"ok   trace            0.5 s",
		"FAIL test            44.9 s",
		"",
		"===== lint =====",
		"error[undefined_variable]: `kmap` is not defined",
		"    ┌─ lua/gleb/keymaps.lua:134:1",
		"",
		"===== test =====",
		"\27[1mTotal number of cases:\27[0m 300",
	}
	for i = 1, 200 do
		table.insert(lines, ("tests/integration/a/test_a.lua | a: case %d: \27[1;32mo\27[0m"):format(i))
	end
	vim.list_extend(lines, {
		"\27[1mFails (2) and Notes (0)\27[0m",
		"\27[1;31mFAIL\27[0m in tests/integration/a/test_a.lua | a: first broken case:",
		"  Failed expectation for equality",
		"\27[1;31mFAIL\27[0m in tests/screen/statusline/test_b.lua | statusline: second broken case:",
	})
	for i = 1, 100 do
		table.insert(lines, ("  Traceback line %d"):format(i))
	end
	vim.list_extend(lines, { "", "check: FAILED: lint test (46.2 s)" })
	return table.concat(lines, "\n")
end

T["loop: Gate failures keep an early lint section"] = function()
	local repo = H.tempdir(child)
	local artifacts = H.tempdir(child)
	local scratch = H.tempdir(child)
	write(scratch, { ["check.log"] = red_check_log() })
	local bin = fake_tool(scratch, "make", ('cat "%s/check.log"\nexit 1'):format(scratch))
	local env = { ARTIFACTS_DIR = artifacts, INPUTS_CHANGE = "", PATH = bin .. ":" .. vim.env.PATH }

	local result = H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, "gate.py") }, repo, env)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	local verdict = vim.json.decode(result.stdout)
	eq(verdict.green, false)
	local failures = verdict.failures
	has(failures, vim.fs.joinpath(artifacts, "check-1.log"))
	has(failures, "FAIL lint             0.2 s")
	has(failures, "check: FAILED: lint test (46.2 s)")
	has(failures, "error[undefined_variable]: `kmap` is not defined")
	has(failures, "tests/integration/a/test_a.lua | a: first broken case")
	has(failures, "tests/screen/statusline/test_b.lua | statusline: second broken case")
	eq(failures:find("\27", 1, true), nil)
	eq(failures:find(" | a: case 1: o", 1, true), nil)
	eq(#failures <= 5000, true)
	eq(read(vim.fs.joinpath(artifacts, "check-1.log")):find("\27", 1, true), nil)
end

T["loop: Gate gives language servers a long timeout"] = function()
	local repo = H.tempdir(child)
	local artifacts = H.tempdir(child)
	local scratch = H.tempdir(child)
	local bin = fake_tool(scratch, "make", ('echo "$LSP_TIMEOUT_MS" >"%s/lsp_timeout"'):format(scratch))
	local env = { ARTIFACTS_DIR = artifacts, INPUTS_CHANGE = "", PATH = bin .. ":" .. vim.env.PATH }

	local result = H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, "gate.py") }, repo, env)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	eq(read(vim.fs.joinpath(scratch, "lsp_timeout")), "120000")
end

---@param value string?
---@param default_ms integer
---@return integer
local function lsp_timeout_with(value, default_ms)
	local saved = vim.env.LSP_TIMEOUT_MS
	vim.env.LSP_TIMEOUT_MS = value
	local ok, ms = pcall(H.lsp_timeout, default_ms)
	vim.env.LSP_TIMEOUT_MS = saved
	assert(ok, ms)
	return ms
end

T["loop: LSP waits in tests honor LSP_TIMEOUT_MS"] = function()
	eq(lsp_timeout_with(nil, 10000), 10000)
	eq(lsp_timeout_with("", 10000), 10000)
	eq(lsp_timeout_with("abc", 10000), 10000)
	eq(lsp_timeout_with("0", 10000), 10000)
	eq(lsp_timeout_with("120000", 10000), 120000)
end

T["loop: Types output drops LuaLS progress lines"] = function()
	local repo = H.tempdir(child)
	local progress = [[printf '>>>>>>>>=====  12/369 [Found 5 problems in 1 files]\r>>>>>>>>>>>>= 300/369\n']]
	local diagnostic =
		[[printf 'lua/x.lua:1:1 [Warning] Undefined global `kmap`.\nDiagnosis complete, 1 problems found\n']]
	local luals = ('[ "$1" = --version ] && { echo 3.0.0; exit 0; }\n%s\n%s\nexit 1'):format(progress, diagnostic)
	local bin = fake_tool(H.tempdir(child), "lua-language-server", luals)
	local env = { PATH = bin .. ":" .. vim.env.PATH, VIMRUNTIME = vim.env.VIMRUNTIME }

	local result = H.system(child, { "sh", vim.fs.joinpath(H.root, "tests/types.sh") }, repo, env)
	eq(result.code, 1, { fail_reason = result.stdout .. result.stderr })
	has(result.stdout, "lua/x.lua:1:1 [Warning] Undefined global `kmap`.")
	has(result.stdout, "Diagnosis complete, 1 problems found")
	eq(result.stdout:find("/369", 1, true), nil, { fail_reason = result.stdout })
end

T["loop: Fix prompt reruns failed files and names reference commits"] = function()
	local fix = read(vim.fs.joinpath(H.root, ".archon/commands/fix.md"))
	has(fix, "Rerun every test file named in a `FAIL in …` line")
	has(fix, "`tests/screen/<area>`")
	has(fix, "never a `check-*.log` glob")
	has(fix, "at most `-C 3`")
	has(fix, "never a broad multi-word `rg` over\n`lua tests`")
	has(fix, "only when its cell diff is limited to UI that\na merged or base commit changed; name that commit")
	eq(fix:find("Rerun only", 1, true), nil)
end

---@param tasks string
---@return boolean has_task
local function pack_has_task(tasks)
	local repo = H.tempdir(child)
	local artifacts = H.tempdir(child)
	write(repo, {
		["docs/workflow.md"] = "## Loop lessons\n\n## The loop\n",
		["openspec/changes/c/tasks.md"] = tasks,
	})
	local env = { INPUTS_CHANGE = "c", ARTIFACTS_DIR = artifacts }
	local result = H.system(child, { "python3", vim.fs.joinpath(SCRIPTS, "context_pack.py") }, repo, env)
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	local out = vim.json.decode(result.stdout)
	eq(out.context, vim.fs.joinpath(artifacts, "context.md"))
	return out.has_task
end

T["loop: Context pack reports when no task is left"] = function()
	eq(pack_has_task("## 1. Done\n- [x] 1.1 a"), false)
	eq(pack_has_task("## 1. Todo\n- [x] 1.1 a\n- [ ] 1.2 b"), true)
	local workflow = read(vim.fs.joinpath(H.root, ".archon/workflows/nvim-deliver/nvim-deliver.yaml"))
	has(
		workflow,
		'- id: implement\n          command: implement\n          depends_on: [pack]\n          when: "$pack.output.has_task == true"'
	)
end

T["loop: Startup timing fails on a startup error"] = function()
	-- a checkout copy whose init.lua fails: the harness finds its root from its own file path
	local root = H.tempdir(child)
	write(root, { ["init.lua"] = 'error("smoke-startup-boom")' })
	for _, file in ipairs({ "minimal_init.lua", "helpers.lua", "smoke/run.lua", "smoke/budget.lua" }) do
		write(root, { ["tests/" .. file] = read(vim.fs.joinpath(H.root, "tests", file)) })
	end
	local env = { TEST_DEPS_DIR = vim.fs.joinpath(H.root, ".tests/deps"), STARTUP_BUDGET_MS = "100000" }
	local cmd = { vim.v.progpath, "-u", "tests/minimal_init.lua", "-l", "tests/smoke/run.lua", "startup" }

	local result = H.system(child, cmd, root, env)
	eq(result.code ~= 0, true, { fail_reason = result.stdout .. result.stderr })
	has(result.stdout, "FAIL startup exited cleanly without stderr")
	has(result.stdout, "smoke-startup-boom")
end

return T

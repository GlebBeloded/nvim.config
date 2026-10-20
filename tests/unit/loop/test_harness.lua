local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

T["loop: Test children keep the Go build cache under .tests"] = function()
	local cache = vim.fs.joinpath(H.root, ".tests/go/cache")
	eq({ child.lua_get("vim.env.GOCACHE"), child.lua_get("vim.env.GOMAXPROCS") }, { cache, "2" })
	local out = H.system(child, { "go", "env", "GOCACHE" }, H.root)
	eq(vim.trim(out.stdout), cache, { fail_reason = out.stderr })
end

T["loop: Product test runs skip the loop's own tests"] = function()
	local runner = require("tests.runner")
	local saved = { FILE = vim.env.FILE, CAPS = vim.env.CAPS, LOOP_TESTS = vim.env.LOOP_TESTS }
	local function files(env)
		vim.env.FILE, vim.env.CAPS, vim.env.LOOP_TESTS = env.FILE, env.CAPS, env.LOOP_TESTS
		local found = runner.find_files("unit")
		vim.env.FILE, vim.env.CAPS, vim.env.LOOP_TESTS = saved.FILE, saved.CAPS, saved.LOOP_TESTS
		return found
	end
	local function has(list, file)
		return vim.tbl_contains(list, file)
	end
	local sandbox, gate = "tests/unit/shortcuts/test_sandbox.lua", "tests/unit/loop/test_gate.lua"
	local product = files({})
	eq({ has(product, sandbox), has(product, gate), has(product, "tests/unit/pr/test_gh.lua") }, { false, false, true })
	local only = files({ LOOP_TESTS = "only" })
	eq({ has(only, sandbox), has(only, gate), has(only, "tests/unit/pr/test_gh.lua") }, { true, true, false })
	eq(has(files({ CAPS = "loop" }), gate), true)
	eq(has(files({ LOOP_TESTS = "1" }), sandbox), true)
end

T["loop: A test directory runs its files"] = function()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(vim.fs.joinpath(dir, "area/nested"), "p")
	vim.fn.writefile({}, vim.fs.joinpath(dir, "area/nested/test_b.lua"))
	vim.fn.writefile({}, vim.fs.joinpath(dir, "area/test_a.lua"))
	vim.fn.writefile({}, vim.fs.joinpath(dir, "area/helper.lua"))
	local files = child.lua(
		[[
		vim.env.FILE = ...
		return require("tests.runner").find_files("unit")
	]],
		{ vim.fs.joinpath(dir, "area") }
	)
	eq(files, { vim.fs.joinpath(dir, "area/nested/test_b.lua"), vim.fs.joinpath(dir, "area/test_a.lua") })
end

T["loop: Hard-rule checks leave the real index alone"] = function()
	local repo = vim.fn.tempname()
	vim.fn.mkdir(repo, "p")
	local function git(...)
		local result = H.system(child, { "git", ... }, repo, H.GIT_ENV)
		eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
		return result.stdout
	end
	git("init", "-q", "-b", "auto")
	vim.fn.writefile({ "x" }, vim.fs.joinpath(repo, "README"))
	git("add", "README")
	git("commit", "-qm", "init")
	vim.fn.mkdir(vim.fs.joinpath(repo, "tests"), "p")
	vim.fn.writefile({ "-- new" }, vim.fs.joinpath(repo, "tests/test_new.lua"))
	local result = H.system(child, {
		"python3",
		"-c",
		"import sys; sys.path.insert(0, sys.argv[1]); import integrity; print(integrity.diff('tests/'))",
		vim.fs.joinpath(H.root, ".archon/scripts"),
	}, repo, vim.tbl_extend("force", H.GIT_ENV, { BASE_BRANCH = "auto" }))
	eq(result.code, 0, { fail_reason = result.stdout .. result.stderr })
	eq(result.stdout:find("tests/test_new.lua", 1, true) ~= nil, true)
	eq(git("diff", "--cached", "--name-only"), "")
end

T["loop: Reusable child resets case state"] = function()
	local hooks = getmetatable(H.child_set(child, child.start_bare, { reuse = true })).opts.hooks
	hooks.pre_once()
	hooks.pre_case()
	local reusable_pid = child.fn.getpid()
	local reusable_cwd = child.fn.getcwd()
	local changed_cwd = vim.fn.tempname()
	vim.fn.mkdir(changed_cwd, "p")
	child.cmd("tabnew")
	child.cmd("enew")
	child.fn.chdir(changed_cwd)
	child.lua("_G.ReusableChildCaseState = true")
	eq({ #child.api.nvim_list_tabpages(), child.fn.getcwd() }, { 2, vim.uv.fs_realpath(changed_cwd) })
	hooks.pre_case()
	eq(child.fn.getpid(), reusable_pid)
	eq({
		child.fn.getcwd(),
		#child.api.nvim_list_tabpages(),
		#child.api.nvim_list_bufs(),
		child.lua_get("_G.ReusableChildCaseState == nil"),
	}, { reusable_cwd, 1, 1, true })
end

T["loop: Fresh child remains the default"] = function()
	local hooks = getmetatable(H.child_set(child, child.start_bare)).opts.hooks
	hooks.pre_case()
	local first_pid = child.fn.getpid()
	hooks.pre_case()
	eq(child.fn.getpid() == first_pid, false)
end

return T

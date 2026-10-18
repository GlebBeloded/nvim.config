local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

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

return T

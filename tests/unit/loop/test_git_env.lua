local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local T = H.child_set(child, child.start_bare)

T["loop: Test bootstrap ignores a leaked GIT_DIR"] = function()
	for _, path in ipairs({ "tests/bootstrap.sh", "tests/fixtures/build.sh" }) do
		local text = table.concat(vim.fn.readfile(vim.fs.joinpath(H.root, path)), "\n")
		eq(text:find("unset $(git rev-parse --local-env-vars)", 1, true) ~= nil, true, { fail_reason = path })
	end
	-- the idiom keeps `git init <dir>` off the repository a leaked GIT_DIR names
	local repo = H.tempdir(child)
	eq(H.system(child, { "git", "init", "-q", repo }, repo, H.GIT_ENV).code, 0)
	local target = vim.fs.joinpath(H.tempdir(child), "dep")
	local env = vim.tbl_extend("force", H.GIT_ENV, { GIT_DIR = vim.fs.joinpath(repo, ".git") })
	local script = 'unset $(git rev-parse --local-env-vars); git init -q "$1"'
	eq(H.system(child, { "sh", "-c", script, "sh", target }, repo, env).code, 0)
	local bare = H.system(child, { "git", "-C", repo, "config", "--get", "core.bare" }, repo, H.GIT_ENV)
	eq(vim.trim(bare.stdout), "false")
	eq(vim.fn.isdirectory(vim.fs.joinpath(target, ".git")), 1)
end

return T

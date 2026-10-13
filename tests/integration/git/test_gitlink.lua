local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

---@return string file
local function repo_file()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local file = vim.fs.joinpath(dir, "a.txt")
	vim.fn.writefile({ "one", "two", "three", "four", "five" }, file)
	local function git(args)
		vim.system(vim.list_extend({ "git" }, args), { cwd = dir }):wait()
	end
	git({ "init", "-q", "-b", "main" })
	git({ "config", "user.name", "t" })
	git({ "config", "user.email", "t@t" })
	git({ "add", "a.txt" })
	git({ "commit", "-qm", "init" })
	git({ "remote", "add", "origin", "https://github.com/owner/repo.git" })
	git({ "update-ref", "refs/remotes/origin/main", "HEAD" })
	return file
end

local T = H.child_set(child, child.start_config)

T["git: Gitlink copies range URL"] = function()
	child.cmd("edit " .. vim.fn.fnameescape(repo_file()))
	child.type_keys("3GV5G", ":Gitlink<CR>")
	eq(child.fn.getreg("+"):match("#L%d+%-L%d+$"), "#L3-L5")
end

return T

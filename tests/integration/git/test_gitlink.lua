local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

---@param dir string
---@param args string[]
local function git(dir, args)
	local result = vim.system(vim.list_extend({ "git" }, args), { cwd = dir }):wait()
	eq(result.code, 0)
end

---@return string file
local function repo_file()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local file = vim.fs.joinpath(dir, "a.txt")
	vim.fn.writefile({ "one", "two", "three", "four", "five" }, file)
	git(dir, { "init", "-q", "-b", "main" })
	git(dir, { "config", "user.name", "t" })
	git(dir, { "config", "user.email", "t@t" })
	git(dir, { "add", "a.txt" })
	git(dir, { "commit", "-qm", "init" })
	git(dir, { "remote", "add", "origin", "https://github.com/owner/repo.git" })
	git(dir, { "update-ref", "refs/remotes/origin/main", "HEAD" })
	return file
end

local T = H.child_set(child, child.start_config)

T["git: Gitlink copies range URL"] = function()
	child.cmd("edit " .. vim.fn.fnameescape(repo_file()))
	child.type_keys("3GV5G", ":Gitlink<CR>")
	eq(child.fn.getreg("+"):match("#L%d+%-L%d+$"), "#L3-L5")
	eq(child.fn.mode(), "n")
	eq(child.api.nvim_win_get_cursor(0), { 3, 0 })
end

T["git: Gitlink range preserves editor state"] = function()
	child.cmd("edit " .. vim.fn.fnameescape(repo_file()))
	child.type_keys("ggVj<Esc>", "4G2l")
	local cursor = child.api.nvim_win_get_cursor(0)
	local visual_start = child.api.nvim_buf_get_mark(0, "<")
	local visual_end = child.api.nvim_buf_get_mark(0, ">")

	child.cmd("3,5Gitlink")

	eq(child.fn.mode(), "n")
	eq(child.api.nvim_win_get_cursor(0), cursor)
	eq(child.api.nvim_buf_get_mark(0, "<"), visual_start)
	eq(child.api.nvim_buf_get_mark(0, ">"), visual_end)
end

T["git: Gitlink range failure restores editor state"] = function()
	child.cmd("edit " .. vim.fn.fnameescape(repo_file()))
	child.type_keys("ggVj<Esc>", "4G2l")
	local cursor = child.api.nvim_win_get_cursor(0)
	local visual_start = child.api.nvim_buf_get_mark(0, "<")
	local visual_end = child.api.nvim_buf_get_mark(0, ">")
	child.lua([[require("gitlinker").get_buf_range_url = function() error("gitlink test failure", 0) end]])

	local result = child.lua([[
		local ok, err = pcall(vim.cmd, "3,5Gitlink")
		return { ok, err }
	]])

	eq(result[1], false)
	eq(result[2]:find("gitlink test failure", 1, true) ~= nil, true)
	eq(child.fn.mode(), "n")
	eq(child.api.nvim_win_get_cursor(0), cursor)
	eq(child.api.nvim_buf_get_mark(0, "<"), visual_start)
	eq(child.api.nvim_buf_get_mark(0, ">"), visual_end)
end

return T

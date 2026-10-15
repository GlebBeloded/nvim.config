-- Reference screenshot of the neo-tree help (`?`) in the git_status tree (tests/screenshots/).
-- Update with `make screenshots` (UPDATE_SCREENSHOTS=1) after an intended change.
local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local ASYNC_MS = 3000
-- Fixed path so the `GIT STATUS for` header is the same on every run.
local REPO = "/tmp/gleb-nvim-git-status-help"
local FILE = "lua/gleb/file_tree/init.lua"

---@param args string[]
local function git(args)
	vim.system(vim.list_extend({ "git", "-c", "user.name=t", "-c", "user.email=t@t" }, args), { cwd = REPO }):wait()
end

--- Recreate REPO with FILE committed and then modified.
local function modified_repo()
	vim.fn.delete(REPO, "rf")
	local path = vim.fs.joinpath(REPO, FILE)
	vim.fn.mkdir(vim.fs.dirname(path), "p")
	vim.fn.writefile({ "one" }, path)
	git({ "init", "-q" })
	git({ "add", FILE })
	git({ "commit", "-qm", "init" })
	vim.fn.writefile({ "two" }, path)
end

local function start()
	modified_repo()
	child.start_config()
	child.o.lines, child.o.columns = 40, 100
	child.wait_very_lazy()
	child.cmd("cd " .. REPO .. " | enew | Neotree git_status")
	eq(child.wait([[vim.bo.filetype == "neo-tree" and vim.fn.search("init.lua", "nw") > 0]], ASYNC_MS), true)
end

---@param screenshot table
---@return string
local function screen_text(screenshot)
	return table.concat(vim.tbl_map(table.concat, screenshot.text), "\n")
end

local T = H.child_set(child, start)

T["file-tree: Help lists the moved git status keys"] = function()
	child.type_keys("?")
	eq(child.wait([[vim.fn.getline(1):find("Press the corresponding key", 1, true) ~= nil]], ASYNC_MS), true)

	local screenshot = child.get_screenshot()
	local text = screen_text(screenshot)
	for _, row in ipairs({
		"X -> Tree: Revert Git Tree File",
		"c -> Tree: Copy Tree Node",
		"gc -> Tree: Commit Git Changes with AI",
	}) do
		eq({ row, text:find(" " .. row, 1, true) ~= nil }, { row, true })
	end
	eq(text:find(" gr -> ", 1, true), nil)
	H.expect_screenshot(screenshot)
end

return T

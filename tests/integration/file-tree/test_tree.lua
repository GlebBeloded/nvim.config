local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local ASYNC_MS = 3000

--- Temp git repo with one committed file that has an unstaged change.
---@return string dir
local function modified_repo()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local file = vim.fs.joinpath(dir, "a.txt")
	vim.fn.writefile({ "one" }, file)
	vim.system({ "git", "init", "-q" }, { cwd = dir }):wait()
	vim.system({ "git", "add", "a.txt" }, { cwd = dir }):wait()
	vim.system({ "git", "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "init" }, { cwd = dir }):wait()
	vim.fn.writefile({ "two" }, file)
	return dir
end

---@return boolean
local function current_tab_has_neo_tree()
	return child.lua_get([[vim.iter(vim.api.nvim_tabpage_list_wins(0)):any(function(win)
		return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree"
	end)]])
end

---@param dir string
---@param args string[]
---@return string stdout
local function git(dir, args)
	return vim.system(vim.list_extend({ "git" }, args), { cwd = dir, text = true }):wait().stdout
end

--- Open the git_status tree on `dir` with the cursor on `a.txt`.
---@param dir string
local function open_git_status(dir)
	child.start_config()
	child.wait_very_lazy()
	child.cmd("cd " .. dir .. " | enew | Neotree git_status")
	eq(child.wait([[vim.bo.filetype == "neo-tree" and vim.fn.search("a.txt", "nw") > 0]], ASYNC_MS), true)
	child.lua([[vim.fn.search("a.txt")]])
end

--- Press X on the cursor node and answer the neo-tree confirm popup.
---@param answer "y"|"n"
local function revert_with_answer(answer)
	child.type_keys("X")
	eq(child.wait([[vim.fn.getline("."):find(" y/n: ", 1, true) ~= nil]], ASYNC_MS), true)
	child.type_keys(answer, "<CR>")
end

local T = MiniTest.new_set({ hooks = { post_once = child.stop } })

T["file-tree: Filesystem tree opens on the left at width 35"] = function()
	child.start_config()
	child.cmd("cd " .. H.root .. " | enew | Neotree filesystem")
	eq(child.wait([[vim.bo.filetype == "neo-tree"]], 3000), true)

	local leftmost = child.lua_get([[vim.fn.win_getid(1)]])
	eq(child.lua_get("vim.bo[vim.api.nvim_win_get_buf(...)].filetype", { leftmost }), "neo-tree")
	eq(child.api.nvim_win_get_width(leftmost), 35)
end

T["file-tree: Missing neo-tree is tolerated"] = function()
	child.start_bare()

	eq(child.lua_get([[pcall(require, "gleb.file_tree")]]), true)
end

T["file-tree: q closes preview and tree"] = function()
	child.start_config()
	child.wait_very_lazy()
	-- codediff view.create crashes until fix-diff-preview-codediff-crash; this case asserts tab state only
	child.lua([[require("codediff.ui.view").create = function() vim.cmd("tabnew") end]])
	child.cmd("cd " .. modified_repo() .. " | enew")
	child.lua([[DiffPreview = require("gleb.file_tree.diff_preview")]])
	local original = child.api.nvim_get_current_tabpage()
	child.cmd("Neotree git_status")
	eq(child.wait([[vim.bo.filetype == "neo-tree" and vim.fn.search("a.txt", "nw") > 0]], ASYNC_MS), true)

	child.type_keys("j")
	eq(child.wait("DiffPreview.state.diff_tab ~= nil", ASYNC_MS), true)
	eq(child.wait([[vim.bo.filetype == "neo-tree"]], ASYNC_MS), true)
	local diff_tab = child.lua_get("DiffPreview.state.diff_tab")
	child.type_keys("q")

	eq(child.api.nvim_get_current_tabpage(), original)
	eq(child.api.nvim_tabpage_is_valid(diff_tab), false)
	eq(child.lua_get("DiffPreview.state.current_file"), vim.NIL)
	eq(child.lua_get("DiffPreview.state.original_tab"), vim.NIL)
	eq(current_tab_has_neo_tree(), false)
end

T["file-tree: X reverts a file after confirmation"] = function()
	local dir = modified_repo()
	open_git_status(dir)

	revert_with_answer("y")

	eq(
		vim.wait(ASYNC_MS, function()
			return git(dir, { "status", "--porcelain" }) == ""
		end, 20),
		true
	)
	eq(vim.fn.readfile(vim.fs.joinpath(dir, "a.txt")), { "one" })
end

T["file-tree: X keeps a file when revert is declined"] = function()
	local dir = modified_repo()
	open_git_status(dir)

	revert_with_answer("n")

	eq(child.wait([[vim.bo.filetype == "neo-tree"]], ASYNC_MS), true)
	eq(vim.fn.readfile(vim.fs.joinpath(dir, "a.txt")), { "two" })
	eq(git(dir, { "status", "--porcelain" }), " M a.txt\n")
end

T["file-tree: gr keeps its global meaning in git status tree"] = function()
	open_git_status(modified_repo())

	eq(child.lua_get([[vim.fn.maparg("gr", "n", false, true).buffer]]), 0)
	eq(
		child.lua_get([[vim.fn.maparg("gr", "n", false, true).callback == require("telescope.builtin").lsp_references]]),
		true
	)
end

return T

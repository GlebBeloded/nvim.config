local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local ASYNC_MS = 3000

local function start()
	child.start_config()
	child.wait_very_lazy()
	child.lua([[require("codediff.ui.view").create = function() vim.cmd("tabnew") end]])
end

---@param args string[]
---@param dir string
local function git(args, dir)
	vim.system(vim.list_extend({ "git" }, args), { cwd = dir }):wait()
end

--- Temp repo with `files` committed.
---@param files string[]
---@return string dir
local function staging_repo(files)
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	for _, name in ipairs(files) do
		vim.fn.mkdir(vim.fs.dirname(vim.fs.joinpath(dir, name)), "p")
		vim.fn.writefile({ "one" }, vim.fs.joinpath(dir, name))
	end
	git({ "init", "-q" }, dir)
	git(vim.list_extend({ "add", "--" }, files), dir)
	git({ "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "init" }, dir)
	return dir
end

---@param dir string
---@param name string
local function modify(dir, name)
	vim.fn.writefile({ "two" }, vim.fs.joinpath(dir, name))
end

---@param dir string
---@return string[]
local function staged(dir)
	local out = vim.system({ "git", "diff", "--cached", "--name-only" }, { cwd = dir, text = true }):wait().stdout
	return vim.split(vim.trim(out or ""), "\n", { trimempty = true })
end

---@param dir string
---@param name string
---@param want boolean
---@return boolean
local function wait_staged(dir, name, want)
	return vim.wait(ASYNC_MS, function()
		return vim.list_contains(staged(dir), name) == want
	end, 50)
end

---@param dir string
local function open_in_repo(dir)
	child.cmd("cd " .. dir .. " | enew | Neotree git_status")
end

---@param dir string
local function open_from_outside(dir)
	local outside = vim.fn.tempname()
	vim.fn.mkdir(outside, "p")
	child.cmd("cd " .. outside .. " | enew | Neotree git_status dir=" .. dir)
end

---@param dir string
local function open_in_subdir(dir)
	child.cmd("cd " .. vim.fs.joinpath(dir, "sub") .. " | enew | Neotree git_status")
end

--- Wait until the tree lists `name`, put the cursor on its node line and press `<space>`.
---@param name string
local function press_space_on(name)
	local escaped = vim.fn.escape(name, [[.\]])
	eq(child.wait(("vim.bo.filetype == 'neo-tree' and vim.fn.search(%q, 'nw') > 0"):format(escaped), ASYNC_MS), true)
	child.fn.search([[\<]] .. escaped .. "$", "w")
	child.type_keys(" ")
end

local function press_space_on_a_lua()
	press_space_on("a.lua")
end

local T = H.child_set(child, start)

T["file-tree: Space stages an unstaged file"] = function()
	local dir = staging_repo({ "a.lua" })
	modify(dir, "a.lua")
	open_in_repo(dir)

	press_space_on_a_lua()

	eq(wait_staged(dir, "a.lua", true), true)
end

T["file-tree: Space unstages a staged file"] = function()
	local dir = staging_repo({ "a.lua" })
	modify(dir, "a.lua")
	git({ "add", "a.lua" }, dir)
	open_in_repo(dir)

	press_space_on_a_lua()

	eq(wait_staged(dir, "a.lua", false), true)
end

T["file-tree: Space stages a file whose name is a suffix of a staged file"] = function()
	local dir = staging_repo({ "a.lua", "aa.lua" })
	modify(dir, "a.lua")
	modify(dir, "aa.lua")
	git({ "add", "aa.lua" }, dir)
	open_in_repo(dir)

	press_space_on_a_lua()

	eq(wait_staged(dir, "a.lua", true), true)
	eq(vim.list_contains(staged(dir), "aa.lua"), true)
end

T["file-tree: Space stages when cwd is outside the repository"] = function()
	local dir = staging_repo({ "a.lua" })
	modify(dir, "a.lua")
	open_from_outside(dir)

	press_space_on_a_lua()

	eq(wait_staged(dir, "a.lua", true), true)
end

T["file-tree: Space unstages when cwd is outside the repository"] = function()
	local dir = staging_repo({ "a.lua" })
	modify(dir, "a.lua")
	git({ "add", "a.lua" }, dir)
	open_from_outside(dir)

	press_space_on_a_lua()

	eq(wait_staged(dir, "a.lua", false), true)
end

T["file-tree: Space stages from a subdirectory cwd"] = function()
	local dir = staging_repo({ "sub/x.lua" })
	modify(dir, "sub/x.lua")
	open_in_subdir(dir)

	press_space_on("x.lua")

	eq(wait_staged(dir, "sub/x.lua", true), true)
end

T["file-tree: Space unstages from a subdirectory cwd"] = function()
	local dir = staging_repo({ "sub/x.lua" })
	modify(dir, "sub/x.lua")
	git({ "add", "sub/x.lua" }, dir)
	open_in_subdir(dir)

	press_space_on("x.lua")

	eq(wait_staged(dir, "sub/x.lua", false), true)
end

T["file-tree: Space reports a staging failure"] = function()
	local dir = staging_repo({ "a.lua" })
	modify(dir, "a.lua")
	open_in_repo(dir)
	eq(child.wait([[vim.bo.filetype == "neo-tree" and vim.fn.search("a.lua", "nw") > 0]], ASYNC_MS), true)
	vim.fn.writefile({}, vim.fs.joinpath(dir, ".git", "index.lock"))
	child.lua([[
		Notes = {}
		vim.notify = function(msg, level) table.insert(Notes, { msg = msg, level = level }) end
	]])

	press_space_on_a_lua()

	eq(
		child.wait(
			[[vim.iter(Notes):any(function(n)
				return n.level == vim.log.levels.ERROR and vim.startswith(n.msg, "Stage failed:")
			end)]],
			ASYNC_MS
		),
		true
	)
end

return T

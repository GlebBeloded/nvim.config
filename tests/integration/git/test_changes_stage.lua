local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local ASYNC_MS = 3000

local function start()
	child.start_config()
	child.wait_very_lazy()
end

local T = H.child_set(child, start)

---@param dir string
local function open_changes(dir)
	child.cmd("cd " .. vim.fn.fnameescape(dir))
	child.cmd("enew")
	child.lua([[
		local catalog = require("gleb.actions").state.applicator.catalog
		assert(catalog:get("changes.toggle"), "changes.toggle is not registered").run()
	]])
	eq(
		child.wait([[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()] ~= nil]], ASYNC_MS),
		true
	)
end

---@param root string
---@param cwd string
local function open_changes_at(root, cwd)
	child.cmd("cd " .. vim.fn.fnameescape(cwd))
	child.cmd("enew")
	child.lua(([[require("gleb.git.changes").open({ root = %q })]]):format(root))
	eq(
		child.wait([[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()] ~= nil]], ASYNC_MS),
		true
	)
end

---@param path string
local function press_space_on(path)
	eq(
		child.wait(
			([[(function()
				local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
				if not view then return false end
				for index, row in ipairs(view.rows) do
					if row.path == %q then
						vim.api.nvim_win_set_cursor(view.win, { index, 0 })
						return true
					end
				end
				return false
			end)()]]):format(path),
			ASYNC_MS
		),
		true
	)
	child.type_keys(" ")
end

---@param dir string
---@return string[]
local function staged(dir)
	return vim.split(vim.trim(H.git(dir, { "diff", "--cached", "--name-only" })), "\n", { trimempty = true })
end

---@param dir string
---@param path string
---@param wanted boolean
---@return boolean
local function wait_staged(dir, path, wanted)
	return vim.wait(ASYNC_MS, function()
		return vim.list_contains(staged(dir), path) == wanted
	end, 50)
end

---@param dir string
---@param path string
---@return boolean
local function wait_worktree_clean(dir, path)
	return vim.wait(ASYNC_MS, function()
		return vim.system({ "git", "diff", "--quiet", "--", path }, { cwd = dir }):wait().code == 0
	end, 50)
end

---@param path string
---@param checkbox string
---@return boolean
local function wait_checkbox(path, checkbox)
	return child.wait(
		([[(function()
			local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			if not view then return false end
			for _, row in ipairs(view.rows) do
				if row.path == %q then return row.checkbox == %q end
			end
			return false
		end)()]]):format(path, checkbox),
		ASYNC_MS
	)
end

T["git: Changes panel Space stages an unstaged file"] = function()
	local dir = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(dir)

	press_space_on("b.txt")

	eq(wait_staged(dir, "b.txt", true), true)
	eq(wait_checkbox("b.txt", "󰄲"), true)
end

T["git: Changes panel Space unstages a staged file"] = function()
	local dir = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(dir)

	press_space_on("a.txt")

	eq(wait_staged(dir, "a.txt", false), true)
	eq(wait_checkbox("a.txt", "󰄱"), true)
end

T["git: Changes panel Space stages a partially staged file"] = function()
	local dir = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(dir)

	press_space_on("d.txt")

	eq(wait_staged(dir, "d.txt", true), true)
	eq(wait_worktree_clean(dir, "d.txt"), true)
	eq(wait_checkbox("d.txt", "󰄲"), true)
end

T["git: Changes panel Space stages an untracked file"] = function()
	local dir = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	open_changes(dir)

	press_space_on("new.txt")

	eq(wait_staged(dir, "new.txt", true), true)
	eq(wait_checkbox("new.txt", "󰄲"), true)
	eq(
		child.wait(
			[[
			vim.iter(require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()].rows)
				:all(function(row) return row.root ~= "unversioned" end)
		]],
			ASYNC_MS
		),
		true
	)
end

T["git: Changes panel Space stages a file whose name is a suffix of a staged file"] = function()
	local dir = H.git_repo({ ["a.lua"] = "one\n", ["aa.lua"] = "one\n" })
	H.write_files(dir, { ["a.lua"] = "two\n", ["aa.lua"] = "two\n" })
	H.git(dir, { "add", "--", "aa.lua" })
	open_changes(dir)

	press_space_on("a.lua")

	eq(wait_staged(dir, "a.lua", true), true)
	eq(staged(dir), { "a.lua", "aa.lua" })
end

T["git: Changes panel stages when cwd is outside the repository"] = function()
	local dir = H.git_repo({ ["a.lua"] = "one\n" })
	local outside = vim.fn.tempname()
	vim.fn.mkdir(outside, "p")
	H.write_files(dir, { ["a.lua"] = "two\n" })
	open_changes_at(dir, outside)

	press_space_on("a.lua")

	eq(wait_staged(dir, "a.lua", true), true)
end

T["git: Changes panel unstages when cwd is outside the repository"] = function()
	local dir = H.git_repo({ ["a.lua"] = "one\n" })
	local outside = vim.fn.tempname()
	vim.fn.mkdir(outside, "p")
	H.write_files(dir, { ["a.lua"] = "two\n" })
	H.git(dir, { "add", "--", "a.lua" })
	open_changes_at(dir, outside)

	press_space_on("a.lua")

	eq(wait_staged(dir, "a.lua", false), true)
end

T["git: Changes panel stages from a subdirectory cwd"] = function()
	local dir = H.git_repo({ ["sub/x.lua"] = "one\n" })
	H.write_files(dir, { ["sub/x.lua"] = "two\n" })
	open_changes(vim.fs.joinpath(dir, "sub"))

	press_space_on("sub/x.lua")

	eq(wait_staged(dir, "sub/x.lua", true), true)
end

T["git: Changes panel unstages from a subdirectory cwd"] = function()
	local dir = H.git_repo({ ["sub/x.lua"] = "one\n" })
	H.write_files(dir, { ["sub/x.lua"] = "two\n" })
	H.git(dir, { "add", "--", "sub/x.lua" })
	open_changes(vim.fs.joinpath(dir, "sub"))

	press_space_on("sub/x.lua")

	eq(wait_staged(dir, "sub/x.lua", false), true)
end

T["git: Changes panel reports a staging failure"] = function()
	local dir = H.git_repo({ ["a.lua"] = "one\n" })
	H.write_files(dir, { ["a.lua"] = "two\n" })
	open_changes(dir)
	local notifications = H.record_notify(child)
	vim.fn.writefile({}, vim.fs.joinpath(dir, ".git", "index.lock"))

	press_space_on("a.lua")

	eq(
		child.wait(
			[[vim.iter(Notifications):any(function(notification)
				return notification.level == vim.log.levels.ERROR
					and vim.startswith(notification.msg, "Stage failed:")
			end)]],
			ASYNC_MS
		),
		true
	)
	eq(vim.startswith(notifications()[1].msg, "Stage failed:"), true)
end

return T

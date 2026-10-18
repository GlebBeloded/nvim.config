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
	child.lua([[require("gleb.git.changes").open({ root = ... })]], { dir })
	eq(
		child.wait([[require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()] ~= nil]], ASYNC_MS),
		true
	)
end

---@param path string
local function select_path(path)
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
end

---@param answer "y"|"n"
local function revert_with_answer(answer)
	child.lua([[
		InputAnswer = nil
		local input = vim.ui.input
		vim.ui.input = function(opts, callback)
			input(opts, function(value)
				InputAnswer = value
				callback(value)
			end)
		end
	]])
	child.type_keys("X")
	eq(child.wait([[vim.fn.mode() == "c"]], ASYNC_MS), true)
	child.type_keys(answer, "<CR>")
	eq(child.wait(("InputAnswer == %q"):format(answer), ASYNC_MS), true)
end

local function record_system_calls()
	child.lua([[
		SystemCalls = {}
		local original_system = vim.system
		vim.system = function(command, opts, callback)
			table.insert(SystemCalls, vim.deepcopy(command))
			return original_system(command, opts, callback)
		end
	]])
end

---@return table[]
local function revert_calls()
	return child.lua_get([[vim.iter(SystemCalls):filter(function(command)
		return command[1] == "git"
			and command[2] == "--literal-pathspecs"
			and (command[3] == "checkout" or command[3] == "rm")
	end):totable()]])
end

T["git: Changes panel X reverts a file after confirmation"] = function()
	local dir = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	local head = vim.split(H.git(dir, { "show", "HEAD:b.txt" }), "\n", { trimempty = true })
	open_changes(dir)
	select_path("b.txt")

	revert_with_answer("y")

	eq(
		vim.wait(ASYNC_MS, function()
			return H.git(dir, { "status", "--porcelain", "--", "b.txt" }) == ""
		end, 50),
		true
	)
	eq(vim.fn.readfile(vim.fs.joinpath(dir, "b.txt")), head)
end

T["git: Changes panel X keeps a file when revert is declined"] = function()
	local dir = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	local path = vim.fs.joinpath(dir, "b.txt")
	local before = vim.fn.readfile(path)
	open_changes(dir)
	select_path("b.txt")

	revert_with_answer("n")

	eq(vim.fn.readfile(path), before)
	eq(H.git(dir, { "status", "--porcelain", "--", "b.txt" }) ~= "", true)
end

T["git: Changes panel X unstages a new file and keeps it"] = function()
	local dir = F.copy("billing", vim.fn.tempname() .. "/billing")
	local path = vim.fs.joinpath(dir, "internal/billing/tax.go")
	open_changes(dir)
	select_path("internal/billing/tax.go")

	revert_with_answer("y")

	eq(
		vim.wait(ASYNC_MS, function()
			return vim.trim(
				H.git(dir, { "ls-files", "--others", "--exclude-standard", "--", "internal/billing/tax.go" })
			) == "internal/billing/tax.go"
		end, 50),
		true
	)
	eq(vim.fn.filereadable(path), 1)
	eq(#vim.fn.readfile(path), 41)
end

T["git: Changes panel X ignores an unversioned file"] = function()
	local dir = F.copy("dirty", vim.fn.tempname() .. "/dirty")
	local path = vim.fs.joinpath(dir, "new.txt")
	open_changes(dir)
	select_path("new.txt")
	record_system_calls()

	child.type_keys("X")

	eq(vim.fn.filereadable(path), 1)
	eq(revert_calls(), {})
	eq(child.lua_get([[vim.fn.mode() ~= "c"]]), true)
end

T["git: Changes panel X reverts a rename"] = function()
	local dir = H.git_repo({ ["old.txt"] = "content\n" })
	H.git(dir, { "mv", "old.txt", "new.txt" })
	open_changes(dir)
	select_path("new.txt")
	record_system_calls()

	revert_with_answer("y")

	eq(
		vim.wait(ASYNC_MS, function()
			return H.git(dir, { "status", "--porcelain", "--", "old.txt", "new.txt" }) == "?? new.txt\n"
		end, 50),
		true
	)
	eq(vim.fn.readfile(vim.fs.joinpath(dir, "old.txt")), { "content" })
	eq(vim.fn.readfile(vim.fs.joinpath(dir, "new.txt")), { "content" })
	eq(revert_calls(), {
		{ "git", "--literal-pathspecs", "checkout", "HEAD", "--", vim.fs.joinpath(dir, "old.txt") },
		{ "git", "--literal-pathspecs", "rm", "--cached", "--", vim.fs.joinpath(dir, "new.txt") },
	})
end

return T

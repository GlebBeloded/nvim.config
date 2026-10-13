local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local ASYNC_MS = 3000

local function start()
	child.start_config()
	child.wait_very_lazy()
end

--- Fixture: `docs/workflow.md`, `empty/`, `lua/gleb/`, `init.lua`, `sample.lua`.
---@return string dir
local function fixture_dir()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(vim.fs.joinpath(dir, "docs"), "p")
	vim.fn.mkdir(vim.fs.joinpath(dir, "empty"), "p")
	vim.fn.mkdir(vim.fs.joinpath(dir, "lua", "gleb"), "p")
	vim.fn.writefile({ "# workflow" }, vim.fs.joinpath(dir, "docs", "workflow.md"))
	vim.fn.writefile({ "-- init" }, vim.fs.joinpath(dir, "init.lua"))
	vim.fn.writefile({ "local M = {}" }, vim.fs.joinpath(dir, "sample.lua"))
	return dir
end

---@param dir string
---@param args string[]
local function git(dir, args)
	local cmd = { "git", "-c", "user.name=t", "-c", "user.email=t@t", "-c", "init.defaultBranch=main" }
	vim.system(vim.list_extend(cmd, args), { cwd = dir }):wait()
end

--- Temp git repo where `conflict.txt` is unmerged after a failed `git merge`.
---@return string dir
local function conflicted_repo()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local file = vim.fs.joinpath(dir, "conflict.txt")
	git(dir, { "init", "-q" })
	vim.fn.writefile({ "base" }, file)
	git(dir, { "add", "." })
	git(dir, { "commit", "-qm", "base" })
	git(dir, { "checkout", "-qb", "other" })
	vim.fn.writefile({ "other" }, file)
	git(dir, { "commit", "-qam", "other" })
	git(dir, { "checkout", "-q", "main" })
	vim.fn.writefile({ "main" }, file)
	git(dir, { "commit", "-qam", "main" })
	git(dir, { "merge", "-q", "other" })
	return dir
end

---@param name string
---@return string? line of the neo-tree buffer whose node name is `name`
local function tree_row(name)
	local row = child.lua(
		[[
		local needle = " " .. ... .. " "
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.bo[buf].filetype == "neo-tree" then
				for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
					if (line .. " "):find(needle, 1, true) then
						return line
					end
				end
			end
		end
	]],
		{ name }
	)
	return row ~= vim.NIL and row or nil
end

--- Wait until the tree row of `name` matches the Lua `pattern`.
---@param name string
---@param pattern string
---@return string? row
local function wait_row(name, pattern)
	vim.wait(ASYNC_MS, function()
		return (tree_row(name) or ""):find(pattern) ~= nil
	end, 50)
	return tree_row(name)
end

---@param dir string
local function open_filesystem(dir)
	child.cmd("cd " .. dir .. " | enew | Neotree filesystem")
	eq(child.wait([[vim.bo.filetype == "neo-tree"]], ASYNC_MS), true)
	eq(wait_row("docs", "docs") ~= nil, true)
end

--- Put the cursor on the tree row of `name` and press `<cr>`.
---@param name string
local function press_enter_on(name)
	child.lua([[vim.fn.search(" " .. ... .. "\\>", "w")]], { name })
	child.type_keys("<cr>")
end

local T = H.child_set(child, start)

T["file-tree: Collapsed directory shows expander and folder icon"] = function()
	open_filesystem(fixture_dir())

	local row = wait_row("docs", "\u{F460}.*\u{E5FF}.*docs")
	eq({ row, (row or ""):find("\u{F460}.*\u{E5FF}.*docs") ~= nil }, { row, true })
end

T["file-tree: Expanded directory shows open expander and folder icon"] = function()
	open_filesystem(fixture_dir())
	press_enter_on("docs")

	local row = wait_row("docs", "\u{F47C}.*\u{E5FE}.*docs")
	eq({ row, (row or ""):find("\u{F47C}.*\u{E5FE}.*docs") ~= nil }, { row, true })
end

T["file-tree: Empty directory shows empty folder icon"] = function()
	open_filesystem(fixture_dir())
	press_enter_on("empty")
	press_enter_on("empty")

	local row = wait_row("empty", "\u{F0256}.*empty")
	eq({ row, (row or ""):find("\u{F0256}.*empty") ~= nil }, { row, true })
end

T["file-tree: Tree shows diagnostic glyph of a file"] = function()
	local dir = fixture_dir()
	open_filesystem(dir)
	eq(wait_row("sample.lua", "sample%.lua") ~= nil, true)
	child.lua(
		[[
		local buf = vim.fn.bufadd(...)
		vim.fn.bufload(buf)
		local ns = vim.api.nvim_create_namespace("test")
		vim.diagnostic.set(ns, buf, { { lnum = 0, col = 0, message = "e", severity = vim.diagnostic.severity.ERROR } })
	]],
		{ vim.fs.joinpath(dir, "sample.lua") }
	)

	local row = wait_row("sample.lua", "\u{F057}")
	eq({ row, (row or ""):find("\u{F057}") ~= nil }, { row, true })
end

T["file-tree: Conflicted file shows conflict symbol"] = function()
	child.cmd("cd " .. conflicted_repo() .. " | enew | Neotree git_status")
	eq(child.wait([[vim.bo.filetype == "neo-tree"]], ASYNC_MS), true)

	local row = wait_row("conflict.txt", "\u{E727}")
	eq({ row, (row or ""):find("\u{E727}") ~= nil }, { row, true })
end

return T

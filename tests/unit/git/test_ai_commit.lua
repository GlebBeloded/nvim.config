local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local OLLAMA_CMD = { "ollama", "run", "tavernari/git-commit-message:sp_commit_mini" }

---@type string
local repo

--- Bare child with nui.nvim, cwd in a temp repo with a committed `a.txt`.
local function start()
	repo = H.git_repo({ ["a.txt"] = "a\n" })
	child.start_bare({ "nui.nvim" })
	child.cmd("cd " .. repo)
end

--- Child-side recorder for external processes (design D4): `vim.fn.jobstart`
--- records the command and the job's callbacks in `Jobs` instead of spawning,
--- `chansend` appends to the job's `stdin`, `jobstop` marks it stopped.
--- `FinishJob(text, code)` replays stdout `text` (split into lines as a
--- channel delivers it) and the exit `code` through the recorded callbacks.
local RECORD_JOBSTART_LUA = [[
Jobs = {}
local FIRST_ID = 100
local function job(id) return Jobs[id - FIRST_ID + 1] end
vim.fn.jobstart = function(cmd, opts)
	table.insert(Jobs, { cmd = cmd, opts = opts, stdin = "", stopped = false })
	return FIRST_ID + #Jobs - 1
end
vim.fn.chansend = function(id, data) job(id).stdin = job(id).stdin .. data end
vim.fn.chanclose = function() end
vim.fn.jobstop = function(id) job(id).stopped = true end
function FinishJob(text, code)
	local id = FIRST_ID + #Jobs - 1
	vim.schedule(function()
		job(id).opts.on_stdout(id, vim.split(text, "\n"))
		job(id).opts.on_exit(id, code)
	end)
end]]

--- Install the jobstart/chansend recorder in the child.
local function record_jobstart()
	child.lua(RECORD_JOBSTART_LUA)
end

---@class test.RecordedJob
---@field cmd string[]
---@field stdin string
---@field stopped boolean

---@return test.RecordedJob[]
local function jobs()
	return child.lua([[return vim.tbl_map(function(job)
		return { cmd = job.cmd, stdin = job.stdin, stopped = job.stopped }
	end, Jobs)]])
end

--- Child-side: `PopupTitle()`, the text between the corners of the top edge
--- of nui's border window (a separate float whose first line starts with `╭`).
local POPUP_TITLE_LUA = [[
function PopupTitle()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local line = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, 1, false)[1] or ""
		-- a Vim regex: Lua patterns repeat single bytes, not the multibyte `─`
		if line:find("^╭") then return vim.fn.matchstr(line, [=[^╭─*\zs.\{-}\ze─*╮$]=]) end
	end
end]]

--- Open the popup with an `on_commit` that records its calls in `Commits`.
local function show_commit_input()
	child.lua(POPUP_TITLE_LUA)
	child.lua([[
		Commits = {}
		require("gleb.git.ai_commit").show_commit_input(function(msg) table.insert(Commits, msg) end)
		PopupWin = vim.api.nvim_get_current_win()
	]])
end

--- Stage `files` in the temp repo.
---@param files table<string, string>
local function stage(files)
	H.write_files(repo, files)
	H.git(repo, { "add", "-A" })
end

local T = H.child_set(child, start)

T["git: No staged changes"] = function()
	record_jobstart()
	show_commit_input()

	eq(child.api.nvim_win_get_config(0).relative ~= "", true)
	eq(child.api.nvim_buf_get_lines(0, 0, -1, false), { "# No staged changes" })
	eq(child.bo.filetype, "gitcommit")
	eq(child.lua_get("PopupTitle()"), " Commit Message ")
	eq(jobs(), {})
end

T["git: Ollama is spawned with staged diff"] = function()
	stage({ ["a.txt"] = "a\nb\n" })
	local diff = H.git(repo, { "diff", "--cached" })
	record_jobstart()
	show_commit_input()

	local spawned = jobs()
	eq(#spawned, 1)
	eq(spawned[1].cmd, OLLAMA_CMD)
	eq(spawned[1].stdin:find(diff, 1, true) ~= nil, true)
end

T["git: Long diff is truncated"] = function()
	stage({ ["long.txt"] = table.concat(vim.fn.range(1, 300), "\n") .. "\n" })
	local diff_lines = vim.split(H.git(repo, { "diff", "--cached" }), "\n")
	record_jobstart()
	show_commit_input()

	local stdin = jobs()[1].stdin
	local sent = stdin:sub(assert(stdin:find("\nDiff:\n", 1, true)) + #"\nDiff:\n")
	eq(sent, table.concat(vim.list_slice(diff_lines, 1, 200), "\n") .. "\n... (truncated)")
end

return T

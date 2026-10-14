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
	child.lua([[
		require("gleb.actions").setup({ require("gleb.git.actions") })
		require("gleb.actions").apply()
	]])
	child.cmd("cd " .. repo)
end

---@type fun(): test.JobCall[]
local jobs

--- Record jobs instead of spawning them; ollama runs until `finish_job`.
local function record_jobstart()
	jobs = H.record_jobstart(child, { ollama = { hold = true } })
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

---@return string[]
local function popup_lines()
	return child.lua_get("vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(PopupWin), 0, -1, false)")
end

---@return boolean
local function popup_open()
	return child.lua_get("vim.api.nvim_win_is_valid(PopupWin)")
end

---@return string[] messages `on_commit` was called with
local function commits()
	return child.lua_get("Commits")
end

--- Replay the job's stdout `text` and exit `code`.
---@param text string
---@param code integer
local function finish_job(text, code)
	H.finish_job(child, text, code)
end

--- Open the popup with a staged change, so the AI job is running.
local function show_generating()
	stage({ ["a.txt"] = "a\nb\n" })
	record_jobstart()
	show_commit_input()
end

local T = H.child_set(child, start)

T["git: Commit popup mappings come from git actions"] = function()
	show_commit_input()

	eq(
		child.lua_get([[
		(function()
			local mappings = {}
			for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
				mappings[mapping.lhs] = mapping.desc
			end
			local shortcuts = require("gleb.actions").state.store.last_good
			return {
				shortcuts["git.confirm_commit_popup"],
				mappings["<CR>"],
				shortcuts["git.discard_commit_popup"],
				mappings.q,
			}
		end)()
	]]),
		{
			{ "<CR>" },
			"Git: Confirm commit message",
			{ "q" },
			"Git: Discard commit message",
		}
	)
end

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

T["git: Generated message fills popup"] = function()
	show_generating()
	finish_job("```\nfeat(git): add x\n```", 0)

	eq(popup_lines(), { "feat(git): add x" })
	eq(child.lua_get("PopupTitle()"), " Commit Message ")
end

T["git: Popup resizes to content"] = function()
	child.o.columns = 200
	show_generating()
	finish_job("feat(git): add x\n", 0)

	eq(child.lua_get("{ vim.api.nvim_win_get_width(PopupWin), vim.api.nvim_win_get_height(PopupWin) }"), { 72, 1 })
end

T["git: Ollama failure is shown"] = function()
	show_generating()
	finish_job("", 1)

	eq(popup_lines(), { "# Error: Ollama exited with code 1" })
	eq(child.lua_get("PopupTitle()"), " Commit Message ")
end

T["git: Enter confirms message"] = function()
	show_commit_input()
	child.api.nvim_buf_set_lines(0, 0, -1, false, { "feat: x  " })
	child.type_keys("<CR>")

	eq(popup_open(), false)
	eq(commits(), { "feat: x" })
end

T["git: Enter on empty buffer does nothing"] = function()
	show_commit_input()
	child.api.nvim_buf_set_lines(0, 0, -1, false, {})
	child.type_keys("<CR>")

	eq(popup_open(), true)
	eq(commits(), {})
end

T["git: Enter on placeholder does nothing"] = function()
	show_commit_input()
	child.type_keys("<CR>")

	eq(popup_open(), true)
	eq(commits(), {})
end

T["git: q discards popup"] = function()
	show_generating()
	child.type_keys("q")

	eq(popup_open(), false)
	eq(jobs()[1].stopped, true)
	finish_job("feat: late\n", 0)
	eq(commits(), {})
	eq(child.v.errmsg, "")
end

T["git: Leaving popup closes it"] = function()
	show_commit_input()
	child.cmd("wincmd p")

	eq(popup_open(), false)
	eq(commits(), {})
end

return T

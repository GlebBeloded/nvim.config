local MiniTest = require("mini.test")
local H = require("tests.helpers")

local eq = MiniTest.expect.equality
local child = H.new_child()

local ASYNC_MS = 5000
--- current_line_blame_opts.delay of the config (the spec's 300 ms).
local BLAME_DELAY_MS = 300

---@type string
local repo

local function start()
	child.start_config()
end

--- Fresh temp git repo with `files` committed, as the child's cwd.
---@param files table<string, string>
---@param opts? test.GitRepoOpts
---@return string repo path
local function use_repo(files, opts)
	repo = H.git_repo(files, opts)
	child.cmd("cd " .. repo)
	return repo
end

--- Edit `name` of the current repo in the child.
---@param name string
local function edit(name)
	child.cmd("edit " .. vim.fs.joinpath(repo, name))
end

--- Child-side: true once gitsigns has attached to the current buffer.
local GITSIGNS_ATTACHED = "vim.b.gitsigns_status_dict ~= nil"

--- Child-side: define `GitsignsSigns()`, the sign texts gitsigns placed in the
--- current buffer keyed by 1-based line (as strings, so the table survives RPC).
local GITSIGNS_SIGNS_LUA = [[
function GitsignsSigns()
	local signs = {}
	for name, ns in pairs(vim.api.nvim_get_namespaces()) do
		if name:find("^gitsigns_signs") then
			for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true, type = "sign" })) do
				signs[tostring(mark[2] + 1)] = vim.trim(mark[4].sign_text or "")
			end
		end
	end
	return signs
end]]

--- Child-side: hunk signs placed by MiniDiff namespaces in the current buffer.
local MINIDIFF_SIGNS_LUA = [[
local signs = {}
for name, ns in pairs(vim.api.nvim_get_namespaces()) do
	if name:find("^MiniDiff") then
		for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true, type = "sign" })) do
			table.insert(signs, { name, mark[2] + 1, vim.trim(mark[4].sign_text or "") })
		end
	end
end
return signs]]

--- Child-side: sign extmarks on line 2 outside gitsigns namespaces.
local COMPETING_LINE_2_SIGNS_LUA = [[
local gitsigns_namespaces = {}
for name, ns in pairs(vim.api.nvim_get_namespaces()) do
	if name:find("^gitsigns") then gitsigns_namespaces[ns] = true end
end
local signs = {}
for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, -1, { 1, 0 }, { 1, -1 }, { details = true, type = "sign" })) do
	if not gitsigns_namespaces[mark[4].ns_id] then
		table.insert(signs, { mark[4].ns_id, vim.trim(mark[4].sign_text or "") })
	end
end
return signs]]

--- Child-side: end-of-line virtual texts in the current buffer, all namespaces.
local EOL_VIRT_TEXT_LUA = [[
local texts = {}
for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })) do
	if mark[4].virt_text and mark[4].virt_text_pos == "eol" then
		table.insert(texts, mark[4].virt_text)
	end
end
return texts]]

--- Child-side: define `TopLeftWindow()` (filetype, width and buffer lines of
--- the first window of the current tab's layout) and `WindowWithFt(ft)`.
local WINDOW_PROBES_LUA = [[
function TopLeftWindow()
	local layout = vim.fn.winlayout()
	while layout[1] ~= "leaf" do
		layout = layout[2][1]
	end
	local win = layout[2]
	local buf = vim.api.nvim_win_get_buf(win)
	return {
		win = win,
		filetype = vim.bo[buf].filetype,
		width = vim.api.nvim_win_get_width(win),
		lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false),
	}
end
function WindowWithFt(ft)
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == ft then return win end
	end
end
function WindowWithFile(path)
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)) == path then return win end
	end
end]]

---@return integer
local function tab_count()
	return #child.api.nvim_list_tabpages()
end

--- Write `files` into the repo without committing them.
---@param files table<string, string>
local function change(files)
	H.write_files(repo, files)
end

---@param name string
---@return string absolute path in the repo
local function path(name)
	return vim.fs.joinpath(repo, name)
end

--- `:DiffviewOpen` and wait until its file panel and the window showing
--- `first` are drawn.
---@param first string repo-relative file shown in the diff windows
local function open_diffview(first)
	child.lua(WINDOW_PROBES_LUA)
	child.cmd("DiffviewOpen")
	assert(child.wait("WindowWithFt('DiffviewFiles') ~= nil", ASYNC_MS), "no DiffviewFiles window")
	assert(child.wait(("WindowWithFile(%q) ~= nil"):format(path(first)), ASYNC_MS), "diff of " .. first .. " not shown")
end

--- Focus the diff window showing `name` once diffview has mapped `lhs` in it
--- (view mappings are attached after the buffer is shown).
---@param name string
---@param lhs string
---@return integer window
local function focus_diff_window(name, lhs)
	local win = child.lua_get(("WindowWithFile(%q)"):format(path(name)))
	child.api.nvim_set_current_win(win)
	assert(child.wait(("vim.fn.maparg(%q, 'n', false, true).buffer == 1"):format(lhs), ASYNC_MS), lhs .. " not mapped")
	return win
end

--- Type `keys` in a diffview window. Not `child.type_keys`: that fails on any
--- v:errmsg, and diffview's file switch sets one from its own
--- `pcall(vim.cmd, "norm! zE")` (E490: No fold found) without showing it.
---@param keys string
local function press_in_diffview(keys)
	child.api.nvim_input(keys)
end

--- Move the cursor of the diffview file panel to the entry for `name`.
---@param name string
local function focus_panel_entry(name)
	local win = child.lua_get("WindowWithFt('DiffviewFiles')")
	child.api.nvim_set_current_win(win)
	local lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
	for row, line in ipairs(lines) do
		if line:find(name, 1, true) then
			child.api.nvim_win_set_cursor(win, { row, 0 })
			return
		end
	end
	error("no file panel entry for " .. name .. ":\n" .. table.concat(lines, "\n"))
end

---@param id string
---@param lhs string
local function expect_action_shortcut(id, lhs)
	eq(
		child.lua_get(([[require("gleb.actions").state.applicator.catalog:get(%q) ~= nil
				and vim.tbl_contains(require("gleb.actions").state.store.last_good[%q] or {}, %q)]]):format(id, id, lhs)),
		true
	)
end

---@param win integer
---@param lhs string
---@return table
local function window_mapping(win, lhs)
	return child.lua_get(([[(function()
			local map = vim.api.nvim_win_call(%d, function() return vim.fn.maparg(%q, "n", false, true) end)
			return { mapped = next(map) ~= nil, buffer = map.buffer == 1, desc = map.desc }
		end)()]]):format(win, lhs))
end

---@return string[] files in the index that differ from HEAD
local function staged_files()
	return vim.split(vim.trim(H.git(repo, { "diff", "--cached", "--name-only" })), "\n", { trimempty = true })
end

--- Rows of a file panel that name a file or directory (last word ending in
--- `/` or of the form `name.ext`), as that name indented by two spaces when
--- the row is indented, so a tree listing reads like `{ "dir/", "  b.txt" }`.
---@param lines string[]
---@return string[]
local function tree_rows(lines)
	local rows = {}
	for _, line in ipairs(lines) do
		local indent, name = line:match("^(%s*).-(%S+)$")
		if name and (name:find("^[%w_-]+/$") or name:find("^[%w_-]+%.%w+$")) then
			table.insert(rows, (indent ~= "" and "  " or "") .. name)
		end
	end
	return rows
end

---@param target test.Child
---@param timeout? integer
local function open_differ(target, timeout)
	H.open_surface(target, {
		open = [[vim.cmd("Differ")]],
		condition = [[TopLeftWindow().filetype == "differpanel"
			and table.concat(TopLeftWindow().lines, "\n"):find("b.txt", 1, true) ~= nil]],
		surface = "Differ",
		timeout = timeout,
	})
end

local function expect_blocked_differ_diagnostic()
	local blocked = H.new_child()
	blocked.start_config()
	blocked.cmd("cd " .. vim.fn.fnameescape(repo) .. " | edit a.txt")
	blocked.lua(WINDOW_PROBES_LUA)
	blocked.lua([[
		local system = vim.system
		vim.system = function(command, opts, on_exit)
			if command[1] == "git" then
				return system({ "/bin/sleep", "30" }, opts, on_exit)
			end
			return system(command, opts, on_exit)
		end
	]])

	local started = vim.uv.hrtime()
	local ok, diagnostic = pcall(open_differ, blocked, 1000)
	local elapsed = (vim.uv.hrtime() - started) / 1000000
	pcall(blocked.stop)

	eq(ok, false)
	eq(elapsed < 10000, true)
	for _, field in ipairs({ "Differ", "phase: opening", "elapsed:", "mode:", "getchar:", "messages:", "sleep 30" }) do
		assert(tostring(diagnostic):find(field, 1, true), ("missing %q in %s"):format(field, diagnostic))
	end
end

--- Change the middle line of `name` ("top", "base", "bottom") to "ours" on
--- main and "theirs" on branch `other`, then merge `other` so that line is
--- left in conflict.
---@param name string
local function make_conflict(name)
	H.git(repo, { "checkout", "-q", "-b", "other" })
	change({ [name] = "top\ntheirs\nbottom\n" })
	H.git(repo, { "commit", "-q", "-am", "theirs" })
	H.git(repo, { "checkout", "-q", "main" })
	change({ [name] = "top\nours\nbottom\n" })
	H.git(repo, { "commit", "-q", "-am", "ours" })
	local merge = vim.system({ "git", "-C", repo, "merge", "-q", "other" }, { text = true }):wait()
	assert(merge.code ~= 0, "merge did not conflict")
end

--- Twelve numbered lines, so line 10 and the range 3-5 exist.
local NUMBERED = table.concat(vim.fn.range(1, 12), "\n") .. "\n"

--- Repo with `a.txt` (NUMBERED) whose `origin` is `remote` and whose HEAD is
--- on `origin/main` (a local ref, no fetch), as gitlinker links only
--- commits a remote branch contains; `a.txt` is opened.
---@param remote string
---@return string sha of HEAD
local function use_linked_repo(remote)
	use_repo({ ["a.txt"] = NUMBERED }, { remote = remote })
	H.git(repo, { "update-ref", "refs/remotes/origin/main", "HEAD" })
	edit("a.txt")
	return vim.trim(H.git(repo, { "rev-parse", "HEAD" }))
end

local T = H.child_set(child, start)

T["git: Git commands are available after startup"] = function()
	use_repo({ ["a.txt"] = "a\n" })
	local commands = { "Gitsigns", "Differ", "DiffviewOpen", "Gitlink" }
	local exists = vim.tbl_map(function(cmd)
		return child.fn.exists(":" .. cmd)
	end, commands)
	eq(exists, { 2, 2, 2, 2 })
end

T["git: vscode-diff setup runs on plugin load"] = function()
	child.lua([[require("lazy").load({ plugins = { "vscode-diff.nvim" } })]])

	eq(child.lua_get([[package.loaded["gleb.git.vscode_diff"] ~= nil]]), true)
	-- the plugin defaults are width 40 and a list view, so these come from the config's setup
	local explorer = child.lua_get([[require("codediff.config").options.explorer]])
	eq({ explorer.position, explorer.width, explorer.view_mode }, { "left", 35, "tree" })
end

T["git: Added line has no competing hunk sign"] = function()
	use_repo({ ["a.txt"] = "a\n" })
	edit("a.txt")
	eq(child.wait(GITSIGNS_ATTACHED, ASYNC_MS), true)
	child.lua(GITSIGNS_SIGNS_LUA)
	child.api.nvim_buf_set_lines(0, 1, 1, false, { "added" })

	eq(child.wait("GitsignsSigns()['2'] ~= nil", ASYNC_MS), true)
	eq(child.lua_get('package.loaded["mini.diff"]'), vim.NIL)
	eq(child.lua_get('require("lazy.core.config").plugins["mini.diff"]'), vim.NIL)
	eq(child.lua(MINIDIFF_SIGNS_LUA), {})
	eq(child.lua(COMPETING_LINE_2_SIGNS_LUA), {})
end

T["git: Blame is off by default"] = function()
	use_repo({ ["a.txt"] = "a\nb\n" })
	edit("a.txt")
	eq(child.wait(GITSIGNS_ATTACHED, ASYNC_MS), true)
	child.type_keys("j")
	vim.uv.sleep(BLAME_DELAY_MS + 200)

	eq(child.lua(EOL_VIRT_TEXT_LUA), {})
end

T["git: Differ opens panel on the left"] = function()
	use_repo({ ["a.txt"] = "a\n", ["dir/b.txt"] = "b\n" })
	change({ ["a.txt"] = "a2\n", ["dir/b.txt"] = "b2\n" })
	expect_blocked_differ_diagnostic()
	child.lua(WINDOW_PROBES_LUA)
	local windows = #child.api.nvim_tabpage_list_wins(0)
	open_differ(child)

	local panel = child.lua_get("TopLeftWindow()")
	eq(#child.api.nvim_tabpage_list_wins(0) > windows, true)
	eq(panel.width, 35)
	eq(tree_rows(panel.lines), { "dir/", "  b.txt", "a.txt" })
end

T["git: Diffview file panel on the left"] = function()
	use_repo({ ["a.txt"] = "a\n" })
	change({ ["a.txt"] = "a2\n" })
	local tabs = tab_count()
	open_diffview("a.txt")

	eq(tab_count(), tabs + 1)
	local panel = child.lua_get("TopLeftWindow()")
	eq({ panel.filetype, panel.width }, { "DiffviewFiles", 35 })
end

T["git: Diffview mappings come from git actions"] = function()
	use_repo({ ["a.txt"] = "a\n" })
	change({ ["a.txt"] = "a2\n" })
	open_diffview("a.txt")
	local win = focus_diff_window("a.txt", "<Tab>")

	expect_action_shortcut("diffview.select_next_entry", "<Tab>")
	eq(window_mapping(win, "<Tab>").desc, "Git | Diff: Select Next Diffview Entry")
	eq(window_mapping(win, "g<C-x>").mapped, false)
end

T["git: Differ mappings come from git actions"] = function()
	use_repo({ ["a.txt"] = "a\n" })
	change({ ["a.txt"] = "a2\n" })
	child.lua(WINDOW_PROBES_LUA)
	child.cmd("Differ")
	eq(child.wait("TopLeftWindow().filetype == 'differpanel'", ASYNC_MS), true)
	local win = child.lua_get("TopLeftWindow().win")

	expect_action_shortcut("differ.next_hunk", "]c")
	eq(window_mapping(win, "]c").buffer, true)
	eq(window_mapping(win, "[c").mapped, false)
end

T["git: Codediff mappings come from git actions"] = function()
	use_repo({ ["a.txt"] = "a\n" })
	change({ ["a.txt"] = "a2\n" })
	child.lua(WINDOW_PROBES_LUA)
	child.cmd("CodeDiff")
	eq(child.wait("WindowWithFt('codediff-explorer') ~= nil", ASYNC_MS), true)
	eq(
		child.wait(
			[[vim.iter(vim.api.nvim_tabpage_list_wins(0)):any(function(candidate)
		return vim.api.nvim_win_call(candidate, function()
			return next(vim.fn.maparg("]c", "n", false, true)) ~= nil
		end)
	end)]],
			ASYNC_MS
		),
		true
	)
	local win = child.lua_get([[vim.iter(vim.api.nvim_tabpage_list_wins(0)):find(function(candidate)
		return vim.api.nvim_win_call(candidate, function()
			return next(vim.fn.maparg("]c", "n", false, true)) ~= nil
		end)
	end)]])

	expect_action_shortcut("codediff.next_hunk", "]c")
	eq(window_mapping(win, "]c").buffer, true)
	eq(window_mapping(win, "[c").mapped, false)
end

T["git: tab moves to next entry"] = function()
	use_repo({ ["a.txt"] = "a\n", ["b.txt"] = "b\n" })
	change({ ["a.txt"] = "a2\n", ["b.txt"] = "b2\n" })
	open_diffview("a.txt")
	focus_diff_window("a.txt", "<Tab>")
	press_in_diffview("<Tab>")

	eq(child.wait(("WindowWithFile(%q) ~= nil"):format(path("b.txt")), ASYNC_MS), true)
	eq(child.lua_get(("WindowWithFile(%q)"):format(path("a.txt"))), vim.NIL)
	local current_b = ([[vim.wo.diff and vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0) == %q]]):format(
		path("b.txt")
	)
	eq(child.wait(current_b, ASYNC_MS), true)
end

T["git: j selects next entry from file panel"] = function()
	use_repo({ ["a.txt"] = "a\n", ["b.txt"] = "b\n" })
	change({ ["a.txt"] = "a2\n", ["b.txt"] = "b2\n" })
	open_diffview("a.txt")
	focus_panel_entry("a.txt")
	press_in_diffview("j")

	eq(child.wait(("WindowWithFile(%q) ~= nil"):format(path("b.txt")), ASYNC_MS), true)
	eq(child.lua_get(("WindowWithFile(%q)"):format(path("a.txt"))), vim.NIL)
end

T["git: k selects previous entry from file panel"] = function()
	use_repo({ ["a.txt"] = "a\n", ["b.txt"] = "b\n" })
	change({ ["a.txt"] = "a2\n", ["b.txt"] = "b2\n" })
	open_diffview("a.txt")
	focus_diff_window("a.txt", "<Tab>")
	press_in_diffview("<Tab>")
	eq(child.wait(("WindowWithFile(%q) ~= nil"):format(path("b.txt")), ASYNC_MS), true)
	focus_panel_entry("b.txt")
	press_in_diffview("k")

	eq(child.wait(("WindowWithFile(%q) ~= nil"):format(path("a.txt")), ASYNC_MS), true)
	eq(child.lua_get(("WindowWithFile(%q)"):format(path("b.txt"))), vim.NIL)
end

T["git: s stages entry from file panel"] = function()
	use_repo({ ["a.txt"] = "a\n" })
	change({ ["a.txt"] = "a2\n" })
	open_diffview("a.txt")
	focus_panel_entry("a.txt")
	child.type_keys("s")

	eq(
		vim.wait(ASYNC_MS, function()
			return vim.deep_equal(staged_files(), { "a.txt" })
		end, 50),
		true
	)
end

T["git: q closes diffview from file panel"] = function()
	use_repo({ ["a.txt"] = "a\n" })
	change({ ["a.txt"] = "a2\n" })
	local tabs = tab_count()
	open_diffview("a.txt")
	focus_panel_entry("a.txt")
	child.type_keys("q")

	eq(child.wait(("#vim.api.nvim_list_tabpages() == %d"):format(tabs), ASYNC_MS), true)
	eq(child.lua_get("WindowWithFt('DiffviewFiles')"), vim.NIL)
end

T["git: dx drops both conflict sides"] = function()
	use_repo({ ["c.txt"] = "top\nbase\nbottom\n" })
	make_conflict("c.txt")
	open_diffview("c.txt")
	local win = focus_diff_window("c.txt", "dx")
	local lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
	local inside = assert(vim.iter(ipairs(lines)):find(function(_, line)
		return line == "ours"
	end))
	child.api.nvim_win_set_cursor(win, { inside, 0 })
	child.type_keys("dx")

	eq(child.api.nvim_buf_get_lines(child.api.nvim_win_get_buf(win), 0, -1, false), { "top", "bottom" })
end

T["git: Gitlink copies current line URL"] = function()
	local sha = use_linked_repo("https://github.com/owner/repo.git")
	child.api.nvim_win_set_cursor(0, { 10, 0 })
	child.cmd("Gitlink")

	eq(child.fn.getreg("+"), ("https://github.com/owner/repo/blob/%s/a.txt#L10"):format(sha))
end

T["git: pgw.dev remote uses GitHub URL format"] = function()
	local sha = use_linked_repo("git@pgw.dev:owner/repo.git")
	child.api.nvim_win_set_cursor(0, { 7, 0 })
	child.cmd("Gitlink")

	eq(child.fn.getreg("+"), ("https://pgw.dev/owner/repo/blob/%s/a.txt#L7"):format(sha))
end

return T

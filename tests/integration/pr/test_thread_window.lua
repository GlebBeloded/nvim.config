local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")
local pr482 = require("tests.fixtures.gh.pr482")
local mutations = require("tests.fixtures.gh.mutations")

local eq = MiniTest.expect.equality
local child = H.new_child()
local T = H.child_set(child, child.start_config)

local function timeout()
	return math.floor(5000 * H.load_factor())
end

---@param mutate? fun(files: table<string, string>)
---@return string
---@return string
local function open_review(mutate)
	child.wait_very_lazy()
	child.o.lines = 30
	child.o.columns = 100
	local root, manifest = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	root = vim.fs.normalize(vim.fn.resolve(root))
	local files = pr482(manifest)
	if mutate then
		mutate(files)
	end
	local gh_dir = vim.fn.tempname()
	local gh_log = vim.fn.tempname()
	H.write_files(gh_dir, files)
	child.lua([[vim.env.FAKE_GH_DIR = ...; vim.env.FAKE_GH_LOG = select(2, ...)]], { gh_dir, gh_log })
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
	child.lua(
		[[local root = ...
		Ready = false
		require("gleb.git.base").resolve(root, function()
			vim.api.nvim_create_autocmd("User", {
				pattern = "GlebPrThreads",
				once = true,
				callback = function() Ready = true end,
			})
			require("gleb.pr").refresh(root)
		end)]],
		{ root }
	)
	assert(child.wait("Ready == true", timeout()), "Pull request threads did not load")
	child.lua([[require("gleb.pr").now = function()
		return os.time({ year = 2026, month = 1, day = 2, hour = 1 })
	end]])
	return root, gh_log
end

---@param id string
local function run_action(id)
	child.lua(
		[[local action = assert(require("gleb.actions").state.applicator.catalog:get(...), "action is not registered")
		action.run(require("gleb.actions.context").capture())]],
		{ id }
	)
end

local function thread_windows()
	return child.lua_get([[(function()
		local result = {}
		local module = package.loaded["gleb.pr.thread_window"]
		local state = module and module.state.by_tab[vim.api.nvim_get_current_tabpage()]
		for _, win in ipairs(state and { state.messages_win, state.reply_win, state.hint_win } or {}) do
			local buf = vim.api.nvim_win_get_buf(win)
			local config = vim.api.nvim_win_get_config(win)
			result[#result + 1] = {
				current = win == vim.api.nvim_get_current_win(),
				lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false),
				modifiable = vim.bo[buf].modifiable,
				row = config.row,
				col = config.col,
				width = config.width,
				height = config.height,
				title = config.title and vim.iter(config.title):map(function(part) return part[1] end):join("") or "",
			}
		end
		table.sort(result, function(a, b) return a.row < b.row end)
		return result
	end)()]])
end

---@param line integer
local function open_thread_at(line)
	child.lua([[vim.api.nvim_win_set_cursor(0, { ..., 0 })]], { line })
	run_action("pr.open_thread")
	assert(child.wait([[vim.bo.filetype == "gleb-pr-thread"]], timeout()), "thread reply did not take focus")
end

local REPLY = "Defaulting to Rate(0) now, see e325463."

---@param text? string
local function ask_to_send(text)
	open_thread_at(22)
	child.type_keys("<CR>", text or REPLY, "<Esc><CR>")
	assert(child.wait([[vim.bo.filetype == "gleb-pr-confirm"]], timeout()), "send confirmation did not open")
end

---@param line integer
local function ask_to_resolve(line)
	open_thread_at(line)
	child.type_keys("R")
	assert(child.wait([[vim.bo.filetype == "gleb-pr-confirm"]], timeout()), "resolve confirmation did not open")
end

---@param id string
---@param resolved boolean
local function serve_resolution(id, resolved)
	child.lua(
		[[local id, resolved = ...
		local path = vim.fs.joinpath(vim.env.FAKE_GH_DIR, "ReviewThreads.json")
		local response = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
		for _, thread in ipairs(response.data.repository.pullRequest.reviewThreads.nodes) do
			if thread.id == id then
				thread.isResolved = resolved
				thread.viewerCanUnresolve = resolved
				thread.resolvedBy = resolved and { login = "gleb-beloded" } or vim.NIL
			end
		end
		vim.fn.writefile({ vim.json.encode(response) }, path)]],
		{ id, resolved }
	)
end

---@param gh_log string
---@param needle string
---@return string[]
local function log_lines(gh_log, needle)
	return vim.tbl_filter(function(line)
		return line:find(needle, 1, true) ~= nil
	end, vim.fn.readfile(gh_log))
end

local function wait_unblocked()
	assert(
		vim.wait(timeout(), function()
			return not child.is_blocked()
		end, 20),
		"thread action did not return"
	)
end

T["pr: Thread window colours"] = function()
	child.cmd("colorscheme gruvbox-material")

	H.expect_hl_colors(child, "PrConfirm", { fg = "#d8a657", bg = "#4b4131", bold = true })
	H.expect_hl_colors(child, "PrConfirmHint", { fg = "#ddc7a1", bg = "#4b4131" })
	H.expect_hl_colors(child, "PrReplyPlaceholder", { fg = "#7c6f64", italic = true })
end

T["pr: Open thread shows the thread centred"] = function()
	open_review()
	child.lua([[vim.api.nvim_win_set_cursor(0, { 22, 0 })]])
	run_action("pr.open_thread")
	assert(child.wait([[vim.bo.filetype == "gleb-pr-thread"]], timeout()), "thread reply did not take focus")

	local windows = thread_windows()
	eq(#windows, 3)
	eq({ windows[1].row, windows[1].col, windows[1].width }, { 5, 14, 70 })
	eq(windows[1].title, " invoice.go:22 · PR #482 · open ")
	eq(windows[1].lines, {
		"  22 \tif i.Tax == nil {",
		"",
		"maria.k · 2h",
		"Should a nil rate mean no tax at all?",
		"A missing config would silently drop tax.",
		"",
		"gleb-beloded · 1h",
		"Good catch, defaulting to Rate(0) and",
		"logging a warning.",
		"",
	})
	eq(windows[2].lines, { "", "", "" })
	eq(windows[2].current, true)
	eq(windows[2].modifiable, true)
	eq(child.lua_get([[vim.fn.mode()]]), "n")
	eq(vim.endswith(windows[3].lines[1], " Reply ↩ · Resolve R · Open on web gx · Close q "), true)
	eq(vim.fn.strdisplaywidth(windows[3].lines[1]), 70)
end

T["pr: Open thread without a thread on the line"] = function()
	open_review()
	local notifications = H.record_notify(child)
	child.lua([[vim.api.nvim_win_set_cursor(0, { 1, 0 })]])
	run_action("pr.open_thread")

	assert(child.wait([[#Notifications == 1]], timeout()), "no-thread notification did not arrive")
	eq(notifications(), { { msg = "No thread on this line", level = vim.log.levels.INFO } })
	eq(#thread_windows(), 0)
end

T["pr: An unmapped thread window shows its diff hunk"] = function()
	local hunk = table.concat({ "@@ -7,4 +7,0 @@", " context", "-first", "-second", "-third", "-fourth" }, "\n")
	open_review(function(files)
		local response = vim.json.decode(files["ReviewThreads.json"])
		local thread = response.data.repository.pullRequest.reviewThreads.nodes[1]
		thread.diffSide = "LEFT"
		thread.line = 22
		thread.comments.nodes[1].diffHunk = hunk
		files["ReviewThreads.json"] = vim.json.encode(response)
	end)
	run_action("changes.show_comments")
	assert(
		child.wait(
			[[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		return panel and panel.tabs_ready and panel.active_tab == "comments"
	end)()]],
			timeout()
		),
		"Comments tab did not open"
	)
	child.lua([[(function()
		local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
		for index, row in pairs(panel.rows) do
			if row.thread and row.thread.id == "PRRT_t1" then
				vim.api.nvim_win_set_cursor(panel.win, { index, 0 })
				return
			end
		end
		error("thread row not found")
	end)()]])
	child.type_keys("<CR>")
	assert(child.wait([[vim.bo.filetype == "gleb-pr-thread"]], timeout()), "unmapped thread window did not open")

	local messages = thread_windows()[1]
	eq(vim.list_slice(messages.lines, 1, 4), { "-first", "-second", "-third", "-fourth" })
	eq(vim.endswith(messages.title, "· open "), true)
end

T["pr: Enter on an empty reply starts writing"] = function()
	open_review()
	open_thread_at(22)
	child.type_keys("<CR>")

	assert(child.wait([[vim.fn.mode() == "i"]], timeout()), "empty reply did not enter Insert mode")
	eq(
		child.lua_get(
			[[vim.api.nvim_get_current_win() == require("gleb.pr.thread_window").state.by_tab[vim.api.nvim_get_current_tabpage()].reply_win]]
		),
		true
	)
end

T["pr: gx opens the thread on the web"] = function()
	open_review()
	child.lua([[OpenedUrls = {} vim.ui.open = function(url) table.insert(OpenedUrls, url) end]])
	open_thread_at(22)
	child.type_keys("gx")

	eq(child.lua_get([[OpenedUrls]]), {
		"https://pgw.dev/finteqhub/billing/pull/482#discussion_r1",
	})
end

T["pr: q keeps the draft for the next open"] = function()
	open_review()
	open_thread_at(22)
	child.type_keys("<CR>Draft<Esc>")
	eq(child.lua_get([[vim.fn.maparg("q", "n") ~= ""]]), true)
	child.type_keys("q")
	assert(child.wait([[#vim.api.nvim_list_wins() == 1]], timeout()), "thread window did not close")
	eq(#thread_windows(), 0)

	open_thread_at(22)
	eq(thread_windows()[2].lines, { "Draft", "", "" })
end

T["pr: Resolved thread offers Unresolve"] = function()
	open_review()
	open_thread_at(11)

	local windows = thread_windows()
	eq(vim.endswith(windows[1].title, "· resolved "), true)
	eq(vim.endswith(windows[3].lines[1], " Reply ↩ · Unresolve R · Open on web gx · Close q "), true)
end

T["pr: Resolve is hidden without permission"] = function()
	local _, gh_log = open_review(function(files)
		local response = vim.json.decode(files["ReviewThreads.json"])
		response.data.repository.pullRequest.reviewThreads.nodes[1].viewerCanResolve = false
		files["ReviewThreads.json"] = vim.json.encode(response)
	end)
	open_thread_at(22)
	local before = thread_windows()[3].lines[1]
	child.type_keys("R")

	eq(vim.endswith(before, " Reply ↩ · Open on web gx · Close q "), true)
	eq(thread_windows()[3].lines[1], before)
	eq(
		vim.tbl_filter(function(line)
			return line:find("mutation", 1, true) ~= nil
		end, vim.fn.readfile(gh_log)),
		{}
	)
end

T["pr: Thread window keys come from the shortcut file"] = function()
	open_review()
	open_thread_at(22)

	local mappings = child.lua_get([[
		(function()
			local context = require("gleb.actions.context")
			local original = context.execute
			local invoked
			context.execute = function(action)
				invoked = action.id
				return true
			end
			local result = {}
			for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
				invoked = nil
				mapping.callback()
				table.insert(result, { mapping.lhs, mapping.desc, invoked })
			end
			context.execute = original
			table.sort(result, function(a, b) return a[1] < b[1] end)
			return result
		end)()
	]])
	eq(mappings, {
		{ "<CR>", "Git | Pull Request: Reply to Thread", "pr.thread_send" },
		{ "R", "Git | Pull Request: Resolve or Unresolve Thread", "pr.thread_resolve" },
		{ "gx", "Git | Pull Request: Open Thread on Web", "pr.thread_open_web" },
		{ "q", "Git | Pull Request: Close Thread", "pr.thread_close" },
	})
	eq(vim.endswith(thread_windows()[3].lines[1], " Reply ↩ · Resolve R · Open on web gx · Close q "), true)
end

T["pr: Enter asks before sending a reply"] = function()
	local _, gh_log = open_review(function(files)
		files["AddReply.json"] = mutations.reply
	end)
	ask_to_send()

	local windows = thread_windows()
	eq(vim.startswith(windows[3].lines[1], " Send this reply to maria.k on pgw.dev?"), true)
	eq(vim.endswith(windows[3].lines[1], "Send y · Keep editing n "), true)
	eq(child.lua_get([[vim.bo.filetype]]), "gleb-pr-confirm")
	eq(child.lua_get([[vim.bo.modifiable]]), false)
	eq(child.lua_get([[vim.fn.maparg("y", "n", false, true).desc]]), "Git | Pull Request: Confirm")
	eq(child.lua_get([[vim.fn.maparg("n", "n", false, true).desc]]), "Git | Pull Request: Cancel")
	eq(child.lua_get([[vim.fn.maparg("<Esc>", "n", false, true).desc]]), "Git | Pull Request: Cancel")
	eq(log_lines(gh_log, "mutation"), {})
end

T["pr: y sends the reply"] = function()
	local _, gh_log = open_review(function(files)
		files["AddReply.json"] = mutations.reply
	end)
	local notifications = H.record_notify(child)
	ask_to_send()
	child.type_keys("y")
	wait_unblocked()

	assert(
		child.wait(
			[[#Notifications == 1 and #vim.tbl_filter(function(line)
				return line:find("query ReviewThreads", 1, true) ~= nil
			end, vim.fn.readfile(vim.env.FAKE_GH_LOG)) == 2]],
			timeout()
		),
		"reply mutation and refresh did not finish"
	)
	eq(#log_lines(gh_log, "mutation AddReply"), 1)
	eq(log_lines(gh_log, "mutation AddReply")[1]:find("-f id=PRRT_t1", 1, true) ~= nil, true)
	eq(log_lines(gh_log, "mutation AddReply")[1]:find("-f body=" .. REPLY, 1, true) ~= nil, true)
	eq(notifications(), { { msg = "Reply sent", level = vim.log.levels.INFO } })
	eq(thread_windows()[2].lines, { "", "", "" })
	eq(child.lua_get([[vim.bo.filetype]]), "gleb-pr-thread")
	eq(vim.endswith(thread_windows()[3].lines[1], " Reply ↩ · Resolve R · Open on web gx · Close q "), true)
end

T["pr: n keeps editing"] = function()
	local _, gh_log = open_review(function(files)
		files["AddReply.json"] = mutations.reply
	end)
	ask_to_send()
	child.type_keys("n")

	assert(child.wait([[vim.fn.mode() == "i"]], timeout()), "reply editing did not resume")
	eq(child.lua_get([[vim.bo.filetype]]), "gleb-pr-thread")
	eq(child.lua_get([[vim.api.nvim_win_get_cursor(0)]]), { 1, #REPLY - 1 })
	eq(thread_windows()[2].lines[1], REPLY)
	eq(vim.endswith(thread_windows()[3].lines[1], " Reply ↩ · Resolve R · Open on web gx · Close q "), true)
	eq(log_lines(gh_log, "mutation"), {})
end

T["pr: A failed reply keeps the draft"] = function()
	open_review(function(files)
		files["AddReply.json"] = mutations.reply
		files["AddReply.json.stderr"] = "HTTP 502: Bad Gateway\n"
		files["AddReply.json.code"] = "1\n"
	end)
	local notifications = H.record_notify(child)
	ask_to_send()
	child.type_keys("y")
	wait_unblocked()

	assert(child.wait([[#Notifications == 1]], timeout()), "reply failure was not reported")
	eq(notifications(), { { msg = "Reply failed: HTTP 502: Bad Gateway", level = vim.log.levels.ERROR } })
	eq(thread_windows()[2].lines[1], REPLY)
	eq(child.lua_get([[vim.bo.filetype]]), "gleb-pr-thread")
	eq(child.lua_get([[vim.bo.modifiable]]), true)
	eq(vim.endswith(thread_windows()[3].lines[1], " Reply ↩ · Resolve R · Open on web gx · Close q "), true)
end

T["pr: The reply goes to gh as one argument"] = function()
	local body = [[it's "fine" $(touch /tmp/pwned) @notes.md]]
	eq(vim.uv.fs_stat("/tmp/pwned"), nil)
	local _, gh_log = open_review(function(files)
		files["AddReply.json"] = mutations.reply
	end)
	ask_to_send(body)
	child.type_keys("y")
	wait_unblocked()

	assert(child.wait([[#vim.fn.readfile(vim.env.FAKE_GH_LOG) >= 3]], timeout()), "reply did not refresh")
	local lines = log_lines(gh_log, "mutation AddReply")
	eq(#lines, 1)
	eq(lines[1]:find("-f body=" .. body, 1, true) ~= nil, true)
	eq(vim.uv.fs_stat("/tmp/pwned"), nil)
end

T["pr: R asks before resolving"] = function()
	local _, gh_log = open_review(function(files)
		files["ResolveThread.json"] = mutations.resolve
	end)
	ask_to_resolve(22)

	local windows = thread_windows()
	eq(vim.startswith(windows[3].lines[1], " Resolve this thread?"), true)
	eq(vim.endswith(windows[3].lines[1], "Resolve y · Cancel n "), true)
	eq(child.lua_get([[vim.bo.modifiable]]), false)
	eq(log_lines(gh_log, "mutation"), {})
end

T["pr: y resolves the thread"] = function()
	local _, gh_log = open_review(function(files)
		files["ResolveThread.json"] = mutations.resolve
	end)
	local notifications = H.record_notify(child)
	ask_to_resolve(22)
	serve_resolution("PRRT_t1", true)
	child.type_keys("y")
	wait_unblocked()

	assert(
		child.wait(
			[[#Notifications == 1 and require("gleb.pr.thread_window").state.by_tab[vim.api.nvim_get_current_tabpage()].thread.resolved]],
			timeout()
		),
		"resolve mutation and refresh did not finish"
	)
	local lines = log_lines(gh_log, "mutation ResolveThread")
	eq(#lines, 1)
	eq(lines[1]:find("-f id=PRRT_t1", 1, true) ~= nil, true)
	eq(notifications(), { { msg = "Thread resolved", level = vim.log.levels.INFO } })
	eq(vim.endswith(thread_windows()[1].title, "· resolved "), true)
end

T["pr: y unresolves a resolved thread"] = function()
	local _, gh_log = open_review(function(files)
		files["UnresolveThread.json"] = mutations.unresolve
	end)
	local notifications = H.record_notify(child)
	ask_to_resolve(11)
	eq(vim.startswith(thread_windows()[3].lines[1], " Unresolve this thread?"), true)
	serve_resolution("PRRT_t4", false)
	child.type_keys("y")
	wait_unblocked()

	assert(child.wait([[#Notifications == 1]], timeout()), "unresolve mutation did not finish")
	local lines = log_lines(gh_log, "mutation UnresolveThread")
	eq(#lines, 1)
	eq(lines[1]:find("-f id=PRRT_t4", 1, true) ~= nil, true)
	eq(notifications(), { { msg = "Thread unresolved", level = vim.log.levels.INFO } })
end

T["pr: A failed resolve is reported"] = function()
	open_review(function(files)
		files["ResolveThread.json"] = mutations.errors
		files["ResolveThread.json.stderr"] = "Resource not accessible by integration\n"
		files["ResolveThread.json.code"] = "1\n"
	end)
	local notifications = H.record_notify(child)
	ask_to_resolve(22)
	child.type_keys("y")
	wait_unblocked()

	assert(child.wait([[#Notifications == 1]], timeout()), "resolve failure was not reported")
	eq(notifications(), {
		{ msg = "Resolve failed: Resource not accessible by integration", level = vim.log.levels.ERROR },
	})
	eq(vim.endswith(thread_windows()[1].title, "· open "), true)
	eq(child.lua_get([[vim.bo.filetype]]), "gleb-pr-thread")
	eq(vim.endswith(thread_windows()[3].lines[1], " Reply ↩ · Resolve R · Open on web gx · Close q "), true)
end

return T

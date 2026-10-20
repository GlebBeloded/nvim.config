local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")
local pr482 = require("tests.fixtures.gh.pr482")

local eq = MiniTest.expect.equality
local child = H.new_child()
local T = H.child_set(child, child.start_config)

local function timeout()
	return math.floor(5000 * H.load_factor())
end

---@param mutate? fun(files: table<string, string>)
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
	H.write_files(gh_dir, files)
	child.lua([[vim.env.FAKE_GH_DIR = ...]], { gh_dir })
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
	return root
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

return T

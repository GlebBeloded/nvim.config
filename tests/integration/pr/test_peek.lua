local MiniTest = require("mini.test")
local F = require("tests.fixtures")
local H = require("tests.helpers")
local pr482 = require("tests.fixtures.gh.pr482")

local eq = MiniTest.expect.equality
local child = H.new_child()

local function start()
	local root, manifest = F.copy("billing-branch", vim.fn.tempname() .. "/billing-branch")
	root = vim.fs.normalize(vim.fn.resolve(root))
	local gh_dir = vim.fn.tempname()
	H.write_files(gh_dir, pr482(manifest))
	child.start_config()
	child.lua([[vim.env.FAKE_GH_DIR = ...]], { gh_dir })
	child.cmd("cd " .. vim.fn.fnameescape(root))
	child.cmd("edit " .. vim.fn.fnameescape(vim.fs.joinpath(root, "internal/billing/invoice.go")))
	child.lua(
		[[
		local root = ...
		Ready = false
		require("gleb.git.base").resolve(root, function()
			vim.api.nvim_create_autocmd("User", { pattern = "GlebPrThreads", once = true, callback = function()
				Ready = true
			end })
			require("gleb.pr").refresh(root)
		end)
	]],
		{ root }
	)
	assert(child.wait("Ready == true", math.floor(5000 * H.load_factor())), "PR peeks did not load")
	child.lua([[require("gleb.pr").now = function() return os.time({ year = 2026, month = 1, day = 2, hour = 1 }) end]])
	child.lua([[vim.api.nvim_win_set_cursor(0, { 18, 0 })]])
	assert(
		child.wait(
			[[(function()
		local ns = vim.api.nvim_get_namespaces().gleb_pr_peek
		return ns and #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) > 0
	end)()]],
			math.floor(5000 * H.load_factor())
		),
		"PR peek extmarks did not draw"
	)
	return root, gh_dir
end

local T = H.child_set(child, start)

---@param line integer
---@return table[]
local function virt_lines(line)
	return child.lua_get(
		[[(function(line)
		local ns = vim.api.nvim_get_namespaces().gleb_pr_peek
		if not ns then return {} end
		local marks = vim.api.nvim_buf_get_extmarks(0, ns, { line - 1, 0 }, { line - 1, -1 }, { details = true })
		return marks[1] and marks[1][4].virt_lines or {}
	end)(...)]],
		{ line }
	)
end

local function virt_text(line)
	return vim.tbl_map(function(segments)
		return vim.trim(vim.iter(segments):fold("", function(text, segment)
			return text .. segment[1]
		end))
	end, virt_lines(line))
end

T["pr: Open threads peek as one line"] = function()
	eq(virt_text(22), { "╰─ 󰆈 maria.k Should a nil rate mean no tax at all? +1 reply" })
	eq(virt_text(13), { "╰─ 󰆈 ivan.p Rate or *Rate here?" })
	local groups = vim.tbl_map(function(segment)
		return segment[2]
	end, virt_lines(22)[1])
	eq(vim.list_slice(groups, 2), { "PrPeekMeta", "PrPeekIcon", "PrPeekAuthor", "PrPeek", "PrPeekMeta" })
end

T["pr: Peek expands at the cursor line"] = function()
	child.lua([[vim.api.nvim_win_set_cursor(0, { 22, 0 })]])
	assert(
		child.wait(
			"#vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces().gleb_pr_peek, {21, 0}, {21, -1}, {details=true}) > 0",
			1000
		)
	)
	local expanded = virt_text(22)
	eq(#expanded, 8)
	eq(expanded[1]:find("PR #482 · 2 comments", 1, true) ~= nil, true)
	eq(expanded[2]:find("maria.k · 2h", 1, true) ~= nil, true)
	eq(expanded[5]:find("gleb-beloded · 1h", 1, true) ~= nil, true)
	child.lua([[vim.api.nvim_win_set_cursor(0, { 23, 0 })]])
	eq(#virt_lines(22), 1)
end

T["pr: Resolved threads fold to one grey line"] = function()
	child.lua([[vim.api.nvim_win_set_cursor(0, { 11, 0 })]])
	local lines = virt_lines(11)
	eq(#lines, 1)
	eq(virt_text(11)[1]:find("╰─  Resolved · ivan.p: Should ID stay a string?", 1, true) ~= nil, true)
	for _, segment in ipairs(vim.list_slice(lines[1], 2)) do
		eq(segment[2], "PrThreadResolved")
	end
end

T["pr: Outdated threads are hidden in code"] = function()
	child.cmd("edit internal/billing/tax.go")
	eq(child.lua_get([[#vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces().gleb_pr_peek, 0, -1, {})]]), 0)
end

T["pr: Peeks follow the threads"] = function()
	local gh_dir = child.lua_get([[vim.env.FAKE_GH_DIR]])
	local response = vim.json.decode(table.concat(vim.fn.readfile(vim.fs.joinpath(gh_dir, "ReviewThreads.json")), "\n"))
	local nodes = response.data.repository.pullRequest.reviewThreads.nodes
	response.data.repository.pullRequest.reviewThreads.nodes = vim.tbl_filter(function(thread)
		return thread.id ~= "PRRT_t2"
	end, nodes)
	vim.fn.writefile({ vim.json.encode(response) }, vim.fs.joinpath(gh_dir, "ReviewThreads.json"))
	child.lua([[ThreadsDone = false
		vim.api.nvim_create_autocmd("User", { pattern = "GlebPrThreads", once = true, callback = function()
			ThreadsDone = true
		end })
		require("gleb.pr").refresh(vim.fn.getcwd())]])
	assert(child.wait("ThreadsDone == true", math.floor(5000 * H.load_factor())), "PR refresh did not finish")
	eq(#virt_lines(13), 0)
	eq(#virt_lines(22), 1)
end

T["pr: Peek cut follows window width"] = function()
	child.cmd("vsplit")
	local narrow = virt_text(22)[1]
	child.lua([[vim.api.nvim_win_set_cursor(0, { 22, 0 })]])
	local narrow_border = virt_text(22)[1]
	child.cmd("only")
	assert(child.wait([[vim.api.nvim_win_get_width(0) > 60]]), "editor did not widen")
	local wide_border = virt_text(22)[1]
	child.lua([[vim.api.nvim_win_set_cursor(0, { 23, 0 })]])
	local wide = virt_text(22)[1]
	eq(vim.fn.strdisplaywidth(wide) > vim.fn.strdisplaywidth(narrow), true)
	eq(vim.fn.strdisplaywidth(wide_border) > vim.fn.strdisplaywidth(narrow_border), true)
	eq(wide, "╰─ 󰆈 maria.k Should a nil rate mean no tax at all? +1 reply")
end

---@param id string
local function run_action(id)
	child.lua(
		[[
		local action = assert(require("gleb.actions").state.applicator.catalog:get(...))
		action.run(require("gleb.actions.context").capture())
	]],
		{ id }
	)
end

--- Run action `id` `times` times from line `from`; the cursor line and file after each run.
---@param id string
---@param from integer
---@param times integer
---@return string[]
local function walk(id, from, times)
	child.lua([[vim.api.nvim_win_set_cursor(0, { ..., 0 })]], { from })
	local stops = {}
	for _ = 1, times do
		run_action(id)
		stops[#stops + 1] = child.lua_get([[vim.fs.basename(vim.api.nvim_buf_get_name(0)) .. ":" .. vim.fn.line(".")]])
	end
	return stops
end

T["pr: pr.next_thread visits the open threads"] = function()
	local notifications = H.record_notify(child)
	eq(walk("pr.next_thread", 1, 3), { "invoice.go:13", "invoice.go:22", "invoice.go:22" })
	eq(notifications(), { { msg = "No next thread", level = vim.log.levels.INFO } })
end

T["pr: pr.prev_thread goes back"] = function()
	local notifications = H.record_notify(child)
	eq(walk("pr.prev_thread", 30, 3), { "invoice.go:22", "invoice.go:13", "invoice.go:13" })
	eq(notifications(), { { msg = "No previous thread", level = vim.log.levels.INFO } })
end

T["pr: Thread actions are unbound Find Action entries"] = function()
	local entries = child.lua_get([[(function()
		local catalog = require("gleb.actions").state.applicator.catalog
		local shortcuts = vim.json.decode(table.concat(vim.fn.readfile(
			vim.fs.joinpath(vim.fn.stdpath("config"), "settings/keymap.json")
		), "\n"))
		local entries = {}
		for _, id in ipairs({ "pr.next_thread", "pr.prev_thread", "changes.show_comments" }) do
			local action = catalog:get(id)
			entries[id] = { title = action and action.title, category = action and action.category, shortcut = shortcuts[id] }
		end
		return entries
	end)()]])
	eq(entries, {
		["pr.next_thread"] = { title = "Next Review Thread", category = "Git | Pull Request" },
		["pr.prev_thread"] = { title = "Previous Review Thread", category = "Git | Pull Request" },
		["changes.show_comments"] = { title = "Show Pull Request Comments", category = "View | Tool Windows" },
	})
end

--- Run `action` and wait until the panel's `tab` shows the diff of `invoice.go`.
---@param action string
---@param tab string
local function show_invoice_diff(action, tab)
	run_action(action)
	assert(
		child.wait(
			([[(function()
			local panel = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()]
			local view = panel and panel.diff_view
			return panel ~= nil and panel.active_tab == %q and view ~= nil
				and vim.endswith(view.path, "internal/billing/invoice.go")
		end)()]]):format(tab),
			math.floor(5000 * H.load_factor())
		),
		("the %s tab did not show the diff of invoice.go"):format(tab)
	)
end

--- The diff view's virtual lines on `side`: `{ line = <1-based>, above = <bool>, text = { <row text>... } }`.
---@param side "left"|"right"
---@return { line: integer, above: boolean, text: string[] }[]
local function diff_virt_lines(side)
	return child.lua_get(
		[[(function(side)
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()].diff_view
		local buf = side == "left" and view.left_buf or view.right_buf
		local result = {}
		for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, view.ns, 0, -1, { details = true })) do
			if mark[4].virt_lines then
				local text = vim.tbl_map(function(chunks)
					return vim.trim(vim.iter(chunks):fold("", function(acc, chunk) return acc .. chunk[1] end))
				end, mark[4].virt_lines)
				table.insert(result, { line = mark[2] + 1, above = mark[4].virt_lines_above == true, text = text })
			end
		end
		return result
	end)(...)]],
		{ side }
	)
end

--- Rows of padding (`pad`), blank (`blank`) or peek text in virtual lines.
---@param text string[]
---@return string[]
local function row_kinds(text)
	return vim.tbl_map(function(row)
		return row == "" and "blank" or row:gsub("╱", "") == "" and "pad" or row
	end, text)
end

--- `PRRT_t1`'s collapsed peek, one line cut to the pane's width.
---@param text string[]
---@return boolean
local function is_t1_peek(text)
	return #text == 1 and vim.startswith(text[1], "╰─ 󰆈 maria.k S") and vim.endswith(text[1], " +1 reply")
end

T["pr: Diff view peeks keep the panes aligned"] = function()
	child.o.lines = 60 -- the whole diff fits, so both panes show it from their first line
	show_invoice_diff("changes.show_branch", "branch")
	local right = vim.tbl_filter(function(mark)
		return mark.line == 22 and not mark.above
	end, diff_virt_lines("right"))
	eq(#right, 1)
	eq(is_t1_peek(right[1].text), true)
	-- right lines 22-24 are new: their left padding rows hold the blank under the row of line 22
	local padding = vim.tbl_filter(function(mark)
		return mark.above and vim.tbl_contains(row_kinds(mark.text), "blank")
	end, diff_virt_lines("left"))
	eq(
		vim.tbl_map(function(mark)
			return row_kinds(mark.text)
		end, padding),
		{ { "pad", "blank", "pad", "pad" } }
	)
	local rows = child.lua_get([[(function()
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()].diff_view
		local last = #view.left
		local aligned = vim.iter(view.layout.rows):find(function(row) return row.left == last end).right
		for _, win in ipairs({ view.left_win, view.right_win }) do
			vim.api.nvim_win_call(win, function() vim.fn.winrestview({ topline = 1 }) end)
		end
		vim.cmd("redraw")
		return { vim.fn.screenpos(view.left_win, last, 1).row, vim.fn.screenpos(view.right_win, aligned, 1).row }
	end)()]])
	eq(rows[1] > 0, true)
	eq(rows[1], rows[2])
end

T["pr: Local diff peeks once"] = function()
	show_invoice_diff("changes.review", "local")
	local view = child.lua_get([[(function()
		local view = require("gleb.git.changes").state.by_tab[vim.api.nvim_get_current_tabpage()].diff_view
		local scope = vim.api.nvim__ns_get(vim.api.nvim_get_namespaces().gleb_pr_peek).wins or {}
		return {
			file_buffer = vim.api.nvim_buf_get_name(view.right_buf) == vim.api.nvim_buf_get_name(vim.fn.bufnr("invoice.go")),
			editor_peeks_in_right = vim.tbl_contains(scope, view.right_win),
		}
	end)()]])
	eq(view, { file_buffer = true, editor_peeks_in_right = false })
	local right = vim.tbl_filter(function(mark)
		return mark.line == 22
	end, diff_virt_lines("right"))
	eq(#right, 1)
	eq(is_t1_peek(right[1].text), true)
	local left = vim.tbl_filter(function(mark)
		return mark.line == 22
	end, diff_virt_lines("left"))
	eq(
		vim.tbl_map(function(mark)
			return mark.text
		end, left),
		{ { "" } }
	)
end

T["pr: Diff peek cut follows pane width"] = function()
	show_invoice_diff("changes.show_branch", "branch")
	local narrow = vim.tbl_filter(function(mark)
		return mark.line == 22 and not mark.above
	end, diff_virt_lines("right"))[1].text[1]
	child.o.columns = 160
	child.cmd("doautocmd VimResized")
	local wide = vim.tbl_filter(function(mark)
		return mark.line == 22 and not mark.above
	end, diff_virt_lines("right"))[1].text[1]
	eq(vim.fn.strdisplaywidth(wide) > vim.fn.strdisplaywidth(narrow), true)
end

return T

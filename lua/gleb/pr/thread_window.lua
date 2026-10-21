-- Review-thread window: one tab-local owner lays out thread context, comments, reply space, and hints.

local M = {}

local MAX_WIDTH = 72
local MIN_REPLY_HEIGHT = 3
local MAX_REPLY_HEIGHT = 8
local namespace = vim.api.nvim_create_namespace("gleb_pr_thread_window")
local action_rows = require("gleb.find_action.rows")

---@class gleb.pr.ThreadWindow
---@field tab integer
---@field review gleb.pr.Review
---@field thread gleb.pr.Thread
---@field messages_buf integer
---@field messages_win integer
---@field reply_buf integer
---@field reply_win integer
---@field hint_buf integer
---@field hint_win integer
---@field origin_win integer
---@field origin_scrolloff integer the origin's local 'scrolloff' before it was pinned
---@field group integer
---@field closing boolean
---@field mode "normal"|"confirm_send"|"confirm_resolve"|"running"
---@field operation? "send"|"resolve"|"unresolve"

---@class gleb.pr.ThreadHighlight
---@field line integer 0-based
---@field col integer
---@field end_col integer
---@field group string

---@class gleb.pr.ThreadMessages
---@field lines string[]
---@field highlights gleb.pr.ThreadHighlight[]
---@field vartabstop string tab stops of the source line, shifted past its line number

---@class gleb.pr.ThreadHintRow
---@field text string
---@field normal string the row's `Normal` group
---@field group string highlight of the span `col`..`end_col`
---@field col integer
---@field end_col integer

---@class gleb.pr.ThreadWindowState
---@field by_tab table<integer, gleb.pr.ThreadWindow>
---@field drafts table<string, string[]>

---@type gleb.pr.ThreadWindowState
M.state = { by_tab = {}, drafts = {} }

---@param text string
---@param width integer
---@return string[]
local function wrap(text, width)
	local result = {}
	for _, source in ipairs(vim.split(text, "\n", { plain = true })) do
		local line = ""
		for word in source:gmatch("%S+") do
			local candidate = line == "" and word or line .. " " .. word
			if line ~= "" and vim.fn.strdisplaywidth(candidate) > width then
				result[#result + 1] = line
				line = word
			else
				line = candidate
			end
		end
		result[#result + 1] = line
	end
	return result
end

---@return integer
local function wall_time()
	local now = require("gleb.pr").now()
	return now > 1000000000 and now or os.time()
end

---@param value string
---@return string
local function age(value)
	local created = vim.fn.strptime("%Y-%m-%dT%H:%M:%SZ", value)
	return require("gleb.git.changes.branch").age(math.max(0, wall_time() - created))
end

---@param thread gleb.pr.Thread
---@return string
local function state_label(thread)
	if thread.resolved then
		return "resolved"
	end
	return thread.outdated and "outdated" or "open"
end

---@param review gleb.pr.Review
---@param thread gleb.pr.Thread
---@return string?
---@return integer?
---@return integer? buf the loaded buffer the line comes from
local function source_line(review, thread)
	if thread.side == "LEFT" or thread.subject == "file" then
		return nil, nil, nil
	end
	local path = vim.fs.joinpath(review.root, thread.path)
	local line = thread.line or thread.original_line
	if not line then
		return nil, nil, nil
	end
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.fs.normalize(vim.api.nvim_buf_get_name(buf)) == path then
			return vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1], line, buf
		end
	end
	local lines = vim.fn.readfile(path, "", line)
	return lines[line], line, nil
end

--- The highlight group Tree-sitter draws at one position of `buf`: its last highlight capture there.
---@param buf integer
---@param row integer 0-based
---@param col integer 0-based byte
---@return string?
local function capture_group(buf, row, col)
	local captures = vim.tbl_filter(function(capture)
		return not vim.startswith(capture.capture, "_") and capture.capture ~= "spell" and capture.capture ~= "nospell"
	end, vim.treesitter.get_captures_at_pos(buf, row, col))
	local capture = captures[#captures]
	return capture and ("@%s.%s"):format(capture.capture, capture.lang)
end

--- The source buffer's Tree-sitter highlights of line `row`, shifted `offset` bytes right.
---@param buf integer
---@param row integer 0-based
---@param length integer bytes of the line
---@param offset integer
---@return gleb.pr.ThreadHighlight[]
local function capture_highlights(buf, row, length, offset)
	local highlights = {}
	for col = 0, length - 1 do
		local group = capture_group(buf, row, col)
		local last = highlights[#highlights]
		if group and last and last.group == group and last.end_col == offset + col then
			last.end_col = offset + col + 1
		elseif group then
			highlights[#highlights + 1] = { line = 0, col = offset + col, end_col = offset + col + 1, group = group }
		end
	end
	return highlights
end

---@param result gleb.pr.ThreadMessages
---@param comment gleb.pr.Comment
---@param width integer
local function add_comment(result, comment, width)
	local meta = " · " .. age(comment.created_at)
	local header = #result.lines
	result.lines[header + 1] = comment.author .. meta
	vim.list_extend(result.highlights, {
		{ line = header, col = 0, end_col = #comment.author, group = "PrPeekAuthor" },
		{ line = header, col = #comment.author, end_col = #comment.author + #meta, group = "PrPeekMeta" },
	})
	for _, body in ipairs(wrap(comment.body, width)) do
		result.highlights[#result.highlights + 1] = { line = #result.lines, col = 0, end_col = #body, group = "PrPeek" }
		result.lines[#result.lines + 1] = body
	end
	result.lines[#result.lines + 1] = ""
end

---@param review gleb.pr.Review
---@param thread gleb.pr.Thread
---@param width integer
---@return gleb.pr.ThreadMessages
local function message_lines(review, thread, width)
	local line, lnum, buf = source_line(review, thread)
	local result = { lines = {}, highlights = {}, vartabstop = "" }
	if line and lnum then
		local number = ("%4d "):format(lnum)
		local tabstop = buf and vim.bo[buf].tabstop or vim.o.tabstop
		result.lines[1] = number .. line
		result.vartabstop = ("%d,%d"):format(#number + tabstop, tabstop)
		result.highlights[1] = { line = 0, col = 0, end_col = #number, group = "LineNr" }
		if buf then
			vim.list_extend(result.highlights, capture_highlights(buf, lnum - 1, #line, #number))
		end
	else
		local comment = thread.comments[1]
		local hunk = comment and vim.split(comment.diff_hunk, "\n", { plain = true }) or {}
		result.lines = vim.list_slice(hunk, math.max(1, #hunk - 3), #hunk)
	end
	result.lines[#result.lines + 1] = ""
	for _, comment in ipairs(thread.comments) do
		add_comment(result, comment, width)
	end
	return result
end

--- Keep the code behind the window still: focus leaving the origin collapses its peek, and on the next redraw
--- 'scrolloff' would scroll the origin to centre its cursor again.
---@param win integer
---@return integer scrolloff the window's local value to restore
local function pin_origin(win)
	local scrolloff = vim.api.nvim_get_option_value("scrolloff", { win = win, scope = "local" })
	vim.api.nvim_set_option_value("scrolloff", 0, { win = win, scope = "local" })
	return scrolloff
end

---@param state gleb.pr.ThreadWindow
---@return nil
function M.close(state)
	if state.closing then
		return
	end
	state.closing = true
	if vim.api.nvim_win_is_valid(state.origin_win) then
		vim.api.nvim_set_option_value("scrolloff", state.origin_scrolloff, { win = state.origin_win, scope = "local" })
	end
	if vim.api.nvim_buf_is_valid(state.reply_buf) then
		M.state.drafts[state.thread.id] = vim.api.nvim_buf_get_lines(state.reply_buf, 0, -1, false)
	end
	M.state.by_tab[state.tab] = nil
	pcall(vim.api.nvim_del_augroup_by_id, state.group)
	for _, win in ipairs({ state.messages_win, state.reply_win, state.hint_win }) do
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
end

---@return gleb.pr.ThreadWindow?
local function current()
	return M.state.by_tab[vim.api.nvim_get_current_tabpage()]
end

---@type fun(state: gleb.pr.ThreadWindow)
local layout
---@type fun(buf: integer, lines: string[], modifiable: boolean)
local fill

---@param state gleb.pr.ThreadWindow
---@return boolean
local function reply_is_empty(state)
	return vim.iter(vim.api.nvim_buf_get_lines(state.reply_buf, 0, -1, false)):all(function(line)
		return line == ""
	end)
end

---@param state gleb.pr.ThreadWindow
---@return string
local function reply_text(state)
	local lines = vim.api.nvim_buf_get_lines(state.reply_buf, 0, -1, false)
	while #lines > 0 and lines[#lines] == "" do
		table.remove(lines)
	end
	return table.concat(lines, "\n")
end

---@param state gleb.pr.ThreadWindow
---@param resume_insert boolean
local function restore_editing(state, resume_insert)
	state.mode = "normal"
	state.operation = nil
	vim.bo[state.reply_buf].filetype = "gleb-pr-thread"
	vim.bo[state.reply_buf].modifiable = true
	layout(state)
	vim.api.nvim_set_current_win(state.reply_win)
	local lines = vim.api.nvim_buf_get_lines(state.reply_buf, 0, -1, false)
	local last = #lines
	while last > 1 and lines[last] == "" do
		last = last - 1
	end
	local line = vim.api.nvim_buf_get_lines(state.reply_buf, last - 1, last, false)[1]
	vim.api.nvim_win_set_cursor(state.reply_win, { last, #line })
	if resume_insert then
		vim.cmd.startinsert()
	end
end

---@return nil
function M.send()
	local state = current()
	if not state or state.mode ~= "normal" or not state.thread.can_reply then
		return
	end
	if reply_is_empty(state) then
		vim.api.nvim_set_current_win(state.reply_win)
		vim.api.nvim_win_set_cursor(state.reply_win, { 1, 0 })
		vim.cmd.startinsert()
		return
	end
	state.mode = "confirm_send"
	vim.bo[state.reply_buf].modifiable = false
	vim.bo[state.reply_buf].filetype = "gleb-pr-confirm"
	layout(state)
end

---@return nil
function M.confirm_no()
	local state = current()
	if not state or (state.mode ~= "confirm_send" and state.mode ~= "confirm_resolve") then
		return
	end
	restore_editing(state, state.mode == "confirm_send")
end

---@return nil
function M.confirm_yes()
	local state = current()
	if not state or (state.mode ~= "confirm_send" and state.mode ~= "confirm_resolve") then
		return
	end
	if state.mode == "confirm_resolve" then
		local resolved = not state.thread.resolved
		state.mode = "running"
		state.operation = resolved and "resolve" or "unresolve"
		layout(state)
		require("gleb.pr.gh").set_resolved(state.review, state.thread.id, resolved, nil, function(ok, message)
			local verb = resolved and "Resolve" or "Unresolve"
			if M.state.by_tab[state.tab] == state and vim.api.nvim_buf_is_valid(state.reply_buf) then
				restore_editing(state, false)
			end
			if not ok then
				vim.notify(verb .. " failed: " .. (message or "Unknown error"), vim.log.levels.ERROR)
				return
			end
			vim.notify("Thread " .. (resolved and "resolved" or "unresolved"), vim.log.levels.INFO)
			require("gleb.pr").refresh(state.review.root, { force = true, silent = true })
		end)
		return
	end
	local body = reply_text(state)
	state.mode = "running"
	state.operation = "send"
	layout(state)
	require("gleb.pr.gh").reply(state.review, state.thread.id, body, nil, function(ok, message)
		if ok then
			M.state.drafts[state.thread.id] = nil
			if M.state.by_tab[state.tab] == state and vim.api.nvim_buf_is_valid(state.reply_buf) then
				vim.bo[state.reply_buf].modifiable = true
				fill(state.reply_buf, { "", "", "" }, true)
				restore_editing(state, false)
			end
			vim.notify("Reply sent", vim.log.levels.INFO)
			require("gleb.pr").refresh(state.review.root, { force = true, silent = true })
			return
		end
		if M.state.by_tab[state.tab] == state and vim.api.nvim_buf_is_valid(state.reply_buf) then
			restore_editing(state, false)
		end
		vim.notify("Reply failed: " .. (message or "Unknown error"), vim.log.levels.ERROR)
	end)
end

---@return nil
function M.resolve()
	local state = current()
	if not state or state.mode ~= "normal" then
		return
	end
	local permitted = state.thread.resolved and state.thread.can_unresolve or state.thread.can_resolve
	if not permitted then
		return
	end
	state.mode = "confirm_resolve"
	vim.bo[state.reply_buf].modifiable = false
	vim.bo[state.reply_buf].filetype = "gleb-pr-confirm"
	layout(state)
end

---@return nil
function M.open_web()
	local state = current()
	local comment = state and state.thread.comments[1] or nil
	if comment then
		vim.ui.open(comment.url)
	end
end

---@return nil
function M.close_current()
	local state = current()
	if state then
		M.close(state)
	end
end

---@param buf integer
---@param lines string[]
---@param modifiable boolean
fill = function(buf, lines, modifiable)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = modifiable
end

---@param id string
---@return string
local function shortcut(id)
	local store = assert(require("gleb.actions").state.store, "actions are not set up")
	local lhs = assert(store.last_good[id], "shortcut is not configured")[1]
	if lhs == "<CR>" then
		return "↩"
	end
	return action_rows.physical_label(lhs)
end

---@param question string
---@param keys string
---@param width integer
---@return gleb.pr.ThreadHintRow
local function question_row(question, keys, width)
	local padding = math.max(width - 2 - vim.fn.strdisplaywidth(question) - vim.fn.strdisplaywidth(keys), 1)
	return {
		text = " " .. question .. string.rep(" ", padding) .. keys .. " ",
		normal = "PrConfirmHint",
		group = "PrConfirm",
		col = 1,
		end_col = 1 + #question,
	}
end

---@param state gleb.pr.ThreadWindow
---@param width integer
---@return gleb.pr.ThreadHintRow
local function hint_row(state, width)
	if state.mode == "confirm_send" then
		return question_row(
			"Send this reply to " .. state.thread.comments[1].author .. " on " .. state.review.host .. "?",
			"Send " .. shortcut("pr.confirm_yes") .. " · Keep editing " .. shortcut("pr.confirm_no"),
			width
		)
	elseif state.mode == "confirm_resolve" then
		local verb = state.thread.resolved and "Unresolve" or "Resolve"
		return question_row(
			verb .. " this thread?",
			verb .. " " .. shortcut("pr.confirm_yes") .. " · Cancel " .. shortcut("pr.confirm_no"),
			width
		)
	elseif state.mode == "running" then
		local progress = state.operation == "send" and "Sending..." or "Resolving..."
		return {
			text = " " .. progress .. string.rep(" ", math.max(width - vim.fn.strdisplaywidth(progress) - 1, 0)),
			normal = "PrConfirmHint",
			group = "PrConfirm",
			col = 1,
			end_col = 1 + #progress,
		}
	end
	local hints = {}
	if state.thread.can_reply then
		hints[#hints + 1] = "Reply " .. shortcut("pr.thread_send")
	end
	local can_change_resolution = state.thread.resolved and state.thread.can_unresolve or state.thread.can_resolve
	if can_change_resolution then
		local label = state.thread.resolved and "Unresolve " or "Resolve "
		hints[#hints + 1] = label .. shortcut("pr.thread_resolve")
	end
	vim.list_extend(hints, {
		"Open on web " .. shortcut("pr.thread_open_web"),
		"Close " .. shortcut("pr.thread_close"),
	})
	local text = table.concat(hints, " · ")
	local padding = string.rep(" ", math.max(width - vim.fn.strdisplaywidth(text) - 1, 0))
	return {
		text = padding .. text .. " ",
		normal = "Normal",
		group = "PickerHint",
		col = #padding,
		end_col = #padding + #text,
	}
end

---@param state gleb.pr.ThreadWindow
---@param width integer
local function draw_hint_row(state, width)
	local row = hint_row(state, width)
	fill(state.hint_buf, { row.text }, false)
	vim.api.nvim_buf_clear_namespace(state.hint_buf, namespace, 0, -1)
	vim.api.nvim_buf_set_extmark(state.hint_buf, namespace, 0, row.col, { end_col = row.end_col, hl_group = row.group })
	vim.wo[state.hint_win].winhighlight = ("Normal:%s,FloatBorder:FloatBorder"):format(row.normal)
end

---@param state gleb.pr.ThreadWindow
---@param messages gleb.pr.ThreadMessages
local function draw_messages(state, messages)
	fill(state.messages_buf, messages.lines, false)
	vim.bo[state.messages_buf].vartabstop = messages.vartabstop
	vim.api.nvim_buf_clear_namespace(state.messages_buf, namespace, 0, -1)
	for _, highlight in ipairs(messages.highlights) do
		if highlight.line < #messages.lines then
			vim.api.nvim_buf_set_extmark(state.messages_buf, namespace, highlight.line, highlight.col, {
				end_col = highlight.end_col,
				hl_group = highlight.group,
			})
		end
	end
end

--- The empty reply shows the placeholder; any text hides it.
---@param state gleb.pr.ThreadWindow
---@return nil
local function draw_placeholder(state)
	if not vim.api.nvim_buf_is_valid(state.reply_buf) then
		return
	end
	vim.api.nvim_buf_clear_namespace(state.reply_buf, namespace, 0, -1)
	if reply_is_empty(state) then
		vim.api.nvim_buf_set_extmark(state.reply_buf, namespace, 0, 0, {
			virt_text = { { "Write a reply…", "PrReplyPlaceholder" } },
			virt_text_pos = "overlay",
		})
	end
end

--- The global statusline shows the current window's: give the floats the active statusline of the window the thread
--- was opened from, as lualine draws none for floats.
---@param state gleb.pr.ThreadWindow
---@return nil
local function draw_statusline(state)
	if not package.loaded.lualine or not vim.api.nvim_win_is_valid(state.origin_win) then
		return
	end
	local statusline = vim.api.nvim_win_call(state.origin_win, function()
		local actual_curwin = vim.g.actual_curwin
		vim.g.actual_curwin = state.origin_win
		local rendered = require("lualine").statusline(true) or ""
		vim.g.actual_curwin = actual_curwin
		return rendered
	end)
	for _, win in ipairs({ state.messages_win, state.reply_win }) do
		if vim.api.nvim_win_is_valid(win) then
			vim.wo[win].statusline = statusline
		end
	end
end

---@param state gleb.pr.ThreadWindow
---@return nil
layout = function(state)
	if not vim.api.nvim_win_is_valid(state.messages_win) then
		return
	end
	local outer_width = math.max(4, math.min(MAX_WIDTH, vim.o.columns - 4))
	local inner_width = outer_width - 2
	local reply_height =
		math.min(MAX_REPLY_HEIGHT, math.max(MIN_REPLY_HEIGHT, vim.api.nvim_buf_line_count(state.reply_buf)))
	local messages = message_lines(state.review, state.thread, math.max(1, outer_width - 4))
	local max_outer_height = math.max(8, vim.o.lines - 4)
	local max_messages = math.max(1, max_outer_height - reply_height - 5)
	if #messages.lines > max_messages then
		local dropped = #messages.lines - max_messages
		messages.lines = vim.list_slice(messages.lines, dropped + 1, #messages.lines)
		for _, highlight in ipairs(messages.highlights) do
			highlight.line = highlight.line - dropped
		end
		messages.highlights = vim.tbl_filter(function(highlight)
			return highlight.line >= 0
		end, messages.highlights)
	end
	draw_messages(state, messages)
	local message_height = #messages.lines
	local outer_height = message_height + reply_height + 5
	local row = math.floor((vim.o.lines - 1 - outer_height) / 2)
	local col = math.floor((vim.o.columns - outer_width) / 2)
	draw_hint_row(state, inner_width)
	draw_placeholder(state)

	vim.api.nvim_win_set_config(state.messages_win, {
		relative = "editor",
		row = row,
		col = col,
		width = inner_width,
		height = message_height,
		title = (" %s:%d · PR #%d · %s "):format(
			vim.fs.basename(state.thread.path),
			state.thread.line or state.thread.original_line or 0,
			state.review.pr.number,
			state_label(state.thread)
		),
		title_pos = "left",
		footer = { { "─", "FloatBorder" }, { " Reply ", "PrPeekMeta" } },
		footer_pos = "left",
	})
	vim.api.nvim_win_set_config(state.reply_win, {
		relative = "editor",
		row = row + message_height + 2,
		col = col,
		width = inner_width,
		height = reply_height,
	})
	vim.api.nvim_win_set_config(state.hint_win, {
		relative = "editor",
		row = row + message_height + reply_height + 3,
		col = col,
		width = inner_width,
		height = 1,
	})
	draw_statusline(state)
end

---@param enter boolean
---@param config table
---@return integer
local function open_window(enter, config)
	local buf = config.buf
	config.buf = nil
	config.relative = "editor"
	config.style = "minimal"
	config.zindex = 50
	return vim.api.nvim_open_win(buf, enter, config)
end

---@param review gleb.pr.Review
---@param thread gleb.pr.Thread
---@return nil
function M.open(review, thread)
	local tab = vim.api.nvim_get_current_tabpage()
	local previous = M.state.by_tab[tab]
	if previous then
		M.close(previous)
	end
	local origin_win = vim.api.nvim_get_current_win()
	local origin_scrolloff = pin_origin(origin_win)

	local messages_buf = vim.api.nvim_create_buf(false, true)
	local reply_buf = vim.api.nvim_create_buf(false, true)
	local hint_buf = vim.api.nvim_create_buf(false, true)
	for _, buf in ipairs({ messages_buf, reply_buf, hint_buf }) do
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].swapfile = false
	end
	vim.bo[messages_buf].filetype = "gleb-pr-thread"
	vim.bo[reply_buf].filetype = "gleb-pr-thread"
	fill(messages_buf, { "" }, false)
	fill(reply_buf, M.state.drafts[thread.id] or { "", "", "" }, true)
	fill(hint_buf, { "" }, false)

	local messages_win = open_window(false, {
		buf = messages_buf,
		row = 0,
		col = 0,
		width = 1,
		height = 1,
		border = { "╭", "─", "╮", "│", "┤", "─", "├", "│" },
		title = " ",
	})
	local reply_win = open_window(true, {
		buf = reply_buf,
		row = 0,
		col = 0,
		width = 1,
		height = 3,
		border = { "", "", "", "│", "┤", "─", "├", "│" },
	})
	local hint_win = open_window(false, {
		buf = hint_buf,
		row = 0,
		col = 0,
		width = 1,
		height = 1,
		focusable = false,
		border = { "", "", "", "│", "╯", "─", "╰", "│" },
	})
	-- a one-cell fold column is the inner padding before the text
	for _, win in ipairs({ messages_win, reply_win }) do
		vim.wo[win].foldcolumn = "1"
	end
	vim.wo[messages_win].winhighlight = "Normal:Normal,FoldColumn:Normal,FloatBorder:FloatBorder,FloatTitle:FloatTitle"
	vim.wo[reply_win].winhighlight = "Normal:Normal,FoldColumn:Normal,FloatBorder:FloatBorder"

	local group = vim.api.nvim_create_augroup("gleb_pr_thread_window_" .. tab, { clear = true })
	local state = {
		tab = tab,
		review = review,
		thread = thread,
		messages_buf = messages_buf,
		messages_win = messages_win,
		reply_buf = reply_buf,
		reply_win = reply_win,
		hint_buf = hint_buf,
		hint_win = hint_win,
		origin_win = origin_win,
		origin_scrolloff = origin_scrolloff,
		group = group,
		closing = false,
		mode = "normal",
	}
	M.state.by_tab[tab] = state
	vim.api.nvim_create_autocmd("VimResized", {
		group = group,
		callback = function()
			layout(state)
		end,
	})
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = group,
		buffer = reply_buf,
		callback = function()
			draw_placeholder(state)
		end,
	})
	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		callback = function()
			draw_statusline(state)
		end,
	})
	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		pattern = vim.tbl_map(tostring, { messages_win, reply_win, hint_win }),
		callback = function()
			M.close(state)
		end,
	})
	vim.api.nvim_create_autocmd("WinLeave", {
		group = group,
		callback = function()
			vim.schedule(function()
				if state.closing then
					return
				end
				local focused = vim.api.nvim_get_current_win()
				if not vim.tbl_contains({ state.messages_win, state.reply_win, state.hint_win }, focused) then
					M.close(state)
				end
			end)
		end,
	})
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "GlebPrThreads",
		callback = function(event)
			if state.closing or not event.data or event.data.root ~= state.review.root then
				return
			end
			local refreshed_review = require("gleb.pr").get(state.review.root)
			local refreshed_thread = refreshed_review
				and vim.iter(refreshed_review.threads):find(function(candidate)
					return candidate.id == state.thread.id
				end)
			if refreshed_review and refreshed_thread then
				state.review = refreshed_review
				state.thread = refreshed_thread
				layout(state)
			end
		end,
	})
	layout(state)
	vim.cmd("stopinsert")
end

---@param win integer
---@param buf integer
---@return nil
function M.open_at_cursor(win, buf)
	local path = vim.api.nvim_buf_get_name(buf)
	local review
	for root, candidate in pairs(require("gleb.pr").state.by_root) do
		if vim.fs.relpath(root, path) then
			review = candidate
			break
		end
	end
	local cursor_line = vim.api.nvim_win_get_cursor(win)[1]
	local notified = false
	local function finish(locations)
		local matching = vim.tbl_filter(function(location)
			return location.line == cursor_line
		end, locations)
		table.sort(matching, function(left, right)
			return left.thread.resolved == right.thread.resolved and false or not left.thread.resolved
		end)
		if review and matching[1] then
			M.open(review, matching[1].thread)
		elseif not notified then
			notified = true
			vim.notify("No thread on this line", vim.log.levels.INFO)
		end
	end
	local locations, loading = require("gleb.pr").locate(buf, finish)
	if not loading then
		finish(locations)
	end
end

return M

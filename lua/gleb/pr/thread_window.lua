-- Review-thread window: one tab-local owner lays out thread context, comments, reply space, and hints.

local M = {}

local MAX_WIDTH = 72
local MIN_REPLY_HEIGHT = 3
local MAX_REPLY_HEIGHT = 8
local namespace = vim.api.nvim_create_namespace("gleb_pr_thread_window")

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
---@field group integer
---@field closing boolean

---@class gleb.pr.ThreadWindowState
---@field by_tab table<integer, gleb.pr.ThreadWindow>

---@type gleb.pr.ThreadWindowState
M.state = { by_tab = {} }

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
local function source_line(review, thread)
	if thread.side == "LEFT" or thread.subject == "file" then
		return nil, nil
	end
	local path = vim.fs.joinpath(review.root, thread.path)
	local line = thread.line or thread.original_line
	if not line then
		return nil, nil
	end
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.fs.normalize(vim.api.nvim_buf_get_name(buf)) == path then
			return vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1], line
		end
	end
	local lines = vim.fn.readfile(path, "", line)
	return lines[line], line
end

---@param review gleb.pr.Review
---@param thread gleb.pr.Thread
---@param width integer
---@return string[]
local function message_lines(review, thread, width)
	local line, lnum = source_line(review, thread)
	local lines = {}
	if line and lnum then
		lines[#lines + 1] = ("%4d %s"):format(lnum, line)
	else
		local comment = thread.comments[1]
		local hunk = comment and vim.split(comment.diff_hunk, "\n", { plain = true }) or {}
		lines = vim.list_slice(hunk, math.max(1, #hunk - 3), #hunk)
	end
	lines[#lines + 1] = ""
	for _, comment in ipairs(thread.comments) do
		lines[#lines + 1] = comment.author .. " · " .. age(comment.created_at)
		vim.list_extend(lines, wrap(comment.body, width))
		lines[#lines + 1] = ""
	end
	return lines
end

---@param state gleb.pr.ThreadWindow
---@return nil
function M.close(state)
	if state.closing then
		return
	end
	state.closing = true
	M.state.by_tab[state.tab] = nil
	pcall(vim.api.nvim_del_augroup_by_id, state.group)
	for _, win in ipairs({ state.messages_win, state.reply_win, state.hint_win }) do
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
end

---@param buf integer
---@param lines string[]
---@param modifiable boolean
local function fill(buf, lines, modifiable)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = modifiable
end

---@param state gleb.pr.ThreadWindow
---@return nil
local function layout(state)
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
	if #messages > max_messages then
		messages = vim.list_slice(messages, #messages - max_messages + 1, #messages)
	end
	fill(state.messages_buf, messages, false)
	local outer_height = #messages + reply_height + 5
	local row = math.floor((vim.o.lines - 1 - outer_height) / 2)
	local col = math.floor((vim.o.columns - outer_width) / 2)
	local line = " Reply ↩ · Resolve R · Open on web gx · Close q "
	local padding = math.max(inner_width - vim.fn.strdisplaywidth(line), 0)
	fill(state.hint_buf, { string.rep(" ", padding) .. line }, false)

	vim.api.nvim_win_set_config(state.messages_win, {
		relative = "editor",
		row = row,
		col = col,
		width = inner_width,
		height = #messages,
		title = (" %s:%d · PR #%d · %s "):format(
			vim.fs.basename(state.thread.path),
			state.thread.line or state.thread.original_line or 0,
			state.review.pr.number,
			state_label(state.thread)
		),
		title_pos = "left",
	})
	vim.api.nvim_win_set_config(state.reply_win, {
		relative = "editor",
		row = row + #messages + 1,
		col = col,
		width = inner_width,
		height = reply_height,
	})
	vim.api.nvim_win_set_config(state.hint_win, {
		relative = "editor",
		row = row + #messages + reply_height + 2,
		col = col,
		width = inner_width,
		height = 1,
	})
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
	fill(reply_buf, { "", "", "" }, true)
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
	vim.wo[messages_win].winhighlight = "Normal:Normal,FloatBorder:FloatBorder,FloatTitle:FloatTitle"
	vim.wo[reply_win].winhighlight = "Normal:Normal,FloatBorder:FloatBorder"
	vim.wo[hint_win].winhighlight = "Normal:PickerHint,FloatBorder:FloatBorder"
	vim.api.nvim_buf_set_extmark(reply_buf, namespace, 0, 0, {
		virt_text = { { "Write a reply…", "PrReplyPlaceholder" } },
		virt_text_pos = "overlay",
	})

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
		group = group,
		closing = false,
	}
	M.state.by_tab[tab] = state
	vim.api.nvim_create_autocmd("VimResized", {
		group = group,
		callback = function()
			layout(state)
		end,
	})
	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		pattern = vim.tbl_map(tostring, { messages_win, reply_win, hint_win }),
		callback = function()
			M.close(state)
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
